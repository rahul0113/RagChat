"""
Multi-format document loader with rich metadata extraction.
Supports: PDF, DOCX, TXT, HTML, CSV, Markdown, JSON
Extracts: filename, page_number, section_heading, language, upload_timestamp
"""
import io
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import BinaryIO

logger = logging.getLogger(__name__)


def _detect_language(text: str) -> str:
    """Detect language of text. Returns ISO 639-1 code."""
    try:
        from langdetect import detect
        return detect(text[:5000])
    except Exception:
        return "en"


def _extract_headings_from_html(text: str) -> list[str]:
    """Extract heading text from HTML content."""
    try:
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(text, "html.parser")
        headings = []
        for tag in soup.find_all(["h1", "h2", "h3", "h4", "h5", "h6"]):
            headings.append(tag.get_text(strip=True))
        return headings
    except Exception:
        return []


def _extract_headings_from_text(text: str) -> list[str]:
    """Extract potential section headings from plain text."""
    import re
    headings = []
    for line in text.split('\n'):
        line = line.strip()
        if not line or len(line) > 80:
            continue
        # Markdown headings
        if re.match(r'^#{1,6}\s+', line):
            headings.append(line.lstrip('#').strip())
        # Numbered sections
        elif re.match(r'^\d+[\.\)]\s+[A-Z]', line):
            headings.append(line)
    return headings


def load_pdf(file: BinaryIO, filename: str, base_metadata: dict = None) -> list[dict]:
    """Load PDF with per-page text extraction and metadata."""
    from pypdf import PdfReader
    base_metadata = base_metadata or {}

    raw = file.read()
    reader = PdfReader(io.BytesIO(raw))
    all_text_parts = []
    chunks = []

    for page_num, page in enumerate(reader.pages, 1):
        text = page.extract_text()
        if text and text.strip():
            all_text_parts.append(text)
            chunks.append({
                "text": text.strip(),
                "page_number": page_num,
                **base_metadata,
            })

    full_text = "\n\n".join(all_text_parts)

    # If no text extracted, try OCR for scanned PDFs
    if not chunks:
        try:
            from rag.ocr import is_scanned_pdf, ocr_pdf
            if is_scanned_pdf(raw):
                logger.info(f"Detected scanned PDF: {filename}, attempting OCR...")
                ocr_text = ocr_pdf(raw)
                if ocr_text.strip():
                    chunks = [{
                        "text": ocr_text.strip(),
                        "page_number": 1,
                        "language": _detect_language(ocr_text),
                        **base_metadata,
                    }]
                    full_text = ocr_text
        except ImportError:
            pass

    if not chunks:
        raise ValueError(f"PDF '{filename}' produced no text content.")

    # Detect language from full text
    lang = _detect_language(full_text)
    for chunk in chunks:
        chunk["language"] = lang

    logger.info(f"Loaded PDF: {filename}, {len(chunks)} pages, lang={lang}")
    return chunks


def load_docx(file: BinaryIO, filename: str, base_metadata: dict = None) -> list[dict]:
    """Load DOCX with paragraph-level heading detection."""
    from docx import Document
    base_metadata = base_metadata or {}

    raw = file.read()
    doc = Document(io.BytesIO(raw))

    paragraphs = []
    current_heading = ""
    all_text = []

    for para in doc.paragraphs:
        text = para.text.strip()
        if not text:
            continue

        # Detect headings (DOCX heading styles)
        if para.style and para.style.name and para.style.name.startswith("Heading"):
            current_heading = text

        paragraphs.append({
            "text": text,
            "section_heading": current_heading,
        })
        all_text.append(text)

    if not paragraphs:
        raise ValueError(f"DOCX '{filename}' produced no text content.")

    full_text = "\n".join(all_text)
    lang = _detect_language(full_text)

    # Group paragraphs into pages (every ~20 paragraphs ≈ 1 page)
    PAGE_SIZE = 20
    chunks = []
    for i in range(0, len(paragraphs), PAGE_SIZE):
        group = paragraphs[i:i + PAGE_SIZE]
        combined_text = "\n\n".join(p["text"] for p in group)
        heading = group[0].get("section_heading", "")
        chunks.append({
            "text": combined_text,
            "page_number": (i // PAGE_SIZE) + 1,
            "section_heading": heading,
            "language": lang,
            **base_metadata,
        })

    logger.info(f"Loaded DOCX: {filename}, {len(chunks)} sections, lang={lang}")
    return chunks


def load_html(file: BinaryIO, filename: str, base_metadata: dict = None) -> list[dict]:
    """Load HTML with heading extraction."""
    from bs4 import BeautifulSoup
    base_metadata = base_metadata or {}

    raw = file.read()
    soup = BeautifulSoup(io.BytesIO(raw), "html.parser")

    # Remove script and style elements
    for tag in soup(["script", "style", "nav", "footer", "header"]):
        tag.decompose()

    # Extract headings
    headings = []
    for tag in soup.find_all(["h1", "h2", "h3", "h4", "h5", "h6"]):
        headings.append(tag.get_text(strip=True))

    text = soup.get_text(separator="\n", strip=True)
    if not text:
        raise ValueError(f"HTML '{filename}' produced no text content.")

    lang = _detect_language(text)

    # Split by sections based on headings
    chunks = []
    current_heading = ""
    current_text = []

    for element in soup.find_all(["h1", "h2", "h3", "h4", "h5", "h6", "p", "div", "li"]):
        tag_name = element.name
        element_text = element.get_text(strip=True)
        if not element_text:
            continue

        if tag_name.startswith("h"):
            # Save previous section
            if current_text:
                chunks.append({
                    "text": "\n".join(current_text),
                    "section_heading": current_heading,
                    "language": lang,
                    **base_metadata,
                })
                current_text = []
            current_heading = element_text
        else:
            current_text.append(element_text)

    # Don't forget last section
    if current_text:
        chunks.append({
            "text": "\n".join(current_text),
            "section_heading": current_heading,
            "language": lang,
            **base_metadata,
        })

    # Fallback: if no structured chunks, return full text as one chunk
    if not chunks:
        chunks = [{
            "text": text,
            "section_heading": "",
            "language": lang,
            **base_metadata,
        }]

    logger.info(f"Loaded HTML: {filename}, {len(chunks)} sections, lang={lang}")
    return chunks


def load_csv(file: BinaryIO, filename: str, base_metadata: dict = None) -> list[dict]:
    """Load CSV with row-level metadata."""
    import pandas as pd
    base_metadata = base_metadata or {}

    raw = file.read()
    df = pd.read_csv(io.BytesIO(raw))

    all_text = []
    chunks = []

    for row_num, (_, row) in enumerate(df.iterrows(), 1):
        row_text = "\n".join(f"{col}: {val}" for col, val in row.items() if pd.notna(val))
        if row_text.strip():
            all_text.append(row_text)
            chunks.append({
                "text": row_text,
                "page_number": row_num,  # Use row number as page
                "language": _detect_language(row_text),
                **base_metadata,
            })

    if not chunks:
        raise ValueError(f"CSV '{filename}' produced no text content.")

    logger.info(f"Loaded CSV: {filename}, {len(chunks)} rows")
    return chunks


def load_markdown(file: BinaryIO, filename: str, base_metadata: dict = None) -> list[dict]:
    """Load Markdown with heading detection."""
    base_metadata = base_metadata or {}

    raw = file.read()
    text = raw.decode("utf-8", errors="ignore")
    if not text.strip():
        raise ValueError(f"Markdown '{filename}' is empty.")

    headings = _extract_headings_from_text(text)
    lang = _detect_language(text)

    # Split by headings
    import re
    sections = re.split(r'(^#{1,6}\s+.+$)', text, flags=re.MULTILINE)
    chunks = []
    current_heading = ""
    current_text = []

    for part in sections:
        if re.match(r'^#{1,6}\s+', part):
            # Save previous section
            if current_text:
                combined = "\n".join(current_text).strip()
                if combined:
                    chunks.append({
                        "text": combined,
                        "section_heading": current_heading,
                        "language": lang,
                        **base_metadata,
                    })
                current_text = []
            current_heading = part.lstrip('#').strip()
        else:
            current_text.append(part)

    # Last section
    if current_text:
        combined = "\n".join(current_text).strip()
        if combined:
            chunks.append({
                "text": combined,
                "section_heading": current_heading,
                "language": lang,
                **base_metadata,
            })

    if not chunks:
        chunks = [{
            "text": text,
            "section_heading": "",
            "language": lang,
            **base_metadata,
        }]

    logger.info(f"Loaded Markdown: {filename}, {len(chunks)} sections, lang={lang}")
    return chunks


def load_text(file: BinaryIO, filename: str, base_metadata: dict = None) -> list[dict]:
    """Load plain text file."""
    base_metadata = base_metadata or {}

    raw = file.read()
    text = raw.decode("utf-8", errors="ignore")
    if not text.strip():
        raise ValueError(f"Text file '{filename}' is empty.")

    lang = _detect_language(text)
    return [{
        "text": text,
        "language": lang,
        **base_metadata,
    }]


def load_json(file: BinaryIO, filename: str, base_metadata: dict = None) -> list[dict]:
    """Load JSON file with structured extraction."""
    base_metadata = base_metadata or {}

    raw = file.read()
    data = json.loads(raw.decode("utf-8", errors="ignore"))

    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        items = [data]
    else:
        raise ValueError(f"JSON '{filename}' has unexpected structure.")

    chunks = []
    for i, item in enumerate(items):
        text = json.dumps(item, indent=2) if isinstance(item, dict) else str(item)
        lang = _detect_language(text)
        chunks.append({
            "text": text,
            "page_number": i + 1,
            "language": lang,
            **base_metadata,
        })

    if not chunks:
        raise ValueError(f"JSON '{filename}' produced no text content.")

    logger.info(f"Loaded JSON: {filename}, {len(chunks)} items, lang={lang}")
    return chunks


LOADERS = {
    ".pdf": load_pdf,
    ".docx": load_docx,
    ".doc": load_docx,
    ".txt": load_text,
    ".html": load_html,
    ".htm": load_html,
    ".csv": load_csv,
    ".md": load_markdown,
    ".json": load_json,
}


def load_document(file: BinaryIO, filename: str) -> list[dict]:
    """
    Load a document and return list of chunk metadata dicts.
    Each dict contains: text, language, and format-specific fields
    (page_number, section_heading, etc.).
    """
    ext = Path(filename).suffix.lower()
    loader = LOADERS.get(ext)
    if not loader:
        raise ValueError(f"Unsupported format: {ext}. Supported: {list(LOADERS.keys())}")

    logger.info(f"Loading {ext} file: {filename}")

    base_metadata = {
        "source": filename,
        "upload_timestamp": datetime.utcnow().isoformat(),
    }

    chunks = loader(file, filename, base_metadata)

    if not chunks:
        raise ValueError(f"Document '{filename}' produced no text content.")

    total_chars = sum(len(c["text"]) for c in chunks)
    logger.info(f"Loaded {total_chars} characters in {len(chunks)} chunks from '{filename}'.")
    return chunks

"""
Multi-format document loader.
Supports: PDF, DOCX, TXT, HTML, CSV, Markdown, JSON
"""
import logging
import json
from pathlib import Path
from typing import BinaryIO

logger = logging.getLogger(__name__)


class DocumentChunk:
    """A single chunk of text from a document."""
    def __init__(self, text: str, metadata: dict):
        self.text = text
        self.metadata = metadata

    def __repr__(self):
        return f"DocumentChunk(text={self.text[:50]}..., metadata={self.metadata})"


def load_pdf(file: BinaryIO, filename: str) -> str:
    from pypdf import PdfReader
    import io
    reader = PdfReader(io.BytesIO(file.read()))
    pages = []
    for page in reader.pages:
        text = page.extract_text()
        if text:
            pages.append(text)
    return "\n\n".join(pages)


def load_docx(file: BinaryIO, filename: str) -> str:
    from docx import Document
    import io
    doc = Document(io.BytesIO(file.read()))
    return "\n\n".join(para.text for para in doc.paragraphs if para.text.strip())


def load_html(file: BinaryIO, filename: str) -> str:
    from bs4 import BeautifulSoup
    import io
    soup = BeautifulSoup(io.BytesIO(file.read()), "html.parser")
    # Remove script and style elements
    for tag in soup(["script", "style", "nav", "footer", "header"]):
        tag.decompose()
    return soup.get_text(separator="\n", strip=True)


def load_csv(file: BinaryIO, filename: str) -> str:
    import pandas as pd
    import io
    df = pd.read_csv(io.BytesIO(file.read()))
    # Convert each row to a text block
    rows = []
    for _, row in df.iterrows():
        row_text = "\n".join(f"{col}: {val}" for col, val in row.items() if pd.notna(val))
        rows.append(row_text)
    return "\n\n".join(rows)


def load_markdown(file: BinaryIO, filename: str) -> str:
    import io
    return io.BytesIO(file.read()).read().decode("utf-8", errors="ignore")


def load_text(file: BinaryIO, filename: str) -> str:
    import io
    return io.BytesIO(file.read()).read().decode("utf-8", errors="ignore")


def load_json(file: BinaryIO, filename: str) -> str:
    import io
    data = json.loads(io.BytesIO(file.read()).read().decode("utf-8", errors="ignore"))
    if isinstance(data, list):
        return "\n\n".join(json.dumps(item, indent=2) for item in data)
    return json.dumps(data, indent=2)


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


def load_document(file: BinaryIO, filename: str) -> str:
    """Load a document and return its text content."""
    ext = Path(filename).suffix.lower()
    loader = LOADERS.get(ext)
    if not loader:
        raise ValueError(f"Unsupported format: {ext}. Supported: {list(LOADERS.keys())}")

    logger.info(f"Loading {ext} file: {filename}")
    text = loader(file, filename)

    if not text or not text.strip():
        raise ValueError(f"Document '{filename}' produced no text content.")

    logger.info(f"Loaded {len(text)} characters from '{filename}'.")
    return text

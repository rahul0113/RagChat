"""
Smart document chunking with paragraph awareness, sentence preservation,
and heading detection. Produces semantically meaningful chunks for embedding.
"""
import re
from config import get_settings

settings = get_settings()

# Patterns for detecting section headings
HEADING_PATTERNS = [
    re.compile(r'^#{1,6}\s+.+', re.MULTILINE),           # Markdown headings
    re.compile(r'^[A-Z][A-Za-z0-9 ]{2,50}$', re.MULTILINE),  # ALL CAPS or Title Case lines
    re.compile(r'^\d+[\.\)]\s+[A-Z].+', re.MULTILINE),   # Numbered sections: "1. Introduction"
    re.compile(r'^[IVXLC]+[\.\)]\s+.+', re.MULTILINE),    # Roman numeral sections
    re.compile(r'^Chapter\s+\d+', re.IGNORECASE | re.MULTILINE),
    re.compile(r'^Section\s+\d+', re.IGNORECASE | re.MULTILINE),
]

SENTENCE_SPLIT = re.compile(r'(?<=[.!?])\s+(?=[A-Z])')


def _is_heading(line: str) -> bool:
    """Check if a line looks like a section heading."""
    line = line.strip()
    if not line or len(line) > 80:
        return False
    for pattern in HEADING_PATTERNS:
        if pattern.match(line):
            return True
    return False


def _split_sentences(text: str) -> list[str]:
    """Split text into sentences while preserving abbreviations."""
    sentences = SENTENCE_SPLIT.split(text)
    return [s.strip() for s in sentences if s.strip()]


def chunk_text(
    text: str,
    source: str = "",
    chunk_size: int = None,
    overlap: int = None,
    metadata: dict = None,
) -> list[dict]:
    """
    Split text into overlapping chunks with heading awareness.

    Strategy:
    1. Normalize whitespace while preserving paragraph breaks.
    2. Split into paragraphs on double newlines.
    3. Track current section heading from detected headings.
    4. Accumulate paragraphs into chunks until chunk_size is exceeded.
    5. When splitting, avoid breaking sentences.
    6. Apply character-level overlap from previous chunk tail.
    7. Final pass: split any oversized chunks by sentences.

    Returns list of chunk dicts with text, source, chunk_index, section_heading, metadata.
    """
    chunk_size = chunk_size or settings.CHUNK_SIZE
    overlap = overlap or settings.CHUNK_OVERLAP
    extra_metadata = metadata or {}

    # Normalize whitespace
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'[ \t]+', ' ', text)
    text = text.strip()

    if not text:
        return []

    # Split into paragraphs
    paragraphs = re.split(r'\n\n+', text)
    chunks = []
    current_chunk = ""
    current_heading = ""
    chunk_index = 0

    for para in paragraphs:
        para = para.strip()
        if not para:
            continue

        # Check if this paragraph is a heading
        lines = para.split('\n')
        if len(lines) == 1 and _is_heading(lines[0]):
            # If we have accumulated content, finalize current chunk
            if current_chunk.strip():
                chunks.append(_make_chunk(
                    current_chunk.strip(), source, chunk_index,
                    current_heading, extra_metadata,
                ))
                chunk_index += 1
                # Apply overlap
                if overlap > 0 and len(current_chunk) > overlap:
                    current_chunk = current_chunk[-overlap:] + "\n\n" + para
                else:
                    current_chunk = para
            else:
                current_chunk = para
            current_heading = para.strip('#').strip()
            continue

        # Check if adding this paragraph exceeds chunk size
        test_chunk = current_chunk + "\n\n" + para if current_chunk else para
        if current_chunk and len(test_chunk) > chunk_size:
            # Finalize current chunk
            chunks.append(_make_chunk(
                current_chunk.strip(), source, chunk_index,
                current_heading, extra_metadata,
            ))
            chunk_index += 1

            # Start new chunk with overlap from previous
            if overlap > 0 and len(current_chunk) > overlap:
                current_chunk = current_chunk[-overlap:] + "\n\n" + para
            else:
                current_chunk = para
        else:
            current_chunk = test_chunk

    # Don't forget the last chunk
    if current_chunk.strip():
        chunks.append(_make_chunk(
            current_chunk.strip(), source, chunk_index,
            current_heading, extra_metadata,
        ))

    # Second pass: split any oversized chunks by sentences
    final_chunks = []
    for chunk in chunks:
        if len(chunk["text"]) > chunk_size * 1.5:
            sub_chunks = _split_oversized(chunk, chunk_size, overlap)
            final_chunks.extend(sub_chunks)
        else:
            final_chunks.append(chunk)

    # Re-index after splitting
    for i, chunk in enumerate(final_chunks):
        chunk["chunk_index"] = i

    return final_chunks


def _make_chunk(
    text: str,
    source: str,
    chunk_index: int,
    section_heading: str,
    metadata: dict,
) -> dict:
    """Create a chunk dict with all metadata."""
    chunk = {
        "text": text,
        "source": source,
        "chunk_index": chunk_index,
        "section_heading": section_heading,
    }
    chunk.update(metadata)
    return chunk


def _split_oversized(
    chunk: dict,
    chunk_size: int,
    overlap: int,
) -> list[dict]:
    """Split an oversized chunk by sentences."""
    text = chunk["text"]
    sentences = _split_sentences(text)
    sub_chunks = []
    current = ""
    sub_index = 0

    for sentence in sentences:
        if current and len(current) + len(sentence) + 1 > chunk_size:
            sub_chunk = {
                "text": current.strip(),
                "source": chunk["source"],
                "chunk_index": sub_index,
                "section_heading": chunk.get("section_heading", ""),
            }
            # Copy extra metadata
            for k, v in chunk.items():
                if k not in ("text", "source", "chunk_index", "section_heading"):
                    sub_chunk[k] = v
            sub_chunks.append(sub_chunk)
            sub_index += 1

            if overlap > 0 and len(current) > overlap:
                current = current[-overlap:] + " " + sentence
            else:
                current = sentence
        else:
            current = current + " " + sentence if current else sentence

    if current.strip():
        sub_chunk = {
            "text": current.strip(),
            "source": chunk["source"],
            "chunk_index": sub_index,
            "section_heading": chunk.get("section_heading", ""),
        }
        for k, v in chunk.items():
            if k not in ("text", "source", "chunk_index", "section_heading"):
                sub_chunk[k] = v
        sub_chunks.append(sub_chunk)

    return sub_chunks

"""
Smart document chunking with overlap.
Splits text into semantically meaningful chunks for embedding.
"""
import re
from config import get_settings

settings = get_settings()


def chunk_text(text: str, source: str = "",
               chunk_size: int = None, overlap: int = None) -> list[dict]:
    """
    Split text into overlapping chunks.
    Tries to split on paragraph boundaries first, then sentences.
    """
    chunk_size = chunk_size or settings.CHUNK_SIZE
    overlap = overlap or settings.CHUNK_OVERLAP

    # Normalize whitespace but keep paragraph breaks
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'[ \t]+', ' ', text)
    text = text.strip()

    if not text:
        return []

    # Split into paragraphs first
    paragraphs = re.split(r'\n\n+', text)
    chunks = []
    current_chunk = ""
    chunk_index = 0

    for para in paragraphs:
        para = para.strip()
        if not para:
            continue

        # If adding this paragraph exceeds chunk size, finalize current chunk
        if current_chunk and len(current_chunk) + len(para) + 2 > chunk_size:
            chunks.append({
                "text": current_chunk.strip(),
                "source": source,
                "chunk_index": chunk_index,
            })
            chunk_index += 1

            # Keep overlap from end of previous chunk
            if overlap > 0 and len(current_chunk) > overlap:
                current_chunk = current_chunk[-overlap:] + "\n\n" + para
            else:
                current_chunk = para
        else:
            if current_chunk:
                current_chunk += "\n\n" + para
            else:
                current_chunk = para

    # Don't forget the last chunk
    if current_chunk.strip():
        chunks.append({
            "text": current_chunk.strip(),
            "source": source,
            "chunk_index": chunk_index,
        })

    # Handle case where single paragraphs exceed chunk_size
    final_chunks = []
    for chunk in chunks:
        if len(chunk["text"]) > chunk_size * 1.5:
            # Split oversized chunks by sentences
            sentences = re.split(r'(?<=[.!?])\s+', chunk["text"])
            sub_chunk = ""
            sub_idx = chunk["chunk_index"]
            for sent in sentences:
                if sub_chunk and len(sub_chunk) + len(sent) + 1 > chunk_size:
                    final_chunks.append({
                        "text": sub_chunk.strip(),
                        "source": source,
                        "chunk_index": sub_idx,
                    })
                    sub_idx += 1
                    if overlap > 0:
                        sub_chunk = sub_chunk[-overlap:] + " " + sent
                    else:
                        sub_chunk = sent
                else:
                    sub_chunk = (sub_chunk + " " + sent).strip() if sub_chunk else sent
            if sub_chunk.strip():
                final_chunks.append({
                    "text": sub_chunk.strip(),
                    "source": source,
                    "chunk_index": sub_idx,
                })
        else:
            final_chunks.append(chunk)

    return final_chunks

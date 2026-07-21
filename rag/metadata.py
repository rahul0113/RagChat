"""
Shared metadata builder for consistent chunk/vector metadata across the system.
Single source of truth for metadata structure — used by pipeline, ingestion,
crawler, OCR, and vector store.
"""
import uuid
from datetime import datetime


def build_document_id() -> str:
    """Generate a unique document ID."""
    return str(uuid.uuid4())


def build_chunk_metadata(
    text: str,
    source: str,
    document_id: str,
    chunk_index: int,
    tenant_id: str,
    page_number: int = None,
    section_heading: str = "",
    language: str = "en",
    upload_timestamp: str = None,
    extra: dict = None,
) -> dict:
    """
    Build a complete metadata dict for a single chunk/vector.

    This is the canonical metadata structure used throughout the system.
    Every field stored here is also stored in the Qdrant vector payload.
    """
    meta = {
        "text": text,
        "source": source,
        "document_id": document_id,
        "chunk_index": chunk_index,
        "tenant_id": tenant_id,
        "page_number": page_number,
        "section_heading": section_heading,
        "language": language,
        "upload_timestamp": upload_timestamp or datetime.utcnow().isoformat(),
    }
    if extra:
        meta.update(extra)
    return meta


def build_source_info(chunk: dict) -> dict:
    """
    Build a source reference for citations/responses.
    Extracts the citation-relevant fields from a chunk dict.
    """
    return {
        "source": chunk.get("source", ""),
        "document_id": chunk.get("document_id", ""),
        "page_number": chunk.get("page_number"),
        "section_heading": chunk.get("section_heading", ""),
        "score": round(chunk.get("score", 0), 3),
        "excerpt": chunk.get("text", "")[:200],
    }


def build_error_response(message: str, status_code: int = 500, detail: dict = None) -> dict:
    """Build a consistent error response dict."""
    resp = {
        "error": True,
        "message": message,
        "status_code": status_code,
    }
    if detail:
        resp["detail"] = detail
    return resp

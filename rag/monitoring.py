"""
Structured monitoring and logging for the RAG pipeline.
Provides helper functions for consistent, queryable log output.
"""
import time
import logging
from functools import wraps
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


def setup_structured_logging():
    """Configure JSON-structured logging for production."""
    import structlog
    structlog.configure(
        processors=[
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.add_log_level,
            structlog.processors.JSONRenderer(),
        ],
        logger_factory=structlog.PrintLoggerFactory(),
    )
    return structlog.get_logger()


def log_ingestion(tenant_id: str, filename: str, chunks: int, vectors_stored: int,
                  latency_ms: int, success: bool = True, error: str = None, **extra):
    """Log document ingestion completion."""
    fields = {
        "operation": "ingestion",
        "tenant_id": tenant_id,
        "filename": filename,
        "chunks": chunks,
        "vectors_stored": vectors_stored,
        "latency_ms": latency_ms,
        "success": success,
    }
    if error:
        fields["error"] = error
    fields.update(extra)
    _emit("ingestion", fields, success)


def log_document_parse(tenant_id: str, filename: str, pages: int, format: str,
                       latency_ms: int, ocr_used: bool = False, **extra):
    """Log document parsing stage."""
    fields = {
        "operation": "document_parse",
        "tenant_id": tenant_id,
        "filename": filename,
        "pages": pages,
        "format": format,
        "latency_ms": latency_ms,
        "ocr_used": ocr_used,
    }
    fields.update(extra)
    _emit("document_parse", fields, True)


def log_chunking(tenant_id: str, filename: str, chunk_count: int, total_chars: int,
                 chunk_size: int = None, **extra):
    """Log chunking stage."""
    fields = {
        "operation": "chunking",
        "tenant_id": tenant_id,
        "filename": filename,
        "chunk_count": chunk_count,
        "total_chars": total_chars,
    }
    if chunk_size:
        fields["chunk_size"] = chunk_size
    fields.update(extra)
    _emit("chunking", fields, True)


def log_embedding(tenant_id: str, vector_count: int, dimension: int,
                  latency_ms: int, success: bool = True, error: str = None, **extra):
    """Log embedding stage."""
    fields = {
        "operation": "embedding",
        "tenant_id": tenant_id,
        "vector_count": vector_count,
        "dimension": dimension,
        "latency_ms": latency_ms,
        "success": success,
    }
    if error:
        fields["error"] = error
    fields.update(extra)
    _emit("embedding", fields, success)


def log_qdrant(tenant_id: str, operation: str, vectors_count: int = None,
               latency_ms: int = None, success: bool = True, error: str = None, **extra):
    """Log Qdrant vector store operations."""
    fields = {
        "operation": f"qdrant_{operation}",
        "tenant_id": tenant_id,
        "success": success,
    }
    if vectors_count is not None:
        fields["vectors_count"] = vectors_count
    if latency_ms is not None:
        fields["latency_ms"] = latency_ms
    if error:
        fields["error"] = error
    fields.update(extra)
    _emit("qdrant", fields, success)


def log_retrieval(tenant_id: str, query: str, results_count: int, search_mode: str,
                  latency_ms: int, hybrid_used: bool = False, **extra):
    """Log retrieval/search stage."""
    fields = {
        "operation": "retrieval",
        "tenant_id": tenant_id,
        "query": query[:200],
        "results_count": results_count,
        "search_mode": search_mode,
        "latency_ms": latency_ms,
        "hybrid_used": hybrid_used,
    }
    fields.update(extra)
    _emit("retrieval", fields, True)


def log_reranking(tenant_id: str, input_count: int, output_count: int,
                  latency_ms: int, model: str = None, **extra):
    """Log reranking stage."""
    fields = {
        "operation": "reranking",
        "tenant_id": tenant_id,
        "input_count": input_count,
        "output_count": output_count,
        "latency_ms": latency_ms,
    }
    if model:
        fields["model"] = model
    fields.update(extra)
    _emit("reranking", fields, True)


def log_query_rewrite(tenant_id: str, original: str, rewritten: str,
                      rewrite_used: bool, latency_ms: int = 0, **extra):
    """Log query rewriting."""
    fields = {
        "operation": "query_rewrite",
        "tenant_id": tenant_id,
        "original": original[:200],
        "rewritten": rewritten[:200] if rewrite_used else "(unchanged)",
        "rewrite_used": rewrite_used,
        "latency_ms": latency_ms,
    }
    fields.update(extra)
    _emit("query_rewrite", fields, True)


def log_llm_call(tenant_id: str, model: str, latency_ms: int, tokens_in: int = None,
                 tokens_out: int = None, success: bool = True, error: str = None, **extra):
    """Log LLM generation call."""
    fields = {
        "operation": "llm_call",
        "tenant_id": tenant_id,
        "model": model,
        "latency_ms": latency_ms,
        "success": success,
    }
    if tokens_in is not None:
        fields["tokens_in"] = tokens_in
    if tokens_out is not None:
        fields["tokens_out"] = tokens_out
    if error:
        fields["error"] = error
    fields.update(extra)
    _emit("llm_call", fields, success)


def log_cache_hit(tenant_id: str, query: str, latency_ms: int, **extra):
    """Log a cache hit."""
    fields = {
        "operation": "cache_hit",
        "tenant_id": tenant_id,
        "query": query[:200],
        "latency_ms": latency_ms,
    }
    fields.update(extra)
    _emit("cache", fields, True)


def log_cache_miss(tenant_id: str, query: str, **extra):
    """Log a cache miss."""
    fields = {
        "operation": "cache_miss",
        "tenant_id": tenant_id,
        "query": query[:200],
    }
    fields.update(extra)
    _emit("cache", fields, True)


def log_ocr(tenant_id: str, filename: str, engine: str, latency_ms: int,
            text_length: int, success: bool = True, error: str = None, **extra):
    """Log OCR processing."""
    fields = {
        "operation": "ocr",
        "tenant_id": tenant_id,
        "filename": filename,
        "engine": engine,
        "latency_ms": latency_ms,
        "text_length": text_length,
        "success": success,
    }
    if error:
        fields["error"] = error
    fields.update(extra)
    _emit("ocr", fields, success)


def log_crawl(tenant_id: str, start_url: str, pages_crawled: int, chunks: int,
              latency_ms: int, success: bool = True, error: str = None, **extra):
    """Log website crawling."""
    fields = {
        "operation": "crawl",
        "tenant_id": tenant_id,
        "start_url": start_url,
        "pages_crawled": pages_crawled,
        "chunks": chunks,
        "latency_ms": latency_ms,
        "success": success,
    }
    if error:
        fields["error"] = error
    fields.update(extra)
    _emit("crawl", fields, success)


def log_error(operation: str, error: Exception, tenant_id: str = None,
              document_id: str = None, **extra):
    """Log an error with full context."""
    fields = {
        "operation": operation,
        "error_type": type(error).__name__,
        "error_message": str(error),
        "success": False,
    }
    if tenant_id:
        fields["tenant_id"] = tenant_id
    if document_id:
        fields["document_id"] = document_id
    fields.update(extra)
    _emit("error", fields, False)


def _emit(category: str, fields: dict, success: bool):
    """Emit a structured log entry."""
    msg = f"[{category}] " + " ".join(f"{k}={v}" for k, v in fields.items())
    if success:
        logger.info(msg)
    else:
        logger.warning(msg)


def get_health_check() -> dict:
    """Basic health check for the RAG system."""
    health = {"status": "healthy", "components": {}}

    # Check Qdrant
    try:
        from rag.vector_store import get_tenant_stats
        health["components"]["qdrant"] = "healthy"
    except Exception as e:
        health["components"]["qdrant"] = f"unhealthy: {e}"
        health["status"] = "degraded"

    # Check database
    try:
        from tenants.models import SessionLocal
        db = SessionLocal()
        db.execute("SELECT 1")
        db.close()
        health["components"]["database"] = "healthy"
    except Exception as e:
        health["components"]["database"] = f"unhealthy: {e}"
        health["status"] = "degraded"

    # Check cache
    try:
        from rag.cache import get_cache_stats
        stats = get_cache_stats()
        health["components"]["cache"] = f"healthy ({stats.get('total_entries', 0)} entries)"
    except Exception:
        health["components"]["cache"] = "unavailable"

    # Check background jobs
    try:
        from rag.jobs import get_job_status
        status = get_job_status()
        health["components"]["jobs"] = f"healthy (queue={status.get('queue_size', 0)})"
    except Exception:
        health["components"]["jobs"] = "unavailable"

    return health

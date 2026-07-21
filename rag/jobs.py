"""
Background job processor for async operations.
Thread-based with job status tracking, retry support, and graceful shutdown.
"""
import time
import uuid
import logging
import threading
from queue import Queue, Empty
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

MAX_RETRIES = 2

# Job status tracking
_jobs = {}
_jobs_lock = threading.Lock()


def _track_job(job_id: str, job_type: str, status: str, tenant_id: str = None,
               result: dict = None, error: str = None, retries: int = 0):
    """Update job status in the tracking store."""
    with _jobs_lock:
        _jobs[job_id] = {
            "job_id": job_id,
            "job_type": job_type,
            "status": status,
            "tenant_id": tenant_id,
            "result": result,
            "error": error,
            "retries": retries,
            "updated_at": time.time(),
        }


def _worker():
    """Background worker that processes jobs from the queue."""
    worker_id = threading.current_thread().name
    logger.info(f"Worker {worker_id} started")
    while True:
        try:
            job_id, job_type, kwargs = settings._job_queue.get(timeout=2)
            if job_id is None:  # Poison pill
                break
            _process_job(job_id, job_type, kwargs)
            settings._job_queue.task_done()
        except Empty:
            continue
        except Exception as e:
            logger.error(f"Worker {worker_id} error: {e}")


def _process_job(job_id: str, job_type: str, kwargs: dict):
    """Process a single job with retry support."""
    _track_job(job_id, job_type, "processing", tenant_id=kwargs.get("tenant_id"))
    retries = kwargs.get("_retries", 0)
    try:
        if job_type == "ingest_document":
            result = _handle_ingest_document(**kwargs)
        elif job_type == "delete_document":
            result = _handle_delete_document(**kwargs)
        elif job_type == "crawl_website":
            result = _handle_crawl_website(**kwargs)
        else:
            result = {"error": f"Unknown job type: {job_type}"}

        _track_job(job_id, job_type, "completed", tenant_id=kwargs.get("tenant_id"), result=result)
        logger.info(f"Job {job_id} ({job_type}) completed")

    except Exception as e:
        logger.error(f"Job {job_id} ({job_type}) failed: {e}")
        if retries < MAX_RETRIES:
            logger.info(f"Retrying job {job_id} (attempt {retries + 1})")
            kwargs["_retries"] = retries + 1
            _track_job(job_id, job_type, "retrying", tenant_id=kwargs.get("tenant_id"),
                      error=str(e), retries=retries + 1)
            settings._job_queue.put((job_id, job_type, kwargs))
        else:
            _track_job(job_id, job_type, "failed", tenant_id=kwargs.get("tenant_id"),
                      error=str(e), retries=retries)
            logger.error(f"Job {job_id} ({job_type}) failed after {retries} retries")


def _handle_ingest_document(tenant_id, document_id, filename, file_obj=None,
                             **kwargs):
    """Handle document ingestion job."""
    from rag.pipeline import ingest_document
    from tenants.manager import update_document_ingestion_status
    from tenants.models import Document, SessionLocal

    update_document_ingestion_status(document_id, "processing")

    try:
        # If file_obj not provided, try to load from temp storage
        if file_obj is None:
            update_document_ingestion_status(document_id, "failed",
                                              "File not available for background processing")
            return {"error": "File not available"}

        result = ingest_document(tenant_id, file_obj, filename)

        # Update DB record
        db = SessionLocal()
        try:
            doc = db.query(Document).filter(Document.id == document_id).first()
            if doc:
                doc.chunk_count = result["chunks"]
                doc.character_count = result["characters"]
                update_document_ingestion_status(document_id, "completed")
                db.commit()
        finally:
            db.close()

        return result
    except Exception as e:
        update_document_ingestion_status(document_id, "failed", str(e))
        raise


def _handle_delete_document(tenant_id, document_id, **kwargs):
    """Handle document deletion job."""
    from rag.vector_store import delete_document_vectors
    from tenants.manager import delete_document as db_delete
    delete_document_vectors(tenant_id, document_id)
    db_delete(tenant_id, document_id)
    return {"deleted": True}


def _handle_crawl_website(tenant_id, start_url, org_name, max_depth=3,
                            max_pages=100, **kwargs):
    """Handle website crawling job."""
    from rag.web_crawler import crawl_website, pages_to_chunks
    from rag.embeddings import embed_texts
    from rag.vector_store import insert_vectors, create_tenant_collection
    from tenants.manager import add_document
    from rag.chunker import chunk_text
    import uuid

    pages = crawl_website(start_url, max_depth=max_depth, max_pages=max_pages)
    if not pages:
        return {"pages": 0, "chunks": 0}

    document_id = str(uuid.uuid4())
    all_chunks = []
    for page in pages:
        chunked = chunk_text(
            page["text"],
            source=page.get("url", start_url),
            metadata={"url": page.get("url", ""), "title": page.get("title", "")},
        )
        for c in chunked:
            c["document_id"] = document_id
        all_chunks.extend(chunked)

    if all_chunks:
        create_tenant_collection(tenant_id)
        texts = [c["text"] for c in all_chunks]
        vectors = embed_texts(texts)
        metadatas = [
            {"source": c.get("source", start_url), "document_id": document_id,
             "chunk_index": c.get("chunk_index", 0)}
            for c in all_chunks
        ]
        insert_vectors(tenant_id, texts, vectors, metadatas)

        add_document(
            tenant_id=tenant_id,
            filename=start_url,
            original_filename=start_url,
            file_size=0,
            file_type="website",
            chunk_count=len(all_chunks),
            character_count=sum(len(c["text"]) for c in all_chunks),
            document_id=document_id,
            ingestion_status="completed",
        )

    return {"pages": len(pages), "chunks": len(all_chunks), "document_id": document_id}


def submit_job(job_type: str, **kwargs) -> str:
    """Submit a job for background processing. Returns job_id."""
    job_id = str(uuid.uuid4())
    _track_job(job_id, job_type, "queued", tenant_id=kwargs.get("tenant_id"))
    settings._job_queue.put((job_id, job_type, kwargs))
    logger.info(f"Job submitted: {job_id} ({job_type})")
    return job_id


def start_workers(num_workers: int = None):
    """Start background worker threads."""
    if not getattr(settings, "BACKGROUND_JOBS_ENABLED", False):
        return

    num_workers = num_workers or getattr(settings, "MAX_WORKERS", 2)
    settings._job_queue = Queue()
    settings._workers = []
    for i in range(num_workers):
        t = threading.Thread(target=_worker, name=f"worker-{i}", daemon=True)
        t.start()
        settings._workers.append(t)
    logger.info(f"Started {num_workers} background workers")


def stop_workers():
    """Gracefully stop all background workers."""
    if not hasattr(settings, "_workers") or not settings._workers:
        return

    # Send poison pills
    for _ in settings._workers:
        settings._job_queue.put((None, None, None))

    # Wait for workers to finish
    for t in settings._workers:
        t.join(timeout=5)

    settings._workers = []
    logger.info("All background workers stopped")


def get_job_status(job_id: str = None) -> dict:
    """Get status of a specific job or all jobs."""
    if job_id:
        with _jobs_lock:
            return _jobs.get(job_id, {"error": "Job not found"})
    with _jobs_lock:
        return {
            "total_jobs": len(_jobs),
            "queued": sum(1 for j in _jobs.values() if j["status"] == "queued"),
            "processing": sum(1 for j in _jobs.values() if j["status"] == "processing"),
            "completed": sum(1 for j in _jobs.values() if j["status"] == "completed"),
            "failed": sum(1 for j in _jobs.values() if j["status"] == "failed"),
            "retrying": sum(1 for j in _jobs.values() if j["status"] == "retrying"),
            "queue_size": settings._job_queue.qsize() if hasattr(settings, "_job_queue") else 0,
            "workers_active": len(settings._workers) if hasattr(settings, "_workers") else 0,
            "background_enabled": getattr(settings, "BACKGROUND_JOBS_ENABLED", False),
            "jobs": list(_jobs.values()),
        }

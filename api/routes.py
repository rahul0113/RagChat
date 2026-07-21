"""
FastAPI routes — tenant management, document ingestion, chat,
website crawling, document deletion, analytics, and health checks.
"""
import io
import json
import logging
from fastapi import APIRouter, UploadFile, File, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from tenants.manager import (
    create_tenant, get_tenant, list_tenants, update_tenant_theme,
    delete_tenant, get_tenant_by_id, increment_queries,
    get_top_queries, get_recent_queries, get_query_detail, delete_query_log,
    get_analytics_summary, add_document, get_documents, delete_document,
    update_document_ingestion_status, replace_document,
    get_unanswered_questions, get_unanswered_count, log_unanswered_question,
)
from rag.pipeline import ingest_document, query_rag, query_rag_stream
from rag.vector_store import get_tenant_stats
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()
router = APIRouter()


# --- Request models ---
class ChatRequest(BaseModel):
    query: str
    top_k: int = 5
    chat_history: list[dict] = None
    structured: bool = False


class TenantCreate(BaseModel):
    name: str
    slug: str
    org_name: str
    plan: str = "free"
    theme_name: str = "default"


class ThemeUpdate(BaseModel):
    theme: dict


class WebsiteCrawlRequest(BaseModel):
    url: str
    max_depth: int = 3
    max_pages: int = 100


class QueryRewriteRequest(BaseModel):
    query: str


class CacheClearRequest(BaseModel):
    tenant_id: str = None


# ============================================
# PUBLIC: Chat endpoints (used by widget)
# ============================================
@router.post("/chat/{slug}")
async def chat(slug: str, request: ChatRequest):
    """Public chat endpoint — widget hits this with the tenant slug."""
    tenant = get_tenant(slug=slug)
    if not tenant:
        raise HTTPException(status_code=404, detail="Chat not found")

    if not tenant.is_active:
        raise HTTPException(status_code=403, detail="This chat is currently disabled")

    increment_queries(tenant.id)

    result = query_rag(
        tenant_id=tenant.id,
        question=request.query,
        org_name=tenant.org_name,
        top_k=request.top_k,
        chat_history=request.chat_history,
        structured=request.structured,
    )
    return result


@router.post("/chat/{slug}/stream")
async def chat_stream(slug: str, request: ChatRequest):
    """Streaming chat endpoint."""
    tenant = get_tenant(slug=slug)
    if not tenant:
        raise HTTPException(status_code=404, detail="Chat not found")

    if not tenant.is_active:
        raise HTTPException(status_code=403, detail="This chat is currently disabled")

    increment_queries(tenant.id)

    generator = query_rag_stream(
        tenant_id=tenant.id,
        question=request.query,
        org_name=tenant.org_name,
        top_k=request.top_k,
        chat_history=request.chat_history,
    )

    return StreamingResponse(generator, media_type="text/event-stream")


# ============================================
# PUBLIC: Get widget config
# ============================================
@router.get("/widget/{slug}/config")
async def get_widget_config(slug: str):
    """Widget fetches its theme and config from here."""
    tenant = get_tenant(slug=slug)
    if not tenant:
        raise HTTPException(status_code=404, detail="Not found")

    return {
        "org_name": tenant.org_name,
        "theme": json.loads(tenant.theme),
    }


# ============================================
# TENANT MANAGEMENT
# ============================================
@router.post("/admin/tenants")
async def admin_create_tenant(request: Request, data: TenantCreate):
    """Create a new tenant."""
    try:
        backend_url = str(request.base_url).rstrip("/")
        result = create_tenant(
            name=data.name,
            slug=data.slug,
            org_name=data.org_name,
            plan=data.plan,
            theme_name=data.theme_name,
            backend_url=backend_url,
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Tenant creation failed: {type(e).__name__}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create tenant: {e}")


@router.get("/admin/tenants")
async def admin_list_tenants():
    """List all active tenants."""
    return list_tenants()


@router.get("/admin/tenants/{tenant_id}")
async def admin_get_tenant(tenant_id: str):
    """Get tenant details."""
    tenant = get_tenant_by_id(tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
    stats = get_tenant_stats(tenant.id)
    docs = get_documents(tenant.id)
    return {
        "id": tenant.id,
        "name": tenant.name,
        "slug": tenant.slug,
        "org_name": tenant.org_name,
        "plan": tenant.plan,
        "is_active": tenant.is_active,
        "theme": json.loads(tenant.theme),
        "total_queries": tenant.total_queries,
        "total_documents": tenant.total_documents,
        "documents": docs,
        "vector_stats": stats,
        "embed_code": f'<script src="{settings.BACKEND_URL}/widget/static/widget.js" data-tenant-id="{tenant.id}" data-tenant-slug="{tenant.slug}"></script>',
    }


@router.put("/admin/tenants/{tenant_id}/theme")
async def admin_update_theme(tenant_id: str, data: ThemeUpdate):
    """Update a tenant's widget theme."""
    success = update_tenant_theme(tenant_id, data.theme)
    if not success:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return {"status": "updated"}


@router.delete("/admin/tenants/{tenant_id}")
async def admin_delete_tenant(tenant_id: str):
    """Delete a tenant and all their data."""
    success = delete_tenant(tenant_id)
    if not success:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return {"status": "deleted"}


# ============================================
# DOCUMENT MANAGEMENT
# ============================================
@router.post("/admin/tenants/{tenant_id}/upload")
async def admin_upload_document(
    tenant_id: str,
    file: UploadFile = File(...),
):
    """Upload and ingest a document for a tenant."""
    tenant = get_tenant_by_id(tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")

    # Validate file size
    contents = await file.read()
    size_mb = len(contents) / (1024 * 1024)
    if size_mb > settings.MAX_FILE_SIZE_MB:
        raise HTTPException(status_code=413, detail=f"File too large. Max: {settings.MAX_FILE_SIZE_MB}MB")

    # Validate extension
    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in settings.SUPPORTED_FORMATS:
        raise HTTPException(status_code=400, detail=f"Unsupported format: {ext}")

    # Ingest
    file_obj = io.BytesIO(contents)
    new_doc_id = None
    try:
        # Check for existing document with same filename — replace it
        old_doc_id = replace_document(tenant.id, file.filename, None)

        result = ingest_document(tenant.id, file_obj, file.filename)
        new_doc_id = result["document_id"]

        # Delete old document vectors if replacing
        if old_doc_id:
            from rag.vector_store import delete_document_vectors
            delete_document_vectors(tenant.id, old_doc_id)
            logger.info(f"Replaced old document {old_doc_id} with {new_doc_id}")

        # Store document record with completed status
        add_document(
            tenant_id=tenant.id,
            filename=result["filename"],
            original_filename=file.filename,
            file_size=len(contents),
            file_type=ext,
            chunk_count=result["chunks"],
            character_count=result["characters"],
            document_id=new_doc_id,
            ingestion_status="completed",
        )

        return {"status": "ingested", **result}
    except Exception as e:
        logger.error(f"Ingestion error: {e}")
        # Mark as failed if we have a document_id
        if new_doc_id:
            update_document_ingestion_status(new_doc_id, "failed", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/admin/tenants/{tenant_id}/documents")
async def admin_list_documents(tenant_id: str):
    """List all ingested documents for a tenant."""
    tenant = get_tenant_by_id(tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
    docs = get_documents(tenant_id)
    stats = get_tenant_stats(tenant.id)
    return {
        "documents": docs,
        "total_vectors": stats.get("total_vectors", 0),
        "tenant_id": tenant.id,
        "tenant_name": tenant.name,
    }


@router.delete("/admin/tenants/{tenant_id}/documents/{document_id}")
async def admin_delete_document(tenant_id: str, document_id: str):
    """Delete a specific document and its vectors."""
    tenant = get_tenant_by_id(tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")

    success = delete_document(tenant_id, document_id)
    if not success:
        raise HTTPException(status_code=404, detail="Document not found")

    return {"status": "deleted", "document_id": document_id}


# ============================================
# WEBSITE CRAWL
# ============================================
@router.post("/admin/tenants/{tenant_id}/crawl")
async def admin_crawl_website(tenant_id: str, data: WebsiteCrawlRequest):
    """Crawl a website and ingest its content."""
    tenant = get_tenant_by_id(tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")

    try:
        if settings.BACKGROUND_JOBS_ENABLED:
            from rag.jobs import submit_job
            submit_job(
                "crawl_website",
                tenant_id=tenant.id,
                start_url=data.url,
                org_name=tenant.org_name,
                max_depth=data.max_depth,
                max_pages=data.max_pages,
            )
            return {
                "status": "queued",
                "message": f"Crawl job queued for {data.url}",
                "url": data.url,
            }
        else:
            # Run synchronously
            from rag.web_crawler import crawl_website, pages_to_chunks
            from rag.embeddings import embed_texts
            from rag.vector_store import insert_vectors, create_tenant_collection
            from rag.chunker import chunk_text
            import uuid

            pages = crawl_website(data.url, max_depth=data.max_depth, max_pages=data.max_pages)
            if not pages:
                return {"status": "completed", "pages": 0, "chunks": 0}

            document_id = str(uuid.uuid4())
            all_chunks = []
            for page in pages:
                chunked = chunk_text(page["text"], source=page.get("url", "website"),
                                      metadata={"url": page.get("url", ""), "title": page.get("title", "")})
                for c in chunked:
                    c["document_id"] = document_id
                all_chunks.extend(chunked)

            if all_chunks:
                create_tenant_collection(tenant.id)
                texts = [c["text"] for c in all_chunks]
                vectors = embed_texts(texts)
                metadatas = [{"source": c.get("source", "website"), "document_id": document_id, "chunk_index": c.get("chunk_index", 0)} for c in all_chunks]
                insert_vectors(tenant.id, texts, vectors, metadatas)

                add_document(
                    tenant_id=tenant.id,
                    filename=data.url,
                    original_filename=data.url,
                    file_size=0,
                    file_type="website",
                    chunk_count=len(all_chunks),
                    character_count=sum(len(c["text"]) for c in all_chunks),
                    document_id=document_id,
                )

            return {"status": "completed", "pages": len(pages), "chunks": len(all_chunks)}

    except Exception as e:
        logger.error(f"Crawl error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# ANALYTICS
# ============================================
@router.get("/admin/analytics/summary")
async def admin_analytics_summary():
    """Global analytics summary across all tenants."""
    return get_analytics_summary()


@router.get("/admin/analytics/top-queries")
async def admin_top_queries(tenant_id: str = None, limit: int = 10):
    """Get top queries across all tenants or for a specific tenant."""
    queries = get_top_queries(tenant_id=tenant_id, limit=limit)
    return {"queries": queries, "count": len(queries)}


@router.get("/admin/analytics/recent")
async def admin_recent_queries(tenant_id: str = None, limit: int = 20):
    """Get recent query logs."""
    queries = get_recent_queries(tenant_id=tenant_id, limit=limit)
    return {"queries": queries, "count": len(queries)}


@router.get("/admin/queries/{query_id}")
async def admin_get_query_detail(query_id: str):
    """Get full details of a single query."""
    detail = get_query_detail(query_id)
    if not detail:
        raise HTTPException(status_code=404, detail="Query not found")
    return detail


@router.delete("/admin/queries/{query_id}")
async def admin_delete_query(query_id: str):
    """Delete a single query log entry."""
    success = delete_query_log(query_id)
    if not success:
        raise HTTPException(status_code=404, detail="Query not found")
    return {"status": "deleted"}


@router.post("/admin/analytics/export")
async def admin_export_analytics(tenant_id: str = None):
    """Export query analytics as CSV data."""
    queries = get_recent_queries(tenant_id=tenant_id, limit=1000)
    lines = ["id,tenant_id,question,answer,chunks_found,created_at,total_time_ms"]
    for q in queries:
        answer_escaped = (q.get("answer", "") or "").replace('"', '""')
        question_escaped = (q.get("question", "") or "").replace('"', '""')
        lines.append(f'"{q["id"]}","{q["tenant_id"]}","{question_escaped}","{answer_escaped}",{q.get("chunks_found", 0)},"{q["created_at"]}",{q.get("total_time_ms", 0)}')
    csv_content = "\n".join(lines)
    return {"csv": csv_content, "count": len(queries)}


# ============================================
# UTILITY ENDPOINTS
# ============================================
@router.post("/admin/cache/clear")
async def admin_clear_cache(data: CacheClearRequest):
    """Clear the semantic cache."""
    try:
        from rag.cache import clear_cache
        clear_cache(data.tenant_id)
        return {"status": "cleared", "tenant_id": data.tenant_id}
    except ImportError:
        return {"status": "cache_module_unavailable"}


@router.get("/admin/cache/stats")
async def admin_cache_stats():
    """Get cache statistics."""
    try:
        from rag.cache import get_cache_stats
        return get_cache_stats()
    except ImportError:
        return {"total_entries": 0, "tenant_count": 0, "status": "unavailable"}


@router.get("/admin/jobs")
async def admin_job_status():
    """Get background job status."""
    try:
        from rag.jobs import get_job_status
        return get_job_status()
    except ImportError:
        return {"queue_size": 0, "workers_active": 0, "background_enabled": False}


# ============================================
# UNANSWERED QUESTIONS
# ============================================
@router.get("/admin/unanswered")
async def admin_list_unanswered(tenant_id: str = None, limit: int = 20):
    """List unanswered questions."""
    questions = get_unanswered_questions(tenant_id=tenant_id, limit=limit)
    count = get_unanswered_count(tenant_id=tenant_id)
    return {"questions": questions, "total": count}


# ============================================
# INGESTION STATUS
# ============================================
@router.get("/admin/tenants/{tenant_id}/documents/status")
async def admin_document_ingestion_status(tenant_id: str):
    """Get ingestion status summary for a tenant's documents."""
    tenant = get_tenant_by_id(tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
    docs = get_documents(tenant_id)
    status_counts = {"pending": 0, "processing": 0, "completed": 0, "failed": 0}
    for d in docs:
        s = d.get("ingestion_status", "pending")
        status_counts[s] = status_counts.get(s, 0) + 1
    return {
        "tenant_id": tenant_id,
        "documents": docs,
        "status_counts": status_counts,
        "total": len(docs),
    }

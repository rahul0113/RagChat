"""
FastAPI routes — tenant management, document ingestion, and chat.
"""
import json
import logging
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel

from tenants.models import get_db, Tenant
from tenants.manager import (
    create_tenant, get_tenant, list_tenants, update_tenant_theme,
    delete_tenant, get_tenant_by_id, increment_queries,
    get_top_queries, get_recent_queries, delete_query_log, get_analytics_summary,
)
from rag.pipeline import ingest_document, query_rag, query_rag_stream
from rag.vector_store import get_tenant_stats
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()
router = APIRouter()


# --- Auth dependency ---
async def get_current_tenant(request: Request) -> Tenant:
    """Extract tenant from API key header."""
    api_key = request.headers.get("X-API-Key")
    if not api_key:
        raise HTTPException(status_code=401, detail="Missing X-API-Key header")
    tenant = get_tenant(api_key=api_key)
    if not tenant:
        raise HTTPException(status_code=401, detail="Invalid or inactive API key")
    return tenant


# --- Request models ---
class ChatRequest(BaseModel):
    query: str
    top_k: int = 5
    chat_history: list[dict] = None


class TenantCreate(BaseModel):
    name: str
    slug: str
    org_name: str
    plan: str = "free"
    theme_name: str = "default"


class ThemeUpdate(BaseModel):
    theme: dict


# ============================================
# PUBLIC: Chat endpoint (used by widget)
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
# TENANT MANAGEMENT (requires API key)
# ============================================
@router.post("/admin/tenants")
async def admin_create_tenant(data: TenantCreate):
    """Create a new tenant."""
    try:
        result = create_tenant(
            name=data.name,
            slug=data.slug,
            org_name=data.org_name,
            plan=data.plan,
            theme_name=data.theme_name,
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


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
    import io
    file_obj = io.BytesIO(contents)
    try:
        result = ingest_document(tenant.id, file_obj, file.filename)
        tenant.total_documents += 1
        from tenants.models import SessionLocal
        db = SessionLocal()
        db.merge(tenant)
        db.commit()
        db.close()
        return {"status": "ingested", **result}
    except Exception as e:
        logger.error(f"Ingestion error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/admin/tenants/{tenant_id}")
async def admin_delete_tenant(tenant_id: str):
    """Delete a tenant and all their data."""
    success = delete_tenant(tenant_id)
    if not success:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return {"status": "deleted"}


# ============================================
# DOCUMENTS
# ============================================
@router.get("/admin/tenants/{tenant_id}/documents")
async def admin_list_documents(tenant_id: str):
    """List all ingested documents for a tenant (from vector store)."""
    tenant = get_tenant_by_id(tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
    stats = get_tenant_stats(tenant.id)
    return {
        "total_vectors": stats.get("total_vectors", 0),
        "tenant_id": tenant.id,
        "tenant_name": tenant.name,
    }


# ============================================
# ANALYTICS
# ============================================
@router.get("/admin/analytics/summary")
async def admin_analytics_summary():
    """Global analytics summary across all tenants."""
    summary = get_analytics_summary()
    tenants = list_tenants()
    total_docs = sum(t.get("total_documents", 0) for t in tenants)
    return {
        "total_tenants": len(tenants),
        "total_queries": summary["total_queries"],
        "this_week": summary["this_week"],
        "today": summary["today"],
        "total_documents": total_docs,
    }


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
    # Build CSV content
    lines = ["id,tenant_id,question,answer,chunks_found,created_at"]
    for q in queries:
        answer_escaped = (q.get("answer", "") or "").replace('"', '""')
        question_escaped = (q.get("question", "") or "").replace('"', '""')
        lines.append(f'"{q["id"]}","{q["tenant_id"]}","{question_escaped}","{answer_escaped}",{q.get("chunks_found", 0)},"{q["created_at"]}"')
    csv_content = "\n".join(lines)
    return {"csv": csv_content, "count": len(queries)}

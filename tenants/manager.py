"""
Tenant management operations.
"""
import secrets
import json
import logging
from tenants.models import Tenant, Document, QueryLog, UnansweredQuestion, SessionLocal, DEFAULT_THEMES
from rag.vector_store import delete_tenant_collection

logger = logging.getLogger(__name__)


def generate_api_key() -> str:
    return f"rc_{secrets.token_hex(24)}"


def create_tenant(name: str, slug: str, org_name: str, plan: str = "free",
                   theme_name: str = "default", backend_url: str = "") -> dict:
    """Create a new tenant with isolated collection."""
    db = SessionLocal()
    try:
        existing = db.query(Tenant).filter(Tenant.slug == slug).first()
        if existing:
            raise ValueError(f"Slug '{slug}' is already taken.")

        theme = DEFAULT_THEMES.get(theme_name, DEFAULT_THEMES["default"])

        tenant = Tenant(
            name=name,
            slug=slug,
            org_name=org_name,
            api_key=generate_api_key(),
            plan=plan,
            theme=json.dumps(theme),
        )
        db.add(tenant)
        db.commit()
        db.refresh(tenant)
        logger.info(f"Tenant created in DB: {tenant.id} ({tenant.slug})")

        try:
            from rag.vector_store import create_tenant_collection
            create_tenant_collection(tenant.id)
            logger.info(f"Qdrant collection created for {tenant.id}")
        except Exception as e:
            logger.warning(f"Qdrant collection create failed for {tenant.id}: {e}")

        try:
            embed_code = _embed_code(tenant, backend_url)
        except Exception as e:
            logger.warning(f"Embed code generation failed: {e}")
            embed_code = ""

        result = {
            "id": tenant.id,
            "name": tenant.name,
            "slug": tenant.slug,
            "org_name": tenant.org_name,
            "api_key": tenant.api_key,
            "plan": tenant.plan,
            "theme": theme,
            "embed_code": embed_code,
        }
        logger.info(f"Tenant response built successfully for {tenant.id}")
        return result
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"create_tenant failed: {type(e).__name__}: {e}", exc_info=True)
        raise
    finally:
        db.close()


def get_tenant(api_key: str = None, slug: str = None) -> Tenant | None:
    db = SessionLocal()
    try:
        if api_key:
            return db.query(Tenant).filter(Tenant.api_key == api_key, Tenant.is_active == True).first()
        if slug:
            return db.query(Tenant).filter(Tenant.slug == slug, Tenant.is_active == True).first()
        return None
    finally:
        db.close()


def get_tenant_by_id(tenant_id: str) -> Tenant | None:
    db = SessionLocal()
    try:
        return db.query(Tenant).filter(Tenant.id == tenant_id).first()
    finally:
        db.close()


def list_tenants() -> list[dict]:
    db = SessionLocal()
    try:
        tenants = db.query(Tenant).filter(Tenant.is_active == True).all()
        return [
            {
                "id": t.id,
                "name": t.name,
                "slug": t.slug,
                "org_name": t.org_name,
                "plan": t.plan,
                "total_queries": t.total_queries,
                "total_documents": t.total_documents,
                "created_at": t.created_at.isoformat(),
            }
            for t in tenants
        ]
    finally:
        db.close()


def update_tenant_theme(tenant_id: str, theme: dict) -> bool:
    db = SessionLocal()
    try:
        tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
        if not tenant:
            return False
        tenant.theme = json.dumps(theme)
        db.commit()
        return True
    finally:
        db.close()


def increment_queries(tenant_id: str):
    db = SessionLocal()
    try:
        tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
        if tenant:
            tenant.total_queries += 1
            db.commit()
    finally:
        db.close()


def delete_tenant(tenant_id: str) -> bool:
    db = SessionLocal()
    try:
        tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
        if not tenant:
            return False
        db.delete(tenant)
        db.commit()
        delete_tenant_collection(tenant_id)
        return True
    finally:
        db.close()


def update_document_ingestion_status(document_id: str, status: str,
                                       failure_reason: str = None) -> bool:
    """Update the ingestion status of a document. Status: pending|processing|completed|failed."""
    db = SessionLocal()
    try:
        doc = db.query(Document).filter(Document.id == document_id).first()
        if not doc:
            return False
        from datetime import datetime
        doc.ingestion_status = status
        if status == "processing":
            doc.processing_started_at = datetime.utcnow()
        elif status in ("completed", "failed"):
            doc.processing_completed_at = datetime.utcnow()
        if failure_reason:
            doc.failure_reason = failure_reason
        db.commit()
        return True
    finally:
        db.close()


def get_documents_with_status(tenant_id: str) -> list[dict]:
    """List all documents for a tenant including ingestion status."""
    db = SessionLocal()
    try:
        docs = (
            db.query(Document)
            .filter(Document.tenant_id == tenant_id, Document.status == "active")
            .order_by(Document.created_at.desc())
            .all()
        )
        return [
            {
                "id": d.id,
                "filename": d.original_filename,
                "file_type": d.file_type,
                "file_size": d.file_size,
                "chunk_count": d.chunk_count,
                "character_count": d.character_count,
                "ingestion_status": d.ingestion_status,
                "failure_reason": d.failure_reason,
                "created_at": d.created_at.isoformat(),
            }
            for d in docs
        ]
    finally:
        db.close()


def replace_document(tenant_id: str, original_filename: str, new_doc_id: str) -> str | None:
    """Find existing active document with same filename and soft-delete it. Returns old doc_id."""
    db = SessionLocal()
    try:
        existing = db.query(Document).filter(
            Document.tenant_id == tenant_id,
            Document.original_filename == original_filename,
            Document.status == "active",
        ).first()
        if not existing:
            return None
        old_id = existing.id
        existing.status = "replaced"
        db.commit()
        logger.info(f"Document replaced: {old_id} ({original_filename}) for tenant {tenant_id}")
        return old_id
    finally:
        db.close()


def log_unanswered_question(tenant_id: str, question: str, fallback_reason: str,
                             source_chunks_found: int = 0, top_score: float = 0.0):
    """Log a question the system couldn't answer."""
    db = SessionLocal()
    try:
        entry = UnansweredQuestion(
            tenant_id=tenant_id,
            question=question,
            fallback_reason=fallback_reason,
            source_chunks_found=source_chunks_found,
            top_score=top_score,
        )
        db.add(entry)
        db.commit()
    finally:
        db.close()


def get_unanswered_questions(tenant_id: str = None, limit: int = 20) -> list[dict]:
    """Get unanswered questions, optionally filtered by tenant."""
    db = SessionLocal()
    try:
        from sqlalchemy import func
        query = db.query(UnansweredQuestion)
        if tenant_id:
            query = query.filter(UnansweredQuestion.tenant_id == tenant_id)
        entries = query.order_by(UnansweredQuestion.created_at.desc()).limit(limit).all()
        return [
            {
                "id": e.id,
                "tenant_id": e.tenant_id,
                "question": e.question,
                "fallback_reason": e.fallback_reason,
                "source_chunks_found": e.source_chunks_found,
                "top_score": e.top_score,
                "created_at": e.created_at.isoformat(),
            }
            for e in entries
        ]
    finally:
        db.close()


def get_unanswered_count(tenant_id: str = None) -> int:
    """Count unanswered questions."""
    db = SessionLocal()
    try:
        from sqlalchemy import func
        query = db.query(func.count(UnansweredQuestion.id))
        if tenant_id:
            query = query.filter(UnansweredQuestion.tenant_id == tenant_id)
        return query.scalar() or 0
    finally:
        db.close()


# --- Document Management ---
def add_document(tenant_id: str, filename: str, original_filename: str,
                  file_size: int, file_type: str, chunk_count: int,
                  character_count: int, document_id: str,
                  ingestion_status: str = "pending") -> Document:
    """Add a document record to the database."""
    db = SessionLocal()
    try:
        doc = Document(
            id=document_id,
            tenant_id=tenant_id,
            filename=filename,
            original_filename=original_filename,
            file_size=file_size,
            file_type=file_type,
            chunk_count=chunk_count,
            character_count=character_count,
            ingestion_status=ingestion_status,
        )
        db.add(doc)

        # Update tenant document count
        tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
        if tenant:
            tenant.total_documents += 1

        db.commit()
        db.refresh(doc)
        logger.info(f"Document added: {doc.id} ({filename}) for tenant {tenant_id}")
        return doc
    finally:
        db.close()


def get_documents(tenant_id: str) -> list[dict]:
    """List all documents for a tenant including ingestion status."""
    return get_documents_with_status(tenant_id)


def get_document_by_id(document_id: str) -> Document | None:
    """Get a document by ID."""
    db = SessionLocal()
    try:
        return db.query(Document).filter(Document.id == document_id).first()
    finally:
        db.close()


def delete_document(tenant_id: str, document_id: str) -> bool:
    """Soft-delete a document record and remove its vectors."""
    db = SessionLocal()
    try:
        doc = db.query(Document).filter(
            Document.id == document_id,
            Document.tenant_id == tenant_id,
        ).first()
        if not doc:
            return False

        # Soft delete in DB
        doc.status = "deleted"
        db.commit()

        # Update tenant document count
        tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
        if tenant and tenant.total_documents > 0:
            tenant.total_documents -= 1
            db.commit()

        # Delete vectors from Qdrant
        try:
            from rag.vector_store import delete_document_vectors
            deleted_count = delete_document_vectors(tenant_id, document_id)
            logger.info(f"Deleted {deleted_count} vectors for document {document_id}")
        except Exception as e:
            logger.warning(f"Failed to delete vectors for document {document_id}: {e}")

        logger.info(f"Document deleted: {document_id} from tenant {tenant_id}")
        return True
    finally:
        db.close()


# --- Query Logs ---
def log_query(tenant_id: str, question: str, answer: str, sources: list,
              chunks_found: int, retrieval_time_ms: int = 0,
              embedding_time_ms: int = 0, llm_time_ms: int = 0,
              total_time_ms: int = 0, cache_hit: bool = False):
    db = SessionLocal()
    try:
        log = QueryLog(
            tenant_id=tenant_id,
            question=question,
            answer=answer,
            sources=json.dumps(sources),
            chunks_found=chunks_found,
            retrieval_time_ms=retrieval_time_ms,
            embedding_time_ms=embedding_time_ms,
            llm_time_ms=llm_time_ms,
            total_time_ms=total_time_ms,
            cache_hit=cache_hit,
        )
        db.add(log)
        db.commit()
        # Update tenant query count
        tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
        if tenant:
            tenant.total_queries += 1
            db.commit()
    finally:
        db.close()


def get_top_queries(tenant_id: str = None, limit: int = 10) -> list[dict]:
    db = SessionLocal()
    try:
        query = db.query(QueryLog)
        if tenant_id:
            query = query.filter(QueryLog.tenant_id == tenant_id)
        from sqlalchemy import func
        results = (
            db.query(
                QueryLog.question,
                func.count(QueryLog.id).label("uses"),
                func.max(QueryLog.created_at).label("last_asked"),
            )
            .group_by(QueryLog.question)
            .order_by(func.count(QueryLog.id).desc())
            .limit(limit)
            .all()
        )
        return [
            {
                "question": r.question,
                "uses": r.uses,
                "last_asked": r.last_asked.isoformat() if r.last_asked else None,
            }
            for r in results
        ]
    finally:
        db.close()


def get_recent_queries(tenant_id: str = None, limit: int = 20) -> list[dict]:
    db = SessionLocal()
    try:
        query = db.query(QueryLog).order_by(QueryLog.created_at.desc())
        if tenant_id:
            query = query.filter(QueryLog.tenant_id == tenant_id)
        logs = query.limit(limit).all()
        return [
            {
                "id": q.id,
                "tenant_id": q.tenant_id,
                "question": q.question,
                "answer": q.answer[:200] if q.answer else "",
                "chunks_found": q.chunks_found,
                "created_at": q.created_at.isoformat(),
                "total_time_ms": q.total_time_ms,
                "cache_hit": q.cache_hit,
            }
            for q in logs
        ]
    finally:
        db.close()


def get_query_detail(query_id: str) -> dict | None:
    """Get full details of a single query log entry."""
    db = SessionLocal()
    try:
        q = db.query(QueryLog).filter(QueryLog.id == query_id).first()
        if not q:
            return None
        return {
            "id": q.id,
            "tenant_id": q.tenant_id,
            "question": q.question,
            "answer": q.answer,
            "sources": json.loads(q.sources) if q.sources else [],
            "chunks_found": q.chunks_found,
            "created_at": q.created_at.isoformat(),
            "retrieval_time_ms": q.retrieval_time_ms,
            "embedding_time_ms": q.embedding_time_ms,
            "llm_time_ms": q.llm_time_ms,
            "total_time_ms": q.total_time_ms,
            "cache_hit": q.cache_hit,
        }
    finally:
        db.close()


def delete_query_log(query_id: str) -> bool:
    db = SessionLocal()
    try:
        log = db.query(QueryLog).filter(QueryLog.id == query_id).first()
        if not log:
            return False
        db.delete(log)
        db.commit()
        return True
    finally:
        db.close()


def get_analytics_summary() -> dict:
    db = SessionLocal()
    try:
        from sqlalchemy import func
        from datetime import datetime, timedelta

        total_queries = db.query(func.count(QueryLog.id)).scalar() or 0
        total_tenants = db.query(func.count(Tenant.id)).filter(Tenant.is_active == True).scalar() or 0
        total_documents = db.query(func.count(Document.id)).filter(Document.status == "active").scalar() or 0

        week_ago = datetime.utcnow() - timedelta(days=7)
        today = datetime.utcnow().date()
        this_week = db.query(func.count(QueryLog.id)).filter(QueryLog.created_at >= week_ago).scalar() or 0
        this_day = db.query(func.count(QueryLog.id)).filter(func.date(QueryLog.created_at) == today).scalar() or 0

        # Performance analytics
        avg_total_ms = db.query(func.avg(QueryLog.total_time_ms)).scalar() or 0
        avg_llm_ms = db.query(func.avg(QueryLog.llm_time_ms)).scalar() or 0
        avg_retrieval_ms = db.query(func.avg(QueryLog.retrieval_time_ms)).scalar() or 0
        avg_embedding_ms = db.query(func.avg(QueryLog.embedding_time_ms)).scalar() or 0
        cache_hits = db.query(func.count(QueryLog.id)).filter(QueryLog.cache_hit == True).scalar() or 0

        # Unanswered questions
        total_unanswered = db.query(func.count(UnansweredQuestion.id)).scalar() or 0

        # Top documents by query frequency
        from sqlalchemy import text
        top_docs = db.execute(text("""
            SELECT sources, COUNT(*) as count
            FROM query_logs
            GROUP BY sources
            ORDER BY count DESC
            LIMIT 5
        """)).fetchall()

        # Recent top queries
        top_queries = (
            db.query(
                QueryLog.question,
                func.count(QueryLog.id).label("uses"),
            )
            .group_by(QueryLog.question)
            .order_by(func.count(QueryLog.id).desc())
            .limit(10)
            .all()
        )

        return {
            "total_queries": total_queries,
            "total_tenants": total_tenants,
            "total_documents": total_documents,
            "this_week": this_week,
            "today": this_day,
            "avg_response_time_ms": round(avg_total_ms),
            "avg_llm_time_ms": round(avg_llm_ms),
            "avg_retrieval_time_ms": round(avg_retrieval_ms),
            "avg_embedding_time_ms": round(avg_embedding_ms),
            "cache_hit_rate": round(cache_hits / max(total_queries, 1) * 100, 1),
            "total_unanswered": total_unanswered,
            "unanswered_rate": round(total_unanswered / max(total_queries, 1) * 100, 1),
            "top_queries": [
                {"question": q.question, "uses": q.uses} for q in top_queries
            ],
        }
    finally:
        db.close()


def _embed_code(tenant: Tenant, backend_url: str = "") -> str:
    """Generate the embed code for a client to paste on their website."""
    if not backend_url:
        from config import get_settings
        settings = get_settings()
        backend_url = settings.BACKEND_URL or ""
    return f"""<!-- RagChat Widget - {tenant.name} -->
<script src="{backend_url}/widget/static/widget.js"
  data-tenant-id="{tenant.id}"
  data-tenant-slug="{tenant.slug}"></script>"""

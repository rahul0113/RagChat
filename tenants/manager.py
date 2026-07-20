"""
Tenant management operations.
"""
import secrets
import json
from tenants.models import Tenant, QueryLog, SessionLocal, DEFAULT_THEMES
from rag.vector_store import create_tenant_collection, delete_tenant_collection, get_tenant_stats


def generate_api_key() -> str:
    return f"rc_{secrets.token_hex(24)}"


def create_tenant(name: str, slug: str, org_name: str, plan: str = "free",
                   theme_name: str = "default") -> dict:
    """Create a new tenant with isolated collection."""
    db = SessionLocal()
    try:
        # Check slug uniqueness
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

        # Create Qdrant collection
        create_tenant_collection(tenant.id)

        return {
            "id": tenant.id,
            "name": tenant.name,
            "slug": tenant.slug,
            "org_name": tenant.org_name,
            "api_key": tenant.api_key,
            "plan": tenant.plan,
            "theme": theme,
            "embed_code": _embed_code(tenant),
        }
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


# --- Query Logs ---
def log_query(tenant_id: str, question: str, answer: str, sources: list, chunks_found: int):
    db = SessionLocal()
    try:
        log = QueryLog(
            tenant_id=tenant_id,
            question=question,
            answer=answer,
            sources=json.dumps(sources),
            chunks_found=chunks_found,
        )
        db.add(log)
        db.commit()
    finally:
        db.close()


def get_top_queries(tenant_id: str = None, limit: int = 10) -> list[dict]:
    db = SessionLocal()
    try:
        query = db.query(QueryLog)
        if tenant_id:
            query = query.filter(QueryLog.tenant_id == tenant_id)
        # Group by question, count occurrences
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
            }
            for q in logs
        ]
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
        total = db.query(func.count(QueryLog.id)).scalar() or 0
        from datetime import datetime, timedelta
        week_ago = datetime.utcnow() - timedelta(days=7)
        today = datetime.utcnow().date()
        this_week = db.query(func.count(QueryLog.id)).filter(QueryLog.created_at >= week_ago).scalar() or 0
        this_day = db.query(func.count(QueryLog.id)).filter(func.date(QueryLog.created_at) == today).scalar() or 0
        return {
            "total_queries": total,
            "this_week": this_week,
            "today": this_day,
        }
    finally:
        db.close()


def _embed_code(tenant: Tenant) -> str:
    """Generate the embed code for a client to paste on their website."""
    from config import get_settings
    settings = get_settings()
    backend_url = settings.BACKEND_URL or ""
    return f"""<!-- RagChat Widget - {tenant.name} -->
<script src="{backend_url}/widget/static/widget.js"
  data-tenant-id="{tenant.id}"
  data-tenant-slug="{tenant.slug}"></script>"""

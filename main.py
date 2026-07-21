"""
RagChat — White-label RAG SaaS Platform
Main FastAPI application entry point.
"""
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from pathlib import Path

from config import get_settings
from tenants.models import init_db
from api.routes import router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)
settings = get_settings()


def create_app() -> FastAPI:
    app = FastAPI(
        title="RagChat",
        description="White-label RAG SaaS — AI chat for any organization",
        version=settings.APP_VERSION,
    )

    # CORS — allow all origins for widget embedding
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Rate limiting middleware
    app.add_middleware(
        RateLimitMiddleware,
        default_limit=100,  # 100 req/min for general endpoints
        admin_limit=30,     # 30 req/min for admin endpoints
        chat_limit=60,      # 60 req/min for chat endpoints
    )

    # Routes
    app.include_router(router, prefix="/api")

    # Serve widget static files
    widget_dir = Path(__file__).parent / "widget" / "static"
    if widget_dir.exists():
        app.mount("/widget/static", StaticFiles(directory=str(widget_dir)), name="widget")

    @app.on_event("startup")
    def startup():
        logger.info("Initializing database...")
        init_db()

        # Run schema migrations
        try:
            from migrate import run_migrations
            run_migrations()
        except Exception as e:
            logger.warning(f"Migration failed: {e}")

        # Start background workers
        try:
            from rag.jobs import start_workers
            start_workers()
        except Exception as e:
            logger.warning(f"Background workers failed to start: {e}")

        # Setup structured logging
        try:
            from rag.monitoring import setup_structured_logging
            setup_structured_logging()
        except Exception:
            pass

        logger.info(f"RagChat v{settings.APP_VERSION} is ready.")

    @app.on_event("shutdown")
    def shutdown():
        try:
            from rag.jobs import stop_workers
            stop_workers()
        except Exception:
            pass
        logger.info("RagChat shutting down.")

    # Health check endpoint
    @app.get("/api/health")
    def health():
        try:
            from rag.monitoring import get_health_check
            return get_health_check()
        except Exception:
            # Basic health check
            status = {"status": "healthy", "version": settings.APP_VERSION, "checks": {}}
            try:
                from tenants.models import get_tenant_count
                tenant_count = get_tenant_count()
                status["checks"]["database"] = "ok"
                status["checks"]["tenant_count"] = tenant_count
            except Exception as e:
                status["checks"]["database"] = f"error: {e}"
            try:
                from rag.vector_store import get_client
                client = get_client()
                collections = client.get_collections()
                status["checks"]["qdrant"] = "ok"
                status["checks"]["collections"] = len(collections.collections)
            except Exception as e:
                status["checks"]["qdrant"] = f"error: {e}"
            return status

    @app.get("/", response_class=HTMLResponse)
    def root():
        return """
        <html>
        <head><title>RagChat</title></head>
        <body style="font-family: sans-serif; padding: 40px; background: #0f172a; color: #e2e8f0;">
            <h1>RagChat</h1>
            <p>White-label RAG SaaS Platform</p>
            <h3>Endpoints:</h3>
            <ul>
                <li><code>POST /api/chat/{slug}</code> — Chat with a tenant's knowledge base</li>
                <li><code>POST /api/chat/{slug}/stream</code> — Streaming chat</li>
                <li><code>GET /api/widget/{slug}/config</code> — Widget configuration</li>
                <li><code>POST /api/admin/tenants</code> — Create tenant</li>
                <li><code>GET /api/admin/tenants</code> — List tenants</li>
                <li><code>POST /api/admin/tenants/{id}/upload</code> — Upload documents</li>
                <li><code>DELETE /api/admin/tenants/{id}/documents/{doc_id}</code> — Delete document</li>
                <li><code>POST /api/admin/tenants/{id}/crawl</code> — Crawl website</li>
                <li><code>GET /api/admin/analytics/summary</code> — Analytics</li>
                <li><code>GET /api/health</code> — Health check</li>
                <li><code>GET /docs</code> — API documentation</li>
            </ul>
        </body>
        </html>
        """

    return app


app = create_app()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)

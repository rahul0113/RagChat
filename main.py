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
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)
settings = get_settings()


def create_app() -> FastAPI:
    app = FastAPI(
        title="RagChat",
        description="White-label RAG SaaS — AI chat for any organization",
        version=settings.APP_VERSION,
    )

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Routes
    app.include_router(router, prefix="/api")

    # Serve widget static files
    widget_dir = Path(__file__).parent / "widget" / "static"
    app.mount("/widget/static", StaticFiles(directory=str(widget_dir)), name="widget")

    @app.on_event("startup")
    def startup():
        logger.info("Initializing database...")
        init_db()
        logger.info("RagChat is ready.")

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
                <li><code>GET /api/widget/{slug}/config</code> — Widget configuration</li>
                <li><code>POST /api/admin/tenants</code> — Create tenant</li>
                <li><code>GET /api/admin/tenants</code> — List tenants</li>
                <li><code>POST /api/admin/tenants/{id}/upload</code> — Upload documents</li>
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

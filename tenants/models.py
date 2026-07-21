"""
Tenant data models and database.
Each client is a separate tenant with isolated data.
"""
import uuid
import json
from datetime import datetime
from sqlalchemy import create_engine, Column, String, DateTime, Text, Boolean, Integer, Float, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from config import get_settings

settings = get_settings()

# PostgreSQL pool settings, SQLite uses defaults
engine_kwargs = {
    "connect_args": settings.db_connect_args,
}
if settings.is_postgresql:
    engine_kwargs["pool_size"] = 10
    engine_kwargs["max_overflow"] = 20
    engine_kwargs["pool_pre_ping"] = True  # Verify connections before use

engine = create_engine(settings.DATABASE_URL, **engine_kwargs)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Tenant(Base):
    __tablename__ = "tenants"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)                  # Display name
    slug = Column(String, unique=True, nullable=False)     # URL-safe identifier
    org_name = Column(String, nullable=False)              # Organization name shown to users
    api_key = Column(String, unique=True, nullable=False)  # Tenant API key for auth
    plan = Column(String, default="free")                  # free | pro | enterprise
    is_active = Column(Boolean, default=True)

    # Widget theme (JSON)
    theme = Column(Text, default="{}")

    # Usage tracking
    total_queries = Column(Integer, default=0)
    total_documents = Column(Integer, default=0)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Document(Base):
    __tablename__ = "documents"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    tenant_id = Column(String, ForeignKey("tenants.id"), nullable=False, index=True)
    filename = Column(String, nullable=False)
    original_filename = Column(String, nullable=False)
    file_size = Column(Integer, default=0)  # bytes
    file_type = Column(String, nullable=False)  # extension
    chunk_count = Column(Integer, default=0)
    character_count = Column(Integer, default=0)
    status = Column(String, default="active")  # active | deleted
    ingestion_status = Column(String, default="pending")  # pending | processing | completed | failed
    failure_reason = Column(Text, nullable=True)
    processing_started_at = Column(DateTime, nullable=True)
    processing_completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class UnansweredQuestion(Base):
    __tablename__ = "unanswered_questions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    tenant_id = Column(String, index=True, nullable=False)
    question = Column(Text, nullable=False)
    fallback_reason = Column(String, nullable=False)  # insufficient_context | no_results | low_confidence
    source_chunks_found = Column(Integer, default=0)
    top_score = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)


class QueryLog(Base):
    __tablename__ = "query_logs"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    tenant_id = Column(String, nullable=False, index=True)
    question = Column(Text, nullable=False)
    answer = Column(Text, nullable=True)
    sources = Column(Text, default="[]")  # JSON array
    chunks_found = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    # Performance timing (milliseconds)
    retrieval_time_ms = Column(Integer, default=0)
    embedding_time_ms = Column(Integer, default=0)
    llm_time_ms = Column(Integer, default=0)
    total_time_ms = Column(Integer, default=0)
    cache_hit = Column(Boolean, default=False)


def init_db():
    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# --- Default widget themes ---

DEFAULT_THEMES = {
    "default": {
        "primary_color": "#6366f1",
        "background_color": "rgba(255, 255, 255, 0.7)",
        "text_color": "#1e293b",
        "border_color": "rgba(99, 102, 241, 0.3)",
        "blur_amount": "20px",
        "font_family": "'Inter', 'Segoe UI', sans-serif",
        "border_radius": "16px",
        "header_gradient": "linear-gradient(135deg, #6366f1, #8b5cf6)",
        "bot_bubble_bg": "rgba(99, 102, 241, 0.1)",
        "user_bubble_bg": "rgba(99, 102, 241, 0.85)",
        "position": "bottom-right",
    },
    "dark": {
        "primary_color": "#818cf8",
        "background_color": "rgba(15, 23, 42, 0.85)",
        "text_color": "#e2e8f0",
        "border_color": "rgba(129, 140, 248, 0.3)",
        "blur_amount": "20px",
        "font_family": "'Inter', 'Segoe UI', sans-serif",
        "border_radius": "16px",
        "header_gradient": "linear-gradient(135deg, #1e1b4b, #312e81)",
        "bot_bubble_bg": "rgba(129, 140, 248, 0.1)",
        "user_bubble_bg": "rgba(129, 140, 248, 0.85)",
        "position": "bottom-right",
    },
}

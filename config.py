"""
Configuration management for the RAG SaaS platform.
All settings loaded from environment variables with sensible defaults.
"""
import os
from pathlib import Path
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # --- App ---
    APP_NAME: str = "RagChat"
    APP_VERSION: str = "2.0.0"
    DEBUG: bool = False
    HOST: str = "0.0.0.0"
    PORT: int = int(os.environ.get("PORT", "8000"))

    # --- Groq LLM ---
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama3-70b-8192"
    GROQ_TEMPERATURE: float = 0.3
    GROQ_MAX_TOKENS: int = 2048

    # --- Embeddings (local, no API needed) ---
    EMBEDDING_MODEL: str = "BAAI/bge-large-en-v1.5"
    EMBEDDING_DIMENSION: int = 1024
    EMBEDDING_BATCH_SIZE: int = 32

    # --- Qdrant Vector DB ---
    QDRANT_HOST: str = "localhost"
    QDRANT_PORT: int = 6333
    QDRANT_API_KEY: str = ""  # empty = local instance
    QDRANT_COLLECTION_PREFIX: str = "tenant_"

    # --- Database (SQLite for simplicity, swap to Postgres for scale) ---
    DATABASE_URL: str = "sqlite:///./ragchat.db"

    # --- Document Ingestion ---
    UPLOAD_DIR: Path = Path("./uploads")
    MAX_FILE_SIZE_MB: int = 50
    CHUNK_SIZE: int = 1024  # Increased to match BGE-large capacity (512 tokens ≈ 2048 chars)
    CHUNK_OVERLAP: int = 100  # 10% of chunk size for better context continuity
    SUPPORTED_FORMATS: list[str] = ["pdf", "docx", "doc", "txt", "html", "htm", "csv", "md", "json"]
    MAX_CONTEXT_TOKENS: int = 6000  # Leave room for system prompt + response
    EMBEDDING_CACHE_ENABLED: bool = True  # Cache embeddings for deduplication

    # --- Tenant ---
    DEFAULT_TENANT_PLAN: str = "free"  # free | pro | enterprise

    # --- CORS ---
    CORS_ORIGINS: list[str] = ["*"]

    # --- Backend URL (for widget embed code generation) ---
    BACKEND_URL: str = ""  # Set to your deployed URL, e.g. https://ragchat-app.onrender.com

    # --- Hybrid Search ---
    HYBRID_SEARCH_ENABLED: bool = True
    HYBRID_ALPHA: float = 0.7  # 1.0 = pure vector, 0.0 = pure keyword
    BM25_K1: float = 1.5
    BM25_B: float = 0.75

    # --- Reranking ---
    RERANKING_ENABLED: bool = True
    RERANKER_MODEL: str = "cross-encoder/ms-marco-MiniLM-L-6-v2"
    RERANK_TOP_K: int = 20  # retrieve this many before reranking
    RERANK_FINAL_K: int = 5  # return this many after reranking

    # --- Query Rewriting ---
    QUERY_REWRITING_ENABLED: bool = True

    # --- Semantic Cache ---
    SEMANTIC_CACHE_ENABLED: bool = True
    SEMANTIC_CACHE_THRESHOLD: float = 0.92  # cosine similarity threshold
    SEMANTIC_CACHE_TTL: int = 3600  # seconds
    SEMANTIC_CACHE_PERSIST: bool = True  # persist to disk
    SEMANTIC_CACHE_DIR: str = "./cache"  # directory for cache files

    # --- OCR ---
    OCR_ENABLED: bool = True
    OCR_ENGINE: str = "tesseract"  # tesseract | easyocr

    # --- Web Crawler ---
    CRAWL_MAX_DEPTH: int = 3
    CRAWL_MAX_PAGES: int = 100
    CRAWL_DELAY: float = 0.5  # seconds between requests
    CRAWL_TIMEOUT: int = 30  # seconds per request

    # --- Background Jobs ---
    BACKGROUND_JOBS_ENABLED: bool = True
    MAX_WORKERS: int = 2

    # --- Monitoring ---
    LOG_LEVEL: str = "INFO"
    STRUCTURED_LOGGING: bool = True

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()

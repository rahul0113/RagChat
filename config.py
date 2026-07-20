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
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    HOST: str = "0.0.0.0"
    PORT: int = 8000

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
    CHUNK_SIZE: int = 512
    CHUNK_OVERLAP: int = 64
    SUPPORTED_FORMATS: list[str] = ["pdf", "docx", "doc", "txt", "html", "htm", "csv", "md", "json"]

    # --- Tenant ---
    DEFAULT_TENANT_PLAN: str = "free"  # free | pro | enterprise

    # --- CORS ---
    CORS_ORIGINS: list[str] = ["*"]

    # --- Backend URL (for widget embed code generation) ---
    BACKEND_URL: str = ""  # Set to your deployed URL, e.g. https://ragchat-app.onrender.com

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()

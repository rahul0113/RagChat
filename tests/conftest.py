"""
Pytest conftest — mock heavy dependencies before any rag modules are imported.
"""
import sys
from unittest.mock import MagicMock

# Mock heavy dependencies that aren't available in test env
for mod in [
    "pydantic", "pydantic_settings",
    "pypdf", "pypdf.errors",
    "langdetect",
    "rank_bm25",
    "numpy",
    "qdrant_client", "qdrant_client.models",
    "groq",
    "fastapi", "fastapi.middleware", "fastapi.middleware.cors",
    "fastapi.staticfiles", "fastapi.responses",
    "httpx",
    "structlog",
    "requests",
]:
    sys.modules[mod] = MagicMock()

# Provide a real Settings class with real defaults
class FakeSettings:
    APP_NAME: str = "RagChat"
    APP_VERSION: str = "0.2.0"
    SQLALCHEMY_DATABASE_URI: str = "sqlite:///./test.db"
    DATABASE_URL: str = "sqlite:///./test.db"
    OPENAI_API_KEY: str = "test-key"
    OPENAI_BASE_URL: str = "http://localhost:11434/v1"
    EMBEDDING_MODEL: str = "nomic-embed-text:latest"
    EMBEDDING_DIMENSIONS: int = 768
    LLM_MODEL: str = "gemma3:1b"
    QDRANT_URL: str = "http://localhost:6333"
    QDRANT_API_KEY: str = ""
    CHUNK_SIZE: int = 512
    CHUNK_OVERLAP: int = 64
    RETRIEVAL_TOP_K: int = 5
    MAX_FILE_SIZE_MB: int = 50
    ALLOWED_FILE_TYPES: str = ".pdf,.txt,.md,.csv,.docx,.html"
    BACKGROUND_JOBS_ENABLED: bool = False
    MAX_WORKERS: int = 2
    CACHE_ENABLED: bool = False
    RATE_LIMIT_ENABLED: bool = False
    MAX_QUERIES_PER_DAY: int = 1000
    MAX_STORAGE_MB: int = 5000
    QDRANT_COLLECTION_PREFIX: str = "tenant_"
    RERANKING_ENABLED: bool = True
    RERANKER_MODEL: str = "cross-encoder/ms-marco-MiniLM-L-6-v2"
    RERANK_TOP_K: int = 20
    RERANK_FINAL_K: int = 5
    HYBRID_SEARCH_ENABLED: bool = False
    SEMANTIC_CACHE_ENABLED: bool = True
    SEMANTIC_CACHE_THRESHOLD: float = 0.92
    SEMANTIC_CACHE_TTL: int = 3600
    SEMANTIC_CACHE_PERSIST: bool = True
    SEMANTIC_CACHE_DIR: str = "./cache"
    OCR_ENGINE: str = "pytesseract"
    CRAWL_MAX_DEPTH: int = 3
    CRAWL_MAX_PAGES: int = 100
    CRAWL_DELAY: float = 0.5
    CRAWL_TIMEOUT: int = 30

    class Config:
        env_file = ".env"

_fake_settings = FakeSettings()

def _mock_get_settings():
    return _fake_settings

# Replace get_settings in config module BEFORE rag imports
# We need to monkey-patch config.get_settings
import importlib
# Pre-populate config module with fake settings
_fake_config = MagicMock()
_fake_config.get_settings = _mock_get_settings
_fake_config._settings = _fake_settings
sys.modules["config"] = _fake_config

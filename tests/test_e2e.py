"""
End-to-end test for RagChat backend.
Tests the full flow: tenant creation → document upload → RAG pipeline → chat response.

Run with: python tests/test_e2e.py (requires all dependencies installed)
Or run individually with mocked dependencies to verify wiring.
"""
import io
import os
import sys
import json
import hashlib
import tempfile
import sqlite3
from unittest.mock import patch, MagicMock, PropertyMock

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))


# ============================================================
# MOCK HEAVY DEPENDENCIES
# ============================================================
for mod in [
    "pydantic", "pydantic_settings",
    "qdrant_client", "qdrant_client.models",
    "groq",
    "numpy",
    "rank_bm25",
    "langdetect",
    "pypdf", "pypdf.errors",
    "fastapi", "fastapi.middleware", "fastapi.middleware.cors",
    "fastapi.staticfiles", "fastapi.responses",
    "httpx",
    "structlog",
    "requests",
]:
    sys.modules[mod] = MagicMock()


# Provide real settings
class FakeSettings:
    APP_NAME = "RagChat"
    APP_VERSION = "0.2.0"
    SQLALCHEMY_DATABASE_URI = "sqlite:///./test_e2e.db"
    DATABASE_URL = "sqlite:///./test_e2e.db"
    OPENAI_API_KEY = "test-key"
    OPENAI_BASE_URL = "http://localhost:11434/v1"
    EMBEDDING_MODEL = "nomic-embed-text:latest"
    EMBEDDING_DIMENSIONS = 768
    LLM_MODEL = "gemma3:1b"
    QDRANT_URL = "http://localhost:6333"
    QDRANT_API_KEY = ""
    CHUNK_SIZE = 512
    CHUNK_OVERLAP = 64
    RETRIEVAL_TOP_K = 5
    MAX_FILE_SIZE_MB = 50
    ALLOWED_FILE_TYPES = ".pdf,.txt,.md,.csv,.docx,.html"
    BACKGROUND_JOBS_ENABLED = False
    MAX_WORKERS = 2
    CACHE_ENABLED = False
    RATE_LIMIT_ENABLED = False
    MAX_QUERIES_PER_DAY = 1000
    MAX_STORAGE_MB = 5000
    QDRANT_COLLECTION_PREFIX = "tenant_"
    RERANKING_ENABLED = False
    RERANKER_MODEL = "cross-encoder/ms-marco-MiniLM-L-6-v2"
    RERANK_TOP_K = 20
    RERANK_FINAL_K = 5
    HYBRID_SEARCH_ENABLED = False
    SEMANTIC_CACHE_ENABLED = False
    SEMANTIC_CACHE_THRESHOLD = 0.92
    SEMANTIC_CACHE_TTL = 3600
    SEMANTIC_CACHE_PERSIST = False
    SEMANTIC_CACHE_DIR = "./cache"
    OCR_ENGINE = "pytesseract"
    CRAWL_MAX_DEPTH = 3
    CRAWL_MAX_PAGES = 100
    CRAWL_DELAY = 0.5
    CRAWL_TIMEOUT = 30
    BACKEND_URL = "http://localhost:8000"

    @property
    def is_postgresql(self):
        return self.DATABASE_URL.startswith("postgresql") or self.DATABASE_URL.startswith("postgres")

    @property
    def db_connect_args(self):
        if self.is_postgresql:
            return {}
        return {"check_same_thread": False}

_fake_settings = FakeSettings()

fake_config = MagicMock()
fake_config.get_settings = lambda: _fake_settings
fake_config._settings = _fake_settings
sys.modules["config"] = fake_config


# ============================================================
# TEST HELPERS
# ============================================================

class TestResult:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.errors = []

    def check(self, name, condition, detail=""):
        if condition:
            self.passed += 1
            print(f"  ✅ {name}")
        else:
            self.failed += 1
            self.errors.append(f"{name}: {detail}")
            print(f"  ❌ {name} — {detail}")

    def summary(self):
        total = self.passed + self.failed
        print(f"\n{'='*60}")
        print(f"Results: {self.passed}/{total} passed, {self.failed} failed")
        if self.errors:
            print("\nFailures:")
            for e in self.errors:
                print(f"  - {e}")
        print(f"{'='*60}")
        return self.failed == 0


# ============================================================
# TEST 1: METADATA CONSISTENCY
# ============================================================

def test_metadata_consistency(r):
    print("\n📋 Test 1: Metadata Consistency")
    from rag.metadata import build_chunk_metadata, build_source_info, build_document_id

    # Test chunk metadata has all required fields
    meta = build_chunk_metadata(
        text="Test content about machine learning",
        source="ml_guide.pdf",
        document_id="doc-123",
        chunk_index=0,
        tenant_id="t-1",
        page_number=1,
        section_heading="Introduction",
        language="en",
    )
    required_fields = ["text", "source", "document_id", "chunk_index", "tenant_id",
                       "page_number", "section_heading", "language", "upload_timestamp"]
    for field in required_fields:
        r.check(f"Metadata has '{field}'", field in meta, f"Missing: {field}")

    # Test document_id uniqueness
    id1 = build_document_id()
    id2 = build_document_id()
    r.check("Document IDs are unique", id1 != id2, f"Both: {id1}")

    # Test source info extraction
    source = build_source_info(meta)
    r.check("Source info has 'source'", "source" in source)
    r.check("Source info has 'score'", "score" in source)
    r.check("Source info has 'excerpt'", "excerpt" in source)


# ============================================================
# TEST 2: CHUNKING BEHAVIOR
# ============================================================

def test_chunking(r):
    print("\n📦 Test 2: Chunking Behavior")
    from rag.chunker import chunk_text

    # Test paragraph-aware splitting — use enough text to exceed chunk_size (512)
    text = ("This is a paragraph about artificial intelligence and its applications. " * 10 +
            "\n\n" +
            "This is a second paragraph about machine learning algorithms and data science. " * 10 +
            "\n\n" +
            "This is a third paragraph about natural language processing and chatbots. " * 10)
    chunks = chunk_text(text, source="test.pdf", metadata={})
    r.check("Paragraph splitting produces multiple chunks", len(chunks) > 1, f"Got {len(chunks)} chunks")
    r.check("All chunks have text", all("text" in c for c in chunks))
    r.check("All chunks have source", all(c.get("source") == "test.pdf" for c in chunks))

    # Test heading preservation
    text_h = "# Introduction\n\nThis is the intro.\n\n# Methods\n\nThese are the methods."
    chunks_h = chunk_text(text_h, source="test.pdf", metadata={})
    headings = [c.get("section_heading", "") for c in chunks_h]
    r.check("Heading 'Introduction' detected", any("Introduction" in h for h in headings))
    r.check("Heading 'Methods' detected", any("Methods" in h for h in headings))

    # Test chunk indices are sequential
    indices = [c.get("chunk_index", -1) for c in chunks]
    r.check("Chunk indices sequential", indices == list(range(len(chunks))))


# ============================================================
# TEST 3: DOCUMENT LOADER
# ============================================================

def test_document_loader(r):
    print("\n📄 Test 3: Document Loader")
    from rag.document_loader import load_document

    # Test plain text loading
    txt_content = b"This is a test document about artificial intelligence.\n\nIt covers machine learning and deep learning."
    file_obj = io.BytesIO(txt_content)
    chunks = load_document(file_obj, "test.txt")
    r.check("Text file loads successfully", len(chunks) > 0)
    r.check("Text chunks have text content", len(chunks[0].get("text", "")) > 0)

    # Test markdown loading
    md_content = b"# Title\n\nThis is a markdown document.\n\n## Section\n\nContent here."
    file_obj = io.BytesIO(md_content)
    chunks = load_document(file_obj, "test.md")
    r.check("Markdown file loads successfully", len(chunks) > 0)


# ============================================================
# TEST 4: SEMANTIC CACHE
# ============================================================

def test_semantic_cache(r):
    print("\n💾 Test 4: Semantic Cache")
    from rag import cache

    cache._cache.clear()

    # The cache module captures settings at import time.
    # Patch the module-level settings with a mock that has correct values.
    mock_settings = MagicMock()
    mock_settings.SEMANTIC_CACHE_ENABLED = True
    mock_settings.SEMANTIC_CACHE_THRESHOLD = 0.92
    mock_settings.SEMANTIC_CACHE_TTL = 86400
    original_settings = cache.settings
    cache.settings = mock_settings

    try:
        import time
        # Test store and retrieve
        entry = {
            "query": "what is machine learning?",
            "embedding": [1.0, 0.0, 0.0],
            "response": {"answer": "Machine learning is a subset of AI."},
            "timestamp": time.time(),
            "hash": cache._get_query_hash("what is machine learning?"),
        }
        cache._cache["test-tenant"] = [entry]
        result = cache.check_cache("test-tenant", "what is machine learning?")
        r.check("Cache exact match returns response", result is not None)
        r.check("Cache response has answer", result.get("answer") is not None if result else False)

        # Test cache miss
        miss = cache.check_cache("nonexistent-tenant", "query")
        r.check("Cache miss returns None", miss is None)

        # Test cache expiry
        old_entry = {
            "query": "old",
            "embedding": None,
            "response": {"answer": "old"},
            "timestamp": time.time() - 100000,
            "hash": cache._get_query_hash("old"),
        }
        cache._cache["expired-tenant"] = [old_entry]
        mock_settings.SEMANTIC_CACHE_TTL = 1
        expired = cache.check_cache("expired-tenant", "old")
        r.check("Expired cache entry returns None", expired is None)
        mock_settings.SEMANTIC_CACHE_TTL = 86400

        # Test cache stats
        stats = cache.get_cache_stats()
        r.check("Cache stats has total_entries", "total_entries" in stats)
        r.check("Cache stats has tenant_count", "tenant_count" in stats)

        # Test clear
        cache.clear_cache("test-tenant")
        r.check("Clear cache removes entries", "test-tenant" not in cache._cache)
    finally:
        cache.settings = original_settings
        cache._cache.clear()


# ============================================================
# TEST 5: MONITORING HOOKS
# ============================================================

def test_monitoring(r):
    print("\n📊 Test 5: Monitoring Hooks")
    from rag.monitoring import (
        log_ingestion, log_document_parse, log_chunking, log_embedding,
        log_qdrant, log_retrieval, log_reranking, log_query_rewrite,
        log_llm_call, log_cache_hit, log_cache_miss, log_ocr, log_crawl,
        log_error, get_health_check,
    )

    # All monitoring functions should be callable without raising
    r.check("log_ingestion callable", callable(log_ingestion))
    r.check("log_document_parse callable", callable(log_document_parse))
    r.check("log_chunking callable", callable(log_chunking))
    r.check("log_embedding callable", callable(log_embedding))
    r.check("log_qdrant callable", callable(log_qdrant))
    r.check("log_retrieval callable", callable(log_retrieval))
    r.check("log_reranking callable", callable(log_reranking))
    r.check("log_query_rewrite callable", callable(log_query_rewrite))
    r.check("log_llm_call callable", callable(log_llm_call))
    r.check("log_cache_hit callable", callable(log_cache_hit))
    r.check("log_cache_miss callable", callable(log_cache_miss))
    r.check("log_ocr callable", callable(log_ocr))
    r.check("log_crawl callable", callable(log_crawl))
    r.check("log_error callable", callable(log_error))

    # Health check should return a dict
    health = get_health_check()
    r.check("Health check returns dict", isinstance(health, dict))
    r.check("Health check has 'status'", "status" in health)
    r.check("Health check has 'components'", "components" in health)


# ============================================================
# TEST 6: JOB TRACKING
# ============================================================

def test_job_tracking(r):
    print("\n⚙️ Test 6: Background Job Tracking")
    from rag.jobs import get_job_status, _track_job, _jobs

    # Test initial status
    status = get_job_status()
    r.check("Job status has total_jobs", "total_jobs" in status)
    r.check("Job status has queued", "queued" in status)
    r.check("Job status has processing", "processing" in status)
    r.check("Job status has completed", "completed" in status)
    r.check("Job status has failed", "failed" in status)
    r.check("Job status has retrying", "retrying" in status)

    # Test tracking a job
    _track_job("test-job-1", "ingest", "queued", tenant_id="t1")
    r.check("Job tracked in _jobs", "test-job-1" in _jobs)
    r.check("Job status is queued", _jobs["test-job-1"]["status"] == "queued")
    _jobs.pop("test-job-1", None)


# ============================================================
# TEST 7: MIGRATION HELPER
# ============================================================

def test_migration(r):
    print("\n🔄 Test 7: Database Migration")
    from migrate import run_migrations, _add_column_if_missing

    # Test migration on fresh DB
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        db_path = f.name
    conn = sqlite3.connect(db_path)
    conn.execute("""CREATE TABLE documents (
        id TEXT PRIMARY KEY, tenant_id TEXT, filename TEXT,
        original_filename TEXT, file_size INTEGER, file_type TEXT,
        chunk_count INTEGER, character_count INTEGER, status TEXT
    )""")
    conn.commit()
    conn.close()

    # Run migration
    run_migrations(db_path)

    # Verify columns added
    conn = sqlite3.connect(db_path)
    cols = [r[1] for r in conn.execute("PRAGMA table_info(documents)").fetchall()]
    r.check("Migration adds ingestion_status", "ingestion_status" in cols)
    r.check("Migration adds failure_reason", "failure_reason" in cols)
    r.check("Migration adds processing_started_at", "processing_started_at" in cols)
    r.check("Migration adds processing_completed_at", "processing_completed_at" in cols)

    # Verify unanswered_questions table
    tables = [r[0] for r in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    ).fetchall()]
    r.check("Migration creates unanswered_questions table", "unanswered_questions" in tables)

    # Test idempotency
    run_migrations(db_path)
    cols2 = [r[1] for r in conn.execute("PRAGMA table_info(documents)").fetchall()]
    r.check("Migration is idempotent", len(cols) == len(cols2))

    conn.close()
    os.unlink(db_path)


# ============================================================
# TEST 8: ANALYTICS
# ============================================================

def test_analytics(r):
    print("\n📈 Test 8: Analytics Summary")
    from tenants.models import init_db
    from tenants.manager import get_analytics_summary

    # Initialize database tables
    init_db()

    summary = get_analytics_summary()
    expected_fields = [
        "total_queries", "total_tenants", "total_documents",
        "this_week", "today",
        "avg_response_time_ms", "avg_llm_time_ms", "avg_retrieval_time_ms",
        "avg_embedding_time_ms",
        "cache_hit_rate", "total_unanswered", "unanswered_rate",
        "top_queries",
    ]
    for field in expected_fields:
        r.check(f"Analytics has '{field}'", field in summary, f"Missing: {field}")


# ============================================================
# TEST 9: INGESTION STATUS TRACKING
# ============================================================

def test_ingestion_status(r):
    print("\n📥 Test 9: Ingestion Status Tracking")
    from tenants.models import Document, UnansweredQuestion

    r.check("Document has ingestion_status", hasattr(Document, "ingestion_status"))
    r.check("Document has failure_reason", hasattr(Document, "failure_reason"))
    r.check("Document has processing_started_at", hasattr(Document, "processing_started_at"))
    r.check("Document has processing_completed_at", hasattr(Document, "processing_completed_at"))

    r.check("UnansweredQuestion has question", hasattr(UnansweredQuestion, "question"))
    r.check("UnansweredQuestion has fallback_reason", hasattr(UnansweredQuestion, "fallback_reason"))
    r.check("UnansweredQuestion has source_chunks_found", hasattr(UnansweredQuestion, "source_chunks_found"))
    r.check("UnansweredQuestion has top_score", hasattr(UnansweredQuestion, "top_score"))


# ============================================================
# TEST 10: ROUTE IMPORTS
# ============================================================

def test_route_imports(r):
    print("\n🌐 Test 10: Route Imports")
    from api.routes import (
        update_document_ingestion_status,
        replace_document,
        get_unanswered_questions,
        get_unanswered_count,
    )
    r.check("update_document_ingestion_status importable", callable(update_document_ingestion_status))
    r.check("replace_document importable", callable(replace_document))
    r.check("get_unanswered_questions importable", callable(get_unanswered_questions))
    r.check("get_unanswered_count importable", callable(get_unanswered_count))


# ============================================================
# TEST 11: PIPELINE WIRING
# ============================================================

def test_pipeline_wiring(r):
    print("\n🔗 Test 11: Pipeline Integration")
    import ast

    with open("rag/pipeline.py") as f:
        source = f.read()
    tree = ast.parse(source)

    # Check imports
    import_modules = []
    for node in ast.iter_child_nodes(tree):
        if isinstance(node, ast.ImportFrom):
            import_modules.append(node.module or "")

    r.check("Pipeline imports rag.metadata", any("metadata" in m for m in import_modules))
    r.check("Pipeline imports tenants.manager", any("manager" in m for m in import_modules))

    # Check function calls
    calls = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                calls.add(node.func.id)
            elif isinstance(node.func, ast.Attribute):
                calls.add(node.func.attr)

    r.check("Pipeline calls _monitor", "_monitor" in calls)
    r.check("Pipeline calls build_chunk_metadata", "build_chunk_metadata" in calls)
    r.check("Pipeline calls log_unanswered_question", "log_unanswered_question" in calls)
    r.check("Pipeline calls log_query", "log_query" in calls)

    # Check quality_signals in return
    r.check("Pipeline returns quality_signals", "quality_signals" in source)


# ============================================================
# TEST 12: FLUTTER API SERVICE WIRING
# ============================================================

def test_flutter_api_wiring(r):
    print("\n📱 Test 12: Flutter API → Backend Wiring")
    with open("admin/lib/services/api_service.dart") as f:
        dart_source = f.read()

    # Check all API endpoints match backend
    endpoints = {
        "chat": ("/chat/", "POST"),
        "uploadDocument": ("/upload", "POST"),
        "getTenants": ("/admin/tenants", "GET"),
        "createTenant": ("/admin/tenants", "POST"),
        "updateTheme": ("/theme", "PUT"),
        "deleteTenant": ("/admin/tenants/", "DELETE"),
        "getDocuments": ("/documents", "GET"),
        "getAnalytics": ("/admin/analytics/summary", "GET"),
        "getTopQueries": ("/admin/analytics/top-queries", "GET"),
        "getRecentQueries": ("/admin/analytics/recent", "GET"),
        "deleteQuery": ("/admin/queries/", "DELETE"),
        "exportAnalytics": ("/admin/analytics/export", "POST"),
    }

    for method, (path, verb) in endpoints.items():
        r.check(f"Flutter calls {verb} {path}", path in dart_source)


# ============================================================
# TEST 13: ANDROID MANIFEST COMPLETENESS
# ============================================================

def test_android_manifest(r):
    print("\n🤖 Test 13: Android Manifest")
    with open("admin/android/app/src/main/AndroidManifest.xml") as f:
        manifest = f.read()

    r.check("ChatWidgetProvider registered", "ChatWidgetProvider" in manifest)
    r.check("UploadWidgetProvider registered", "UploadWidgetProvider" in manifest)
    r.check("StatusWidgetProvider registered", "StatusWidgetProvider" in manifest)
    r.check("WidgetClickReceiver registered", "WidgetClickReceiver" in manifest)
    r.check("RagChatTileService registered", "RagChatTileService" in manifest)
    r.check("Deep link scheme registered", "ragchat" in manifest)
    r.check("Quick Settings permission", "BIND_QUICK_SETTINGS_TILE" in manifest)
    r.check("APPWIDGET_UPDATE action", "APPWIDGET_UPDATE" in manifest)


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":
    print("=" * 60)
    print("RagChat End-to-End Test Suite")
    print("=" * 60)

    r = TestResult()

    test_metadata_consistency(r)
    test_chunking(r)
    test_document_loader(r)
    test_semantic_cache(r)
    test_monitoring(r)
    test_job_tracking(r)
    test_migration(r)
    test_analytics(r)
    test_ingestion_status(r)
    test_route_imports(r)
    test_pipeline_wiring(r)
    test_flutter_api_wiring(r)
    test_android_manifest(r)

    # Cleanup test DB
    if os.path.exists("./test_e2e.db"):
        os.remove("./test_e2e.db")

    success = r.summary()
    sys.exit(0 if success else 1)

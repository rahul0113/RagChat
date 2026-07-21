"""
Tests for RagChat core functionality after the fix sprint.
Focuses on behavior verification, not implementation details.
Uses module-level mocking to avoid heavy dependency requirements.
"""
import os
import sys
import hashlib
import sqlite3
from unittest.mock import patch, MagicMock

# Ensure we can import from project root
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))


def _make_settings(**overrides):
    """Create a mock settings object with sensible defaults."""
    defaults = {
        "CHUNK_SIZE": 512,
        "CHUNK_OVERLAP": 64,
        "SEMANTIC_CACHE_ENABLED": True,
        "SEMANTIC_CACHE_THRESHOLD": 0.92,
        "SEMANTIC_CACHE_TTL": 3600,
        "SEMANTIC_CACHE_PERSIST": False,
        "SEMANTIC_CACHE_DIR": "./cache",
        "RERANKING_ENABLED": True,
        "RERANK_TOP_K": 20,
        "RERANK_FINAL_K": 5,
        "RERANKER_MODEL": "cross-encoder/ms-marco-MiniLM-L-6-v2",
        "HYBRID_SEARCH_ENABLED": False,
        "BACKGROUND_JOBS_ENABLED": False,
        "MAX_WORKERS": 2,
        "SQLALCHEMY_DATABASE_URI": "sqlite:///./test.db",
    }
    defaults.update(overrides)
    m = MagicMock()
    for k, v in defaults.items():
        setattr(m, k, v)
    return m


def _patch_config(**overrides):
    """Context manager that mocks get_settings."""
    return patch("config.get_settings", return_value=_make_settings(**overrides))


# ============================================
# METADATA HELPER TESTS (no deps)
# ============================================

class TestMetadataHelper:
    def test_build_chunk_metadata(self):
        from rag.metadata import build_chunk_metadata
        meta = build_chunk_metadata(
            text="Hello world",
            source="test.pdf",
            document_id="doc-123",
            chunk_index=0,
            tenant_id="t-1",
            page_number=1,
            section_heading="Intro",
            language="en",
        )
        assert meta["text"] == "Hello world"
        assert meta["source"] == "test.pdf"
        assert meta["document_id"] == "doc-123"
        assert meta["chunk_index"] == 0
        assert meta["tenant_id"] == "t-1"
        assert meta["page_number"] == 1
        assert meta["section_heading"] == "Intro"
        assert meta["language"] == "en"
        assert "upload_timestamp" in meta

    def test_build_chunk_metadata_with_extra(self):
        from rag.metadata import build_chunk_metadata
        meta = build_chunk_metadata(
            text="x", source="f.pdf", document_id="d",
            chunk_index=0, tenant_id="t",
            extra={"custom_key": "custom_value"},
        )
        assert meta["custom_key"] == "custom_value"

    def test_build_source_info(self):
        from rag.metadata import build_source_info
        chunk = {
            "source": "test.pdf",
            "document_id": "d1",
            "page_number": 5,
            "section_heading": "Section 1",
            "score": 0.85,
            "text": "A" * 300,
        }
        info = build_source_info(chunk)
        assert info["source"] == "test.pdf"
        assert info["page_number"] == 5
        assert info["score"] == 0.85
        assert len(info["excerpt"]) <= 200

    def test_build_error_response(self):
        from rag.metadata import build_error_response
        resp = build_error_response("Not found", 404, {"detail": "x"})
        assert resp["error"] is True
        assert resp["message"] == "Not found"
        assert resp["status_code"] == 404
        assert resp["detail"] == {"detail": "x"}


# ============================================
# CHUNKING TESTS
# ============================================

class TestChunking:
    @patch("rag.chunker.get_settings")
    def test_paragraph_aware_splitting(self, mock_gs):
        mock_gs.return_value = _make_settings()
        from rag.chunker import chunk_text
        text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
        chunks = chunk_text(text, source="test", metadata={})
        assert len(chunks) >= 1
        assert all("text" in c for c in chunks)

    @patch("rag.chunker.get_settings")
    def test_heading_preservation(self, mock_gs):
        mock_gs.return_value = _make_settings()
        from rag.chunker import chunk_text
        # Headings must be standalone paragraphs (separated by \n\n from body)
        text = "# Introduction\n\nSome intro text.\n\n# Methods\n\nMethod details here."
        chunks = chunk_text(text, source="test", metadata={})
        headings = [c.get("section_heading", "") for c in chunks]
        assert any("Introduction" in h for h in headings)
        assert any("Methods" in h for h in headings)

    @patch("rag.chunker.get_settings")
    def test_configurable_chunk_size(self, mock_gs):
        mock_gs.return_value = _make_settings(CHUNK_SIZE=100, CHUNK_OVERLAP=20)
        from rag.chunker import chunk_text
        # Use text with sentence boundaries so the splitter can work
        text = "This is sentence one about topic A. This is sentence two about topic B. " * 100
        chunks = chunk_text(text, source="test", metadata={})
        assert len(chunks) > 1

    @patch("rag.chunker.get_settings")
    def test_chunk_index_sequential(self, mock_gs):
        mock_gs.return_value = _make_settings()
        from rag.chunker import chunk_text
        text = "A\n\nB\n\nC\n\nD\n\nE\n\nF\n\nG\n\nH"
        chunks = chunk_text(text, source="test", metadata={})
        indices = [c.get("chunk_index", 0) for c in chunks]
        assert indices == list(range(len(chunks)))


# ============================================
# SEMANTIC CACHE TESTS
# ============================================

class TestSemanticCache:
    def _setup_cache(self):
        from rag import cache
        cache._cache.clear()
        return cache

    def test_store_and_retrieve(self):
        import time
        c = self._setup_cache()
        query = "what is rag?"
        qhash = hashlib.md5(query.lower().strip().encode()).hexdigest()
        entry = {
            "query": query,
            "embedding": [1.0, 0.0, 0.0],
            "response": {"answer": "RAG is retrieval augmented generation"},
            "timestamp": time.time(),  # Use current time so TTL doesn't expire
            "hash": qhash,
        }
        c._cache["test-tenant"] = [entry]
        result = c.check_cache("test-tenant", query)
        assert result is not None
        assert "answer" in result

    def test_cache_miss(self):
        c = self._setup_cache()
        result = c.check_cache("nonexistent", "query")
        assert result is None

    def test_cache_expiry(self):
        import time
        c = self._setup_cache()
        old_entry = {
            "query": "old",
            "embedding": None,
            "response": {"answer": "old"},
            "timestamp": time.time() - 100000,
            "hash": hashlib.md5(b"old").hexdigest(),
        }
        c._cache["test-tenant"] = [old_entry]
        with patch.object(c.settings, "SEMANTIC_CACHE_TTL", 1):
            result = c.check_cache("test-tenant", "old")
            assert result is None

    def test_clear_cache(self):
        c = self._setup_cache()
        c._cache["test-tenant"] = [{"query": "x"}]
        c.clear_cache("test-tenant")
        assert "test-tenant" not in c._cache

    def test_clear_all_cache(self):
        c = self._setup_cache()
        c._cache["t1"] = [{"query": "x"}]
        c._cache["t2"] = [{"query": "y"}]
        c.clear_cache()
        assert len(c._cache) == 0

    def test_cache_stats(self):
        c = self._setup_cache()
        c._cache["t1"] = [1, 2, 3]
        c._cache["t2"] = [1]
        stats = c.get_cache_stats()
        assert stats["total_entries"] == 4
        assert stats["tenant_count"] == 2

    def test_max_entries_eviction(self):
        import time
        c = self._setup_cache()
        # Directly fill cache entries, then use store_cache to trigger eviction
        c._cache["t"] = [{"query": f"q{i}", "embedding": None, "response": {},
                           "timestamp": time.time(), "hash": f"h{i}"} for i in range(1005)]
        # Now store one more — store_cache should evict oldest
        c.store_cache("t", "new_query", {"answer": "new"})
        assert len(c._cache["t"]) <= 1001  # 1000 + the new one


# ============================================
# MODEL TESTS
# ============================================

class TestModels:
    def test_document_model_has_ingestion_fields(self):
        from tenants.models import Document
        assert hasattr(Document, "ingestion_status")
        assert hasattr(Document, "failure_reason")
        assert hasattr(Document, "processing_started_at")
        assert hasattr(Document, "processing_completed_at")

    def test_unanswered_question_model(self):
        from tenants.models import UnansweredQuestion
        assert hasattr(UnansweredQuestion, "question")
        assert hasattr(UnansweredQuestion, "fallback_reason")
        assert hasattr(UnansweredQuestion, "source_chunks_found")
        assert hasattr(UnansweredQuestion, "top_score")


# ============================================
# MONITORING TESTS
# ============================================

class TestMonitoring:
    def test_log_ingestion(self):
        from rag.monitoring import log_ingestion
        log_ingestion("t1", "test.pdf", 10, 10, 500)

    def test_log_error(self):
        from rag.monitoring import log_error
        log_error("test_op", Exception("test error"), tenant_id="t1")

    def test_log_document_parse(self):
        from rag.monitoring import log_document_parse
        log_document_parse("t1", "test.pdf", 5, "pdf", 100)

    def test_log_retrieval(self):
        from rag.monitoring import log_retrieval
        log_retrieval("t1", "what is rag?", 5, "hybrid", 200)

    def test_log_reranking(self):
        from rag.monitoring import log_reranking
        log_reranking("t1", 20, 5, 50, model="ms-marco")

    def test_log_query_rewrite(self):
        from rag.monitoring import log_query_rewrite
        log_query_rewrite("t1", "original", "rewritten", True, 10)

    def test_log_llm_call(self):
        from rag.monitoring import log_llm_call
        log_llm_call("t1", "gpt-4", 500, tokens_in=100, tokens_out=200)

    def test_log_cache_hit(self):
        from rag.monitoring import log_cache_hit
        log_cache_hit("t1", "what is rag?", 5)

    def test_log_cache_miss(self):
        from rag.monitoring import log_cache_miss
        log_cache_miss("t1", "what is rag?")

    def test_log_ocr(self):
        from rag.monitoring import log_ocr
        log_ocr("t1", "scan.pdf", "tesseract", 2000, 5000)


# ============================================
# JOBS TESTS
# ============================================

class TestJobs:
    def test_job_status_fields(self):
        from rag.jobs import get_job_status
        result = get_job_status()
        assert "total_jobs" in result
        assert "queued" in result
        assert "processing" in result
        assert "completed" in result
        assert "failed" in result
        assert "retrying" in result
        assert "background_enabled" in result

    def test_track_job(self):
        from rag.jobs import _track_job, _jobs
        job_id = "test-job-1"
        _track_job(job_id, "ingest", "queued", tenant_id="t1")
        assert job_id in _jobs
        assert _jobs[job_id]["status"] == "queued"
        _jobs.pop(job_id, None)


# ============================================
# MIGRATION HELPER TESTS
# ============================================

class TestMigration:
    def test_migration_module_exists(self):
        from migrate import run_migrations, _add_column_if_missing
        assert callable(run_migrations)
        assert callable(_add_column_if_missing)

    def test_add_column_if_missing(self):
        conn = sqlite3.connect(":memory:")
        cursor = conn.cursor()
        cursor.execute("CREATE TABLE test (id TEXT)")
        from migrate import _add_column_if_missing
        _add_column_if_missing(cursor, "test", "new_col", "TEXT DEFAULT 'x'")
        cursor.execute("PRAGMA table_info(test)")
        cols = [row[1] for row in cursor.fetchall()]
        assert "new_col" in cols
        _add_column_if_missing(cursor, "test", "new_col", "TEXT DEFAULT 'x'")
        conn.close()


# ============================================
# METADATA CONSISTENCY
# ============================================

class TestMetadataConsistency:
    def test_metadata_has_required_fields(self):
        from rag.metadata import build_chunk_metadata
        meta = build_chunk_metadata(
            text="test", source="test.pdf", document_id="d1",
            chunk_index=0, tenant_id="t1",
        )
        required = ["text", "source", "document_id", "chunk_index", "tenant_id",
                     "page_number", "section_heading", "language", "upload_timestamp"]
        for field in required:
            assert field in meta, f"Missing required field: {field}"


# ============================================
# ROUTES IMPORT TEST
# ============================================

class TestRoutes:
    def test_routes_imports_new_functions(self):
        from api.routes import (
            update_document_ingestion_status,
            replace_document,
            get_unanswered_questions,
            get_unanswered_count,
        )
        assert callable(update_document_ingestion_status)
        assert callable(replace_document)
        assert callable(get_unanswered_questions)
        assert callable(get_unanswered_count)

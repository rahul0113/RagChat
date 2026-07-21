"""
Semantic cache for RAG queries.
Caches query → response mappings with cosine similarity lookup.
Supports file-based persistence for durability across restarts.
"""
import os
import json
import time
import hashlib
import logging
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# In-memory cache: {tenant_id: [{query, embedding, response, timestamp, hash}]}
_cache = {}
_cache_lock = __import__("threading").Lock()
_MAX_ENTRIES_PER_TENANT = 1000


def _cache_dir() -> str:
    """Get or create the cache directory."""
    d = getattr(settings, "SEMANTIC_CACHE_DIR", "./cache")
    os.makedirs(d, exist_ok=True)
    return d


def _persist_cache():
    """Write cache to disk (best-effort, per-tenant files)."""
    if not getattr(settings, "SEMANTIC_CACHE_PERSIST", False):
        return
    try:
        for tenant_id, entries in _cache.items():
            path = os.path.join(_cache_dir(), f"{tenant_id}.json")
            # Only persist query text, response, and timestamp (not embeddings)
            serializable = [
                {
                    "query": e["query"],
                    "response": e["response"],
                    "timestamp": e["timestamp"],
                    "hash": e["hash"],
                }
                for e in entries
            ]
            with open(path, "w") as f:
                json.dump(serializable, f)
    except Exception as e:
        logger.warning(f"Cache persist failed: {e}")


def _load_cache():
    """Load cache from disk on startup (best-effort)."""
    if not getattr(settings, "SEMANTIC_CACHE_PERSIST", False):
        return
    try:
        cache_dir = _cache_dir()
        if not os.path.exists(cache_dir):
            return
        for fname in os.listdir(cache_dir):
            if not fname.endswith(".json"):
                continue
            tenant_id = fname.replace(".json", "")
            path = os.path.join(cache_dir, fname)
            with open(path) as f:
                entries = json.load(f)
            # We can only restore metadata, not embeddings
            _cache[tenant_id] = [
                {
                    "query": e["query"],
                    "embedding": None,  # Not persisted
                    "response": e["response"],
                    "timestamp": e["timestamp"],
                    "hash": e.get("hash", ""),
                }
                for e in entries
            ]
            logger.info(f"Loaded {len(entries)} cache entries for tenant {tenant_id}")
    except Exception as e:
        logger.warning(f"Cache load failed: {e}")


# Load cache on module import
_load_cache()


def _get_query_hash(query: str) -> str:
    """Deterministic hash for exact-match cache lookups."""
    return hashlib.md5(query.lower().strip().encode()).hexdigest()


def check_cache(tenant_id: str, query: str) -> dict | None:
    """
    Check if a similar query has been cached.
    Returns the cached response if similarity exceeds threshold, else None.
    """
    if not getattr(settings, "SEMANTIC_CACHE_ENABLED", True):
        return None

    threshold = getattr(settings, "SEMANTIC_CACHE_THRESHOLD", 0.92)
    ttl = getattr(settings, "SEMANTIC_CACHE_TTL", 3600)
    now = time.time()

    query_hash = _get_query_hash(query)

    with _cache_lock:
        entries = _cache.get(tenant_id, [])

        # Remove expired entries
        entries = [e for e in entries if now - e["timestamp"] < ttl]
        _cache[tenant_id] = entries

        for entry in entries:
            # Exact match via hash
            if entry.get("hash") == query_hash:
                return entry["response"]

            # Semantic similarity check (requires embedding)
            if entry.get("embedding") is not None:
                try:
                    from rag.embeddings import embed_query
                    query_vec = embed_query(query)
                    sim = _cosine_similarity(query_vec, entry["embedding"])
                    if sim >= threshold:
                        return entry["response"]
                except Exception:
                    pass

    return None


def store_cache(tenant_id: str, query: str, response: dict):
    """Store a query-response pair in the cache."""
    if not getattr(settings, "SEMANTIC_CACHE_ENABLED", True):
        return

    now = time.time()
    entry = {
        "query": query,
        "embedding": None,
        "response": response,
        "timestamp": now,
        "hash": _get_query_hash(query),
    }

    # Try to store embedding for semantic lookup
    try:
        from rag.embeddings import embed_query
        entry["embedding"] = embed_query(query)
    except Exception:
        pass

    with _cache_lock:
        if tenant_id not in _cache:
            _cache[tenant_id] = []
        _cache[tenant_id].append(entry)
        # Evict oldest if over limit
        if len(_cache[tenant_id]) > _MAX_ENTRIES_PER_TENANT:
            _cache[tenant_id] = _cache[tenant_id][-_MAX_ENTRIES_PER_TENANT:]

    # Persist after write
    _persist_cache()


def clear_cache(tenant_id: str = None):
    """Clear cache for a specific tenant or all tenants."""
    with _cache_lock:
        if tenant_id:
            _cache.pop(tenant_id, None)
            # Remove persisted file
            if getattr(settings, "SEMANTIC_CACHE_PERSIST", False):
                path = os.path.join(_cache_dir(), f"{tenant_id}.json")
                if os.path.exists(path):
                    os.remove(path)
        else:
            _cache.clear()
            # Remove all persisted files
            if getattr(settings, "SEMANTIC_CACHE_PERSIST", False):
                cache_dir = _cache_dir()
                if os.path.exists(cache_dir):
                    for f in os.listdir(cache_dir):
                        if f.endswith(".json"):
                            os.remove(os.path.join(cache_dir, f))


def get_cache_stats() -> dict:
    """Get cache statistics."""
    with _cache_lock:
        total = sum(len(entries) for entries in _cache.values())
        return {
            "total_entries": total,
            "tenant_count": len(_cache),
            "per_tenant": {
                tid: len(entries) for tid, entries in _cache.items()
            },
            "persistence_enabled": getattr(settings, "SEMANTIC_CACHE_PERSIST", False),
        }


def _cosine_similarity(a, b) -> float:
    """Compute cosine similarity between two vectors."""
    import numpy as np
    a = np.array(a)
    b = np.array(b)
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return float(np.dot(a, b) / (norm_a * norm_b))

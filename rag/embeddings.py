"""
Embedding engine using BAAI/bge-large-en-v1.5 (best open-source model).
Runs locally — zero API cost, no rate limits.

Improvements:
- Content-hash based embedding cache for deduplication
- Batch optimization
- Memory-efficient encoding
"""
import hashlib
import logging
import threading
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

_model = None
_model_lock = threading.Lock()

# Embedding cache: {content_hash: embedding_vector}
_embedding_cache = {}
_embedding_cache_lock = threading.Lock()
_MAX_CACHE_SIZE = 10000


def get_embedding_model():
    global _model
    if _model is None:
        with _model_lock:
            if _model is None:  # Double-check locking
                logger.info(f"Loading embedding model: {settings.EMBEDDING_MODEL}")
                from sentence_transformers import SentenceTransformer
                _model = SentenceTransformer(settings.EMBEDDING_MODEL)
                logger.info("Embedding model loaded.")
    return _model


def _content_hash(text: str) -> str:
    """Compute hash of text content for cache key."""
    return hashlib.md5(text.encode('utf-8')).hexdigest()


def _get_cached_embedding(text: str) -> list[float] | None:
    """Get cached embedding if available."""
    if not settings.EMBEDDING_CACHE_ENABLED:
        return None

    key = _content_hash(text)
    with _embedding_cache_lock:
        return _embedding_cache.get(key)


def _cache_embedding(text: str, embedding: list[float]):
    """Cache an embedding."""
    if not settings.EMBEDDING_CACHE_ENABLED:
        return

    key = _content_hash(text)
    with _embedding_cache_lock:
        if len(_embedding_cache) >= _MAX_CACHE_SIZE:
            # Simple FIFO eviction: remove oldest entries
            keys_to_remove = list(_embedding_cache.keys())[:1000]
            for k in keys_to_remove:
                del _embedding_cache[k]
        _embedding_cache[key] = embedding


def embed_texts(texts: list[str]) -> list[list[float]]:
    """Embed a batch of texts into vectors with caching."""
    model = get_embedding_model()

    # Check cache first
    results = [None] * len(texts)
    uncached_indices = []
    uncached_texts = []

    for i, text in enumerate(texts):
        cached = _get_cached_embedding(text)
        if cached is not None:
            results[i] = cached
        else:
            uncached_indices.append(i)
            uncached_texts.append(text)

    # Embed uncached texts
    if uncached_texts:
        logger.info(f"Embedding {len(uncached_texts)} new texts (cached: {len(texts) - len(uncached_texts)})")
        new_embeddings = model.encode(
            uncached_texts,
            batch_size=settings.EMBEDDING_BATCH_SIZE,
            show_progress_bar=False,
            normalize_embeddings=True,
        ).tolist()

        # Cache and fill results
        for idx, embedding in zip(uncached_indices, new_embeddings):
            results[idx] = embedding
            _cache_embedding(texts[idx], embedding)
    else:
        logger.info(f"All {len(texts)} texts served from cache")

    return results


def embed_query(query: str) -> list[float]:
    """Embed a single query string with caching."""
    # Queries are too unique to cache effectively, but check anyway
    cached = _get_cached_embedding(query)
    if cached is not None:
        return cached

    query_with_prefix = f"Represent this sentence for searching relevant passages: {query}"
    result = embed_texts([query_with_prefix])[0]
    _cache_embedding(query, result)
    return result


def clear_embedding_cache():
    """Clear the embedding cache."""
    with _embedding_cache_lock:
        _embedding_cache.clear()
    logger.info("Embedding cache cleared")

"""
Cross-encoder reranking for improved retrieval quality.
Reranks retrieved chunks using a dedicated reranking model.
"""
import logging
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

_reranker_model = None


def _get_reranker():
    """Lazy-load the cross-encoder reranker model."""
    global _reranker_model
    if _reranker_model is None:
        try:
            from sentence_transformers import CrossEncoder
            _reranker_model = CrossEncoder(settings.RERANKER_MODEL)
            logger.info(f"Loaded reranker model: {settings.RERANKER_MODEL}")
        except Exception as e:
            logger.warning(f"Failed to load reranker model: {e}")
            raise
    return _reranker_model


def rerank(query: str, results: list[dict], top_k: int = None) -> list[dict]:
    """
    Rerank search results using a cross-encoder model.

    Args:
        query: The user's query
        results: List of search results with 'text' field
        top_k: Number of results to return after reranking

    Returns:
        Reranked results sorted by cross-encoder score
    """
    if not results:
        return results

    top_k = top_k or settings.RERANK_FINAL_K

    try:
        model = _get_reranker()
    except Exception:
        logger.warning("Reranker unavailable, returning original order")
        return results[:top_k]

    # Build query-document pairs for cross-encoder
    pairs = [(query, doc.get("text", "")) for doc in results]

    # Get cross-encoder scores
    scores = model.predict(pairs)

    # Attach scores to results
    for doc, score in zip(results, scores):
        doc["rerank_score"] = float(score)

    # Sort by rerank score
    results.sort(key=lambda x: x.get("rerank_score", 0), reverse=True)

    # Return top_k with normalized scores
    reranked = results[:top_k]
    if reranked:
        max_score = max(d.get("rerank_score", 0) for d in reranked)
        min_score = min(d.get("rerank_score", 0) for d in reranked)
        score_range = max_score - min_score if max_score != min_score else 1

        for doc in reranked:
            # Normalize to [0, 1] range and blend with original score
            normalized = (doc.get("rerank_score", 0) - min_score) / score_range
            doc["score"] = round((doc.get("score", 0) * 0.3 + normalized * 0.7), 3)
            del doc["rerank_score"]

    logger.info(f"Reranked {len(results)} results, returning top {top_k}")
    return reranked

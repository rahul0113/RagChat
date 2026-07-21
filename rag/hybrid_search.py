"""
Hybrid search combining vector similarity and BM25 keyword search.
Merges results using Reciprocal Rank Fusion (RRF).
"""
import logging
from rank_bm25 import BM25Okapi
from rag.vector_store import search_similar, get_all_texts_for_tenant
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


def _tokenize(text: str) -> list[str]:
    """Simple whitespace + lowercase tokenization for BM25."""
    return text.lower().split()


def hybrid_search(
    tenant_id: str,
    query: str,
    query_vector: list[float],
    top_k: int = 5,
    alpha: float = None,
) -> list[dict]:
    """
    Hybrid search combining vector and keyword retrieval.

    alpha controls the blend:
    - 1.0 = pure vector search
    - 0.0 = pure keyword search
    - 0.7 = good default (70% vector, 30% keyword)

    Uses Reciprocal Rank Fusion to merge results from both methods.
    """
    alpha = alpha if alpha is not None else settings.HYBRID_ALPHA

    # Get vector results
    vector_results = search_similar(tenant_id, query_vector, top_k=top_k * 2)

    # Get all texts for BM25
    all_texts = get_all_texts_for_tenant(tenant_id)
    if not all_texts:
        return vector_results[:top_k]

    # Build BM25 index
    tokenized_corpus = [_tokenize(doc["text"]) for doc in all_texts]
    bm25 = BM25Okapi(tokenized_corpus, k1=settings.BM25_K1, b=settings.BM25_B)

    # Search with BM25
    tokenized_query = _tokenize(query)
    bm25_scores = bm25.get_scores(tokenized_query)

    # Get top BM25 results
    bm25_indices = sorted(range(len(bm25_scores)), key=lambda i: bm25_scores[i], reverse=True)[:top_k * 2]
    bm25_results = []
    for idx in bm25_indices:
        if bm25_scores[idx] > 0:
            doc = all_texts[idx]
            bm25_results.append({
                "text": doc["text"],
                "score": float(bm25_scores[idx]),
                "source": doc.get("source", ""),
                "document_id": doc.get("document_id", ""),
                "chunk_index": doc.get("chunk_index", 0),
                "page_number": doc.get("page_number"),
                "section_heading": doc.get("section_heading", ""),
            })

    # Merge using Reciprocal Rank Fusion
    merged = _rrf_merge(vector_results, bm25_results, alpha, top_k)

    logger.info(f"Hybrid search: {len(vector_results)} vector + {len(bm25_results)} keyword = {len(merged)} merged results")
    return merged


def _rrf_merge(
    vector_results: list[dict],
    bm25_results: list[dict],
    alpha: float,
    top_k: int,
) -> list[dict]:
    """
    Merge results using Reciprocal Rank Fusion.

    RRF score = alpha * (1 / (k + rank_vector)) + (1 - alpha) * (1 / (k + rank_bm25))
    where k = 60 (standard constant).
    """
    k = 60  # RRF constant

    # Build rank maps
    vector_ranks = {}
    for rank, doc in enumerate(vector_results):
        key = _doc_key(doc)
        vector_ranks[key] = rank

    bm25_ranks = {}
    for rank, doc in enumerate(bm25_results):
        key = _doc_key(doc)
        bm25_ranks[key] = rank

    # Combine all unique documents
    all_keys = set(vector_ranks.keys()) | set(bm25_ranks.keys())
    scored = []

    for key in all_keys:
        v_rank = vector_ranks.get(key, len(vector_results))
        b_rank = bm25_ranks.get(key, len(bm25_results))

        rrf_score = (
            alpha * (1 / (k + v_rank + 1)) +
            (1 - alpha) * (1 / (k + b_rank + 1))
        )

        # Find the document with full metadata
        doc = _find_doc(key, vector_results, bm25_results)
        if doc:
            doc["rrf_score"] = rrf_score
            scored.append(doc)

    # Sort by RRF score
    scored.sort(key=lambda x: x["rrf_score"], reverse=True)

    # Normalize scores to [0, 1] range for consistency with vector search
    if scored:
        max_score = scored[0]["rrf_score"]
        for doc in scored:
            doc["score"] = doc["rrf_score"] / max_score if max_score > 0 else 0
            del doc["rrf_score"]

    return scored[:top_k]


def _doc_key(doc: dict) -> str:
    """Generate a unique key for a document chunk."""
    return f"{doc.get('document_id', '')}_{doc.get('source', '')}_{doc.get('chunk_index', 0)}"


def _find_doc(key: str, *result_lists) -> dict | None:
    """Find a document by key across multiple result lists."""
    for results in result_lists:
        for doc in results:
            if _doc_key(doc) == key:
                return doc.copy()
    return None

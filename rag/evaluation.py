"""
Evaluation framework for RAG pipeline quality.
Measures retrieval quality, answer faithfulness, and overall system performance.

Metrics:
- Precision@K: Fraction of retrieved chunks that are relevant
- Recall@K: Fraction of relevant chunks that are retrieved
- MRR (Mean Reciprocal Rank): How high the first relevant result is
- NDCG: Normalized Discounted Cumulative Gain
- Faithfulness: Whether the answer is grounded in context
- Relevance: Whether the answer addresses the question
"""
import json
import logging
import time
from dataclasses import dataclass, asdict
from typing import Optional

logger = logging.getLogger(__name__)


@dataclass
class RetrievalMetrics:
    """Metrics for retrieval quality."""
    precision_at_k: float = 0.0
    recall_at_k: float = 0.0
    mrr: float = 0.0
    ndcg: float = 0.0
    top_score: float = 0.0
    avg_score: float = 0.0
    num_results: int = 0


@dataclass
class GenerationMetrics:
    """Metrics for generation quality."""
    faithfulness: float = 0.0  # 0-1, how grounded in context
    relevance: float = 0.0     # 0-1, how relevant to question
    confidence: str = "low"    # low/medium/high
    grounded: bool = False
    citations_used: int = 0
    tokens_used: int = 0


@dataclass
class PipelineMetrics:
    """Full pipeline metrics."""
    retrieval: RetrievalMetrics
    generation: GenerationMetrics
    total_latency_ms: int = 0
    query_rewrite_latency_ms: int = 0
    embedding_latency_ms: int = 0
    retrieval_latency_ms: int = 0
    reranking_latency_ms: int = 0
    generation_latency_ms: int = 0
    cache_hit: bool = False
    search_mode: str = "hybrid"


def compute_retrieval_metrics(
    retrieved_chunks: list[dict],
    relevant_doc_ids: Optional[set[str]] = None,
    k: int = 5,
) -> RetrievalMetrics:
    """
    Compute retrieval quality metrics.

    Args:
        retrieved_chunks: List of chunks with 'score' and 'document_id'
        relevant_doc_ids: Set of document IDs that are relevant (for evaluation)
        k: Number of top results to evaluate
    """
    if not retrieved_chunks:
        return RetrievalMetrics()

    top_k = retrieved_chunks[:k]
    scores = [c.get("score", 0) for c in top_k]

    metrics = RetrievalMetrics(
        num_results=len(retrieved_chunks),
        top_score=max(scores) if scores else 0,
        avg_score=sum(scores) / len(scores) if scores else 0,
    )

    # If we have relevance labels, compute precision/recall/MRR/NDCG
    if relevant_doc_ids:
        # Precision@K: fraction of retrieved docs that are relevant
        relevant_retrieved = sum(
            1 for c in top_k
            if c.get("document_id") in relevant_doc_ids
        )
        metrics.precision_at_k = relevant_retrieved / k if k > 0 else 0

        # Recall@K: fraction of relevant docs that were retrieved
        if relevant_doc_ids:
            metrics.recall_at_k = relevant_retrieved / len(relevant_doc_ids)

        # MRR: 1/rank of first relevant result
        for i, c in enumerate(top_k, 1):
            if c.get("document_id") in relevant_doc_ids:
                metrics.mrr = 1.0 / i
                break

        # NDCG@K
        dcg = sum(
            (1.0 if top_k[i].get("document_id") in relevant_doc_ids else 0) /
            (i + 1)  # log2(rank + 1)
            for i in range(min(k, len(top_k)))
        )
        ideal_dcg = sum(1.0 / (i + 1) for i in range(min(len(relevant_doc_ids), k)))
        metrics.ndcg = dcg / ideal_dcg if ideal_dcg > 0 else 0

    return metrics


def compute_generation_metrics(
    answer: str,
    context_chunks: list[dict],
    question: str,
    citations: list[dict] = None,
) -> GenerationMetrics:
    """
    Compute generation quality metrics.

    Simple heuristics (for production, use LLM-as-judge):
    - Faithfulness: based on answer length and citation usage
    - Relevance: based on keyword overlap with question
    """
    if not answer:
        return GenerationMetrics()

    # Simple faithfulness heuristic
    answer_lower = answer.lower()
    context_text = " ".join(c.get("text", "").lower() for c in context_chunks)

    # Check if answer words appear in context
    answer_words = set(answer_lower.split())
    context_words = set(context_text.split())
    if answer_words:
        overlap = len(answer_words & context_words) / len(answer_words)
        faithfulness = min(overlap * 1.2, 1.0)  # Boost slightly
    else:
        faithfulness = 0.0

    # Simple relevance heuristic
    question_words = set(question.lower().split())
    if question_words:
        answer_question_overlap = len(question_words & answer_words) / len(question_words)
        relevance = min(answer_question_overlap * 1.5, 1.0)
    else:
        relevance = 0.0

    # Count citations
    citations_used = len(citations) if citations else 0

    # Estimate confidence based on faithfulness and relevance
    avg_quality = (faithfulness + relevance) / 2
    if avg_quality >= 0.7:
        confidence = "high"
        grounded = True
    elif avg_quality >= 0.4:
        confidence = "medium"
        grounded = faithfulness >= 0.5
    else:
        confidence = "low"
        grounded = False

    return GenerationMetrics(
        faithfulness=round(faithfulness, 3),
        relevance=round(relevance, 3),
        confidence=confidence,
        grounded=grounded,
        citations_used=citations_used,
    )


def create_pipeline_metrics(
    retrieval_chunks: list[dict],
    answer: str,
    question: str,
    context_chunks: list[dict],
    timings: dict,
    search_mode: str = "hybrid",
    cache_hit: bool = False,
    relevant_doc_ids: Optional[set[str]] = None,
) -> PipelineMetrics:
    """Create complete pipeline metrics."""
    retrieval_metrics = compute_retrieval_metrics(retrieval_chunks, relevant_doc_ids)
    generation_metrics = compute_generation_metrics(answer, context_chunks, question)

    return PipelineMetrics(
        retrieval=retrieval_metrics,
        generation=generation_metrics,
        total_latency_ms=timings.get("total_ms", 0),
        query_rewrite_latency_ms=timings.get("rewrite_ms", 0),
        embedding_latency_ms=timings.get("embed_ms", 0),
        retrieval_latency_ms=timings.get("search_ms", 0),
        reranking_latency_ms=timings.get("rerank_ms", 0),
        generation_latency_ms=timings.get("llm_ms", 0),
        cache_hit=cache_hit,
        search_mode=search_mode,
    )


def log_metrics(metrics: PipelineMetrics, tenant_id: str, query: str):
    """Log pipeline metrics for monitoring."""
    logger.info(
        f"[metrics] tenant={tenant_id} "
        f"query_length={len(query)} "
        f"total_ms={metrics.total_latency_ms} "
        f"retrieval_ms={metrics.retrieval_latency_ms} "
        f"generation_ms={metrics.generation_latency_ms} "
        f"precision@5={metrics.retrieval.precision_at_k:.3f} "
        f"mrr={metrics.retrieval.mrr:.3f} "
        f"faithfulness={metrics.generation.faithfulness:.3f} "
        f"confidence={metrics.generation.confidence} "
        f"cache_hit={metrics.cache_hit} "
        f"search_mode={metrics.search_mode}"
    )


def export_metrics_json(metrics: PipelineMetrics) -> dict:
    """Export metrics as JSON-serializable dict."""
    return {
        "retrieval": asdict(metrics.retrieval),
        "generation": asdict(metrics.generation),
        "timing": {
            "total_ms": metrics.total_latency_ms,
            "query_rewrite_ms": metrics.query_rewrite_latency_ms,
            "embedding_ms": metrics.embedding_latency_ms,
            "retrieval_ms": metrics.retrieval_latency_ms,
            "reranking_ms": metrics.reranking_latency_ms,
            "generation_ms": metrics.generation_latency_ms,
        },
        "cache_hit": metrics.cache_hit,
        "search_mode": metrics.search_mode,
    }

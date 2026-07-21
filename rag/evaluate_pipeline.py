"""
Golden dataset evaluation script for the RAG pipeline.

Run with: python -m rag.evaluate_pipeline

This script evaluates the pipeline against a golden dataset of Q&A pairs
and produces retrieval and generation quality metrics.
"""
import json
import time
import logging
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from rag.pipeline import query_rag
from rag.evaluation import (
    compute_retrieval_metrics,
    compute_generation_metrics,
    RetrievalMetrics,
    GenerationMetrics,
)
from config import get_settings

logger = logging.getLogger(__name__)

# Default golden dataset — replace with your own Q&A pairs
DEFAULT_GOLDEN_DATASET = [
    {
        "question": "What is the main topic of the document?",
        "expected_keywords": ["introduction", "overview", "main", "topic"],
        "document_id": None,  # Set to specific doc_id if needed
    },
    {
        "question": "What are the key features mentioned?",
        "expected_keywords": ["feature", "capability", "function"],
        "document_id": None,
    },
    {
        "question": "Who is the intended audience?",
        "expected_keywords": ["audience", "user", "reader", "target"],
        "document_id": None,
    },
]


def load_golden_dataset(path: str = None) -> list[dict]:
    """Load golden dataset from file or use defaults."""
    if path and os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return DEFAULT_GOLDEN_DATASET


def evaluate_single(
    tenant_id: str,
    golden: dict,
    structured: bool = True,
) -> dict:
    """Evaluate the pipeline on a single question."""
    question = golden["question"]
    expected_keywords = golden.get("expected_keywords", [])

    start_time = time.time()

    try:
        result = query_rag(
            tenant_id=tenant_id,
            question=question,
            org_name="Evaluation",
            structured=structured,
        )
    except Exception as e:
        return {
            "question": question,
            "error": str(e),
            "latency_ms": int((time.time() - start_time) * 1000),
        }

    latency_ms = int((time.time() - start_time) * 1000)
    answer = result.get("answer", "")
    sources = result.get("sources", [])

    # Compute retrieval metrics
    retrieval_metrics = compute_retrieval_metrics(
        [{"document_id": s.get("document", ""), "score": s.get("score", 0)} for s in sources],
        k=5,
    )

    # Compute generation metrics
    generation_metrics = compute_generation_metrics(
        answer=answer,
        context_chunks=sources,
        question=question,
        citations=sources,
    )

    # Check keyword coverage
    answer_lower = answer.lower()
    keywords_found = sum(1 for kw in expected_keywords if kw.lower() in answer_lower)
    keyword_coverage = keywords_found / len(expected_keywords) if expected_keywords else 0

    return {
        "question": question,
        "answer": answer[:200] + "..." if len(answer) > 200 else answer,
        "num_sources": len(sources),
        "retrieval": {
            "precision_at_k": round(retrieval_metrics.precision_at_k, 3),
            "mrr": round(retrieval_metrics.mrr, 3),
            "avg_score": round(retrieval_metrics.avg_score, 3),
        },
        "generation": {
            "faithfulness": round(generation_metrics.faithfulness, 3),
            "relevance": round(generation_metrics.relevance, 3),
            "confidence": generation_metrics.confidence,
        },
        "keyword_coverage": round(keyword_coverage, 3),
        "latency_ms": latency_ms,
        "quality_signals": result.get("quality_signals", {}),
    }


def run_evaluation(
    tenant_id: str,
    dataset_path: str = None,
    output_path: str = None,
) -> dict:
    """Run full evaluation against golden dataset."""
    dataset = load_golden_dataset(dataset_path)
    results = []

    print(f"\n{'='*60}")
    print(f"RAG Pipeline Evaluation")
    print(f"Tenant: {tenant_id}")
    print(f"Dataset: {len(dataset)} questions")
    print(f"{'='*60}\n")

    for i, golden in enumerate(dataset, 1):
        print(f"[{i}/{len(dataset)}] {golden['question'][:60]}...")
        result = evaluate_single(tenant_id, golden)
        results.append(result)
        print(f"  -> {result.get('latency_ms', 0)}ms | confidence: {result.get('generation', {}).get('confidence', 'N/A')}")

    # Compute aggregate metrics
    valid_results = [r for r in results if "error" not in r]

    if not valid_results:
        print("\nNo valid results to aggregate.")
        return {"results": results}

    avg_retrieval_precision = sum(r["retrieval"]["precision_at_k"] for r in valid_results) / len(valid_results)
    avg_retrieval_mrr = sum(r["retrieval"]["mrr"] for r in valid_results) / len(valid_results)
    avg_faithfulness = sum(r["generation"]["faithfulness"] for r in valid_results) / len(valid_results)
    avg_relevance = sum(r["generation"]["relevance"] for r in valid_results) / len(valid_results)
    avg_latency = sum(r["latency_ms"] for r in valid_results) / len(valid_results)
    avg_keyword_coverage = sum(r["keyword_coverage"] for r in valid_results) / len(valid_results)

    summary = {
        "total_questions": len(dataset),
        "valid_results": len(valid_results),
        "errors": len(results) - len(valid_results),
        "metrics": {
            "retrieval_precision@5": round(avg_retrieval_precision, 3),
            "retrieval_mrr": round(avg_retrieval_mrr, 3),
            "generation_faithfulness": round(avg_faithfulness, 3),
            "generation_relevance": round(avg_relevance, 3),
            "keyword_coverage": round(avg_keyword_coverage, 3),
            "avg_latency_ms": round(avg_latency, 0),
        },
    }

    print(f"\n{'='*60}")
    print(f"Aggregate Results")
    print(f"{'='*60}")
    print(f"Retrieval Precision@5: {summary['metrics']['retrieval_precision@5']}")
    print(f"Retrieval MRR:         {summary['metrics']['retrieval_mrr']}")
    print(f"Faithfulness:          {summary['metrics']['generation_faithfulness']}")
    print(f"Relevance:             {summary['metrics']['generation_relevance']}")
    print(f"Keyword Coverage:      {summary['metrics']['keyword_coverage']}")
    print(f"Avg Latency:           {summary['metrics']['avg_latency_ms']}ms")
    print(f"{'='*60}\n")

    # Save results
    output = {
        "summary": summary,
        "results": results,
    }

    output_file = output_path or "evaluation_results.json"
    with open(output_file, "w") as f:
        json.dump(output, f, indent=2)
    print(f"Results saved to {output_file}")

    return output


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Evaluate RAG pipeline")
    parser.add_argument("--tenant", required=True, help="Tenant ID to evaluate")
    parser.add_argument("--dataset", help="Path to golden dataset JSON")
    parser.add_argument("--output", help="Output path for results")
    args = parser.parse_args()

    run_evaluation(args.tenant, args.dataset, args.output)

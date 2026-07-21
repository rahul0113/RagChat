"""
Core RAG pipeline — orchestrates the full flow:
Query → Rewrite → Embed → Search → Rerank → Context → LLM → Response

Supports:
- Query rewriting for better retrieval
- Hybrid search (vector + BM25)
- Cross-encoder reranking
- Structured citations
- Semantic caching
- Performance timing
- Structured monitoring
- Retrieval quality signals
- Unanswered question tracking
- Token budgeting
- Context deduplication
- Evaluation metrics (precision, MRR, faithfulness)
"""
import time
import uuid
import logging
from rag.embeddings import embed_texts, embed_query
from rag.vector_store import search_similar, insert_vectors, create_tenant_collection
from rag.hybrid_search import invalidate_bm25_cache
from rag.llm import (
    generate_response,
    generate_structured_response,
    stream_response,
    rewrite_query,
    generate_hyde_query,
    generate_multi_queries,
)
from rag.evaluation import (
    compute_retrieval_metrics,
    compute_generation_metrics,
    log_metrics,
)
from rag.chunker import chunk_text
from rag.document_loader import load_document
from rag.metadata import build_chunk_metadata, build_source_info
from tenants.manager import log_query, log_unanswered_question
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


def _monitor(operation: str, tenant_id: str = None, success: bool = True,
             latency_ms: int = 0, extra: dict = None):
    """Emit a structured monitoring log entry."""
    fields = {"operation": operation, "success": success, "latency_ms": latency_ms}
    if tenant_id:
        fields["tenant_id"] = tenant_id
    if extra:
        fields.update(extra)
    msg_parts = [f"{k}={v}" for k, v in fields.items()]
    if success:
        logger.info(f"[monitor] {' '.join(msg_parts)}")
    else:
        logger.warning(f"[monitor] {' '.join(msg_parts)}")


def ingest_document(tenant_id: str, file_obj, filename: str) -> dict:
    """Full ingestion pipeline: load → chunk → embed → store."""
    document_id = str(uuid.uuid4())
    ingest_start = time.time()

    # 1. Load document with rich metadata
    _monitor("ingestion.start", tenant_id, extra={"filename": filename})
    try:
        raw_chunks = load_document(file_obj, filename)
        _monitor("document.load", tenant_id, extra={"pages": len(raw_chunks), "filename": filename})
    except Exception as e:
        _monitor("document.load", tenant_id, success=False, extra={"error": str(e)})
        raise

    # 2. Chunk each page/section with metadata
    all_chunks = []
    for raw in raw_chunks:
        page_text = raw.pop("text", "")
        meta = {k: v for k, v in raw.items() if v is not None}
        chunked = chunk_text(page_text, source=filename, metadata=meta)
        all_chunks.extend(chunked)

    if not all_chunks:
        raise ValueError(f"No content extracted from '{filename}'.")

    # Add document_id to all chunks
    for chunk in all_chunks:
        chunk["document_id"] = document_id

    _monitor("chunking", tenant_id, extra={
        "filename": filename,
        "chunk_count": len(all_chunks),
        "total_chars": sum(len(c["text"]) for c in all_chunks),
    })

    # 3-5. Vector operations (Qdrant) — non-fatal if unreachable
    vectors_stored = 0
    embed_start = time.time()
    try:
        create_tenant_collection(tenant_id)
        texts_to_embed = [c["text"] for c in all_chunks]
        vectors = embed_texts(texts_to_embed)
        _monitor("embedding", tenant_id, latency_ms=int((time.time() - embed_start) * 1000),
                 extra={"vector_count": len(vectors)})

        # Build rich metadata using shared helper
        metadatas = []
        for c in all_chunks:
            metadatas.append(build_chunk_metadata(
                text=c["text"],
                source=c.get("source", filename),
                document_id=document_id,
                chunk_index=c.get("chunk_index", 0),
                tenant_id=tenant_id,
                page_number=c.get("page_number"),
                section_heading=c.get("section_heading", ""),
                language=c.get("language", ""),
                upload_timestamp=c.get("upload_timestamp"),
            ))

        insert_vectors(tenant_id, texts_to_embed, vectors, metadatas)
        vectors_stored = len(all_chunks)
        invalidate_bm25_cache(tenant_id)
        _monitor("qdrant.insert", tenant_id, extra={"vectors_stored": vectors_stored})
    except Exception as e:
        logger.warning(f"Vector storage failed for '{filename}' (Qdrant unreachable?): {e}")
        _monitor("qdrant.insert", tenant_id, success=False, extra={"error": str(e)})

    total_ms = int((time.time() - ingest_start) * 1000)
    _monitor("ingestion.complete", tenant_id, latency_ms=total_ms, extra={
        "filename": filename,
        "chunks": len(all_chunks),
        "vectors_stored": vectors_stored,
    })

    return {
        "document_id": document_id,
        "filename": filename,
        "chunks": len(all_chunks),
        "characters": sum(len(c["text"]) for c in all_chunks),
        "vectors_stored": vectors_stored,
    }


def query_rag(
    tenant_id: str,
    question: str,
    org_name: str = "the organization",
    top_k: int = 5,
    chat_history: list[dict] = None,
    structured: bool = False,
) -> dict:
    """Full RAG query: rewrite → embed → search → rerank → generate."""
    timings = {}
    total_start = time.time()

    # 0. Check semantic cache
    cached = None
    if settings.SEMANTIC_CACHE_ENABLED:
        try:
            from rag.cache import check_cache
            cache_start = time.time()
            cached = check_cache(tenant_id, question)
            if cached:
                cache_ms = int((time.time() - cache_start) * 1000)
                _monitor("cache.hit", tenant_id, latency_ms=cache_ms, extra={
                    "query": question[:80],
                })
                cached["cache_hit"] = True
                cached["timings"] = {"total_ms": int((time.time() - total_start) * 1000)}
                return cached
            _monitor("cache.miss", tenant_id, extra={"query": question[:80]})
        except ImportError:
            pass

    # 1. Query rewriting
    query_start = time.time()
    rewrite_used = False
    rewritten_query = rewrite_query(question)
    if rewritten_query.lower().strip() != question.lower().strip():
        rewrite_used = True
    timings["rewrite_ms"] = int((time.time() - query_start) * 1000)
    _monitor("query.rewrite", tenant_id, extra={
        "rewrite_used": rewrite_used,
        "original": question[:60],
        "rewritten": rewritten_query[:60] if rewrite_used else "(unchanged)",
    })

    # 2. Generate HyDE query for better retrieval
    hyde_query = generate_hyde_query(rewritten_query)
    hyde_used = hyde_query != rewritten_query
    _monitor("query.hyde", tenant_id, extra={"hyde_used": hyde_used})

    # 3. Embed the HyDE query (or original if HyDE failed)
    embed_start = time.time()
    query_vector = embed_query(hyde_query)
    timings["embedding_ms"] = int((time.time() - embed_start) * 1000)

    # 3. Search for relevant chunks (hybrid if enabled)
    search_start = time.time()
    search_k = settings.RERANK_TOP_K if settings.RERANKING_ENABLED else top_k
    search_mode = "hybrid" if settings.HYBRID_SEARCH_ENABLED else "vector"

    if settings.HYBRID_SEARCH_ENABLED:
        try:
            from rag.hybrid_search import hybrid_search
            results = hybrid_search(tenant_id, rewritten_query, query_vector, top_k=search_k)
        except ImportError:
            results = search_similar(tenant_id, query_vector, top_k=search_k)
    else:
        results = search_similar(tenant_id, query_vector, top_k=search_k)
    timings["search_ms"] = int((time.time() - search_start) * 1000)

    # 3.5 If few results, try multi-query retrieval
    if len(results) < 3:
        _monitor("query.multi_query", tenant_id, extra={"trigger": "few_results", "count": len(results)})
        multi_queries = generate_multi_queries(rewritten_query)
        seen_texts = {r.get("text", "")[:200] for r in results}

        for mq in multi_queries[1:]:  # Skip first (same as rewritten_query)
            try:
                mq_vector = embed_query(mq)
                if settings.HYBRID_SEARCH_ENABLED:
                    from rag.hybrid_search import hybrid_search
                    mq_results = hybrid_search(tenant_id, mq, mq_vector, top_k=top_k)
                else:
                    mq_results = search_similar(tenant_id, mq_vector, top_k=top_k)

                for r in mq_results:
                    text_key = r.get("text", "")[:200]
                    if text_key not in seen_texts:
                        results.append(r)
                        seen_texts.add(text_key)
            except Exception as e:
                logger.warning(f"Multi-query search failed for '{mq[:50]}': {e}")

        # Re-sort by score and take top_k
        results.sort(key=lambda x: x.get("score", 0), reverse=True)
        results = results[:search_k]

    if not results:
        total_ms = int((time.time() - total_start) * 1000)
        _monitor("query.no_results", tenant_id, latency_ms=total_ms, extra={"query": question[:80]})
        # Track unanswered question
        try:
            log_unanswered_question(
                tenant_id=tenant_id,
                question=question,
                fallback_reason="no_results",
                source_chunks_found=0,
                top_score=0.0,
            )
        except Exception:
            pass
        return {
            "answer": "I couldn't find relevant information in the knowledge base. Please try rephrasing your question or upload more documents.",
            "sources": [],
            "chunks_found": 0,
            "cache_hit": False,
            "timings": {**timings, "total_ms": total_ms},
            "quality_signals": {
                "rewrite_used": rewrite_used,
                "search_mode": search_mode,
                "chunks_retrieved": 0,
                "reranker_used": False,
                "reranked_count": 0,
                "final_context_size": 0,
                "fallback_reason": "no_results",
            },
        }

    # 4. Rerank if enabled
    rerank_start = time.time()
    reranker_used = False
    pre_rerank_count = len(results)
    if settings.RERANKING_ENABLED:
        try:
            from rag.reranker import rerank
            results = rerank(question, results, top_k=settings.RERANK_FINAL_K)
            reranker_used = True
        except ImportError:
            results = results[:top_k]
    else:
        results = results[:top_k]
    timings["rerank_ms"] = int((time.time() - rerank_start) * 1000)

    # 5. Generate response
    llm_start = time.time()
    if structured:
        response = generate_structured_response(
            query=question,
            context_chunks=results,
            org_name=org_name,
            chat_history=chat_history,
        )
        answer = response.get("answer", "")
        citations = response.get("citations", [])
        sources = []
        for c in citations:
            sources.append({
                "document": c.get("document", ""),
                "page": c.get("page"),
                "score": next(
                    (r.get("score", 0) for r in results if r.get("source") == c.get("document")),
                    0,
                ),
                "excerpt": c.get("excerpt", ""),
            })
        cited_docs = {c.get("document") for c in citations}
        for r in results:
            if r.get("source") not in cited_docs:
                sources.append({
                    "document": r.get("source", ""),
                    "page": r.get("page_number"),
                    "score": round(r.get("score", 0), 3),
                    "excerpt": r.get("text", "")[:200],
                })
    else:
        answer = generate_response(
            query=question,
            context_chunks=results,
            org_name=org_name,
            chat_history=chat_history,
        )
        sources = [
            {
                "source": r.get("source", ""),
                "document_id": r.get("document_id", ""),
                "score": round(r.get("score", 0), 3),
                "excerpt": r.get("text", "")[:200],
                "page_number": r.get("page_number"),
                "section_heading": r.get("section_heading", ""),
            }
            for r in results
        ]
    timings["llm_ms"] = int((time.time() - llm_start) * 1000)

    # Detect fallback / insufficient context
    fallback_reason = None
    insufficient_context = False
    if results and results[0].get("score", 0) < 0.3:
        fallback_reason = "low_confidence"
        insufficient_context = True
    elif answer and ("I couldn't" in answer or "no relevant" in answer.lower()):
        fallback_reason = "insufficient_context"
        insufficient_context = True

    # Compute final context size
    final_context_size = sum(len(r.get("text", "")) for r in results)

    _monitor("query.complete", tenant_id, latency_ms=int((time.time() - total_start) * 1000), extra={
        "search_mode": search_mode,
        "reranker_used": reranker_used,
        "chunks_retrieved": pre_rerank_count,
        "final_count": len(results),
        "fallback_reason": fallback_reason or "none",
    })

    # Track unanswered if fallback detected
    if fallback_reason:
        try:
            log_unanswered_question(
                tenant_id=tenant_id,
                question=question,
                fallback_reason=fallback_reason,
                source_chunks_found=len(results),
                top_score=results[0].get("score", 0) if results else 0.0,
            )
        except Exception:
            pass

    # 6. Log the query for analytics
    total_ms = int((time.time() - total_start) * 1000)
    timings["total_ms"] = total_ms
    try:
        log_query(
            tenant_id, question, answer, sources, len(results),
            retrieval_time_ms=timings.get("search_ms", 0) + timings.get("rerank_ms", 0),
            embedding_time_ms=timings.get("embedding_ms", 0),
            llm_time_ms=timings.get("llm_ms", 0),
            total_time_ms=total_ms,
            cache_hit=False,
        )
    except Exception as e:
        logger.warning(f"Failed to log query: {e}")

    # 7. Cache the result
    if settings.SEMANTIC_CACHE_ENABLED:
        try:
            from rag.cache import store_cache
            store_cache(tenant_id, question, {
                "answer": answer,
                "sources": sources,
                "chunks_found": len(results),
            })
        except ImportError:
            pass

    # 8. Compute evaluation metrics
    try:
        retrieval_metrics = compute_retrieval_metrics(results, k=top_k)
        generation_metrics = compute_generation_metrics(answer, results, question, citations if structured else None)
    except Exception:
        retrieval_metrics = None
        generation_metrics = None

    return {
        "answer": answer,
        "sources": sources,
        "chunks_found": len(results),
        "cache_hit": False,
        "timings": timings,
        "quality_signals": {
            "rewrite_used": rewrite_used,
            "search_mode": search_mode,
            "chunks_retrieved": pre_rerank_count,
            "reranker_used": reranker_used,
            "reranked_count": len(results),
            "final_context_size": final_context_size,
            "fallback_reason": fallback_reason,
            "insufficient_context": insufficient_context,
            "top_score": results[0].get("score", 0) if results else 0,
            "retrieval": {
                "precision_at_k": retrieval_metrics.precision_at_k if retrieval_metrics else 0,
                "mrr": retrieval_metrics.mrr if retrieval_metrics else 0,
                "avg_score": retrieval_metrics.avg_score if retrieval_metrics else 0,
            } if retrieval_metrics else None,
            "generation": {
                "faithfulness": generation_metrics.faithfulness if generation_metrics else 0,
                "relevance": generation_metrics.relevance if generation_metrics else 0,
                "confidence": generation_metrics.confidence if generation_metrics else "low",
                "grounded": generation_metrics.grounded if generation_metrics else False,
            } if generation_metrics else None,
        },
    }


def query_rag_stream(
    tenant_id: str,
    question: str,
    org_name: str = "the organization",
    top_k: int = 5,
    chat_history: list[dict] = None,
):
    """Streaming version of RAG query."""
    rewrite_used = False
    rewritten_query = rewrite_query(question)
    if rewritten_query.lower().strip() != question.lower().strip():
        rewrite_used = True
    _monitor("query.rewrite", tenant_id, extra={"rewrite_used": rewrite_used})

    query_vector = embed_query(rewritten_query)
    search_mode = "hybrid" if settings.HYBRID_SEARCH_ENABLED else "vector"

    if settings.HYBRID_SEARCH_ENABLED:
        try:
            from rag.hybrid_search import hybrid_search
            results = hybrid_search(tenant_id, rewritten_query, query_vector, top_k=top_k)
        except ImportError:
            results = search_similar(tenant_id, query_vector, top_k=top_k)
    else:
        results = search_similar(tenant_id, query_vector, top_k=top_k)

    if not results:
        _monitor("query.no_results", tenant_id, extra={"query": question[:80]})
        try:
            log_unanswered_question(
                tenant_id=tenant_id, question=question,
                fallback_reason="no_results",
            )
        except Exception:
            pass
        yield "I couldn't find relevant information in the knowledge base."
        return

    sources_info = "\n".join(
        f"{r.get('source', 'Unknown')}" for r in results[:3]
    )
    yield f"[Sources: {sources_info}]\n\n"

    yield from stream_response(
        query=question,
        context_chunks=results,
        org_name=org_name,
        chat_history=chat_history,
    )

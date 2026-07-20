"""
Core RAG pipeline — orchestrates the full flow:
Query → Embed → Search → Context → LLM → Response
"""
import logging
from rag.embeddings import embed_texts, embed_query
from rag.vector_store import search_similar, insert_vectors, create_tenant_collection
from rag.llm import generate_response, stream_response
from rag.chunker import chunk_text
from rag.document_loader import load_document
from tenants.manager import log_query
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


def ingest_document(tenant_id: str, file_obj, filename: str) -> dict:
    """Full ingestion pipeline: load → chunk → embed → store."""
    # 1. Load document text
    text = load_document(file_obj, filename)

    # 2. Chunk the text
    chunks = chunk_text(text, source=filename)
    if not chunks:
        raise ValueError(f"No content extracted from '{filename}'.")

    # 3-5. Vector operations (Qdrant) — non-fatal if unreachable
    vectors_stored = 0
    try:
        create_tenant_collection(tenant_id)
        texts_to_embed = [c["text"] for c in chunks]
        vectors = embed_texts(texts_to_embed)
        metadatas = [{"source": c["source"], "chunk_index": c["chunk_index"]} for c in chunks]
        insert_vectors(tenant_id, texts_to_embed, vectors, metadatas)
        vectors_stored = len(chunks)
    except Exception as e:
        logger.warning(f"Vector storage failed for '{filename}' (Qdrant unreachable?): {e}")

    logger.info(f"Ingested '{filename}' into tenant '{tenant_id}': {len(chunks)} chunks, {vectors_stored} vectors stored.")
    return {
        "filename": filename,
        "chunks": len(chunks),
        "characters": len(text),
        "vectors_stored": vectors_stored,
    }


def query_rag(
    tenant_id: str,
    question: str,
    org_name: str = "the organization",
    top_k: int = 5,
    chat_history: list[dict] = None,
) -> dict:
    """Full RAG query: embed question → search → generate response."""
    # 1. Embed the query
    query_vector = embed_query(question)

    # 2. Search for relevant chunks
    results = search_similar(tenant_id, query_vector, top_k=top_k)

    if not results:
        return {
            "answer": "I couldn't find relevant information in the knowledge base. Please try rephrasing your question or upload more documents.",
            "sources": [],
            "chunks_found": 0,
        }

    # 3. Generate response with context
    answer = generate_response(
        query=question,
        context_chunks=results,
        org_name=org_name,
        chat_history=chat_history,
    )

    # 4. Log the query for analytics
    sources = [
        {"source": r.get("source", ""), "score": round(r.get("score", 0), 3),
         "excerpt": r.get("text", "")[:200]}
        for r in results
    ]
    try:
        log_query(tenant_id, question, answer, sources, len(results))
    except Exception as e:
        logger.warning(f"Failed to log query: {e}")

    return {
        "answer": answer,
        "sources": sources,
        "chunks_found": len(results),
    }


def query_rag_stream(
    tenant_id: str,
    question: str,
    org_name: str = "the organization",
    top_k: int = 5,
    chat_history: list[dict] = None,
):
    """Streaming version of RAG query."""
    query_vector = embed_query(question)
    results = search_similar(tenant_id, query_vector, top_k=top_k)

    if not results:
        yield "I couldn't find relevant information in the knowledge base."
        return

    # Yield sources first as a JSON-like prefix
    sources_info = "\n".join(
        f"📄 {r.get('source', 'Unknown')}" for r in results[:3]
    )
    yield f"[Sources: {sources_info}]\n\n"

    # Stream the answer
    yield from stream_response(
        query=question,
        context_chunks=results,
        org_name=org_name,
        chat_history=chat_history,
    )

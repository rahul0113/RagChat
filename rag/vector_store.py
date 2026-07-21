"""
Qdrant vector store with multi-tenant isolation.
Each tenant gets their own collection: tenant_{id}
Supports document-level deletion and rich metadata filtering.
"""
import logging
from qdrant_client import QdrantClient
from qdrant_client.models import (
    VectorParams,
    Distance,
    PointStruct,
    Filter,
    FieldCondition,
    MatchValue,
)
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

_client = None


def get_qdrant_client() -> QdrantClient:
    global _client
    if _client is None:
        host = settings.QDRANT_HOST.replace("https://", "").replace("http://", "").rstrip("/")
        if settings.QDRANT_API_KEY:
            _client = QdrantClient(host=host, port=settings.QDRANT_PORT, api_key=settings.QDRANT_API_KEY)
        else:
            _client = QdrantClient(host=host, port=settings.QDRANT_PORT)
        logger.info(f"Connected to Qdrant at {host}:{settings.QDRANT_PORT}")
    return _client


def _collection_name(tenant_id: str) -> str:
    return f"{settings.QDRANT_COLLECTION_PREFIX}{tenant_id}"


def create_tenant_collection(tenant_id: str):
    """Create a vector collection for a tenant."""
    client = get_qdrant_client()
    name = _collection_name(tenant_id)
    try:
        client.get_collection(name)
        logger.info(f"Collection '{name}' already exists.")
    except Exception:
        client.create_collection(
            collection_name=name,
            vectors_config=VectorParams(
                size=settings.EMBEDDING_DIMENSION,
                distance=Distance.COSINE,
            ),
        )
        logger.info(f"Created collection '{name}'.")


def delete_tenant_collection(tenant_id: str):
    """Delete a tenant's entire vector collection."""
    client = get_qdrant_client()
    name = _collection_name(tenant_id)
    try:
        client.delete_collection(name)
        logger.info(f"Deleted collection '{name}'.")
    except Exception:
        pass


def delete_document_vectors(tenant_id: str, document_id: str) -> int:
    """Delete all vectors belonging to a specific document. Returns count deleted."""
    client = get_qdrant_client()
    name = _collection_name(tenant_id)

    try:
        results = client.scroll(
            collection_name=name,
            scroll_filter=Filter(
                must=[
                    FieldCondition(
                        key="document_id",
                        match=MatchValue(value=document_id),
                    )
                ]
            ),
            with_payload=False,
            with_vectors=False,
            limit=10000,
        )
        point_ids = [point.id for point in results[0]]

        if point_ids:
            client.delete(
                collection_name=name,
                points_selector=point_ids,
            )
            logger.info(f"Deleted {len(point_ids)} vectors for document {document_id} in '{name}'.")
            return len(point_ids)
        return 0
    except Exception as e:
        logger.error(f"Failed to delete vectors for document {document_id}: {e}")
        return 0


def insert_vectors(tenant_id: str, texts: list[str], vectors: list[list[float]],
                    metadatas: list[dict]):
    """Insert document chunks into a tenant's collection with rich metadata."""
    client = get_qdrant_client()
    name = _collection_name(tenant_id)

    points = []
    for i, (text, vector, meta) in enumerate(zip(texts, vectors, metadatas)):
        doc_id = meta.get("document_id", "")
        chunk_index = meta.get("chunk_index", i)
        point_id = hash(f"{tenant_id}_{doc_id}_{chunk_index}") % (2**63)

        payload = {"text": text}
        payload.update(meta)

        points.append(PointStruct(
            id=point_id,
            vector=vector,
            payload=payload,
        ))

    batch_size = 100
    for start in range(0, len(points), batch_size):
        client.upsert(
            collection_name=name,
            points=points[start:start + batch_size],
        )

    logger.info(f"Inserted {len(points)} vectors into '{name}'.")


def search_similar(tenant_id: str, query_vector: list[float],
                    top_k: int = 5) -> list[dict]:
    """Search for similar document chunks within a tenant's collection."""
    client = get_qdrant_client()
    name = _collection_name(tenant_id)

    results = client.search(
        collection_name=name,
        query_vector=query_vector,
        limit=top_k,
    )

    return [
        {
            "text": hit.payload.get("text", ""),
            "score": hit.score,
            "source": hit.payload.get("source", ""),
            "document_id": hit.payload.get("document_id", ""),
            "chunk_index": hit.payload.get("chunk_index", 0),
            "page_number": hit.payload.get("page_number", None),
            "section_heading": hit.payload.get("section_heading", ""),
            "language": hit.payload.get("language", ""),
            "upload_timestamp": hit.payload.get("upload_timestamp", ""),
        }
        for hit in results
    ]


def get_all_texts_for_tenant(tenant_id: str) -> list[dict]:
    """Retrieve all text payloads for a tenant (used for BM25 index building)."""
    client = get_qdrant_client()
    name = _collection_name(tenant_id)

    try:
        results, _ = client.scroll(
            collection_name=name,
            with_payload=True,
            with_vectors=False,
            limit=10000,
        )
        return [
            {
                "text": r.payload.get("text", ""),
                "source": r.payload.get("source", ""),
                "document_id": r.payload.get("document_id", ""),
                "chunk_index": r.payload.get("chunk_index", 0),
                "page_number": r.payload.get("page_number", None),
                "section_heading": r.payload.get("section_heading", ""),
            }
            for r in results
        ]
    except Exception as e:
        logger.error(f"Failed to scroll collection '{name}': {e}")
        return []


def get_tenant_stats(tenant_id: str) -> dict:
    """Get collection statistics for a tenant."""
    client = get_qdrant_client()
    name = _collection_name(tenant_id)
    try:
        info = client.get_collection(name)
        return {
            "total_vectors": info.points_count or 0,
            "collection_name": name,
        }
    except Exception:
        return {"total_vectors": 0, "collection_name": name}

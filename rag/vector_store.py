"""
Qdrant vector store with multi-tenant isolation.
Each tenant gets their own collection: tenant_{id}
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
        # Strip protocol and trailing slashes from host
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


def insert_vectors(tenant_id: str, texts: list[str], vectors: list[list[float]],
                    metadatas: list[dict]):
    """Insert document chunks into a tenant's collection."""
    client = get_qdrant_client()
    name = _collection_name(tenant_id)

    points = []
    for i, (text, vector, meta) in enumerate(zip(texts, vectors, metadatas)):
        points.append(PointStruct(
            id=hash(f"{tenant_id}_{meta.get('source', '')}_{i}") % (2**63),
            vector=vector,
            payload={"text": text, **meta},
        ))

    # Upsert in batches of 100
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
        {"text": hit.payload.get("text", ""), "score": hit.score,
         "source": hit.payload.get("source", ""),
         "chunk_index": hit.payload.get("chunk_index", 0),
         **{k: v for k, v in hit.payload.items() if k not in ("text", "source", "chunk_index")}}
        for hit in results
    ]


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

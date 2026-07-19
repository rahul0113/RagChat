"""
Embedding engine using BAAI/bge-large-en-v1.5 (best open-source model).
Runs locally — zero API cost, no rate limits.
"""
import logging
from sentence_transformers import SentenceTransformer
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

_model = None


def get_embedding_model() -> SentenceTransformer:
    global _model
    if _model is None:
        logger.info(f"Loading embedding model: {settings.EMBEDDING_MODEL}")
        _model = SentenceTransformer(settings.EMBEDDING_MODEL)
        logger.info("Embedding model loaded.")
    return _model


def embed_texts(texts: list[str]) -> list[list[float]]:
    """Embed a batch of texts into vectors."""
    model = get_embedding_model()
    embeddings = model.encode(
        texts,
        batch_size=settings.EMBEDDING_BATCH_SIZE,
        show_progress_bar=False,
        normalize_embeddings=True,  # normalize for cosine similarity
    )
    return embeddings.tolist()


def embed_query(query: str) -> list[float]:
    """Embed a single query string."""
    # BGE models use a query prefix for retrieval
    query_with_prefix = f"Represent this sentence for searching relevant passages: {query}"
    return embed_texts([query_with_prefix])[0]

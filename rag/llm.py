"""
Groq LLM client — fast inference with Llama 3 70B (free tier).
"""
import logging
from groq import Groq
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

_client = None


def get_groq_client() -> Groq:
    global _client
    if _client is None:
        if not settings.GROQ_API_KEY:
            raise ValueError("GROQ_API_KEY not set. Get a free key at https://console.groq.com")
        _client = Groq(api_key=settings.GROQ_API_KEY)
        logger.info("Groq client initialized.")
    return _client


SYSTEM_PROMPT = """You are a helpful AI assistant for {org_name}.
You answer questions accurately based on the provided context documents.
If the context doesn't contain enough information to answer, say so honestly.
Be concise, professional, and helpful.
Always cite which document or source your answer comes from when possible."""


def generate_response(
    query: str,
    context_chunks: list[dict],
    org_name: str = "the organization",
    chat_history: list[dict] = None,
) -> str:
    """Generate a response using Groq with RAG context."""

    client = get_groq_client()

    # Build context from retrieved chunks
    context_parts = []
    for i, chunk in enumerate(context_chunks, 1):
        source = chunk.get("source", "Unknown")
        text = chunk.get("text", "")
        context_parts.append(f"[Source {i}: {source}]\n{text}")
    context = "\n\n---\n\n".join(context_parts)

    # Build messages
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT.format(org_name=org_name)},
    ]

    # Add chat history if available
    if chat_history:
        for msg in chat_history[-10:]:  # Keep last 10 messages for context
            messages.append({"role": msg["role"], "content": msg["content"]})

    # Add current query with context
    user_message = f"""Based on the following documents, answer the user's question.

CONTEXT DOCUMENTS:
{context}

USER QUESTION: {query}

Provide a clear, accurate answer. If referencing a source, mention it."""

    messages.append({"role": "user", "content": user_message})

    try:
        response = client.chat.completions.create(
            model=settings.GROQ_MODEL,
            messages=messages,
            temperature=settings.GROQ_TEMPERATURE,
            max_tokens=settings.GROQ_MAX_TOKENS,
            top_p=0.9,
        )
        return response.choices[0].message.content
    except Exception as e:
        logger.error(f"Groq API error: {e}")
        raise


def stream_response(
    query: str,
    context_chunks: list[dict],
    org_name: str = "the organization",
    chat_history: list[dict] = None,
):
    """Stream a response token by token."""
    client = get_groq_client()

    context_parts = []
    for i, chunk in enumerate(context_chunks, 1):
        source = chunk.get("source", "Unknown")
        text = chunk.get("text", "")
        context_parts.append(f"[Source {i}: {source}]\n{text}")
    context = "\n\n---\n\n".join(context_parts)

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT.format(org_name=org_name)},
    ]
    if chat_history:
        for msg in chat_history[-10:]:
            messages.append({"role": msg["role"], "content": msg["content"]})

    user_message = f"""Based on the following documents, answer the user's question.

CONTEXT DOCUMENTS:
{context}

USER QUESTION: {query}

Provide a clear, accurate answer. If referencing a source, mention it."""

    messages.append({"role": "user", "content": user_message})

    stream = client.chat.completions.create(
        model=settings.GROQ_MODEL,
        messages=messages,
        temperature=settings.GROQ_TEMPERATURE,
        max_tokens=settings.GROQ_MAX_TOKENS,
        top_p=0.9,
        stream=True,
    )

    for chunk in stream:
        if chunk.choices[0].delta.content:
            yield chunk.choices[0].delta.content

"""
Groq LLM client — fast inference with Llama 3 70B (free tier).
Supports structured citations, query rewriting, and streaming.
"""
import json
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

IMPORTANT: When citing sources, use the EXACT source identifier provided (e.g., [Source 1: filename.pdf], page N).
Always reference the document name and page number when available."""


REWRITE_PROMPT = """You are a query rewriting assistant. Given a user's question, rewrite it to be more effective for document retrieval.

Rules:
- Preserve the original meaning
- Make it more specific and searchable
- Remove ambiguous references
- Expand abbreviations if context is clear
- Return ONLY the rewritten query, nothing else

Original query: {query}"""


STRUCTURED_CITATION_PROMPT = """You are a helpful AI assistant for {org_name}.
You answer questions based on the provided context documents.

IMPORTANT: You MUST respond with a JSON object in this exact format, nothing else:
{{
  "answer": "Your detailed answer here",
  "citations": [
    {{
      "document": "filename.pdf",
      "page": 12,
      "excerpt": "Relevant text excerpt from the source"
    }}
  ]
}}

Rules:
- Always cite sources in the citations array
- Include the document name and page number when available
- The excerpt should be a relevant quote from the source
- If the context doesn't contain enough info, say so in the answer
- Return ONLY valid JSON, no markdown formatting

CONTEXT DOCUMENTS:
{context}

USER QUESTION: {query}"""


def rewrite_query(query: str) -> str:
    """Rewrite a vague query into a more effective retrieval query."""
    if not settings.QUERY_REWRITING_ENABLED:
        return query

    # Skip rewriting for short, simple queries
    if len(query.split()) <= 3:
        return query

    client = get_groq_client()

    try:
        response = client.chat.completions.create(
            model=settings.GROQ_MODEL,
            messages=[
                {"role": "system", "content": "You are a query rewriting assistant. Return only the rewritten query."},
                {"role": "user", "content": REWRITE_PROMPT.format(query=query)},
            ],
            temperature=0.3,
            max_tokens=200,
        )
        rewritten = response.choices[0].message.content.strip()
        logger.info(f"Query rewritten: '{query}' -> '{rewritten}'")
        return rewritten
    except Exception as e:
        logger.warning(f"Query rewriting failed, using original: {e}")
        return query


def _build_context(context_chunks: list[dict]) -> str:
    """Build context string from retrieved chunks."""
    context_parts = []
    for i, chunk in enumerate(context_chunks, 1):
        source = chunk.get("source", "Unknown")
        page = chunk.get("page_number")
        page_str = f", page {page}" if page else ""
        text = chunk.get("text", "")
        context_parts.append(f"[Source {i}: {source}{page_str}]\n{text}")
    return "\n\n---\n\n".join(context_parts)


def generate_response(
    query: str,
    context_chunks: list[dict],
    org_name: str = "the organization",
    chat_history: list[dict] = None,
) -> str:
    """Generate a response using Groq with RAG context."""
    client = get_groq_client()
    context = _build_context(context_chunks)

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


def generate_structured_response(
    query: str,
    context_chunks: list[dict],
    org_name: str = "the organization",
    chat_history: list[dict] = None,
) -> dict:
    """Generate a structured response with citations as JSON."""
    client = get_groq_client()
    context = _build_context(context_chunks)

    messages = [
        {"role": "system", "content": "You must respond with valid JSON only. No markdown formatting."},
    ]

    if chat_history:
        for msg in chat_history[-10:]:
            messages.append({"role": msg["role"], "content": msg["content"]})

    user_message = STRUCTURED_CITATION_PROMPT.format(
        org_name=org_name, context=context, query=query,
    )
    messages.append({"role": "user", "content": user_message})

    try:
        response = client.chat.completions.create(
            model=settings.GROQ_MODEL,
            messages=messages,
            temperature=settings.GROQ_TEMPERATURE,
            max_tokens=settings.GROQ_MAX_TOKENS,
            top_p=0.9,
        )
        raw = response.choices[0].message.content.strip()

        # Try to extract JSON from response
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]

        result = json.loads(raw)
        return result
    except (json.JSONDecodeError, KeyError) as e:
        logger.warning(f"Failed to parse structured response, falling back: {e}")
        # Fallback: use regular generation
        answer = generate_response(query, context_chunks, org_name, chat_history)
        return {
            "answer": answer,
            "citations": [
                {
                    "document": c.get("source", "Unknown"),
                    "page": c.get("page_number", None),
                    "excerpt": c.get("text", "")[:200],
                }
                for c in context_chunks[:3]
            ],
        }
    except Exception as e:
        logger.error(f"Groq API error in structured response: {e}")
        raise


def stream_response(
    query: str,
    context_chunks: list[dict],
    org_name: str = "the organization",
    chat_history: list[dict] = None,
):
    """Stream a response token by token."""
    client = get_groq_client()
    context = _build_context(context_chunks)

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

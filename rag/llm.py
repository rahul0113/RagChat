"""
Groq LLM client — fast inference with Llama 3 70B (free tier).
Supports structured citations, query rewriting, and streaming.

Improvements:
- Token budgeting to prevent context overflow
- Context deduplication
- Grounded answer validation
- Confidence estimation
"""
import json
import logging
from datetime import datetime, timezone
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
Today's date is {current_date}.

You answer questions accurately based on the provided context documents.
If the context doesn't contain enough information to answer, say so honestly.
Be concise, professional, and helpful.

IMPORTANT RULES:
1. Only use information from the provided context to answer.
2. Do NOT make up or hallucinate information.
3. If the context is insufficient, say "I don't have enough information to answer that question."
4. Always cite your sources using [Source N] format.
5. Be concise but complete."""


REWRITE_PROMPT = """You are a query rewriting assistant. Given a user's question, rewrite it to be more effective for document retrieval.

Rules:
- Preserve the original meaning
- Make it more specific and searchable
- Remove ambiguous references
- Expand abbreviations if context is clear
- Return ONLY the rewritten query, nothing else

Original query: {query}"""


STRUCTURED_CITATION_PROMPT = """You are a helpful AI assistant for {org_name}.
Today's date is {current_date}.
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
  ],
  "confidence": "high" | "medium" | "low",
  "grounded": true | false
}}

Rules:
- Only cite documents that actually support your answer
- Set "grounded": true only if the answer is fully supported by the context
- Set "confidence" based on how well the context supports the answer
- If context is insufficient, set "confidence": "low" and explain what's missing
- NEVER make up information not in the context

Context:
{context}

Question: {query}"""


def rewrite_query(query: str) -> str:
    """Rewrite a query for better retrieval."""
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


def _estimate_tokens(text: str) -> int:
    """Estimate token count (rough: 1 token ≈ 4 characters)."""
    return len(text) // 4


def _deduplicate_chunks(context_chunks: list[dict]) -> list[dict]:
    """Remove near-duplicate chunks from context."""
    seen_texts = set()
    unique_chunks = []

    for chunk in context_chunks:
        text = chunk.get("text", "").strip()
        # Normalize text for comparison
        normalized = " ".join(text.lower().split())
        # Use first 200 chars as dedup key
        key = normalized[:200]

        if key not in seen_texts:
            seen_texts.add(key)
            unique_chunks.append(chunk)

    return unique_chunks


def _fit_to_token_budget(
    context_chunks: list[dict],
    max_tokens: int = 6000,
    system_prompt_tokens: int = 200,
    query_tokens: int = 100,
) -> list[dict]:
    """Fit context chunks within token budget, prioritizing by score."""
    available_tokens = max_tokens - system_prompt_tokens - query_tokens

    # Sort by score (highest first)
    sorted_chunks = sorted(context_chunks, key=lambda x: x.get("score", 0), reverse=True)

    selected = []
    used_tokens = 0

    for chunk in sorted_chunks:
        text = chunk.get("text", "")
        chunk_tokens = _estimate_tokens(text)

        if used_tokens + chunk_tokens <= available_tokens:
            selected.append(chunk)
            used_tokens += chunk_tokens
        else:
            # Try to fit a truncated version
            remaining_tokens = available_tokens - used_tokens
            if remaining_tokens > 100:  # Minimum useful chunk
                truncated_text = text[:remaining_tokens * 4]  # 4 chars per token
                truncated_chunk = chunk.copy()
                truncated_chunk["text"] = truncated_text + "..."
                truncated_chunk["truncated"] = True
                selected.append(truncated_chunk)
            break

    logger.info(f"Token budget: {used_tokens}/{available_tokens} tokens used, {len(selected)}/{len(context_chunks)} chunks selected")
    return selected


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

    # Deduplicate and fit to token budget
    unique_chunks = _deduplicate_chunks(context_chunks)
    budgeted_chunks = _fit_to_token_budget(unique_chunks)

    context = _build_context(budgeted_chunks)
    current_date = datetime.now(timezone.utc).strftime("%A, %B %d, %Y")

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT.format(org_name=org_name, current_date=current_date)},
    ]

    if chat_history:
        for msg in chat_history[-10:]:
            messages.append({"role": msg["role"], "content": msg["content"]})

    messages.append({"role": "user", "content": f"Context:\n{context}\n\nQuestion: {query}"})

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

    # Deduplicate and fit to token budget
    unique_chunks = _deduplicate_chunks(context_chunks)
    budgeted_chunks = _fit_to_token_budget(unique_chunks)

    context = _build_context(budgeted_chunks)
    current_date = datetime.now(timezone.utc).strftime("%A, %B %d, %Y")

    messages = [
        {"role": "system", "content": "You must respond with valid JSON only. No markdown formatting."},
    ]

    if chat_history:
        for msg in chat_history[-10:]:
            messages.append({"role": msg["role"], "content": msg["content"]})

    user_message = STRUCTURED_CITATION_PROMPT.format(
        org_name=org_name, context=context, query=query, current_date=current_date,
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
            "citations": [],
            "confidence": "low",
            "grounded": False,
        }


def stream_response(
    query: str,
    context_chunks: list[dict],
    org_name: str = "the organization",
    chat_history: list[dict] = None,
):
    """Stream a response token by token."""
    client = get_groq_client()

    # Deduplicate and fit to token budget
    unique_chunks = _deduplicate_chunks(context_chunks)
    budgeted_chunks = _fit_to_token_budget(unique_chunks)

    context = _build_context(budgeted_chunks)
    current_date = datetime.now(timezone.utc).strftime("%A, %B %d, %Y")

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT.format(org_name=org_name, current_date=current_date)},
    ]

    if chat_history:
        for msg in chat_history[-10:]:
            messages.append({"role": msg["role"], "content": msg["content"]})

    messages.append({"role": "user", "content": f"Context:\n{context}\n\nQuestion: {query}"})

    try:
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

    except Exception as e:
        logger.error(f"Streaming error: {e}")
        yield f"Error: {e}"

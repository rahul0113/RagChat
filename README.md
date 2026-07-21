# RagChat

White-label RAG (Retrieval-Augmented Generation) SaaS platform. Build AI chatbots for any organization — sell to multiple clients with isolated data, custom themes, and a single embed code.

**Live Backend:** `https://ragchat-tsqf.onrender.com`

## Architecture

```
Client Website ←→ Glassmorphic Chat Widget ←→ FastAPI Backend ←→ Qdrant Cloud (vectors) + Groq LLM
                                                ↕                    ↕
                                     Background Workers      Hybrid Search + Reranker
                                                ↕                    ↕
                                         Flutter Admin       Semantic Cache + OCR
```

| Component | Technology | Why |
|-----------|-----------|-----|
| LLM | Groq Llama 3 70B | Free tier, fastest inference |
| Embeddings | BAAI/bge-large-en-v1.5 | Best open-source, lazy-loaded to save memory |
| Vector DB | Qdrant Cloud | Production-grade, native multi-tenancy |
| Hybrid Search | BM25 + Vector (RRF) | Best of keyword + semantic retrieval |
| Reranker | Cross-encoder/ms-marco | Higher precision after retrieval |
| Backend | FastAPI + SQLite | Async, auto-docs, simple persistence |
| Admin | Flutter | Cross-platform (Android APK, Web) |
| Chat Widget | Vanilla JS | Embeddable, glassmorphic UI |
| Hosting | Render (free tier) | Zero-cost deployment |

## Features

### Core
- **Multi-tenant**: Each client gets isolated vector collections, API keys, and themes
- **Document ingestion**: PDF, DOCX, TXT, HTML, CSV, Markdown, JSON
- **Document-level deletion**: Remove individual documents and their vectors
- **Rich metadata**: Page numbers, section headings, language detection, timestamps
- **Smart chunking**: Paragraph-aware, sentence-preserving, heading-aware with configurable size/overlap
- **Structured citations**: Source document + page + excerpt in responses

### Retrieval Quality
- **Hybrid search**: Vector similarity + BM25 keyword search with Reciprocal Rank Fusion
- **Query rewriting**: LLM-based query expansion for better retrieval
- **Cross-encoder reranking**: Higher precision with dedicated reranking model
- **Semantic cache**: Repeated queries served from embedding-similarity cache

### Ingestion
- **OCR support**: Text extraction from scanned PDFs (Tesseract/EasyOCR)
- **Website import**: Crawl entire websites with sitemap support, depth control, deduplication

### Infrastructure
- **Background jobs**: Heavy operations (embedding, crawling, OCR) run asynchronously
- **Performance analytics**: Retrieval time, embedding time, LLM latency, cache hit rates
- **Structured logging**: Ingestion, retrieval, Qdrant, LLM operations tracked

### Widget & Admin
- **Glassmorphic chat widget**: Embeddable via single `<script>` tag
- **Theme customization**: Per-client colors, gradients, blur effects
- **Flutter admin dashboard**: Manage tenants, upload docs, view analytics
- **Dark + Light mode**: Full theme support with accent color picker
- **Mobile-optimized**: All screens responsive for phone/tablet

## Quick Start

### Backend (local development)

```bash
cd RagChat
cp .env.example .env
# Add your GROQ_API_KEY (free at https://console.groq.com)
# Add your QDRANT_HOST, QDRANT_PORT, QDRANT_API_KEY (free at https://cloud.qdrant.io)

pip install -r requirements.txt
python main.py
# Server runs at http://localhost:8000
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GROQ_API_KEY` | `""` | Groq API key (free) |
| `GROQ_MODEL` | `llama3-70b-8192` | LLM model |
| `QDRANT_HOST` | `localhost` | Qdrant host |
| `QDRANT_PORT` | `6333` | Qdrant port |
| `QDRANT_API_KEY` | `""` | Qdrant Cloud API key |
| `BACKEND_URL` | `""` | Your deployed URL for embed codes |
| `CHUNK_SIZE` | `512` | Characters per chunk |
| `CHUNK_OVERLAP` | `64` | Overlap between chunks |
| `HYBRID_SEARCH_ENABLED` | `true` | Enable hybrid vector + BM25 search |
| `HYBRID_ALPHA` | `0.7` | 1.0=vector, 0.0=keyword |
| `RERANKING_ENABLED` | `true` | Enable cross-encoder reranking |
| `QUERY_REWRITING_ENABLED` | `true` | Enable LLM query rewriting |
| `SEMANTIC_CACHE_ENABLED` | `true` | Enable semantic cache |
| `SEMANTIC_CACHE_PERSIST` | `true` | Persist cache to disk |
| `SEMANTIC_CACHE_DIR` | `./cache` | Cache storage directory |
| `OCR_ENABLED` | `true` | Enable OCR for scanned PDFs |
| `BACKGROUND_JOBS_ENABLED` | `true` | Enable background workers |

### Flutter Admin

```bash
cd RagChat/admin
flutter pub get
flutter run -d chrome    # Web
flutter run              # Default device
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/chat/{slug}` | Chat with tenant's knowledge base |
| POST | `/api/chat/{slug}/stream` | Streaming chat |
| GET | `/api/widget/{slug}/config` | Widget theme config |
| POST | `/api/admin/tenants` | Create tenant |
| GET | `/api/admin/tenants` | List tenants |
| GET | `/api/admin/tenants/{id}` | Tenant details |
| PUT | `/api/admin/tenants/{id}/theme` | Update theme |
| DELETE | `/api/admin/tenants/{id}` | Delete tenant |
| POST | `/api/admin/tenants/{id}/upload` | Upload document |
| GET | `/api/admin/tenants/{id}/documents` | List documents |
| DELETE | `/api/admin/tenants/{id}/documents/{doc_id}` | Delete document |
| POST | `/api/admin/tenants/{id}/crawl` | Crawl website |
| GET | `/api/admin/analytics/summary` | Dashboard stats |
| GET | `/api/admin/analytics/top-queries` | Top queries |
| GET | `/api/admin/analytics/recent` | Recent queries |
| GET | `/api/admin/queries/{id}` | Query detail |
| POST | `/api/admin/analytics/export` | Export CSV |
| DELETE | `/api/admin/queries/{id}` | Delete query |
| POST | `/api/admin/cache/clear` | Clear semantic cache |
| GET | `/api/admin/cache/stats` | Cache statistics |
| GET | `/api/admin/jobs` | Background job status |
| GET | `/api/admin/unanswered` | Unanswered questions list |
| GET | `/api/admin/tenants/{id}/documents/status` | Ingestion status per document |
| GET | `/api/health` | Health check (with system status) |

Full interactive docs at `/docs` when the server is running.

## Embedding the Widget

```html
<script src="https://ragchat-tsqf.onrender.com/widget/static/widget.js"
        data-tenant-slug="your-client-slug"></script>
```

## Project Structure

```
RagChat/
├── main.py                    # FastAPI entry point
├── config.py                  # Settings from .env
├── requirements.txt           # Python dependencies
├── .env                       # Secrets (QDRANT, GROQ keys)
├── rag/                       # RAG pipeline
│   ├── pipeline.py            # Core orchestrator
│   ├── embeddings.py          # BGE-large-en-v1.5 (lazy-loaded)
│   ├── vector_store.py        # Qdrant multi-tenant + document deletion
│   ├── llm.py                 # Groq Llama 3 70B + query rewriting
│   ├── chunker.py             # Smart chunking (heading-aware)
│   ├── document_loader.py     # Multi-format + OCR + metadata
│   ├── hybrid_search.py       # BM25 + vector search (RRF fusion)
│   ├── reranker.py            # Cross-encoder reranking
│   ├── cache.py               # Semantic cache (embedding similarity + disk persistence)
│   ├── ocr.py                 # PDF/image OCR (Tesseract/EasyOCR)
│   ├── web_crawler.py         # Website import + sitemap parsing
│   ├── jobs.py                # Background job manager (with retry + status tracking)
│   ├── metadata.py            # Shared metadata builder (single source of truth)
│   └── monitoring.py          # Structured logging + health checks
├── migrate.py                 # Database schema migration helper
├── tenants/                   # Tenant management
│   ├── models.py              # SQLite DB + Document + UnansweredQuestion
│   └── manager.py             # CRUD + analytics + ingestion status + unanswered tracking
├── api/routes.py              # All REST endpoints
├── widget/static/widget.js    # Glassmorphic chat widget
├── admin/                     # Flutter dashboard
│   ├── lib/
│   │   ├── main.dart           # App entry + global theme state
│   │   ├── screens/            # Landing, Dashboard, Tenants, Tenant Detail,
│   │   │                       # Documents, Analytics, Settings, Query Detail
│   │   ├── widgets/            # Sidebar, stat cards, tenant cards
│   │   ├── services/           # API service, auth, error handler
│   │   └── theme/              # Dark + light glassmorphic theme
│   └── pubspec.yaml
└── .github/workflows/         # CI/CD
    └── flutter-admin.yml      # Build web + APK on push
```

## Deploy to Render (Free)

### Prerequisites
1. GitHub account with this repo
2. Qdrant Cloud account (free 1 GB) — https://cloud.qdrant.io
3. Groq API key (free) — https://console.groq.com

### Steps
1. Go to https://render.com → Sign up with GitHub
2. Click **New** → **Web Service**
3. Connect GitHub repo: `rahul0113/RagChat`
4. Configure:
   - **Name**: `ragchat`
   - **Runtime**: Python 3
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
   - **Instance**: Free
5. Add **Environment Variables**:
   - `GROQ_API_KEY` = your Groq key
   - `QDRANT_HOST` = your Qdrant Cloud cluster URL (e.g. `xxx.qdrant.io`)
   - `QDRANT_PORT` = `6333`
   - `QDRANT_API_KEY` = your Qdrant Cloud API key
   - `BACKEND_URL` = `https://ragchat-tsqf.onrender.com` (your Render URL)
6. Click **Create Web Service**
7. Your app is live at `https://ragchat-tsqf.onrender.com`

### APK

The Android APK works out of the box — the backend URL is pre-configured. Install and start using immediately.

Download from GitHub Releases or build from `admin/` with:
```bash
cd admin
flutter build apk --release
```

## Ingestion Status

Documents track ingestion progress through these states:

| Status | Description |
|--------|-------------|
| `pending` | Document uploaded, waiting to be processed |
| `processing` | Currently being chunked and embedded |
| `completed` | Successfully indexed and searchable |
| `failed` | Ingestion failed (see `failure_reason`) |

Check status via `GET /api/admin/tenants/{id}/documents/status`.

## Unanswered Questions

When the system can't find relevant context or confidence is low, the question is logged as unanswered. This helps identify gaps in your knowledge base.

- **Fallback reasons**: `no_results`, `low_confidence`, `insufficient_context`
- **View via**: `GET /api/admin/unanswered`
- **Tracked in analytics**: `total_unanswered` and `unanswered_rate` fields

## Retrieval Quality Signals

Every response includes a `quality_signals` object:

```json
{
  "rewrite_used": true,
  "search_mode": "hybrid",
  "chunks_retrieved": 20,
  "reranker_used": true,
  "reranked_count": 5,
  "final_context_size": 1250,
  "fallback_reason": null,
  "insufficient_context": false,
  "top_score": 0.87
}
```

## Migration

After pulling new code, run the schema migration:

```bash
python migrate.py
```

This adds ingestion status columns and the unanswered questions table. Safe to run multiple times.

## New Dependencies

| Package | Purpose | Why |
|---------|---------|-----|
| `rank-bm25` | BM25 keyword search | Fast, lightweight BM25 implementation for hybrid search |
| `pytesseract` | OCR engine | Tesseract wrapper for scanned PDF text extraction |
| `Pillow` | Image processing | Required by pytesseract for image handling |
| `httpx` | Async HTTP client | Web crawler with better performance than requests |
| `langdetect` | Language detection | Auto-detect document language for metadata |

## License

MIT

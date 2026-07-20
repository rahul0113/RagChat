
# RagChat

White-label RAG (Retrieval-Augmented Generation) SaaS platform. Build AI chatbots for any organization — sell to multiple clients with isolated data, custom themes, and a single embed code.

**Live Backend:** `https://ragchat-tsqf.onrender.com`

## Architecture

```
Client Website ←→ Glassmorphic Chat Widget ←→ FastAPI Backend ←→ Qdrant Cloud (vectors) + Groq LLM
                                                                      ↕
                                                          Flutter Admin Dashboard (APK/Web)
```

| Component | Technology | Why |
|-----------|-----------|-----|
| LLM | Groq Llama 3 70B | Free tier, fastest inference |
| Embeddings | BAAI/bge-large-en-v1.5 | Best open-source, lazy-loaded to save memory |
| Vector DB | Qdrant Cloud | Production-grade, native multi-tenancy |
| Backend | FastAPI + SQLite | Async, auto-docs, simple persistence |
| Admin | Flutter | Cross-platform (Android APK, Web) |
| Chat Widget | Vanilla JS | Embeddable, glassmorphic UI |
| Hosting | Render (free tier) | Zero-cost deployment |

## Features

- **Multi-tenant**: Each client gets isolated vector collections, API keys, and themes
- **Document ingestion**: PDF, DOCX, TXT, HTML, CSV, Markdown, JSON
- **Smart chunking**: Paragraph-aware with overlap for better retrieval
- **Glassmorphic chat widget**: Embeddable via single `<script>` tag
- **Theme customization**: Per-client colors, gradients, blur effects
- **Flutter admin dashboard**: Manage tenants, upload docs, view analytics
- **Query analytics**: Top queries, usage trends, export to CSV
- **Landing screen**: Animated startup sequence with onboarding
- **Global error handling**: Popup dialogs for network, server, and validation errors
- **Dark + Light mode**: Full theme support with accent color picker
- **Mobile-optimized**: All screens responsive for phone/tablet
- **Pre-configured APK**: Works out of the box with no setup required

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
| GET | `/api/admin/analytics/summary` | Dashboard stats |
| GET | `/api/admin/analytics/top-queries` | Top queries |
| GET | `/api/admin/analytics/recent` | Recent queries |
| POST | `/api/admin/analytics/export` | Export CSV |
| DELETE | `/api/admin/queries/{id}` | Delete query |
| GET | `/api/health` | Health check |

Full interactive docs at `/docs` when the server is running.

## Embedding the Widget

```html
<script src="https://ragchat-tsqf.onrender.com/widget/static/widget.js"
        data-tenant-slug="your-client-slug"></script>
```

## Selling to Clients

1. Create a tenant via admin dashboard or API
2. Upload their documents
3. Customize theme (colors, gradient, blur)
4. Give them the embed code
5. Done — their data is fully isolated

## Project Structure

```
RagChat/
├── main.py                    # FastAPI entry point
├── config.py                  # Settings from .env
├── requirements.txt           # Python dependencies (unpinned for Render compat)
├── Dockerfile                 # Container config for Render
├── .env                       # Secrets (QDRANT, GROQ keys)
├── rag/                       # RAG pipeline
│   ├── pipeline.py            # Core orchestrator
│   ├── embeddings.py          # BGE-large-en-v1.5 (lazy-loaded)
│   ├── vector_store.py        # Qdrant multi-tenant
│   ├── llm.py                 # Groq Llama 3 70B
│   ├── chunker.py             # Smart chunking
│   └── document_loader.py     # Multi-format loader
├── tenants/                   # Tenant management
│   ├── models.py              # SQLite DB + QueryLog
│   └── manager.py             # CRUD + analytics
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

## License

MIT

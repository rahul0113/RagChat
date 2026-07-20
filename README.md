
# RagChat

White-label RAG (Retrieval-Augmented Generation) SaaS platform. Build AI chatbots for any organization — sell to multiple clients with isolated data, custom themes, and a single embed code.

## Architecture

```
Client Website ←→ Glassmorphic Chat Widget ←→ FastAPI Backend ←→ Qdrant (vectors) + Groq LLM
                                                                   ↕
                                                        Flutter Admin Dashboard
```

| Component | Technology | Why |
|-----------|-----------|-----|
| LLM | Groq Llama 3 70B | Free tier, fastest inference |
| Embeddings | BAAI/bge-large-en-v1.5 | Best open-source, runs locally |
| Vector DB | Qdrant | Production-grade, native multi-tenancy |
| Backend | FastAPI | Async, fast, auto-docs |
| Admin | Flutter | Cross-platform (Web, Android, iOS, Desktop) |
| Chat Widget | Vanilla JS | Embeddable, glassmorphic UI |

## Features

- **Multi-tenant**: Each client gets isolated vector collections, API keys, and themes
- **Document ingestion**: PDF, DOCX, TXT, HTML, CSV, Markdown, JSON
- **Smart chunking**: Paragraph-aware with overlap for better retrieval
- **Glassmorphic chat widget**: Embeddable via single `<script>` tag
- **Theme customization**: Per-client colors, gradients, blur effects
- **Flutter admin dashboard**: Manage tenants, upload docs, view analytics
- **Query analytics**: Top queries, usage trends, export to CSV
- **CI/CD**: GitHub Actions builds web + APK on every push

## Quick Start

### Backend

```bash
cd RagChat
cp .env.example .env
# Add your GROQ_API_KEY (free at https://console.groq.com)

pip install -r requirements.txt

# Start Qdrant
docker run -d -p 6333:6333 qdrant/qdrant

# Start server
python main.py
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
| GET | `/api/widget/{slug}/config` | Widget theme config |
| POST | `/api/admin/tenants` | Create tenant |
| GET | `/api/admin/tenants` | List tenants |
| GET | `/api/admin/tenants/{id}` | Tenant details |
| PUT | `/api/admin/tenants/{id}/theme` | Update theme |
| DELETE | `/api/admin/tenants/{id}` | Delete tenant |
| POST | `/api/admin/tenants/{id}/upload` | Upload document |
| GET | `/api/admin/analytics/summary` | Dashboard stats |
| GET | `/api/admin/analytics/top-queries` | Top queries |
| POST | `/api/admin/analytics/export` | Export CSV |
| DELETE | `/api/admin/queries/{id}` | Delete query |

## Embedding the Widget

```html
<script src="YOUR_DOMAIN/widget/static/widget.js"
        data-tenant-slug="your-client-slug"></script>
```

## Selling to Clients

1. Create a tenant via admin dashboard or API
2. Upload their documents (500-600+ supported)
3. Customize theme (colors, gradient, blur)
4. Give them the embed code
5. Done — their data is fully isolated

## Project Structure

```
RagChat/
├── main.py                    # FastAPI entry point
├── config.py                  # Settings from .env
├── requirements.txt
├── rag/                       # RAG pipeline
│   ├── pipeline.py            # Core orchestrator
│   ├── embeddings.py          # BGE-large-en-v1.5
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
│   │   ├── screens/           # 7 screens
│   │   ├── widgets/           # Sidebar, cards
│   │   ├── services/          # API + Auth
│   │   └── theme/             # Dark glassmorphic theme
│   └── pubspec.yaml
└── .github/workflows/         # CI/CD
    └── flutter-admin.yml
```

## Deploy to Koyeb (Free, No Sleep)

### Prerequisites
1. GitHub account with this repo
2. Qdrant Cloud account (free 1 GB) — https://cloud.qdrant.io
3. Groq API key (free) — https://console.groq.com

### Steps
1. Go to https://www.koyeb.com → Sign up with GitHub
2. Click **Create App** → **Git**
3. Select your `RagChat` repo
4. Configure:
   - **Name**: `ragchat`
   - **Port**: `7860`
   - **Instance**: Nano (free)
5. Add **Environment Variables**:
   - `GROQ_API_KEY` = your Groq key
   - `QDRANT_HOST` = your Qdrant Cloud cluster URL
   - `QDRANT_PORT` = 6333
   - `QDRANT_API_KEY` = your Qdrant Cloud API key
   - `BACKEND_URL` = `https://ragchat-app.koyeb.app` (your Koyeb URL)
6. Click **Deploy**
7. Your app is live at `https://ragchat-app.koyeb.app`

### Connect Flutter Admin
In the app, go to Settings → API Configuration and paste:
```
https://ragchat-app.koyeb.app/api
```

## License

MIT

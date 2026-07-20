FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for document processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py config.py ./
COPY api/ ./api/
COPY rag/ ./rag/
COPY tenants/ ./tenants/
COPY widget/ ./widget/

# Create uploads directory
RUN mkdir -p uploads

# Koyeb auto-assigns PORT env var
ENV PORT=7860
EXPOSE $PORT

CMD sh -c "uvicorn main:app --host 0.0.0.0 --port $PORT"

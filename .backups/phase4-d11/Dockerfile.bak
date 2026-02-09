# ─── Build stage ───────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

# Install system deps for building Python packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --prefix=/install .

# ─── Runtime stage ─────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

LABEL maintainer="Psitta <team@psitta.dev>"
LABEL description="Psitta API & worker runtime"

# Install runtime-only system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 tesseract-ocr curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r psitta && useradd -r -g psitta psitta

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY src/ /app/src/

# Set Python path
ENV PYTHONPATH=/app/src
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Non-root user
USER psitta

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

# Default: run the API (override in docker-compose for worker)
CMD ["uvicorn", "psitta.main:create_app", "--factory", \
     "--host", "0.0.0.0", "--port", "8000"]

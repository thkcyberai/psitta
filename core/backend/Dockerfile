# ══════════════════════════════════════════════════════════════════════
# Psitta — Multi-Stage Dockerfile
#
# Stages:
#   builder  — Install dependencies, run linting (used by CI + migrate)
#   runtime  — Minimal production image with only runtime deps
#
# Build:
#   docker build -t psitta-api --target runtime core/backend/
#
# Security:
#   - Non-root user (appuser:1001)
#   - Minimal packages in runtime
#   - Pip cache purged after install
#   - .dockerignore excludes tests, docs, local envs
# ══════════════════════════════════════════════════════════════════════

# ── Builder Stage ────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app

# System deps for building Python packages with C extensions
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies first (cache layer)
COPY pyproject.toml README.md ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir ".[dev]"

# Copy source
COPY alembic.ini ./
COPY src/ ./src/
COPY tests/ ./tests/

# ── Runtime Stage ────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

WORKDIR /app

# Runtime-only system deps
# - poppler-utils provides pdftoppm (required by pdf2image)
# - tesseract-ocr provides OCR engine for scanned PDFs
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libpq5 \
        curl \
        poppler-utils \
        tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -g 1001 appuser && \
    useradd -r -u 1001 -g appuser appuser

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application source
COPY --from=builder /app/alembic.ini ./
COPY --from=builder /app/src/ ./src/

# Set Python path
ENV PYTHONPATH=/app/src
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Switch to non-root user
USER appuser

EXPOSE 8000

# Default command — override in docker-compose.yml
CMD ["uvicorn", "psitta.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000"]

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

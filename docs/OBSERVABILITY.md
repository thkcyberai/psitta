# Observability

This document describes Psitta's approach to logging, distributed tracing, metrics, and alerting.

## Three Pillars

```
┌─────────────────────────────────────────────────┐
│                  Observability                   │
├────────────────┬────────────────┬────────────────┤
│     Logs       │    Traces      │    Metrics     │
│  (structlog)   │  (OpenTelemetry│  (Prometheus)  │
│                │   + Jaeger)    │                │
└────────────────┴────────────────┴────────────────┘
```

## Structured Logging

Psitta uses `structlog` for JSON-structured logs with automatic context binding.

### Log Format

Every log line includes these fields:

```json
{
  "timestamp": "2025-01-15T10:30:45.123Z",
  "level": "info",
  "event": "document.processed",
  "request_id": "req_a1b2c3d4",
  "user_id": "user_abc123",
  "method": "POST",
  "path": "/api/v1/documents",
  "duration_ms": 1523,
  "document_id": "doc_xyz789",
  "page_count": 42,
  "chunk_count": 156
}
```

### Context Propagation

The `RequestIDMiddleware` automatically binds `request_id`, `method`, and `path` to structlog's context variables. All subsequent log calls within that request include these fields without explicit passing.

```python
# In any service or provider — context is automatic
import structlog
logger = structlog.get_logger()

async def process_document(document_id: str):
    logger.info("document.processing_started", document_id=document_id)
    # ... processing ...
    logger.info("document.processing_complete",
                document_id=document_id,
                chunk_count=len(chunks),
                duration_ms=elapsed)
```

### Log Levels

| Level | Usage | Examples |
|-------|-------|---------|
| `debug` | Detailed flow tracing | SQL queries, cache hits/misses, provider calls |
| `info` | Business events | Document uploaded, playback started, voice created |
| `warning` | Recoverable issues | Rate limit approached, retry triggered, slow query |
| `error` | Failures requiring attention | Provider timeout, migration failure, auth error |

### Sensitive Data

Never log these fields:
- Authentication tokens or API keys
- File contents or audio data
- User passwords or personal information
- Full stack traces in production (use `error` level with exception ID)

## Distributed Tracing

### OpenTelemetry Integration

Psitta instruments all request paths with OpenTelemetry spans:

```
HTTP Request
└── api.upload_document
    ├── storage.upload_file (S3)
    ├── db.insert_document (PostgreSQL)
    └── queue.enqueue_job (Redis Streams)
        └── worker.process_document
            ├── parser.extract_text
            ├── chunker.split_document
            ├── vision.describe_images (Anthropic)
            ├── tone.classify_chunks
            └── tts.synthesize_batch (Azure)
                ├── tts.synthesize_chunk[0]
                ├── tts.synthesize_chunk[1]
                └── tts.synthesize_chunk[N]
```

### Trace Context

The `X-Request-ID` header propagates through all services. For worker jobs, the request ID from the originating API call is stored in the job payload and restored when the worker picks up the job.

### Configuration

```bash
# .env
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
OTEL_SERVICE_NAME=psitta-api
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1     # Sample 10% in production
```

### Local Development

For local tracing, add Jaeger to your Docker Compose:

```yaml
# docker-compose.override.yml
services:
  jaeger:
    image: jaegertracing/all-in-one:1.54
    ports:
      - "16686:16686"   # Jaeger UI
      - "4317:4317"     # OTLP gRPC
    environment:
      COLLECTOR_OTLP_ENABLED: true
```

Then visit `http://localhost:16686` to explore traces.

## Metrics

### Key Metrics

**API Metrics**

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `http_requests_total` | Counter | method, path, status | Total HTTP requests |
| `http_request_duration_seconds` | Histogram | method, path | Request latency |
| `http_requests_in_flight` | Gauge | — | Concurrent requests |

**Document Processing**

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `documents_uploaded_total` | Counter | source_type | Documents uploaded |
| `documents_processed_total` | Counter | status | Processing outcomes |
| `document_processing_duration_seconds` | Histogram | source_type | Processing time |
| `document_chunks_created_total` | Counter | content_type | Chunks generated |

**TTS**

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `tts_requests_total` | Counter | provider, voice_id | TTS API calls |
| `tts_request_duration_seconds` | Histogram | provider | TTS latency |
| `tts_cache_hits_total` | Counter | — | Audio cache hits |
| `tts_cache_misses_total` | Counter | — | Audio cache misses |
| `tts_characters_total` | Counter | provider | Characters synthesized |

**Playback**

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `playback_sessions_active` | Gauge | — | Active playback sessions |
| `playback_started_total` | Counter | — | Sessions started |
| `playback_completed_total` | Counter | — | Sessions completed (100%) |

**Infrastructure**

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `db_pool_active_connections` | Gauge | — | Active DB connections |
| `redis_connected` | Gauge | — | Redis connectivity |
| `s3_operations_total` | Counter | operation | S3 get/put/delete |
| `job_queue_depth` | Gauge | job_type | Pending jobs |
| `job_processing_duration_seconds` | Histogram | job_type | Job execution time |

### Prometheus Endpoint

Metrics are exposed at `GET /metrics` in Prometheus format. This endpoint is excluded from authentication and rate limiting.

## Alerting

### Recommended Alert Rules

**Critical (Page immediately)**

```yaml
- alert: APIDown
  expr: up{job="psitta-api"} == 0
  for: 1m

- alert: ErrorRateHigh
  expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
  for: 5m

- alert: DatabaseDown
  expr: pg_up == 0
  for: 30s
```

**Warning (Investigate within hours)**

```yaml
- alert: HighLatency
  expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
  for: 10m

- alert: QueueBacklog
  expr: job_queue_depth > 100
  for: 15m

- alert: TTSErrorRate
  expr: rate(tts_requests_total{status="error"}[10m]) > 0.1
  for: 10m

- alert: DiskSpaceWarning
  expr: node_filesystem_avail_bytes{mountpoint="/data"} / node_filesystem_size_bytes < 0.15
  for: 30m
```

### Dashboards

Recommended Grafana dashboards (importable JSON in `docs/dashboards/`):

1. **API Overview** — Request rate, latency percentiles, error rate, active connections
2. **Document Pipeline** — Upload rate, processing duration, queue depth, failure rate
3. **TTS Performance** — Provider latency, cache hit ratio, character consumption, cost estimate
4. **Infrastructure** — Database connections, Redis memory, S3 operations, container resource usage

## Health Checks

### Endpoints

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `GET /health` | No | Shallow liveness (returns 200 if process is running) |
| `GET /health/ready` | No | Deep readiness (checks DB, Redis, S3 connectivity) |

### Readiness Check Response

```json
{
  "status": "healthy",
  "version": "0.1.0",
  "checks": {
    "database": {"status": "healthy", "latency_ms": 2},
    "redis": {"status": "healthy", "latency_ms": 1},
    "storage": {"status": "healthy", "latency_ms": 15}
  }
}
```

If any check fails, status becomes `"degraded"` and HTTP status is 503.

## Runbook Quick Reference

| Symptom | Check First | Likely Cause |
|---------|------------|-------------|
| 503 on all requests | `GET /health/ready` | Database or Redis down |
| Slow document processing | Queue depth metric + worker logs | Worker backlog or provider throttling |
| Audio not playing | TTS error rate metric | Azure TTS quota exceeded |
| High memory usage (API) | `db_pool_active_connections` | Connection leak or missing pool limits |
| High memory usage (Worker) | Worker logs for document ID | Large document (>200 pages) |

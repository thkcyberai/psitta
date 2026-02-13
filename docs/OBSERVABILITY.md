# Psitta — Observability Guide

## 1. Overview

Psitta uses three pillars of observability: structured logging, distributed tracing, and metrics. All telemetry flows through OpenTelemetry (OTel) for vendor-neutral collection and export.
```
┌────────────┐    ┌────────────┐    ┌────────────┐
│  Logs      │    │  Traces    │    │  Metrics   │
│ (structlog)│    │ (OTel SDK) │    │ (OTel SDK) │
└─────┬──────┘    └─────┬──────┘    └─────┬──────┘
      │                 │                 │
      ▼                 ▼                 ▼
┌─────────────────────────────────────────────────┐
│          OpenTelemetry Collector (OTel)          │
└─────┬──────────────┬──────────────┬─────────────┘
      │              │              │
      ▼              ▼              ▼
┌──────────┐  ┌────────────┐  ┌───────────┐
│ Loki /   │  │ Jaeger /   │  │Prometheus │
│CloudWatch│  │ Tempo      │  │           │
└──────────┘  └────────────┘  └───────────┘
      │              │              │
      └──────────────┼──────────────┘
                     ▼
              ┌────────────┐
              │  Grafana   │
              └────────────┘
```

---

## 2. Structured Logging

### 2.1 Configuration

Psitta uses `structlog` for structured JSON logging in production, and human-readable console output in development.
```python
# Configured in main.py create_app()
import structlog

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
        structlog.dev.set_exc_info,
        structlog.processors.TimeStamper(fmt="iso"),
        # Production: JSON; Development: Console
        structlog.dev.ConsoleRenderer()
        if settings.ENVIRONMENT == "development"
        else structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(
        logging.getLevelName(settings.LOG_LEVEL)
    ),
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
    cache_logger_on_first_use=True,
)
```

### 2.2 Log Format

**Development (console):**
```
2025-02-08 14:23:01 [info] document uploaded  request_id=abc-123 user_id=usr_001 doc_id=doc_456 size_bytes=1048576
```

**Production (JSON):**
```json
{
  "timestamp": "2025-02-08T14:23:01.456Z",
  "level": "info",
  "event": "document_uploaded",
  "request_id": "abc-123",
  "user_id": "usr_001",
  "doc_id": "doc_456",
  "size_bytes": 1048576,
  "service": "psitta-api",
  "environment": "production"
}
```

### 2.3 Log Levels

| Level | Usage | Example |
|-------|-------|---------|
| `DEBUG` | Detailed internal state | SQL queries, provider payloads |
| `INFO` | Normal operations | Document uploaded, playback started |
| `WARNING` | Recoverable issues | Rate limit approached, retry attempted |
| `ERROR` | Failed operations | TTS synthesis failed, S3 unreachable |
| `CRITICAL` | System-level failure | Database connection lost, worker crash |

### 2.4 Request Context

Every log entry within a request automatically includes:

| Field | Source | Purpose |
|-------|--------|---------|
| `request_id` | X-Request-ID header / generated UUID | Correlate all logs for a single request |
| `user_id` | JWT token `sub` claim | Identify actor |
| `method` | HTTP method | Request classification |
| `path` | URL path | Endpoint identification |
| `status_code` | Response status | Outcome tracking |
| `duration_ms` | Request lifecycle timer | Performance monitoring |

Context is bound via `structlog.contextvars` in the RequestID middleware, making it available to all downstream code without explicit passing.

### 2.5 Sensitive Data Filtering

The following data is **never logged**, enforced by a custom structlog processor:
```python
REDACTED_FIELDS = {
    "password", "secret", "token", "authorization",
    "api_key", "access_key", "secret_key", "cookie",
    "x-api-key", "x-auth-token",
}

def redact_sensitive(logger, method_name, event_dict):
    for key in list(event_dict.keys()):
        if any(s in key.lower() for s in REDACTED_FIELDS):
            event_dict[key] = "[REDACTED]"
    return event_dict
```

---

## 3. Distributed Tracing

### 3.1 OpenTelemetry Setup
```python
# Configured in main.py lifespan
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

provider = TracerProvider(resource=Resource.create({
    "service.name": "psitta-api",
    "service.version": __version__,
    "deployment.environment": settings.ENVIRONMENT,
}))
provider.add_span_processor(BatchSpanProcessor(
    OTLPSpanExporter(endpoint=settings.OTEL_EXPORTER_ENDPOINT)
))
trace.set_tracer_provider(provider)

# Auto-instrument frameworks
FastAPIInstrumentor.instrument_app(app)
SQLAlchemyInstrumentor().instrument(engine=engine.sync_engine)
RedisInstrumentor().instrument()
HTTPXClientInstrumentor().instrument()
```

### 3.2 Trace Structure

A typical document upload request produces this trace:
```
[psitta-api] POST /api/v1/documents/upload (trace_id: abc123)
  ├── [middleware] request_id_middleware          2ms
  ├── [middleware] rate_limit_check               1ms
  ├── [handler]   documents.upload_document      45ms
  │   ├── [service]  document_service.upload      40ms
  │   │   ├── [db]     INSERT documents            5ms
  │   │   ├── [s3]     put_object uploads/...     25ms
  │   │   └── [redis]  XADD document:jobs          3ms
  │   └── [schema]  DocumentResponse.validate      2ms
  └── [response]  200 OK                          1ms
```

### 3.3 Custom Spans

Services add custom spans for business-critical operations:
```python
tracer = trace.get_tracer("psitta.services.document")

async def upload(self, file, user_id):
    with tracer.start_as_current_span("document_service.upload") as span:
        span.set_attribute("user.id", user_id)
        span.set_attribute("file.size_bytes", file.size)
        span.set_attribute("file.content_type", file.content_type)
        # ... operation logic
```

### 3.4 Worker Trace Propagation

The document processor worker propagates trace context through Redis Streams:
```python
# Producer (API): inject context into message
from opentelemetry.propagate import inject
headers = {}
inject(headers)
await redis.xadd("document:jobs", {
    "document_id": doc_id,
    "traceparent": headers.get("traceparent", ""),
})

# Consumer (Worker): extract context from message
from opentelemetry.propagate import extract
ctx = extract({"traceparent": message["traceparent"]})
with tracer.start_as_current_span("process_document", context=ctx):
    # ... processing pipeline
```

---

## 4. Metrics

### 4.1 Application Metrics

| Metric | Type | Labels | Purpose |
|--------|------|--------|---------|
| `psitta_http_requests_total` | Counter | method, path, status | Request volume |
| `psitta_http_request_duration_seconds` | Histogram | method, path | Latency distribution |
| `psitta_documents_uploaded_total` | Counter | source_type, user_tier | Upload volume |
| `psitta_documents_processed_total` | Counter | status (success/error) | Pipeline completion |
| `psitta_document_processing_duration_seconds` | Histogram | stage | Pipeline stage timing |
| `psitta_tts_synthesis_duration_seconds` | Histogram | voice_id, provider | TTS latency |
| `psitta_tts_characters_total` | Counter | voice_id, user_tier | TTS usage (for cost) |
| `psitta_playback_sessions_active` | Gauge | — | Concurrent sessions |
| `psitta_storage_bytes_total` | Gauge | bucket, type | Storage consumption |
| `psitta_rate_limit_rejections_total` | Counter | client_type | Rate limit hits |

### 4.2 Infrastructure Metrics

Collected automatically via Prometheus exporters:

| Source | Metrics |
|--------|---------|
| PostgreSQL | Connections, query duration, cache hit ratio, table sizes |
| Redis | Memory usage, connected clients, commands/sec, stream length |
| MinIO / S3 | Request count, bytes transferred, error rate |
| Docker | CPU, memory, network, disk I/O per container |

### 4.3 Prometheus Endpoint
```python
# Exposed at /metrics (internal network only)
from prometheus_client import make_asgi_app
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)
```

Production: the `/metrics` endpoint is bound to an internal-only port (9090) or restricted by network policy. Never exposed publicly.

---

## 5. Health Checks

### 5.1 Endpoints

| Endpoint | Purpose | Checks | Used By |
|----------|---------|--------|---------|
| `GET /health` | Liveness | App is running | Load balancer, Kubernetes |
| `GET /ready` | Readiness | All dependencies reachable | Traffic routing |

### 5.2 Readiness Checks
```python
@app.get("/ready")
async def readiness():
    checks = {}

    # PostgreSQL
    try:
        await db.execute(text("SELECT 1"))
        checks["postgres"] = "ok"
    except Exception as e:
        checks["postgres"] = f"error: {e}"

    # Redis
    try:
        await redis.ping()
        checks["redis"] = "ok"
    except Exception as e:
        checks["redis"] = f"error: {e}"

    # S3 / MinIO
    try:
        await storage.head_bucket()
        checks["storage"] = "ok"
    except Exception as e:
        checks["storage"] = f"error: {e}"

    all_ok = all(v == "ok" for v in checks.values())
    return JSONResponse(
        status_code=200 if all_ok else 503,
        content={"status": "ok" if all_ok else "degraded", "checks": checks},
    )
```

---

## 6. Alerting Rules

### 6.1 Critical Alerts (Page Immediately)

| Alert | Condition | Action |
|-------|-----------|--------|
| API Down | `/health` returns non-200 for > 60s | Restart container, check logs |
| Database Unreachable | `/ready` postgres check fails > 30s | Check connection pool, PostgreSQL status |
| Error Rate Spike | 5xx rate > 5% of requests over 5min | Check error logs, recent deployments |
| Worker Stalled | Redis stream pending > 100 messages for > 10min | Check worker process, restart |

### 6.2 Warning Alerts (Investigate)

| Alert | Condition | Action |
|-------|-----------|--------|
| High Latency | P95 response time > 2s for 5min | Profile slow endpoints, check DB queries |
| Rate Limit Surge | > 50 rate limit rejections in 5min | Investigate abuse, adjust limits |
| TTS Error Rate | TTS failures > 10% over 15min | Check Azure status, failover |
| Storage Growth | S3 usage > 80% of budget threshold | Review TTL policies, clean orphans |
| Queue Depth | Redis stream length > 500 | Scale workers, check processing speed |

### 6.3 Grafana Dashboard Panels

**API Overview:**
- Request rate (RPM) by endpoint
- Error rate (%) with 5xx breakdown
- P50 / P95 / P99 latency
- Active connections

**Document Pipeline:**
- Documents uploaded (per hour)
- Processing queue depth
- Processing duration by stage
- Success / failure rate

**TTS Usage:**
- Characters synthesized (per hour, per voice)
- Synthesis latency distribution
- Cost estimate (characters × rate)
- Cache hit ratio

**Infrastructure:**
- Container CPU / memory usage
- PostgreSQL connections and query time
- Redis memory and command rate
- S3 request volume and error rate

---

## 7. Log Aggregation & Retention

### 7.1 Retention Policy

| Environment | Retention | Storage |
|-------------|----------|---------|
| Development | 7 days | Local Docker volumes |
| Staging | 30 days | CloudWatch / Loki |
| Production | 90 days (logs), 30 days (traces) | CloudWatch / Loki + S3 archive |
| Audit logs | 1 year | S3 Glacier |

### 7.2 Log Queries (Loki/CloudWatch Examples)
```
# All errors for a specific request
{service="psitta-api"} |= "request_id=abc-123" | level="error"

# Document processing failures in last hour
{service="psitta-worker"} | json | event="processing_failed" | last 1h

# Slow TTS synthesis (> 5 seconds)
{service="psitta-worker"} | json | event="tts_synthesis_complete" | duration_ms > 5000

# Rate limit rejections by client
{service="psitta-api"} | json | event="rate_limit_exceeded" | count by (client_id)
```

---

## 8. Development Observability

### 8.1 Local Setup
```yaml
# docker-compose.yml includes:
services:
  # Application logs visible via:
  # docker compose logs -f api worker

  # Optional: local observability stack
  # Uncomment in docker-compose.override.yml:
  # jaeger:
  #   image: jaegertracing/all-in-one:1.53
  #   ports:
  #     - "16686:16686"  # Jaeger UI
  #     - "4317:4317"    # OTLP gRPC
  #
  # prometheus:
  #   image: prom/prometheus:v2.48.0
  #   ports:
  #     - "9090:9090"
  #   volumes:
  #     - ./prometheus.yml:/etc/prometheus/prometheus.yml
  #
  # grafana:
  #   image: grafana/grafana:10.2.0
  #   ports:
  #     - "3000:3000"
```

### 8.2 Debug Logging
```bash
# Enable debug logging for development
LOG_LEVEL=DEBUG uvicorn psitta.main:create_app --factory --reload

# Enable SQL query logging
SQLALCHEMY_ECHO=true LOG_LEVEL=DEBUG uvicorn ...
```

---

## 9. Runbook: Common Investigations

### 9.1 "Why is this document stuck in processing?"
```bash
# 1. Find the document in logs
docker compose logs worker | grep "doc_id=DOC_UUID"

# 2. Check Redis stream for pending messages
docker compose exec redis redis-cli XPENDING document:jobs psitta-workers - + 10

# 3. Check processing stage
docker compose exec redis redis-cli HGET "doc:DOC_UUID:status" stage

# 4. Check for TTS errors
docker compose logs worker | grep "doc_id=DOC_UUID" | grep "error"
```

### 9.2 "Why is the API slow?"
```bash
# 1. Check P95 latency in metrics
curl -s localhost:9090/api/v1/query?query=histogram_quantile(0.95,psitta_http_request_duration_seconds)

# 2. Check database connection pool
docker compose exec postgres psql -U psitta -c "SELECT count(*) FROM pg_stat_activity"

# 3. Check Redis memory
docker compose exec redis redis-cli INFO memory | grep used_memory_human

# 4. Look for slow queries in traces (Jaeger UI: localhost:16686)
```

### 9.3 "How much is TTS costing?"
```bash
# Query Prometheus for total characters in last 24h
curl -s 'localhost:9090/api/v1/query?query=increase(psitta_tts_characters_total[24h])'

# Multiply by provider rate:
# Azure Neural: $16/1M chars → chars × $0.000016
```

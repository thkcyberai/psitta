# Psitta — Cost Model & Scaling Guide

## 1. Per-Document Cost Breakdown

### 1.1 Reference Document

Baseline: 50-page PDF, ~25,000 words, ~150,000 characters, 12 embedded images.

| Operation | Provider | Unit Rate | Per-Doc Cost | % of Total |
|-----------|----------|-----------|-------------|------------|
| Vision (image descriptions) | Anthropic Claude Haiku | $0.25/1M input tokens | $0.04 | 1.5% |
| Text-to-Speech synthesis | Azure Cognitive Neural | $16/1M characters | $2.40 | 92.3% |
| Object storage (audio) | S3 / MinIO | $0.023/GB/month | $0.001 | <0.1% |
| Object storage (source) | S3 / MinIO | $0.023/GB/month | $0.0002 | <0.1% |
| Compute (processing) | Self-hosted | ~$0.10/hr amortized | $0.02 | 0.8% |
| Database (metadata) | PostgreSQL | Included in compute | ~$0.00 | <0.1% |
| Redis (queue + cache) | Self-hosted | Included in compute | ~$0.00 | <0.1% |
| CDN (audio delivery) | CloudFront / Cloudflare | $0.085/GB | $0.14 | 5.4% |
| **Total** | | | **~$2.60** | **100%** |

**Key insight:** TTS is ~92% of per-document cost. All optimization efforts should focus here first.

### 1.2 Cost by Document Size

| Document | Pages | Characters | TTS Cost | Total Cost |
|----------|-------|-----------|----------|------------|
| Short article | 5 | 15,000 | $0.24 | $0.30 |
| Technical report | 50 | 150,000 | $2.40 | $2.60 |
| Academic paper | 25 | 75,000 | $1.20 | $1.35 |
| Novel (full) | 300 | 750,000 | $12.00 | $12.50 |
| Legal contract | 100 | 400,000 | $6.40 | $6.80 |

### 1.3 Cost by TTS Provider

| Provider | Rate (Neural) | 50-page Doc | Quality | Latency |
|----------|--------------|-------------|---------|---------|
| Azure Cognitive | $16/1M chars | $2.40 | High | ~200ms/chunk |
| Google Cloud TTS | $16/1M chars | $2.40 | High | ~250ms/chunk |
| Amazon Polly (Neural) | $16/1M chars | $2.40 | Medium-High | ~150ms/chunk |
| ElevenLabs | $30/1M chars | $4.50 | Very High | ~400ms/chunk |
| OpenAI TTS | $15/1M chars | $2.25 | High | ~300ms/chunk |

Extension providers (ElevenLabs, premium voices) are routed via the `premium-tts` extension.

---

## 2. User Tier Economics

### 2.1 Tier Definitions

| Tier | Price | Doc Limit | Page Limit | Voices | Storage TTL |
|------|-------|-----------|-----------|--------|-------------|
| Free | $0/mo | 5 docs/mo | 50 pages/doc | Standard (6) | 7 days |
| Pro | $12/mo | 50 docs/mo | 500 pages/doc | Premium (20+) | 90 days |
| Enterprise | Custom | Unlimited | Unlimited | All + cloning | Custom |

### 2.2 Unit Economics per Tier

| Metric | Free | Pro | Enterprise |
|--------|------|-----|------------|
| Average docs/month | 2 | 15 | 80 |
| Average pages/doc | 20 | 60 | 100 |
| TTS chars/month | 60,000 | 2,700,000 | 24,000,000 |
| TTS cost/month | $0.96 | $43.20 | $384.00 |
| Infra cost/month | $0.10 | $0.80 | $5.00 |
| **Total COGS/month** | **$1.06** | **$44.00** | **$389.00** |
| Revenue/month | $0.00 | $12.00 | ~$500+ |
| **Gross margin** | **-$1.06** | **-$32.00** | **~$111+** |

**Key insight:** Pro tier is currently unprofitable at heavy usage. Mitigations:

1. Audio caching eliminates re-synthesis (target: 30% cache hit rate)
2. Tiered TTS routing (standard voices = Azure, premium = ElevenLabs)
3. Document page limits enforce cost ceiling per document
4. Chunk deduplication across documents (headers, footers, boilerplate)

### 2.3 Break-Even Analysis

| Scenario | Pro Break-Even | Assumptions |
|----------|---------------|-------------|
| No caching | $12 ÷ $2.60 = 4.6 docs/mo | 50-page average |
| 30% cache hits | $12 ÷ $1.82 = 6.6 docs/mo | Repeated voices/speeds |
| 50% cache hits | $12 ÷ $1.30 = 9.2 docs/mo | High repeat usage |
| Optimized routing | $12 ÷ $1.50 = 8.0 docs/mo | Standard voices only |

Target: users process ≤8 docs/month on Pro for positive margin with caching.

---

## 3. Cost Optimization Strategies

### 3.1 Audio Caching (Priority 1 — Highest Impact)

**Cache key:** `(chunk_hash, voice_id, speed, tone)`
```
┌──────────┐    Cache     ┌──────────┐
│ Request  │───lookup───▶│  Redis   │──hit──▶ Return cached audio URL
│ (chunk)  │             │  (hash)  │
└──────────┘             └──────────┘
      │                       │
      │ miss                  │
      ▼                       │
┌──────────┐    store     ┌──────────┐
│ TTS      │───result───▶│  S3      │
│ Provider │             │ (audio)  │
└──────────┘             └──────────┘
```

**Expected savings:**
- First play: 0% savings (cold cache)
- Repeat play (same settings): 100% TTS savings
- Different speed: miss (re-synthesis required)
- Cross-user (same content + voice): hit (shared cache)

**Target:** 30-50% cache hit rate at steady state → $13-22 savings per 1M characters.

### 3.2 Chunk Deduplication (Priority 2)

Hash document chunks (SHA-256 of normalized text). Identical chunks across documents share cached audio.

**Common duplicates:** document headers/footers, copyright notices, table of contents boilerplate, repeated disclaimers.

**Expected savings:** 5-15% of total TTS volume.

### 3.3 Tiered TTS Routing (Priority 3)

| User Tier | Default Provider | Fallback |
|-----------|-----------------|----------|
| Free | Azure (standard voices) | — |
| Pro | Azure (neural voices) | Google Cloud TTS |
| Enterprise | ElevenLabs / voice cloning | Azure Neural |

Route to cheapest acceptable provider per tier. Premium voices only for paying users.

### 3.4 Document TTL Auto-Expiry (Priority 4)

| Tier | Source TTL | Audio TTL | Metadata TTL |
|------|-----------|-----------|-------------|
| Free | 7 days | 7 days | 30 days |
| Pro | 90 days | 90 days | 1 year |
| Enterprise | Custom | Custom | Retained |

Auto-expiry prevents unbounded storage growth. Cron job runs nightly:
```sql
-- Mark expired documents for deletion
UPDATE documents
SET status = 'expired'
WHERE created_at < NOW() - INTERVAL '7 days'
  AND user_tier = 'free'
  AND status != 'expired';
```

### 3.5 Vision Batching (Priority 5)

Batch multiple images from the same document into a single Anthropic API call where possible. Reduces per-request overhead and improves throughput.

**Expected savings:** 20-30% reduction in vision API calls.

---

## 4. Scaling Architecture

### 4.1 Component Scaling
```
                    ┌─────────────────────────────────┐
                    │         Load Balancer            │
                    └──────┬──────────┬───────────────┘
                           │          │
                    ┌──────▼──┐ ┌─────▼───┐
                    │ API-1   │ │ API-2   │  ◄── Stateless, horizontal
                    │ (8000)  │ │ (8000)  │
                    └────┬────┘ └────┬────┘
                         │           │
              ┌──────────┼───────────┼──────────┐
              │          │           │          │
        ┌─────▼──┐ ┌─────▼──┐ ┌─────▼──┐ ┌─────▼──┐
        │Postgres│ │ Redis  │ │  S3    │ │ CDN    │
        │(primary│ │(cluster│ │(bucket)│ │(edge)  │
        │+replica│ │  mode) │ │        │ │        │
        └────────┘ └───┬────┘ └────────┘ └────────┘
                       │
              ┌────────┼────────┐
              │        │        │
        ┌─────▼──┐┌────▼───┐┌──▼──────┐
        │Worker-1││Worker-2││Worker-3 │  ◄── Scale by queue depth
        └────────┘└────────┘└─────────┘
```

### 4.2 Scaling Triggers

| Component | Metric | Scale-Up Trigger | Scale-Down Trigger |
|-----------|--------|-----------------|-------------------|
| API servers | CPU utilization | > 70% for 3min | < 30% for 10min |
| API servers | Request queue depth | > 100 pending | < 10 pending |
| Workers | Redis stream length | > 50 messages | < 5 messages |
| Workers | Processing latency | P95 > 60s | P95 < 15s |
| PostgreSQL replicas | Read query latency | P95 > 100ms | P95 < 20ms |
| Redis | Memory utilization | > 75% | < 40% |

### 4.3 Horizontal Scaling Rules

**API Servers (stateless):**
- Min: 2 instances (high availability)
- Max: 20 instances
- Scale unit: 1 instance
- Health check: `/health` every 10s
- Drain timeout: 30s (allow in-flight requests to complete)

**Workers (stateless consumers):**
- Min: 1 instance
- Max: 10 instances
- Scale unit: 1 instance
- Consumer group: `psitta-workers` (Redis Streams auto-distributes)
- Idle timeout: process pending messages before shutdown

**PostgreSQL:**
- Primary: 1 (writes)
- Read replicas: 0-3 (reads, scale by query load)
- Connection pooling: PgBouncer (max 100 connections per pool)
- Failover: automatic via managed service (RDS/CloudSQL)

**Redis:**
- Single instance for development
- Cluster mode (3 shards) for production
- Memory: 1GB dev → 4GB staging → 16GB production

---

## 5. Capacity Planning

### 5.1 Growth Projections

| Metric | Month 1 | Month 6 | Month 12 | Month 24 |
|--------|---------|---------|----------|----------|
| Users | 100 | 2,000 | 10,000 | 50,000 |
| Documents/day | 20 | 400 | 2,000 | 10,000 |
| TTS chars/day | 600K | 12M | 60M | 300M |
| Storage (cumulative) | 5 GB | 200 GB | 1.5 TB | 10 TB |
| API requests/min | 5 | 100 | 500 | 2,500 |

### 5.2 Infrastructure Requirements per Phase

| Phase | API | Workers | PostgreSQL | Redis | S3 | Monthly Infra Cost |
|-------|-----|---------|-----------|-------|----|--------------------|
| Launch (M1) | 1× t3.small | 1× t3.small | db.t3.micro | cache.t3.micro | Standard | ~$80 |
| Growth (M6) | 2× t3.medium | 2× t3.medium | db.t3.small | cache.t3.small | Standard | ~$350 |
| Scale (M12) | 4× c6g.large | 4× c6g.large | db.r6g.large | cache.r6g.large | Standard + CDN | ~$1,800 |
| Maturity (M24) | 8× c6g.xlarge | 8× c6g.xlarge | db.r6g.xlarge (+ replicas) | Redis Cluster | Standard + CDN | ~$6,000 |

### 5.3 Monthly Cost Model (All-In)

| Component | M1 | M6 | M12 | M24 |
|-----------|-----|------|-------|--------|
| Compute (EC2/ECS) | $40 | $200 | $1,200 | $4,000 |
| Database (RDS) | $15 | $50 | $300 | $1,000 |
| Cache (ElastiCache) | $10 | $30 | $150 | $500 |
| Storage (S3) | $1 | $5 | $35 | $230 |
| CDN (CloudFront) | $2 | $15 | $100 | $250 |
| **Infra subtotal** | **$68** | **$300** | **$1,785** | **$5,980** |
| TTS API costs | $300 | $6,000 | $30,000 | $150,000 |
| Vision API costs | $10 | $200 | $1,000 | $5,000 |
| **Total COGS** | **$378** | **$6,500** | **$32,785** | **$160,980** |

**Observation:** TTS API costs dominate at every scale. Infrastructure is <10% of total cost.

---

## 6. Cost Monitoring & Budgets

### 6.1 Cost Alerts

| Alert | Threshold | Action |
|-------|-----------|--------|
| Daily TTS spend | > 120% of daily budget | Notify team, investigate spikes |
| Monthly TTS spend | > 80% of monthly budget | Review top users, check abuse |
| Storage growth | > 50GB/week | Review TTL policies |
| Single user TTS | > $50/day | Rate limit, investigate |
| API error-driven retries | > 10% of TTS calls | Fix errors (retries are expensive) |

### 6.2 Cost Dashboard Metrics
```
# Prometheus queries for cost tracking

# TTS cost per hour (Azure Neural rate)
sum(rate(psitta_tts_characters_total[1h])) * 0.000016

# TTS cost per user per day
sum by (user_id) (increase(psitta_tts_characters_total[24h])) * 0.000016

# Cache savings per hour
sum(rate(psitta_cache_hits_total{type="tts"}[1h]))
  / sum(rate(psitta_tts_requests_total[1h])) * 100
# → percentage of TTS requests served from cache

# Storage cost projection (monthly)
sum(psitta_storage_bytes_total) / 1073741824 * 0.023
```

### 6.3 Budget Guardrails
```python
# Enforced in document_service.py
async def check_tier_budget(user: User) -> bool:
    """Prevent processing if user has exceeded tier limits."""
    usage = await get_monthly_usage(user.id)

    limits = {
        "free":       {"docs": 5,   "pages": 250},
        "pro":        {"docs": 50,  "pages": 25_000},
        "enterprise": {"docs": -1,  "pages": -1},  # unlimited
    }

    tier_limit = limits[user.tier]
    if tier_limit["docs"] > 0 and usage.docs >= tier_limit["docs"]:
        raise QuotaExceededError("Monthly document limit reached")
    if tier_limit["pages"] > 0 and usage.pages >= tier_limit["pages"]:
        raise QuotaExceededError("Monthly page limit reached")

    return True
```

---

## 7. Performance Benchmarks

### 7.1 Target SLOs

| Metric | Target | Measurement |
|--------|--------|-------------|
| API response time (P50) | < 100ms | Excluding TTS/processing |
| API response time (P95) | < 500ms | Excluding TTS/processing |
| Document processing | < 5min for 50 pages | End-to-end pipeline |
| Audio streaming start | < 2s | First byte of audio from playback start |
| System availability | 99.5% | Monthly uptime |

### 7.2 Bottleneck Analysis

| Bottleneck | Impact | Mitigation |
|-----------|--------|------------|
| TTS API latency (~200ms/chunk) | Processing time | Parallel synthesis (4 concurrent) |
| S3 upload latency (~50ms/file) | Processing time | Batch uploads, multi-part for large |
| PostgreSQL write contention | API throughput | Connection pooling, async writes |
| Redis memory pressure | Cache eviction | LRU policy, tier-based TTLs |
| Image description latency | Processing time | Batch images, async pipeline |

---

## 8. Disaster Recovery

### 8.1 Backup Strategy

| Component | Method | Frequency | Retention | RTO | RPO |
|-----------|--------|-----------|-----------|-----|-----|
| PostgreSQL | Automated snapshots | Every 6 hours | 30 days | 1 hour | 6 hours |
| Redis | RDB snapshots | Every hour | 7 days | 15 min | 1 hour |
| S3 (audio) | Cross-region replication | Continuous | Same as source | 0 | 0 |
| S3 (source docs) | Versioning enabled | Continuous | 30 days | 0 | 0 |

### 8.2 Recovery Procedures

**Database failure:**
1. Failover to read replica (automatic with RDS)
2. Promote replica to primary
3. Restore from snapshot if no replica available
4. Re-run Alembic migrations to verify schema

**Redis failure:**
1. Restart Redis container (data in AOF/RDB)
2. Workers reconnect automatically (exponential backoff)
3. Cache rebuilds organically through normal usage
4. Queue messages are durable (Redis Streams acknowledgment)

**S3 failure:**
1. Cross-region failover (if configured)
2. Audio can be re-synthesized from source documents
3. Source documents are the only truly irreplaceable asset

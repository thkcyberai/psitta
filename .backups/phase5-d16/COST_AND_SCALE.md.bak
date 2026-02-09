# Cost & Scale

## Per-Document Cost (50-page PDF, ~150K characters)

| Operation | Provider | Per-Document |
|-----------|----------|-------------|
| Vision descriptions | Anthropic Claude | ~$0.05 |
| Text-to-speech | Azure Cognitive TTS | ~$2.40 |
| Object storage | S3 / MinIO | ~$0.001 |
| Compute | Self-hosted | ~$0.02 |
| **Total** | | **~$2.50** |

TTS is ~96% of per-document spend.

## Scaling Architecture
- API servers: Stateless, scale behind load balancer
- Workers: Scale independently by queue depth
- PostgreSQL: Read replicas, connection pooling
- Redis: Cluster for cache, Streams for jobs
- S3: CDN for audio delivery

## Cost Optimization
1. Audio caching per (chunk_id, voice_id, speed)
2. Chunk deduplication across documents
3. Tiered TTS routing per user tier
4. Document TTL (60-day default)
5. Vision description batching

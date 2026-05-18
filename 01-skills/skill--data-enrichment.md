# Data Enrichment

## Why Enrichment Must Be Async

Enrichment calls external APIs that can take 200ms–2s and fail unpredictably. Blocking an insert on enrichment means every new record creation inherits that latency and failure mode. The insert must complete in < 50ms; enrichment happens in the background and fills in fields when it returns.

The user entered the data — that's the critical path. Enrichment is additive, never a blocker.

## Enrichment Queue Architecture

```
Insert record → mark enrichment_status = 'pending' → return 201
                      ↓
              Background worker picks up pending records
                      ↓
              Call enrichment API
                      ↓
              Merge returned fields → mark enrichment_status = 'complete' | 'failed'
```

Use a DB table as the queue (simpler, durable) or a proper queue (BullMQ, Inngest) for retry semantics. Either way, the original insert is never blocked.

```sql
alter table companies add column enrichment_status text default 'pending'
  check (enrichment_status in ('pending', 'in_progress', 'complete', 'failed', 'skipped'));
alter table companies add column enrichment_attempted_at timestamptz;
alter table companies add column enrichment_source text;  -- 'clearbit' | 'hunter' | 'apollo'
alter table companies add column enrichment_data jsonb;   -- raw API response, separate from core fields
```

Store the raw API response in `enrichment_data` alongside the promoted fields. When the enrichment schema changes (APIs evolve), you can re-derive fields from the raw response without re-calling the API.

## Provider Selection and Characteristics

**Clearbit (now HubSpot Enrichment)**: Best for company + person data. 20k+ data points per company. Rate limit: varies by plan (typically 100–600 req/min). Credit-based — check whether a lookup will consume a credit before firing (use the `reveal` endpoint first if available).

**Hunter.io**: Best for finding professional email addresses by domain. Rate limit: 10 req/s on paid plans. Useful for contact generation, not full company enrichment.

**Apollo.io**: People + company enrichment. REST API, 50 req/min on basic plans. Good for B2B contact enrichment at scale.

**Key rule**: never call enrichment inside a transaction. A slow API call holding an open DB transaction is a deadlock waiting to happen.

## Rate Limiting

Respect API quotas by controlling concurrency at the worker level:

```ts
const limiter = new Bottleneck({
  maxConcurrent: 5,         // parallel requests
  minTime: 100,             // ms between requests → max 10/s
  reservoir: 600,           // tokens
  reservoirRefreshAmount: 600,
  reservoirRefreshInterval: 60 * 1000, // refill every minute
});

async function enrichCompany(domain: string) {
  return limiter.schedule(() => clearbit.Company.find({ domain }));
}
```

When a 429 is returned: back off with exponential delay, do not immediately retry. Retry after `Retry-After` header if present, otherwise use `Math.pow(2, attempt) * 1000` ms.

## Partial Failure Handling

External APIs return partial data or fail for specific records (no data found, invalid domain, rate limited). Handle each case separately:

- **Not found (404 / empty result)**: mark `enrichment_status = 'skipped'`, set a `no_data` flag. Do not retry — the API will return the same result.
- **Rate limit (429)**: mark `enrichment_status = 'pending'` again with a future `enrichment_after_at` timestamp. Re-queue.
- **Transient error (500, timeout)**: mark `in_progress` → `failed`, increment `attempt_count`. Retry up to 3 times with backoff.
- **Validation error in response**: store raw response anyway, log error, mark `failed`.

Never let one failed enrichment block the rest of the queue.

## Enrichment Freshness (TTL)

Enrichment data goes stale — companies rebrand, people change jobs. Set a TTL per data type:

| Data type       | Typical TTL  |
|-----------------|-------------|
| Company domain  | 90 days     |
| Employee count  | 30 days     |
| Email validity  | 7 days      |
| Social profiles | 60 days     |

On TTL expiry: mark `enrichment_status = 'pending'` via a nightly cron. Only re-enrich records that have been active recently (accessed in last 30 days) — avoid burning credits on stale records nobody uses.

## Merging Enriched Fields

Apply a field precedence rule when merging:

1. User-provided value always wins over enriched value (trust the human).
2. Enriched value fills in only null/empty fields.
3. Exception: explicitly flagged fields where enrichment should override (e.g., `industry_code` — users often don't know the SIC code).

```ts
function mergeEnrichment(record: Company, enriched: ClearbitCompany): Partial<Company> {
  return {
    logo_url:      record.logo_url ?? enriched.logo,
    employee_count: record.employee_count ?? enriched.metrics?.employees,
    industry:      record.industry ?? enriched.category?.industry,
    // user value always wins — don't overwrite
  };
}
```

## Key Rules

- **Never block the insert** — enrichment is always async.
- Store the **raw API response** in a JSON column; promote key fields to typed columns.
- Treat **not-found** differently from **errors** — not-found should not be retried.
- Rate-limit at the **worker level**, not the API call level — prevent thundering herd on restarts.
- Set **freshness TTL per field type** and re-enrich only active records.
- **User-supplied values win** over enriched values unless explicitly overridden.
- Use **a separate `enrichment_data` column** — don't pollute core schema with unstable API shapes.

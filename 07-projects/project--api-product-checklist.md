# Project: API Product Launch Checklist

## Overview
An API is a product where the customer is a developer. Developer experience — documentation clarity, SDK quality, error message quality — is the product quality. Unlike a UI product, bugs in an API propagate into customer applications and can be very difficult for them to diagnose. Versioning, rate limiting, and audit logging are not optional extras; they are the table stakes developers expect.

## API Key Management

- [ ] API key generation on account creation (or on demand)
- [ ] Multiple keys per account (so customers can rotate without downtime)
- [ ] Key scoping: read-only vs read-write vs admin
- [ ] Key revocation (immediate effect)
- [ ] Last-used timestamp per key
- [ ] Keys stored hashed in the database (display full key only once on creation)

## Rate Limiting

- [ ] Rate limit per API key (not just per IP — IPs are shared in enterprise networks)
- [ ] Different limits per plan tier (free: 100/min, paid: 1000/min, enterprise: custom)
- [ ] Rate limit headers in every response: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- [ ] HTTP 429 with `Retry-After` header when limit exceeded
- [ ] Burst allowance (short spikes above limit allowed, sustained rate enforced)

## Versioning

- [ ] Version in URL path: `/v1/`, `/v2/` (not headers — harder for developers to discover and test)
- [ ] Deprecation policy documented (minimum 6-month sunset window for breaking changes)
- [ ] Deprecation-Warning header on deprecated endpoints
- [ ] Changelog listing breaking vs non-breaking changes by version

## API Design

- [ ] RESTful resource naming (nouns, not verbs): `/orders` not `/getOrders`
- [ ] Consistent response envelope: `{ "data": {...}, "meta": {...} }` or `{ "error": {...} }`
- [ ] Pagination on all list endpoints: cursor-based preferred over offset (consistent with deletions)
- [ ] Filtering and sorting on list endpoints (documented query parameters)
- [ ] HTTP status codes used correctly: 200, 201, 204, 400, 401, 403, 404, 422, 429, 500
- [ ] Error responses include: `code` (machine-readable), `message` (human-readable), `request_id`

## Documentation

- [ ] OpenAPI 3.x spec (auto-generated from code preferred)
- [ ] Interactive docs (Swagger UI, Redoc, or custom)
- [ ] Getting started guide (first API call in < 5 minutes)
- [ ] Authentication guide
- [ ] Error reference (all error codes, what they mean, how to fix)
- [ ] Rate limit guide
- [ ] Versioning and migration guides
- [ ] Code examples in the top 3 languages your customers use

## SDKs

- [ ] At minimum: official SDK in your customers' primary language
- [ ] SDK handles auth, retry on 429 (with backoff), and error parsing
- [ ] SDK published to package manager (npm, PyPI, etc.) with semantic versioning
- [ ] SDK changelog

## Webhooks (if applicable)

- [ ] Event types documented
- [ ] Webhook delivery with retry (exponential backoff, at-least-once delivery)
- [ ] Signature verification (HMAC — so customers can verify the payload is from you)
- [ ] Webhook logs visible to customer (last N attempts, status, payload)
- [ ] Test webhook trigger (send a sample event to a customer's endpoint)

## Observability

- [ ] Per-API-key usage dashboard for customers
- [ ] Audit log: every API call logged with key ID, endpoint, status, timestamp
- [ ] Internal dashboards: p50/p95/p99 latency, error rate, usage by endpoint

## Key Rules

- Errors must be actionable: include what went wrong AND how to fix it in the error message
- Never return 500 with an empty body — always include a request_id and message
- Rate limit per API key, not per IP — enterprise customers share IPs
- OpenAPI spec must stay in sync with actual behavior — drift destroys developer trust
- Webhook payload schema must be stable (additive-only changes allowed without version bump)
- API key secrets are displayed exactly once — if lost, customer must rotate, not recover

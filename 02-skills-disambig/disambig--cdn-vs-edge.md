# CDN vs Edge Functions vs Origin

## Three Layers, Three Jobs

These are not competing solutions — they are layers in a request-handling stack, each suited to different work. The decision is which layer handles a given request, not which layer to use exclusively.

**CDN** caches static assets close to users. It doesn't execute code. It serves the same bytes to every request for a given URL until the cache is invalidated.

**Edge Functions** execute lightweight code at CDN PoPs (Points of Presence), close to users, with no cold start or minimal cold start. They can run dynamic logic — but without direct database access, heavy computation, or large runtimes.

**Origin** is your application server (Node, Python, Go, etc.) running in one or a few datacenter regions. It has full access to databases, file systems, and arbitrary compute. It is the furthest from users and the most capable.

## CDN: Static Assets

CDN is the correct layer for anything that is the same bytes for every user: images, fonts, compiled JavaScript bundles, CSS, video, PDFs, and other binary assets.

Why: latency from a CDN PoP 20ms away vs an origin server 200ms away makes a measurable difference for every page load. Bandwidth cost is also lower — CDN egress is cheaper than origin egress.

What does not belong on CDN: any response that varies per user (auth-dependent content, personalized pages), any response that must be fresh on every request, or any response generated from database data.

Cache-Control headers determine CDN behavior. Long `max-age` for content-addressed assets (hashed filenames), shorter or no caching for HTML pages that may change.

## Edge Functions: Dynamic-but-Fast Logic

Edge runs code at the CDN layer. This is valuable for logic that needs to run on every request but doesn't need database access:

- **Geo-routing**: redirect users to a region-appropriate URL based on `request.cf.country` or similar headers
- **A/B testing**: assign a variant bucket and rewrite the URL or set a cookie before the request reaches origin
- **Auth token validation**: verify a JWT signature and reject unauthenticated requests before they consume origin resources
- **Request/response transformation**: add headers, rewrite URLs, inject content into responses
- **Feature flags at the edge**: serve different content based on a flag without origin involvement

What does not belong at the edge: database queries (no TCP connection to a DB from an edge PoP), CPU-heavy computation (execution time limits are strict), large Node.js dependencies (bundle size limits apply), or stateful operations that require distributed coordination.

Edge Functions at Cloudflare Workers have a 128MB memory limit and ~10ms CPU time limit per request. Vercel Edge Functions have similar constraints. These are hard limits — work that exceeds them belongs at origin.

## Origin: Everything Else

Origin handles requests that require:
- Database reads and writes
- External API calls with secrets
- File system operations
- Heavy computation (image processing, PDF generation, ML inference)
- Long-running operations (server-sent events, WebSocket upgrades)
- Large runtime dependencies

Origin latency is higher (one region, no geographic distribution), but it is the only layer with the capability to do this work. The mitigation for latency is caching responses aggressively at the CDN layer when possible, and using edge functions to eliminate origin calls entirely for requests that don't need dynamic data.

## Decision Flowchart

```
Is the response identical for every user and doesn't change frequently?
  → CDN

Does the request need to run logic (routing, auth check, A/B) without database access?
  → Edge Function

Does the request need a database, secrets, heavy computation, or external APIs?
  → Origin
```

## The Cost of Getting It Wrong

Routing static assets through origin instead of CDN wastes compute and adds latency. Running database queries at the edge is impossible (or requires a globally distributed database like D1/Turso/Neon Edge, which adds its own complexity). Running heavy computation at the edge hits time limits and fails under load.

## Key Rules

- All static assets (images, JS, CSS, fonts) must be served from CDN — there is no reason to serve them from origin
- Edge Functions are not a replacement for origin — they extend the origin by handling pre-flight logic without consuming origin resources
- Never attempt database queries in Edge Functions unless using a purpose-built edge-compatible database with HTTP API
- A/B testing at the edge requires that variants be deterministic from a cookie or header — never depend on external state at edge
- Use CDN cache-busting via content-hashed filenames, not query strings (some CDNs treat query-string variants as different cache keys, some don't)
- `Cache-Control: no-store` on API responses that contain user data — never let a CDN cache personalized content

# REST vs GraphQL

## The Core Problem Each Solves

REST organizes APIs around resources (`/users`, `/orders`). Every resource gets its own endpoint. This is simple to build and reason about, but it creates two failure modes at scale: **over-fetching** (the endpoint returns 30 fields and you need 3) and **under-fetching** (you need data from 3 endpoints and must make 3 round trips).

GraphQL solves over/under-fetching by letting clients declare exactly what they need in a single query. This is genuinely valuable when clients have divergent needs — a mobile app needs 4 fields, a dashboard needs 20 — and you don't want to maintain separate endpoints for each.

## Why REST's Caching Advantage Is Real

HTTP caching works on URLs. A GET to `/api/products/42` can be cached by browsers, CDNs, and reverse proxies automatically. No extra configuration needed.

GraphQL typically sends everything as POST to a single endpoint. POST is not cacheable by default. Persisted queries and CDN-level caching can work around this, but they require deliberate effort. If your data is read-heavy and benefits from caching, REST has a structural advantage.

## The N+1 Problem Is GraphQL's Achilles Heel

When a GraphQL resolver fetches a list of 100 orders and each order resolver fetches the associated customer, you've made 101 database queries. This happens naturally when resolvers are written naively.

The fix is DataLoader: batch and deduplicate child queries so 100 order → customer lookups become 1 query. DataLoader works but it's non-obvious infrastructure that every team must build or adopt. With REST, you control the query — there's no resolver chain creating hidden round trips.

## Schema Maintenance Overhead

GraphQL requires a schema definition (SDL or code-first). This schema becomes a contract. Evolving it — adding fields, deprecating fields, handling nullability — requires discipline. Tools like schema stitching and federation add further complexity when multiple services contribute to one graph.

REST doesn't require a formal schema (though OpenAPI is recommended). Informal REST is easier to iterate on quickly; formal REST via OpenAPI is roughly comparable maintenance to GraphQL SDL.

## Team Familiarity Matters More Than You Think

Every developer knows how to curl a REST endpoint. Debugging REST with browser DevTools, Postman, or curl is frictionless. GraphQL requires understanding query syntax, variables, fragments, and directives before writing a first request. Junior developers and external API consumers hit this learning curve immediately.

## Decision Framework

**Use REST when:**
- The API is public-facing or consumed by external parties
- Data is relatively flat (no deep nesting, few relationships)
- Caching at the CDN or browser layer is important
- The team is small or not yet experienced with GraphQL

**Use GraphQL when:**
- Multiple client types (mobile, web, third-party) need different shapes of the same data
- The data model is highly relational (social graph, e-commerce catalog with variants/inventory/pricing)
- A single query replacing multiple REST calls is the dominant use case
- You have bandwidth to implement DataLoader and maintain a schema

**Default position:** Start with REST. It handles the majority of CRUD applications without friction. Migrate specific domains to GraphQL only when over-fetching or client-shape divergence is actively causing problems — not as a premature optimization.

## Key Rules

- Never choose GraphQL to "future-proof" a simple CRUD API — it adds complexity before it adds value
- Always implement DataLoader for any list → related-resource resolver pattern, without exception
- If a REST endpoint returns more than 2x the fields any single client uses, that's the signal to reconsider
- Public APIs should default to REST; the tooling ecosystem and developer familiarity make adoption far easier
- GraphQL's benefit is real only when clients genuinely have divergent field requirements — not when one web frontend is the only consumer

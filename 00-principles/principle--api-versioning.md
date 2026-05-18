# Principle: API Versioning

## Overview

API versioning allows making breaking changes without breaking existing clients. The right strategy depends on change frequency, client count, and deployment model. Most teams version too early with too much ceremony, or skip versioning until it's painful.

## When to Version

**Don't version yet** if:
- You have zero external consumers (only your own frontend)
- The API is behind auth and you deploy frontend + backend together
- You can update all consumers simultaneously

**Start versioning when**:
- External parties integrate your API (partners, mobile apps, SDKs)
- Multiple independent frontend teams consume the API
- Mobile app users can be on old versions for months

## URL Path Versioning (Most Common)

```
https://api.example.com/v1/invoices
https://api.example.com/v2/invoices
```

```ts
// Next.js App Router
app/
  api/
    v1/
      invoices/
        route.ts
    v2/
      invoices/
        route.ts
```

Pros: Obvious in URLs, logs, caches, and network traces. Easy to route in CDN/proxy.
Cons: Version leaks into every URL.

## Header Versioning

```
GET /api/invoices
Accept: application/vnd.myapi.v2+json
```

Pros: Clean URLs.
Cons: Invisible in browser, hard to test without tooling, cache invalidation problems.

Generally not recommended for public APIs.

## Version Lifecycle

```
v1: Released
v2: Released → v1 marked deprecated
v3: Released → v2 marked deprecated → v1 sunsetted (clients must migrate)
```

Typical deprecation timeline: 6-12 months notice before sunsetting a version.

Announce via:
- `Sunset` HTTP header in responses: `Sunset: Sat, 01 Jan 2027 00:00:00 GMT`
- `Deprecation` header: `Deprecation: true`
- Email notifications to registered API consumers
- Dashboard warnings for affected API key holders

## What Requires a New Version

Breaking changes that need a new version:
- Removing a field from a response
- Renaming a field
- Changing a field's type (`"1234"` → `1234`)
- Changing URL structure
- Removing an endpoint
- Changing authentication scheme
- Changing error format

Non-breaking changes (no version bump needed):
- Adding new optional fields to responses
- Adding new optional request parameters
- Adding new endpoints
- Performance improvements
- Bug fixes that don't change the contract

## Shared Logic, Versioned Interface

Don't duplicate business logic between versions:

```ts
// Shared business logic
export async function getInvoiceById(id: string) {
  return await db.query.invoices.findFirst({ where: eq(invoices.id, id) })
}

// v1 response format (old)
export async function GET(req: Request, { params }: { params: { id: string } }) {
  const invoice = await getInvoiceById(params.id)
  return Response.json({
    id: invoice.id,
    total: invoice.totalCents / 100,  // v1 used dollars as float
  })
}

// v2 response format (new)
export async function GET(req: Request, { params }: { params: { id: string } }) {
  const invoice = await getInvoiceById(params.id)
  return Response.json({
    id: invoice.id,
    total_cents: invoice.totalCents,  // v2 uses cents as integer
    currency: invoice.currency,
  })
}
```

Shared query layer. Separate presentation layer per version.

## Backward Compatibility First

Before creating a new version, ask: can this change be backward-compatible?

```ts
// Instead of removing a field (breaking):
// v1: { name: "Jane Doe" }
// v2: { first_name: "Jane", last_name: "Doe" }  ← removes "name"

// Better: add new fields, keep old (additive change):
// v1+: { name: "Jane Doe", first_name: "Jane", last_name: "Doe" }
// Mark "name" as deprecated in docs
```

Every version you ship is tech debt. The best version is one you never create.

## Internal APIs

For internal APIs (only your own services):
- Use URL path versioning so logs are clear
- Deploy in lock-step: update all consumers before sunsetting
- Feature flags can replace versions for gradual rollout
- Canary deployment is safer than versioning for internal changes

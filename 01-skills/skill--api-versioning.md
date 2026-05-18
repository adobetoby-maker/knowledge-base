# Skill: API Versioning Strategy

## What This Covers

How to version a public or partner-facing API so breaking changes can ship without breaking existing clients, including the tradeoffs between URL versioning and header versioning, what constitutes a breaking change, and how to manage version lifecycle.

## URL Versioning vs Header Versioning

**URL versioning** (`/v1/users`, `/v2/users`): the version is explicit in every request. Logs are immediately readable, curl works with no special flags, caching is straightforward (the URL is the cache key). The cost is that base URLs change, and clients must update their SDK or base URL config.

**Header versioning** (`API-Version: 2024-01-01` or `Accept: application/vnd.api+json;version=2`): cleaner URLs, but the version is invisible in logs unless explicitly extracted, and most HTTP caches ignore it by default (need `Vary: API-Version`). Stripe and GitHub use date-based header versioning; it signals that versioning is a first-class concern.

Choose URL versioning (`/v1/`) for:
- Public APIs where clients build hardcoded base URLs
- APIs consumed via simple HTTP clients without custom header support
- Anything where log readability at a glance matters

Choose header versioning for:
- Internal service-to-service APIs where all clients are under your control
- APIs that change frequently on a date cadence (Stripe's model)

Avoid: query parameter versioning (`?version=2`). It pollutes analytics and gets stripped by proxies.

## What Is a Breaking Change

Breaking changes require a version bump. Non-breaking changes can ship any time.

**Breaking (require new version):**
- Removing a field from a response
- Renaming a field
- Changing a field's type (string → integer)
- Changing required/optional semantics on a request field
- Removing an endpoint
- Changing authentication scheme
- Changing error response shape

**Non-breaking (safe to ship in existing version):**
- Adding new optional fields to a response
- Adding new optional request parameters
- Adding new endpoints
- Adding new enum values (caveat: only if clients are expected to handle unknowns gracefully)
- Relaxing validation (accepting more inputs)

The reason this matters: clients serialize responses into typed models. Removing or renaming a field breaks deserialization silently if the client uses strict parsing. Adding fields is safe because most JSON parsers ignore unknown keys.

## Deprecation Process

Never remove a version without a deprecation period. The process:

1. **Announce**: publish a deprecation notice in changelog, docs, and developer email. Include the `Sunset` date.
2. **Warn in responses**: add a `Deprecation` header (`Deprecation: true`) and a `Sunset` header (`Sunset: Sat, 31 Dec 2025 23:59:59 GMT`) to all responses from the deprecated version. Clients can detect this programmatically.
3. **Migration guide**: document exactly what changed between the old version and the new version, field by field. A diff table works well.
4. **Minimum notice period**: 6 months for external/public APIs, 2 months for internal APIs. Never less.
5. **Sunset**: return 410 Gone from the deprecated version after the sunset date.

Track active version usage per client (API key) in your analytics so you know who needs migration help before sunsetting.

## Version Lifecycle Policy

Define this upfront and publish it in your docs:

- **Supported**: current version, full support
- **Deprecated**: older version, receives security fixes only, scheduled for sunset
- **Sunset**: returns 410 Gone

A common policy: maintain 2 versions simultaneously (current + previous). When v3 ships, v1 enters the sunset countdown.

## Implementation Pattern

```ts
// Middleware: extract and validate version
app.use('/api/:version/*', (req, res, next) => {
  const version = req.params.version  // 'v1', 'v2'
  const supported = ['v1', 'v2']
  const deprecated = ['v1']
  
  if (!supported.includes(version)) {
    return res.status(410).json({ error: `API version ${version} is no longer supported` })
  }
  
  if (deprecated.includes(version)) {
    res.set('Deprecation', 'true')
    res.set('Sunset', 'Sat, 31 Dec 2025 23:59:59 GMT')
    res.set('Link', '<https://api.example.com/v2>; rel="successor-version"')
  }
  
  req.apiVersion = version
  next()
})
```

Route handlers read `req.apiVersion` to branch behavior, or use separate controller files per version. Separate files are cleaner for large surface areas; branching inside a single handler works for small differences.

## Key Rules

- URL versioning is the default choice for public APIs — it's explicit and debuggable
- Adding fields is never a breaking change; removing or renaming always is
- Publish the deprecation notice and migration guide simultaneously — developers need both
- Include `Sunset` and `Deprecation` headers in responses for deprecated versions
- Never sunset without at least 6 months notice for external APIs
- Track version usage per API key to identify clients that need migration before sunset
- Define the version lifecycle policy (e.g., support N and N-1) before shipping v1

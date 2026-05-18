# Principle: API Backward Compatibility

## Overview
Breaking an API breaks every consumer simultaneously — mobile apps, third-party integrations, internal services. Unlike a database migration, an API break is immediately visible to end users. The cost of a breaking change isn't just the fix; it's the forced upgrade of every consumer on their own timeline, or maintaining multiple API versions indefinitely. Backward compatibility is a contract, not a courtesy.

## What Constitutes a Breaking Change

| Change | Breaking? | Why |
|---|---|---|
| Remove a field from response | Yes | Consumers reading that field get `undefined` |
| Rename a field | Yes | Old name no longer exists |
| Change field type (`string` → `number`) | Yes | Type mismatch in consumer code |
| Add required request parameter | Yes | Old callers omit it, now rejected |
| Change HTTP method | Yes | Existing integrations use wrong verb |
| Add optional response field | No | Tolerant reader ignores unknown fields |
| Add optional request parameter | No | Old callers don't send it; server uses default |
| Expand enum values (add new) | Usually No | Consumers must handle unknown values |
| Restrict enum values (remove) | Yes | Old values now rejected |

## The Tolerant Reader Pattern

Consumers should be built to tolerate additive changes:
```typescript
// Fragile: assumes exact response shape
const { name, email, role } = await getUser(id);

// Tolerant: destructure only what you need, don't reject unknown fields
const user = await getUser(id);
const { name, email } = user;
// 'role' added to API response? No problem. 'name' or 'email' removed? Breaks immediately.
```

## Versioning Strategies

### URL versioning (most common, most visible)
```
GET /api/v1/users
GET /api/v2/users
```
Consumers explicitly opt into the new version. Old version is maintained until sunset.

### Header versioning
```
GET /api/users
Accept-Version: 2024-01-01
```
Cleaner URLs; harder to test in a browser.

### Sunset headers (deprecation signaling)
```http
HTTP/1.1 200 OK
Sunset: Sat, 01 Jan 2026 00:00:00 GMT
Deprecation: true
Link: <https://api.example.com/v2/users>; rel="successor-version"
```
Gives consumers a deadline without forcing immediate migration.

## Consumer-Driven Contract Tests

The consumer writes a test that defines what it expects from the provider. The provider runs this test in CI before deploying. If a change would break the consumer's expectations, CI fails.

```typescript
// Consumer test (saved as a "pact")
expect(response).toMatchObject({
  id: expect.any(String),
  email: expect.stringContaining('@'),
  // Consumer only cares about these fields; doesn't break if 'role' is added
});
```

Tooling: Pact, Spring Cloud Contract. Without this: breaking changes reach production.

## Migration Path for Breaking Changes

1. Deploy v2 endpoint alongside v1 (both live)
2. Notify consumers via changelog, email, `Sunset` header
3. Monitor v1 traffic — watch for decline
4. After sunset date AND zero traffic: deprecate v1 code
5. After 30-day grace period: remove v1

Never remove before traffic reaches zero. Never set a sunset date less than 90 days out for external APIs.

## Key Rules
- Removing or renaming a field is always a breaking change, regardless of how "internal" the field seems
- Additive changes (new optional fields, new endpoints) never require versioning
- Always add `Sunset` headers at least 90 days before planned removal
- Consumers should be built as tolerant readers — only validate what they use
- Consumer-driven contract tests are the only reliable way to detect breaks before deployment
- Maintain old versions until traffic is zero, not until you think consumers have migrated

# Review: API Breaking Change Detection

## Overview
A breaking change is any modification that causes existing clients to fail without any changes on their end. The cost of accidental breaking changes is high — clients can't predict them, can't test for them until they deploy, and the damage is immediate. Distinguishing breaking from non-breaking changes enables confident API evolution.

## Implementation / Key Points

### Breaking Changes (require major version bump)

**Removed endpoint**
```
DELETE /api/v1/users/:id  removed
```
Any client calling this endpoint now gets 404 instead of expected behavior.

**Removed field from response**
```json
// Before
{ "id": 1, "name": "Alice", "role": "admin" }
// After — role removed
{ "id": 1, "name": "Alice" }
```
Clients accessing `response.role` get `undefined` or throw.

**Changed field type**
```json
// Before: id is number
{ "id": 123 }
// After: id is string
{ "id": "user_123" }
```
Clients doing arithmetic or strict equality (`id === 123`) break silently.

**Changed required ↔ optional**
Making an optional field required breaks existing requests that don't include it. Making a required field optional doesn't break existing clients (non-breaking).

**Renamed field**
```json
// Before
{ "firstName": "Alice" }
// After — renamed
{ "first_name": "Alice" }
```
Clients reading `firstName` get undefined.

**Changed behavior** (silent breaking changes — hardest to detect)
- Changed status codes (200 → 201, 400 → 422)
- Changed validation rules (was permissive, now strict)
- Changed auth requirements (was public, now requires token)
- Changed pagination behavior (page-based → cursor-based)
- Changed error response shape

### Non-Breaking Changes (safe to deploy)
- Added optional field to request body
- Added field to response (clients ignore unknown fields)
- Added new endpoint
- Added new enum value (unless client validates exhaustively)
- Made a required request field optional
- Loosened validation (accepting more input)
- Performance improvements with same semantics

**Careful with enum values:** Adding a value to a response enum is breaking if any client does exhaustive matching and throws on unknown values.

### Detection Tools

**OpenAPI / JSON Schema diff:**
```bash
# Using openapi-diff
npx openapi-diff old-spec.yaml new-spec.yaml

# Using oasdiff
oasdiff breaking old-spec.yaml new-spec.yaml
```

**Contract testing (Pact):**
Consumer defines what it expects. Provider verifies it still delivers that. Catches breaking changes before deploy.

```typescript
// Consumer test defines the contract
provider
  .given('user exists')
  .uponReceiving('GET /users/1')
  .willRespondWith({
    status: 200,
    body: { id: integer(), name: string() }
  });
```

### Versioning Strategy
```
/api/v1/users  — current stable
/api/v2/users  — new version with breaking changes
```
Maintain v1 for a deprecation window (typically 6–12 months), emit `Deprecation` header:
```
Deprecation: true
Sunset: Sat, 31 Dec 2025 23:59:59 GMT
Link: <https://api.example.com/v2>; rel="successor-version"
```

### Changelog Format
```
## Breaking Changes
- `GET /orders` — removed `customerName` field from response. Use `customer.name` instead.

## Non-Breaking Changes  
- `GET /orders` — added `customer.email` field to response
- `POST /orders` — `notes` field is now optional (was required)
```

## Key Rules
- Any field removal or type change in a response is a breaking change, regardless of how "unimportant" it seems
- Behavior changes (status codes, validation, auth) are breaking even if the schema looks identical
- Adding optional response fields is non-breaking — clients should tolerate unknown fields
- Use OpenAPI diff tooling in CI to automatically flag breaking changes in PRs
- Version at the URL level (`/v1/`) for public APIs; use headers for internal APIs
- Communicate breaking changes with a minimum 6-month deprecation window for external APIs
- Adding a new enum value is breaking if consumer code pattern-matches exhaustively

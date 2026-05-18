# Principle: Cross-Team APIs

## Overview
An API between two teams is a contract between two organizations. Breaking it without notice is like changing the terms of a business agreement unilaterally. Teams on the consuming side have their own roadmaps, their own deploy schedules, and their own risk tolerances. They cannot absorb a breaking change on your timeline. The practices that make external public APIs trustworthy — versioning, changelogs, deprecation timelines, consumer testing against contracts — apply with equal force to internal APIs.

## Key Points

### Treat Internal APIs as External
The team across the org chart has the same expectations as an external developer:
- "Don't break things without warning"
- "Tell us what's changing and when"
- "Give us time to migrate"

Internal APIs break these expectations more often than external APIs because teams assume informal communication ("I told them in Slack") is sufficient. It is not. Slack is not a changelog.

### Versioning
```
/api/v1/orders        ← stable, no breaking changes
/api/v2/orders        ← new version with breaking changes
```

Introduce a new version for breaking changes:
- Removing a field from a response
- Changing a field's type (string → integer)
- Changing required/optional semantics
- Changing auth method
- Renaming an endpoint

Non-breaking changes go into the existing version:
- Adding optional fields to responses
- Adding optional query params
- Adding new endpoints

### Backward Compatibility Rules
```ts
// BREAKING — consumers reading `userName` will break
type UserV1 = { userId: string; userName: string; }
type UserV2 = { userId: string; name: string; } // renamed field

// NON-BREAKING — old consumers ignore the new field
type UserV1 = { userId: string; userName: string; }
type UserV1_1 = { userId: string; userName: string; displayName?: string; } // new optional field
```

### Deprecation Timeline
When deprecating a version:
1. Announce deprecation with a sunset date (minimum 90 days)
2. Return `Deprecation` and `Sunset` headers on deprecated endpoints
3. Log which consumers are still calling the deprecated version
4. Contact consuming teams directly if they haven't migrated before sunset
5. Remove the endpoint on or after the sunset date

```http
HTTP/1.1 200 OK
Deprecation: true
Sunset: Sat, 01 Jan 2026 00:00:00 GMT
Link: </api/v2/orders>; rel="successor-version"
```

### Consumer-Driven Contract Testing
The consuming team defines what they need from the API; the provider proves they satisfy it:
```ts
// Consumer (team B) defines contract
const contract = {
  endpoint: 'GET /api/v1/users/:id',
  response: {
    id: expect.any(String),
    email: expect.any(String),
    // Note: they don't care about "phone" field — it's optional for them
  },
};

// Provider (team A) runs contract tests in their CI
// If team A tries to remove "email", the contract test fails
// Even if team A thinks no one uses "email"
```

Tools: Pact.io for full contract testing, or shared OpenAPI schemas with validation.

### Changelog and Communication
- Every API change has a changelog entry
- Semantic versioning for the API itself (not just URL versioning)
- Slack announcements go to a dedicated `#api-changes` channel (not a DM to one person)
- Breaking changes require individual outreach to consuming teams, not just a Slack post

### API Design Decisions Are Long-Term Decisions
The shape of an API that has consumers is very expensive to change. Before shipping:
- Run the API design by consumers before implementation (API-first: design the interface, get feedback, then build)
- Identify optional vs. required fields correctly — required fields added later are breaking
- Document what behavior consuming teams can rely on vs. implementation details they should not

## Key Rules
- Slack ≠ changelog; API changes require formal documentation visible to all consuming teams
- Any field removal, rename, or type change is a breaking change — requires a new version
- Deprecation requires a minimum 90-day sunset window with active monitoring of who still calls the old version
- Run consumer-driven contract tests in CI — the provider's CI should catch contract violations before they deploy
- API design reviews with consuming teams happen before implementation, not after
- "No one uses that field" is something you verify with telemetry, not something you assume
- Internal API stability = external API stability; treat them identically

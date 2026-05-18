# Principle: API Contract Design

## Why Contracts Matter More Than Code

A contract is a promise about the shape and behavior of an API. The producer (server) promises to send data in a certain form; the consumer (client) promises to request data in a certain form. When contracts are implicit — understood by convention, tribal knowledge, or reading the source — they break in production when one side changes without notifying the other.

Making contracts explicit makes breakage detectable before deployment. Consumer-driven contract testing makes it automatic.

## Consumer-Driven Contracts

In most organizations, the API server team decides what to expose. Consumer-driven contracts reverse this: each consumer documents what it actually uses, and the server verifies it still satisfies all consumers before any change ships.

This matters because servers tend to think "I'll add this field for Consumer A, and Consumer B can ignore it." Consumer B does ignore it — until six months later when Consumer B is being debugged and someone notices it was never receiving the data it should have been.

Tools like Pact capture the consumer's expectations as a contract file:

```ts
// Consumer test (Pact example)
await provider.addInteraction({
  uponReceiving: 'a request for user profile',
  withRequest: { method: 'GET', path: '/users/123' },
  willRespondWith: {
    status: 200,
    body: { id: like('123'), email: like('user@example.com') } // flexible matchers
  }
});
```

The contract is published to a Pact Broker. The server runs provider verification tests against all published contracts in CI. If any consumer's expectations break, the server build fails before deployment.

## Backward Compatibility Rules

Changes to an API fall into two categories: safe and breaking.

**Safe (additive) changes:**
- Adding a new optional field to a response
- Adding a new optional request parameter
- Adding a new endpoint
- Relaxing a constraint (allowing more values where fewer were allowed)

**Breaking changes:**
- Removing a field from a response
- Renaming a field
- Changing a field's type
- Making an optional field required
- Changing the semantics of a field (same name, different meaning)

The rule: **never remove or rename a field in a versioned API.** Add the new field, keep the old one, and mark the old one deprecated. Remove it only after all consumers have migrated.

Semantic changes are the most dangerous — the API looks the same to type checkers but behaves differently. Document semantic changes explicitly in changelog entries and deprecation notices.

## Deprecation Headers

Use standard HTTP headers to signal deprecation:

```
Deprecation: true
Sunset: Sat, 31 Dec 2026 23:59:59 GMT
Link: <https://api.example.com/v2/users>; rel="successor-version"
```

`Deprecation` signals the field/endpoint is deprecated. `Sunset` gives the removal date. `Link` points to the replacement. Consumers can log these headers to surface deprecation warnings in their own monitoring.

## Versioning Strategy

Two dominant approaches:

**URL versioning** (`/v1/users`, `/v2/users`): Explicit, cacheable, easy to route in proxies. Every breaking change requires a new URL. Old versions run in parallel until consumers migrate.

**Header versioning** (`Accept: application/vnd.api+json; version=2`): Cleaner URLs but harder to test in a browser, harder to cache selectively. Better for internal APIs where consumers are controlled.

For public APIs, URL versioning wins — it's unambiguous and requires no documentation for consumers to discover.

Avoid minor versioning (`/v1.1/`). Minor versions signal "this might break you but probably won't" — a meaningless promise. Ship additive changes without a version bump; save version bumps for actual breaking changes.

## Key Rules

- **Additive changes are always safe; removals and renames are always breaking** — treat every field removal as a major version change.
- **Use consumer-driven contract tests** to catch breaking changes before deployment, not after.
- **Keep deprecated fields alive** until all consumers have migrated; use `Sunset` headers to communicate the removal date.
- **Version by URL for public APIs** — it's explicit, cacheable, and doesn't require consumers to set headers.
- **Never change field semantics without a version bump** — type safety doesn't catch meaning changes.

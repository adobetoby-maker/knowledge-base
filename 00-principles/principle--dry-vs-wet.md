# Principle: DRY vs WET — When to Abstract

## The Rule vs The Trap

DRY (Don't Repeat Yourself) is the correct default. But premature DRY is more damaging than duplication. The test is not "does this code look similar?" — it is "does this code have the same reason to change?"

## When NOT to Abstract (WET is better)

Three identical-looking code blocks are not enough justification for abstraction. You also need:

1. **They change together** — if one changes, all change identically
2. **The abstraction has a clear name** — if you can't name it, it's not a concept yet
3. **All callers will always want the same behavior** — no special-cases needed now or soon

Code that looks the same but serves different domains should stay separate:

```ts
// These look identical but are NOT the same thing
// Bad: abstract into one function
function validateEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
}

// Contact form email validation
function validateContactEmail(email: string) { /* same regex */ }

// Payment billing email validation  
function validateBillingEmail(email: string) { /* same regex */ }
```

If the billing email later needs to match company domain, or the contact email needs to accept `+` aliases — they diverge. Separate functions are correct.

## When to Abstract

```ts
// BAD: Duplicated logic with single reason to change
function getAdminUser(userId: string) {
  return db.query.users.findFirst({
    where: and(eq(users.id, userId), eq(users.role, 'admin')),
    columns: { password: false },  // Exclude password — security requirement
  })
}

function getPortalUser(userId: string) {
  return db.query.users.findFirst({
    where: and(eq(users.id, userId), eq(users.role, 'portal')),
    columns: { password: false },  // Same security requirement
  })
}

// If "exclude password" is a single security requirement:
function excludePassword<T>(query: T): T & { columns: { password: false } } {
  return { ...query, columns: { ...(query as any).columns, password: false } }
}
```

## The Rule of Three

Wait until the third time before abstracting. The first two instances might be coincidence. The third is a pattern.

1. First time: write it
2. Second time: write it again, leave a note
3. Third time: now abstract

## Abstractions That Age Well

Good abstractions have stable interfaces. These tend to last:
- Formatting utilities (currencies, dates, phone numbers)
- HTTP client wrappers with auth/retry
- Validation schemas for shared data shapes
- Database query builders for common patterns

Bad abstractions decay quickly:
- "Generic" form components with 15 props for every variant
- Shared UI components between two apps with different design systems
- "BaseComponent" patterns — inheritance doesn't compose

## Test for Coupling

Before extracting shared code, ask: if one caller needs to change this behavior, will the other callers also need the change? If yes, abstract. If no, the similarity is superficial.

## Key Rules

- Duplication is far cheaper than the wrong abstraction.
- The name of the abstraction is the first test — if you need 3 adjectives to describe it, it's not a concept.
- Library code gets abstracted early; application code gets abstracted late (when the pattern stabilizes).
- Never abstract to reduce line count — abstract to reduce reasons to change.

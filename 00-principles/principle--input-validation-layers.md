# Defense-in-Depth Input Validation

Input validation is not a single gate — it's a series of layers, each with a distinct purpose and failure mode. Removing any layer because another layer exists is a mistake, because each layer defends against threats and failure modes that others cannot.

## Layer 1: Client-Side Validation (UX Only)

Client-side validation exists for **user experience**, not security. Its job is to give immediate feedback — highlighting an empty required field before the form is submitted, showing a character count as the user types, formatting a phone number inline.

Client-side validation can always be bypassed. Any attacker with browser dev tools can disable it, modify it, or skip it entirely with a direct HTTP request. Never treat client-side validation as a security control. Never make authorization decisions based on client-side checks.

The cost of this misconception: teams that rely on client-side validation for security find that their API is unprotected when called directly from scripts, automated tools, or compromised clients.

## Layer 2: Server Boundary Validation (Schema Validation with Zod/Similar)

Every external input that crosses the server boundary — HTTP request body, query params, headers, webhook payloads, message queue messages — must be validated against an explicit schema before it touches business logic.

Zod (TypeScript) or equivalent schema validators provide:
- Type coercion and parsing (string `"42"` → number `42` if expected)
- Structural validation (required fields present, no unexpected fields)
- Semantic validation (email format, string length, enum membership)
- A typed output — after parsing, the data is typed as the schema's output type

Don't validate "manually" with if/else chains. Schema validators are declarative, composable, and generate useful error messages. The validation should happen at the entry point (route handler, API handler) before any service layer code runs.

Return structured 422 errors with field-level detail when validation fails. Don't return the raw Zod error object — map it to your standard error envelope.

## Layer 3: Database Constraints (NOT NULL, CHECK, FOREIGN KEY, UNIQUE)

Database constraints are the last line of defense and the one that cannot be bypassed by application code. No matter what bug exists in the service layer, a `NOT NULL` constraint on a required column prevents null from being written. A `UNIQUE` constraint prevents duplicate email addresses even if the application-level uniqueness check has a race condition.

Database constraints should encode the invariants of the domain that must always hold, regardless of what code path reached the write. They are not redundant with schema validation — they defend against:
- Application bugs that bypass validation
- Migrations that run ad-hoc SQL
- Direct database access by developers
- Race conditions between validation-check and write

Use them for: required fields (`NOT NULL`), valid ranges (`CHECK (price > 0)`), referential integrity (`FOREIGN KEY`), uniqueness (`UNIQUE`). Don't use them for complex business rules that require cross-table logic — those belong in the service layer.

## Why Every Layer Is Needed

The layers address different threat models:

| Layer | What it stops |
|---|---|
| Client | Honest mistakes, UX friction |
| Server boundary | Malformed input, type errors, field validation, missing required data |
| DB constraints | Application bugs, race conditions, direct DB writes, migration errors |

A missing server boundary layer means business logic receives untrusted data and must handle every possible garbage value throughout its call chain. A missing database layer means any bug or race condition in the application can corrupt the data permanently. A missing client layer means users wait for a round-trip to find out they made a typo.

## Key Rules

- Client-side validation is UX only; it is never a security control
- Every server entry point validates input against an explicit schema (Zod, Joi, etc.) before running business logic
- Return 422 with field-level error details when server validation fails
- Database constraints encode invariants that must hold regardless of code path
- Use `NOT NULL`, `CHECK`, `UNIQUE`, and `FOREIGN KEY` for domain invariants, not for complex business rules
- Never remove a validation layer because another layer "should" catch it — they defend against different failure modes

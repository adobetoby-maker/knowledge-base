# Convention Over Configuration

Convention over configuration means the framework (or codebase) makes decisions by default based on names and locations, rather than requiring explicit setup. The developer only specifies the exceptional cases.

## Why It Exists

Configuration explodes. Every explicit wiring decision — this route maps to this handler, this component imports this stylesheet — is a line of code that can be wrong, out of date, or misunderstood. When there are 200 routes, 200 import statements become the dominant maintenance surface.

Conventions eliminate that surface. Name the file `app/dashboard/page.tsx` and it becomes the `/dashboard` route — no routing config needed. The name encodes the intent. This trades documentation (the config file) for discoverability (the file system).

## Next.js File-System Routing as the Prime Example

Next.js App Router is the clearest illustration: file location determines URL, `page.tsx` exports the page component, `layout.tsx` wraps subtrees, `loading.tsx` provides suspense fallback, `error.tsx` provides error boundary, `route.ts` handles API requests. Zero routing configuration for any of these — the conventions do the work.

This is why Next.js teams move faster than teams on custom routers: the decision about where to put things is already made.

## Naming Conventions That Eliminate Configuration

Apply the same principle inside your own codebase:

- `useX.ts` for hooks — nothing imports it that doesn't expect a React hook
- `XContext.tsx` for context providers — consistent, findable, no need to document
- `X.schema.ts` for Zod schemas — co-located with the feature, always findable
- `X.test.ts` alongside `X.ts` — no test directory config needed, tests travel with the code

Every convention you establish is a decision you don't have to make (or debate) again.

## The Downside: Requires Team Knowledge

Conventions are invisible to newcomers. A configuration file is self-documenting — it says "this file at this path maps to this thing." A convention requires knowing the convention exists before you can understand the code.

Conventions also hide magic. When something breaks because a file is in the wrong directory or named wrong, the error message often doesn't explain the convention — it just says the thing wasn't found.

Mitigation: document your conventions once in `CLAUDE.md` or equivalent, enforce them with linting rules where possible, and make violations produce clear error messages.

## Where Configuration Is Still Better

Use explicit configuration when:

- **The variation is high**: different environments need genuinely different behavior — use config files, not naming conventions
- **The cost of mistake is high**: database connection strings, API keys, feature flags that control billing — explicit beats implicit
- **The convention would be non-obvious**: if two reasonable people would put the file in different places, a convention isn't strong enough; add a config
- **Third-party integrations**: external services don't follow your naming conventions; you need explicit wiring

The pattern: use convention for structural decisions (where things live, what they're named), use configuration for values that change (environment-specific settings, secret credentials).

## Key Rules

- Establish naming conventions early and document them in one place
- Use convention for structural decisions; use config for values that vary
- Enforce conventions with linting (ESLint rules, folder-structure tools) so violations are caught at commit time
- When a convention breaks, the error message should name the convention, not just report "not found"
- Don't add configuration files for things the framework already handles by convention — that's duplication
- Conventions are most valuable when the team grows; document them before the team grows, not after

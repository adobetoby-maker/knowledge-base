# Drizzle vs Prisma — When to Use Each

## The Core Difference

Prisma is a full ORM with a custom schema language (`schema.prisma`), a code generator, and a query engine binary bundled at runtime. Drizzle is a TypeScript-native query builder with no code generation step — the schema is TypeScript, and queries are compiled to SQL at build time, not at runtime via a separate process.

This distinction drives every downstream trade-off.

## Where Prisma Falls Short

**Edge runtime incompatibility.** Prisma's query engine is a Rust binary that cannot run inside Cloudflare Workers, Vercel Edge Functions, or any V8-isolate environment. The official workaround is Prisma Accelerate (a paid proxy). Drizzle compiles to plain SQL strings and ships zero native binaries — it works anywhere `fetch` works.

**Bundle size.** Prisma's generated client plus the query engine adds 40–80 MB to a cold container. This is irrelevant for a long-lived Node server but catastrophic for serverless cold starts. Drizzle's entire footprint is a few KB of JS.

**Code generation friction.** Every schema change requires running `prisma generate`, and the generated client must be re-committed or re-built in CI. Drizzle has no generate step — change the TypeScript schema file and TypeScript re-infers automatically.

## Where Prisma Still Wins

**Relational query API (`include` / nested reads).** Prisma's `include` deeply nests related records in a single round trip with automatic result shaping. Drizzle's relational API (`drizzle.query.users.findMany({ with: { posts: true } })`) matches this capability but requires explicit `relations()` declarations in the schema file — more setup, same power once configured.

**Migration ergonomics for beginners.** `prisma migrate dev` generates a named SQL migration, applies it, and handles shadow databases automatically. Drizzle Kit's `drizzle-kit generate` + `drizzle-kit migrate` is comparable but less hand-holding — you own the SQL files more directly, which is a feature for teams that want full control and a stumbling block for those who don't.

**Ecosystem and community.** Prisma has more tutorials, Stack Overflow answers, and third-party adapters (NextAuth Prisma adapter, etc.).

## Decision Matrix

| Situation | Choose |
|---|---|
| Cloudflare Workers / Edge runtime | **Drizzle** — Prisma cannot run here without Accelerate |
| Serverless (Lambda, Vercel Functions) with cold start sensitivity | **Drizzle** — smaller bundle |
| Long-lived Node.js server (Express, Fastify) | Either; Prisma if team prefers its DX |
| Need declaration merging / augmenting generated types | **Drizzle** — schema is just TypeScript |
| Team is junior or unfamiliar with raw SQL | **Prisma** — better error messages, more guardrails |
| Complex nested reads are the primary query pattern | Either; Drizzle relational API is now at parity |

## The Migration Path

Projects in this workspace use Drizzle on Cloudflare/TanStack Start (LinguaLens) and Prisma is unused. When migrating from Prisma to Drizzle, the main work is rewriting `schema.prisma` as `db/schema.ts` using `pgTable`/`sqliteTable` declarations and replacing `prisma.model.findMany(...)` calls with Drizzle's `db.select().from(table)` API.

## Key Rules

- **Never use Prisma on an edge runtime** without Accelerate — it will fail silently during deployment or crash at invocation.
- **Always declare `relations()`** in Drizzle schema files before using the relational query API — without it, `with:` is not available on the query builder.
- Drizzle migrations are plain SQL files you own; commit them to version control and treat them like database contracts.
- If a project uses NextAuth with the Prisma adapter and you switch to Drizzle, replace the adapter with `@auth/drizzle-adapter` — do not attempt to bridge the two ORMs.
- Do not mix Prisma Client and Drizzle in the same project — pick one and be consistent.

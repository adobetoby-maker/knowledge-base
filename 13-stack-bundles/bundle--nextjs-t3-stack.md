# T3 Stack — Next.js + tRPC + Prisma + NextAuth + Tailwind

## What T3 Is

T3 is an opinionated fullstack Next.js scaffold that prioritizes end-to-end type safety. The core insight: if your database schema, server logic, and client calls all share types, an entire class of bugs (mismatched API contracts) becomes a compile-time error. tRPC is the mechanism that delivers this — it generates a type-safe client from your router definition with zero code generation.

## tRPC Router Definition

Define procedures in a router file. Routers compose into an `appRouter` that becomes the type export.

```ts
// server/api/routers/invoice.ts
import { z } from 'zod';
import { createTRPCRouter, protectedProcedure } from '~/server/api/trpc';

export const invoiceRouter = createTRPCRouter({
  list: protectedProcedure
    .input(z.object({ clientId: z.string().optional() }))
    .query(async ({ ctx, input }) => {
      return ctx.db.invoice.findMany({
        where: { clientId: input.clientId },
        orderBy: { createdAt: 'desc' },
      });
    }),

  create: protectedProcedure
    .input(z.object({ amount: z.number(), clientId: z.string() }))
    .mutation(async ({ ctx, input }) => {
      return ctx.db.invoice.create({ data: { ...input, userId: ctx.session.user.id } });
    }),
});

// server/api/root.ts
export const appRouter = createTRPCRouter({ invoice: invoiceRouter });
export type AppRouter = typeof appRouter; // <-- export this type
```

## Type-Safe Client Usage

The client derives its types from `AppRouter` — no codegen, no schema files, no `openapi.json`.

```ts
// In a client component
const { data: invoices } = api.invoice.list.useQuery({ clientId: '123' });
const create = api.invoice.create.useMutation({
  onSuccess: () => utils.invoice.list.invalidate(),
});
```

TypeScript errors at the call site if you pass wrong input types or access non-existent fields on the response. This is the entire value proposition.

## Prisma Schema with NextAuth Adapter

The NextAuth Prisma adapter requires specific models in your schema. Do not omit any of these fields — NextAuth will fail silently or throw at runtime if they are missing.

```prisma
model Account {
  id                String  @id @default(cuid())
  userId            String
  type              String
  provider          String
  providerAccountId String
  refresh_token     String? @db.Text
  access_token      String? @db.Text
  expires_at        Int?
  token_type        String?
  scope             String?
  id_token          String? @db.Text
  session_state     String?
  user              User    @relation(fields: [userId], references: [id], onDelete: Cascade)
  @@unique([provider, providerAccountId])
}

model Session {
  id           String   @id @default(cuid())
  sessionToken String   @unique
  userId       String
  expires      DateTime
  user         User     @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model User {
  id            String    @id @default(cuid())
  name          String?
  email         String?   @unique
  emailVerified DateTime?
  image         String?
  accounts      Account[]
  sessions      Session[]
}

model VerificationToken {
  identifier String
  token      String   @unique
  expires    DateTime
  @@unique([identifier, token])
}
```

## The Core Trade-off vs REST API

**tRPC couples your client to your server schema.** If the tRPC server and client are deployed separately (a public API consumed by third parties, a mobile app with its own release cycle, microservices), the tight coupling becomes a liability — you cannot update the server without coordinating all clients.

T3 is designed for **monorepos where client and server deploy together**. The coupling is a feature in that context. The moment you need a public API or a separately-deployed consumer, switch to REST + OpenAPI or GraphQL where the contract is an explicit, versioned document.

## Key Rules

- **Export `AppRouter` type from the server** and import it in the client provider — without this the client has no types.
- **Always use Zod for input validation** in procedures — `protectedProcedure.input(zodSchema)` runs server-side validation before your query/mutation logic executes.
- **Run `prisma migrate dev` before `npm run dev`** after schema changes — the Prisma client will be out of sync with the database otherwise.
- Use `protectedProcedure` for any procedure that requires auth — it throws `UNAUTHORIZED` automatically if `ctx.session` is null.
- Do not use T3/tRPC for endpoints that need to be called by external services or third-party clients — build a standard REST route handler for those.

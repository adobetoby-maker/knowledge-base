# Disambig: Prisma vs Drizzle

## Overview
Both are TypeScript ORMs for relational databases. Prisma generates a type-safe client from a schema file with a build step (`prisma generate`). Drizzle is SQL-first with no code generation — you define tables as TypeScript objects and queries mirror SQL syntax. Drizzle runs at the edge (Cloudflare Workers, Vercel Edge) where Prisma's generated client requires Node.js.

## Implementation / Key Points

### Schema Definition

**Prisma — Schema DSL:**
```prisma
// schema.prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  orders    Order[]
  createdAt DateTime @default(now())
}

model Order {
  id         String   @id @default(cuid())
  userId     String
  user       User     @relation(fields: [userId], references: [id])
  total      Decimal
  createdAt  DateTime @default(now())
}
```
After schema change: `npx prisma generate` → regenerates the type-safe client.

**Drizzle — TypeScript tables:**
```typescript
// schema.ts
import { pgTable, text, decimal, timestamp } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: text('id').primaryKey().$defaultFn(() => createId()),
  email: text('email').notNull().unique(),
  name: text('name'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const orders = pgTable('orders', {
  id: text('id').primaryKey().$defaultFn(() => createId()),
  userId: text('user_id').notNull().references(() => users.id),
  total: decimal('total').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});
```
No build step — types inferred directly from the schema definition.

### Query Syntax

**Prisma — Relations API:**
```typescript
// Include related data
const users = await prisma.user.findMany({
  include: { orders: true },
  where: { orders: { some: { total: { gt: 100 } } } },
});

// Update with nested create
await prisma.order.create({
  data: {
    userId: 'user_1',
    total: 150,
    items: { create: [{ productId: 'p_1', quantity: 2 }] },
  },
});
```

**Drizzle — SQL-first:**
```typescript
// SELECT with JOIN
const users = await db
  .select({ user: users, orderTotal: orders.total })
  .from(users)
  .leftJoin(orders, eq(orders.userId, users.id))
  .where(gt(orders.total, 100));

// INSERT
await db.insert(orders).values({ userId: 'user_1', total: '150' });
```
Drizzle queries read like SQL. If you know SQL, you know what query will be generated.

### Migrations

**Prisma:** `npx prisma migrate dev` generates SQL migration from schema diff. `prisma migrate deploy` applies in production. Prisma Studio provides a browser UI.

**Drizzle:** `npx drizzle-kit generate` generates SQL from schema diff. `npx drizzle-kit push` for rapid dev. No browser UI (Drizzle Studio is available but newer).

### Edge Runtime Compatibility
```typescript
// Drizzle + Cloudflare D1 (edge-native)
import { drizzle } from 'drizzle-orm/d1';
export default {
  fetch: async (request, env) => {
    const db = drizzle(env.DB);
    const users = await db.select().from(users);
    return Response.json(users);
  },
};

// Prisma requires @prisma/adapter-d1 for edge — more complex
```
Prisma's generated client uses Node.js APIs by default. Edge adapters exist but add complexity. Drizzle is zero-dependency and runs natively in V8 environments.

### Decision Matrix
| Scenario | Choice |
|---|---|
| Cloudflare Workers / edge runtime | Drizzle |
| Standard Node.js + Next.js | Either (Prisma has more documentation) |
| Complex relations with nested writes | Prisma (better API for this) |
| Team comfortable with SQL | Drizzle |
| Need Prisma Studio / GUI | Prisma |
| Bundle size sensitive | Drizzle (~35KB vs Prisma ~500KB) |
| Neon / PlanetScale HTTP driver | Drizzle (native support) |

## Key Rules
- Use Drizzle for Cloudflare Workers — Prisma's generated client is not edge-compatible without adapters
- Use Prisma when the team prefers a high-level API over writing SQL-like queries
- Drizzle's SQL-first API means you understand the generated query — Prisma can surprise with N+1 or missing joins
- `prisma generate` must run after every schema change — forgetting causes type errors at runtime, not compile time
- Both generate correct SQL; the difference is API ergonomics and runtime compatibility
- The workspace pattern (`drizzle-orm/schema` + separate `db` client) prevents circular dependency issues in Drizzle

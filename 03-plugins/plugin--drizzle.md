# Plugin: Drizzle ORM

## Overview

Drizzle is a lightweight, SQL-first TypeScript ORM. Schema is defined in TypeScript, not a separate DSL. Works in all runtimes including Cloudflare Workers and Edge environments where Prisma does not run.

## When to Choose Drizzle Over Prisma

| Factor | Drizzle | Prisma |
|--------|---------|--------|
| Cloudflare Workers / Edge | Yes | No (Node.js runtime only) |
| Bundle size | ~40KB | ~3MB+ |
| SQL transparency | High (writes SQL-like TS) | Lower (magic ORM methods) |
| Migration tooling | Basic (drizzle-kit) | Excellent (migrate dev/deploy) |
| Query complexity | Excellent | Good with $queryRaw fallback |
| Ecosystem maturity | Newer | Mature |

Choose Drizzle for: Cloudflare Workers, edge deployments, Neon serverless, when you want full SQL control with types.

## Setup

```ts
// db/schema.ts
import { pgTable, text, timestamp, boolean, uuid } from 'drizzle-orm/pg-core'

export const users = pgTable('users', {
  id: uuid('id').defaultRandom().primaryKey(),
  email: text('email').unique().notNull(),
  name: text('name'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
})

export const posts = pgTable('posts', {
  id: uuid('id').defaultRandom().primaryKey(),
  title: text('title').notNull(),
  body: text('body').notNull(),
  published: boolean('published').default(false).notNull(),
  authorId: uuid('author_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
})
```

```ts
// db/index.ts — for Cloudflare Workers + Neon
import { neon } from '@neondatabase/serverless'
import { drizzle } from 'drizzle-orm/neon-http'

const sql = neon(process.env.DATABASE_URL!)
export const db = drizzle(sql)

// For Node.js + postgres.js
import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'

const client = postgres(process.env.DATABASE_URL!)
export const db = drizzle(client)
```

## Query Patterns

```ts
import { eq, and, desc, like, sql } from 'drizzle-orm'
import { db } from './db'
import { users, posts } from './schema'

// Select
const user = await db.select().from(users).where(eq(users.email, 'test@example.com')).limit(1)

// Insert
const [newUser] = await db.insert(users).values({ email: 'new@example.com', name: 'New' }).returning()

// Update
await db.update(posts).set({ published: true }).where(eq(posts.id, postId))

// Delete
await db.delete(users).where(eq(users.id, userId))

// Join
const postsWithAuthors = await db
  .select({ post: posts, author: users })
  .from(posts)
  .innerJoin(users, eq(posts.authorId, users.id))
  .where(eq(posts.published, true))
  .orderBy(desc(posts.createdAt))
  .limit(20)

// Aggregate
const [{ count }] = await db
  .select({ count: sql<number>`count(*)::int` })
  .from(posts)
  .where(eq(posts.published, true))
```

## Type Inference

```ts
import type { InferSelectModel, InferInsertModel } from 'drizzle-orm'
import { users } from './schema'

type User = InferSelectModel<typeof users>
type NewUser = InferInsertModel<typeof users>
```

Never manually type your models. `InferSelectModel` and `InferInsertModel` derive types directly from your schema, staying in sync automatically as you change columns.

## Migrations with drizzle-kit

```bash
# Generate migration SQL from schema changes
npx drizzle-kit generate

# Push schema directly to database (dev only — no migration files)
npx drizzle-kit push

# Drizzle Studio — GUI
npx drizzle-kit studio
```

`push` is for rapid prototyping. `generate` creates migration files in `drizzle/` — commit these. Run migrations in CI with a custom script:

```ts
// scripts/migrate.ts
import { migrate } from 'drizzle-orm/postgres-js/migrator'
import { db } from '../db'

await migrate(db, { migrationsFolder: './drizzle' })
process.exit(0)
```

## Drizzle + Cloudflare D1

```ts
import { drizzle } from 'drizzle-orm/d1'

// In Cloudflare Worker handler
export default {
  async fetch(request: Request, env: Env) {
    const db = drizzle(env.DB)  // env.DB is the D1 binding
    const users = await db.select().from(usersTable)
    return Response.json(users)
  }
}
```

D1 is SQLite, so use `sqliteTable` from `drizzle-orm/sqlite-core` instead of `pgTable`. Most query syntax is identical.

## Transaction Pattern

```ts
const result = await db.transaction(async (tx) => {
  const [order] = await tx.insert(orders).values(orderData).returning()
  await tx.insert(orderItems).values(items.map((i) => ({ ...i, orderId: order.id })))
  return order
})
```

Transactions roll back automatically if any operation throws. Return values from the callback to access them outside.

# Plugin: Kysely Type-Safe Query Builder

## Purpose
Write complex SQL queries in TypeScript with full type inference — no raw strings, no ORM magic, no hidden N+1s. Kysely sits between "raw SQL" and "full ORM": you still write SQL-shaped code, but the compiler catches column name typos, wrong join conditions, and missing `where` clauses at build time.

## Why Kysely Over Raw SQL or a Full ORM
- **vs raw SQL**: Column names are typed — a renamed column is a compile error, not a runtime crash.
- **vs Prisma/Drizzle ORM**: Kysely doesn't generate queries for you; you write them. This means you can write exactly the query you need without fighting the ORM's abstraction. For complex analytical queries, aggregations, or CTEs, Kysely wins.
- **vs Drizzle query builder**: Similar positioning. Choose Kysely when you want stronger SQL expressiveness; choose Drizzle when you want the relational query API (`db.query.*`). They can coexist.

## Setup
Generate the DB type from your schema (use `kysely-codegen` against a live DB, or write it manually):

```ts
import { Kysely, PostgresDialect } from 'kysely';
import { Pool } from 'pg';

export const db = new Kysely<Database>({ dialect: new PostgresDialect({ pool: new Pool() }) });
```

Where `Database` is an interface mapping table names to row types.

## Core Query Pattern — Chaining
```ts
const users = await db
  .selectFrom('users')
  .select(['id', 'email', 'created_at'])
  .where('status', '=', 'active')
  .where('created_at', '>', cutoffDate)
  .orderBy('created_at', 'desc')
  .limit(50)
  .execute();
```

Every `.select()` call narrows the return type. If you select `['id', 'email']`, the result type only has those two fields — no accidental access to other columns.

## Relations with `jsonArrayFrom`
Kysely doesn't have Prisma-style `include`. Instead, use `jsonArrayFrom` (from `kysely/helpers/postgres`) to embed related rows:

```ts
import { jsonArrayFrom } from 'kysely/helpers/postgres';

const orders = await db
  .selectFrom('orders')
  .select(eb => [
    'orders.id',
    'orders.total',
    jsonArrayFrom(
      eb.selectFrom('order_items')
        .select(['id', 'product_id', 'quantity', 'price'])
        .whereRef('order_items.order_id', '=', 'orders.id')
    ).as('items'),
  ])
  .where('orders.user_id', '=', userId)
  .execute();
```

This compiles to a single query using a lateral join — no N+1. The `items` field on each result is typed as `{ id: string, product_id: string, quantity: number, price: number }[]`.

## Migrations
Kysely has a built-in migration runner. Define migrations as files returning `up` and `down` functions:

```ts
export const up = async (db: Kysely<unknown>): Promise<void> => {
  await db.schema.createTable('users')
    .addColumn('id', 'uuid', col => col.primaryKey().defaultTo(sql`gen_random_uuid()`))
    .addColumn('email', 'text', col => col.notNull().unique())
    .execute();
};
export const down = async (db: Kysely<unknown>): Promise<void> => {
  await db.schema.dropTable('users').execute();
};
```

Run migrations: `new Migrator({ db, provider }).migrateToLatest()`. In production, run this at startup or as a separate pre-deploy step. Never run raw `ALTER TABLE` in production without a migration file.

## Complex Queries — CTEs and Subqueries
Kysely handles CTEs natively:
```ts
const result = await db
  .with('ranked_users', db =>
    db.selectFrom('users')
      .select(['id', sql<number>`row_number() over (order by created_at)`.as('rank')])
  )
  .selectFrom('ranked_users')
  .select(['id', 'rank'])
  .where('rank', '<=', 10)
  .execute();
```

Use CTEs when a subquery is referenced more than once. Kysely will inline them correctly.

## Key Rules
- **Use `jsonArrayFrom` for relations** — it compiles to a single query with no N+1 risk
- **Run migrations via Kysely's `Migrator`** — don't mix with raw ALTER TABLE statements
- **Type the `Database` interface from your actual schema** — use `kysely-codegen` to generate it
- **Prefer Kysely for complex analytical queries** — it's more expressive than Drizzle's relational API for CTEs and window functions
- **Use `.executeTakeFirstOrThrow()`** when expecting exactly one row — it throws a typed error instead of returning `undefined`
- **Never use `sql` template literals for user input** — use parameterised `.where()` chains to prevent SQL injection

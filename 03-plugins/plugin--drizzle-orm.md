# Plugin: Drizzle ORM Patterns

## Purpose
Supplement to `plugin--drizzle.md`. This file covers patterns beyond the basics: the relational query API, complex query patterns, connection management in different runtimes, and common traps that produce subtle bugs.

## Relational Query API (`db.query.*`)
Drizzle has two query styles: the SQL-like builder (`db.select().from()`) and the relational API (`db.query.users.findMany()`). The relational API is higher-level and handles joins for you, but requires defining relations:

```ts
// schema.ts
export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').notNull().unique(),
});

export const posts = pgTable('posts', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').references(() => users.id),
  title: text('title').notNull(),
  body: text('body').notNull(),
  publishedAt: timestamp('published_at'),
});

// relations.ts — separate file keeps schema clean
import { relations } from 'drizzle-orm';

export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, { fields: [posts.userId], references: [users.id] }),
}));
```

## `db.query.*` with `with` for Eager Loading
```ts
// Pass both schema and relations when creating the db instance
const db = drizzle(client, { schema: { ...schema, ...relations } });

// Fetch users with their posts
const users = await db.query.users.findMany({
  with: {
    posts: {
      where: (posts, { isNotNull }) => isNotNull(posts.publishedAt),
      orderBy: (posts, { desc }) => [desc(posts.publishedAt)],
      limit: 5,
    },
  },
  where: (users, { eq }) => eq(users.status, 'active'),
});
// users[0].posts is typed as Post[]
```

The relational API compiles to an efficient query (typically a single SQL query with a lateral join), not multiple round trips. Avoid using it as if it were lazy-loading — it's eager by design.

## `extras` for Computed Columns
Add virtual/computed fields to query results without a DB schema change:

```ts
const users = await db.query.users.findMany({
  extras: {
    fullName: sql<string>`concat(${users.firstName}, ' ', ${users.lastName})`.as('full_name'),
    postCount: sql<number>`(select count(*) from posts where posts.user_id = users.id)`.as('post_count'),
  },
});
// users[0].fullName and users[0].postCount are available and typed
```

`extras` is purely for computed read-only values. It's equivalent to adding a derived column in the SELECT clause. The `sql<T>` generic sets the TypeScript type; `as()` sets the column alias.

## `relations()` Definition — What It Does and Doesn't Do
`relations()` only affects the relational query API (`db.query.*`). It does NOT:
- Add foreign key constraints to the DB (use `.references()` in the column definition for that)
- Affect the SQL builder API (`db.select().from()`)
- Generate any SQL

You can define relations between tables that have no FK constraints at the DB level — useful for virtual relationships. Conversely, having a `.references()` FK constraint doesn't automatically give you a relation in `db.query.*` — you must define it explicitly.

## N+1 in the SQL Builder vs Relational API
The SQL builder API doesn't prevent N+1:
```ts
// BAD — N+1
const posts = await db.select().from(postsTable);
for (const post of posts) {
  post.author = await db.select().from(users).where(eq(users.id, post.userId)); // N queries
}

// GOOD — single query with join
const posts = await db
  .select({ post: postsTable, author: users })
  .from(postsTable)
  .leftJoin(users, eq(postsTable.userId, users.id));

// ALSO GOOD — relational API
const posts = await db.query.posts.findMany({ with: { author: true } });
```

Use the relational API when the shape naturally maps to your relations. Use the SQL builder for custom aggregations, CTEs, or when you need fine-grained control over the query structure.

## Connection Pooling Considerations
- **Serverless (Vercel, Cloudflare)**: use `@neondatabase/serverless`, `@libsql/client`, or a connection pooler like PgBouncer/Supabase pooler. Do not use a regular `pg.Pool` — new connections per invocation exhaust Postgres's connection limit.
- **Long-running server**: `pg.Pool` is fine; set `max: 10` (default 10, tune to your Postgres `max_connections`).
- **Edge runtime**: only drivers that don't use Node.js `net` module work — `@neondatabase/serverless` (uses fetch/WebSocket), `@libsql/client` (HTTP mode), Supabase Postgres with `@supabase/supabase-js`.

## Key Rules
- **Pass both schema and relations to `drizzle()`** — `db.query.*` won't know about relations otherwise
- **`relations()` is only for `db.query.*`** — it doesn't add FK constraints or affect the SQL builder
- **Use `with` in `db.query.*` for eager loading** — don't run joins manually then map results
- **`extras` for computed columns** — avoids schema migration for derived read values
- **No N+1 in the SQL builder** — it won't warn you; write joins explicitly or use the relational API
- **Use the right driver for your runtime** — `pg.Pool` will exhaust connections in serverless environments

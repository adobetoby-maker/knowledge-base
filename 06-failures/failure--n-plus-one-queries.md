# Failure: N+1 Query Problem

## What It Is

N+1 occurs when code fetches a list of N items and then issues one query per item to fetch related data — resulting in N+1 database queries instead of 2. Causes severe performance degradation at scale: a page that loads in 50ms with 10 items takes 5+ seconds with 1000 items.

## Example

```ts
// BROKEN: N+1 — 1 query for posts + 1 query per post for author
const posts = await db.query.posts.findMany()  // 1 query

for (const post of posts) {
  post.author = await db.query.users.findFirst({
    where: eq(users.id, post.authorId),  // N queries
  })
}
```

For 100 posts, this runs 101 queries. For 1000 posts, 1001 queries.

## Fix 1: JOIN / with (Drizzle)

```ts
// FIXED: 1 query with JOIN
const posts = await db.query.posts.findMany({
  with: {
    author: true,  // Drizzle generates a JOIN
  },
})
```

## Fix 2: Batch Fetch

When a JOIN isn't clean (e.g., mixing data sources):

```ts
const posts = await db.query.posts.findMany()

// Collect all unique IDs
const authorIds = [...new Set(posts.map(p => p.authorId))]

// Fetch in one query
const authors = await db.query.users.findMany({
  where: inArray(users.id, authorIds),
})

// Build lookup map
const authorMap = new Map(authors.map(a => [a.id, a]))

// Attach
const enriched = posts.map(p => ({ ...p, author: authorMap.get(p.authorId) }))
```

## Fix 3: DataLoader Pattern (GraphQL)

```ts
import DataLoader from 'dataloader'

const userLoader = new DataLoader<string, User>(async (userIds) => {
  const users = await db.query.users.findMany({
    where: inArray(users.id, [...userIds]),
  })
  const map = new Map(users.map(u => [u.id, u]))
  return userIds.map(id => map.get(id) ?? null)
})

// DataLoader automatically batches all getUserById calls in one tick
const author = await userLoader.load(post.authorId)
```

## Detection

### Logging
```ts
// Log query counts per request
let queryCount = 0
db.on('query', () => queryCount++)

// After request: if queryCount > 10, investigate
if (queryCount > 10) {
  logger.warn({ queryCount, path: req.path }, 'High query count — possible N+1')
}
```

### Prisma
```ts
const prisma = new PrismaClient({
  log: [{ level: 'query', emit: 'event' }]
})
prisma.$on('query', e => console.log('Query:', e.query))
```

### Development Only
Use `pg-monitor` or Supabase's "slow query log" to spot repeated queries in dev.

## Common Sources

| Pattern | Symptom |
|---|---|
| ORM lazy loading in a loop | `for await` with nested `findFirst` |
| Template rendering | `{{ post.author.name }}` where author not eager-loaded |
| GraphQL resolvers without DataLoader | Each field resolver issues its own query |
| React component data fetching | Each list item fetches its own data |

## Key Rules

- Any ORM `findFirst` inside a loop is almost certainly an N+1.
- Use `with` / `include` / `eager loading` for known relationships.
- DataLoader is the right fix for GraphQL field resolvers.
- N+1 on a single-page UI appears fast (10 items × 5ms = 50ms). At 1000 items or under concurrent load, it collapses.
- Check query counts in development, not just query performance — a fast query still costs if called 1000 times.

# Failure: API Over-Fetching

## Overview
Over-fetching is fetching more data than is needed for the current view — selecting all columns when only 3 are displayed, loading all records without pagination, or eagerly loading every relation on every request. The symptoms are slow API responses, large JSON payloads, high memory usage on the server, and slow time-to-interactive on the client. It's one of the most impactful performance problems to fix because the gains compound: less data transferred, less parsing, less rendering work.

## Symptoms and Diagnosis

```bash
# Measure payload size in the browser network tab
# Or from the server:
curl -s -o /dev/null -w "%{size_download}" https://api.example.com/users

# In Next.js, log response sizes:
console.log('Response size:', Buffer.byteLength(JSON.stringify(data)), 'bytes')
```

## Fix 1: Select only needed columns

```ts
// BAD: fetches all 40+ columns from users table
const users = await db.user.findMany()

// GOOD: only fetch what the user list UI needs
const users = await db.user.findMany({
  select: {
    id: true,
    name: true,
    email: true,
    role: true,
    createdAt: true,
    // Don't select: passwordHash, resetToken, internalNotes, preferences (JSON blob), etc.
  },
})
```

## Fix 2: Always paginate list endpoints

```ts
// BAD: returns all records, no limit
app.get('/api/users', async (req, res) => {
  const users = await db.user.findMany()
  res.json(users)
})

// GOOD: paginated with cursor or offset
app.get('/api/users', async (req, res) => {
  const page = parseInt(req.query.page as string) || 1
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 100)
  const offset = (page - 1) * limit

  const [users, total] = await Promise.all([
    db.user.findMany({ skip: offset, take: limit, orderBy: { createdAt: 'desc' } }),
    db.user.count(),
  ])

  res.json({
    users,
    pagination: { page, limit, total, pages: Math.ceil(total / limit) },
  })
})
```

## Fix 3: Lazy-load relations

```ts
// BAD: loads all posts with all comments for each post
const users = await db.user.findMany({
  include: {
    posts: {
      include: {
        comments: true,  // Could be thousands of comments
        author: true,
        tags: true,
      }
    }
  }
})

// GOOD: load base users, then load related data only when needed
const users = await db.user.findMany({
  select: { id: true, name: true, email: true, _count: { select: { posts: true } } }
})

// Load post detail only when user clicks "View posts"
async function getUserPosts(userId: string, page = 1) {
  return db.post.findMany({
    where: { authorId: userId },
    select: { id: true, title: true, createdAt: true, _count: { select: { comments: true } } },
    take: 10,
    skip: (page - 1) * 10,
    orderBy: { createdAt: 'desc' },
  })
}
```

## Fix 4: Field projection in API responses

```ts
// Route handler with projection support
app.get('/api/users/:id', async (req, res) => {
  const fields = (req.query.fields as string)?.split(',') ?? null

  const user = await db.user.findUnique({
    where: { id: req.params.id },
    select: fields
      ? Object.fromEntries(fields.map(f => [f, true]))
      : { id: true, name: true, email: true, role: true, bio: true }  // Safe default set
  })

  res.json(user)
})

// Client requests only what it needs
const { data } = useQuery({
  queryKey: ['user', userId, 'card'],
  queryFn: () => fetch(`/api/users/${userId}?fields=id,name,email,avatar`).then(r => r.json()),
})
```

## Fix 5: Aggregate instead of fetch-all

```ts
// BAD: fetch all orders to calculate total
const orders = await db.order.findMany({ where: { userId } })
const total = orders.reduce((sum, o) => sum + o.amount, 0)  // N rows fetched and summed in JS

// GOOD: aggregate in the database
const result = await db.order.aggregate({
  where: { userId },
  _sum: { amount: true },
  _count: true,
})
const total = result._sum.amount ?? 0
```

## Key Rules
- `SELECT *` is almost always wrong in production — select only what the view needs
- Every list endpoint needs pagination — a table with 10,000 rows will eventually break a client that fetches all
- Max page size should be enforced server-side — `Math.min(limit, 100)` prevents abuse
- Related records should load on demand — an initial list view rarely needs the full relation tree
- Measure before optimizing: use the network tab or server logs to identify the worst offenders
- For admin views that genuinely need large datasets, use server-side rendering or streaming
- Cursor-based pagination is better than offset for large tables (consistent performance regardless of page depth)

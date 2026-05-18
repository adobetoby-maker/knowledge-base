# Principle: Zero Trust Security

## What It Means

"Never trust, always verify" — don't assume that a request is authorized just because it comes from inside your network, from a service you control, or from a valid session. Verify authorization on every operation against the specific resource being accessed.

## The Classic Mistake: Perimeter Trust

```ts
// BAD — assumes "logged in" means "can access anything"
async function getOrder(req: Request) {
  const user = await requireAuth(req)  // Only checks if logged in
  const { orderId } = req.params
  return db.query.orders.findFirst({ where: eq(orders.id, orderId) })
  // No check: does this user own this order?
}
```

A logged-in user can fetch any order by guessing the ID. This is IDOR (Insecure Direct Object Reference).

## Object-Level Authorization

```ts
// GOOD — verify ownership on every resource access
async function getOrder(req: Request) {
  const user = await requireAuth(req)
  const { orderId } = req.params
  
  const order = await db.query.orders.findFirst({
    where: and(
      eq(orders.id, orderId),
      eq(orders.userId, user.id),  // Scope to this user
    ),
  })
  
  if (!order) {
    // Return 404, not 403 — don't confirm the order exists
    return Response.json({ error: 'Not found' }, { status: 404 })
  }
  
  return Response.json(order)
}
```

## Service-to-Service Trust

Internal services calling each other don't get a free pass:

```ts
// BAD — assumes internal network = trusted
async function internalJob(req: Request) {
  // No auth check — "only internal callers reach this endpoint"
  await processAllOrders()
}

// GOOD — verify even internal requests
async function internalJob(req: Request) {
  const secret = req.headers.get('x-internal-secret')
  if (secret !== process.env.INTERNAL_SECRET) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 })
  }
  await processAllOrders()
}
```

## Role + Object Authorization

Admin role ≠ access to everything. An admin of Org A should not access Org B's data:

```ts
async function adminGetUser(req: Request) {
  const admin = await requireAdmin(req)
  const { userId } = req.params
  
  const user = await db.query.users.findFirst({
    where: and(
      eq(users.id, userId),
      eq(users.orgId, admin.orgId),  // Admin can only see their own org's users
    ),
  })
  
  if (!user) return notFound()
  return user
}
```

## Row-Level Security (Postgres RLS)

Enforce authorization at the database level — not just at the application layer:

```sql
-- Policy: users can only see their own data
CREATE POLICY "users_own_data" ON orders
  FOR ALL
  USING (user_id = auth.uid());
```

RLS means even if application code has a bug, the database refuses unauthorized reads.

## Defense in Depth

Multiple layers, each independently enforcing authorization:

```
1. Network: Firewall rules, no public access to admin endpoints
2. Application: requireAuth() + ownership check on every route
3. Database: RLS policies enforce same rules at DB level
4. Audit log: Record all access to sensitive data
```

If layer 2 has a bug, layer 3 catches it. If layer 3 is misconfigured, layer 2 catches it.

## Key Rules

- Verify resource ownership on every data access — being authenticated is not sufficient.
- Return 404 (not 403) when denying access to an object — don't confirm the resource exists to unauthorized users.
- Don't trust request parameters (`userId`, `orgId`) sent by the client — derive them from the authenticated session.
- RLS in Postgres is the most reliable authorization layer — implement it even if you also check in application code.
- Log all authorization failures — repeated failures indicate probing or a bug.

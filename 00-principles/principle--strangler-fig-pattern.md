# Principle: Strangler Fig Pattern

## What It Is

Incrementally migrate a legacy system by routing new traffic to new implementations while keeping the old system running for untouched areas. Named after the strangler fig tree that grows around a host tree and gradually replaces it. The old system continues running while the new system expands.

## When to Use

- Rewriting a monolith to microservices
- Migrating from one framework to another (Pages Router → App Router)
- Replacing a vendor integration (Chargebee → Stripe)
- Modernizing a legacy API without breaking clients

## Core Pattern

Route traffic through a facade that dispatches to old or new implementation:

```ts
// Facade — all code goes through here
async function getUser(userId: string): Promise<User> {
  if (await isFeatureEnabled('new_user_service')) {
    // New implementation
    return newUserService.getUser(userId)
  }
  // Old implementation
  return legacyDb.query('SELECT * FROM users WHERE id = ?', [userId])
}
```

Start with 0% on the new implementation, ramp up as you gain confidence.

## Next.js Pages Router → App Router Migration

The frameworks can coexist — migrate one route at a time:

```
/pages/dashboard.tsx  → still works
/app/dashboard/page.tsx  → new App Router version

Next.js routes App Router routes first, falls back to Pages Router.
```

Migration order:
1. Static pages (no data, low risk)
2. Simple data-fetching pages
3. Complex pages with auth, layouts
4. API routes (last, most risk)

## Database Migration with Strangler Fig

Running two schemas simultaneously during migration:

```ts
async function saveCustomer(data: CustomerData) {
  // Write to both systems during migration
  await Promise.all([
    legacyDb.update('customers', data),
    newDb.upsert('customers', transformToNewSchema(data)),
  ])
}

async function getCustomer(id: string) {
  // Read from new system if data exists there
  const customer = await newDb.find('customers', id)
  if (customer) return transformFromNewSchema(customer)

  // Fall back to legacy
  const legacyCustomer = await legacyDb.find('customers', id)
  return transformFromLegacy(legacyCustomer)
}
```

## API Migration

Maintain backward compatibility while introducing new API:

```ts
// Old endpoint — keep working
app.get('/api/v1/users/:id', async (req, res) => {
  const user = await newUserService.getUser(req.params.id)
  res.json(transformToV1Format(user))  // Transform new format → old format
})

// New endpoint — new clients use this
app.get('/api/v2/users/:id', async (req, res) => {
  const user = await newUserService.getUser(req.params.id)
  res.json(user)
})
```

Both endpoints use the new underlying service. Old clients get old format, new clients get new format.

## Rollback Safety

The strangler fig pattern is safe to roll back at any point:

```
Week 1:  Old system handles 100%, new system handles 0%
Week 2:  Old handles 90%, new handles 10% (canary)
Week 3:  Old handles 0%, new handles 100%
Week 4:  Remove old system
```

At any point in weeks 1-3, you can flip back to 100% old. Week 4 is the only irreversible step.

## Key Rules

- Never do a "big bang" rewrite — migrate one piece at a time using strangler fig.
- The facade is temporary — remove it when migration is complete.
- Dual-write during migration (write to both old and new) ensures the new system has all data before you cut over reads.
- Keep the old system running until you're confident — premature deletion is the main risk.
- Log all requests to both systems during migration to compare behavior and catch discrepancies.

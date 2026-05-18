# Tenant Data Isolation

## Why Isolation Matters More Than Features

A multi-tenant data leak — where one customer can see another's records — is an existential event for a SaaS product. It causes immediate churn, legal exposure, and destroys trust permanently. Isolation is not a feature to add later; it is the foundation everything else is built on. Get it wrong once and no feature backlog matters.

## Two Fundamental Strategies

### Schema-per-Tenant

Each tenant gets a dedicated PostgreSQL schema: `tenant_abc.invoices`, `tenant_xyz.invoices`. The application switches the `search_path` on connect.

**Advantages**: complete isolation, no cross-tenant query risk, easy per-tenant backups, can run different schema versions per tenant during migrations.

**Disadvantages**: schema proliferation at scale (1000 tenants = 1000 schemas and connection pools), migrations must run per-schema, cross-tenant analytics are difficult, connection poolers (PgBouncer) are harder to configure.

Use schema-per-tenant when: regulatory compliance requires physical separation, tenants require contractual data isolation, or tenant count is small (< 200).

### Row-Level Isolation (Shared Schema)

All tenants share the same tables. A `tenant_id` column is on every table. Row-Level Security (RLS) enforces that queries only see rows where `tenant_id` matches the authenticated tenant.

**Advantages**: simpler operations, single migration run, cross-tenant analytics are possible (with a service role), connection pooling is straightforward.

**Disadvantages**: a missing `WHERE tenant_id = ?` is a bug rather than an error (RLS is the safety net), more complex permission policies, a DB misconfiguration exposes all tenants at once.

This is the correct approach for most SaaS products.

## Supabase RLS for Row Isolation

Every table that contains tenant data gets a `tenant_id` column and RLS policies. Never rely on application-level filtering alone — RLS is the last line of defense when code has bugs.

```sql
-- Enable RLS on every tenant-scoped table
alter table invoices enable row level security;
alter table invoices force row level security;  -- applies to table owner too

-- The JWT must contain tenant_id (set in the claims via a custom auth hook)
create policy "tenant isolation on invoices"
on invoices
using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);
```

`force row level security` makes RLS apply even to the table owner — without this, a misconfigured admin query bypasses all policies.

The JWT `tenant_id` claim must be set server-side during the auth flow, not by the client.

## Setting Tenant Context in JWT

In Supabase, add `tenant_id` to the JWT via a custom access token hook:

```sql
create or replace function public.add_tenant_to_jwt(event jsonb)
returns jsonb language plpgsql as $$
declare
  tenant_id uuid;
begin
  select t.id into tenant_id
  from tenant_memberships tm
  join tenants t on t.id = tm.tenant_id
  where tm.user_id = (event->>'user_id')::uuid
  limit 1;

  return jsonb_set(event, '{claims,tenant_id}', to_jsonb(tenant_id));
end;
$$;
```

For applications managing their own JWT (not Supabase Auth): include `tenant_id` in the payload during token creation and read it from the token in middleware — never from a request parameter the client can control.

## Connection Pooling with Tenant Context

When using PgBouncer or Supabase connection poolers in transaction mode, `SET LOCAL` commands don't persist across connections. This means setting `search_path` or config parameters per-tenant only works in session mode.

For transaction-mode poolers with shared schema: pass `tenant_id` via JWT claims and let RLS handle filtering — don't try to set session variables.

For schema-per-tenant with transaction-mode poolers: use a separate connection string per tenant (one entry in PgBouncer config per tenant). At large scale, this is operationally painful — consider schema-per-tenant only if you're willing to manage this.

## Cross-Tenant Query Prevention

Application-level bugs cause the most cross-tenant leaks. Defenses:

1. **Never accept `tenant_id` from request body/query params** — always derive from the authenticated token.
2. **Middleware sets `req.tenantId`** from the JWT; all DB queries read from `req.tenantId`.
3. **Service functions take explicit `tenantId` parameter** — not pulled from a global. This makes cross-tenant calls visible in code review.
4. **Integration tests must verify** that a request authenticated as tenant A cannot access tenant B's data — not just that tenant A can access their own.

```ts
// Good: tenantId is threaded explicitly
async function getInvoice(invoiceId: string, tenantId: string) {
  return db.select().from(invoices)
    .where(and(eq(invoices.id, invoiceId), eq(invoices.tenantId, tenantId)));
}

// Dangerous: relies on caller to remember to filter
async function getInvoice(invoiceId: string) {
  return db.select().from(invoices).where(eq(invoices.id, invoiceId));
}
```

## Service Role Usage

Service-role queries (Supabase `SUPABASE_SERVICE_ROLE_KEY`) bypass RLS entirely. This is necessary for admin operations, analytics, and background jobs. Rules:

- **Never expose the service role key client-side**.
- Service role queries must **explicitly include `WHERE tenant_id = ?`** — RLS is bypassed, so the application must enforce isolation manually.
- Log service role DB access separately for audit purposes.

## Key Rules

- **RLS is mandatory** on every tenant-scoped table — `ALTER TABLE ... FORCE ROW LEVEL SECURITY`.
- **Never accept `tenant_id` from client input** — always derive from the authenticated JWT.
- Prefer **row-level isolation** for most SaaS; schema-per-tenant only for regulatory/contractual requirements.
- Service role queries **bypass RLS** — always add explicit `WHERE tenant_id = ?` filters.
- Write **integration tests that verify cross-tenant access is blocked**, not just that same-tenant access works.
- Thread `tenantId` as an **explicit parameter** to service functions — don't read from ambient state.
- In Supabase: use a **custom access token hook** to embed `tenant_id` in the JWT server-side.

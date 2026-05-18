# Skill: Tenant Data Isolation

## Overview
In a multi-tenant system, every query that can accidentally return another tenant's data is a catastrophic data breach. Row-level security (RLS) enforced by the database is the safest isolation layer because it cannot be bypassed by application logic bugs — the database itself rejects unauthorized queries. Application-layer filtering alone is a single point of failure.

## Implementation / Key Points

### Schema: `tenant_id` on Every Table
```sql
CREATE TABLE projects (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- tenant_id must be part of every index that's used in WHERE clauses
CREATE INDEX idx_projects_tenant_id ON projects(tenant_id);
CREATE INDEX idx_projects_tenant_created ON projects(tenant_id, created_at DESC);
```

### RLS Policy (Supabase / PostgreSQL)
```sql
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- Users can only see their own tenant's rows
CREATE POLICY "tenant_isolation" ON projects
  USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);

-- Same for write operations
CREATE POLICY "tenant_isolation_insert" ON projects
  WITH CHECK (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);
```
The `tenant_id` is embedded in the JWT at login time. The RLS policy reads it from the token — no application code involvement.

### Embedding `tenant_id` in JWT
```ts
// Supabase: set custom claim on login
const { data } = await supabase.auth.signInWithPassword({ email, password });

// Use a Database Function + Trigger to auto-populate:
// CREATE OR REPLACE FUNCTION set_tenant_claim()
// RETURNS void LANGUAGE plpgsql AS $$
// BEGIN
//   PERFORM set_config('request.jwt.claims',
//     json_build_object('tenant_id', (SELECT tenant_id FROM profiles WHERE user_id = auth.uid()))::text,
//     true
//   );
// END;
// $$;
```

### Service Role Bypass (Audit Logged)
```ts
// Service role bypasses RLS — log every such operation
const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function adminQuery(operation: string, tenantId: string, query: () => Promise<any>) {
  const result = await query();
  await auditLog({ operation, tenantId, actorType: 'service', timestamp: new Date() });
  return result;
}
```
Service role access must be restricted to specific server-side functions, never client-side.

### Super-Admin Cross-Tenant Queries
```ts
// Only via explicit super-admin context — never accidentally
async function superAdminQuery<T>(
  tenantId: string,
  operation: (adminClient: SupabaseClient) => Promise<T>
): Promise<T> {
  if (!currentUser.isSuperAdmin) throw new Error('Unauthorized cross-tenant access');
  await auditLog({ tenantId, actor: currentUser.id, operation: operation.name });
  return operation(adminClient);
}
```

### Application Layer Defense in Depth
Even with RLS, always filter by `tenant_id` in application queries — belt and suspenders:
```ts
// ALWAYS include tenant_id even though RLS also enforces it
const projects = await supabase
  .from('projects')
  .select('*')
  .eq('tenant_id', currentTenantId);   // explicit filter
```
This makes the tenant scope visible in code reviews and protects against RLS misconfiguration.

### Tenant Context in Background Jobs
```ts
// Background jobs must set tenant context explicitly — no HTTP session available
async function processJobForTenant(tenantId: string) {
  const tenantClient = createTenantClient(tenantId);  // client with tenant JWT
  // All queries via tenantClient are RLS-scoped to tenantId
}
```

## Key Rules
- Every table has a `tenant_id` column — no exceptions, including junction tables.
- RLS must be `ENABLED` on every tenant-scoped table before it goes to production.
- The JWT must carry `tenant_id` so RLS can validate without a DB lookup on each request.
- Service role bypasses RLS — every service role operation must be audit logged.
- Cross-tenant queries require explicit super-admin check + audit log — never accidental.
- Application-layer `tenant_id` filter is required in addition to RLS, not instead of it.
- `tenant_id` must appear in all indexes used in WHERE clauses — isolation without it is slow.

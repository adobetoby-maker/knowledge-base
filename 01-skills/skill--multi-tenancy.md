# Skill: Multi-Tenancy

## Overview

Multi-tenancy serves multiple organizations from one codebase and database. Each tenant's data is isolated — one tenant cannot see or affect another's data. Two common approaches: row-level isolation (single schema, `org_id` on every table) and schema-per-tenant.

## Architecture Decision

**Row-level isolation** (recommended for most SaaS):
- Single database schema, `org_id` column on every table
- RLS policies enforce isolation at the database level
- Simpler operations (single migration runs once)
- Works with connection pooling

**Schema-per-tenant** (for enterprise, regulated industries):
- Each tenant in their own Postgres schema
- Complete isolation, easier audit
- More complex: migrations run N times, no connection pooling

This guide covers row-level isolation.

## Database Schema

```sql
-- Tenants table
CREATE TABLE organizations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,  -- For URL routing: app.com/org/slug
  plan        TEXT DEFAULT 'free',
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- Add org_id to every tenant-specific table
ALTER TABLE invoices ADD COLUMN org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE customers ADD COLUMN org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE users ADD COLUMN org_id UUID REFERENCES organizations(id);  -- null = personal/admin account
```

## Row-Level Security

```sql
-- Enable RLS on every tenant table
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- Policy: users can only see their org's rows
CREATE POLICY invoices_org_isolation ON invoices
  USING (org_id = (SELECT org_id FROM users WHERE id = auth.uid()));

-- If service role needed to bypass (admin operations):
-- Use admin Supabase client which bypasses RLS
```

## Getting Current Org from Auth

```ts
// lib/auth.ts
export async function requireOrgMember(
  orgId?: string,
): Promise<{ user: User; org: Organization }> {
  const supabase = createServerClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) throw new AuthError('Not authenticated')

  // Get user's org membership
  const membership = await db.query.orgMembers.findFirst({
    where: orgId
      ? and(eq(orgMembers.userId, user.id), eq(orgMembers.orgId, orgId))
      : eq(orgMembers.userId, user.id),
    with: { org: true },
  })

  if (!membership) throw new AuthError('Not a member of this organization')

  return { user, org: membership.org }
}
```

## URL Routing Strategies

**Subdomain** (`acme.app.com`):
- Cleanest UX
- Requires wildcard SSL certificate
- More complex middleware

**Path segment** (`app.com/org/acme/...`):
- Simpler implementation
- Works with standard SSL

```ts
// Next.js middleware — extract org from subdomain or path
export function middleware(request: NextRequest) {
  const hostname = request.headers.get('host') ?? ''
  const subdomain = hostname.split('.')[0]

  // Check if it's a tenant subdomain (not 'www', 'app', etc.)
  if (subdomain !== 'www' && subdomain !== 'app') {
    // Rewrite to include org slug in path for downstream use
    const url = request.nextUrl.clone()
    url.pathname = `/org/${subdomain}${url.pathname}`
    return NextResponse.rewrite(url)
  }
}
```

## Org Context Provider

```tsx
// app/org/[slug]/layout.tsx
import { requireOrgMember } from '@/lib/auth'

export default async function OrgLayout({
  children,
  params,
}: {
  children: React.ReactNode
  params: Promise<{ slug: string }>
}) {
  const { slug } = await params
  const org = await db.query.organizations.findFirst({
    where: eq(organizations.slug, slug),
  })
  if (!org) notFound()

  const { user } = await requireOrgMember(org.id)

  return (
    <OrgProvider org={org} user={user}>
      {children}
    </OrgProvider>
  )
}
```

## Always Scope Queries

Every query on a tenant table must include `org_id`:

```ts
// Wrong: returns all invoices from all orgs (RLS will block this, but explicit is better)
const invoices = await db.query.invoices.findMany()

// Right: explicit scope
const invoices = await db.query.invoices.findMany({
  where: eq(invoices.orgId, org.id),
})
```

Even with RLS, be explicit in queries. Defense in depth: if RLS is misconfigured, explicit scoping prevents data leakage.

## Cross-Org Operations (Admin Only)

Admin operations that need to see all orgs should use the service role client:

```ts
// lib/supabase/admin.ts — service role bypasses RLS
// Only import this in server-side admin routes

const adminDb = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
)

// Admin route: list all orgs
export async function GET() {
  await requireAdminSession()  // Must verify admin auth first
  const orgs = await adminDb.from('organizations').select('*')
  return Response.json(orgs.data)
}
```

## Billing per Org

Stripe customer maps to org, not user:

```ts
// Organizations have their own Stripe customer
ALTER TABLE organizations ADD COLUMN stripe_customer_id TEXT UNIQUE;

// When an admin upgrades their org's plan:
const customerId = await getOrCreateStripeCustomer(org.id, org.name, adminUser.email)
```

Multiple users in an org share the same billing. The org pays, not the individual user.

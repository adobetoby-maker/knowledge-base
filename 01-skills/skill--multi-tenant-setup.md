# Skill: Multi-Tenant Setup

## What Multi-Tenancy Means

Multiple organizations share the same database/codebase. Each org's data is isolated from others. Common pattern for SaaS: each customer is a "tenant" (org).

## Tenant Model: Shared DB + Row-Level Isolation

Used in this stack. All tenants in the same Postgres database, each row tagged with `org_id`. RLS enforces isolation.

```sql
-- Organizations table
CREATE TABLE organizations (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT NOT NULL,
  slug       TEXT NOT NULL UNIQUE,  -- URL slug: 'jrs-auto-repair'
  created_at TIMESTAMPTZ DEFAULT now()
);

-- User to org membership
CREATE TABLE org_members (
  id       UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  org_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role     TEXT NOT NULL DEFAULT 'member',
  UNIQUE(org_id, user_id)
);

-- All business tables get org_id
CREATE TABLE invoices (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  org_id     UUID NOT NULL REFERENCES organizations(id),
  ...
);
```

## RLS for Tenant Isolation

```sql
-- Helper: get current user's orgs
CREATE OR REPLACE FUNCTION user_org_ids()
RETURNS UUID[] AS $$
  SELECT ARRAY(
    SELECT org_id FROM org_members WHERE user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- All invoice access restricted to user's orgs
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can only see their org invoices"
ON invoices FOR ALL
USING (org_id = ANY(user_org_ids()));
```

With this RLS in place, a user can never access another org's data — even if they guess the invoice ID.

## Identifying Current Tenant

```ts
// Strategy 1: From URL subdomain (saas.myapp.com)
// middleware.ts
const host = request.headers.get('host') ?? ''
const subdomain = host.split('.')[0]  // 'saas' from 'saas.myapp.com'

// Strategy 2: From URL path segment (/org/acme-corp/invoices)
// Already in route: params.orgSlug

// Strategy 3: From user's org (single-org users)
const { data: membership } = await supabase
  .from('org_members')
  .select('org_id')
  .eq('user_id', user.id)
  .single()
const orgId = membership?.org_id
```

## Context Provider for Current Org

```tsx
// app/providers/org-context.tsx
'use client'
import { createContext, useContext } from 'react'

interface OrgContext {
  orgId: string
  orgName: string
  orgSlug: string
  userRole: string
}

const OrgCtx = createContext<OrgContext | null>(null)

export function useOrg(): OrgContext {
  const ctx = useContext(OrgCtx)
  if (!ctx) throw new Error('useOrg must be used within OrgProvider')
  return ctx
}

export function OrgProvider({
  org,
  userRole,
  children,
}: {
  org: { id: string; name: string; slug: string }
  userRole: string
  children: React.ReactNode
}) {
  return (
    <OrgCtx.Provider value={{ orgId: org.id, orgName: org.name, orgSlug: org.slug, userRole }}>
      {children}
    </OrgCtx.Provider>
  )
}
```

## Route Structure

```
/dashboard                    → redirect to user's org
/org/[orgSlug]/               → org dashboard
/org/[orgSlug]/invoices       → invoices
/org/[orgSlug]/clients        → clients
/org/[orgSlug]/settings       → org settings
```

```ts
// app/org/[orgSlug]/layout.tsx
export default async function OrgLayout({
  children,
  params,
}: {
  children: React.ReactNode
  params: Promise<{ orgSlug: string }>
}) {
  const { orgSlug } = await params
  const supabase = createServerComponentClient({ cookies })
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: org } = await supabase
    .from('organizations')
    .select('id, name, slug')
    .eq('slug', orgSlug)
    .single()

  if (!org) redirect('/dashboard')

  // Verify user is a member
  const { data: member } = await supabase
    .from('org_members')
    .select('role')
    .eq('org_id', org.id)
    .eq('user_id', user.id)
    .single()

  if (!member) redirect('/dashboard?error=unauthorized')

  return (
    <OrgProvider org={org} userRole={member.role}>
      {children}
    </OrgProvider>
  )
}
```

## Creating a New Org (Signup Flow)

```ts
// After user signs up, create their org
async function createOrgForNewUser(userId: string, orgName: string) {
  const slug = orgName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')

  const { data: org } = await supabaseAdmin.from('organizations').insert({
    name: orgName,
    slug: `${slug}-${Date.now()}`,  // Ensure uniqueness
  }).select().single()

  // Make the user an owner
  await supabaseAdmin.from('org_members').insert({
    org_id: org.id,
    user_id: userId,
    role: 'owner',
  })

  return org
}
```

## Single vs Multi Org Users

For simple use cases (jrs-auto-repair: one user, one business), the `org_id` complexity isn't needed — just use `user_id` directly. Use multi-tenant setup only when:
- Multiple users share data (team accounts)
- Users might belong to multiple orgs
- You need org-level billing (subscription per org, not per user)

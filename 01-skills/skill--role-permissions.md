# Skill: Role-Based Permissions

## Model: Flat Roles + Supabase RLS

Three-tier model used across the project stack:
1. **Admin** — cookie-based, separate from Supabase Auth, controls `/admin/*`
2. **Authenticated user** — Supabase JWT, controls `/portal/*`
3. **Public** — no auth, controls `/` (marketing, public invoice pages)

Never mix admin and portal auth. See `auth--two-system-pattern.md`.

## Application-Level Roles (Beyond Admin/Portal)

For multi-tenant apps where users have different permissions within the same authenticated tier:

```sql
-- User roles table
CREATE TYPE app_role AS ENUM ('owner', 'manager', 'member', 'viewer');

CREATE TABLE user_roles (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  org_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  role       app_role NOT NULL DEFAULT 'member',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, org_id)
);
```

## RLS with Roles

```sql
-- Helper function to get caller's role
CREATE OR REPLACE FUNCTION current_user_role(org_id UUID)
RETURNS app_role AS $$
  SELECT role FROM user_roles
  WHERE user_id = auth.uid()
  AND user_roles.org_id = current_user_role.org_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- Policy: owners and managers can edit
CREATE POLICY "managers can update invoices"
ON invoices FOR UPDATE
USING (
  current_user_role(org_id) IN ('owner', 'manager')
);

-- Policy: all members can read
CREATE POLICY "members can read invoices"
ON invoices FOR SELECT
USING (
  current_user_role(org_id) IS NOT NULL  -- Any role = member or above
);
```

## TypeScript Role Checking

```ts
// lib/roles.ts
export type AppRole = 'owner' | 'manager' | 'member' | 'viewer'

const ROLE_HIERARCHY: Record<AppRole, number> = {
  owner: 4,
  manager: 3,
  member: 2,
  viewer: 1,
}

export function hasPermission(userRole: AppRole, required: AppRole): boolean {
  return ROLE_HIERARCHY[userRole] >= ROLE_HIERARCHY[required]
}

// Usage
hasPermission('manager', 'member')  // true
hasPermission('viewer', 'manager')  // false
```

## Fetching Current User's Role

```ts
// In Server Component or Route Handler
async function getUserRole(userId: string, orgId: string): Promise<AppRole | null> {
  const { data } = await supabase
    .from('user_roles')
    .select('role')
    .eq('user_id', userId)
    .eq('org_id', orgId)
    .single()

  return (data?.role as AppRole) ?? null
}
```

Cache the role in session/cookie if read frequently — one DB round-trip per request is expensive.

## Route Protection by Role

```ts
// In a Server Component (App Router)
export default async function AdminPage() {
  const supabase = createServerComponentClient({ cookies })
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const role = await getUserRole(user.id, currentOrgId)
  if (!hasPermission(role ?? 'viewer', 'manager')) {
    redirect('/dashboard?error=forbidden')
  }

  return <AdminContent />
}
```

Always validate on the server. Client-side role checks are cosmetic only.

## UI: Conditional Rendering

```tsx
interface PermissionGateProps {
  role: AppRole
  required: AppRole
  children: React.ReactNode
  fallback?: React.ReactNode
}

function PermissionGate({ role, required, children, fallback = null }: PermissionGateProps) {
  if (!hasPermission(role, required)) return <>{fallback}</>
  return <>{children}</>
}

// Usage
<PermissionGate role={currentUser.role} required="manager">
  <DeleteButton />
</PermissionGate>
```

## Permission Matrix Pattern

For complex permission systems, define as a matrix instead of scattered checks:

```ts
const PERMISSIONS = {
  invoice: {
    create:  ['owner', 'manager'],
    read:    ['owner', 'manager', 'member', 'viewer'],
    update:  ['owner', 'manager'],
    delete:  ['owner'],
    send:    ['owner', 'manager'],
  },
  client: {
    create:  ['owner', 'manager'],
    read:    ['owner', 'manager', 'member'],
    update:  ['owner', 'manager'],
    delete:  ['owner'],
  },
} satisfies Record<string, Record<string, AppRole[]>>

type Resource = keyof typeof PERMISSIONS
type Action<R extends Resource> = keyof (typeof PERMISSIONS)[R]

function can<R extends Resource>(
  role: AppRole,
  resource: R,
  action: Action<R>
): boolean {
  return (PERMISSIONS[resource][action] as AppRole[]).includes(role)
}

can('manager', 'invoice', 'delete')  // false — only owner
can('manager', 'invoice', 'send')    // true
```

Matrix approach puts all permission logic in one place — easy to audit and update.

## Inviting Users

```ts
// Generate invite with role pre-set
const invite = await supabase.auth.admin.inviteUserByEmail(email, {
  data: {
    org_id: orgId,
    invited_role: 'member',
  },
  redirectTo: `${SITE_URL}/auth/accept-invite`,
})

// On accept (after signup), create the user_roles record
await supabase.from('user_roles').insert({
  user_id: newUser.id,
  org_id: newUser.user_metadata.org_id,
  role: newUser.user_metadata.invited_role,
})
```

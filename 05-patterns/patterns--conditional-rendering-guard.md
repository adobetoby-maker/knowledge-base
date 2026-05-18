# Pattern: Auth / Permission Rendering Guard

## Overview
Using `&&` for conditional rendering of protected UI causes a brief flash of null before the redirect occurs — users see a blank slot where the UI was. More critically, a missing server-side guard means someone with a manipulated URL can access the page even if the component hides the UI. Guards must exist at both the server (prevents access) and component (prevents rendering) layers.

## Implementation

```tsx
// Server Component guard — redirect in layout, before any content renders
// app/(admin)/layout.tsx
import { redirect } from 'next/navigation'
import { getSession } from '@/lib/auth'

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const session = await getSession()

  // Guard at the layout level: every admin route is protected
  // redirect() throws internally — no return value needed
  if (!session) {
    redirect('/login?next=/admin')
  }

  if (session.role !== 'admin') {
    // Has session but wrong role — show 403, not redirect to login
    redirect('/403')
  }

  return <div className="admin-layout">{children}</div>
}
```

```tsx
// RequireRole.tsx — component-level guard
// Used for UI elements that should conditionally show within an already-accessible page

interface RequireRoleProps {
  role: 'admin' | 'editor' | 'viewer'
  children: React.ReactNode
  // What to show if permission check fails:
  // - undefined/null: render nothing (hide the element)
  // - React.ReactNode: show fallback UI
  // - 'redirect': shouldn't be used here — use server guard instead
  fallback?: React.ReactNode
}

export function RequireRole({ role, children, fallback = null }: RequireRoleProps) {
  const { user } = useAuth()

  // Loading: don't show children OR fallback until we know
  if (!user) return null

  // Check role hierarchy: admin can do editor and viewer things
  if (!hasRole(user, role)) {
    return <>{fallback}</>
  }

  return <>{children}</>
}

// Role hierarchy check
function hasRole(user: User, required: string): boolean {
  const hierarchy = { admin: 3, editor: 2, viewer: 1 }
  return (hierarchy[user.role as keyof typeof hierarchy] ?? 0) >=
         (hierarchy[required as keyof typeof hierarchy] ?? 99)
}
```

```tsx
// Usage — component-level guards for UI elements

// ❌ Wrong: && causes null flash and doesn't communicate the guard clearly
function ActionMenu() {
  return (
    <div>
      <Button>Edit</Button>
      {user?.role === 'admin' && <Button>Delete</Button>}  {/* null flash */}
    </div>
  )
}

// ✓ Correct: explicit guard component
function ActionMenu() {
  return (
    <div>
      <Button>Edit</Button>
      <RequireRole role="admin">
        <Button>Delete</Button>
      </RequireRole>
    </div>
  )
}

// ✓ With fallback: show different UI for non-admins
function PricingCard() {
  return (
    <RequireRole
      role="admin"
      fallback={<p>Contact your admin to change plans.</p>}
    >
      <ChangePlanButton />
    </RequireRole>
  )
}
```

```typescript
// Server-side guard for API routes (Route Handlers)
// app/api/admin/users/route.ts
export async function GET(req: Request) {
  const session = await getSession(req)

  if (!session) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 })
  }

  if (session.role !== 'admin') {
    return Response.json({ error: 'Forbidden' }, { status: 403 })
  }

  const users = await db.user.findMany()
  return Response.json(users)
}
```

```typescript
// Permission-based (not just role-based) guard
// More granular than roles — checks specific capabilities

interface Permission {
  action: 'create' | 'read' | 'update' | 'delete'
  resource: 'project' | 'invoice' | 'user'
}

export function RequirePermission({
  action,
  resource,
  children,
  fallback = null,
}: Permission & { children: React.ReactNode; fallback?: React.ReactNode }) {
  const { user } = useAuth()

  if (!user) return null

  const allowed = checkPermission(user, action, resource)
  return allowed ? <>{children}</> : <>{fallback}</>
}

// Usage
<RequirePermission action="delete" resource="invoice">
  <DeleteInvoiceButton />
</RequirePermission>
```

## Key Rules
- Server guards (layout redirects, Route Handler auth checks) are security — they must always exist.
- Component guards (`RequireRole`) are UX — they prevent UI confusion but do not constitute security on their own.
- Never rely solely on component-level guards to protect data — the API route must also check permissions.
- Don't use `&&` for protected UI — use `<RequireRole>` to make the intent explicit and avoid null-flash.
- In layouts: use `redirect()` for unauthorized users. Return a 403 page for authenticated-but-unauthorized users (different states, different responses).
- Show fallback UI when the user is authenticated but lacks permission — a blank space is confusing; an explanation is helpful.
- While auth state is loading, render null (not the protected content, not the fallback) — revealing protected UI before auth loads is a flash bug.
- Distinguish 401 (not authenticated) from 403 (authenticated but forbidden) in API responses — they require different client handling.
- Permission checks should be centralized (`checkPermission(user, action, resource)`) not scattered as inline conditions.

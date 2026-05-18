# Pattern: Permission Gate

## Overview

Permission gates conditionally render UI based on user roles or capabilities. The pattern has two levels: UI-level gating (hide/show elements) and route-level protection (redirect unauthorized users). Both are needed — UI gates alone are insufficient because they can be bypassed by direct navigation.

## Role-Based Gate Component

```tsx
type Role = 'admin' | 'editor' | 'viewer'

interface PermissionGateProps {
  requiredRole: Role
  children: React.ReactNode
  fallback?: React.ReactNode
}

const ROLE_HIERARCHY: Record<Role, number> = {
  viewer: 1,
  editor: 2,
  admin: 3,
}

export function PermissionGate({ requiredRole, children, fallback = null }: PermissionGateProps) {
  const { user } = useAuth()

  if (!user) return <>{fallback}</>

  const userLevel = ROLE_HIERARCHY[user.role] ?? 0
  const requiredLevel = ROLE_HIERARCHY[requiredRole]

  if (userLevel < requiredLevel) return <>{fallback}</>

  return <>{children}</>
}
```

Usage:

```tsx
<PermissionGate requiredRole="admin">
  <DeleteWorkspaceButton />
</PermissionGate>

<PermissionGate requiredRole="editor" fallback={<ViewOnlyBadge />}>
  <EditButton />
</PermissionGate>
```

## Capability-Based Check

Role hierarchy doesn't cover every case. Use capability-based checks for fine-grained control:

```tsx
type Capability = 
  | 'projects:create'
  | 'projects:delete'
  | 'members:invite'
  | 'billing:manage'

interface User {
  id: string
  role: Role
  capabilities: Capability[]  // explicit overrides
}

function hasCapability(user: User, cap: Capability): boolean {
  // Admin has all capabilities
  if (user.role === 'admin') return true
  // Explicit grant/deny
  return user.capabilities.includes(cap)
}

function Can({ do: cap, children, fallback = null }: {
  do: Capability
  children: React.ReactNode
  fallback?: React.ReactNode
}) {
  const { user } = useAuth()
  if (!user || !hasCapability(user, cap)) return <>{fallback}</>
  return <>{children}</>
}
```

## Route Protection (Next.js App Router)

```tsx
// app/(app)/admin/layout.tsx
import { redirect } from 'next/navigation'
import { getServerUser } from '@/lib/auth'

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const user = await getServerUser()

  if (!user || user.role !== 'admin') {
    redirect('/dashboard')
  }

  return <>{children}</>
}
```

## Server Action Guard

```tsx
// lib/withPermission.ts
export function withPermission(requiredRole: Role, action: Function) {
  return async (...args: any[]) => {
    'use server'
    const user = await getServerUser()
    if (!user || ROLE_HIERARCHY[user.role] < ROLE_HIERARCHY[requiredRole]) {
      throw new Error('Unauthorized')
    }
    return action(...args)
  }
}

// usage
const deleteProject = withPermission('admin', async (projectId: string) => {
  await db.delete(projects).where(eq(projects.id, projectId))
})
```

## Database-Level Check

Always scope database queries to the user's authorized data:

```tsx
// Even if UI gate passed, always verify in the DB query
async function getProject(projectId: string, userId: string) {
  return db.select()
    .from(projects)
    .where(
      and(
        eq(projects.id, projectId),
        or(
          eq(projects.ownerId, userId),
          // OR user is a member
          exists(
            db.select().from(projectMembers)
              .where(and(
                eq(projectMembers.projectId, projectId),
                eq(projectMembers.userId, userId)
              ))
          )
        )
      )
    )
    .get()
}
```

## Key Rules

- UI gates are UX, not security. Server-side checks in route handlers, server actions, and DB queries are the actual security layer.
- Role hierarchy (viewer < editor < admin) handles most cases. Capabilities handle exceptions.
- `fallback` prop lets the gate show alternative UI rather than blank space — prevents layout shift.
- Server Actions need their own permission check — they're just POST endpoints; a malicious user can call them directly.
- Never pass the user object from client to server to authorize actions — always re-fetch the session server-side.

# Principle: Access Control Layers

## Overview
Access control must be implemented at multiple independent layers. A single layer fails in ways that are hard to detect — a bug in the authorization check, a stolen token, a misconfigured RLS policy. Defense in depth means each layer provides protection even if other layers fail. The three layers — authentication, authorization, and data filtering — answer different questions and must each be implemented explicitly.

## Implementation

### The Three Layers
```
Layer 1: Authentication — WHO are you?
  ↓ (fails: 401 Unauthorized — not logged in)
Layer 2: Authorization — WHAT can you do?
  ↓ (fails: 403 Forbidden — logged in but not allowed)
Layer 3: Data Filtering — WHAT DATA can you see?
  ↓ (enforced by RLS or query conditions)
```

### Layer 1: Authentication
```ts
// Middleware — runs on every request
export async function authenticateRequest(req: Request): Promise<Session> {
  const token = extractToken(req);

  if (!token) {
    throw new AuthenticationError('Authentication required');
  }

  const session = await verifyToken(token);
  if (!session) {
    throw new AuthenticationError('Invalid or expired token');
  }

  return session;
}
```

### Layer 2: Authorization (RBAC)
```ts
// Separate from authentication — checks what the authenticated user CAN DO
type Permission =
  | 'invoice:read'
  | 'invoice:write'
  | 'invoice:delete'
  | 'user:admin'
  | 'billing:manage';

const ROLE_PERMISSIONS: Record<string, Permission[]> = {
  owner:  ['invoice:read', 'invoice:write', 'invoice:delete', 'user:admin', 'billing:manage'],
  admin:  ['invoice:read', 'invoice:write', 'invoice:delete', 'user:admin'],
  editor: ['invoice:read', 'invoice:write'],
  viewer: ['invoice:read'],
};

export function authorize(session: Session, permission: Permission): void {
  const permissions = ROLE_PERMISSIONS[session.role] ?? [];
  if (!permissions.includes(permission)) {
    throw new ForbiddenError(`Insufficient permissions: ${permission} required`);
  }
}

// Usage in route handler:
const session = await authenticateRequest(req);       // Layer 1
authorize(session, 'invoice:delete');                 // Layer 2
const invoice = await getInvoice(id, session.userId); // Layer 3 (filtered by userId)
```

### Layer 3: Data Filtering
Data filtering ensures that even if layers 1 and 2 pass, a user can only see THEIR data:

```ts
// WRONG: Authorization-only (no data filtering)
// If someone exploits an auth bug, they can see ALL invoices
async function getInvoice(id: string): Promise<Invoice> {
  return db.invoices.findById(id); // returns any invoice
}

// RIGHT: Always filter by authenticated user
async function getInvoice(id: string, userId: string): Promise<Invoice> {
  const invoice = await db.invoices.findOne({
    where: { id, userId } // Layer 3: scope to user's data
  });
  if (!invoice) throw new NotFoundError('Invoice not found');
  return invoice;
}
```

### Row-Level Security (Postgres RLS)
RLS enforces data filtering at the database level — it applies even to direct SQL queries:

```sql
-- Enable RLS
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- Policy: users can only see their own invoices
CREATE POLICY invoices_user_isolation ON invoices
  USING (user_id = current_setting('app.current_user_id')::uuid);

-- Policy: admins can see all (separate policy)
CREATE POLICY invoices_admin_access ON invoices
  USING (
    current_setting('app.current_user_role', true) = 'admin'
  );
```

```ts
// Set RLS context before every query
async function withUserContext(userId: string, fn: () => Promise<void>) {
  await db.query(`SELECT set_config('app.current_user_id', $1, true)`, [userId]);
  await fn();
}
```

### Why Each Layer is Necessary
```
Attack scenario: Stolen auth token
Layer 1 (Auth):     Passes — token is valid
Layer 2 (Authz):    Passes — user role allows reading invoices
Layer 3 (Filter):   BLOCKS — attacker's userId only returns their own invoices
Result: Attacker can see their own invoices but not others' — damage contained

Attack scenario: Authorization bug (role check skipped)
Layer 1 (Auth):     Passes — token is valid
Layer 2 (Authz):    Skipped/buggy — no check performed
Layer 3 (Filter):   BLOCKS — query still filtered to user's data
Result: User can reach the endpoint but only see their own data — still safe
```

### Multi-Tenant Authorization
```ts
// For multi-tenant apps: verify both user auth AND organization membership
export async function authorizeOrgMember(
  session: Session,
  orgId: string,
  requiredRole: 'admin' | 'member' | 'viewer' = 'viewer'
): Promise<void> {
  const membership = await db.orgMemberships.findOne({
    where: { userId: session.userId, orgId }
  });

  if (!membership) {
    throw new ForbiddenError('Not a member of this organization');
  }

  const roleHierarchy = ['viewer', 'member', 'admin'];
  if (roleHierarchy.indexOf(membership.role) < roleHierarchy.indexOf(requiredRole)) {
    throw new ForbiddenError(`Requires ${requiredRole} role in organization`);
  }
}
```

## Key Rules
- Never skip a layer for performance — a missing authorization check is a security vulnerability, not a performance optimization.
- Authentication and authorization are different — being logged in does not mean having permission.
- Data filtering must happen even when authorization passes — authorization says "you can read invoices"; data filtering says "you can read YOUR invoices."
- RLS provides the deepest protection by enforcing data filtering at the DB level, independent of application code.
- `NOT FOUND` is the correct error when a user requests a resource they don't have access to — returning `FORBIDDEN` leaks that the resource exists.
- Never return "you don't have access" vs "this doesn't exist" — the distinction enables enumeration attacks.
- Audit every access control decision when the resource is sensitive — log who accessed what, when, from where.

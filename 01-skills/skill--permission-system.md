# Skill: RBAC Permission System

## Purpose
Role-Based Access Control that is fast to check, easy to audit, and hard to misconfigure. The common failure mode is ad-hoc `if user.role === 'admin'` checks scattered through the codebase — these drift, get bypassed, and are invisible to audits.

## Database Schema

```sql
roles (id, name, description, parent_role_id)   -- hierarchy via parent
permissions (id, resource, action)               -- e.g. "invoices", "delete"
role_permissions (role_id, permission_id)
user_roles (user_id, role_id, scope_id nullable) -- scope_id for multi-tenant scoping
```

Role hierarchy means child roles inherit parent permissions. Compute the full set at role assignment time and cache it — don't walk the tree on every request.

## Permission Matrix
Store permissions as `resource:action` pairs (`invoices:read`, `invoices:delete`, `users:manage`). Wildcards are a footgun — avoid `invoices:*`. Explicit beats implicit. The matrix is the source of truth; the UI reads it to decide what to show.

## Caching Strategy
Permission lookups happen on every authenticated request. Hit the DB every time and you add 5–20ms minimum per request.

Cache the full permission set per user in Redis:
- Key: `perms:user:{userId}`
- Value: JSON array of `resource:action` strings
- TTL: 5 minutes

**Invalidation is the hard part.** When a role changes (new permission added, user's role reassigned), immediately delete every `perms:user:*` key for affected users. Use a role→user index in Redis (`role:members:{roleId}`) so you can fan out invalidation without a DB query. On TTL expiry the cache rebuilds from DB automatically — the TTL is a safety net, not the primary mechanism.

## Server-Side Middleware Guard
Every protected API route goes through a single guard function:
```ts
requirePermission('invoices', 'delete')
```
The guard: (1) extracts userId from the session, (2) checks the Redis cache, (3) on miss, loads from DB and populates cache, (4) throws 403 if permission absent, (5) writes an audit log entry regardless of pass/fail.

Never put permission logic in business logic functions — keep it in the middleware layer so it's impossible to accidentally skip.

## React Component Gate
For UI, use a `<Can>` component that reads permissions from a context populated at login:
```tsx
<Can do="invoices:delete">
  <DeleteButton />
</Can>
```
This is **UI hiding only** — it is not a security boundary. The API guard is the real check. Never trust client-side permission state alone.

## Audit Log
Every permission check (pass and fail) writes an audit record:
```sql
permission_audit (user_id, resource, action, granted, ip, user_agent, created_at)
```
Index on `(user_id, created_at)` for user activity reports, `(resource, action, granted=false)` for security alerts. Retain for 90 days minimum.

## Common Pitfalls
- **Checking the wrong user's permissions** — always derive `userId` from the verified session, never from the request body or query params
- **Caching without invalidation** — stale permissions are a security hole, not just a bug
- **Over-permissioned defaults** — new roles should have zero permissions; add what's needed
- **Super-admin backdoors** — even super-admins should go through the same middleware so their actions are audited

## Key Rules
- **All permission checks go through one function** — never inline `user.role === 'x'`
- **Cache with explicit invalidation on change** — TTL is a fallback, not the strategy
- **Log every check, pass and fail** — you need the audit trail for compliance and debugging
- **UI gates are decoration** — the API guard is the real security boundary
- **New roles start with zero permissions** — allowlist, not denylist
- **Scope permissions to tenant when multi-tenant** — `user_roles.scope_id` prevents cross-tenant escalation

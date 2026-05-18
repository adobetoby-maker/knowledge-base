# Role-Based Access Control (RBAC)

## Why Roles Are Not Enough Alone

Roles group permissions for convenience. The actual check at runtime is "does this user have permission X?" — not "is this user in role Y?" This distinction matters when you need to grant a single permission to a user without elevating their entire role (e.g., a contractor who can view invoices but not edit them), or when you need to audit exactly what actions a role enables.

The right mental model: **roles are named bundles of permissions**. Users get roles; roles carry permissions; permissions gate actions.

## Schema

```sql
create table roles (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null,
  name        text not null,          -- 'admin' | 'editor' | 'viewer' | 'billing'
  description text,
  is_system   boolean default false,  -- system roles cannot be deleted
  unique (tenant_id, name)
);

create table permissions (
  id       uuid primary key default gen_random_uuid(),
  action   text not null,             -- 'invoices:create' | 'invoices:read' | 'users:delete'
  resource text not null,             -- 'invoices' | 'users' | 'reports'
  unique (action)
);

create table role_permissions (
  role_id       uuid not null references roles(id) on delete cascade,
  permission_id uuid not null references permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

create table user_roles (
  user_id   uuid not null references users(id) on delete cascade,
  role_id   uuid not null references roles(id) on delete cascade,
  tenant_id uuid not null,
  granted_by uuid references users(id),
  granted_at timestamptz default now(),
  primary key (user_id, role_id)
);
```

Permission `action` follows a `resource:verb` convention (`invoices:create`, `users:read`, `reports:export`). This makes permission grants readable and auditable.

## Role Inheritance

The `admin` role should implicitly include all `editor` permissions, which include all `viewer` permissions. Two approaches:

**Database hierarchy**: add a `parent_role_id` to `roles`. When resolving permissions, recursively collect permissions from parent roles. Correct but requires a recursive query.

**Denormalized permission set**: when a role is saved, recompute its full permission set including inherited permissions and store it in a `permission_cache jsonb` column. Invalidate on role change. Faster reads, slightly complex write path.

For most applications (≤5 roles), explicit `role_permissions` rows duplicated across roles is simpler and more transparent than inheritance machinery.

## Runtime Permission Check

At the application level, resolve the user's full permission set once per request and cache it:

```ts
async function getUserPermissions(userId: string, tenantId: string): Promise<Set<string>> {
  const cacheKey = `perms:${userId}:${tenantId}`;
  const cached = await redis.get(cacheKey);
  if (cached) return new Set(JSON.parse(cached));

  const rows = await db
    .select({ action: permissions.action })
    .from(userRoles)
    .innerJoin(rolePermissions, eq(userRoles.roleId, rolePermissions.roleId))
    .innerJoin(permissions, eq(rolePermissions.permissionId, permissions.id))
    .where(and(eq(userRoles.userId, userId), eq(userRoles.tenantId, tenantId)));

  const perms = new Set(rows.map(r => r.action));
  await redis.set(cacheKey, JSON.stringify([...perms]), 'EX', 300); // 5 min TTL
  return perms;
}

function can(permissions: Set<string>, action: string): boolean {
  return permissions.has(action);
}
```

Invalidate the cache when user roles or role permissions change: `redis.del(`perms:${userId}:*`)`.

## Roles vs Capabilities

A **role** is a named collection: `admin`, `editor`.
A **capability** is a feature flag that lives outside the role system: `can_export_csv`, `beta_analytics`.

Mix them carefully. Capabilities belong in user/plan settings, not in the RBAC permission table. Adding `beta_features:access` as a permission that only one user has is a red flag — that's not a role concern, that's a feature flag.

## Enforcement Patterns

**Route-level**: middleware checks permission before the handler runs.
```ts
app.post('/api/invoices', requirePermission('invoices:create'), handler);
```

**Field-level**: resolvers or service functions check before returning sensitive fields.
```ts
if (!can(perms, 'invoices:read_amount')) { record.amount = null; }
```

**DB-level** (Supabase RLS): express role checks as policies so the DB enforces them even if app code is bypassed. This is the defense-in-depth layer — not a replacement for application checks.

```sql
create policy "viewers can read invoices in their tenant"
on invoices for select
using (
  tenant_id = auth.jwt() ->> 'tenant_id'
  and exists (
    select 1 from user_roles ur
    join role_permissions rp on ur.role_id = rp.role_id
    join permissions p on rp.permission_id = p.id
    where ur.user_id = auth.uid()
    and p.action = 'invoices:read'
  )
);
```

## Key Rules

- The check at runtime is **"does this user have permission X?"** — not "is this user an admin?".
- Follow **`resource:verb` naming** for permissions — readable and auditable.
- **Cache the resolved permission set** per user per request in Redis with a short TTL.
- **Invalidate permission cache** immediately when roles or role_permissions change.
- Use **`is_system = true`** on default roles so they cannot be accidentally deleted.
- Do not put **feature flags** in the RBAC table — those belong in plan/user settings.
- Apply **defense in depth**: app-level checks + DB-level RLS policies.

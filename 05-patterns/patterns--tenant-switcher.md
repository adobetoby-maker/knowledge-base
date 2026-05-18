# Pattern: Tenant Switcher

## Overview
Multi-tenant apps where users belong to multiple organizations need a first-class switching mechanism. Burying it in settings causes friction; every context switch should be two clicks maximum. The active org must be encoded in the session/JWT so every API request knows which tenant's data to scope — relying on a URL param alone creates IDOR risks.

## Implementation

### Session Structure
```typescript
// JWT payload — org context is authoritative, always set server-side
interface SessionPayload {
  userId: string;
  activeOrgId: string;
  orgRole: 'owner' | 'admin' | 'member';
  exp: number;
}

// Switching orgs re-issues the JWT — never just change a cookie value client-side
async function switchOrg(userId: string, targetOrgId: string): Promise<string> {
  // Verify user actually belongs to this org
  const membership = await db.orgMembers.findOne({ userId, orgId: targetOrgId });
  if (!membership) throw new ForbiddenError('Not a member of this organization');

  const newToken = await signJWT({
    userId,
    activeOrgId: targetOrgId,
    orgRole: membership.role,
  });

  return newToken;
}
```

### Switcher Component
```tsx
function TenantSwitcher() {
  const { user, session } = useAuth();
  const { orgs } = useUserOrgs(user.id); // all orgs user belongs to

  return (
    <DropdownMenu>
      <DropdownMenu.Trigger>
        <button className="flex items-center gap-2">
          <OrgAvatar org={currentOrg} size="sm" />
          <span>{currentOrg.name}</span>
          <ChevronDown size={14} />
        </button>
      </DropdownMenu.Trigger>

      <DropdownMenu.Content>
        <DropdownMenu.Label>Your organizations</DropdownMenu.Label>

        {orgs.map(org => (
          <DropdownMenu.Item
            key={org.id}
            onClick={() => handleSwitch(org.id)}
            className={org.id === session.activeOrgId ? 'bg-accent' : ''}
          >
            <OrgAvatar org={org} size="xs" />
            <span>{org.name}</span>
            <RoleBadge role={org.role} />
            {org.id === session.activeOrgId && <CheckIcon size={14} />}
          </DropdownMenu.Item>
        ))}

        <DropdownMenu.Separator />
        <DropdownMenu.Item onClick={openCreateOrgModal}>
          + Create organization
        </DropdownMenu.Item>
      </DropdownMenu.Content>
    </DropdownMenu>
  );
}

async function handleSwitch(orgId: string) {
  const newToken = await switchOrgMutation(orgId);
  // Update session with new JWT
  await updateSession(newToken);
  // Redirect to org's last visited page, or dashboard
  const lastPath = localStorage.getItem(`last-path:${orgId}`) ?? '/dashboard';
  router.push(lastPath);
}
```

### Remember Last Path Per Org
```typescript
// Save current path before switching
function useOrgPathMemory() {
  const { session } = useAuth();
  const pathname = usePathname();

  useEffect(() => {
    if (session?.activeOrgId) {
      localStorage.setItem(`last-path:${session.activeOrgId}`, pathname);
    }
  }, [pathname, session?.activeOrgId]);
}
```

### Placement in Nav
```tsx
// Top nav — not in settings — makes it always accessible
function TopNav() {
  return (
    <nav>
      <TenantSwitcher />       {/* Left side, prominent */}
      <NavLinks />
      <UserMenu />
    </nav>
  );
}
```

## Key Rules
- Encode active org in the JWT/session token — never scope data based on URL param alone
- Re-issue the JWT on org switch — don't just update a client-side variable
- Verify membership server-side on every switch — the client can't be trusted
- Place the switcher in the top nav, always visible — not buried in account settings
- Highlight the current org with a checkmark or background color
- Show the user's role in each org so they understand why access differs between orgs
- Redirect to the org's last visited page on switch, not always the dashboard
- "Create organization" link at the bottom of the list, always present
- Cache the org list — refetch on switch, not on every render
- If user has only one org, still show the switcher — they may create another later

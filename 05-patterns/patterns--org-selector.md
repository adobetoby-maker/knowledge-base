# Pattern: Organization / Workspace Switcher

## Overview
Switching organizations is a high-stakes action — navigating to the wrong org's data before the switch completes causes brief data cross-contamination. The URL must reflect the active org so links and back-navigation work correctly. Recent orgs must be persisted across sessions so returning users don't have to search for their primary workspace every time.

## URL and State Structure

```
// Org is encoded in the URL — not just in state
// /[orgSlug]/dashboard — org is always visible, linkable, and bookmarkable
// Switching org = navigate, not just setState

// Good: /acme-corp/settings → /beta-inc/settings (same path, different org)
// Bad:  switch org in global state → page doesn't reload → stale data shown
```

## Switcher Component

```tsx
function OrgSwitcher() {
  const { currentOrg, userOrgs } = useOrgs();
  const router = useRouter();
  const [search, setSearch] = useState('');
  const [open, setOpen] = useState(false);
  const recentOrgs = useRecentOrgs(); // Persisted to localStorage

  // Filter orgs by search input
  const filtered = userOrgs.filter(org =>
    org.name.toLowerCase().includes(search.toLowerCase()) ||
    org.slug.toLowerCase().includes(search.toLowerCase())
  );

  // Sort: recent orgs first, then alphabetical
  const sorted = [
    ...recentOrgs
      .map(id => userOrgs.find(o => o.id === id))
      .filter(Boolean) as Org[],
    ...filtered.filter(o => !recentOrgs.includes(o.id)),
  ].filter((o, i, arr) => arr.findIndex(x => x.id === o.id) === i); // Deduplicate

  function selectOrg(org: Org) {
    recordRecentOrg(org.id); // Update recent list

    // Replace the org segment in the current path
    // e.g., /old-org/dashboard → /new-org/dashboard
    const currentPath = router.pathname; // /[orgSlug]/...
    const newPath = currentPath.replace(/^\/[^/]+/, `/${org.slug}`);
    router.push(newPath);
    setOpen(false);
  }

  return (
    <div className="org-switcher" role="combobox" aria-expanded={open}>
      {/* Trigger button shows current org avatar + name */}
      <button
        className="org-switcher__trigger"
        onClick={() => setOpen(!open)}
        aria-label="Switch organization"
      >
        <OrgAvatar org={currentOrg} size="sm" />
        <span className="org-switcher__name">{currentOrg.name}</span>
        <ChevronIcon />
      </button>

      {open && (
        <div className="org-switcher__dropdown" role="listbox">
          <input
            type="search"
            placeholder="Find organization..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            autoFocus
          />

          {recentOrgs.length > 0 && !search && (
            <div className="org-switcher__section">
              <span className="org-switcher__section-label">Recent</span>
              {sorted.slice(0, 3).map(org => (
                <OrgOption key={org.id} org={org} current={org.id === currentOrg.id} onSelect={selectOrg} />
              ))}
            </div>
          )}

          <div className="org-switcher__section">
            <span className="org-switcher__section-label">All organizations</span>
            {sorted.map(org => (
              <OrgOption key={org.id} org={org} current={org.id === currentOrg.id} onSelect={selectOrg} />
            ))}
          </div>

          <hr />
          {/* Create new org always at the bottom — not mixed with existing orgs */}
          <button className="org-switcher__create" onClick={() => router.push('/orgs/new')}>
            + Create organization
          </button>
        </div>
      )}
    </div>
  );
}

function OrgOption({ org, current, onSelect }: OrgOptionProps) {
  return (
    <button
      role="option"
      aria-selected={current}
      className={`org-option ${current ? 'org-option--current' : ''}`}
      onClick={() => onSelect(org)}
    >
      <OrgAvatar org={org} size="sm" />
      <div>
        <div className="org-option__name">{org.name}</div>
        <div className="org-option__slug">{org.slug}</div>
      </div>
      {current && <CheckIcon />}
    </button>
  );
}
```

## Recent Orgs Persistence

```ts
const RECENT_KEY = 'recent-orgs';
const MAX_RECENT = 5;

function recordRecentOrg(orgId: string) {
  try {
    const existing: string[] = JSON.parse(localStorage.getItem(RECENT_KEY) ?? '[]');
    const updated = [orgId, ...existing.filter(id => id !== orgId)].slice(0, MAX_RECENT);
    localStorage.setItem(RECENT_KEY, JSON.stringify(updated));
  } catch {} // localStorage may be unavailable (private browsing, storage quota)
}

function useRecentOrgs(): string[] {
  return useMemo(() => {
    try {
      return JSON.parse(localStorage.getItem(RECENT_KEY) ?? '[]');
    } catch {
      return [];
    }
  }, []);
}
```

## Persisting Selected Org

```ts
// The URL is the source of truth for the active org — not localStorage
// But also write to localStorage as a fallback for direct navigation to /
// e.g., user visits the root path without an org segment

function useOrgFromUrl() {
  const { orgSlug } = useParams();
  const org = useOrgBySlug(orgSlug);

  useEffect(() => {
    if (org) {
      // Save as the "last visited org" for redirect on / 
      localStorage.setItem('last-org-slug', org.slug);
    }
  }, [org?.slug]);

  return org;
}

// Root redirect: /  →  /[lastOrgSlug]/dashboard
// This runs server-side via middleware to avoid flash of root page
```

## Key Rules
- Encode the active org in the URL (`/[orgSlug]/`) — state alone is not enough
- Switching org triggers a navigation, not just a state update — prevents stale data
- Show recent orgs first (localStorage, max 5) then all orgs alphabetically
- Put "Create new organization" at the bottom of the list, separated by a divider
- Search filters the full list live — don't paginate the org list server-side
- Record recent org on selection, not on page load — only visits that involve intent count
- Use URL as source of truth; localStorage `last-org-slug` is only for root-path redirect

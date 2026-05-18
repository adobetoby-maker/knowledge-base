# Pattern: Recent Search History with Suggestions

## Problem

Users expect their recent searches to persist across sessions, appear as quick-pick suggestions, support keyboard navigation, and vanish on logout for privacy. The tricky parts are deduplication (don't show "react hooks" twice), capping list length, and clearing on auth state changes.

## localStorage Management

Centralize all read/write in a single module so the component stays clean:

```ts
const STORAGE_KEY = 'recent-searches';
const MAX_ENTRIES = 10;

export function getRecentSearches(): string[] {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '[]');
  } catch {
    return [];
  }
}

export function addRecentSearch(query: string): string[] {
  const trimmed = query.trim();
  if (!trimmed) return getRecentSearches();

  const existing = getRecentSearches();
  // Dedup: remove old occurrence of same query (case-insensitive), prepend new
  const deduped = existing.filter(s => s.toLowerCase() !== trimmed.toLowerCase());
  const updated = [trimmed, ...deduped].slice(0, MAX_ENTRIES);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
  return updated;
}

export function clearRecentSearches(): void {
  localStorage.removeItem(STORAGE_KEY);
}
```

WHY deduplicate case-insensitively: "React" and "react" are the same search intent. WHY prepend instead of append: most recent should appear first.

## Privacy: Clear on Logout

Wire `clearRecentSearches()` to your auth logout handler — not to a component unmount, because unmounting doesn't equal logout:

```ts
// In your auth context or logout handler
async function logout() {
  await supabase.auth.signOut();
  clearRecentSearches();           // ← do this here, not in useEffect cleanup
  router.push('/login');
}
```

## Component with Keyboard Navigation

```tsx
function SearchInput() {
  const [query, setQuery] = useState('');
  const [recents, setRecents] = useState<string[]>([]);
  const [open, setOpen] = useState(false);
  const [activeIdx, setActiveIdx] = useState(-1);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setRecents(getRecentSearches());
  }, []);

  function handleKeyDown(e: React.KeyboardEvent) {
    if (!open) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActiveIdx(i => Math.min(i + 1, recents.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActiveIdx(i => Math.max(i - 1, -1));
    } else if (e.key === 'Enter' && activeIdx >= 0) {
      e.preventDefault();
      submitSearch(recents[activeIdx]);
    } else if (e.key === 'Escape') {
      setOpen(false);
    }
  }

  function submitSearch(value: string) {
    setQuery(value);
    setOpen(false);
    setActiveIdx(-1);
    const updated = addRecentSearch(value);
    setRecents(updated);
    // trigger search...
  }

  return (
    <div role="combobox" aria-expanded={open} aria-haspopup="listbox">
      <input
        ref={inputRef}
        value={query}
        onChange={e => { setQuery(e.target.value); setOpen(true); setActiveIdx(-1); }}
        onFocus={() => recents.length > 0 && setOpen(true)}
        onKeyDown={handleKeyDown}
        aria-controls="recent-list"
        aria-autocomplete="list"
        aria-activedescendant={activeIdx >= 0 ? `recent-${activeIdx}` : undefined}
      />
      {open && recents.length > 0 && (
        <ul id="recent-list" role="listbox">
          {recents.map((s, i) => (
            <li
              key={s}
              id={`recent-${i}`}
              role="option"
              aria-selected={i === activeIdx}
              onMouseDown={() => submitSearch(s)}  // mousedown fires before blur
            >
              {s}
            </li>
          ))}
          <li>
            <button type="button" onClick={() => { clearRecentSearches(); setRecents([]); setOpen(false); }}>
              Clear all
            </button>
          </li>
        </ul>
      )}
    </div>
  );
}
```

WHY `onMouseDown` instead of `onClick` on list items: `onClick` fires after `onBlur`, which closes the dropdown first. `onMouseDown` fires before blur.

## Key Rules

- Max 10 entries; deduplicate case-insensitively; always prepend newest
- `clearRecentSearches()` belongs in the logout handler, not component cleanup
- Arrow Up/Down navigate `activeIdx`; Enter selects; Escape closes
- Use `aria-activedescendant` pointing to the highlighted item ID — this is the correct ARIA pattern for combobox
- `onMouseDown` (not `onClick`) on list items to beat the input `onBlur`

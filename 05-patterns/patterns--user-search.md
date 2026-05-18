# Pattern: User Search / Picker

## Overview
User pickers used for sharing, mentions, and invitations need server-side search because the full user list is too large to load client-side. Debouncing prevents hammering the search endpoint on every keypress. Multi-select with chips gives a clear visual inventory of selected users. The already-selected filter prevents duplicates from appearing as valid picks.

## Hook: Debounced Server Search

```ts
function useUserSearch(
  excludeIds: string[] = [],
  debounceMs = 300
) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<User[]>([]);
  const [loading, setLoading] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    if (query.length < 2) {
      setResults([]);
      return;
    }

    // Cancel in-flight request before starting a new one
    // Without this, fast typists see stale results from earlier queries
    abortRef.current?.abort();
    abortRef.current = new AbortController();

    const timer = setTimeout(async () => {
      setLoading(true);
      try {
        const res = await fetch(
          `/api/users/search?q=${encodeURIComponent(query)}&exclude=${excludeIds.join(',')}`,
          { signal: abortRef.current!.signal }
        );
        if (!res.ok) return;
        const data: User[] = await res.json();
        // Server-side exclude is preferred, but client-side filter is a safety net
        setResults(data.filter(u => !excludeIds.includes(u.id)));
      } catch (e) {
        if ((e as Error).name !== 'AbortError') console.error(e);
        // AbortError is expected — don't treat it as a failure
      } finally {
        setLoading(false);
      }
    }, debounceMs);

    return () => clearTimeout(timer);
  }, [query, excludeIds.join(',')]);

  return { query, setQuery, results, loading };
}
```

## Server-Side Search Endpoint

```ts
// GET /api/users/search?q=alice&exclude=id1,id2
// Use full-text or trigram search — prefix-only search misses "alice smith" when querying "smith"
export async function GET(req: Request) {
  const url = new URL(req.url);
  const q = url.searchParams.get('q') ?? '';
  const excludeIds = url.searchParams.get('exclude')?.split(',').filter(Boolean) ?? [];

  if (q.length < 2) return Response.json([]);

  const users = await db.$queryRaw<User[]>`
    SELECT id, display_name, email, avatar_url
    FROM users
    WHERE
      id != ${currentUserId}                    -- Always exclude self
      AND id != ALL(${excludeIds}::uuid[])      -- Exclude already-selected
      AND (
        display_name ILIKE ${`%${q}%`}
        OR email ILIKE ${`%${q}%`}
      )
    ORDER BY
      similarity(display_name, ${q}) DESC,
      display_name ASC
    LIMIT 20
  `;

  return Response.json(users);
}
```

## Multi-Select Picker Component

```tsx
function UserPicker({ value, onChange, placeholder = 'Add people...' }: UserPickerProps) {
  const [open, setOpen] = useState(false);
  const selectedIds = value.map(u => u.id);
  const { query, setQuery, results, loading } = useUserSearch(selectedIds);
  const inputRef = useRef<HTMLInputElement>(null);

  function addUser(user: User) {
    if (selectedIds.includes(user.id)) return; // Deduplicate — safety check
    onChange([...value, user]);
    setQuery(''); // Clear search after selection
    inputRef.current?.focus(); // Return focus to input for next pick
  }

  function removeUser(userId: string) {
    onChange(value.filter(u => u.id !== userId));
  }

  return (
    <div className="user-picker" onClick={() => inputRef.current?.focus()}>
      {/* Chips for selected users */}
      <div className="user-picker__chips">
        {value.map(user => (
          <div key={user.id} className="user-chip">
            <img src={user.avatarUrl} alt="" className="user-chip__avatar" />
            <span>{user.displayName}</span>
            <button
              onClick={e => { e.stopPropagation(); removeUser(user.id); }}
              aria-label={`Remove ${user.displayName}`}
            >
              ✕
            </button>
          </div>
        ))}

        {/* Input always last — chips grow left of it */}
        <input
          ref={inputRef}
          type="text"
          value={query}
          onChange={e => { setQuery(e.target.value); setOpen(true); }}
          onFocus={() => setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 150)} // Delay for click events
          placeholder={value.length === 0 ? placeholder : ''}
          aria-autocomplete="list"
          aria-controls="user-search-results"
          aria-expanded={open}
        />
      </div>

      {/* Dropdown results */}
      {open && (query.length >= 2) && (
        <ul id="user-search-results" className="user-picker__results" role="listbox">
          {loading && <li className="user-picker__loading">Searching...</li>}
          {!loading && results.length === 0 && query.length >= 2 && (
            <li className="user-picker__empty">No users found for "{query}"</li>
          )}
          {results.map(user => (
            <li
              key={user.id}
              role="option"
              aria-selected={false}
              className="user-picker__result"
              onMouseDown={() => addUser(user)} // mousedown fires before blur
            >
              <img src={user.avatarUrl} alt="" className="user-result__avatar" />
              <div>
                <div className="user-result__name">{user.displayName}</div>
                <div className="user-result__email">{user.email}</div>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

## Key Rules
- Abort in-flight requests on new keystrokes — cancel with `AbortController`, ignore `AbortError`
- Debounce at 300ms; require minimum 2 characters before firing a search
- Exclude already-selected user IDs both server-side (performance) and client-side (safety net)
- Always exclude the current user from results — you can't share/mention yourself
- Use `onMouseDown` on result items, not `onClick` — `onClick` fires after `onBlur`, which closes the dropdown first
- Clear the query input after a selection and return focus to the input
- Show `displayName` + `email` in results — name alone isn't enough for disambiguation
- Empty state "No users found" is required — don't leave an empty dropdown with no message

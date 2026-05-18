# Pattern: Live Search with Instant Preview Dropdown

## Overview
Search-as-you-type with a results dropdown dramatically reduces the friction of finding items. The pattern requires careful attention to three concerns: debouncing to avoid hammering the API on every keystroke, keyboard navigation for accessibility, and the transition from preview to full results. Getting debounce timing wrong in either direction — too short (excessive requests) or too long (feels sluggish) — is the most common bug.

## Implementation

### Debounce + Fetch
```tsx
function useSearchPreview(query: string, delay = 200) {
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);

  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      setTotal(0);
      return;
    }

    setLoading(true);
    const id = setTimeout(async () => {
      try {
        const res = await fetch(`/api/search/preview?q=${encodeURIComponent(query)}&limit=5`);
        const data = await res.json();
        setResults(data.results);
        setTotal(data.total);
      } finally {
        setLoading(false);
      }
    }, delay);

    return () => clearTimeout(id); // Cancel pending if query changes
  }, [query, delay]);

  return { results, loading, total };
}
```

### Component with Keyboard Navigation
```tsx
function SearchWithPreview({ onNavigate }: { onNavigate: (path: string) => void }) {
  const [query, setQuery] = useState('');
  const [activeIndex, setActiveIndex] = useState(-1);
  const [open, setOpen] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLUListElement>(null);

  const { results, loading, total } = useSearchPreview(query);
  const showDropdown = open && query.trim().length > 0;

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (!showDropdown) return;

    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActiveIndex(i => Math.min(i + 1, results.length)); // +1 for "See all" item
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActiveIndex(i => Math.max(i - 1, -1));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (activeIndex === results.length) {
        // "See all results" item
        onNavigate(`/search?q=${encodeURIComponent(query)}`);
        setOpen(false);
      } else if (activeIndex >= 0) {
        onNavigate(results[activeIndex].url);
        setOpen(false);
      } else {
        // Enter with no selection = go to full results page
        onNavigate(`/search?q=${encodeURIComponent(query)}`);
        setOpen(false);
      }
    } else if (e.key === 'Escape') {
      setOpen(false);
      inputRef.current?.blur();
    }
  };

  return (
    <div role="combobox" aria-expanded={showDropdown} aria-haspopup="listbox">
      <input
        ref={inputRef}
        type="search"
        value={query}
        onChange={e => { setQuery(e.target.value); setOpen(true); setActiveIndex(-1); }}
        onFocus={() => setOpen(true)}
        onBlur={() => setTimeout(() => setOpen(false), 150)} // delay for click on result
        onKeyDown={handleKeyDown}
        aria-label="Search"
        aria-autocomplete="list"
        aria-controls="search-listbox"
        aria-activedescendant={activeIndex >= 0 ? `result-${activeIndex}` : undefined}
        placeholder="Search..."
      />
      {loading && <span aria-live="polite" className="sr-only">Loading results</span>}

      {showDropdown && (
        <ul
          id="search-listbox"
          ref={listRef}
          role="listbox"
          style={{ position: 'absolute', zIndex: 50, width: '100%' }}
        >
          {results.map((result, i) => (
            <li
              key={result.id}
              id={`result-${i}`}
              role="option"
              aria-selected={activeIndex === i}
              onMouseDown={() => { onNavigate(result.url); setOpen(false); }}
              style={{ background: activeIndex === i ? '#f3f4f6' : undefined }}
            >
              {/* Highlight matching text */}
              <HighlightMatch text={result.title} query={query} />
              {result.subtitle && <small>{result.subtitle}</small>}
            </li>
          ))}

          {total > results.length && (
            <li
              id={`result-${results.length}`}
              role="option"
              aria-selected={activeIndex === results.length}
              onMouseDown={() => { onNavigate(`/search?q=${encodeURIComponent(query)}`); setOpen(false); }}
            >
              See all {total.toLocaleString()} results →
            </li>
          )}

          {results.length === 0 && !loading && (
            <li role="option" aria-disabled="true">No results for "{query}"</li>
          )}
        </ul>
      )}
    </div>
  );
}
```

### Match Highlighting
```tsx
function HighlightMatch({ text, query }: { text: string; query: string }) {
  const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const parts = text.split(new RegExp(`(${escaped})`, 'gi'));
  return (
    <span>
      {parts.map((part, i) =>
        part.toLowerCase() === query.toLowerCase()
          ? <mark key={i}>{part}</mark>
          : part
      )}
    </span>
  );
}
```

## Key Rules
- Debounce at 200ms — less than 100ms floods the API on fast typers; more than 300ms feels laggy.
- Cancel the previous fetch on new input — return the cleanup function from `useEffect` to `clearTimeout`.
- The blur → close delay (150ms) allows click events on results to fire before the dropdown disappears.
- Show "See all N results" only if `total > results.length` — never show it when the preview already shows everything.
- ArrowDown/Up must use `preventDefault()` — without it, the cursor moves in the input field.
- Never close the dropdown on `ArrowDown`/`ArrowUp` — only `Escape`, click, or Enter closes it.
- Keyboard focus stays in the input during navigation — `aria-activedescendant` communicates selection, the focus ring never moves to the list items.

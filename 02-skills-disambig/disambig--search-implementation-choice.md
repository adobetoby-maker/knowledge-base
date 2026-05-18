# Disambig: Search Implementation Choice

## The Question

A search feature is needed — which implementation approach?

## Options

**1. Postgres full-text search** (via Supabase)
**2. Client-side filter** (filter already-loaded data)
**3. Trigram/ILIKE search** (Postgres ILIKE with index)
**4. External search service** (Algolia, Meilisearch, Typesense)
**5. Semantic vector search** (embeddings + pgvector)

## Decision Guide

| Scenario | Approach |
|----------|----------|
| Admin list with < 1000 items already loaded | Client-side filter |
| User-facing search across 1000–100k rows | Postgres full-text or ILIKE + trigram index |
| Public search on content-heavy site (docs, articles) | Algolia or Meilisearch |
| Semantic "find similar" queries | pgvector (Supabase built-in) |
| Multi-model search (search across invoices + clients + notes) | Full-text with UNION or external service |

## Client-Side Filter (Simplest)

Use when all data is already loaded in the client (small dataset, admin tools):

```tsx
function useSearch<T>(items: T[], searchFn: (item: T, query: string) => boolean) {
  const [query, setQuery] = useState('')
  const filtered = useMemo(() =>
    query ? items.filter(item => searchFn(item, query.toLowerCase())) : items,
    [items, query]
  )
  return { query, setQuery, filtered }
}

// Usage:
const { query, setQuery, filtered } = useSearch(
  clients,
  (client, q) =>
    client.name.toLowerCase().includes(q) ||
    client.email?.toLowerCase().includes(q) ||
    client.phone?.includes(q)
)
```

**Limit**: works up to ~500–1000 items before it feels slow. For 5000+ items, move to server-side.

## Postgres ILIKE + Trigram Index (Most Common)

Good for structured data with 100k+ rows:

```sql
-- Enable extension (once)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Trigram index for fast ILIKE
CREATE INDEX clients_name_trgm ON clients USING GIN (name gin_trgm_ops);
CREATE INDEX clients_email_trgm ON clients USING GIN (email gin_trgm_ops);
```

Query:
```ts
const { data } = await supabase
  .from('clients')
  .select('*')
  .or(`name.ilike.%${query}%,email.ilike.%${query}%`)
  .limit(20)
```

With a trigram index, this runs in < 10ms even on large tables.

## Postgres Full-Text Search

Better for multi-word queries, relevance ranking, and language-specific matching:

```sql
-- Add generated search vector column
ALTER TABLE articles ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(excerpt, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(body, '')), 'C')
  ) STORED;

CREATE INDEX articles_search_idx ON articles USING GIN (search_vector);
```

Query with ranking:
```ts
const { data } = await supabase
  .from('articles')
  .select('slug, title, excerpt, ts_rank(search_vector, query) as rank')
  .textSearch('search_vector', query, { type: 'websearch' })
  .order('rank', { ascending: false })
  .limit(10)
```

`websearch` mode supports: `"exact phrase"`, `OR`, `-excluded` operators.

## Debounced Search Input

Always debounce search queries to avoid hammering the server on every keystroke:

```tsx
function SearchInput({ onSearch }: { onSearch: (q: string) => void }) {
  const [value, setValue] = useState('')
  const debouncedSearch = useMemo(
    () => debounce(onSearch, 300),
    [onSearch]
  )

  return (
    <div className="relative">
      <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
      <Input
        value={value}
        onChange={e => {
          setValue(e.target.value)
          debouncedSearch(e.target.value)
        }}
        placeholder="Search..."
        className="pl-9"
      />
    </div>
  )
}
```

300ms debounce is the standard for search inputs.

## URL State for Search

Search queries belong in the URL so results are shareable and bookmarkable:

```ts
// Next.js: read from URL
const searchParams = useSearchParams()
const query = searchParams.get('q') ?? ''

// Update URL on search (replace, not push — don't pollute history)
const router = useRouter()
const updateSearch = (q: string) => {
  const params = new URLSearchParams(searchParams)
  if (q) params.set('q', q) else params.delete('q')
  router.replace(`?${params}`)
}
```

## When External Search Makes Sense

Use Algolia/Meilisearch when:
- You need real-time faceted filtering (filter by category + date + status simultaneously)
- You need typo tolerance ("auti repair" → "auto repair")
- Your content is mostly text (docs, articles, knowledge base)
- Search is the primary navigation mechanism, not just a filter

External services add infrastructure complexity. Default to Postgres until you have a specific reason to add an external service.

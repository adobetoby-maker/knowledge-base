# Search Implementation

## Three Search Approaches

1. **Client-side filter** — filter in-memory array, no DB calls. Best for < 500 items.
2. **Server-side ILIKE** — Postgres `ILIKE '%query%'`. Good for moderate data, no setup.
3. **Full-text search (FTS)** — Postgres `tsvector`. Best for large datasets, better relevance.

## Client-Side Search

```typescript
// For small datasets (articles, services list):
function useClientSearch<T extends Record<string, unknown>>(
  items: T[],
  searchFields: (keyof T)[],
  query: string
): T[] {
  return useMemo(() => {
    if (!query.trim()) return items
    const lower = query.toLowerCase()
    return items.filter(item =>
      searchFields.some(field => {
        const value = item[field]
        return typeof value === 'string' && value.toLowerCase().includes(lower)
      })
    )
  }, [items, searchFields, query])
}

// Usage:
const results = useClientSearch(articles, ['title', 'excerpt', 'category'], query)
```

## Server-Side ILIKE

For up to ~50k rows. Simple, no index required (though an index helps):

```typescript
// Supabase ILIKE:
const { data } = await supabase
  .from('customers')
  .select('*')
  .ilike('name', `%${query}%`)  // case-insensitive contains
  .order('name')
  .limit(20)

// Multi-field search:
const { data } = await supabase
  .from('invoices')
  .select('*')
  .or(`customer_name.ilike.%${query}%,invoice_number.ilike.%${query}%`)
  .order('created_at', { ascending: false })
  .limit(20)
```

## Full-Text Search

For large datasets or when ranking by relevance matters:

```sql
-- Setup: add FTS index to articles table:
ALTER TABLE articles
ADD COLUMN search_vector tsvector
GENERATED ALWAYS AS (
  to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
) STORED;

CREATE INDEX articles_search_idx ON articles USING GIN (search_vector);
```

```typescript
// Query:
const { data } = await supabase
  .from('articles')
  .select('*')
  .textSearch('search_vector', query, {
    type: 'websearch',     // supports "exact phrases", word1 word2 (AND)
    config: 'english',
  })
  .order('created_at', { ascending: false })
```

`type: 'websearch'` is the most user-friendly — it parses natural language queries.
`type: 'plain'` treats each word as AND.
`type: 'phrase'` requires exact phrase match.

## Search Results Component

```typescript
'use client'
import { useState, useTransition } from 'react'

export function SearchResults() {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Article[]>([])
  const [isPending, startTransition] = useTransition()
  
  const debouncedSearch = useMemo(
    () => debounce((q: string) => {
      if (!q.trim()) { setResults([]); return }
      startTransition(async () => {
        const data = await searchArticles(q)
        setResults(data)
      })
    }, 300),
    []
  )
  
  return (
    <div className="space-y-4">
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <Input
          value={query}
          onChange={(e) => { setQuery(e.target.value); debouncedSearch(e.target.value) }}
          placeholder="Search articles..."
          className="pl-9"
        />
        {isPending && <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 animate-spin" />}
      </div>
      
      {query && results.length === 0 && !isPending && (
        <p className="text-sm text-muted-foreground">No results for "{query}"</p>
      )}
      
      {results.map(article => (
        <SearchResultItem key={article.slug} article={article} query={query} />
      ))}
    </div>
  )
}
```

## Highlighting Matches

```typescript
function SearchResultItem({ article, query }: { article: Article; query: string }) {
  return (
    <Link href={`/blog/${article.slug}`} className="block hover:bg-muted p-3 rounded-md">
      <h3 className="font-medium">
        <HighlightText text={article.title} query={query} />
      </h3>
      <p className="text-sm text-muted-foreground mt-1 line-clamp-2">
        <HighlightText text={article.excerpt} query={query} />
      </p>
    </Link>
  )
}

function HighlightText({ text, query }: { text: string; query: string }) {
  if (!query) return <span>{text}</span>
  
  const parts = text.split(new RegExp(`(${escapeRegExp(query)})`, 'gi'))
  return (
    <span>
      {parts.map((part, i) =>
        part.toLowerCase() === query.toLowerCase()
          ? <mark key={i} className="bg-yellow-200 rounded-sm">{part}</mark>
          : <span key={i}>{part}</span>
      )}
    </span>
  )
}

function escapeRegExp(s: string) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}
```

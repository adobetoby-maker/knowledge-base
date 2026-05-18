# Search with Results Pattern

## Two Approaches

1. **Client-side search**: Filter an in-memory array. Fast for < 500 items. No server round-trip.
2. **Server-side search**: Query the database. Required for large datasets or full-text search.

## Client-Side Filtering

For small datasets loaded once (articles, services list):

```typescript
'use client'
import { useState, useMemo } from 'react'

export function ArticleSearch({ articles }: { articles: Article[] }) {
  const [query, setQuery] = useState('')
  
  const results = useMemo(() => {
    if (!query.trim()) return articles
    const lower = query.toLowerCase()
    return articles.filter(a =>
      a.title.toLowerCase().includes(lower) ||
      a.excerpt.toLowerCase().includes(lower) ||
      a.category.toLowerCase().includes(lower)
    )
  }, [articles, query])
  
  return (
    <div className="space-y-4">
      <Input
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Search articles..."
        className="max-w-sm"
      />
      
      {query && (
        <p className="text-sm text-muted-foreground">
          {results.length} result{results.length !== 1 ? 's' : ''} for "{query}"
        </p>
      )}
      
      {results.length === 0 ? (
        <p className="text-muted-foreground">No articles found for "{query}"</p>
      ) : (
        <ArticleList articles={results} />
      )}
    </div>
  )
}
```

## Server-Side Search (URL State)

For database search — put query in URL so it's shareable and bookmarkable:

```typescript
// Search input — writes to URL:
'use client'
export function SearchInput() {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const [value, setValue] = useState(searchParams.get('q') ?? '')
  
  const debouncedPush = useMemo(
    () => debounce((q: string) => {
      const params = new URLSearchParams(searchParams.toString())
      if (q) { params.set('q', q); params.delete('page') }
      else params.delete('q')
      router.push(`${pathname}?${params.toString()}`)
    }, 300),
    [router, pathname, searchParams]
  )
  
  return (
    <div className="relative">
      <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
      <Input
        value={value}
        onChange={(e) => { setValue(e.target.value); debouncedPush(e.target.value) }}
        placeholder="Search customers..."
        className="pl-9"
      />
      {value && (
        <Button
          variant="ghost" size="icon"
          className="absolute right-1 top-1/2 -translate-y-1/2 h-7 w-7"
          onClick={() => { setValue(''); debouncedPush('') }}
        >
          <X className="h-3 w-3" />
        </Button>
      )}
    </div>
  )
}

// Page component — reads from URL, fetches from DB:
export default async function CustomersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>
}) {
  const { q } = await searchParams
  const customers = await searchCustomers(q)
  
  return (
    <div>
      <SearchInput />
      <CustomerList customers={customers} searchQuery={q} />
    </div>
  )
}
```

## Supabase Full-Text Search

```typescript
// Simple ILIKE search (case-insensitive substring):
const { data } = await supabase
  .from('customers')
  .select('*')
  .ilike('name', `%${query}%`)
  .order('name')
  .limit(20)

// Full-text search (better for longer content):
const { data } = await supabase
  .from('articles')
  .select('*')
  .textSearch('body', query, { type: 'websearch' })
  // 'websearch' supports: "exact phrase", word1 word2 (AND), word1 OR word2

// Multi-field search using or():
const { data } = await supabase
  .from('invoices')
  .select('*')
  .or(`customer_name.ilike.%${query}%,invoice_number.ilike.%${query}%`)
```

Full-text search requires a GIN index on the column:
```sql
CREATE INDEX invoices_body_fts ON articles USING GIN (to_tsvector('english', body));
```

## Highlighting Search Terms

```typescript
function HighlightedText({ text, query }: { text: string; query: string }) {
  if (!query) return <span>{text}</span>
  
  const parts = text.split(new RegExp(`(${escapeRegExp(query)})`, 'gi'))
  
  return (
    <span>
      {parts.map((part, i) =>
        part.toLowerCase() === query.toLowerCase() ? (
          <mark key={i} className="bg-yellow-200 text-yellow-900 rounded px-0.5">
            {part}
          </mark>
        ) : (
          <span key={i}>{part}</span>
        )
      )}
    </span>
  )
}

function escapeRegExp(str: string) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}
```

## Empty State with Suggestions

```typescript
{results.length === 0 && query && (
  <div className="text-center py-12">
    <Search className="h-8 w-8 mx-auto text-muted-foreground mb-3" />
    <p className="font-medium">No results for "{query}"</p>
    <p className="text-sm text-muted-foreground mt-1">
      Try different keywords or{' '}
      <button className="text-primary underline" onClick={() => setValue('')}>
        clear the search
      </button>
    </p>
  </div>
)}
```

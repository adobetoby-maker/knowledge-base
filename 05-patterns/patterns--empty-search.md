# Pattern: Empty State for Search with No Results

## Why This Pattern Matters

Empty search states are missed conversion opportunities. A blank page or generic "No results" message leaves users stranded. The right empty state guides them to either refine their query, discover adjacent content, or take a productive action — all of which keep them in the product instead of leaving.

## Two Distinct Cases

Never render the same UI for both cases. They have different meanings and different remedies.

**Case 1: No query entered** (initial state / cleared input)
Show a list of popular or recent searches, category shortcuts, or a prompt to start typing. This is a discovery surface, not an error.

**Case 2: Query returned no results**
Show the "no results" state with remediation options. This is the error case.

```tsx
if (!query.trim()) return <SearchStartState recentSearches={recents} />;
if (results.length === 0) return <NoResultsState query={query} />;
```

## No Results State: What to Show

**Spelling suggestion:** If fuzzy matching finds a close term, show "Did you mean: [suggestion]?" as a clickable link that fills the input with the corrected term. Many search backends return this natively; client-side use `fastest-levenshtein` for simple cases.

**Related searches:** Show 3–5 terms semantically adjacent to the query. These can come from pre-built tag/category relationships or from a "users who searched X also searched Y" log. Display as clickable chips.

**Clear the query:** Always provide a one-click "Clear search" or "Reset filters" action. Don't rely on the user knowing to delete the input manually.

**CTA to create:** If the user has create permissions and the search is over a list of user-owned items (projects, contacts, documents), show "Create '[query]'" as a primary action. This converts a failed search into a creation intent — high signal for what the user wants.

```tsx
<EmptyState
  icon={<Search className="h-10 w-10 text-muted-foreground" />}
  title={`No results for "${query}"`}
  description="Try a different spelling or browse categories."
>
  {spellingSuggestion && (
    <p>Did you mean: <button onClick={() => setQuery(spellingSuggestion)} className="underline">{spellingSuggestion}</button>?</p>
  )}
  {canCreate && (
    <Button onClick={() => onCreate(query)}>
      Create "{query}"
    </Button>
  )}
  <RelatedSearchChips terms={relatedTerms} onSelect={setQuery} />
</EmptyState>
```

## Searching with Active Filters

If the user has active filters alongside a text query, show which filter is most likely restricting results. "No results in [Current Filter]. Try searching all categories." with a button to clear just that filter. This reduces frustration from invisible filter interactions.

## Search Start State (No Query)

Show recent searches (last 5, from `localStorage`) with an X to remove each. Below that, show 3–6 popular categories or top items as a browsing shortcut. This state should feel like a quick-access panel, not a blank canvas.

```ts
const recentSearches = JSON.parse(localStorage.getItem('search:recent') ?? '[]') as string[];

function recordSearch(query: string) {
  const updated = [query, ...recentSearches.filter(q => q !== query)].slice(0, 5);
  localStorage.setItem('search:recent', JSON.stringify(updated));
}
```

## Key Rules

- Distinguish "no query" from "no results" — never render the same component for both
- Spelling suggestion is a clickable fill action, not plain text
- "Create [query]" CTA only appears if user has create permission
- Show which active filter is causing empty results when filters are applied
- Recent searches stored in `localStorage`, max 5, with individual remove
- Never show "0 results found" in a table header without an empty state illustration
- Related searches must be real terms, not randomly generated — use logs or a curated list

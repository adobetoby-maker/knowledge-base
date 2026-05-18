# Skill: Algolia Search Integration

## Overview
Algolia is a hosted search engine that returns results in under 100ms with typo tolerance, faceting, and ranking built in. The key to getting it right is keeping Algolia's index in sync with your DB (the hard part), and configuring searchable attributes and ranking before going live (hard to change later without confusing users).

## Implementation

### 1. Index configuration (run once, not on every deploy)
```ts
import algoliasearch from 'algoliasearch';

const client = algoliasearch(process.env.ALGOLIA_APP_ID!, process.env.ALGOLIA_ADMIN_KEY!);
const index = client.initIndex('products');

await index.setSettings({
  // Fields searched, in priority order — order matters for relevance
  searchableAttributes: [
    'name',
    'brand',
    'description',    // lower priority than name/brand
    'unordered(tags)', // position within field doesn't matter for tags
  ],
  
  // Fields used to filter/facet (must declare upfront)
  attributesForFaceting: [
    'filterOnly(category)',   // filter only, not shown as facet counts
    'searchable(brand)',      // facet + searchable
    'price',
  ],

  // What to show highlighted in results
  attributesToHighlight: ['name', 'description'],
  attributesToSnippet: ['description:30'],  // 30-word snippet

  // Custom ranking — after relevance, sort by your metrics
  customRanking: ['desc(popularity)', 'desc(rating)'],

  // Typo tolerance (default is fine for most cases)
  minWordSizefor1Typo: 4,
  minWordSizefor2Typos: 8,
});
```

### 2. Sync records via DB webhook
```ts
// Sync on create/update — called from your DB trigger or event
async function syncToAlgolia(product: Product) {
  const record = {
    objectID: product.id,       // Algolia's primary key — must be stable
    name: product.name,
    brand: product.brand,
    description: product.description,
    category: product.category,
    price: product.price,
    popularity: product.viewCount,
    rating: product.avgRating,
    tags: product.tags,
    updatedAt: product.updatedAt.getTime(), // unix ms for range filtering
  };
  
  await index.saveObject(record);  // upsert by objectID
}

// On delete
async function removeFromAlgolia(productId: string) {
  await index.deleteObject(productId);
}
```

### 3. Batch sync (initial load or full re-index)
```ts
async function reindexAll() {
  const products = await db.products.findMany({ where: { active: true } });
  
  const records = products.map(p => ({
    objectID: p.id,
    ...mapProductToRecord(p),
  }));

  // Replace all — atomic swap, no downtime during re-index
  await index.replaceAllObjects(records, { safe: true });
}
```

### 4. Frontend with InstantSearch
```tsx
import { InstantSearch, SearchBox, Hits, RefinementList, Highlight } from 'react-instantsearch';
import algoliasearch from 'algoliasearch/lite';

// Use search-only (public) API key on the frontend — never admin key
const searchClient = algoliasearch(
  process.env.NEXT_PUBLIC_ALGOLIA_APP_ID!,
  process.env.NEXT_PUBLIC_ALGOLIA_SEARCH_KEY!
);

function SearchPage() {
  return (
    <InstantSearch searchClient={searchClient} indexName="products">
      <SearchBox placeholder="Search products..." />
      
      <RefinementList attribute="brand" />  {/* facet sidebar */}
      
      <Hits hitComponent={({ hit }) => (
        <div>
          <Highlight attribute="name" hit={hit} />  {/* highlighted match */}
          <Snippet attribute="description" hit={hit} />
          <span>${hit.price}</span>
        </div>
      )} />
    </InstantSearch>
  );
}
```

### 5. Secured API keys (restrict by user)
```ts
// Generate per-session key restricting to user's tenant
const restrictedKey = client.generateSecuredApiKey(
  process.env.ALGOLIA_SEARCH_KEY!,
  {
    filters: `tenantId:${user.tenantId}`,  // user can only see their tenant's data
    validUntil: Math.floor(Date.now() / 1000) + 3600,  // expires in 1h
  }
);
// Send restrictedKey to client, never the admin key
```

## Key Rules
- **Declare `attributesForFaceting` before querying with filters** — adding a filter attribute not in this list throws an error at query time.
- Use `replaceAllObjects` for re-indexing, never delete + reindex — delete creates a window with no results.
- Never expose the admin API key on the frontend — use search-only keys or secured keys.
- `objectID` must be your DB primary key — don't use auto-generated Algolia IDs or you lose the ability to update/delete by record.
- Index only fields you need for search, filter, or display — extra fields waste bandwidth on every query.
- Set `customRanking` before launch — changing ranking after users develop expectations causes perceived regressions.
- Test typo tolerance with real user queries from search logs before adjusting `minWordSizefor1Typo`.

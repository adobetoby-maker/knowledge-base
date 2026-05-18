# Disambiguation: Where Does Content Live?

## The Cardinal Rule

**Articles, blog posts, how-tos, and static content live in TypeScript files, not markdown files.**

This rule applies across all projects. There is no exception. If you're about to create a `.md` file for content, stop and write to the TypeScript array instead.

## Content by Project

### jrs-auto-repair
```typescript
// lib/articles.ts — blog articles
export const articles: Article[] = [
  { slug, title, excerpt, category, date, readTime, body }
]

// lib/howtos.ts — how-to guides
export const howtos: HowTo[] = [
  { slug, title, steps, ... }
]

// lib/shopInfo.ts — ALL business information
export const shopInfo = {
  name: "Jr.'s Auto Repair",
  phone: "(208) 595-2101",
  address: "417 Main Ave E, Twin Falls, ID 83301",
  hours: { /* ... */ }
}
```

Never put business info (address, phone, hours) anywhere except `lib/shopInfo.ts`. If the phone number changes, it changes in one place.

### climb-brasil / climb-spain / climb-utah / climb-kalymnos
```typescript
// lib/articles.ts — destination and route guide content
// lib/destinations.ts (if exists) — destination data
```

### language-lens-elite
```typescript
// src/data/articles.ts (or similar) — language learning articles
// Content vocabulary, exercises — check existing structure before adding
```

### manage-worker-bee
No article content — it's a management tool. Content decisions for manage-worker-bee are in the blueprint canvas (stored in Supabase Storage as JSON).

## Why TypeScript, Not Markdown?

1. **Type safety:** TypeScript arrays are type-checked. You can't accidentally omit a required field.
2. **Build-time checks:** If you reference `article.slug` that doesn't exist, TypeScript catches it at build time.
3. **No filesystem scanning:** Blog pages read from the array, not from a directory. No `fs.readdir()` needed.
4. **SEO metadata co-location:** The `excerpt` field becomes the meta description in the same object.
5. **Searchable by slug:** `articles.find(a => a.slug === slug)` is faster and more reliable than filesystem glob.

## Adding New Content

```typescript
// Always append to the ARRAY in the existing TypeScript file:
export const articles: Article[] = [
  // ... existing articles ...
  {
    slug: 'brake-pads-twin-falls-2026',
    title: 'Brake Pad Replacement in Twin Falls: 2026 Cost Guide',
    excerpt: 'Brake pad replacement typically costs $150–$300 in Twin Falls ID. Learn the signs and what to expect.',
    category: 'repairs',
    date: '2026-05-18',
    readTime: '5 min read',
    body: `...`
  }
]
```

## Supabase Content (Dynamic)

When content needs to be editable by clients (e.g., a client's own site content managed through manage-worker-bee):
- Store in a Supabase table with appropriate RLS
- Serve via a Route Handler that the frontend fetches

When content is managed by the developer (our sites):
- Static TypeScript array — faster, simpler, type-safe

## Images for Content

Images live in `/public/` directory or are sourced from external CDNs (Wikimedia, Unsplash). Reference them by URL:

```typescript
// In article body (markdown):
![Brake pad inspection](https://example.com/image.jpg)

// Or as a field in the article object:
{ slug: '...', coverImage: '/images/brake-pads.jpg', ... }
```

For the climbing sites: use Wikimedia Commons images (proper licensing for outdoor/travel content). For jrs-auto-repair: use local photos in `/public/images/`.

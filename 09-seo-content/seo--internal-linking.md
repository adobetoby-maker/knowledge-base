# Internal Linking Strategy

## Why Internal Links Matter for SEO

Internal links:
1. Pass PageRank (link equity) between pages — a link from a high-authority page boosts the target
2. Help crawlers discover and index pages
3. Tell search engines which pages are most important (more internal links = more important)
4. Improve user experience by connecting related content

## Hub and Spoke Model

```
Homepage (hub)
├── /services (hub)
│   ├── /services/oil-change (spoke)
│   ├── /services/brake-repair (spoke)
│   └── /services/tire-rotation (spoke)
├── /blog (hub)
│   ├── /blog/when-to-change-oil (spoke → links back to /services/oil-change)
│   └── /blog/brake-pad-signs (spoke → links back to /services/brake-repair)
└── /locations (hub)
    ├── /locations/twin-falls (spoke)
    └── /locations/magic-valley (spoke)
```

Blog articles link back to relevant service pages. Service pages link to related blog articles. This creates a cluster that reinforces topical authority.

## Implementing Internal Links in Static Content

In `lib/articles.ts`, body content is a string. Include internal links as markdown or HTML:
```typescript
{
  slug: 'when-to-change-synthetic-oil',
  title: 'When to Change Full Synthetic Oil',
  body: `
Full synthetic oil lasts longer than conventional oil, typically 7,500–10,000 miles.
If you're unsure about your vehicle's interval, our 
[oil change service in Twin Falls](/services/oil-change) includes a free inspection.

Signs you need an oil change sooner:
- Oil is dark and gritty
- Oil level is low
- Check engine or oil pressure light

[Book an oil change appointment](tel:2085952101) today.
  `,
}
```

## Anchor Text Rules

| Type | When to Use | Example |
|---|---|---|
| Exact match | Use sparingly (once per page max) | "oil change Twin Falls" |
| Partial match | Most common | "our oil change service" |
| Branded | Always safe | "Jr.'s Auto Repair" |
| Generic | Avoid | "click here", "learn more" |

Don't repeat the exact same anchor text for the same target across many pages — it looks manipulative.

## Programmatic Internal Linking

For climb-* sites with many routes and blog posts, add a "Related Articles" section at the bottom of each page:

```typescript
// lib/articles.ts - add related slugs to each article
export const articles = [
  {
    slug: 'best-climbing-in-twin-falls',
    related: ['twin-falls-route-guide', 'camping-near-twin-falls'],
    // ...
  },
]

// Component
function RelatedArticles({ currentSlug }: { currentSlug: string }) {
  const current = articles.find(a => a.slug === currentSlug)
  const related = articles.filter(a => current?.related.includes(a.slug))
  
  if (!related.length) return null
  
  return (
    <section>
      <h2>Related Articles</h2>
      {related.map(article => (
        <a key={article.slug} href={`/blog/${article.slug}`}>
          {article.title}
        </a>
      ))}
    </section>
  )
}
```

## Contextual Links in Body Content

The highest-value internal links are contextual — embedded naturally in body text. A sidebar link is worth less than a link within a relevant paragraph.

For service pages, link to related services within the description:
```typescript
// services/oil-change description
`While you're in for an oil change, ask about our 
[tire rotation service](/services/tire-rotation) — bundled services save time.`
```

## Cross-Site Linking (Climb Sites)

The climb-* sites are separate domains. Link between them when relevant:
- climbbrasil.com blog post about "Planning a Multi-Country Climbing Trip" → links to climb-kalymnos.worker-bee.app
- Kalymnos site → links back to Brasil site for warm-weather winter climbing

Cross-site links build authority by demonstrating a related content network. They don't pass as much equity as same-domain links, but they create a natural link cluster.

## Audit Internal Links

Periodically check for:
- Orphan pages (no internal links pointing to them)
- Pages with only one internal link
- Broken internal links (404s)

```bash
# Quick orphan check: find pages not linked from anywhere else
grep -r "href=" app/ | grep -v "external" | sort | uniq -c | sort -n
# Low count = potential orphan pages
```

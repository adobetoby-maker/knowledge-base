# SEO: Cornerstone Content Strategy

## What This Solves

Cornerstone content is the 2–5 most important pages on a site that define topical authority. Every other piece of content links back to these pages, concentrating link equity and signaling to Google what the site is fundamentally about. Without cornerstone content, a site's link equity is diffused across dozens of equally weighted pages.

## What Makes a Cornerstone Article

A cornerstone article:
- Covers the broadest version of a topic (e.g., "Complete Guide to Car Maintenance" not "How to Change Your Oil")
- Targets a high-volume head keyword (500+ monthly searches)
- Is the most comprehensive treatment of that topic on your site
- Receives internal links from all related articles
- Gets updated regularly (Google rewards freshness on cornerstone topics)
- Is longer than other articles (typically 1,500–3,000+ words)

## Identifying Cornerstones

For jrs-auto-repair, the cornerstone topics align with the highest-volume service searches:
- "Auto repair Twin Falls" — the main local service hub page
- "Car maintenance guide" — an evergreen educational cornerstone
- "Mechanic Twin Falls ID" — the local authority page

For language-lens-elite:
- "Learn Japanese online" — the main language hub
- "JLPT preparation guide" — the test-focused cornerstone

## Internal Linking Structure

```
[Cornerstone: "Complete Car Maintenance Guide"]
         ↑ linked from all sub-articles
         ↓ links to sub-articles

    ├── [Oil Change: When and How Often]
    ├── [Brake Service: Signs Your Brakes Need Attention]
    ├── [Transmission Maintenance Guide]
    ├── [Tire Rotation and Alignment]
    └── [Engine Tune-Up Checklist]
```

Every sub-article must link to the cornerstone with descriptive anchor text (not "click here").

## Cornerstone Page Structure

```tsx
// app/blog/car-maintenance-guide/page.tsx
export const metadata: Metadata = {
  title: 'Complete Car Maintenance Guide | JR\'s Auto Repair Twin Falls',
  description: 'Everything Twin Falls drivers need to know about maintaining their vehicle — oil changes, brakes, tires, and more from a trusted local mechanic.',
}

export default function CarMaintenanceGuide() {
  return (
    <article>
      <h1>The Complete Car Maintenance Guide for Twin Falls Drivers</h1>

      {/* Table of contents — essential for long-form cornerstones */}
      <TableOfContents />

      {/* Each section links to a dedicated sub-article */}
      <section id="oil-changes">
        <h2>Oil Changes</h2>
        <p>Regular oil changes are the foundation of vehicle longevity...</p>
        <Link href="/blog/oil-change-frequency-twin-falls">
          Learn more: How often should you change your oil?
        </Link>
      </section>

      {/* Schema: Article + FAQ */}
      <FaqWithSchema items={maintenanceFaqs} />
    </article>
  )
}
```

## Internal Link Tracking

Maintain a mental map (or a document) of which articles link to which cornerstones:

```ts
// Check: does each cluster article link to the cornerstone?
const CLUSTER_ARTICLES = [
  'oil-change-frequency',
  'brake-repair-signs',
  'transmission-service-guide',
]

// Each article in lib/articles.ts should contain a link
// to the cornerstone using the pattern:
// "For a full overview, see our [Complete Car Maintenance Guide]."
```

## Updating Cornerstones

Cornerstones need updates when:
- A significant sub-topic is added (new article published → add it to the cornerstone)
- Information goes stale (outdated advice, changed prices)
- A keyword starts ranking for the cornerstone but the content doesn't match the intent

When you update a cornerstone, change its `date` field in `lib/articles.ts` — this signals freshness to crawlers.

## Cornerstone vs. Pillar Page

Some call this "pillar and cluster" content. The concept is the same:
- **Pillar/cornerstone**: broad overview, links to cluster
- **Cluster articles**: specific sub-topics, all link back to the pillar

The difference from random blog posts: cornerstones are explicitly maintained as authoritative reference documents, not just standalone articles.

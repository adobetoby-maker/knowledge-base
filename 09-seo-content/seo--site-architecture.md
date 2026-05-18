# Site Architecture for SEO

Site architecture determines how authority flows through the site, how easily crawlers discover all pages, and how clearly topics are grouped. Good architecture is invisible to users but has significant long-term SEO compounding effects.

## Flat URL Structure (Max 3 Levels Deep)

Pages more than 3 levels deep from the root receive less crawl budget and are perceived as lower importance:

```
Good: /blog/auto-repair-tips/brake-maintenance
Avoid: /blog/categories/auto-repair/tips/maintenance/brakes/complete-guide
```

Flat architecture keeps pages closer to the root, distributes PageRank more evenly, and makes URLs shorter and more shareable. Restructure deep hierarchies by flattening category layers: `/shop/category/subcategory/product/` becomes `/shop/category/product/`.

When restructuring, redirect every old URL to its new equivalent. Broken redirects from a restructure are a larger ranking penalty than the structural improvement provides.

## Hub-and-Spoke Topic Clusters

Organize content into clusters: one hub page (pillar/cornerstone) covers a broad topic authoritatively; spoke pages cover subtopics in depth and link back to the hub.

```
Hub:   /auto-repair-twin-falls (broad topic authority)
Spokes: /auto-repair-twin-falls/brake-repair
        /auto-repair-twin-falls/oil-change
        /auto-repair-twin-falls/transmission-service
```

The hub page ranks for competitive head terms; spoke pages rank for long-tail variants. Internal links from spokes to hub and from hub to spokes create a topical authority signal that tells Google this site is the deep expert on auto repair in Twin Falls.

Do not create orphaned spokes with no internal links. Every spoke must link to its hub; the hub must link to all its spokes.

## Pagination SEO

`rel="next"` and `rel="prev"` were deprecated by Google in 2019 — they are ignored. Current best practices for paginated content:

- **Infinite scroll / Load more**: preferred for many use cases. Only page 1 is indexable; subsequent content loads via JavaScript. This is fine for listings where page 1 captures most search value. Add a link to "View all" for crawlable aggregation.
- **Traditional pagination**: each page gets a canonical pointing to `?page=1` (the first page, which has the most link equity), unless individual pages have genuine standalone search value (they usually don't for e-commerce pagination).
- **Category page optimization**: category pages compete for the same queries as paginated pages. Invest content budget in page 1 of category pages; deeper pages can have `noindex` if they're just filtered/sorted product grids with no original content.

## Category Page Optimization

Category pages are often thin (just a grid of products or article thumbnails). They need unique content to rank:
- A 100–200 word introduction that uses the category's target keyword naturally.
- FAQs or buyer guidance above or below the grid.
- Aggregated structured data (AggregateRating, ItemList schema).

A category page with only images and prices/titles is thin content; it will rank below a competitor category page with genuine editorial content.

## Key Rules

- Max 3 URL levels deep from the root; restructure with redirects if violating this.
- Hub-and-spoke topology: every spoke must link to its hub; every hub must link to all spokes.
- `rel="next/prev"` is deprecated (2019); do not implement it.
- Paginated pages beyond page 1 typically warrant canonical to page 1 unless they have standalone search value.
- Category pages need 100–200 words of unique introductory content to compete against editorial pages.
- Internal link graph should be intentional, not random — links pass authority; orphaned pages receive none.

# SEO: Site Architecture for SEO

## Overview
Site architecture determines how PageRank flows through a site, how deep Googlebot must crawl to reach important pages, and whether semantically related pages are grouped together in a way that signals topical authority. A flat, logical architecture means more crawl budget on important pages, cleaner internal link equity distribution, and stronger topical clustering — all of which directly impact rankings.

## Flat Hierarchy

The goal: every important page accessible within 3 clicks from the homepage.

**Why it matters**: Internal links pass PageRank. A page 5 levels deep receives a fraction of the PageRank that a page 2 levels deep receives. Deep pages also get crawled less frequently — Googlebot prioritizes shallower pages.

**Structure targets:**
- Homepage → Category (1 click)
- Category → Subcategory or key pages (2 clicks)
- Subcategory → Individual pages (3 clicks)

Avoid architectures created organically by developers that add levels without considering crawl depth. Date-based blog archives (`/blog/2023/04/article/`) are a common offender — prefer flat `/blog/article/`.

## URL Structure

URLs should reflect hierarchy and be human-readable:
- Good: `/services/oil-change/`, `/blog/how-to-change-oil/`
- Avoid: `/services?service=23`, `/p?id=4512`

**Rules:**
- Lowercase only
- Hyphens as word separators (not underscores — Google treats `_` as a word joiner, not separator)
- Keyword in URL — but don't stuff keywords; one or two is enough
- No dynamic parameters for indexable pages
- Consistent trailing slash — either always `/services/` or always `/services`, but not both

## Internal Linking

Internal links serve two functions: help users navigate and pass PageRank to linked pages.

**Anchor text**
- Descriptive anchor text helps Google understand the topic of the destination page
- "How to change engine oil" beats "click here" or "read more"
- Vary anchor text naturally — exact-match anchors on every internal link look manipulated

**Strategic placement**
- Contextual links (within body copy) pass more value than sidebar/footer links
- Footer links to all major pages are standard but add limited ranking value
- Pillar pages should link to all cluster pages; cluster pages link back to pillar
- New pages need at least 2–3 internal links from existing high-authority pages to be crawled quickly

**Orphan pages**
A page with no internal links pointing to it is an orphan. Googlebot may never find it. Every new page must have at least one internal link from an existing page before publishing.

## Breadcrumb Navigation

Breadcrumbs serve SEO in two ways: they create navigational internal links (Homepage → Category → Page) and they enable BreadcrumbList schema that replaces the URL in SERP with a readable path.

- Implement on every page below the homepage
- Link each breadcrumb level to the actual category/section page
- Add `BreadcrumbList` JSON-LD schema

## Sidebar and Footer Links

- Footer links to all major service/category pages: yes, this is standard and expected
- Footer links to every single page: avoid — dilutes the signal from footer links
- Sidebar links to related articles: good — creates topical associations
- Sidebar links to every category ever: avoid — becomes a de facto link farm

## Architecture During Migrations

Site migrations (URL changes, domain changes, CMS changes) are the most dangerous SEO events. Redirect map is the mitigation:
- 1:1 301 redirects from every old URL to the new equivalent
- No redirect chains (old → interim → new — loses equity at each hop)
- Update internal links to point directly to new URLs (don't rely on redirects internally)
- Update sitemap and submit to GSC immediately after migration
- Monitor GSC Coverage report for 404 spikes for 60 days post-migration

## Key Rules

- Flat architecture (3 clicks max) is the single most impactful architectural decision for large sites
- Never use dynamic parameters in URLs for indexable pages
- Every published page needs at least 2 internal links pointing to it before it will be crawled
- Breadcrumbs are low-effort, high-return — implement site-wide with schema
- Anchor text should describe the destination, not the action ("learn about oil changes" not "click here")
- Migrations require a full redirect map — every URL with any inbound links must have a 301

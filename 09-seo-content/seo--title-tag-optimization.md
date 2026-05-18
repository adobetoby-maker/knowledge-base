# Title Tag Optimization

## What the Title Tag Actually Does

The title tag (`<title>`) is the single most important on-page SEO element. It directly influences: (1) whether Google ranks the page for target queries, (2) whether users click on the result. Google uses it as a primary relevance signal for keyword matching and as the displayed blue link text in results. It is also the default text when pages are bookmarked or shared.

Google rewrites titles it deems poorly representative — long titles, keyword-stuffed titles, or titles that don't match the page content. An optimized title minimizes rewrites and maximizes click-through rate.

## The 50–60 Character Limit

The limit is measured in pixel width (approximately 600px), not characters. "W" is wider than "i." In practice, 50–60 characters covers most combinations of common Latin letters. Monitor titles in Google Search Console → Pages → Title changes to see where Google has rewritten yours.

Truncation in search results means anything after the cutoff is invisible. A truncated title is not a ranking penalty, but it is a CTR problem — a title cut off mid-phrase looks unprofessional and loses the call-to-action.

```
BAD  (68 chars): "Best Auto Repair Shop in Twin Falls Idaho for All Makes and Models"
GOOD (52 chars): "Auto Repair Twin Falls ID | Jr.'s Auto Repair"
```

Measure before publishing: `title.length` is a rough check; use a SERP snippet preview tool (Yoast, Ahrefs, or browser extensions) for pixel-accurate measurement.

## Primary Keyword Near the Front

Eye-tracking studies show users scan the first 2–3 words of a title most heavily. Google also weights early keyword placement slightly higher for relevance matching.

```
BETTER:  "Car AC Repair Twin Falls ID — Affordable Service"
WORSE:   "Affordable Car Service in Twin Falls, Idaho — AC Repair Specialists"
```

Don't force awkward syntax to front-load keywords. Natural-reading titles that happen to start with the keyword outperform keyword-stuffed ones that Google rewrites.

## Brand at the End

Brand name belongs at the end, separated from the main title by a pipe `|` or dash `—`. This preserves keyword density at the front while still identifying the source in branded searches.

```
[Primary keyword phrase] | [Brand Name]
[Primary phrase — Secondary phrase] | [Brand]
```

Exception: homepages. Homepages often lead with the brand name because the homepage is the brand's primary ranking URL: `Brand Name — Tagline or Primary Service`.

## Pipe vs Dash Separator

Pipe `|` and em dash `—` are both acceptable. Pipe is more visually neutral and slightly more common in SERPs. Em dash `—` is slightly warmer in tone. Avoid hyphen `-` as a title separator — it's ambiguous and looks like it's part of a compound word.

## Unique Titles Across All Pages

No two pages should share a title. Duplicate titles tell Google two pages cover the same topic and force it to pick one to rank. In a Next.js site, template-generated titles are the most common source of duplicates:

```typescript
// BAD — generates "Product | Brand" for every product page
title: `${product.name} | Brand`
// But if product.name is empty, all become "| Brand"

// GOOD — validate that the dynamic segment is always populated
export const generateMetadata = ({ params }) => ({
  title: params.productName
    ? `${params.productName} — Buy Online | Brand`
    : 'Products | Brand',  // fallback that's at least unique from product pages
})
```

Run `screaming-frog → exports → Page Titles` and sort by title to find duplicates.

## Title vs H1 Relationship

The title tag and H1 do not need to be identical. The title is optimized for SERP display; the H1 is optimized for on-page reading experience. They should cover the same topic with slight variation:

```
Title: "Auto Repair Twin Falls ID | Jr.'s Auto Repair"
H1:   "Trusted Auto Repair in Twin Falls, Idaho"
```

Google may use either the title or the H1 as the SERP link text depending on which it judges more representative.

## Key Rules

- Keep titles under 60 characters — beyond that, Google may truncate or rewrite; measure with a pixel-accurate preview tool, not just `length`
- Primary keyword belongs in the first 2–3 words of the title — don't bury it after the brand name
- Brand goes at the end, separated by `|` — exception is the homepage where brand leads
- Every page must have a unique title — duplicate titles caused by Next.js templates are the most common technical SEO issue in app-generated content
- Validate title generation in CI: assert that no two generated titles from `generateMetadata` are identical for any populated dataset

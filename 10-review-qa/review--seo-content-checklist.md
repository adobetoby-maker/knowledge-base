# Review: SEO Content Checklist

## Pre-Publish Review

Run this checklist before publishing or updating any article, service page, or location page.

## On-Page SEO

- [ ] **Title tag**: 50–60 characters, includes primary keyword, compelling for clicks
- [ ] **Meta description**: 150–160 characters, includes primary keyword, has a call to action
- [ ] **H1**: Matches or closely paraphrases the title, appears exactly once
- [ ] **H2s**: Each major topic gets an H2; at least 2 H2s for articles over 500 words
- [ ] **Primary keyword in first 100 words**: Keyword appears naturally in the opening paragraph
- [ ] **Keyword density**: Primary keyword appears 3–5 times per 1000 words, secondary keywords 1–2 times
- [ ] **URL slug**: Short (3–5 words), includes primary keyword, hyphen-separated, no stop words

## Content Quality

- [ ] **Answers the search intent**: The page answers what someone searching this keyword actually wants to know
- [ ] **Unique value**: Adds something not on competitor pages (local expertise, more detail, fresher info, original examples)
- [ ] **Word count**: Matches competitor page length ± 20%, or deliberately longer for comprehensive coverage
- [ ] **No filler**: Every paragraph moves the content forward; no padding with synonyms or obvious statements
- [ ] **Correct facts**: Business name, address, phone, hours verified against `lib/shopInfo.ts`
- [ ] **Date updated**: `date` field in `lib/articles.ts` reflects last significant update

## Schema Markup

- [ ] **Article schema**: Long-form content has `Article` or `BlogPosting` schema
- [ ] **FAQ schema**: Pages with Q&A section have `FAQPage` schema (boosts rich results)
- [ ] **HowTo schema**: Step-by-step guides have `HowTo` schema
- [ ] **LocalBusiness schema**: Local service pages reference the business entity
- [ ] **BreadcrumbList**: Multi-level pages have breadcrumb schema

## Technical

- [ ] **Canonical set**: `canonical` URL in metadata matches the page URL exactly (no trailing slash mismatch)
- [ ] **No duplicate content**: This page's content doesn't substantially duplicate another page on the site
- [ ] **Images have alt text**: Every `<Image>` has a descriptive, keyword-containing alt attribute
- [ ] **Images sized correctly**: No oversized images (> 500KB for blog content)
- [ ] **Internal links**: Links to at least 2 related pages on the same site with descriptive anchor text
- [ ] **External links**: Any external links are high-authority sources (not random blogs)

## Local SEO (for jrs-auto-repair, service area pages)

- [ ] **City in title and H1**: Location name appears in the title and main heading
- [ ] **NAP consistent**: Business name, address, phone match `lib/shopInfo.ts` exactly
- [ ] **Surrounding cities mentioned**: At least 3 nearby cities mentioned (Jerome, Kimberly, Filer, Buhl)
- [ ] **LocalBusiness schema includes address**: Complete postal address in schema
- [ ] **Phone is click-to-call**: `href="tel:+12085952101"` on phone number

## In Code (lib/articles.ts)

```ts
// Every article entry must have all required fields:
{
  slug: 'brake-repair-twin-falls-id',        // URL-safe, hyphen-separated
  title: 'Brake Repair in Twin Falls, ID',   // 50-60 chars
  excerpt: 'Full-service brake repair...',   // 150-160 chars, for meta description
  category: 'Brakes',                        // Matches an existing category
  date: '2026-01-15',                        // Date of last significant update
  readTime: '5 min read',                    // Based on word count (200 WPM average)
  body: `...`,                               // Full article content
}
```

Missing or empty `excerpt` means no meta description → Google generates its own (usually worse).

## Post-Publish

- [ ] **Verify in browser**: Page renders correctly, no layout breaks
- [ ] **Check schema**: Google's Rich Results Test passes with no errors
- [ ] **Sitemap updated**: New pages appear in `/sitemap.xml`
- [ ] **Google Search Console**: No crawl errors for the new page after 1–3 days

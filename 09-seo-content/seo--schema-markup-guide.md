# SEO: Schema Markup Guide

## Overview
Schema markup (structured data) gives search engines an unambiguous machine-readable interpretation of page content. Without it, Google must infer what a page is about from text. With it, Google can generate rich results — visual enhancements in SERPs that increase click-through rates significantly (FAQ accordions, star ratings, breadcrumbs, event dates). Schema is not optional for competitive niches.

## Format Recommendation

**JSON-LD is preferred** (Google's recommended format) over Microdata or RDFa because:
- Lives in `<script>` tag — doesn't require modifying HTML structure
- Easier to maintain and debug
- Supports multiple schema types on one page
- Not affected by HTML changes

Place JSON-LD in the `<head>` or at the end of `<body>`. Both work.

## Common Schema Types

### Article
For blog posts, news articles, how-to content:
```json
{ "@type": "Article", "headline": "...", "author": {"@type": "Person", "name": "..."}, "datePublished": "2025-01-01", "image": "..." }
```
Required for Top Stories carousel eligibility.

### FAQPage
For pages with question-answer format — enables accordion rich result in SERP:
```json
{ "@type": "FAQPage", "mainEntity": [{ "@type": "Question", "name": "Q?", "acceptedAnswer": {"@type": "Answer", "text": "A"} }] }
```
Important: FAQ schema has been de-emphasized for most sites since late 2023 — Google limits it to authoritative health and government sources for many queries, but it still triggers for many others.

### HowTo
Step-by-step processes — enables numbered steps in SERP:
```json
{ "@type": "HowTo", "name": "...", "step": [{"@type": "HowToStep", "name": "...", "text": "..."}] }
```

### Product + Offer + AggregateRating
E-commerce product pages — enables price, availability, star rating in SERP. Price must match on-page price.

### LocalBusiness
Homepage / contact page for local businesses. Use the most specific subtype (AutoRepair, Restaurant, etc.).

### BreadcrumbList
Replaces URL in SERP with readable breadcrumb path. Add to every page:
```json
{ "@type": "BreadcrumbList", "itemListElement": [{"@type": "ListItem", "position": 1, "name": "Home", "item": "https://..."}, ...] }
```

### Organization / Person
Homepage / about page. Establishes entity identity — links to social profiles, logo, contact info.

### SiteLinksSearchBox
Homepage schema that enables Google's sitelinks search box for branded queries.

## Validation

1. **Google Rich Results Test** (search.google.com/test/rich-results): checks eligibility for rich results and shows parsing errors
2. **Schema Markup Validator** (validator.schema.org): validates schema.org compliance
3. Both before deployment — schema errors are silent (page loads fine, rich results just don't appear)

## Mismatches = Manual Action Risk

Google's policy: schema content must match visible page content. Violations:
- Price in schema differs from price on page
- Review count in schema differs from visible review count
- Schema on pages where described content doesn't exist

These trigger "Spammy Structured Markup" manual actions — remove ranking for rich results.

## Multiple Schema Types on One Page

A page can have multiple JSON-LD blocks or one block with `@graph`:
```json
{ "@graph": [ { "@type": "Article", ... }, { "@type": "BreadcrumbList", ... } ] }
```

## Key Rules

- Always test with Rich Results Test before deploying — invalid JSON silently fails
- Schema content must exactly match visible page content (price, reviews, dates)
- BreadcrumbList on every page — minimal effort, consistent SERP improvement
- Use `@id` to link related entities across multiple schema objects
- Don't add schema to noindex pages — it's processed but not rewarded
- Check GSC Enhancements reports for schema errors after deployment

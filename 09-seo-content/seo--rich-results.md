# Schema Markup for Rich Results

Rich results are enhanced SERP features — star ratings, FAQ dropdowns, product pricing, recipe details — triggered by structured data on the page. They improve click-through rate significantly (often 20–30% CTR lift) because they make your result visually distinct and answer-complete before the click.

## Schema Types That Generate Rich Results

Not all schema types qualify for rich results in Google. Focus on types with documented rich result eligibility:

- **Article**: for news and blog posts. Enables Article rich result, sitelinks, and AI-powered snippet extraction. Required fields: `headline`, `datePublished`, `author`, `image`.
- **Product**: for e-commerce product pages. Enables price, availability, and review stars. Required: `name`, `image`. Strongly recommended: `offers` (price, currency, availability), `aggregateRating`.
- **FAQ**: for FAQ sections on any page. Shows expandable Q&A directly in the SERP. Required: `mainEntity` array of `Question` + `acceptedAnswer` pairs.
- **HowTo**: for step-by-step instruction pages. Shows numbered steps in the result. Required: `name`, `step` array with `text` per step.
- **LocalBusiness**: for business location pages. Enables Knowledge Panel data: address, phone, hours, rating. Required: `name`, `address`, `telephone`. Strongly recommended: `openingHoursSpecification`, `geo`, `aggregateRating`.

## Implementation: JSON-LD

Use JSON-LD format (a `<script type="application/ld+json">` block) rather than Microdata or RDFa. JSON-LD is:
- Separated from HTML — easier to update without touching visible content.
- Preferred by Google (explicitly stated in their guidelines).
- Easier to generate dynamically in server-side rendering.

Place the JSON-LD block in the `<head>` or anywhere in the `<body>`. Multiple JSON-LD blocks on one page are valid.

## Testing with Rich Results Test

Use [Google's Rich Results Test](https://search.google.com/test/rich-results) (search.google.com/test/rich-results) before deploying schema:
1. Paste the URL or code snippet.
2. The tool shows which rich result types are detected and any errors or warnings.
3. Errors prevent rich results from appearing; warnings are advisory but fix them anyway.

Run the test after every schema change. Also check Search Console's Enhancements report after deployment — it aggregates rich result status across all pages.

## Content Matching Rule

The most important rule: schema markup must match visible on-page content. If your `Product` schema shows `price: 29.99` but the page displays "Call for pricing," Google will:
- Demote the page's rich result eligibility.
- Potentially issue a manual action for misleading structured data.

The same applies to review counts, FAQ answers, and HowTo steps. Schema is not a layer for adding information Google can't see — it's a machine-readable label for information that is already visible.

## Key Rules

- Use JSON-LD; avoid Microdata and RDFa for new implementations.
- Test every schema implementation with Google's Rich Results Test before deploying.
- Schema content must match visible page content exactly — never use schema to display different data than what's on the page.
- `aggregateRating` in Product and LocalBusiness schema must reflect real user reviews, not fabricated scores.
- FAQ schema should only be applied to pages where the Q&A content exists on the page — don't hide FAQs with CSS and markup them anyway.
- Check the Search Console Enhancements report post-deployment for scale validation.

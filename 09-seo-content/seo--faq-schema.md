# FAQ Rich Results Implementation

FAQ schema can unlock a rich result in Google Search that expands to show questions and answers directly in the SERP. This makes your listing taller, more visible, and can dramatically increase click-through rate — especially for navigational and informational queries. But it's frequently misimplemented, causing Google to ignore the markup entirely.

## FAQPage Schema Structure

Use `FAQPage` with nested `Question` and `Answer` entities:

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "What are your hours?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "We're open Monday through Saturday, 9AM to 5PM."
      }
    }
  ]
}
```

Place this in a `<script type="application/ld+json">` block in the `<head>` or at the bottom of `<body>`. Don't use microdata or RDFa — JSON-LD is unambiguously preferred by Google and easier to maintain.

## The Content Must Match What's Visible on the Page

This is the requirement most sites violate: every question and answer in the schema must also appear visibly on the page as rendered HTML. Google crawls both the schema and the visible content and rejects rich results when they diverge.

"Visible" means the text is in the DOM and not hidden via `display:none` or `visibility:hidden`. Accordion/expandable FAQ components are fine — the content exists in the DOM even when collapsed. But if you put five Q&As in the schema and only three appear anywhere in the page's HTML, Google will drop the rich result.

Practically: generate the schema programmatically from the same data source that renders the visible FAQ, rather than maintaining them separately. Divergence is a maintenance problem, not just a technical one.

## Maximum 10 Q&As for Rich Results

Google displays at most 3 Q&As in the rich result preview, with a "Show more" link to expand to around 10. Beyond 10 Q&As, the additional ones are ignored for display purposes. Focus on the 5–8 most impactful questions: the ones users search directly, the ones that address purchase hesitation, and the ones that match long-tail query patterns for your topic.

More Q&As is not better. Diluted, generic questions waste markup and can push more valuable content lower in the structured data.

## FAQ Schema vs HowTo Schema

Use `FAQPage` when: the page presents discrete Q&A pairs where each answer is standalone. Typical uses: product pages, service pages, support/knowledge base articles.

Use `HowTo` schema when: the content describes a sequential process with defined steps toward a goal. Typical uses: tutorials, recipes, repair guides, installation instructions.

Don't use both on the same page. If a page mixes how-to steps and standalone FAQs, choose the schema type that reflects the primary purpose of the content.

## When FAQ Schema Stops Working

Google periodically restricts FAQ rich results for specific site categories or at scale. Sites producing FAQ-stuffed programmatic pages at high volume have seen rich result eligibility stripped. Quality signals matter: pages need topical authority, sufficient non-FAQ content, and genuine E-E-A-T signals. FAQ schema on a thin page with 50 words of body text will not earn rich results regardless of how clean the schema is.

## Key Rules

- Every question and answer in the schema must appear as visible HTML on the page
- Generate schema from the same data source as the visible FAQ — never maintain separately
- Cap at 10 Q&As per page; 5–8 is optimal
- Use `FAQPage` for standalone Q&A pairs; use `HowTo` for sequential processes — not both
- Validate with Google's Rich Results Test before publishing
- FAQ schema on thin pages earns nothing — the page needs genuine topical depth first

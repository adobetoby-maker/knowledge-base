# Meta Description Best Practices

## The Ranking Misconception

Meta descriptions do not directly affect Google search rankings. Google explicitly confirmed this in 2009 and has restated it since. Writing meta descriptions to "rank for keywords" misunderstands their purpose. They exist to improve **click-through rate (CTR)** — which *does* indirectly influence rankings through engagement signals.

If users search for a query and your result has a meta description that clearly answers their question, they click. High CTR on a result tells Google it's satisfying the query, which reinforces and improves ranking position over time. Poor CTR on a high-ranking result is one reason rankings drift down.

## The 150–160 Character Sweet Spot

Google truncates descriptions at approximately 920 pixels (rough equivalent: 155–165 characters in mixed case). Descriptions that fall short miss the opportunity to fill the space; descriptions that run long get cut off mid-sentence.

Target 150–160 characters for every description. This is non-negotiable for important landing pages. Blog posts with unique descriptions are better than auto-generated ones, even if auto-generated ones fill the space.

```
GOOD (153 chars):
"Jr.'s Auto Repair in Twin Falls, ID offers honest auto repair with fair prices.
Oil changes, brakes, AC, and more. Serving Magic Valley since 2011. Call today."

BAD (too long, truncated at 160):
"Jr.'s Auto Repair in Twin Falls, ID offers the most trusted and reliable auto repair services in the area. We do oil changes, brake repairs, air conditioning, engine diagnostics, and more..."
```

## Active Voice with a CTA

Meta descriptions that end with a call to action outperform passive descriptions. Users scanning SERPs respond to instructions.

```
"Call today for same-day service."
"Get a free estimate in minutes."
"Book your appointment online — no waiting."
```

The CTA doesn't need to be aggressive. Even "Learn more" outperforms a sentence that just trails off. Active voice throughout: "We fix" not "Repairs are done," "Schedule" not "Scheduling is available."

## Including the Primary Keyword Naturally

Google **bolds** words in the meta description that match the user's search query. This bold text makes your result visually stand out in the SERP, increasing CTR. Include the primary keyword once, naturally — not forced.

```
Query: "auto repair Twin Falls"
Description bolding: "...trusted **auto repair in Twin Falls**, ID with fair prices..."
```

Don't repeat the keyword multiple times — it looks like spam and Google may rewrite the description with content from the page body instead.

## The Uniqueness Requirement

Every page needs a unique meta description. Pages with identical descriptions are treated the same as pages with no description — Google will extract a passage from the page content instead. Auto-generated descriptions using a template (e.g., `Page about ${topic}`) are counted as duplicates if the template produces similar output across many pages.

For programmatically generated pages (service pages, location pages), use a template that incorporates unique variables:

```typescript
// Unique per page because city, service, and brand differentiate each
description: `${service} in ${city}, ID from ${brandName}. Local, licensed, and trusted. Call for same-day service.`
```

## When Google Ignores Your Description

Google rewrites meta descriptions frequently — studies suggest 70%+ of descriptions shown in SERPs are rewritten from page content. This happens when:
- The description doesn't match the search query's intent
- The description is too short or too long
- A passage from the page body is more relevant to the specific query

This is not a reason to skip writing descriptions. A well-written description that matches the page's primary intent will be used for that query. Google rewrites for variant queries — a description targeting "auto repair Twin Falls" may be rewritten when someone searches "Twin Falls mechanic Saturday hours."

## Key Rules

- Meta descriptions do not affect rankings directly — optimize them for CTR, not keyword density
- Target 150–160 characters — not shorter (wastes space), not longer (gets truncated)
- End with an active-voice CTA — "Call today," "Get a quote," "Book online" outperform trailing sentences
- Include the primary keyword once, naturally — Google bolds query matches in the snippet, improving visual prominence
- Every page needs a unique description — auto-generated templates must use enough page-specific variables to avoid producing near-identical output

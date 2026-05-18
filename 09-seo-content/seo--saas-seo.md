# SEO: SaaS SEO

## Overview

SaaS SEO focuses on three main areas: comparison pages (capturing high-intent "X vs Y" searches), integration pages (capturing "X for Slack/Salesforce" searches), and use-case landing pages. These generate qualified traffic that converts better than generic feature pages because searchers already know they have a problem.

## Comparison Pages

"[Product] vs [Competitor]" pages capture high-intent searches. Users searching these terms are in the evaluation phase.

```tsx
// /compare/[slug] — e.g., /compare/product-vs-competitor

interface ComparisonPage {
  competitor: {
    name: string
    logo: string
    pricing: string
    strengths: string[]
    weaknesses: string[]
  }
  differences: {
    feature: string
    us: boolean | string
    them: boolean | string
  }[]
  switchingCTA: string
}

export async function generateMetadata({ params }: { params: { slug: string } }) {
  const competitor = getCompetitorFromSlug(params.slug)
  return {
    title: `${OUR_PRODUCT} vs ${competitor.name} — Full Comparison ${new Date().getFullYear()}`,
    description: `See how ${OUR_PRODUCT} compares to ${competitor.name} in features, pricing, and ease of use. Updated ${new Date().toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}.`,
  }
}
```

Include the year in the title — "X vs Y 2026" gets more clicks than "X vs Y" because it signals freshness.

## Integration Pages

Integration pages capture users searching for your product in the context of tools they already use.

```tsx
// /integrations/[tool] — e.g., /integrations/slack, /integrations/salesforce

export function IntegrationPage({ integration }: { integration: Integration }) {
  return (
    <>
      <h1>{OUR_PRODUCT} + {integration.name} Integration</h1>
      <p>Connect {OUR_PRODUCT} with {integration.name} to {integration.primaryBenefit}.</p>

      {/* Schema: SoftwareApplication with integration mention */}
      {/* Key sections: */}
      {/* 1. What it does (above fold) */}
      {/* 2. Setup steps (numbered list — targets featured snippets) */}
      {/* 3. Use cases (targets "how to use X for Y" searches) */}
      {/* 4. FAQ */}
    </>
  )
}
```

Each integration page should be substantive (~800 words minimum) — thin pages with just a logo and "connect now" get deindexed.

## Use Case Pages

```tsx
// /use-cases/[industry] — /use-cases/healthcare, /use-cases/marketing-agencies

export function UseCasePage({ useCase }: { useCase: UseCase }) {
  return (
    <>
      <h1>{OUR_PRODUCT} for {useCase.industry}</h1>

      {/* Specific pain points for this industry */}
      {useCase.painPoints.map(pain => (
        <section key={pain.title}>
          <h2>{pain.title}</h2>
          <p>{pain.description}</p>
          <p>With {OUR_PRODUCT}: {pain.solution}</p>
        </section>
      ))}

      {/* Customer quote from this industry */}
      <blockquote>
        <p>{useCase.testimonial.quote}</p>
        <cite>{useCase.testimonial.name}, {useCase.testimonial.company}</cite>
      </blockquote>

      {/* Metrics / ROI specific to this industry */}
    </>
  )
}
```

## Landing Pages for Feature Keywords

```tsx
// /features/[feature] — captures "[Product] [feature]" searches
// e.g., /features/bulk-export, /features/api-access

export function FeaturePage({ feature }: { feature: Feature }) {
  return (
    <>
      <title>{feature.name} — {OUR_PRODUCT}</title>
      <h1>{feature.headline}</h1>  {/* Target the exact search query */}

      {/* Feature demo — video or interactive */}
      {/* How it works — numbered steps */}
      {/* Common use cases */}
      {/* Related features */}
    </>
  )
}
```

## Blog Strategy for SaaS

```
Keyword clusters that work for SaaS:

1. Problem-aware keywords
   "how to [solve problem your product solves]"
   "best way to [workflow your product automates]"

2. Solution-aware keywords
   "[category] software for [use case]"
   "best [category] tools"

3. Job-to-be-done keywords
   "how to reduce [business metric]"
   "[process] automation software"

4. Competitor keywords
   "[Competitor] alternative"
   "[Competitor] pricing"
   "[Competitor] reviews"
```

## SaaS-Specific Schema

```ts
function buildSoftwareApplicationSchema(): object {
  return {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: OUR_PRODUCT,
    applicationCategory: 'BusinessApplication',
    operatingSystem: 'Web',
    offers: {
      '@type': 'Offer',
      price: '0',                    // Free tier
      priceCurrency: 'USD',
      priceValidUntil: '2027-01-01',
    },
    aggregateRating: {
      '@type': 'AggregateRating',
      ratingValue: '4.7',
      reviewCount: '842',
    },
  }
}
```

## Key Rules

- Comparison pages must be fair — ranking "X vs Y" with only negative things about Y gets penalized for low quality. Acknowledge competitor strengths.
- Update comparison pages when competitor pricing or features change — stale comparisons lose trust and rankings.
- Integration pages need real content (setup steps, use cases) — not just a logo grid.
- Use case pages convert better than feature pages because they speak the customer's language ("for marketing agencies" vs "reporting").
- G2/Capterra/Trustpilot links build the trust signals Google uses to rank SaaS products — encourage reviews early.

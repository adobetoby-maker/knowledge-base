# SEO: Structured Data Types

## Overview

Schema.org structured data tells Google what your content means, enabling rich results (stars, FAQs, breadcrumbs, events, products). Each schema type unlocks different SERP features.

## Adding Schema in Next.js

The recommended pattern for schema markup in Next.js is to use `generateMetadata` or a dedicated server component that injects the JSON-LD script tag. The schema data is built from static/validated data in your codebase, never from raw user input.

```tsx
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }: Props) {
  const post = await getPost(params.slug)
  return {
    // Other metadata...
  }
}

// Inline schema in the page component (server component)
export default async function BlogPostPage({ params }: Props) {
  const post = await getPost(params.slug)
  const schema = buildArticleSchema(post)

  return (
    <>
      {/* Schema script — data is from your own validated data model */}
      <script type="application/ld+json">
        {JSON.stringify(schema)}
      </script>
      <article>{/* ... */}</article>
    </>
  )
}
```

## LocalBusiness Schema

For any physical business location — enables map pack appearance and rich results:

```ts
const localBusinessSchema = {
  '@context': 'https://schema.org',
  '@type': 'AutoRepair',
  name: "JR's Auto Repair",
  url: 'https://jrs.worker-bee.app',
  telephone: '(208) 595-2101',
  address: {
    '@type': 'PostalAddress',
    streetAddress: '417 Main Ave E',
    addressLocality: 'Twin Falls',
    addressRegion: 'ID',
    postalCode: '83301',
    addressCountry: 'US',
  },
  geo: {
    '@type': 'GeoCoordinates',
    latitude: 42.5629,
    longitude: -114.4609,
  },
  openingHoursSpecification: [
    {
      '@type': 'OpeningHoursSpecification',
      dayOfWeek: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      opens: '09:00',
      closes: '17:00',
    },
  ],
  aggregateRating: {
    '@type': 'AggregateRating',
    ratingValue: '4.8',
    reviewCount: '146',
  },
  priceRange: '$$',
}
```

## Article Schema (Blog Posts)

```ts
function buildArticleSchema(post: BlogPost) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: post.title,
    description: post.excerpt,
    datePublished: post.date,
    dateModified: post.updatedAt ?? post.date,
    author: {
      '@type': 'Person',
      name: post.author ?? "JR's Auto Repair Team",
    },
    publisher: {
      '@type': 'Organization',
      name: "JR's Auto Repair",
    },
    image: post.imageUrl ?? 'https://jrs.worker-bee.app/og-default.jpg',
  }
}
```

## FAQ Schema

Adds expandable Q&A sections directly in search results:

```ts
function buildFaqSchema(items: Array<{ question: string; answer: string }>) {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: items.map((item) => ({
      '@type': 'Question',
      name: item.question,
      acceptedAnswer: { '@type': 'Answer', text: item.answer },
    })),
  }
}
```

FAQ schema requires the questions and answers to be visibly present on the page. Hidden content violates Google's guidelines.

## BreadcrumbList Schema

```ts
function buildBreadcrumbSchema(crumbs: Array<{ name: string; url: string }>) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: crumbs.map((crumb, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: crumb.name,
      item: crumb.url,
    })),
  }
}
```

## Product Schema

```ts
function buildProductSchema(product: Product) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: product.name,
    description: product.description,
    offers: {
      '@type': 'Offer',
      price: (product.priceCents / 100).toFixed(2),
      priceCurrency: 'USD',
      availability: product.inStock
        ? 'https://schema.org/InStock'
        : 'https://schema.org/OutOfStock',
    },
    aggregateRating: product.reviewCount > 0 ? {
      '@type': 'AggregateRating',
      ratingValue: product.avgRating.toFixed(1),
      reviewCount: String(product.reviewCount),
    } : undefined,
  }
}
```

## HowTo Schema

For step-by-step instructional content:

```ts
function buildHowToSchema(name: string, steps: string[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'HowTo',
    name,
    step: steps.map((text, i) => ({
      '@type': 'HowToStep',
      position: i + 1,
      text,
    })),
  }
}
```

## Validation

Test all structured data with:
1. Google's Rich Results Test: `search "Google Rich Results Test"`
2. Schema.org Validator: validator.schema.org

Common errors:
- Missing required fields (rating requires reviewCount)
- Content mismatch (FAQ answers not visible on page)
- Invalid date format (must be ISO 8601: `2026-05-18`)
- Price without currency
- Number values passed as numbers where string is required (reviewCount must be `"146"` not `146` in some validators)

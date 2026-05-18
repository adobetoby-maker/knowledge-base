# SEO: Structured Data (JSON-LD)

## Overview

Structured data tells search engines what your content means, not just what it says. Correctly implemented structured data unlocks rich results: star ratings in SERPs, FAQ dropdowns, breadcrumbs, product prices, event dates. Implement as JSON-LD in a `<script>` tag — Google's preferred method, works with SSR, and doesn't affect page layout.

## Implementation (Next.js)

JSON-LD requires injecting a `<script type="application/ld+json">` tag. In React this is the one case where setting inner HTML is required and safe — the content is server-generated JSON, never user input. Always use `JSON.stringify` on a controlled plain object, never concatenate user data into the string.

```tsx
// app/blog/[slug]/page.tsx
export default async function BlogPost({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug)
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: post.title,          // Always from DB, not URL params
    description: post.excerpt,
    datePublished: post.publishedAt,
    dateModified: post.updatedAt,
    author: {
      '@type': 'Person',
      name: post.authorName,
    },
  }

  // JSON.stringify on a plain object — safe, no user-controlled HTML
  const scriptContent = JSON.stringify(jsonLd)

  return (
    <>
      <script
        type="application/ld+json"
        suppressHydrationWarning
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{ __html: scriptContent }}
      />
      <article>
        <h1>{post.title}</h1>
      </article>
    </>
  )
}
```

**Security note:** `JSON.stringify` on an object that contains only server-controlled values (never raw user input) is safe here — it produces valid JSON, not executable HTML. Never interpolate user-supplied strings directly into the JSON-LD template.

## Product Schema

```ts
const productSchema = {
  '@context': 'https://schema.org',
  '@type': 'Product',
  name: product.name,
  description: product.description,
  sku: product.sku,
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
    reviewCount: product.reviewCount,
  } : undefined,
}
```

## FAQ Schema

```ts
const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: faqs.map(faq => ({
    '@type': 'Question',
    name: faq.question,
    acceptedAnswer: { '@type': 'Answer', text: faq.answer },
  })),
}
```

## Local Business Schema

```ts
const localBusinessSchema = {
  '@context': 'https://schema.org',
  '@type': 'AutoRepair',  // More specific than LocalBusiness
  name: 'Jr\'s Auto Repair',
  address: {
    '@type': 'PostalAddress',
    streetAddress: '417 Main Ave E',
    addressLocality: 'Twin Falls',
    addressRegion: 'ID',
    postalCode: '83301',
    addressCountry: 'US',
  },
  telephone: '+1-208-595-2101',
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
}
```

## Breadcrumbs Schema

```ts
const breadcrumbSchema = {
  '@context': 'https://schema.org',
  '@type': 'BreadcrumbList',
  itemListElement: [
    { '@type': 'ListItem', position: 1, name: 'Home', item: baseUrl },
    { '@type': 'ListItem', position: 2, name: 'Blog', item: `${baseUrl}/blog` },
    { '@type': 'ListItem', position: 3, name: post.title },
  ],
}
```

## Multiple Schemas

```ts
// Array of schemas in one script tag
const schemas = [productSchema, breadcrumbSchema]
const scriptContent = JSON.stringify(schemas)
```

## Validation

```
Google Rich Results Test: https://search.google.com/test/rich-results
Schema.org Validator: https://validator.schema.org/
```

## Key Rules

- `suppressHydrationWarning` prevents React hydration mismatch warnings from whitespace differences in `JSON.stringify`.
- Only include `aggregateRating` with real reviews — fabricated ratings earn manual penalties.
- Schema content must match visible page content — data not present on the page is treated as spam.
- Use the most specific type available (`AutoRepair` over `LocalBusiness`, `Article` over `CreativeWork`).
- Never inject user-provided content directly into JSON-LD — always use server-controlled DB values processed through `JSON.stringify`.

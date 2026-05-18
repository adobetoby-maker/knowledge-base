# SEO: Schema Markup (Structured Data)

**When:** Adding machine-readable context to pages. Enables rich results in Google: star ratings, FAQ dropdowns, business info, breadcrumbs.
**Rule:** Schema doesn't directly boost rankings but unlocks rich results that increase click-through rates. Use JSON-LD in a `<script>` tag — never RDFa or Microdata.

## Implementation — JSON-LD in Next.js
The `JSON.stringify()` of a plain object literal is safe — no user input in the schema.
```typescript
// Add to page component
export default function ServicePage() {
  const schema = {
    "@context": "https://schema.org",
    "@type": "LocalBusiness",
    // ... schema data (never interpolate user input here)
  }
  
  return (
    <>
      <script type="application/ld+json">
        {JSON.stringify(schema)}
      </script>
      {/* page content */}
    </>
  )
}
```

## LocalBusiness Schema (JRS Auto Repair)
```json
{
  "@context": "https://schema.org",
  "@type": "AutoRepair",
  "name": "Jr.'s Auto Repair",
  "image": "https://jrsautorepair.worker-bee.app/og-image.jpg",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "417 Main Ave E",
    "addressLocality": "Twin Falls",
    "addressRegion": "ID",
    "postalCode": "83301",
    "addressCountry": "US"
  },
  "geo": {
    "@type": "GeoCoordinates",
    "latitude": 42.5571,
    "longitude": -114.4609
  },
  "telephone": "+12085952101",
  "openingHoursSpecification": [
    {
      "@type": "OpeningHoursSpecification",
      "dayOfWeek": ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"],
      "opens": "09:00",
      "closes": "17:00"
    }
  ],
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.8",
    "reviewCount": "146"
  },
  "priceRange": "$$"
}
```

## FAQ Schema (Enables FAQ rich results in Google)
```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "How much does an oil change cost in Twin Falls?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "At Jr.'s Auto Repair, conventional oil changes start at $39.99. Synthetic oil changes start at $59.99. We serve Twin Falls and the Magic Valley area."
      }
    },
    {
      "@type": "Question",
      "name": "Do I need an appointment for an oil change?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Walk-ins are welcome. You can also call (208) 595-2101 or book online to guarantee your spot."
      }
    }
  ]
}
```

## Article Schema (for blog posts)
```json
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "How to Know When to Replace Your Brakes",
  "author": {
    "@type": "Organization",
    "name": "Jr.'s Auto Repair"
  },
  "publisher": {
    "@type": "Organization",
    "name": "Jr.'s Auto Repair",
    "logo": {
      "@type": "ImageObject",
      "url": "https://jrsautorepair.worker-bee.app/logo.png"
    }
  },
  "datePublished": "2026-05-18",
  "dateModified": "2026-05-18"
}
```

## Breadcrumb Schema
```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Home", "item": "https://jrsautorepair.worker-bee.app" },
    { "@type": "ListItem", "position": 2, "name": "Services", "item": "https://jrsautorepair.worker-bee.app/services" },
    { "@type": "ListItem", "position": 3, "name": "Brake Repair" }
  ]
}
```

## Validation
Test schema at: https://search.google.com/test/rich-results
After deployment: check Google Search Console → Rich Results status.

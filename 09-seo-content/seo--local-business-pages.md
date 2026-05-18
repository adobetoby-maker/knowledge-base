# SEO: Local Business Pages

## What This Solves

Local businesses rank for geographic searches like "auto repair twin falls id" or "mechanic near me." Local SEO requires specific patterns: LocalBusiness schema, Google Business Profile signals, city/neighborhood pages, and NAP consistency (Name, Address, Phone).

## LocalBusiness Schema (Essential)

Every local business page must have this schema. Inconsistency in NAP across schema and Google Business Profile causes ranking problems.

```ts
// lib/localBusinessSchema.ts
export const LOCAL_BUSINESS_SCHEMA = {
  '@context': 'https://schema.org',
  '@type': 'AutoRepair',          // Use specific type: AutoRepair, Restaurant, MedicalBusiness, etc.
  name: "JR's Auto Repair",
  url: 'https://jrsautorepair.com',
  telephone: '+12085952101',      // E.164 format
  priceRange: '$$',
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
    bestRating: '5',
  },
}
```

Place this in the root layout's `<head>` for maximum coverage, or on the homepage.

## NAP Consistency Rule

Name, Address, Phone must be IDENTICAL across:
- Schema markup
- Page text
- Google Business Profile
- Yelp, Bing Places, Apple Maps
- Any citation directories

Even small differences ("JR's Auto Repair" vs "JRs Auto Repair" vs "JR Auto Repair") create conflicting signals. Pick one format and use it everywhere.

## City/Service Page Structure

For "auto repair Twin Falls ID" type searches:

```
/services/oil-change-twin-falls-id
/services/brake-repair-twin-falls
/services/transmission-repair-magic-valley
```

Page template:
```tsx
export function ServiceCityPage({ service, city }: { service: string; city: string }) {
  return (
    <>
      <h1>{service} in {city}, ID — JR's Auto Repair</h1>

      {/* Above fold: key info */}
      <div className="flex gap-4">
        <address>417 Main Ave E, {city}, ID 83301</address>
        <a href="tel:+12085952101">(208) 595-2101</a>
      </div>

      {/* Service description with local signals */}
      <p>
        JR's Auto Repair has provided {service.toLowerCase()} to {city} and
        Magic Valley drivers for over 13 years. Located on Main Ave E,
        we serve customers from Jerome, Kimberly, and throughout Twin Falls County.
      </p>

      {/* FAQ with local intent */}
      <FaqWithSchema items={localFaqs} />
    </>
  )
}
```

## "Near Me" Targeting

"Near me" searches are localized by Google — you don't need to literally write "near me" in content. Instead, signal proximity through:
- Neighborhood names
- Nearby landmarks: "across from the Twin Falls Public Library"
- County and region names: "Magic Valley", "Twin Falls County"
- Surrounding cities: "serving Jerome, Kimberly, Filer, Buhl"

## Google Business Profile Signals

These factors influence local pack rankings (the map results):
1. **Proximity** to searcher — you can't control this
2. **Relevance** — keywords in GBP description, correct category
3. **Prominence** — review count, review score, citation volume

The highest-ROI action: respond to every Google review within 24 hours. This signals active management and improves prominence.

## Review Schema Page

A dedicated reviews page or section with individual review schema:
```ts
const reviewSchema = {
  '@context': 'https://schema.org',
  '@type': 'Review',
  author: { '@type': 'Person', name: 'Sarah M.' },
  reviewBody: 'Excellent service, fast turnaround, fair pricing.',
  reviewRating: {
    '@type': 'Rating',
    ratingValue: '5',
    bestRating: '5',
  },
  datePublished: '2025-11-15',
  itemReviewed: {
    '@type': 'LocalBusiness',
    name: "JR's Auto Repair",
  },
}
```

## Surrounding City Pages

Create lightweight pages for nearby cities if you serve them:
```
/service-area/jerome-id
/service-area/kimberly-id
/service-area/filer-id
```

Each page: mention the city 3–5 times naturally, include the drive distance, link to relevant services. Don't create these as thin pages — they need at least 300 words of genuine information.

## Hreflang for Multi-Location

If the same business has multiple locations, create a page per location with unique schema and unique content. Canonicalize each to its own URL — never canonical one location page to another.

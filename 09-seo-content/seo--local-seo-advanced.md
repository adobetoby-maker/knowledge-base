# Local SEO Technical Implementation

## Why Local SEO Is a Distinct Technical Domain

Local SEO is not just "national SEO + city name." Google's local ranking algorithm uses proximity, relevance, and prominence signals that differ fundamentally from organic ranking. A technically correct local implementation affects Google Maps pack rankings, local organic rankings, and voice search results. The technical gaps in most local SEO implementations are in structured data, NAP consistency, and GBP optimization — not content quality.

## NAP Consistency

NAP (Name, Address, Phone) must be character-for-character identical across all citation sources: website, Google Business Profile, Yelp, Facebook, Apple Maps, industry directories, and data aggregators (Neustar Localeze, Data Axle, Foursquare).

Common inconsistency causes:
- "St" vs "Street" vs "St." in the address
- "(208) 595-2101" vs "208-595-2101" vs "2085952101"
- "Jr.'s Auto Repair" vs "Jr.s Auto Repair" vs "Jrs Auto Repair"
- Suite number sometimes included, sometimes omitted

Pick one canonical format and audit every citation source. Tools: BrightLocal Citation Tracker, Whitespark, or manual search `site:yelp.com "business name"`.

Never have two different phone numbers on different platforms — Google's entity resolution treats conflicting NAP as low-quality signals.

## LocalBusiness Structured Data

Implement `LocalBusiness` schema (or its specific subtype) with complete data:

```json
{
  "@context": "https://schema.org",
  "@type": "AutoRepair",
  "name": "Jr.'s Auto Repair",
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
    "latitude": 42.5630,
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
  "priceRange": "$$",
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.8",
    "reviewCount": "146"
  }
}
```

Use the most specific `@type` available (`AutoRepair` > `LocalBusiness`). Include `geo` coordinates — they directly tie your schema to a map point. Include hours in `openingHoursSpecification` format, not the deprecated `openingHours` string array.

Validate with Google's Rich Results Test and Schema.org's validator before deploying.

## Google Business Profile API

The GBP API (`mybusiness.googleapis.com`) enables programmatic updates for multi-location businesses:
- Update hours for holidays/special events
- Post updates and offers
- Respond to reviews
- Sync attribute changes (accepts credit cards, wheelchair accessible)

For single-location businesses, direct GBP dashboard management is simpler. The API is essential at 10+ locations where manual updates become error-prone.

Keep GBP data synchronized with your website — mismatched hours between GBP and website schema are a consistency signal Google uses to assess trustworthiness.

## Review Schema

`aggregateRating` in your `LocalBusiness` schema can generate star ratings in local search results. Rules:
- Only mark up reviews from your own website (where the review content lives). Do not mark up third-party reviews (Yelp, Google) in your schema — this violates Google's guidelines.
- Keep `reviewCount` synchronized with actual count. Stale counts (schema says 50 reviews, site shows 146) trigger manual review.
- If you embed Google reviews on your site via API, do not add schema markup to them.

## Service Area Pages vs Location Pages

**Location pages** (a physical office or store exists): Full `LocalBusiness` schema, NAP, hours. One page per physical location.

**Service area pages** (you serve a region but don't have an office there): No physical address in schema. Use `ServiceArea` + `areaServed` in the schema, not `address`. Content should include genuine local relevance — neighborhood knowledge, local projects, local testimonials — not just a city name.

Don't create location pages for cities where you have no physical presence — Google treats them as spam. Service area pages are the correct pattern for service businesses that travel to customers.

## Key Rules

- NAP must be character-for-character identical across all citation sources; audit every major directory annually.
- Use the most specific LocalBusiness subtype available; include `geo` coordinates and `openingHoursSpecification`.
- Only mark up reviews that live on your own website; never mark up embedded third-party reviews.
- Sync GBP hours with website schema; mismatches reduce local trustworthiness signals.
- Use service area pages (not location pages) for cities where no physical location exists.
- Validate structured data with Google's Rich Results Test before deploying; schema errors that don't surface in validation still fail silently in indexing.

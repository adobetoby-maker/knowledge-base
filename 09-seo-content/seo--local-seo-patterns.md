# Local SEO Patterns — Ranking for "Near Me" and City Searches

**When:** Building or optimizing any local business website.
**Rule:** Local SEO is a different game than national SEO. The ranking factors are: Google Business Profile, NAP consistency, local content, proximity, and reviews.

## The Three Local Ranking Factors (Google's)
1. **Relevance** — does your business match what they searched for?
2. **Proximity** — how physically close are you to the searcher?
3. **Prominence** — how well-known are you (reviews, links, citations)?

You control: relevance (via content) and prominence (via reviews/citations).
You can't change proximity — but you can expand your geographic footprint via content.

## NAP Consistency (Name, Address, Phone)
Your business name, address, and phone must be IDENTICAL everywhere:
- Website (header, footer, contact page, structured data)
- Google Business Profile
- Yelp, Facebook, Apple Maps, Bing Places
- Every citation directory

Even small differences hurt: "Jr.'s Auto Repair" vs "JR's Auto Repair" vs "Junior's Auto Repair"
Use one canonical form everywhere. Check: `lib/shopInfo.ts` is the source of truth for our projects.

## Geo-Targeting Content Strategy
One city page per target city — not just the primary city:
```
/service-areas/twin-falls    → primary
/service-areas/jerome        → 20 min away
/service-areas/kimberly
/service-areas/buhl
/service-areas/filer
```

Each city page: unique content about serving that city, local landmarks, NAP, embedded map.
Never duplicate the same content with only the city name swapped — Google detects this.

## Schema Markup for Local Business
```typescript
// In <head> or a Server Component
const schema = {
  "@context": "https://schema.org",
  "@type": "AutoRepair",  // or LocalBusiness, Restaurant, etc.
  "name": "Jr.'s Auto Repair",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "417 Main Ave E",
    "addressLocality": "Twin Falls",
    "addressRegion": "ID",
    "postalCode": "83301"
  },
  "telephone": "(208) 595-2101",
  "openingHours": ["Mo-Sa 09:00-17:00"],
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.8",
    "reviewCount": "146"
  },
  "url": "https://jrsautorepair.worker-bee.app"
}
```

## Review Generation Strategy
Reviews are a ranking factor AND a conversion factor.
Automate the ask: after a service is completed, SMS or email the customer with a direct Google review link.
Never buy reviews. Never review-gate (showing the link only if they'd give 5 stars).

## Content Signals That Help Local Rankings
- Mention of city/neighborhood in page title tag
- City name in H1 and first paragraph
- Embedded Google Map on contact/location page
- Directions from landmarks ("1 mile south of Twin Falls Magic Valley Airport")
- Local events, partnerships, community mentions

## The "Near Me" Trick
Google interprets "auto repair near me" as a local query.
You don't need to use "near me" in your content — Google knows your location.
What helps: strong local signals (NAP, reviews, schema, local content).

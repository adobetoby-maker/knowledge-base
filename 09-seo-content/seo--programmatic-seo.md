# Programmatic SEO — Auto-Generating Pages at Scale

**When:** You have structured data and need many similar pages (city pages, product pages, location variants).
**Rule:** Each generated page must have unique, substantive content. Thin pages that only swap the city/product name are spam and get penalized.

## When Programmatic SEO Makes Sense
- 10+ locations with real services in each
- Product catalog pages (100+ products with real descriptions)
- "Best X in Y city" pages with actual local data
- Service + location combinations: "oil change in Twin Falls", "oil change in Jerome"

## Next.js Dynamic Route Pattern
```typescript
// app/service-areas/[city]/page.tsx

interface CityData {
  name: string
  slug: string
  population: number
  distanceFromTwinFalls: string
  localLandmarks: string[]
  localPhrase: string
}

// lib/cities.ts — your structured data
export const CITIES: CityData[] = [
  {
    name: 'Jerome',
    slug: 'jerome',
    population: 12000,
    distanceFromTwinFalls: '25 miles west',
    localLandmarks: ['Jerome County Fairgrounds', 'I-84 corridor'],
    localPhrase: 'the Dairy Capital of the West'
  },
  // ... more cities
]

// Generate all static paths at build time
export async function generateStaticParams() {
  return CITIES.map(city => ({ city: city.slug }))
}

// Unique metadata per page
export async function generateMetadata({ params }: { params: { city: string } }) {
  const city = CITIES.find(c => c.slug === params.city)!
  return {
    title: `Auto Repair in ${city.name} ID | JR's Auto Repair`,
    description: `Trusted auto repair serving ${city.name}. JR's Auto Repair is just ${city.distanceFromTwinFalls} — call (208) 595-2101.`
  }
}

export default function CityPage({ params }: { params: { city: string } }) {
  const city = CITIES.find(c => c.slug === params.city)!
  return <CityServicePage city={city} />
}
```

## Making Each Page Unique — The Minimum Bar
Every generated page needs at least three things that are genuinely different:
1. **Local context** — landmarks, history, what the city is known for
2. **Specific data** — distance, drive time, area-specific details
3. **Unique paragraph** — something you can't say about every city

```typescript
// Unique content per city (not just name substitution)
function CityServicePage({ city }: { city: CityData }) {
  return (
    <>
      <h1>Auto Repair Serving {city.name}, Idaho</h1>
      <p>
        JR's Auto Repair has been serving drivers from {city.name}
        — {city.localPhrase} — for over 13 years. Located {city.distanceFromTwinFalls}
        on Main Ave E in Twin Falls, we're the closest full-service shop to
        {city.localLandmarks[0]}.
      </p>
      {/* Unique content per city goes here */}
    </>
  )
}
```

## Internal Linking Between City Pages
```typescript
// Service areas hub page (e.g., /service-areas)
<ul>
  {CITIES.map(city => (
    <li key={city.slug}>
      <a href={`/service-areas/${city.slug}`}>Auto Repair Near {city.name}</a>
    </li>
  ))}
</ul>
```

## Avoiding Google Penalties
- Each page must have > 300 words of unique content
- Title tags must be unique (not just "[City] - Service Name")
- Don't generate pages for cities you don't actually serve
- Don't keyword-stuff city names — use them naturally
- Internal link all city pages from a hub page

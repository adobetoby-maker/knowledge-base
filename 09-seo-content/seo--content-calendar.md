# SEO: Content Calendar

## Overview

A content calendar coordinates what to publish, when, and why. Without one, content efforts are reactive, inconsistent, and miss seasonal opportunities. With one, you build momentum: each piece supports the next.

## Planning Framework

### Capacity First

Decide sustainable cadence before planning topics:
- 1 article/month: focus only on the highest-impact cornerstone topic each month
- 1 article/week: mix of cornerstone (1x/month) + supporting cluster pieces
- Daily: scale with templates, batch production, and AI-assisted drafting

Under-promising and over-delivering beats the reverse. A 2-year-old article that gets weekly updates ranks better than 10 published articles with no follow-through.

### Rolling 90-Day Plan

Plan 90 days ahead, publish daily/weekly from the queue. Review and adjust monthly:

```ts
interface ContentCalendarItem {
  publishDate: string
  title: string
  slug: string
  type: 'cornerstone' | 'supporting' | 'news' | 'seasonal'
  targetKeyword: string
  cluster: string          // groups pieces that support each other
  status: 'planned' | 'in-progress' | 'written' | 'edited' | 'scheduled' | 'published'
  assignedTo?: string
  notes?: string
}
```

## Seasonal Planning for Local Business

For a local service business (auto repair, logistics, medical), seasonal search patterns drive a predictable content calendar:

```ts
const SEASONAL_CONTENT: Record<string, string[]> = {
  january: [
    'New Year car maintenance checklist',
    'Winter tire tips for Idaho drivers',
  ],
  february: [
    'Preparing your car for spring',
    'Valentine\'s Day car care gift ideas',
  ],
  march: [
    'Spring vehicle inspection guide',
    'How spring potholes damage your car',
  ],
  april: [
    'Spring cleaning: detailing your car after winter',
    'April showers and your windshield wipers',
  ],
  may: [
    'Summer road trip preparation checklist',
    'Memorial Day weekend car maintenance',
  ],
  june: [
    'Summer heat and your car\'s cooling system',
    'Road trip tire safety guide',
  ],
  july: [
    'Overheating prevention: summer car care',
    'What to do if your car breaks down in summer',
  ],
  august: [
    'Back-to-school car safety inspection',
    'College student car maintenance guide',
  ],
  september: [
    'Fall car maintenance checklist',
    'Preparing your car for winter',
  ],
  october: [
    'Winter tire guide: studded vs all-season',
    'Halloween driving safety tips',
  ],
  november: [
    'Thanksgiving road trip car prep',
    'Winter emergency kit for your car',
  ],
  december: [
    'Holiday travel car maintenance guide',
    'Year-end car maintenance recap',
  ],
}
```

Plan seasonal content 6–8 weeks before the month — it takes time to rank. A December Christmas-themed post published December 20 will rank January 3.

## Topic Cluster Calendar

Organize publications so cluster pieces publish after the cornerstone is indexed:

```
Week 1: Cornerstone — "Complete Guide to Auto Repair in Twin Falls"
Week 3: Supporting — "How Much Does an Oil Change Cost in Twin Falls?"
Week 5: Supporting — "When to Get Your Brakes Inspected"
Week 7: Supporting — "Twin Falls Mechanic Ratings and Reviews Guide"
Week 9: Supporting — "Auto Repair vs Dealership: Which is Right for You?"
```

Internal linking flows from supporting pieces to the cornerstone. The cornerstone links to each supporting piece. Together they build topical authority.

## Publishing Schedule Template

```ts
// Generate a 90-day content calendar
function generate90DayCalendar(startDate: Date, cadence: 'weekly' | 'biweekly'): Date[] {
  const dates: Date[] = []
  const days = cadence === 'weekly' ? 7 : 14
  let current = new Date(startDate)

  while (current < new Date(startDate.getTime() + 90 * 24 * 60 * 60 * 1000)) {
    // Prefer Tuesday or Wednesday publications (higher traffic days)
    while (current.getDay() !== 2 && current.getDay() !== 3) {
      current.setDate(current.getDate() + 1)
    }
    dates.push(new Date(current))
    current.setDate(current.getDate() + days)
  }

  return dates
}
```

## Content Refresh Calendar

Old articles need scheduled refreshes to maintain rankings. Plan these alongside new content:

- Monthly: update statistics, prices, and time-sensitive facts
- Quarterly: check if the article still matches current search intent
- Annually: full rewrite if the topic has evolved significantly

Track last-updated dates in the article metadata. Articles older than 18 months without a refresh are prime candidates for decay.

## Tracking Publication Impact

Create a simple impact log:

```ts
interface PublicationImpact {
  slug: string
  publishedAt: string
  monthOneTraffic: number    // Sessions in first 30 days
  month3Traffic: number      // Sessions at 90 days
  rankingKeyword: string
  rankingPosition: number    // At 90 days
  conversions: number        // Contact form, calls attributed
}
```

Review this monthly. High-traffic, low-conversion articles need CTAs or internal links to service pages. Low-traffic articles need keyword re-optimization or a different topic angle.

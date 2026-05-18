# Stack Bundle: JRS Auto Repair Blog Context

## Purpose

Compact context for local models or batch jobs writing blog articles for Jr.'s Auto Repair. Load this file + the article template for ~1800 tokens of context.

## Business Information

```
Business: Jr.'s Auto Repair
Owner: Pablo Zaldivar
Address: 417 Main Ave E, Twin Falls, ID 83301
Phone: (208) 595-2101
Hours: Monday–Saturday, 9AM–5PM
Rating: 4.8 stars · 146 reviews
Tagline: "Honest work, fair prices, done right the first time."
Years in business: 13+ years
```

## Geographic Targeting

Primary: Twin Falls, Idaho
Secondary: Magic Valley (50-mile radius)
City mentions to include: Jerome, Kimberly, Filer, Buhl, Hansen, Wendell, Gooding, Shoshone, Burley, Rupert, Hagerman

Use both "Twin Falls" and "Magic Valley" in articles. Geo phrases:
- "auto repair Twin Falls ID"
- "mechanic Magic Valley Idaho"  
- "mechanic near me Twin Falls"

## Content Architecture

Articles live in `lib/articles.ts` as a TypeScript array — NEVER as markdown files.

Article type:
```typescript
{
  slug: string         // kebab-case, URL-safe
  title: string        // 50-60 chars, keyword-first
  excerpt: string      // 140-160 chars, for meta description
  category: string     // "Services" | "Maintenance" | "Safety" | "Tips"
  date: string         // "YYYY-MM-DD"
  readTime: number     // minutes, estimated
  body: string         // HTML string, 600-1200 words
}
```

Blog URL: `/blog/[slug]` (not `/articles/`)

## Content Clusters (Priority Topics)

**By Service:**
- Oil change (high volume keyword)
- Brake repair and replacement
- Transmission service
- Engine diagnostics / check engine light
- AC repair / heating system
- Tire rotation and alignment
- Battery replacement
- Coolant flush

**By Car Problem:**
- Strange noises (squealing, grinding, knocking)
- Warning lights
- Hard starting / won't start
- Overheating
- Poor fuel economy

**By Maintenance Schedule:**
- 30k/60k/90k mile service
- Seasonal maintenance (winter prep, summer prep)
- Pre-road trip inspection
- When to replace brakes

## Article Structure (HTML Body)

```html
<p>Opening hook — 2-3 sentences connecting to customer pain point. Mention Twin Falls or Magic Valley.</p>

<h2>Why [Topic] Matters</h2>
<p>Educational content about why this matters for the customer's vehicle or safety.</p>

<h2>Signs You Need [Service]</h2>
<ul>
  <li>Symptom 1</li>
  <li>Symptom 2</li>
  <li>Symptom 3</li>
</ul>

<h2>Our Process at Jr.'s Auto Repair</h2>
<p>What happens during the service. Build trust.</p>

<h2>How Often Should You [Service]?</h2>
<p>Maintenance schedule information. Industry standards.</p>

<p>Call to action with phone number: (208) 595-2101</p>
```

## Tone and Voice

- Direct and practical — customers want answers, not marketing
- Trust-building — reference experience ("13 years serving Twin Falls")
- Include real specifics — phone number, address, hours
- Never mention prices in articles (they vary, go out of date)
- Active voice: "we replace" not "brakes can be replaced"
- 8th grade reading level

## Quality Checks

Every article body must:
- Contain "(208)" (phone number)
- Contain "Twin Falls"
- Be at least 500 characters
- Not contain "TODO", "PLACEHOLDER", "[object Object]"
- Not contain prices ("$XX" patterns)
- H2 headings present (not wall of text)

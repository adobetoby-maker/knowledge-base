# Skill: content-generation

**Trigger:** Generating articles, blog posts, marketing copy, or structured content for any of the projects.
**Returns:** Voice guidelines, article format, content type patterns, batch generation approach.

## Content Destination by Project

| Project | Content Type | Storage | Location |
|---------|-------------|---------|----------|
| jrs-auto-repair | Auto service articles | TypeScript array | lib/articles.ts |
| climb-brasil | Climbing destinations + guides | TypeScript array | lib/articles.ts |
| climb-spain | Climbing destinations + guides | TypeScript array | lib/articles.ts |
| climb-utah | Climbing destinations + guides | TypeScript array | lib/articles.ts |
| climb-kalymnos | Climbing destinations + guides | TypeScript array | lib/articles.ts |
| language-lens-elite | Language learning articles | TypeScript array | lib/articles.ts |

**All projects:** Content lives in TypeScript arrays, not markdown files. Never create standalone `.md` files for blog content.

## Article Object Structure

```typescript
interface Article {
  slug: string        // URL slug: kebab-case
  title: string       // SEO title: 50-60 chars
  excerpt: string     // Meta description: 150-160 chars
  category: string    // Categorical grouping
  date: string        // ISO date: YYYY-MM-DD
  readTime: string    // "N min read"
  body: string        // Markdown content (no code blocks for SEO content)
}
```

## Writing for jrs-auto-repair

**Voice:** Pablo, the mechanic — direct, knowledgeable, Twin Falls local. Not corporate.

**Required elements:**
- Primary keyword in title and first paragraph
- Reference to Twin Falls and/or Magic Valley
- Phone number (208) 595-2101 in at least one CTA
- Service-specific pricing (approximate ranges if exact unknown)
- One section answering "how much does X cost" for cost keywords

**Article categories:**
- `maintenance` — oil changes, tire rotation, fluid checks
- `repairs` — brakes, transmission, AC, electrical
- `diagnostics` — check engine, warning lights
- `seasonal` — winter prep, summer AC, fall checklist
- `buying-guide` — what to check before buying a used car

## Writing for Climb Sites

**Voice:** Enthusiastic local beta, specific route names and grades.

**Required elements:**
- Exact route grades (Yosemite for Utah, French for Brazil/Spain/Kalymnos)
- Approach time and directions
- Season/conditions information
- Difficulty range (beginner-friendly crags vs. sport project areas)
- Gear requirements (quickdraws, double ropes, trad gear)

**Content categories:**
- `destination` — overview of a climbing area
- `route-guide` — specific crag or wall
- `training` — technique, fitness for climbing
- `gear` — equipment reviews and recommendations
- `travel` — logistics, accommodation, flights

## Batch Article Generation

For generating multiple articles at once:

1. Create a task list with all article specs:
```typescript
const articlesToGenerate = [
  { keyword: 'brake repair Twin Falls', category: 'repairs', wordCount: 900 },
  { keyword: 'oil change near me Twin Falls', category: 'maintenance', wordCount: 700 },
  // ...
]
```

2. Generate each article against the spec using the overnight batch templates in `11-overnight-batch/`

3. Validate: each article has correct word count, keyword in first paragraph, local reference, CTA

4. Append to `lib/articles.ts` with a unique slug and today's date

## Avoiding Duplicate Content

Before generating any article, check existing articles in `lib/articles.ts`:

```typescript
// Slug collision check
const existingSlug = articles.find(a => a.slug === newSlug)
if (existingSlug) console.warn('DUPLICATE SLUG:', newSlug)

// Topic overlap check
const similar = articles.filter(a => 
  a.body.includes(primaryKeyword) || a.title.toLowerCase().includes(primaryKeyword)
)
if (similar.length > 0) console.warn('TOPIC OVERLAP:', similar.map(a => a.slug))
```

Duplicate slugs cause 404 routing conflicts. Topic overlap dilutes SEO — update the existing article instead of creating a new one.

## SEO Formatting Requirements

In the article body (markdown):
- First H2 appears within first 200 words
- Primary keyword in at least one H2 heading
- At least 3 internal links to service pages or related articles
- At least one list (bulleted or numbered)
- One FAQ section with 3-5 Q&A pairs (targets "People Also Ask")

For local service content, include the `LocalBusiness` citation at the end:
```markdown
*Content provided by Jr.'s Auto Repair · 417 Main Ave E, Twin Falls, ID 83301 · (208) 595-2101*
```

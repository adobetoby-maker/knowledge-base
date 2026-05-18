# Skill: seo-aeo-blog-writer

**Trigger:** Writing a long-form blog article (800-2500 words) designed to rank in Google and appear in AI-generated answers (AEO = Answer Engine Optimization).
**Invoke:** `/seo-aeo-blog-writer`
**Returns:** Fully structured, SEO-optimized blog post with headings, FAQ section, internal links, meta description, and AEO-ready phrasing.

## When to Invoke
- Writing a service page article (e.g., "How to Know When to Replace Your Brakes")
- Writing an informational guide that targets a how-to question
- Wanting to capture a featured snippet on Google
- Wanting the article to be cited as an answer by AI assistants
- Building out a content cluster with 10+ articles on a topic

## AEO vs SEO — The Difference
**SEO** optimizes for Google rankings (backlinks, keyword density, page speed).
**AEO** optimizes to be the source AI assistants quote (direct answers, factual claims, clear question-answer pairs).

Both matter. AEO requires:
- Answer the question in the first 100 words
- Use the exact question phrasing as an H2
- Give a crisp 1-2 sentence answer, then expand
- Include a structured FAQ section at the end

## Article Structure
```
## [H2: Primary Keyword / Core Question]
Opening that answers directly in 2 sentences.
Then expands with context.

## [H2: Subtopic 1]
## [H2: Subtopic 2]
## [H2: Subtopic 3]

## Frequently Asked Questions
### [Question 1 people actually search?]
[1-2 sentence direct answer]

### [Question 2?]
[1-2 sentence direct answer]
```

## Keyword Placement Rules
Primary keyword must appear in:
- H1 title (naturally, not forced)
- First 100 words
- At least one H2 subheading
- URL slug (handled by article slug field)
- Meta description (generated from excerpt field)

Secondary keywords: scatter naturally throughout, no forced repetition.

## Local SEO Articles (JRS Auto Repair)
Every article must include:
- "Twin Falls" in first paragraph
- "Magic Valley" at least once in body
- Address: "417 Main Ave E, Twin Falls, ID"
- Phone: "(208) 595-2101"
- One internal link to another service or article
- CTA at the end: "Call us at (208) 595-2101 or visit us at..."

## Adding to jrs-auto-repair
Articles go in `lib/articles.ts` as TypeScript objects:
```typescript
{
  slug: 'how-to-know-when-to-replace-brakes',
  title: 'How to Know When to Replace Your Brakes: A Twin Falls Driver\'s Guide',
  excerpt: 'Learn the 5 warning signs your brakes need replacement...',
  category: 'Brakes',
  date: '2026-05-18',
  readTime: '5 min read',
  body: `...full markdown content...`
}
```

## What Skill Returns
Complete article with front matter, full body text, FAQ section, internal link suggestions, meta description, and category assignment.

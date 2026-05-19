# ADR: Static Content in TypeScript Arrays — Not Markdown or CMS

**Projects:** jrs-auto-repair, silver-creek-logistics
**Decision:** Blog articles and business data live in TypeScript files, not markdown files or a CMS.

## Core Files

- `lib/articles.ts` — array of `Article` objects with slug, title, excerpt, category, date, readTime, body
- `lib/shopInfo.ts` — single source of truth for ALL business data: name, phone, address, hours, services
- `lib/howtos.ts` — how-to guides (same pattern as articles)

## Why TypeScript Arrays Instead of Markdown

- **Type safety at content level** — add a new field to `Article`, TypeScript immediately flags every entry missing it. Markdown frontmatter fails silently at runtime.
- **No additional tooling** — no gray-matter, no remark/rehype, no contentlayer, no next-mdx-remote. Zero parser config.
- **`generateStaticParams()` works from any source** — TypeScript array produces identical output to filesystem-driven markdown.
- **Content is developer-authored** — these are AI-generated SEO articles; no one is editing markdown files in VS Code.
- **Build time is pure TypeScript** — no filesystem reads, no frontmatter parsing.

## Why Not a CMS

- Pablo (JRS) is not logging into Contentful. All changes go through Drive anyway.
- CMS = API keys + paid tier + webhook for ISR + separate dashboard = overhead with no benefit.
- Content velocity is low (SEO articles, stable business info).
- If velocity increases, the `Article` type maps cleanly to any CMS schema.

## `lib/shopInfo.ts` — The Golden Rule

Every hardcoded business fact is a ticking inconsistency bug.
The phone number in the hero eventually diverges from the phone number in the footer, which diverges from JSON-LD, which diverges from email templates.

**NEVER hardcode name, phone, address, hours, or services inline. Always import from `lib/shopInfo.ts`.**

## Article Schema

```ts
interface Article {
  slug: string;       // URL: /blog/[slug]
  title: string;      // <h1> and <title>
  excerpt: string;    // list views + meta description
  category: string;   // "brakes" | "oil-change" | "tires" | etc.
  date: string;       // YYYY-MM-DD
  readTime: string;   // display only: "5 min"
  body: string;       // HTML string — rendered server-side, developer-authored only
}
```

Body is HTML, not markdown — rendered at build time from static developer-authored content. It is safe because it is never user-submitted.

## SEO Article Clusters

- **Service**: one article per core service, geo-targeted to Twin Falls / Magic Valley
- **Problem**: "car won't start", "check engine light" — problem-aware searchers
- **Maintenance**: "when to rotate tires", "how often oil change" — top-of-funnel informational

Blog category filter on `/blog` is derived dynamically: `new Set(articles.map(a => a.category))`. No registry needed — adding an article with a new category adds it to the filter.

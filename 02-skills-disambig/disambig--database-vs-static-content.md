# Disambiguation: Database vs Static Content

## The Rule

**Static TypeScript arrays** (`lib/*.ts`) for content that:
- Changes with code deployments (new blog post = new code commit)
- Doesn't need user customization
- Is authored by the developer, not the business owner at runtime

**Database** (`Supabase`) for data that:
- Changes at runtime without code deployment
- Is created or modified by end users through the UI
- Needs to be queried, filtered, sorted at scale
- Has relationships (invoices belong to customers)

## Project-Specific Content Rules

### jrs-auto-repair

| Content Type | Location | Reason |
|---|---|---|
| Blog articles | `lib/articles.ts` | Dev-authored, deploy-gated |
| How-to guides | `lib/howtos.ts` | Dev-authored |
| Business info (name, phone, hours) | `lib/shopInfo.ts` | Single source of truth |
| Services list | `lib/services.ts` | Dev-authored |
| Customer invoices | Supabase `invoices` table | Created by Pablo at runtime |
| Customers | Supabase `customers` table | Created by Pablo at runtime |
| Appointments | Supabase `appointments` table | Created by customers |

**Never** create markdown files for JRS content. Static content belongs in TypeScript arrays in `lib/`.

### manage-worker-bee

| Content Type | Location | Reason |
|---|---|---|
| Blueprint data (nodes, edges) | Supabase Storage `blueprints/` | Updated via UI |
| Client site records | Supabase `sites` table | Created via admin UI |
| Vault credentials | Supabase `vault_entries` table | Created via admin UI |
| Form submissions | Supabase `submissions` table | Created by public form |

### language-lens-elite

| Content Type | Location | Reason |
|---|---|---|
| CEFR vocabulary data | TypeScript arrays in `src/data/` | Pre-authored, not user-generated |
| User XP and progress | Supabase `profiles` table | Changes at runtime |
| Leaderboard scores | Supabase `scores` table | Dynamic, queried by rank |

### climb-brasil / climb-utah / climb-kalymnos / climb-spain

| Content Type | Location | Reason |
|---|---|---|
| Route descriptions | TypeScript arrays in `lib/routes.ts` | Static guide content |
| Blog articles | TypeScript arrays in `lib/articles.ts` | SEO articles written at deploy time |
| Destination info | TypeScript arrays in `lib/destinations.ts` | Static geographic data |

## When to Migrate from Static to Database

Migrate content from static arrays to the database when:
1. The business owner needs to update it WITHOUT a code deployment
2. The content set exceeds 500+ items (TypeScript compilation becomes slow)
3. The content has relationships that require querying (e.g., filter articles by author)
4. A/B testing requires dynamic content variation

The climb sites currently have static content — if Pablo wants to add new routes or articles without a dev, migrate to Supabase.

## Schema Article vs Static Article

The TypeScript static article structure:
```typescript
// lib/articles.ts
export const articles: Article[] = [
  {
    slug: 'best-time-to-climb-twin-falls',
    title: 'Best Time to Visit Twin Falls for Rock Climbing',
    excerpt: 'Spring and fall offer the best conditions...',
    category: 'planning',
    date: '2026-01-15',
    readTime: '5 min read',
    body: `...full article body as a string...`,
  },
]
```

If migrated to Supabase:
```sql
CREATE TABLE articles (
  slug TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  excerpt TEXT,
  category TEXT,
  published_at DATE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

## Common Mistake: Creating Markdown Files

```
// WRONG for jrs-auto-repair
blog/
  oil-change-guide.md
  brake-inspection.md
```

The JRS project has NO markdown rendering pipeline. Content in `.md` files won't be served or indexed. Put it in `lib/articles.ts` as a TypeScript array entry.

## Dynamic SEO From Static Data

Static TypeScript content still enables dynamic metadata:
```typescript
// app/blog/[slug]/page.tsx
import { articles } from '@/lib/articles'

export function generateStaticParams() {
  return articles.map(article => ({ slug: article.slug }))
}

export function generateMetadata({ params }: { params: { slug: string } }) {
  const article = articles.find(a => a.slug === params.slug)
  return { title: article?.title, description: article?.excerpt }
}
```

This generates one static page per article at build time — fast, SEO-friendly, no database query needed.

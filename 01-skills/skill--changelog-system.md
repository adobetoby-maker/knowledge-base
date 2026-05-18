# Skill: Changelog System

## Overview

Public changelog displaying product updates, new features, and fixes. Doubles as content for user re-engagement emails and SEO. Common in SaaS products.

## Data Structure

```ts
interface ChangelogEntry {
  slug: string
  title: string
  date: string               // ISO date: '2026-05-18'
  type: ChangeType[]         // Multiple types allowed
  summary: string            // 1-2 sentences
  body: string               // MDX or rich text for full entry
  imageUrl?: string
  published: boolean
}

type ChangeType = 'feature' | 'improvement' | 'fix' | 'breaking' | 'security'

const TYPE_CONFIG: Record<ChangeType, { label: string; color: string }> = {
  feature: { label: 'New Feature', color: 'bg-blue-100 text-blue-800' },
  improvement: { label: 'Improvement', color: 'bg-green-100 text-green-800' },
  fix: { label: 'Bug Fix', color: 'bg-yellow-100 text-yellow-800' },
  breaking: { label: 'Breaking Change', color: 'bg-red-100 text-red-800' },
  security: { label: 'Security', color: 'bg-purple-100 text-purple-800' },
}
```

## Storage Options

**Static TypeScript array** (recommended for small-medium changelogs):
```ts
// lib/changelog.ts
export const CHANGELOG: ChangelogEntry[] = [
  {
    slug: 'csv-export-2026-05',
    title: 'CSV Export for Reports',
    date: '2026-05-18',
    type: ['feature'],
    summary: 'Export any report as a CSV file directly from the dashboard.',
    body: `...`,
    published: true,
  },
]
```

Advantages: no database queries, build-time validation, easy to diff in git, can trigger deploy on publish. Suitable for up to ~100 entries.

**Database table** (for high-volume or team-authored changelogs):
```sql
CREATE TABLE changelog_entries (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug       TEXT UNIQUE NOT NULL,
  title      TEXT NOT NULL,
  entry_date DATE NOT NULL,
  types      TEXT[] NOT NULL,
  summary    TEXT NOT NULL,
  body       TEXT NOT NULL,
  image_url  TEXT,
  published  BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ON changelog_entries (entry_date DESC) WHERE published = true;
```

## Changelog Page

```tsx
// app/changelog/page.tsx
import { CHANGELOG } from '@/lib/changelog'
import { format, parseISO } from 'date-fns'

export default function ChangelogPage() {
  const published = CHANGELOG.filter((e) => e.published).sort(
    (a, b) => parseISO(b.date).getTime() - parseISO(a.date).getTime()
  )

  return (
    <div className="max-w-2xl mx-auto px-4 py-16">
      <h1 className="text-3xl font-bold mb-12">Changelog</h1>
      <div className="space-y-12">
        {published.map((entry) => (
          <ChangelogItem key={entry.slug} entry={entry} />
        ))}
      </div>
    </div>
  )
}

function ChangelogItem({ entry }: { entry: ChangelogEntry }) {
  return (
    <article id={entry.slug} className="scroll-mt-16">
      <div className="flex items-start gap-4">
        <div className="flex-shrink-0 w-32 text-sm text-gray-400 pt-1">
          {format(parseISO(entry.date), 'MMM d, yyyy')}
        </div>
        <div className="flex-1">
          <div className="flex flex-wrap gap-2 mb-3">
            {entry.type.map((t) => (
              <span key={t} className={`text-xs px-2 py-0.5 rounded-full font-medium ${TYPE_CONFIG[t].color}`}>
                {TYPE_CONFIG[t].label}
              </span>
            ))}
          </div>
          <h2 className="text-xl font-semibold mb-2">
            <a href={`/changelog#${entry.slug}`} className="hover:text-blue-600">
              {entry.title}
            </a>
          </h2>
          <p className="text-gray-600 mb-4">{entry.summary}</p>
          {entry.imageUrl && (
            <img src={entry.imageUrl} alt={entry.title} className="rounded-lg border mb-4" />
          )}
          <ChangelogBody content={entry.body} />
        </div>
      </div>
    </article>
  )
}
```

## RSS Feed

```ts
// app/changelog/rss.xml/route.ts
import { CHANGELOG } from '@/lib/changelog'
import { format, parseISO } from 'date-fns'

export async function GET() {
  const entries = CHANGELOG.filter((e) => e.published)
    .sort((a, b) => parseISO(b.date).getTime() - parseISO(a.date).getTime())
    .slice(0, 20)

  const items = entries.map((e) => `
    <item>
      <title><![CDATA[${e.title}]]></title>
      <link>https://yourapp.com/changelog#${e.slug}</link>
      <guid>https://yourapp.com/changelog#${e.slug}</guid>
      <pubDate>${format(parseISO(e.date), 'EEE, dd MMM yyyy HH:mm:ss xx')}</pubDate>
      <description><![CDATA[${e.summary}]]></description>
    </item>`).join('')

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>YourApp Changelog</title>
    <link>https://yourapp.com/changelog</link>
    <description>Product updates and new features</description>
    ${items}
  </channel>
</rss>`

  return new Response(xml, {
    headers: {
      'Content-Type': 'application/rss+xml',
      'Cache-Control': 'public, max-age=3600',
    },
  })
}
```

## In-App Notification Badge

Show users when there are changelog entries they haven't seen:

```ts
// Store the last seen date in localStorage
function useChangelogBadge() {
  const lastSeen = localStorage.getItem('changelog-last-seen')
  const newestEntry = CHANGELOG.filter((e) => e.published)[0]?.date

  if (!lastSeen || newestEntry > lastSeen) {
    return true  // Show badge
  }
  return false
}

function markChangelogSeen() {
  const newestEntry = CHANGELOG.filter((e) => e.published)[0]?.date
  if (newestEntry) localStorage.setItem('changelog-last-seen', newestEntry)
}
```

## SEO

Each changelog entry generates an anchor (`#slug`), making individual updates linkable and indexable. Add structured data for news-style entries:

```ts
const newsSchema = entries.map((e) => ({
  '@context': 'https://schema.org',
  '@type': 'NewsArticle',
  headline: e.title,
  datePublished: e.date,
  description: e.summary,
  publisher: { '@type': 'Organization', name: 'YourApp' },
}))
```

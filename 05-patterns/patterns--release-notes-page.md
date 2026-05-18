# Pattern: Release Notes / Changelog Page

## Overview
A changelog page is both a discovery mechanism for existing users and a trust signal for evaluating users. The structure must make it effortless to find out "what changed recently" (newest first), understand severity (Feature vs Fix vs Breaking vs Deprecation), and deep-link to a specific version from in-app notifications. The in-app "What's New" badge integrating with the changelog creates a complete notification loop.

## Implementation

### Changelog data structure

```ts
interface ChangelogEntry {
  version: string           // "2.4.1"
  date: string              // ISO date "2026-05-15"
  categories: ChangeCategory[]
}

interface ChangeCategory {
  type: 'feature' | 'fix' | 'breaking' | 'deprecation' | 'improvement' | 'security'
  items: string[]
}

// Static data or loaded from MDX files
const CHANGELOG: ChangelogEntry[] = [
  {
    version: '2.5.0',
    date: '2026-05-15',
    categories: [
      {
        type: 'feature',
        items: [
          'Added bulk export to CSV for all data tables',
          'New AI-powered search with natural language queries',
        ],
      },
      {
        type: 'improvement',
        items: ['Dashboard loads 40% faster due to query optimization'],
      },
      {
        type: 'fix',
        items: ['Fixed timezone display bug in activity feed'],
      },
    ],
  },
  {
    version: '2.4.0',
    date: '2026-04-20',
    categories: [
      {
        type: 'breaking',
        items: ['`/api/v1/users` endpoint removed — migrate to `/api/v2/users`'],
      },
      {
        type: 'feature',
        items: ['Two-factor authentication for all accounts'],
      },
    ],
  },
]
```

### Changelog page

```tsx
export default function ChangelogPage({
  searchParams,
}: {
  searchParams: { type?: string }
}) {
  const activeFilter = searchParams.type as ChangeCategory['type'] | undefined

  const filtered = activeFilter
    ? CHANGELOG.map((entry) => ({
        ...entry,
        categories: entry.categories.filter((c) => c.type === activeFilter),
      })).filter((entry) => entry.categories.length > 0)
    : CHANGELOG

  return (
    <div className="max-w-3xl mx-auto py-16 px-4">
      <div className="mb-10">
        <h1 className="text-4xl font-bold mb-3">Changelog</h1>
        <p className="text-gray-500">New updates and improvements to our platform.</p>
        <SubscribeButton />
      </div>

      <ChangeTypeFilter activeFilter={activeFilter} />

      <div className="space-y-16 mt-8">
        {filtered.map((entry) => (
          <ChangelogEntry key={entry.version} entry={entry} />
        ))}
      </div>
    </div>
  )
}
```

### Changelog entry with anchor link

```tsx
function ChangelogEntry({ entry }: { entry: ChangelogEntry }) {
  const anchor = `v${entry.version}`

  return (
    <article id={anchor} className="scroll-mt-16">
      <div className="flex items-baseline gap-4 mb-4">
        <a href={`#${anchor}`} className="group flex items-center gap-2">
          <h2 className="text-2xl font-bold group-hover:text-blue-600">
            v{entry.version}
          </h2>
          <span className="text-gray-400 opacity-0 group-hover:opacity-100 text-sm">#</span>
        </a>
        <time dateTime={entry.date} className="text-sm text-gray-400">
          {new Date(entry.date).toLocaleDateString('en-US', {
            year: 'numeric', month: 'long', day: 'numeric'
          })}
        </time>
      </div>

      <div className="space-y-4">
        {entry.categories.map((category) => (
          <ChangeSection key={category.type} category={category} />
        ))}
      </div>
    </article>
  )
}

const CATEGORY_CONFIG = {
  feature:     { label: 'New',        color: 'bg-blue-100 text-blue-700' },
  improvement: { label: 'Improved',   color: 'bg-purple-100 text-purple-700' },
  fix:         { label: 'Fixed',      color: 'bg-green-100 text-green-700' },
  breaking:    { label: 'Breaking',   color: 'bg-red-100 text-red-700' },
  deprecation: { label: 'Deprecated', color: 'bg-amber-100 text-amber-700' },
  security:    { label: 'Security',   color: 'bg-orange-100 text-orange-700' },
}

function ChangeSection({ category }: { category: ChangeCategory }) {
  const config = CATEGORY_CONFIG[category.type]
  return (
    <div>
      <span className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium mb-2 ${config.color}`}>
        {config.label}
      </span>
      <ul className="space-y-1">
        {category.items.map((item, i) => (
          // Items are authored content (not user input), safe to render as text
          <li key={i} className="flex items-start gap-2 text-sm text-gray-700">
            <span className="mt-1.5 w-1 h-1 rounded-full bg-gray-400 shrink-0" />
            <span>{item}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
```

### In-app "What's New" notification badge

```tsx
function WhatsNewBadge() {
  const [hasNew, setHasNew] = useState(false)

  useEffect(() => {
    const lastSeen = localStorage.getItem('changelog_last_seen')
    const latestDate = CHANGELOG[0]?.date

    if (!lastSeen || (latestDate && lastSeen < latestDate)) {
      setHasNew(true)
    }
  }, [])

  function markSeen() {
    localStorage.setItem('changelog_last_seen', CHANGELOG[0]?.date ?? '')
    setHasNew(false)
  }

  return (
    <a
      href="/changelog"
      onClick={markSeen}
      className="relative flex items-center gap-1 text-sm text-gray-600 hover:text-gray-900"
    >
      <Sparkles size={16} />
      What&apos;s New
      {hasNew && (
        <span className="absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full bg-blue-500" />
      )}
    </a>
  )
}
```

## Key Rules
- Newest entry first — users come to see what's new, not historical context
- Breaking changes and security fixes get distinct visual treatment — they require user action
- Anchor links per version (`#v2.5.0`) allow deep-linking from release emails and in-app notifications
- Filter by category (feature/fix/breaking) for users who only care about specific change types
- `<time datetime="ISO">` for correct semantic HTML and time zone independent dates
- Subscribe mechanism (email or RSS) lets users opt into notifications without polling the page
- The in-app badge uses localStorage to track what the user has already seen
- `scroll-mt-16` on the anchor target prevents sticky nav from covering the entry header
- Changelog items are authored content — render as plain text, not HTML markup

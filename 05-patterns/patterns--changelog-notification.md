# Pattern: In-App Changelog Notification

## Overview
Users need to know when new features ship, but email announcements are often ignored and full release notes are rarely read proactively. An in-app "What's New" badge that appears on unread items brings the changelog into the flow the user is already in. Storing the "last seen version" in localStorage (not in a database) avoids a server round-trip just to render the unread badge on every page load — it's display state, not business data.

## Implementation

### Changelog Data
```tsx
interface ChangelogEntry {
  id: string
  version: string         // Semver string: "2.4.0"
  date: string            // ISO date
  title: string
  description: string
  features: string[]
  screenshotUrl?: string
  docsUrl?: string
}

// Changelog entries — newest first
const CHANGELOG: ChangelogEntry[] = [
  {
    id: 'v2-4-0',
    version: '2.4.0',
    date: '2026-05-01',
    title: 'Bulk Export & Smart Filters',
    description: 'Export multiple records at once and filter with the new hierarchical category picker.',
    features: [
      'Bulk CSV export from any table',
      'Hierarchical category filter',
      'Saved filter sets',
    ],
    screenshotUrl: '/changelog/v2-4-0-bulk-export.png',
    docsUrl: '/docs/bulk-export',
  },
  // ...
]

const CURRENT_VERSION = CHANGELOG[0].version
```

### Unread Count Hook
```tsx
const LAST_SEEN_KEY = 'changelog-last-seen-version'

function semverIsNewer(a: string, b: string): boolean {
  const parse = (v: string) => v.split('.').map(Number) as [number, number, number]
  const [aMaj, aMin, aPatch] = parse(a)
  const [bMaj, bMin, bPatch] = parse(b)
  if (aMaj !== bMaj) return aMaj > bMaj
  if (aMin !== bMin) return aMin > bMin
  return aPatch > bPatch
}

function useChangelogUnread() {
  const [lastSeenVersion, setLastSeenVersion] = useState<string | null>(() =>
    localStorage.getItem(LAST_SEEN_KEY)
  )

  const unreadCount = lastSeenVersion
    ? CHANGELOG.filter((entry) => semverIsNewer(entry.version, lastSeenVersion)).length
    : CHANGELOG.length

  const markAllRead = () => {
    setLastSeenVersion(CURRENT_VERSION)
    localStorage.setItem(LAST_SEEN_KEY, CURRENT_VERSION)
  }

  const isUnread = (entry: ChangelogEntry): boolean =>
    !lastSeenVersion || semverIsNewer(entry.version, lastSeenVersion)

  return { unreadCount, markAllRead, isUnread }
}
```

### Changelog Trigger (Nav Link)
```tsx
function ChangelogNavLink({ onClick }: { onClick: () => void }) {
  const { unreadCount } = useChangelogUnread()

  return (
    <button
      type="button"
      onClick={onClick}
      className="relative flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900"
    >
      What's New
      {unreadCount > 0 && (
        <span
          aria-label={`${unreadCount} unread`}
          className="absolute -top-1 -right-1 w-4 h-4 bg-blue-600 text-white text-xs rounded-full flex items-center justify-center leading-none"
        >
          {unreadCount > 9 ? '9+' : unreadCount}
        </span>
      )}
    </button>
  )
}
```

### Changelog Panel
```tsx
function ChangelogPanel({ isOpen, onClose }: { isOpen: boolean; onClose: () => void }) {
  const { unreadCount, markAllRead, isUnread } = useChangelogUnread()

  // Mark all read when panel opens
  useEffect(() => {
    if (isOpen && unreadCount > 0) {
      markAllRead()
    }
  }, [isOpen])

  return (
    <div
      role="dialog"
      aria-label="What's new"
      aria-hidden={!isOpen}
      className={[
        'fixed inset-y-0 right-0 w-96 bg-white shadow-xl z-50 flex flex-col',
        'transition-transform duration-300',
        isOpen ? 'translate-x-0' : 'translate-x-full',
      ].join(' ')}
    >
      <div className="flex items-center justify-between px-4 py-3 border-b">
        <h2 className="font-semibold">What's New</h2>
        <button type="button" onClick={onClose} aria-label="Close changelog">×</button>
      </div>

      <div className="flex-1 overflow-y-auto">
        {CHANGELOG.map((entry) => (
          <ChangelogEntryCard
            key={entry.id}
            entry={entry}
            isNew={isUnread(entry)}
          />
        ))}
      </div>
    </div>
  )
}
```

### Changelog Entry Card
```tsx
function ChangelogEntryCard({
  entry,
  isNew,
}: {
  entry: ChangelogEntry
  isNew: boolean
}) {
  return (
    <article className="px-4 py-5 border-b">
      <div className="flex items-start justify-between gap-2">
        <div>
          <div className="flex items-center gap-2">
            {isNew && (
              <span className="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full font-medium">
                New
              </span>
            )}
            <time className="text-xs text-gray-400" dateTime={entry.date}>
              {new Date(entry.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
            </time>
          </div>
          <h3 className="font-semibold mt-1">{entry.title}</h3>
          <p className="text-sm text-gray-600 mt-1">{entry.description}</p>
        </div>
      </div>

      {entry.screenshotUrl && (
        <img
          src={entry.screenshotUrl}
          alt={`Screenshot for ${entry.title}`}
          className="mt-3 rounded-lg border w-full object-cover"
          loading="lazy"
        />
      )}

      <ul className="mt-3 space-y-1">
        {entry.features.map((f) => (
          <li key={f} className="text-sm text-gray-700 flex items-start gap-1.5">
            <span aria-hidden="true" className="text-green-500 mt-0.5">✓</span>
            {f}
          </li>
        ))}
      </ul>

      {entry.docsUrl && (
        <a
          href={entry.docsUrl}
          className="inline-block mt-3 text-sm text-blue-600 hover:underline"
          target="_blank"
          rel="noopener noreferrer"
        >
          Read the docs →
        </a>
      )}
    </article>
  )
}
```

## Key Rules
- Store last-seen version in localStorage — this is display-only state; no database round-trip needed
- Compare versions with semver logic — string comparison (`'2.10.0' > '2.9.0'`) fails without proper parsing
- Mark all as read when the panel opens, not when the user clicks a button — requiring an explicit action to dismiss a badge is friction
- Unread badge caps at "9+" — displaying "47" unread changelog items is alarming, not informative
- Screenshots in changelog entries are far more effective than text descriptions — ship at least one per major feature
- "Docs" links open in a new tab — the user may want to reference docs while staying in the app
- Changelog entries are static data — no database needed; embed in the frontend bundle or serve as a JSON file
- Panel slides in from the right — same direction convention as detail drawers, not a center modal

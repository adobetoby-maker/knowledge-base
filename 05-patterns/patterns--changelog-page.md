# Pattern: Changelog Page

## Overview

Public changelog listing product updates by date. Good changelogs build trust and reduce support tickets. Key decisions: where data lives (markdown files vs CMS vs DB), how to categorize changes (Added/Changed/Fixed/Removed — Keep a Changelog format), and how to surface "what's new" in-app (unread dot on changelog link).

## Data Model (Markdown Files)

Store changelog entries as MDX files in `content/changelog/`:

```
content/changelog/
  2024-08-15.mdx
  2024-07-30.mdx
  2024-07-01.mdx
```

Each file:

```mdx
---
title: August 15, 2024
version: 2.4.0
tags: [performance, auth]
---

### Added
- Dashboard load time reduced by 40% with query optimization
- New SSO support for Okta and Azure AD

### Fixed
- Resolved issue where invoices showed incorrect tax amounts for EU customers
- Fixed mobile keyboard overlapping input fields on iOS 17

### Changed
- File upload limit increased from 50MB to 200MB
```

## Changelog Feed Component

```tsx
import { allChangelogs } from 'contentlayer/generated'

export default function ChangelogPage() {
  const entries = allChangelogs.sort(
    (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()
  )

  return (
    <div className="max-w-2xl mx-auto py-16 px-4">
      <h1 className="text-3xl font-bold mb-12">Changelog</h1>

      <div className="relative">
        {/* Timeline line */}
        <div className="absolute left-0 top-0 bottom-0 w-px bg-gray-200 ml-[7px]" />

        <div className="space-y-16">
          {entries.map(entry => (
            <div key={entry.date} className="relative pl-8">
              {/* Timeline dot */}
              <div className="absolute left-0 top-1.5 w-3.5 h-3.5 rounded-full bg-blue-500 border-2 border-white ring-1 ring-gray-200" />

              <div className="flex items-baseline gap-3 mb-4">
                <time className="text-sm text-gray-500 font-mono">
                  {format(new Date(entry.date), 'MMM d, yyyy')}
                </time>
                {entry.version && (
                  <span className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full font-mono">
                    v{entry.version}
                  </span>
                )}
                {entry.tags?.map(tag => (
                  <span key={tag} className="text-xs bg-blue-50 text-blue-700 px-2 py-0.5 rounded-full">
                    {tag}
                  </span>
                ))}
              </div>

              <div className="prose prose-sm max-w-none">
                <entry.Component />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
```

## Unread Indicator in Navigation

Track what the user has seen via `localStorage`:

```tsx
function ChangelogNavLink() {
  const [hasUnread, setHasUnread] = useState(false)

  useEffect(() => {
    const latestDate = LATEST_CHANGELOG_DATE  // injected at build time
    const lastSeen = localStorage.getItem('changelog-last-seen')
    setHasUnread(!lastSeen || lastSeen < latestDate)
  }, [])

  return (
    <a href="/changelog" className="relative" onClick={() => {
      localStorage.setItem('changelog-last-seen', new Date().toISOString())
      setHasUnread(false)
    }}>
      Changelog
      {hasUnread && (
        <span className="absolute -top-1 -right-1 w-2 h-2 bg-blue-500 rounded-full" />
      )}
    </a>
  )
}
```

## What's New Modal (In-App)

Show on first login after a new release:

```tsx
function WhatsNewModal() {
  const [open, setOpen] = useState(false)
  const latestVersion = useLatestVersion()  // from app config

  useEffect(() => {
    const seen = localStorage.getItem('whats-new-seen-version')
    if (seen !== latestVersion) setOpen(true)
  }, [latestVersion])

  const dismiss = () => {
    localStorage.setItem('whats-new-seen-version', latestVersion)
    setOpen(false)
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent>
        <DialogHeader><DialogTitle>What's new in v{latestVersion}</DialogTitle></DialogHeader>
        <LatestChangelogContent />
        <Button onClick={dismiss}>Got it</Button>
      </DialogContent>
    </Dialog>
  )
}
```

## Key Rules

- Follow Keep a Changelog format: **Added**, **Changed**, **Deprecated**, **Removed**, **Fixed**, **Security** — readers scan for their category.
- Write from the user's perspective: "Dashboard loads 40% faster" not "Optimized database queries".
- Date-based filenames (`2024-08-15.mdx`) sort naturally and make it obvious when to create a new entry.
- Always include a version number when shipping discrete releases — helps users correlate support issues.
- RSS feed for changelog (`/changelog.xml`) is expected by developer-audience products.

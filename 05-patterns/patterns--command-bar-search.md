# Pattern: Command Bar with Search + Recent + Actions

## Overview
A command bar (⌘K) is the power-user interface to your entire application. Without sections (recents, actions, results), it's just a search box. Without keyboard-only navigation from open to close, it excludes keyboard-heavy users. Debouncing search prevents API hammering. Persisting recents to localStorage gives users a tailored starting state on every open.

## Implementation

```tsx
// CommandBar.tsx — built on cmdk (command palette primitive)
import { Command } from 'cmdk'
import { useEffect, useState } from 'react'
import { useDebouncedCallback } from 'use-debounce'

interface Action {
  id: string
  label: string
  shortcut?: string
  icon?: React.ReactNode
  onSelect: () => void
}

interface SearchResult {
  id: string
  type: 'page' | 'user' | 'project'
  label: string
  subtitle?: string
  href?: string
  onSelect?: () => void
}

const GLOBAL_ACTIONS: Action[] = [
  { id: 'new-project',  label: 'New Project',  shortcut: '⌘N', onSelect: () => router.push('/projects/new') },
  { id: 'settings',    label: 'Settings',     shortcut: '⌘,', onSelect: () => router.push('/settings') },
  { id: 'invite',      label: 'Invite Team Member',           onSelect: () => openInviteModal() },
  { id: 'theme',       label: 'Toggle Dark Mode',             onSelect: () => toggleTheme() },
]

export function CommandBar() {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [isSearching, setIsSearching] = useState(false)
  const [recents, setRecents] = useLocalStorage<SearchResult[]>('cmd-recents', [])

  // ⌘K to open, Escape to close (cmdk handles Escape internally)
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        setOpen(prev => !prev)
      }
    }
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [])

  // Reset state when closed
  function handleOpenChange(value: boolean) {
    if (!value) {
      setQuery('')
      setResults([])
    }
    setOpen(value)
  }

  // Debounce search: 150ms — responsive without hammering the API
  const search = useDebouncedCallback(async (q: string) => {
    if (!q.trim()) {
      setResults([])
      setIsSearching(false)
      return
    }

    setIsSearching(true)
    try {
      const data = await fetchSearchResults(q)
      setResults(data)
    } finally {
      setIsSearching(false)
    }
  }, 150)

  function handleValueChange(val: string) {
    setQuery(val)
    search(val)
  }

  function handleSelect(item: SearchResult | Action) {
    if ('href' in item && item.href) {
      // Track in recents — cap at 5 items
      setRecents(prev => {
        const filtered = prev.filter(r => r.id !== item.id)
        return [item as SearchResult, ...filtered].slice(0, 5)
      })
    }

    'onSelect' in item && item.onSelect?.()
    setOpen(false)
  }

  return (
    // cmdk Dialog provides accessible modal behavior
    <Command.Dialog
      open={open}
      onOpenChange={handleOpenChange}
      label="Global command bar"
      // Loop arrow key navigation (last item → first on ArrowDown)
      loop
    >
      <div className="command-bar-overlay" onClick={() => setOpen(false)} aria-hidden />

      <div className="command-bar-panel" role="dialog" aria-label="Command bar">
        {/* Search input */}
        <Command.Input
          value={query}
          onValueChange={handleValueChange}
          placeholder="Search or run a command…"
          autoFocus
        />

        <Command.List>
          {/* Loading state */}
          {isSearching && (
            <Command.Loading>
              <div style={{ padding: '8px 12px', color: '#999' }} aria-live="polite">
                Searching…
              </div>
            </Command.Loading>
          )}

          {/* No results */}
          {!isSearching && query && results.length === 0 && (
            <Command.Empty>No results for "{query}"</Command.Empty>
          )}

          {/* SECTION 1: Recents — only when no active query */}
          {!query && recents.length > 0 && (
            <Command.Group heading="Recent">
              {recents.map(item => (
                <Command.Item
                  key={item.id}
                  value={item.id}
                  onSelect={() => handleSelect(item)}
                >
                  <span aria-hidden>🕐</span>
                  <span>{item.label}</span>
                  {item.subtitle && <span className="cmd-subtitle">{item.subtitle}</span>}
                </Command.Item>
              ))}
            </Command.Group>
          )}

          {/* SECTION 2: Global actions — always visible, filtered by query */}
          <Command.Group heading="Actions">
            {GLOBAL_ACTIONS
              .filter(a => !query || a.label.toLowerCase().includes(query.toLowerCase()))
              .map(action => (
                <Command.Item
                  key={action.id}
                  value={`action-${action.id}`}
                  onSelect={() => handleSelect(action)}
                >
                  {action.icon}
                  <span>{action.label}</span>
                  {/* Shortcut hints — right aligned */}
                  {action.shortcut && (
                    <kbd className="cmd-shortcut" aria-label={`Shortcut: ${action.shortcut}`}>
                      {action.shortcut}
                    </kbd>
                  )}
                </Command.Item>
              ))
            }
          </Command.Group>

          {/* SECTION 3: Search results — only when query is active */}
          {query && results.length > 0 && (
            <Command.Group heading="Results">
              {results.map(result => (
                <Command.Item
                  key={result.id}
                  value={result.id}
                  onSelect={() => handleSelect(result)}
                >
                  <span className="cmd-type-badge">{result.type}</span>
                  <span>{result.label}</span>
                  {result.subtitle && <span className="cmd-subtitle">{result.subtitle}</span>}
                </Command.Item>
              ))}
            </Command.Group>
          )}
        </Command.List>
      </div>
    </Command.Dialog>
  )
}
```

```css
.command-bar-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 100;
}

.command-bar-panel {
  position: fixed;
  top: 20vh;
  left: 50%;
  transform: translateX(-50%);
  width: 560px;
  max-width: 90vw;
  background: var(--color-surface);
  border-radius: 12px;
  box-shadow: 0 24px 48px rgba(0, 0, 0, 0.3);
  z-index: 101;
  overflow: hidden;
}

.cmd-shortcut {
  margin-left: auto;
  font-size: 11px;
  opacity: 0.6;
  font-family: monospace;
}

.cmd-subtitle {
  font-size: 12px;
  opacity: 0.6;
  margin-left: 8px;
}
```

## Key Rules
- Use cmdk (`cmdk` package) — it handles ARIA, keyboard navigation, and filtering. Don't build from scratch.
- ⌘K (Mac) / Ctrl+K (Windows) is the universal shortcut — intercept it globally on `document`.
- Three sections in order: Recents (no query), Actions (always), Results (with query). Never merge them.
- Debounce search at 150ms — fast enough to feel responsive, slow enough to avoid API spam.
- Persist recents in localStorage — cap at 5 items, deduplicate by ID.
- Show keyboard shortcuts next to actions — right-aligned `<kbd>` elements.
- The search input must `autoFocus` on open — users expect to type immediately without clicking.
- Resetting query and results on close prevents stale state from flashing on the next open.
- `loop` mode on the command list — ArrowDown from the last item wraps to the first.
- Close on overlay click AND on Escape (cmdk handles Escape automatically).

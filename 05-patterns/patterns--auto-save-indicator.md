# Pattern: Auto-Save Indicator

## Overview

Show save state in document editors, notes apps, and settings forms. Users need feedback that changes are persisted. Three states: unsaved/dirty, saving (in-flight), saved. The indicator should be subtle — a persistent banner is distracting; a small corner indicator is right.

## Save State Hook

```tsx
type SaveState = 'saved' | 'saving' | 'unsaved' | 'error'

function useAutoSave<T>(
  data: T,
  saveFn: (data: T) => Promise<void>,
  debounceMs = 2000,
) {
  const [saveState, setSaveState] = useState<SaveState>('saved')
  const [lastSavedAt, setLastSavedAt] = useState<Date | null>(null)
  const isFirstRender = useRef(true)
  const latestData = useRef(data)
  latestData.current = data

  const debouncedSave = useCallback(
    debounce(async (dataToSave: T) => {
      setSaveState('saving')
      try {
        await saveFn(dataToSave)
        setSaveState('saved')
        setLastSavedAt(new Date())
      } catch {
        setSaveState('error')
      }
    }, debounceMs),
    [saveFn, debounceMs],
  )

  useEffect(() => {
    if (isFirstRender.current) {
      isFirstRender.current = false
      return
    }
    setSaveState('unsaved')
    debouncedSave(data)
  }, [data])

  // Force save before unmount
  useEffect(() => () => {
    debouncedSave.flush()
  }, [])

  return { saveState, lastSavedAt }
}
```

## Save State Indicator Component

```tsx
function SaveIndicator({ saveState, lastSavedAt }: { saveState: SaveState; lastSavedAt: Date | null }) {
  return (
    <div className="flex items-center gap-1.5 text-xs text-gray-500">
      {saveState === 'saving' && (
        <>
          <span className="w-3 h-3 border-2 border-gray-400 border-t-transparent rounded-full animate-spin" />
          <span>Saving...</span>
        </>
      )}
      {saveState === 'saved' && lastSavedAt && (
        <>
          <span className="text-green-500">✓</span>
          <span>Saved {formatRelativeTime(lastSavedAt)}</span>
        </>
      )}
      {saveState === 'unsaved' && (
        <span className="text-amber-500">Unsaved changes</span>
      )}
      {saveState === 'error' && (
        <span className="text-red-500">Save failed — check connection</span>
      )}
    </div>
  )
}

function formatRelativeTime(date: Date): string {
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000)
  if (seconds < 10) return 'just now'
  if (seconds < 60) return `${seconds}s ago`
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}
```

## Debounce Implementation

```ts
function debounce<T extends (...args: unknown[]) => unknown>(fn: T, delay: number) {
  let timer: ReturnType<typeof setTimeout>
  function debounced(...args: Parameters<T>) {
    clearTimeout(timer)
    timer = setTimeout(() => fn(...args), delay)
  }
  debounced.flush = () => {
    clearTimeout(timer)
    fn(...latestArgs)
  }
  return debounced
}
```

Or use `lodash.debounce` which includes `.flush()`.

## Conflict Resolution

If multiple tabs can edit the same document, detect version conflicts:

```ts
async function saveWithConflictCheck(data: Document) {
  const res = await fetch(`/api/docs/${data.id}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'If-Match': data.etag,  // Optimistic concurrency
    },
    body: JSON.stringify(data),
  })

  if (res.status === 412) {
    // Precondition Failed — another tab saved first
    const serverVersion = await res.json()
    promptMerge(data, serverVersion)
    return
  }

  const saved = await res.json()
  updateEtag(saved.etag)
}
```

## Key Rules

- Debounce delay: 1-3 seconds for text editors, 500ms for settings toggles.
- Skip save on first render — don't save immediately when the component mounts with initial data.
- `flush()` on unmount: call the debounced save immediately when the component unmounts, or the last few keystrokes are lost.
- "Saved X ago" should update every 30 seconds so it doesn't show stale relative time.
- On save error: show retry button, not just an error message. Users will want to retry.

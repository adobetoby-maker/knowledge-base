# Pattern: Log Viewer

## Overview

Display streaming or paginated log output with level filtering, search, and auto-scroll. Common in admin dashboards, deployment pipelines, and CI/CD UIs. Key challenge: logs can arrive fast and scroll position must be managed to avoid fighting the user.

## Auto-Scroll Logic

This is the hardest part. Scroll to bottom when new logs arrive, but stop if the user has scrolled up:

```tsx
const containerRef = useRef<HTMLDivElement>(null)
const [autoScroll, setAutoScroll] = useState(true)
const autoScrollRef = useRef(true)

// Sync ref so scroll handler uses latest value
useEffect(() => { autoScrollRef.current = autoScroll }, [autoScroll])

// Scroll to bottom when logs change (if auto-scroll is on)
useEffect(() => {
  if (!autoScrollRef.current || !containerRef.current) return
  containerRef.current.scrollTop = containerRef.current.scrollHeight
}, [logs])

// Detect user scroll
function handleScroll() {
  const el = containerRef.current
  if (!el) return
  const isAtBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 50
  setAutoScroll(isAtBottom)
}
```

Show a "scroll to bottom" button when `autoScroll` is false.

## Log Line Component

```tsx
const LEVEL_STYLES: Record<string, string> = {
  error:   'text-red-400',
  warn:    'text-yellow-400',
  info:    'text-blue-300',
  debug:   'text-gray-400',
  success: 'text-green-400',
}

interface LogLine {
  id: string
  timestamp: string
  level: 'error' | 'warn' | 'info' | 'debug' | 'success'
  message: string
}

function LogLine({ line, query }: { line: LogLine; query: string }) {
  return (
    <div className={`flex gap-2 font-mono text-xs py-0.5 ${LEVEL_STYLES[line.level]}`}>
      <span className="text-gray-500 shrink-0 w-24">{formatTime(line.timestamp)}</span>
      <span className="text-gray-600 shrink-0 w-12 uppercase">{line.level}</span>
      <span className="break-all">{line.message}</span>
    </div>
  )
}
```

## Streaming via EventSource

```tsx
useEffect(() => {
  const es = new EventSource(`/api/logs/stream?jobId=${jobId}`)
  
  es.onmessage = (e) => {
    const line: LogLine = JSON.parse(e.data)
    setLogs(prev => [...prev.slice(-5000), line])  // Cap at 5000 lines
  }

  es.onerror = () => {
    es.close()
    setDone(true)
  }

  return () => es.close()
}, [jobId])
```

Keep only the last 5000 lines in state to prevent memory growth.

## Level Filter

```tsx
const [visibleLevels, setVisibleLevels] = useState(
  new Set(['error', 'warn', 'info', 'success'])
)

const filteredLogs = useMemo(() =>
  logs.filter(l => visibleLevels.has(l.level) &&
    (!query || l.message.toLowerCase().includes(query.toLowerCase()))
  ), [logs, visibleLevels, query])
```

## Search Highlight

```tsx
function highlightMatch(text: string, query: string): React.ReactNode {
  if (!query) return text
  const parts = text.split(new RegExp(`(${escapeRegex(query)})`, 'gi'))
  return (
    <>
      {parts.map((part, i) =>
        part.toLowerCase() === query.toLowerCase()
          ? <mark key={i} className="bg-yellow-500/30 text-yellow-200">{part}</mark>
          : <span key={i}>{part}</span>
      )}
    </>
  )
}
```

## ANSI Color Support

Terminal logs often contain ANSI escape codes. Strip them before rendering:

```ts
// Strip ANSI codes before storing/displaying
function stripAnsi(text: string): string {
  return text.replace(/\x1B\[[0-9;]*m/g, '')
}
```

For colored terminal output, use the `ansi-to-html` package and render via React span mapping (not raw HTML injection) or run server-side and sanitize with DOMPurify before embedding.

## Key Rules

- Cap lines in state (5000 is practical). Logs that scroll off are gone — that's expected and better than a memory leak.
- Auto-scroll only when already at the bottom. Never override user scroll position.
- Keep level toggle state in URL params if this is a shareable/bookmarkable view.
- For very high-frequency logs (>100/sec), batch state updates: accumulate lines in a buffer and flush every 100ms using `setInterval`.

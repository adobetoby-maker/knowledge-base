# Pattern: Batch Import Progress

## Overview
Batch imports of many items (CSV rows, records, files) take seconds to minutes. Users need to see real progress — not a spinner — because they need to know whether to wait or come back later. Continuing on individual item errors (rather than stopping) is almost always the right behavior for batch operations; stopping on first error wastes all prior work. A downloadable error report turns a frustrating "23 failed" message into an actionable result.

## Implementation

### Progress State
```tsx
type ImportStatus = 'idle' | 'processing' | 'complete' | 'cancelled'

interface ImportProgress {
  status: ImportStatus
  total: number
  processed: number
  succeeded: number
  failed: number
  skipped: number
  currentItem: string | null
  errors: ImportError[]
  startedAt: number | null
}

interface ImportError {
  index: number
  item: string
  reason: string
}
```

### Estimated Time Remaining
```tsx
function estimateTimeRemaining(
  startedAt: number,
  processed: number,
  total: number
): string | null {
  if (processed === 0) return null
  const elapsed = Date.now() - startedAt
  const msPerItem = elapsed / processed
  const remaining = (total - processed) * msPerItem
  if (remaining < 5000) return 'less than 5 seconds'
  if (remaining < 60000) return `about ${Math.ceil(remaining / 1000)} seconds`
  return `about ${Math.ceil(remaining / 60000)} minute${remaining > 120000 ? 's' : ''}`
}
```

### Import Runner (streams progress)
```tsx
async function runImport(
  items: ImportItem[],
  onProgress: (update: Partial<ImportProgress>) => void,
  signal: AbortSignal
) {
  onProgress({ status: 'processing', total: items.length, startedAt: Date.now() })

  let succeeded = 0
  let failed = 0
  let skipped = 0
  const errors: ImportError[] = []

  for (let i = 0; i < items.length; i++) {
    if (signal.aborted) {
      onProgress({ status: 'cancelled' })
      return
    }

    const item = items[i]
    onProgress({ processed: i + 1, currentItem: item.name })

    try {
      const result = await processItem(item)
      if (result.skipped) {
        skipped++
      } else {
        succeeded++
      }
    } catch (err) {
      failed++
      errors.push({
        index: i + 1,
        item: item.name,
        reason: err instanceof Error ? err.message : 'Unknown error',
      })
      // Continue — never abort the batch on individual item failure
    }

    onProgress({ succeeded, failed, skipped, errors })
  }

  onProgress({ status: 'complete', currentItem: null })
}
```

### Cancel with Confirmation
```tsx
function useCancelImport(controller: React.MutableRefObject<AbortController | null>) {
  const [confirming, setConfirming] = useState(false)

  const requestCancel = () => setConfirming(true)
  const confirmCancel = () => {
    controller.current?.abort()
    setConfirming(false)
  }
  const dismissCancel = () => setConfirming(false)

  return { confirming, requestCancel, confirmCancel, dismissCancel }
}
```

### Progress UI
```tsx
function ImportProgressUI({ progress }: { progress: ImportProgress }) {
  const pct = progress.total > 0
    ? Math.round((progress.processed / progress.total) * 100)
    : 0

  const eta = progress.startedAt
    ? estimateTimeRemaining(progress.startedAt, progress.processed, progress.total)
    : null

  if (progress.status === 'complete') {
    return <ImportSummary progress={progress} />
  }

  return (
    <div role="region" aria-label="Import progress" aria-live="polite">
      <div className="flex justify-between text-sm mb-1">
        <span>
          Processing {progress.processed.toLocaleString()} of {progress.total.toLocaleString()} items
        </span>
        <span className="text-gray-500">{pct}%</span>
      </div>

      <div
        role="progressbar"
        aria-valuenow={pct}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label="Import progress"
        className="h-2 bg-gray-200 rounded overflow-hidden"
      >
        <div
          className="h-full bg-blue-500 transition-all duration-300"
          style={{ width: `${pct}%` }}
        />
      </div>

      {progress.currentItem && (
        <p className="text-xs text-gray-500 mt-1 truncate">
          Current: {progress.currentItem}
        </p>
      )}

      <div className="flex items-center justify-between mt-2">
        <div className="text-xs text-gray-500 space-x-3">
          {eta && <span>~{eta} remaining</span>}
          {progress.failed > 0 && (
            <span className="text-red-500">{progress.failed} errors</span>
          )}
        </div>
        <CancelButton />
      </div>
    </div>
  )
}
```

### Summary Screen with Error Download
```tsx
function ImportSummary({ progress }: { progress: ImportProgress }) {
  const downloadErrors = () => {
    const csv = [
      'Row,Item,Error',
      ...progress.errors.map((e) =>
        `${e.index},"${e.item.replace(/"/g, '""')}","${e.reason.replace(/"/g, '""')}"`
      ),
    ].join('\n')

    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `import-errors-${Date.now()}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div>
      <h3>Import complete</h3>
      <dl className="grid grid-cols-3 gap-4 my-4">
        <div><dt>Succeeded</dt><dd className="text-green-600">{progress.succeeded}</dd></div>
        <div><dt>Failed</dt><dd className="text-red-600">{progress.failed}</dd></div>
        <div><dt>Skipped</dt><dd className="text-yellow-600">{progress.skipped}</dd></div>
      </dl>
      {progress.errors.length > 0 && (
        <button type="button" onClick={downloadErrors} className="text-sm text-blue-600 underline">
          Download error report ({progress.errors.length} rows)
        </button>
      )}
    </div>
  )
}
```

## Key Rules
- Never stop the batch on individual item failure — continue and collect errors
- Show current item name during processing — "Processing row 47" is more reassuring than a spinning bar
- Estimate time remaining after at least 1 item has processed — never show "0 seconds remaining" at the start
- Cancel button requires confirmation — accidental cancels after 80% completion are very frustrating
- Use `AbortController` for cancellation — do not use boolean flags that race with async operations
- Summary screen shows three counts: succeeded, failed, skipped — all three states happen in real imports
- Error report download is a CSV — users need to fix and re-import failed rows; they need the data in a spreadsheet
- `role="progressbar"` + `aria-valuenow` is required for screen reader progress announcements

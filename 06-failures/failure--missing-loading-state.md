# Failure: Missing Loading State

## Overview
When an async action has no visual feedback, the UI appears frozen. Users click the button again (causing double-submission), navigate away thinking it failed, or lose trust in the product. The 200ms rule: any action that takes longer than 200ms to complete needs visible feedback. Any action that takes longer than 2 seconds needs a progress indicator or message explaining what's happening. Missing loading states are the #1 cause of accidental double-submissions.

## Failure Patterns

```tsx
// BAD: no feedback — user has no idea if their click registered
function SaveButton({ onSave }: { onSave: () => Promise<void> }) {
  return (
    <button onClick={onSave}>Save</button>
  )
}

// BAD: error state handled, loading not — button still looks clickable during request
function DeleteButton({ id }: { id: string }) {
  const [error, setError] = useState<string | null>(null)
  async function handleDelete() {
    try {
      await deleteItem(id)
    } catch {
      setError('Failed to delete')
    }
  }
  return <button onClick={handleDelete}>Delete</button>  // Looks ready to click again
}
```

## Implementation

### Minimal loading state pattern

```tsx
function AsyncButton({
  onClick,
  children,
  loadingText,
}: {
  onClick: () => Promise<void>
  children: React.ReactNode
  loadingText?: string
}) {
  const [isLoading, setIsLoading] = useState(false)
  const [isSuccess, setIsSuccess] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleClick() {
    setIsLoading(true)
    setError(null)
    setIsSuccess(false)

    try {
      await onClick()
      setIsSuccess(true)
      // Reset success state after 2s
      setTimeout(() => setIsSuccess(false), 2000)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div>
      <button
        onClick={handleClick}
        disabled={isLoading}
        className={`px-4 py-2 rounded font-medium transition-colors ${
          isLoading   ? 'bg-gray-400 cursor-not-allowed' :
          isSuccess   ? 'bg-green-500 text-white' :
          error       ? 'bg-red-500 text-white' :
                        'bg-blue-600 text-white hover:bg-blue-700'
        }`}
      >
        {isLoading ? (
          <span className="flex items-center gap-2">
            <Spinner className="w-4 h-4 animate-spin" />
            {loadingText ?? 'Loading…'}
          </span>
        ) : isSuccess ? (
          <span className="flex items-center gap-2"><CheckIcon className="w-4 h-4" /> Done</span>
        ) : children}
      </button>

      {error && <p className="text-red-500 text-sm mt-1">{error}</p>}
    </div>
  )
}
```

### useMutation with TanStack Query (preferred pattern)

```tsx
// TanStack Query handles the loading/error/success states automatically
function DeleteButton({ itemId }: { itemId: string }) {
  const { mutate: deleteItem, isPending, isError, error } = useMutation({
    mutationFn: () => fetch(`/api/items/${itemId}`, { method: 'DELETE' }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['items'] })
      toast.success('Item deleted')
    },
  })

  return (
    <>
      <Button
        variant="destructive"
        onClick={() => deleteItem()}
        disabled={isPending}
      >
        {isPending ? <><Spinner className="mr-2" />Deleting…</> : 'Delete'}
      </Button>
      {isError && <p className="text-red-500 text-sm mt-1">{(error as Error).message}</p>}
    </>
  )
}
```

### Progress indicator for long operations

```tsx
function BatchImportButton({ data }: { data: Item[] }) {
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null)
  const [isDone, setIsDone] = useState(false)

  async function startImport() {
    setProgress({ done: 0, total: data.length })

    // Process in chunks
    const chunkSize = 50
    for (let i = 0; i < data.length; i += chunkSize) {
      const chunk = data.slice(i, i + chunkSize)
      await importChunk(chunk)
      setProgress({ done: Math.min(i + chunkSize, data.length), total: data.length })
    }

    setProgress(null)
    setIsDone(true)
  }

  if (isDone) return <p className="text-green-600">Import complete!</p>

  if (progress) {
    const pct = Math.round((progress.done / progress.total) * 100)
    return (
      <div className="space-y-2">
        <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
          <div className="h-full bg-blue-600 rounded-full transition-all" style={{ width: `${pct}%` }} />
        </div>
        <p className="text-sm text-gray-500">
          Importing {progress.done.toLocaleString()} of {progress.total.toLocaleString()} items…
        </p>
      </div>
    )
  }

  return (
    <Button onClick={startImport}>
      Import {data.length.toLocaleString()} items
    </Button>
  )
}
```

### Global loading indicator for page transitions

```tsx
// NProgress-style top bar for slow navigations
function TopLoadingBar() {
  const [isLoading, setIsLoading] = useState(false)
  const pathname = usePathname()

  useEffect(() => {
    setIsLoading(true)
    const timer = setTimeout(() => setIsLoading(false), 500)
    return () => clearTimeout(timer)
  }, [pathname])

  if (!isLoading) return null

  return (
    <div className="fixed top-0 left-0 right-0 h-0.5 bg-blue-600 z-50 animate-progress-bar" />
  )
}
```

## Key Rules
- Every async action needs three states: loading, error, success
- Disable the button during loading — prevents double-submission
- Re-enable on error — users need to retry
- 200ms threshold: if action takes > 200ms, show feedback immediately on click (before the response)
- 2 second threshold: if action takes > 2s, show what's happening ("Uploading 3 of 10 files…")
- Success feedback should be transient (2 seconds) — it shouldn't stay indefinitely
- TanStack Query's `isPending`/`isError`/`isSuccess` covers most cases without manual state management
- Never disable a button to indicate loading without also changing its visual appearance

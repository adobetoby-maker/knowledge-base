# Pattern: Error State with Retry

## Overview

Error states need more than an error message — they need a recovery path. The design choices: how long to wait before auto-retrying, when to stop auto-retrying and ask the user, and how to distinguish transient errors (network blip → retry) from permanent errors (404, 403 → don't retry). Getting this wrong wastes API quota (retrying a 403 forever) or frustrates users (no auto-retry on a flaky connection).

## Error Classification

Not all errors should be retried:

```ts
function isRetryable(error: unknown): boolean {
  if (error instanceof Response || (error as { status?: number }).status) {
    const status = (error as { status: number }).status
    // 4xx client errors (except 408, 429) are permanent — don't retry
    if (status >= 400 && status < 500 && status !== 408 && status !== 429) return false
    return true   // 5xx, 408 (timeout), 429 (rate limit) are retryable
  }
  // Network errors (TypeError: Failed to fetch) are retryable
  return true
}
```

## Exponential Backoff

Each retry waits longer than the last. Without backoff, simultaneous retries from many users hammer a recovering server:

```ts
function getBackoffMs(attempt: number, { base = 1000, max = 30000, jitter = true } = {}): number {
  const delay = Math.min(base * Math.pow(2, attempt), max)
  // Add ±25% jitter so retries from different clients don't synchronize
  if (jitter) return delay * (0.75 + Math.random() * 0.5)
  return delay
}

// Attempt 0: ~1s, Attempt 1: ~2s, Attempt 2: ~4s, Attempt 3: ~8s, etc.
```

## useRetry Hook

```tsx
interface RetryState {
  status: 'idle' | 'loading' | 'error' | 'success'
  error: unknown
  attempt: number
  nextRetryIn: number | null  // seconds until auto-retry
}

const MAX_AUTO_RETRIES = 3

function useRetry<T>(fn: () => Promise<T>, { autoRetry = true } = {}) {
  const [state, setState] = useState<RetryState>({
    status: 'idle', error: null, attempt: 0, nextRetryIn: null
  })
  const [data, setData] = useState<T | null>(null)
  const timerRef = useRef<ReturnType<typeof setTimeout>>()
  const countdownRef = useRef<ReturnType<typeof setInterval>>()

  async function execute(attempt = 0) {
    clearTimeout(timerRef.current)
    clearInterval(countdownRef.current)
    setState((s) => ({ ...s, status: 'loading', error: null, attempt, nextRetryIn: null }))

    try {
      const result = await fn()
      setData(result)
      setState({ status: 'success', error: null, attempt, nextRetryIn: null })
    } catch (err) {
      const retryable = isRetryable(err)
      const willAutoRetry = autoRetry && retryable && attempt < MAX_AUTO_RETRIES

      if (willAutoRetry) {
        const delayMs = getBackoffMs(attempt)
        const delaySec = Math.round(delayMs / 1000)

        setState({ status: 'error', error: err, attempt, nextRetryIn: delaySec })

        // Countdown display
        let remaining = delaySec
        countdownRef.current = setInterval(() => {
          remaining -= 1
          setState((s) => ({ ...s, nextRetryIn: remaining }))
          if (remaining <= 0) clearInterval(countdownRef.current)
        }, 1000)

        timerRef.current = setTimeout(() => execute(attempt + 1), delayMs)
      } else {
        setState({ status: 'error', error: err, attempt, nextRetryIn: null })
      }
    }
  }

  useEffect(() => () => {
    clearTimeout(timerRef.current)
    clearInterval(countdownRef.current)
  }, [])

  return { ...state, data, run: () => execute(0), retry: () => execute(state.attempt + 1) }
}
```

## Error UI Component

```tsx
function ErrorWithRetry({ error, attempt, nextRetryIn, onRetry }: {
  error: unknown
  attempt: number
  nextRetryIn: number | null
  onRetry: () => void
}) {
  const retryable = isRetryable(error)
  const exhausted = attempt >= MAX_AUTO_RETRIES

  const message = getErrorMessage(error)  // Human-readable extraction

  return (
    <div role="alert" className="rounded-lg border border-red-200 bg-red-50 p-4">
      <div className="flex gap-3">
        <AlertCircleIcon className="text-red-500 flex-shrink-0 mt-0.5" />
        <div className="flex-1">
          <p className="font-medium text-red-800">Something went wrong</p>
          <p className="text-sm text-red-700 mt-1">{message}</p>

          {nextRetryIn !== null && (
            <p className="text-sm text-red-600 mt-2">
              Retrying in {nextRetryIn}s... (attempt {attempt + 1} of {MAX_AUTO_RETRIES})
            </p>
          )}

          <div className="flex gap-2 mt-3">
            {retryable && (
              <button
                type="button"
                onClick={onRetry}
                className="text-sm font-medium text-red-700 hover:text-red-900"
              >
                {nextRetryIn !== null ? 'Retry now' : 'Try again'}
              </button>
            )}

            {exhausted && (
              <a
                href="/support"
                className="text-sm text-gray-600 hover:underline"
              >
                Contact support
              </a>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
```

## Escalation Path

After `MAX_AUTO_RETRIES` automatic retries fail, stop trying and offer a manual path. Always show a "Contact support" link at this point — the user may have hit a real bug, not a transient failure:

```tsx
{exhausted && (
  <p className="text-xs text-gray-500 mt-2">
    Tried {MAX_AUTO_RETRIES} times. If this keeps happening,{' '}
    <a href="/support">contact support</a> with error code: {errorCode}.
  </p>
)}
```

Include an error code or correlation ID in the escalation message so support can look it up.

## Key Rules

- Classify errors before retrying: 4xx (except 408/429) are permanent — never auto-retry them.
- Use exponential backoff with jitter — linear retries without jitter cause thundering herd.
- Max 3 auto-retries before stopping and requiring manual action.
- Show a countdown to next auto-retry so users know the system is working, not frozen.
- Always provide a manual "Try again" button even during auto-retry — some users won't wait.
- After exhausting retries, show a "contact support" link with an error code for debugging context.

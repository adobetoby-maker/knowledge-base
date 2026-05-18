# Pattern: Async Button

## Overview

A button that triggers an async operation shows loading state during the operation, prevents double-submission, and communicates success or failure. Getting this wrong causes duplicate orders, wasted API calls, or confusing feedback.

## Core Implementation

```tsx
type AsyncButtonState = 'idle' | 'loading' | 'success' | 'error'

interface AsyncButtonProps {
  onClick: () => Promise<void>
  children: React.ReactNode
  successLabel?: string
  className?: string
}

export function AsyncButton({ onClick, children, successLabel, className }: AsyncButtonProps) {
  const [state, setState] = useState<AsyncButtonState>('idle')

  async function handleClick() {
    if (state === 'loading') return  // prevent double-click
    setState('loading')
    try {
      await onClick()
      setState('success')
      if (successLabel) {
        setTimeout(() => setState('idle'), 2000)
      }
    } catch {
      setState('error')
      setTimeout(() => setState('idle'), 3000)
    }
  }

  return (
    <button
      onClick={handleClick}
      disabled={state === 'loading'}
      aria-busy={state === 'loading'}
      className={className}
    >
      {state === 'loading' && <Spinner className="mr-2 h-4 w-4 animate-spin" />}
      {state === 'success' && successLabel ? successLabel : children}
      {state === 'error' && 'Try again'}
      {state === 'idle' && children}
    </button>
  )
}
```

## With React Hook Form

```tsx
// Submit button tied to form state — avoids duplicating state
function SubmitButton({ children }: { children: React.ReactNode }) {
  const { formState: { isSubmitting } } = useFormContext()

  return (
    <button type="submit" disabled={isSubmitting} aria-busy={isSubmitting}>
      {isSubmitting ? <Spinner /> : children}
    </button>
  )
}
```

## Destructive Actions

Destructive async actions (delete, cancel, irreversible) need extra care:

```tsx
function DeleteButton({ onDelete }: { onDelete: () => Promise<void> }) {
  const [confirming, setConfirming] = useState(false)
  const [deleting, setDeleting] = useState(false)

  if (!confirming) {
    return (
      <button onClick={() => setConfirming(true)} className="text-red-600">
        Delete
      </button>
    )
  }

  return (
    <div className="flex gap-2">
      <button
        onClick={async () => {
          setDeleting(true)
          await onDelete()
        }}
        disabled={deleting}
        className="bg-red-600 text-white"
      >
        {deleting ? 'Deleting...' : 'Confirm delete'}
      </button>
      <button onClick={() => setConfirming(false)}>Cancel</button>
    </div>
  )
}
```

## Server Action Pattern (Next.js)

```tsx
import { useTransition } from 'react'

function SaveButton({ action }: { action: () => Promise<void> }) {
  const [isPending, startTransition] = useTransition()

  return (
    <button
      onClick={() => startTransition(action)}
      disabled={isPending}
    >
      {isPending ? 'Saving...' : 'Save'}
    </button>
  )
}
```

`useTransition` marks the update as non-urgent — React can interrupt it. The UI stays responsive during the transition.

## Key Rules

- Guard against double-click at the top of the handler — check `state === 'loading'` before proceeding.
- Use `aria-busy` so screen readers announce loading state.
- Always reset to `idle` after success/error (with a timeout) — leave the user able to try again.
- For destructive actions, require explicit confirmation before the async call starts.
- Use `useTransition` for Server Actions — it handles the pending state at the React level, not component level.

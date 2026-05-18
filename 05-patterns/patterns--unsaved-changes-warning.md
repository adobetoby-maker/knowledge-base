# Pattern: Unsaved Changes Warning

## Overview

Warn users before navigating away from a form with unsaved changes. Two surfaces: browser's native `beforeunload` (tab close, external navigation, refresh) and in-app navigation (router link clicks). Both are required — you can't rely on just one.

## Browser beforeunload

```tsx
function useBeforeUnload(isDirty: boolean) {
  useEffect(() => {
    if (!isDirty) return

    function handler(e: BeforeUnloadEvent) {
      e.preventDefault()
      // Modern browsers ignore the custom message and show generic text
      e.returnValue = ''
    }

    window.addEventListener('beforeunload', handler)
    return () => window.removeEventListener('beforeunload', handler)
  }, [isDirty])
}
```

**Browser limitation**: you cannot customize the dialog text in modern browsers. The browser shows its own generic "Changes you made may not be saved" message.

## Router Navigation Warning (Next.js App Router)

Next.js App Router doesn't expose a `router.beforeEach` hook. Work around with a custom navigation interceptor:

```tsx
'use client'
import { useEffect, useCallback } from 'react'
import { useRouter } from 'next/navigation'

function useNavigationGuard(isDirty: boolean, message = 'You have unsaved changes. Leave anyway?') {
  const router = useRouter()

  useEffect(() => {
    if (!isDirty) return

    // Intercept Next.js link clicks before they navigate
    function handleClick(e: MouseEvent) {
      const anchor = (e.target as Element).closest('a')
      if (!anchor) return
      
      const href = anchor.getAttribute('href')
      if (!href || href.startsWith('#') || href.startsWith('mailto:')) return
      if (!isDirty) return
      
      e.preventDefault()
      if (window.confirm(message)) {
        window.location.href = href  // Hard navigate after confirmation
      }
    }

    document.addEventListener('click', handleClick, true)
    return () => document.removeEventListener('click', handleClick, true)
  }, [isDirty, message])
}
```

For client-side router navigation, use `router.push` interception:

```tsx
// Replace router.push calls with a guarded version
function useSafeRouter(isDirty: boolean) {
  const router = useRouter()

  function push(href: string) {
    if (!isDirty || window.confirm('You have unsaved changes. Leave anyway?')) {
      router.push(href)
    }
  }

  return { push, replace: router.replace }
}
```

## Form with Dirty Tracking

```tsx
function EditForm({ initialData }: { initialData: FormData }) {
  const form = useForm({ defaultValues: initialData })
  const isDirty = form.formState.isDirty

  useBeforeUnload(isDirty)
  useNavigationGuard(isDirty)

  async function onSubmit(data: FormData) {
    await saveData(data)
    form.reset(data)  // Reset dirty state after save
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      {isDirty && (
        <div className="flex items-center gap-2 text-sm text-amber-600">
          <span>⚠</span>
          <span>You have unsaved changes</span>
        </div>
      )}
      {/* form fields */}
    </form>
  )
}
```

## Auto-Save Alternative

For long-form content (blog editors, document editors), auto-save is better than the warning:

```ts
// Debounce saves — don't save every keystroke
const debouncedSave = useDebouncedCallback(async (data) => {
  await saveDraft(data)
  setLastSaved(new Date())
}, 2000)

// In form onChange handler
debouncedSave(watchedValues)
```

Show "Auto-saved X seconds ago" indicator. Eliminates the need for unsaved-changes warnings entirely.

## Key Rules

- Both `beforeunload` and router guard are required — one doesn't cover the other.
- `beforeunload` fires for browser close, refresh, and external links; router guard covers internal navigation.
- `window.confirm` is synchronous and blocks — use only for router navigation guard; don't use for async operations.
- `form.reset(data)` after successful save resets `formState.isDirty` to false — always do this.

# Popover Form (Quick Add / Inline Edit)

## When to Use a Popover Form vs a Modal

A popover form is anchored to a trigger element and stays close to the user's current context. Use it for quick, focused edits with 2–4 fields (add a tag, rename an item, set a due date + note). If the form has more than 4–5 fields, or requires confirmation before destructive action, use a full modal instead — a popover that requires excessive scrolling or has a complex layout defeats its purpose.

## Positioning with floating-ui

`@floating-ui/react` (or its `@floating-ui/react-dom` headless core) provides anchor-aware positioning that handles viewport edges automatically. Radix UI's `<Popover>` wraps floating-ui internally — prefer Radix unless you need fully custom behavior.

```tsx
// Using Radix Popover — handles positioning, focus trap, and close-on-outside-click
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'

<Popover open={open} onOpenChange={handleOpenChange}>
  <PopoverTrigger asChild>
    <Button variant="ghost" size="sm">+ Add item</Button>
  </PopoverTrigger>
  <PopoverContent className="w-80" align="start" side="bottom">
    <QuickAddForm onSuccess={() => setOpen(false)} />
  </PopoverContent>
</Popover>
```

`align="start"` + `side="bottom"` is the most common default. Radix flips the popover automatically when there isn't room on the preferred side — you don't need to handle this yourself.

## Focus Trap

Radix `PopoverContent` activates a focus trap automatically when opened. The first focusable element inside receives focus immediately. If building without Radix, use `focus-trap-react` or the `@radix-ui/react-focus-trap` primitive directly.

Why it matters: Without a focus trap, keyboard users can Tab out of the popover into background content — an accessibility violation (WCAG 2.1 SC 2.1.2).

```tsx
// Inside the popover, ensure first interactive element is meaningful
// Don't set autoFocus on the submit button — focus the first text input
<input ref={firstInputRef} autoFocus name="title" ... />
```

## Form Reset on Close

The form state should reset every time the popover closes, whether closed by submit, Escape, or outside click. This prevents stale data appearing on next open.

```tsx
const handleOpenChange = (nextOpen: boolean) => {
  setOpen(nextOpen)
  if (!nextOpen) {
    form.reset()  // react-hook-form reset
  }
}
```

If you initialize with existing values (edit mode), pass them back as `defaultValues` on open, not on mount — so re-opening after a partial edit doesn't show dirty state.

## Submit Closes, Error Does Not

The pattern that trips up most implementations: on success, close the popover. On validation error or server error, stay open and show the error inline. Never close the popover when an error occurs — the user needs to see and fix the problem.

```tsx
const onSubmit = async (data: FormData) => {
  try {
    await createItem(data)
    setOpen(false)          // close only on success
    toast.success('Added')
  } catch (err) {
    form.setError('root', { message: err.message })
    // popover stays open — error displayed below form fields
  }
}
```

Display root-level server errors in a `<p className="text-destructive text-sm">` block below the fields, above the submit button. Don't use toast for inline form errors inside a popover — the toast disappears and the user may not connect it to the popover.

## Handling Escape Key

Radix handles Escape automatically (closes popover). If there are unsaved changes, intercept the close:

```tsx
const handleOpenChange = (nextOpen: boolean) => {
  if (!nextOpen && form.formState.isDirty) {
    // Don't close — show a "discard changes?" prompt inside the popover
    // Or close immediately if the action is low-stakes
    return
  }
  setOpen(nextOpen)
  if (!nextOpen) form.reset()
}
```

For low-stakes forms (filtering, quick tags), don't block Escape. For edits to important data, confirm before discarding.

## Key Rules

- Popover forms are for 2–4 fields; anything larger belongs in a modal — enforcing this prevents scope creep that breaks the UX
- Never use `z.optional()` to work around a missing focus trap — always trap focus inside the popover
- `form.reset()` must fire on close, not just on submit, to handle Escape and outside-click dismissals
- Display server errors *inside* the popover, not as toasts — toasts disappear before the user processes the error
- Close on success, stay open on error — the opposite of both cases causes frustration or data loss

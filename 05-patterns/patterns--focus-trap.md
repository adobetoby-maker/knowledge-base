# Pattern: Keyboard Focus Trap

## What This Solves

When a modal, drawer, or dialog opens, keyboard focus must stay inside it. Without a trap, Tab navigates to elements behind the overlay — the user "escapes" to hidden or obscured content, which is both confusing and a WCAG 2.1 Level AA failure (criterion 2.1.2). Screen reader users experience this as navigating through invisible content.

## Why This Is Mandatory

WCAG 2.1 criterion 2.1.2 requires that if keyboard focus moves into a component, the user can navigate out only using a known key (Escape) — not by tabbing past the end. For modals, this means all Tab and Shift+Tab presses must cycle within the focusable elements inside the dialog. Failure means keyboard-only users and screen reader users cannot use the dialog at all.

## Using focus-trap-react

Install: `npm i focus-trap-react`

```tsx
import FocusTrap from 'focus-trap-react'

function Modal({ open, onClose, children }: ModalProps) {
  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        className="fixed inset-0 bg-black/50"
        onClick={onClose}
        aria-hidden="true"
      />
      <FocusTrap
        focusTrapOptions={{
          // Focus the first focusable element when trap activates
          initialFocus: undefined, // defaults to first tabbable
          // Return focus to the element that opened the modal
          returnFocusOnDeactivate: true,
          // Allow clicking outside to close (backdrop click handled above)
          clickOutsideDeactivates: false,
          // Escape key deactivates trap AND calls onClose
          onDeactivate: onClose,
          escapeDeactivates: true,
        }}
      >
        <div
          role="dialog"
          aria-modal="true"
          className="relative bg-background rounded-lg shadow-xl max-w-lg w-full p-6 z-10"
        >
          {children}
        </div>
      </FocusTrap>
    </div>
  )
}
```

## Initial Focus Placement

Default: focus-trap-react focuses the first tabbable element. This is usually correct (a form's first input or the close button).

When to override with `initialFocus`:
- Destructive confirmation dialogs: focus the "Cancel" button, not "Delete" — prevents accidental keyboard confirmation
- Long-form modals: focus the first input field, not a close icon at the top
- Informational dialogs: focus the primary action button

```tsx
focusTrapOptions={{
  initialFocus: '#modal-cancel-btn',
  // or a function returning an element:
  initialFocus: () => document.querySelector('[data-autofocus]') as HTMLElement,
}}
```

## Return Focus on Close

When the modal closes, focus must return to the element that triggered it — typically a button. This is handled by `returnFocusOnDeactivate: true` (default in focus-trap-react). If the trigger element may have been removed from the DOM by the time the modal closes, pass the element ref explicitly:

```tsx
const triggerRef = useRef<HTMLButtonElement>(null)

focusTrapOptions={{
  setReturnFocus: () => triggerRef.current ?? document.body,
}}
```

## Manual Implementation (Without Library)

When you cannot use focus-trap-react (bundle constraints, Headless UI already managing focus):

```ts
function getFocusableElements(container: HTMLElement): HTMLElement[] {
  return Array.from(
    container.querySelectorAll<HTMLElement>(
      'a[href],button:not([disabled]),input:not([disabled]),select,textarea,[tabindex]:not([tabindex="-1"])'
    )
  ).filter(el => !el.closest('[hidden]'))
}

function handleTabKey(e: KeyboardEvent, container: HTMLElement) {
  const els = getFocusableElements(container)
  if (!els.length) return
  const first = els[0]
  const last = els[els.length - 1]

  if (e.shiftKey) {
    if (document.activeElement === first) {
      e.preventDefault()
      last.focus()
    }
  } else {
    if (document.activeElement === last) {
      e.preventDefault()
      first.focus()
    }
  }
}
```

## Stacked Modals

When a second modal opens over the first, deactivate the first trap and activate the second. On close of the second, reactivate the first. focus-trap-react handles this via the `paused` prop:

```tsx
<FocusTrap active={isActive} paused={isPaused}>
```

## Key Rules

- Every modal, dialog, and drawer must have a focus trap — no exceptions
- Return focus to the trigger element when the dialog closes
- Default initial focus to the first tabbable element; override only for destructive dialogs (focus Cancel)
- Escape key must close the modal AND deactivate the trap
- Do not set `tabIndex={-1}` on the dialog container — that hides it from the trap's tabbable scan
- `aria-modal="true"` on the dialog element tells screen readers to ignore content outside it (some SRs don't honor this; the focus trap is still required)

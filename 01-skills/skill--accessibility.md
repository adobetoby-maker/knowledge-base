# Skill: accessibility

**Trigger:** Building UI components that need to be accessible — forms, modals, navigation, interactive elements.
**Returns:** ARIA patterns, keyboard navigation, focus management, screen reader considerations.

## Core Principles

1. **Semantic HTML first.** A `<button>` is better than `<div role="button">`. Semantic elements have built-in accessibility. Use ARIA only when native semantics are insufficient.

2. **Keyboard navigability.** Every interactive element must be reachable and operable by keyboard alone.

3. **Visible focus.** Never remove focus rings entirely. Style them to match your design, but they must exist.

4. **Color alone is not sufficient.** Don't use color as the only indicator of state (error, success, active).

## Interactive Element Checklist

```
[ ] Can every button/link/input be reached with Tab?
[ ] Can every button/link/input be activated with Enter or Space?
[ ] Does focus return to the trigger when a modal closes?
[ ] Are all images decorative or have alt text?
[ ] Do all form inputs have associated <label> elements?
[ ] Are error messages programmatically associated with their inputs?
[ ] Does the page have a logical heading hierarchy (h1 → h2 → h3)?
```

## Form Accessibility

```typescript
// Correct — label associated with input via htmlFor + id
<div>
  <label htmlFor="email">Email address</label>
  <input
    id="email"
    type="email"
    aria-describedby={error ? 'email-error' : undefined}
    aria-invalid={error ? 'true' : undefined}
  />
  {error && (
    <p id="email-error" role="alert">
      {error}
    </p>
  )}
</div>
```

`role="alert"` causes screen readers to announce the message when it appears. Use it for error messages and important status updates.

## Modal/Dialog Accessibility

```typescript
// When a modal opens:
// 1. Trap focus inside the modal
// 2. Move focus to the first focusable element inside
// 3. When closed, return focus to the trigger

import { useRef, useEffect } from 'react'

function Modal({ isOpen, onClose, triggerRef, children }) {
  const modalRef = useRef<HTMLDivElement>(null)
  
  useEffect(() => {
    if (isOpen) {
      // Move focus into modal
      const firstFocusable = modalRef.current?.querySelector<HTMLElement>(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      )
      firstFocusable?.focus()
    } else {
      // Return focus to trigger
      triggerRef.current?.focus()
    }
  }, [isOpen])
  
  return (
    <div
      ref={modalRef}
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
    >
      {children}
    </div>
  )
}
```

Use the `<dialog>` HTML element when possible — it handles focus trapping natively in modern browsers.

## ARIA Labels

```typescript
// Button with icon only — must have accessible label
<button aria-label="Close dialog">
  <XIcon aria-hidden="true" />  // hide icon from screen readers
</button>

// Button with visible text — no aria-label needed
<button>
  <XIcon aria-hidden="true" />
  Close
</button>

// Expand/collapse pattern
<button
  aria-expanded={isOpen}
  aria-controls="menu-list"
>
  Menu
</button>
<ul id="menu-list" hidden={!isOpen}>
  {items}
</ul>
```

## Skip Links

For pages with navigation, provide a skip link so keyboard users can skip to main content:

```typescript
// app/layout.tsx
<a
  href="#main-content"
  className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 bg-white p-2 z-50"
>
  Skip to main content
</a>
<main id="main-content">
  {children}
</main>
```

The `sr-only` class hides visually until focused (Tailwind utility).

## Focus Styles

```css
/* Never do this — removes all focus indicators */
:focus { outline: none; }
*:focus { outline: 0; }

/* Acceptable — replace with custom style */
:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}
```

`:focus-visible` applies only to keyboard focus (not mouse clicks), avoiding the "ring shows on click" problem without removing it for keyboard users.

## Reduced Motion

```typescript
import { useReducedMotion } from 'framer-motion'

function AnimatedHero() {
  const shouldReduceMotion = useReducedMotion()
  
  return (
    <motion.div
      animate={{ opacity: 1, y: 0 }}
      initial={{ opacity: shouldReduceMotion ? 1 : 0, y: shouldReduceMotion ? 0 : 20 }}
      transition={{ duration: shouldReduceMotion ? 0 : 0.5 }}
    >
      {children}
    </motion.div>
  )
}
```

CSS equivalent:
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Color Contrast Requirements

WCAG AA (minimum standard):
- Normal text: 4.5:1 contrast ratio with background
- Large text (18pt+ or 14pt+ bold): 3:1 ratio
- Interactive elements (focus indicators, borders): 3:1 ratio

Check with: browser DevTools accessibility inspector, or axe DevTools browser extension.

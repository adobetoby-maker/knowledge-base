# QA: Accessibility Checklist

## Overview

Accessibility (a11y) ensures the UI works for users with disabilities: screen readers, keyboard navigation, motor impairments, low vision. WCAG 2.1 AA is the standard for most web apps. These are the most common failures discovered in audits.

## Keyboard Navigation

```tsx
// Every interactive element must be reachable via Tab key
// Focus must be visible (never just remove outline — add a custom style)

// BAD — removes focus without replacement
button { outline: none }

// GOOD — custom focus style
button:focus-visible {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
}
```

```tsx
// Modal: trap focus inside, return focus on close
function Modal({ open, onClose, children }: ModalProps) {
  const firstFocusRef = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    if (open) firstFocusRef.current?.focus()
  }, [open])

  return open ? (
    <div role="dialog" aria-modal="true" aria-label="Dialog">
      <button ref={firstFocusRef} onClick={onClose}>Close</button>
      {children}
    </div>
  ) : null
}
```

## ARIA Labels

```tsx
// Icon buttons must have accessible labels
<button aria-label="Delete account">
  <TrashIcon />
</button>

// Inputs should have associated labels (not just placeholder)
// BAD — placeholder is not a label
<input placeholder="Email address" />

// GOOD
<label htmlFor="email">Email address</label>
<input id="email" type="email" />

// Or aria-label
<input aria-label="Email address" type="email" />
```

## Color Contrast

Minimum contrast ratios (WCAG AA):
- Normal text (< 18pt): 4.5:1
- Large text (≥ 18pt or 14pt bold): 3:1
- UI components (buttons, inputs): 3:1

```ts
// Test in Tailwind: check bg/text combinations
// bg-gray-500 (#6b7280) on white: 4.6:1 ✓ (barely passes)
// bg-gray-400 (#9ca3af) on white: 2.85:1 ✗ (fails for body text)

// Common failure: disabled state text
// BAD — gray-300 on white is 1.78:1
<button disabled className="text-gray-300">Submit</button>

// GOOD — gray-500 minimum for disabled
<button disabled className="text-gray-500 cursor-not-allowed">Submit</button>
```

## Images

```tsx
// Decorative images: alt=""
<img src="/decorative-pattern.png" alt="" />

// Informational images: descriptive alt
<img src="/revenue-chart.png" alt="Monthly revenue from Jan–Jun 2026, trending up 40%" />

// Never use filename or "image of" in alt text
// BAD: alt="photo_23.jpg" or alt="Image of a chart"
// GOOD: alt="Bar chart showing user growth from 100 to 850 over 6 months"
```

## Form Errors

```tsx
// Error messages must be associated with their input
function FormField({ id, label, error, ...inputProps }: FormFieldProps) {
  return (
    <div>
      <label htmlFor={id}>{label}</label>
      <input
        id={id}
        aria-describedby={error ? `${id}-error` : undefined}
        aria-invalid={error ? 'true' : undefined}
        {...inputProps}
      />
      {error && (
        <p id={`${id}-error`} role="alert" className="text-red-500 text-sm">
          {error}
        </p>
      )}
    </div>
  )
}
```

## Live Regions (Dynamic Content)

```tsx
// Announce dynamic updates to screen readers
function StatusMessage({ status }: { status: string }) {
  return (
    <div
      role="status"
      aria-live="polite"
      aria-atomic="true"
      className="sr-only"  // Visually hidden but read by screen reader
    >
      {status}
    </div>
  )
}

// For urgent alerts: aria-live="assertive" (interrupts)
// For non-urgent: aria-live="polite" (waits)
```

## Semantic HTML

```tsx
// Use semantic HTML first — ARIA is a last resort for custom widgets

// BAD — div with role
<div role="button" onClick={handleClick}>Submit</div>

// GOOD — native element
<button onClick={handleClick}>Submit</button>

// Navigation landmark
<nav aria-label="Main navigation">
  <ul>
    <li><a href="/">Home</a></li>
  </ul>
</nav>

// Page regions
<header>
<main>
<footer>
<aside aria-label="Related articles">
```

## Skip Links

```tsx
// Allow keyboard users to skip navigation
// Place as the first element in <body>
<a href="#main-content" className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-50 focus:bg-white focus:px-4 focus:py-2 focus:rounded">
  Skip to main content
</a>

<main id="main-content">
```

## Quick Audit Checklist

```
☐ Tab through entire page — every interactive element reachable?
☐ Focus indicator visible on all focused elements?
☐ All images have alt text (or alt="" if decorative)?
☐ Color contrast ≥ 4.5:1 for normal text?
☐ Form inputs have associated labels?
☐ Error messages associated with inputs (aria-describedby)?
☐ Modal traps focus and returns focus on close?
☐ Icon-only buttons have aria-label?
☐ Dynamic content changes announced via aria-live?
☐ Page has a skip link?
☐ Headings in logical order (h1 → h2 → h3)?
```

## Key Rules

- `focus-visible` (not `focus`) for focus styles — `focus` triggers on mouse clicks too, which is visually distracting.
- `role="alert"` with `aria-live="assertive"` is for errors; `role="status"` with `aria-live="polite"` is for non-urgent updates.
- `aria-invalid="true"` signals invalid state to screen readers — pair with `aria-describedby` pointing to the error message.
- Semantic HTML is always preferable to ARIA — `<button>` beats `<div role="button">` because it gets keyboard handling, focus management, and type inference for free.
- Test with a real screen reader (VoiceOver on Mac, NVDA on Windows) — automated tools catch only 30-40% of accessibility issues.

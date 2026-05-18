# Accessibility Review Checklist

## Why Accessibility Matters for These Projects

jrs-auto-repair serves a general public audience including elderly customers. language-lens-elite has learners with different abilities. All sites should meet WCAG 2.1 AA standard.

## Keyboard Navigation

- [ ] All interactive elements are keyboard-reachable (Tab key)
- [ ] Tab order follows visual reading order (left-to-right, top-to-bottom)
- [ ] Focus indicator is visible (no `outline: none` without custom focus style)
- [ ] Modals/dialogs trap focus (Tab cycles inside modal, not rest of page)
- [ ] Escape closes modals and dropdowns
- [ ] No keyboard traps (focus can leave all components)

```typescript
// Focus visible style (never remove focus indicator without replacement)
// In globals.css:
*:focus-visible {
  outline: 2px solid hsl(var(--ring));
  outline-offset: 2px;
}
```

## Semantic HTML

- [ ] Page has one `<h1>` (the main page title)
- [ ] Heading hierarchy is logical (h1 → h2 → h3, no skipping)
- [ ] Navigation is in a `<nav>` element
- [ ] Form fields have associated `<label>` (htmlFor + id match)
- [ ] Lists use `<ul>/<ol>/<li>` (not div-based fake lists)
- [ ] Main content in `<main>`, footer in `<footer>`

## ARIA Labels

- [ ] Icon-only buttons have `aria-label`
- [ ] Images have meaningful `alt` text (or `alt=""` for decorative)
- [ ] Form error messages linked with `aria-describedby`
- [ ] Loading states announced with `aria-live`
- [ ] Expanded/collapsed state on accordions uses `aria-expanded`

```typescript
// Icon button — needs aria-label
<button aria-label="Delete invoice">
  <Trash2 className="h-4 w-4" aria-hidden="true" />
</button>

// Error message — linked to input
<input
  id="customer_name"
  aria-describedby={error ? "customer_name_error" : undefined}
  aria-invalid={!!error}
/>
{error && (
  <p id="customer_name_error" role="alert" className="text-sm text-red-500">
    {error}
  </p>
)}

// Loading announcement
<div aria-live="polite" aria-atomic="true">
  {isLoading && <span>Loading invoices...</span>}
</div>
```

## Color and Contrast

- [ ] Text contrast ratio ≥ 4.5:1 (normal text) or 3:1 (large text)
- [ ] UI components and focus indicators have ≥ 3:1 contrast
- [ ] Information not conveyed by color alone (error state has icon + text, not just red color)
- [ ] Links distinguishable from surrounding text (underline or stronger contrast)

Test with: axe DevTools browser extension, or WebAIM Contrast Checker.

## Touch Targets (Mobile)

- [ ] Interactive elements are at least 44×44px (48×48px preferred)
- [ ] Sufficient spacing between tap targets (no accidental taps)
- [ ] Form inputs have `font-size: 16px` minimum (prevents iOS zoom on focus)

## Forms

- [ ] Required fields indicated (with `required` attribute + visible indicator)
- [ ] Error messages describe what's wrong AND how to fix it
- [ ] Form can be submitted with Enter key
- [ ] No timeout on form sessions (or warning + extension option)
- [ ] Autocomplete attributes on common fields (`autocomplete="name"`, `autocomplete="email"`)

## Reduced Motion

- [ ] Animations respect `prefers-reduced-motion`

```typescript
// With Framer Motion
import { useReducedMotion } from 'framer-motion'

export function AnimatedCard({ children }) {
  const prefersReduced = useReducedMotion()
  
  return (
    <motion.div
      initial={{ opacity: 0, y: prefersReduced ? 0 : 20 }}
      animate={{ opacity: 1, y: 0 }}
    >
      {children}
    </motion.div>
  )
}
```

```css
/* CSS fallback */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Automated Testing

Run automated accessibility checks:
```bash
# Install axe-core for browser testing
npm install --save-dev @axe-core/playwright

# Or use the built-in Lighthouse check:
# Chrome DevTools → Lighthouse → Accessibility
```

shadcn/ui components are built on Radix UI primitives which handle most ARIA patterns automatically (dialog focus trap, combobox keyboard navigation, etc.).

# Accessibility Audit — WCAG Compliance

**When:** After building any public-facing page. Accessibility is a legal requirement for many sites, and also a ranking signal for Google.
**Rule:** Four categories cover 90% of issues — Perceivable, Operable, Understandable, Robust (POUR).

## Automated Check First
```javascript
// Lighthouse includes accessibility audit
mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit({
  categories: ["accessibility"]
})
// Score > 90 is good; 100 is achievable for most pages
```

## Manual Checklist

### Images
- [ ] All `<img>` have `alt` attributes (even decorative ones: `alt=""`)
- [ ] Alt text describes the content, not "image of..." or filename
- [ ] Complex images (charts, diagrams) have long description nearby

### Color Contrast
Minimum ratios (WCAG AA):
```
Normal text (< 18px): 4.5:1
Large text (>= 18px or 14px bold): 3:1
Interactive elements (focus indicator): 3:1
```
Test in Chrome DevTools: Inspect element → computed → contrast ratio shown.

### Keyboard Navigation
- [ ] Every interactive element reachable by Tab key
- [ ] Focus indicator visible (outline: ring visible on buttons/links/inputs)
- [ ] No "keyboard trap" — Tab always moves forward, can't escape a modal
- [ ] Modal/dialog: focus moves into it on open, returns to trigger on close

### Headings
- [ ] One `<h1>` per page
- [ ] No skipped levels (h1 → h3, skipping h2 = wrong)
- [ ] Headings describe their section content, not used for visual styling

### Forms
- [ ] Every input has a `<label>` associated via `htmlFor` + `id`
- [ ] Required fields marked with `required` attribute AND visual indicator
- [ ] Error messages describe what's wrong and how to fix it
- [ ] Autocomplete attributes set where appropriate (`autocomplete="email"`)

### ARIA
```typescript
// When a button has only an icon (no text)
<button aria-label="Close dialog">
  <X className="h-4 w-4" />
</button>

// Live regions — screen reader reads updates
<div role="alert" aria-live="polite">
  {errorMessage}
</div>

// Skip to main content (first element in page)
<a href="#main" className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4">
  Skip to main content
</a>
<main id="main">
```

### Interactive States
- [ ] Buttons look and feel clickable (not just visually — cursor: pointer, focus ring)
- [ ] Links are distinguishable from body text (underline or different color with 3:1 contrast)
- [ ] Disabled state is communicated (aria-disabled or disabled attribute)

## Tailwind Accessibility Utilities
```html
<!-- Screen reader only (hidden visually, read by screen readers) -->
<span class="sr-only">Loading...</span>

<!-- Visible only on focus (skip links) -->
<a class="sr-only focus:not-sr-only" href="#main">Skip to content</a>

<!-- Focus ring (ensure not removed) -->
<button class="focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
```
NEVER do `outline: none` without providing a visible alternative focus indicator.

## Most Common Fails in This Stack
1. Icon buttons without `aria-label` — very common with shadcn icon-only buttons
2. Missing form labels — especially placeholder-only inputs
3. Low contrast text in gray color scheme (text-gray-400 on white = too light)
4. Dynamic content updates not announced (use `role="alert"` or `aria-live`)

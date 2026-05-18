# Accessibility First

## Why This Is Non-Negotiable

- Screen reader users navigate by headings, landmarks, and labels
- Keyboard-only users cannot reach anything that requires hover or mouse click
- 15% of the population has some disability — that's a real portion of any audience
- SEO and accessibility are aligned: semantic HTML improves both

## Heading Hierarchy

One `<h1>` per page — the page title. Headings descend logically without skipping:

```html
<!-- CORRECT -->
<h1>Oil Change Service in Twin Falls</h1>
  <h2>Why Regular Oil Changes Matter</h2>
    <h3>Engine Protection</h3>
    <h3>Fuel Efficiency</h3>
  <h2>Our Process</h2>

<!-- WRONG — skipping from h1 to h3 -->
<h1>Page Title</h1>
<h3>Section</h3>
```

Never use heading tags for styling. Use them for document structure.

## Semantic HTML

Use the right element for the job:

```html
<!-- Navigation -->
<nav aria-label="Main navigation">
  <ul>
    <li><a href="/services">Services</a></li>
  </ul>
</nav>

<!-- Main content landmark -->
<main>
  <article>...</article>
</main>

<!-- Footer landmark -->
<footer>
  <address>417 Main Ave E, Twin Falls, ID</address>
</footer>

<!-- Buttons vs links:
  - <button> for actions (submit form, open modal, toggle)
  - <a href> for navigation -->
```

## Images

```typescript
// Meaningful image — describe what it shows:
<Image alt="Mechanic replacing oil filter on a Toyota Camry" ... />

// Decorative image — empty alt:
<Image alt="" aria-hidden="true" ... />

// Never:
<Image alt="image" ... />
<Image alt="photo1.jpg" ... />
```

## Form Labels

Every input needs a label. Don't use `placeholder` as the label:

```typescript
// CORRECT — visible label:
<div>
  <Label htmlFor="email">Email address</Label>
  <Input id="email" type="email" />
</div>

// CORRECT — screen-reader-only label when visible is not needed:
<Input
  aria-label="Search invoices"
  type="search"
  placeholder="Search..."
/>

// WRONG — placeholder only:
<Input type="email" placeholder="Email address" />
// When user starts typing, the label disappears
```

## Keyboard Navigation

Interactive elements must be reachable via `Tab` and operable via `Enter`/`Space`:

```typescript
// Custom click handlers on non-interactive elements break keyboard access:
// WRONG:
<div onClick={handleClick}>Click me</div>

// CORRECT: Use button for actions
<button onClick={handleClick}>Click me</button>

// If you must use a div (e.g., drag-and-drop zone):
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') handleClick()
  }}
>
  Custom interactive element
</div>
```

## Focus Management

After route navigation, focus should land on a logical location — usually the `<main>` element or the first `<h1>`:

```typescript
// In layout.tsx — skip nav link:
<a href="#main-content" className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 bg-white p-2">
  Skip to main content
</a>

<main id="main-content" tabIndex={-1}>
  {children}
</main>
```

After opening a modal: focus goes into the modal. After closing: focus returns to the trigger.

```typescript
const triggerRef = useRef<HTMLButtonElement>(null)

function closeDialog() {
  setOpen(false)
  triggerRef.current?.focus()  // return focus to trigger
}
```

## Color Contrast

Text must meet WCAG AA: 4.5:1 for normal text, 3:1 for large text (18px+). shadcn's default palette is designed to meet this. Don't reduce contrast for aesthetics — test with the browser's accessibility checker.

## ARIA Roles

Use sparingly — semantic HTML is better. Only add ARIA when the built-in semantics are insufficient:

```typescript
// Alert regions for dynamic content (notifications, errors):
<div role="alert" aria-live="polite">
  {error && <p>{error}</p>}
</div>

// Progress indicators:
<div role="progressbar" aria-valuenow={progress} aria-valuemin={0} aria-valuemax={100}>
  {progress}%
</div>

// Don't add role="button" to a <button> — it's redundant
// Don't add role="link" to an <a> — it's redundant
```

## Quick Audit Checklist

- [ ] One `<h1>` per page, logical heading order
- [ ] All images have appropriate `alt` text
- [ ] All form inputs have labels
- [ ] Tab order is logical (top-to-bottom, left-to-right)
- [ ] Focus is visible (don't remove `outline` without providing a replacement)
- [ ] No color as the only indicator of meaning
- [ ] Videos have captions (if applicable)
- [ ] Sufficient color contrast (4.5:1 minimum)

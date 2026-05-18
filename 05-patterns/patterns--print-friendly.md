# Pattern: Print-Friendly Layout (General Pages)

Note: For invoice/PDF-specific print layouts and Playwright PDF generation, see `patterns--print-layout.md`. This file covers general application pages that need to be print-friendly: reports, dashboards, data tables, articles.

## Why This Pattern Matters

`@media print` is the fastest path to print support — no extra library, no server cost. The failure mode is always the same: navigation, sidebars, buttons, and fixed/sticky elements invade the printed page, the typography is too small, and tables split across pages at bad breakpoints. All of this is preventable with a focused set of CSS rules.

## Hiding Chrome

The single most impactful print rule: hide everything that is screen-only UI.

```css
@media print {
  /* Layout chrome */
  header, nav, aside, footer,
  .sidebar, .app-header, .mobile-nav,
  /* Buttons and actions */
  button, [role="button"],
  .no-print,
  /* Overlays and toasts */
  [data-radix-popper-content-wrapper],
  .toast-container {
    display: none !important;
  }

  /* Full-width content — remove sidebar margins */
  main, .main-content {
    margin-left: 0 !important;
    padding: 0 !important;
    width: 100% !important;
  }
}
```

Add a `no-print` utility class to any element that should never appear in print. Use it on: floating action buttons, filter panels, tab navigation bars, and the print button itself.

## Print Typography

Screens use px; print uses pt. Reset font sizes for print:

```css
@media print {
  body {
    font-size: 11pt;
    line-height: 1.4;
    color: #000;
    background: #fff;
  }

  h1 { font-size: 18pt; }
  h2 { font-size: 14pt; }
  h3 { font-size: 12pt; }

  /* Remove shadows, gradients, and decorative backgrounds */
  * {
    box-shadow: none !important;
    text-shadow: none !important;
    background-image: none !important;
  }
}
```

Never rely on colored backgrounds to convey information in print — use borders and bold text instead.

## Page Break Control

Use `break-inside: avoid` on any element that should not split across pages. This is more reliable than `page-break-inside` (the older property) in modern browsers.

```css
@media print {
  /* Keep together */
  table, figure, blockquote, .card, tr { break-inside: avoid; }

  /* Force break before section headings */
  h2 { break-before: page; }

  /* Never break after a heading */
  h1, h2, h3 { break-after: avoid; }
}
```

Use `break-before: page` on major report sections when content reliably needs its own page (e.g., separate departments in a financial report). Don't overuse it — forced breaks create blank space that wastes paper.

## Tables in Print

Table headers must repeat on each page via `<thead>`:

```tsx
<table>
  <thead>
    <tr>...</tr>
  </thead>
  <tbody>
    {rows.map(row => <tr key={row.id} className="break-inside-avoid">{...}</tr>)}
  </tbody>
</table>
```

The browser automatically repeats `<thead>` content on each printed page if the table spans multiple pages. This only works when `<thead>` is used — not when header rows are in `<tbody>`.

## Print Button

The print button hides itself in print mode:

```tsx
<button
  onClick={() => window.print()}
  className="no-print flex items-center gap-2"
>
  <Printer className="h-4 w-4" />
  Print
</button>
```

Place the print button near the top of the content area (not in the global header) so it's close to the content being printed. On report pages, consider a sticky print button that scrolls with the page.

## `@page` for Margins

```css
@page {
  margin: 0.75in 1in;
}
```

Default browser margins are usually too small. Setting them explicitly ensures consistent output across Chrome, Safari, and Firefox.

## Conditional Print-Only Content

Some content should only appear when printing (e.g., the URL, a generation timestamp, a legal disclaimer):

```css
.print-only { display: none; }
@media print { .print-only { display: block; } }
```

## Key Rules

- `no-print` class hides elements; apply to all nav, buttons, and UI chrome
- `break-inside: avoid` on table rows and cards — not `page-break-inside` (deprecated)
- `<thead>` repeats automatically on multi-page tables — use it on every data table
- Reset font sizes to pt units in print media query
- Remove `box-shadow`, `background-image`, and color backgrounds
- `@page { margin: 0.75in 1in; }` for consistent cross-browser margins
- Print button has `className="no-print"` so it doesn't appear on the printed page

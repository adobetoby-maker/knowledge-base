# Segmented Control — iOS-Style Tab Switcher

## Semantics: When to Use Which Role

Two valid patterns depending on context:

1. **`role="tablist"` + `role="tab"`** — when the segments switch *content panels* below. Each tab controls a `tabpanel`. This is the correct ARIA pattern for "select this tab, show this content."
2. **`role="group"` + radio inputs** — when segments set a *value* (view mode, filter, sort order) without a visible content panel below. This matches how `<fieldset>` + `<input type="radio">` works semantically.

Don't use `role="tablist"` for a view-mode toggle that changes how a list renders — there's no `tabpanel`. Use `role="group"` with visually-hidden radio inputs instead.

## CSS Sliding Indicator

The highlight slides under the active segment using a single absolutely-positioned element driven by CSS custom properties. No JS animation library needed.

```tsx
export function SegmentedControl({ options, value, onChange }: Props) {
  const activeIdx = options.findIndex(o => o.value === value)

  return (
    <div
      role="group"
      aria-label="View options"
      className="relative flex bg-muted rounded-lg p-1"
      style={{ '--active-idx': activeIdx, '--count': options.length } as React.CSSProperties}
    >
      {/* Sliding highlight */}
      <div
        className="absolute top-1 bottom-1 rounded-md bg-background shadow-sm transition-transform duration-200 ease-out"
        style={{
          width: `calc(100% / var(--count) - 0.5rem)`,
          transform: `translateX(calc(var(--active-idx) * (100% + 0.5rem / (var(--count) - 1))))`,
        }}
        aria-hidden="true"
      />
      {options.map(opt => (
        <button
          key={opt.value}
          role="radio"
          aria-checked={opt.value === value}
          onClick={() => onChange(opt.value)}
          className="relative z-10 flex-1 px-3 py-1 text-sm font-medium"
        >
          {opt.label}
        </button>
      ))}
    </div>
  )
}
```

The sliding div is positioned absolutely and `translateX` moves it by multiples of its own width. `transition-transform` handles the animation entirely in CSS — GPU composited, no layout reflow.

## Controlled vs Uncontrolled

Always **controlled**. A segmented control is almost always wired to something external (URL param, store, parent state). An uncontrolled version with internal state causes the classic "component thinks it's A but app thinks it's B" split-brain problem. Pass `value` + `onChange` always.

## Keyboard Navigation

Arrow keys should move between segments within the group (same as radio group behavior). Implement with `onKeyDown`:

```ts
const handleKeyDown = (e: React.KeyboardEvent, idx: number) => {
  if (e.key === 'ArrowRight') onChange(options[(idx + 1) % options.length].value)
  if (e.key === 'ArrowLeft') onChange(options[(idx - 1 + options.length) % options.length].value)
}
```

## Why Not Use Actual Radio Inputs

Visually-hidden radios work but require wrapping each in a `<label>`, which complicates the sliding-indicator positioning. Pure `role="radio"` on buttons is cleaner and gives the same semantics without extra DOM nodes — as long as the `role`, `aria-checked`, and keyboard behavior are correct.

## Key Rules

- Use `role="tablist"` only when content panels follow; use `role="group"` + `role="radio"` for value selection.
- Sliding indicator uses CSS `translateX` — never `left` (triggers layout), never JS animation.
- Always controlled — no internal `value` state.
- Arrow keys navigate between options (mirrors native radio group behavior).
- `aria-checked` on each segment button, not `aria-selected`.

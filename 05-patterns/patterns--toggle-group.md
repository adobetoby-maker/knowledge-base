# Toggle Group — Multi-Option Toggle (Bold/Italic/Underline style)

## Single vs Multi-Select Modes

A toggle group operates in one of two modes:

- **Single select** (like a radio group): exactly one option active at a time. Value type: `string`.
- **Multi select** (like checkboxes): any combination active. Value type: `string[]`.

Never conflate them in one component with a flag like `multiple?: boolean` that changes the value type — this makes TypeScript generics painful. Use separate components or an explicit overloaded signature:

```ts
// Single select
function ToggleGroup(props: { value: string; onChange: (v: string) => void; ... }): JSX.Element
// Multi select
function ToggleGroup(props: { value: string[]; onChange: (v: string[]) => void; ... }): JSX.Element
```

## Accessibility: `aria-pressed`

Each button uses `aria-pressed` — not `aria-selected` (that's for listboxes/tabs), not `aria-checked` (that's for checkboxes/radios).

```tsx
<div role="group" aria-label="Text formatting">
  {options.map(opt => (
    <button
      key={opt.value}
      aria-pressed={isActive(opt.value)}
      disabled={opt.disabled}
      onClick={() => handleToggle(opt.value)}
      className={cn(
        "px-3 py-1 rounded",
        isActive(opt.value) && "bg-accent text-accent-foreground"
      )}
    >
      {opt.icon ?? opt.label}
    </button>
  ))}
</div>
```

## Multi-Select Toggle Logic

Toggle an item: if it's in the array, remove it; if not, add it. Never mutate the array directly.

```ts
const handleToggle = (val: string) => {
  onChange(
    value.includes(val)
      ? value.filter(v => v !== val)
      : [...value, val]
  )
}
```

## Disabled State

Individual options can be disabled independently (e.g., strikethrough disabled for plain text mode). A disabled button should still be focusable (`disabled` attribute removes it from tab order — use `aria-disabled="true"` + `pointer-events-none` if you need it reachable for screen readers to announce why it's disabled).

```tsx
// Focusable but inert — announces as disabled to screen readers
<button
  aria-pressed={isActive(opt.value)}
  aria-disabled={opt.disabled}
  tabIndex={opt.disabled ? 0 : undefined}
  onClick={opt.disabled ? undefined : () => handleToggle(opt.value)}
  className={cn(opt.disabled && "opacity-50 pointer-events-none cursor-not-allowed")}
>
```

Only use native `disabled` when you're fine losing focus; otherwise prefer `aria-disabled`.

## Keyboard Navigation

Within a toggle group, `Tab` moves focus from group to group (not between items). Arrow keys optionally navigate within (for single-select mode, matching radio behavior). For multi-select, `Tab` between items is standard — each button is independently focusable.

## Visual Grouping

Segmented groups (bold/italic/underline) use `divide-x` borders with shared outer `border` on the container. Spaced groups (tags, filters) use `gap-1.5`. Don't mix — pick one layout for a given toggle group.

```tsx
// Segmented (attached)
<div role="group" className="flex border rounded-md overflow-hidden divide-x">
// Spaced (pill buttons)
<div role="group" className="flex flex-wrap gap-1.5">
```

## Key Rules

- `aria-pressed` on each toggle button — not `aria-selected` or `aria-checked`.
- Single-select value is `string`; multi-select is `string[]` — keep types clean, don't conflate.
- Use `aria-disabled` (not `disabled`) when the button must remain focusable for context.
- Multi-select toggle: filter out if present, spread-add if absent — never mutate in place.
- Segmented layout uses `divide-x`; spaced layout uses `gap` — don't mix within one group.

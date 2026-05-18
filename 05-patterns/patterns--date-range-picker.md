# Date Range Picker

## When the Existing Date Picker Isn't Enough

`patterns--date-picker.md` covers the basic `react-day-picker` range mode with two calendars side-by-side. This file goes deeper on UX behaviors specific to range selection that are frequently implemented incorrectly: hover previews, keyboard clearing, constraint handling, and mobile fallbacks.

## Two-Calendar Layout

Show two months simultaneously in a single popover. This is critical because most date ranges span adjacent months, and forcing the user to navigate forwards is friction. `numberOfMonths={2}` on `react-day-picker`'s `Calendar` achieves this.

The left calendar should default to the current month; the right to next month. When the user selects a `from` date in month N, don't re-center — only move the calendar display when the user explicitly navigates.

```tsx
<Calendar
  mode="range"
  selected={range}
  onSelect={setRange}
  numberOfMonths={2}
  defaultMonth={startOfMonth(new Date())}
  initialFocus
/>
```

## Hover Preview of the Range

After selecting `from` but before selecting `to`, hovering over dates should preview the prospective range. `react-day-picker` handles this natively in range mode via its `modifiers` — the `range_middle` modifier is applied to hovered dates between `from` and the hovered cell. You don't need custom logic; just ensure your CSS applies a visual style to `rdp-day_range_middle`.

```css
/* Subtle fill for the in-progress range */
.rdp-day_range_middle {
  background-color: hsl(var(--primary) / 0.15);
  border-radius: 0;
}
```

If building a custom picker, track a `hoverDate` state and apply range styling to all dates between `range.from` and `hoverDate` during the partial-selection phase.

## Clearing via Keyboard

Users need to clear the range without reaching for the mouse. Two approaches:

1. **Backspace/Delete on the trigger button**: Focus the trigger, press Backspace → clears `range` to `undefined`.
2. **Clear button inside popover**: A small "Clear" text button below the calendar, visible only when a range (or partial range) is set.

```tsx
<Button
  variant="ghost"
  size="sm"
  onClick={() => { setRange(undefined); onRangeChange(undefined) }}
  className={cn(!range && 'invisible')}
>
  Clear
</Button>
```

Reason: ranges get selected accidentally. If clearing requires navigation, users give up and close the form instead.

## Min/Max Date Constraints

Use the `disabled` prop to block invalid dates. Common cases:

```tsx
<Calendar
  mode="range"
  selected={range}
  onSelect={setRange}
  disabled={[
    { before: minDate },          // no dates before min
    { after: maxDate },           // no dates after max
    (date) => isWeekend(date),    // optional: no weekends
  ]}
/>
```

When using `disabled`, also validate the range in your form schema — the calendar prevents *new* selections but won't automatically clear a previously stored range that violates new constraints.

```tsx
const schema = z.object({
  from: z.date().min(minDate),
  to: z.date().max(maxDate),
}).refine(d => d.to >= d.from, { message: 'End must be after start' })
```

## Mobile-Friendly Alternatives

Two-calendar layout is unusable on mobile — 640px or narrower cannot fit both months side by side. Options:

1. **Single calendar, native feel**: Drop to `numberOfMonths={1}` below `sm` breakpoint. Hide the second month. Accept the extra navigation step on mobile.
2. **Native date inputs as fallback**: On mobile, `<input type="date">` renders the OS date picker, which is optimized for touch. Wire two of them (Start Date / End Date) with min/max attributes. Less polished but zero friction.
3. **Bottom sheet with single calendar**: Slide up a bottom sheet (see `patterns--bottom-sheet.md`) containing a single calendar. The larger touch target area on a bottom sheet compensates for losing the dual-month view.

Detection: use a `useMediaQuery('(max-width: 640px)')` hook and render different UI. Don't try to force a two-month picker into mobile — the tap targets become too small and the month-navigation arrows overlap.

## Key Rules

- Always show two months simultaneously on desktop — single month for date ranges forces unnecessary navigation
- Hover preview is a first-class UX requirement, not a nice-to-have; implement it or use a library that does
- Provide an explicit Clear control — keyboard clearing alone is not discoverable
- Validate `min`/`max` constraints in the form schema *and* via `disabled` prop — the calendar alone doesn't prevent programmatically-set invalid ranges
- Render single-month or native inputs on mobile; never force the dual-calendar layout into a small viewport

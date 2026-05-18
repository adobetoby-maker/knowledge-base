# Time Picker

## Native Input on Mobile — The Right Default

On mobile, `<input type="time">` triggers the OS-native time picker, which is optimized for touch with scroll wheels or dial pads depending on the platform. It respects locale (12h vs 24h) automatically. Don't replace this with a custom picker on mobile — native pickers are faster, more accessible, and have zero bundle cost.

```tsx
// Native time input — works great on mobile, acceptable on desktop
<input
  type="time"
  value={value}   // "HH:MM" in 24h format regardless of display locale
  onChange={e => onChange(e.target.value)}
  min="08:00"
  max="20:00"
  step="900"      // 15-minute increments (in seconds)
  className="w-full rounded-md border px-3 py-2 text-sm"
/>
```

The `value` attribute always uses `HH:MM` in 24h format internally, even if the UI shows 12h. `step` is in *seconds* — 900 = 15 min, 1800 = 30 min, 3600 = 60 min.

## Custom Picker for Desktop

A native `<input type="time">` on desktop (especially Chrome/Windows) has an inconsistent UI — the spin buttons are small and the AM/PM toggle is awkward. For desktop apps where time selection is a primary interaction, build a custom picker with a combobox or segmented input.

```tsx
// Segmented approach: separate HH and MM inputs
// Keeps keyboard entry fast and avoids the spin-button UX
<div className="flex items-center gap-1 rounded-md border px-3 py-2 w-fit">
  <input
    type="number"
    min={1} max={12}
    value={hours}
    onChange={e => setHours(clamp(Number(e.target.value), 1, 12))}
    className="w-8 text-center outline-none"
  />
  <span>:</span>
  <input
    type="number"
    min={0} max={59}
    value={String(minutes).padStart(2, '0')}
    onChange={e => setMinutes(snapToStep(Number(e.target.value), 15))}
    className="w-8 text-center outline-none"
  />
  <button
    onClick={() => setPeriod(p => p === 'AM' ? 'PM' : 'AM')}
    className="ml-1 text-sm font-medium px-1 rounded hover:bg-muted"
  >
    {period}
  </button>
</div>
```

## 12h vs 24h Format

Store all times in 24h format internally (`HH:MM` string or minutes-since-midnight integer). Display in the user's locale preference. Don't store "3:30 PM" — store "15:30".

```tsx
// Convert display to storage
const to24h = (h: number, m: number, period: 'AM' | 'PM') => {
  const hours = period === 'PM' && h !== 12 ? h + 12
              : period === 'AM' && h === 12 ? 0
              : h
  return `${String(hours).padStart(2, '0')}:${String(m).padStart(2, '0')}`
}

// Convert storage to display
const to12h = (time: string) => {
  const [h, m] = time.split(':').map(Number)
  const period = h >= 12 ? 'PM' : 'AM'
  const hours = h % 12 || 12
  return { hours, minutes: m, period }
}
```

Detect locale preference: `new Intl.DateTimeFormat(undefined, { hour: 'numeric' }).resolvedOptions().hour12` returns `true` for 12h locales (US, UK) and `false` for 24h (most of Europe).

## Step Increments

15-minute steps are right for most scheduling use cases (appointments, meetings). 30-minute steps for low-precision tasks (time-of-day preferences). Allow free entry of arbitrary times when needed (start time for a shift).

When snapping to increments, round to the nearest step rather than always rounding down:

```tsx
const snapToStep = (minutes: number, step: number) =>
  Math.round(minutes / step) * step
```

## Integration with Date + Time Combined

Store datetime as a single `timestamptz` in Postgres, not a separate date column and time column. When building a combined date+time picker, compose the two pickers and merge on submit:

```tsx
const datetime = new Date(
  selectedDate.getFullYear(),
  selectedDate.getMonth(),
  selectedDate.getDate(),
  parseInt(time.split(':')[0]),
  parseInt(time.split(':')[1])
)
// Then convert to UTC before storing
const utcDatetime = zonedTimeToUtc(datetime, userTimezone)
```

Never concatenate a date string and time string — timezone edge cases (DST transitions, UTC offset in the date string) cause subtle bugs.

## Key Rules

- Use native `<input type="time">` on mobile — don't fight the OS with a custom picker
- Always store time in 24h format (`HH:MM`) regardless of display locale
- `step` on native time input is in *seconds*, not minutes — `step={900}` = 15 min
- Round to nearest step increment, not floor — rounding down always makes the picker feel sluggish
- For date+time combined, construct a full `Date` object and convert to UTC before storage; never concatenate strings

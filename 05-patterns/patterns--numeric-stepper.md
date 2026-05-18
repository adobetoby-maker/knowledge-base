# Pattern: Numeric Stepper (+/- Buttons)

## Overview

A numeric stepper combines a number input with increment/decrement buttons. It's used for quantity selectors, seat counts, temperature controls — anywhere a number has a small range and direct input is secondary. The accessibility requirements are stricter than they appear: each button needs a label describing the *resulting* action and current value, and paste/keyboard entry must be validated.

## Component

```tsx
interface NumericStepperProps {
  value: number
  onChange: (value: number) => void
  min?: number
  max?: number
  step?: number
  label: string
  disabled?: boolean
}

function NumericStepper({
  value,
  onChange,
  min = 0,
  max = Infinity,
  step = 1,
  label,
  disabled,
}: NumericStepperProps) {
  const inputId = useId()

  function decrement() {
    const next = Math.max(min, value - step)
    if (next !== value) onChange(next)
  }

  function increment() {
    const next = Math.min(max, value + step)
    if (next !== value) onChange(next)
  }

  function handleInputChange(e: React.ChangeEvent<HTMLInputElement>) {
    const raw = e.target.value
    if (raw === '' || raw === '-') return   // Allow in-progress typing
    const parsed = Number(raw)
    if (!Number.isFinite(parsed)) return    // Reject non-numeric
    onChange(Math.min(max, Math.max(min, parsed)))
  }

  function handlePaste(e: React.ClipboardEvent<HTMLInputElement>) {
    const pasted = e.clipboardData.getData('text')
    const parsed = Number(pasted.trim())
    if (!Number.isFinite(parsed)) {
      e.preventDefault()  // Block non-numeric paste
    }
  }

  return (
    <div role="group" aria-labelledby={`${inputId}-label`}>
      <span id={`${inputId}-label`} className="sr-only">{label}</span>

      <div className="flex items-center">
        <button
          type="button"
          onClick={decrement}
          disabled={disabled || value <= min}
          aria-label={`Decrease ${label} from ${value} to ${value - step}`}
        >
          −
        </button>

        <input
          id={inputId}
          type="number"
          value={value}
          onChange={handleInputChange}
          onPaste={handlePaste}
          min={min}
          max={max}
          step={step}
          disabled={disabled}
          aria-label={label}
          inputMode="numeric"
          className="w-12 text-center"
        />

        <button
          type="button"
          onClick={increment}
          disabled={disabled || value >= max}
          aria-label={`Increase ${label} from ${value} to ${value + step}`}
        >
          +
        </button>
      </div>
    </div>
  )
}
```

## Why the aria-label Describes Both Current and Next Value

"Decrease" alone tells a screen reader user what the button does, but not where they are or where they're going. "Decrease quantity from 3 to 2" provides full context in a single announcement — the user knows the current state and what will happen. This is the pattern used by Apple's native steppers (HIG) and widely adopted in web components.

When `value - step` would go below `min`, either disable the button or clamp the label to `min`.

## Long-Press Acceleration

For large ranges (0–100), holding the button should accelerate:

```ts
function useLongPress(callback: () => void, { delay = 300, interval = 80 } = {}) {
  const timerRef = useRef<ReturnType<typeof setTimeout>>()
  const intervalRef = useRef<ReturnType<typeof setInterval>>()

  function start() {
    callback()  // Fire once immediately
    timerRef.current = setTimeout(() => {
      intervalRef.current = setInterval(callback, interval)
    }, delay)
  }

  function stop() {
    clearTimeout(timerRef.current)
    clearInterval(intervalRef.current)
  }

  return {
    onMouseDown: start,
    onMouseUp: stop,
    onMouseLeave: stop,
    onTouchStart: start,
    onTouchEnd: stop,
  }
}

// Usage
const decrementProps = useLongPress(decrement)
const incrementProps = useLongPress(increment)

<button type="button" {...decrementProps} disabled={value <= min}>−</button>
<button type="button" {...incrementProps} disabled={value >= max}>+</button>
```

Always fire once immediately on press start — don't wait for the delay. The delay is only for starting the repeat interval.

## Input Validation

`type="number"` inputs accept `e`, `+`, `-` as valid characters in the input string during editing. The `handleInputChange` above allows an empty value (while user is clearing and retyping) but rejects non-finite results. The `onBlur` should clamp to range:

```ts
function handleBlur() {
  onChange(Math.min(max, Math.max(min, value || min)))
}
```

## Key Rules

- `aria-label` on each button must describe the resulting action including the direction and current value: "Decrease quantity from 3 to 2".
- Disable buttons at boundary values (min/max) rather than silently clamping — this communicates that the limit has been reached.
- Long-press should fire immediately on press, then start repeating after a delay — not wait for the delay before the first fire.
- Validate and reject non-numeric paste via `onPaste`, not just in `onChange`.
- `inputMode="numeric"` on the input shows a numeric keyboard on mobile even though it's `type="number"`.
- Use `role="group"` with `aria-labelledby` to associate the label with the entire stepper widget, not just the input.

# Quantity Input — Stepper (+/−)

## Why Not Just a Number Input

A plain `<input type="number">` has browser-native spinners (ugly, inconsistent cross-browser), allows non-integer values, and gives no affordance for typical single-increment use. The stepper pattern — two buttons flanking a display — covers 90% of quantity interactions without keyboard entry. But always provide direct text entry too; power users need it.

## Component Structure

```tsx
interface QuantityInputProps {
  value: number
  min?: number  // default 1
  max?: number  // default Infinity
  onChange: (v: number) => void
}

export function QuantityInput({ value, min = 1, max = Infinity, onChange }: QuantityInputProps) {
  const [inputVal, setInputVal] = useState(String(value))

  // Keep input display in sync if parent changes value externally
  useEffect(() => { setInputVal(String(value)) }, [value])

  const decrement = () => onChange(Math.max(min, value - 1))
  const increment = () => onChange(Math.min(max, value + 1))

  const handleBlur = () => {
    const parsed = parseInt(inputVal, 10)
    if (isNaN(parsed)) { setInputVal(String(value)); return }
    const clamped = Math.min(max, Math.max(min, parsed))
    setInputVal(String(clamped))
    onChange(clamped)
  }

  return (
    <div role="group" aria-label="Quantity">
      <button onClick={decrement} disabled={value <= min} aria-label="Decrease">−</button>
      <input
        type="text"          // not "number" — avoids browser spinners
        inputMode="numeric"  // shows numeric keyboard on mobile
        pattern="[0-9]*"
        value={inputVal}
        onChange={e => setInputVal(e.target.value)}
        onBlur={handleBlur}
        aria-label="Quantity"
      />
      <button onClick={increment} disabled={value >= max} aria-label="Increase">+</button>
    </div>
  )
}
```

## Why `type="text"` Not `type="number"`

`type="number"` fires `onChange` on each keypress including partial states like `"1."` or `"-"`. With `type="text"` and `inputMode="numeric"`, validate only on blur — the field accepts any string while typing, clamps and normalizes on exit. This avoids the frustrating "can't type 10 because 1 triggers onChange and re-renders before I finish."

## Long-Press Acceleration

Hold the button to ramp up increment speed. Start at 300ms intervals, halve every 3 ticks, floor at 50ms:

```ts
const useLongPress = (callback: () => void) => {
  const timerRef = useRef<ReturnType<typeof setTimeout>>()
  const intervalRef = useRef<ReturnType<typeof setInterval>>()
  const speedRef = useRef(300)

  const start = () => {
    callback()
    let ticks = 0
    const fire = () => {
      callback()
      ticks++
      if (ticks % 3 === 0) speedRef.current = Math.max(50, speedRef.current / 2)
    }
    timerRef.current = setTimeout(() => {
      intervalRef.current = setInterval(fire, speedRef.current)
    }, 400)
  }

  const stop = () => {
    clearTimeout(timerRef.current)
    clearInterval(intervalRef.current)
    speedRef.current = 300
  }

  return { onMouseDown: start, onMouseUp: stop, onMouseLeave: stop }
}
```

## Input Direct Entry

Allow typing directly. Reject non-numeric input visually only after blur — never block keystrokes mid-entry. If the final value is out of range, clamp silently (don't error). Only show an error if the clamped value matters semantically (e.g., cart has a max of 5 and user types 99 — a subtle note "Max 5 applied" is helpful).

## Accessibility

- Wrap in `role="group"` with `aria-label="Quantity"` so screen readers announce context.
- The `−` button needs `aria-label="Decrease quantity"` (not just "−").
- Use `aria-live="polite"` on the display value if the stepper is inside a larger live region.

## Key Rules

- Use `type="text"` with `inputMode="numeric"` — not `type="number"`.
- Validate and clamp on blur, not on every keystroke.
- Disable decrement at `min`, disable increment at `max` — don't let them click into invalid state.
- Long-press acceleration starts at 400ms, ramps to 50ms interval floor.
- Never silently discard typed input; always clamp and show the clamped value.

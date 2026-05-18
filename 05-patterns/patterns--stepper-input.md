# Pattern: Numeric Stepper Input

## Overview
A stepper input is preferable to a plain number input for bounded quantities (1–99 items in a cart, 1–10 guests) because it prevents invalid input and provides tactile affordance. The critical UX detail is long-press acceleration — holding the + button should increase speed after 500ms, otherwise incrementing from 1 to 50 requires 49 separate clicks. Accessibility requires proper ARIA attributes so screen readers announce the value.

## Implementation

### Long-press hook

```ts
function useLongPress(
  callback: () => void,
  { delay = 500, interval = 80 }: { delay?: number; interval?: number } = {}
) {
  const timeoutRef = useRef<ReturnType<typeof setTimeout>>()
  const intervalRef = useRef<ReturnType<typeof setInterval>>()

  function start() {
    callback() // Immediate first trigger
    timeoutRef.current = setTimeout(() => {
      // After delay, start rapid-fire
      intervalRef.current = setInterval(callback, interval)
    }, delay)
  }

  function stop() {
    clearTimeout(timeoutRef.current)
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
```

### Stepper component

```tsx
interface StepperProps {
  value: number
  onChange: (value: number) => void
  min?: number
  max?: number
  step?: number
  integerOnly?: boolean
  disabled?: boolean
  label?: string
}

function Stepper({
  value,
  onChange,
  min = 0,
  max = 99,
  step = 1,
  integerOnly = true,
  disabled = false,
  label = 'Quantity',
}: StepperProps) {
  const [inputValue, setInputValue] = useState(String(value))

  // Keep input display in sync with prop
  useEffect(() => { setInputValue(String(value)) }, [value])

  function clamp(n: number) {
    return Math.min(max, Math.max(min, n))
  }

  function decrement() {
    const next = clamp(value - step)
    if (next !== value) onChange(next)
  }

  function increment() {
    const next = clamp(value + step)
    if (next !== value) onChange(next)
  }

  function handleInputChange(e: React.ChangeEvent<HTMLInputElement>) {
    setInputValue(e.target.value) // Allow free typing
  }

  function handleInputBlur() {
    const parsed = integerOnly ? parseInt(inputValue, 10) : parseFloat(inputValue)
    if (isNaN(parsed)) {
      setInputValue(String(value)) // Revert to last valid value
    } else {
      const clamped = clamp(parsed)
      onChange(clamped)
      setInputValue(String(clamped))
    }
  }

  const decrementPress = useLongPress(decrement)
  const incrementPress = useLongPress(increment)

  return (
    <div
      className="inline-flex items-center border rounded-lg overflow-hidden"
      role="group"
      aria-label={label}
    >
      <button
        type="button"
        className="px-3 py-2 text-lg font-medium hover:bg-gray-100 disabled:opacity-40 
                   disabled:cursor-not-allowed select-none"
        disabled={disabled || value <= min}
        aria-label={`Decrease ${label}`}
        {...decrementPress}
      >
        −
      </button>

      <input
        type="number"
        value={inputValue}
        onChange={handleInputChange}
        onBlur={handleInputBlur}
        disabled={disabled}
        min={min}
        max={max}
        step={step}
        className="w-12 text-center border-x py-2 text-sm focus:outline-none 
                   [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none"
        aria-valuenow={value}
        aria-valuemin={min}
        aria-valuemax={max}
        aria-label={label}
      />

      <button
        type="button"
        className="px-3 py-2 text-lg font-medium hover:bg-gray-100 disabled:opacity-40 
                   disabled:cursor-not-allowed select-none"
        disabled={disabled || value >= max}
        aria-label={`Increase ${label}`}
        {...incrementPress}
      >
        +
      </button>
    </div>
  )
}
```

### Usage in cart

```tsx
function CartItem({ item, onQuantityChange, onRemove }: CartItemProps) {
  return (
    <div className="flex items-center gap-4">
      <img src={item.image} alt={item.name} className="w-16 h-16 object-cover rounded" />
      <div className="flex-1">{item.name}</div>
      <Stepper
        value={item.quantity}
        onChange={(qty) => {
          if (qty === 0) onRemove(item.id)
          else onQuantityChange(item.id, qty)
        }}
        min={0}  // Allow 0 to trigger remove
        max={99}
        label={`Quantity for ${item.name}`}
      />
      <div className="w-20 text-right font-medium">
        {formatCurrency(item.price * item.quantity)}
      </div>
    </div>
  )
}
```

## Key Rules
- `type="button"` on stepper buttons is critical inside a form — without it, they submit the form
- Long-press acceleration: start after 500ms hold, fire every 80ms. Without it, large ranges are unusable
- Input is directly editable; validate/clamp on blur, not on every keystroke
- `aria-valuenow`, `aria-valuemin`, `aria-valuemax` required for screen reader announcements
- Hide the native number input spinners with CSS (they duplicate the buttons)
- Min/max enforcement happens in `clamp()` — buttons disable at boundaries, input clamps on blur
- `select-none` on buttons prevents text selection during rapid clicking
- `integerOnly` mode rejects decimals — use `parseInt` not `parseFloat`

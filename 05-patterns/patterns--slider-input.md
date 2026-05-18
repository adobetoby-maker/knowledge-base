# Pattern: Slider + Numeric Input Sync

A range slider paired with a text input showing the exact numeric value. Both controls must stay in sync bidirectionally. The hard parts are: avoiding feedback loops, validating typed values, and making the semantic value readable to screen readers.

## Why It Matters

Sliders are fast for approximate values; inputs are precise. Offering both reduces frustration. The failure mode is subtle: if slider→input sync and input→slider sync fire in a cycle, you get jitter or infinite re-renders. Debouncing input changes prevents that while keeping the slider responsive.

## State Architecture

One source of truth: a single `value` state. Both controls read from it and dispatch changes to it via separate handlers.

```tsx
function SliderInput({
  min = 0,
  max = 100,
  step = 1,
  defaultValue = 50,
  onChange,
  label,
  unit,
}: SliderInputProps) {
  const [value, setValue] = useState(defaultValue);
  const [inputText, setInputText] = useState(String(defaultValue));

  // Slider fires frequently — update immediately, no debounce
  function handleSliderChange(e: React.ChangeEvent<HTMLInputElement>) {
    const num = Number(e.target.value);
    setValue(num);
    setInputText(String(num));
    onChange?.(num);
  }

  // Input text changes buffered — only commit on valid number
  const commitInput = useCallback(
    debounce((raw: string) => {
      const num = Number(raw);
      if (isNaN(num)) { setInputText(String(value)); return; } // revert invalid
      const clamped = Math.min(max, Math.max(min, snapToStep(num, step)));
      setValue(clamped);
      setInputText(String(clamped));
      onChange?.(clamped);
    }, 400),
    [min, max, step, value]
  );

  function handleInputChange(e: React.ChangeEvent<HTMLInputElement>) {
    setInputText(e.target.value); // allow free typing
    commitInput(e.target.value);
  }

  function handleInputBlur() {
    // Flush immediately on blur — don't wait for debounce
    commitInput.cancel();
    const num = Number(inputText);
    if (isNaN(num)) { setInputText(String(value)); return; }
    const clamped = Math.min(max, Math.max(min, snapToStep(num, step)));
    setValue(clamped);
    setInputText(String(clamped));
    onChange?.(clamped);
  }

  const sliderId = useId();

  return (
    <div className="slider-input">
      <label htmlFor={sliderId}>{label}</label>
      <div className="slider-input__controls">
        <input
          id={sliderId}
          type="range"
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={handleSliderChange}
          aria-valuetext={unit ? `${value} ${unit}` : undefined}
          aria-label={label}
        />
        <input
          type="number"
          value={inputText}
          onChange={handleInputChange}
          onBlur={handleInputBlur}
          onKeyDown={e => e.key === 'Enter' && (e.currentTarget as HTMLInputElement).blur()}
          min={min}
          max={max}
          step={step}
          aria-label={`${label} value`}
          className="slider-input__number"
        />
        {unit && <span aria-hidden>{unit}</span>}
      </div>
    </div>
  );
}
```

## Step Snapping

When a user types `33` and step is `5`, it should snap to `35`:

```ts
function snapToStep(value: number, step: number): number {
  return Math.round(value / step) * step;
}
```

## Debounce — Why Two Different Values

- **Slider** fires `onChange` on every pixel of movement (50+ times per drag). Sync immediately—don't debounce—so input stays live.
- **Text input** fires on every keystroke. A user typing "100" emits "1", "10", "100". Debounce at ~400ms so only "100" triggers validation and `onChange`.
- **On blur**: cancel the pending debounce and flush synchronously. Users expect immediate feedback when they leave the field.

## Accessible Labels

The native `<input type="range">` exposes its numeric value to screen readers, but "73" is meaningless without context. Use `aria-valuetext` for semantic values:

```tsx
// For a brightness slider: "73%" instead of "73"
aria-valuetext={`${value}%`}

// For a price range: "$250" instead of "250"
aria-valuetext={`$${value}`}

// For a temperature: "72 degrees Fahrenheit"
aria-valuetext={`${value} degrees Fahrenheit`}
```

## Min/Max Validation Feedback

Show constraint violation inline, not as a toast:

```tsx
const isOutOfRange = value < min || value > max;

<input
  type="number"
  aria-invalid={isOutOfRange}
  aria-describedby={isOutOfRange ? `${sliderId}-error` : undefined}
  ...
/>
{isOutOfRange && (
  <span id={`${sliderId}-error`} role="alert" className="error">
    Value must be between {min} and {max}
  </span>
)}
```

## Styling the Track Fill

Native range inputs have no cross-browser fill styling. Use a CSS custom property updated via inline style:

```tsx
<input
  type="range"
  style={{ '--fill': `${((value - min) / (max - min)) * 100}%` } as React.CSSProperties}
  ...
/>
```

```css
input[type='range'] {
  background: linear-gradient(to right, var(--accent) 0%, var(--accent) var(--fill), var(--muted) var(--fill));
}
```

## Key Rules

- **One state value**—slider and input both derive from it, never independently.
- **No debounce on slider** — sync is immediate to keep input live during drag.
- **Debounce text input at ~400ms**, flush on blur.
- **Snap to step** when user types a value not on the step grid.
- **`aria-valuetext`** when the raw number has a unit or semantic label.
- **Revert** the input text on invalid entry (NaN), don't silently clear.
- **`Enter` on number input** triggers blur, which flushes the value.

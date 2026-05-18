# Pattern: Number Range / Price Slider

## Overview
A range slider with two handles (min/max) is the standard UI for price filters, date ranges, age ranges, and numeric bounds. The complexity lies in synchronizing three views of the same state: the two slider handles, and two numeric input fields. Any of the three controls can drive the state, and each must immediately update the others without creating input loops. The slider must also be fully keyboard-navigable and ARIA-labelled.

## Implementation

### State Model
```tsx
interface RangeState {
  min: number;
  max: number;
}

function useRangeSlider({
  initialMin,
  initialMax,
  absoluteMin,
  absoluteMax,
  step = 1,
}: {
  initialMin: number;
  initialMax: number;
  absoluteMin: number;
  absoluteMax: number;
  step?: number;
}) {
  const [range, setRange] = useState<RangeState>({ min: initialMin, max: initialMax });

  const setMin = (value: number) => {
    const clamped = Math.min(Math.max(value, absoluteMin), range.max - step);
    setRange(r => ({ ...r, min: clamped }));
  };

  const setMax = (value: number) => {
    const clamped = Math.max(Math.min(value, absoluteMax), range.min + step);
    setRange(r => ({ ...r, max: clamped }));
  };

  return { range, setMin, setMax };
}
```

### Range Slider with Dual Handles
Two overlapping native `<input type="range">` elements, positioned absolutely:

```tsx
function RangeSlider({
  min: value_min,
  max: value_max,
  absoluteMin,
  absoluteMax,
  step = 1,
  onMinChange,
  onMaxChange,
  formatValue = (v) => String(v),
  label = 'Range',
}: {
  min: number;
  max: number;
  absoluteMin: number;
  absoluteMax: number;
  step?: number;
  onMinChange: (v: number) => void;
  onMaxChange: (v: number) => void;
  formatValue?: (v: number) => string;
  label?: string;
}) {
  const totalRange = absoluteMax - absoluteMin;
  const minPercent = ((value_min - absoluteMin) / totalRange) * 100;
  const maxPercent = ((value_max - absoluteMin) / totalRange) * 100;

  return (
    <div style={{ position: 'relative', height: 20, userSelect: 'none' }}>
      {/* Track */}
      <div style={{
        position: 'absolute',
        top: '50%',
        transform: 'translateY(-50%)',
        left: 0,
        right: 0,
        height: 4,
        borderRadius: 2,
        background: '#e5e7eb',
      }} />

      {/* Active range fill */}
      <div style={{
        position: 'absolute',
        top: '50%',
        transform: 'translateY(-50%)',
        left: `${minPercent}%`,
        right: `${100 - maxPercent}%`,
        height: 4,
        borderRadius: 2,
        background: '#3b82f6',
      }} />

      {/* Min handle */}
      <input
        type="range"
        min={absoluteMin}
        max={absoluteMax}
        step={step}
        value={value_min}
        onChange={e => onMinChange(Number(e.target.value))}
        aria-label={`${label} minimum: ${formatValue(value_min)}`}
        aria-valuemin={absoluteMin}
        aria-valuemax={value_max}
        aria-valuenow={value_min}
        style={{
          position: 'absolute',
          width: '100%',
          pointerEvents: 'none',
          appearance: 'none',
          background: 'transparent',
          // thumb gets pointer-events via CSS
        }}
        className="range-handle range-handle--min"
      />

      {/* Max handle */}
      <input
        type="range"
        min={absoluteMin}
        max={absoluteMax}
        step={step}
        value={value_max}
        onChange={e => onMaxChange(Number(e.target.value))}
        aria-label={`${label} maximum: ${formatValue(value_max)}`}
        aria-valuemin={value_min}
        aria-valuemax={absoluteMax}
        aria-valuenow={value_max}
        style={{
          position: 'absolute',
          width: '100%',
          pointerEvents: 'none',
          appearance: 'none',
          background: 'transparent',
        }}
        className="range-handle range-handle--max"
      />
    </div>
  );
}
```

### CSS for Stacked Handles
```css
.range-handle {
  -webkit-appearance: none;
  appearance: none;
  height: 4px;
  cursor: pointer;
  pointer-events: none;
}
.range-handle::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: #3b82f6;
  border: 2px solid #fff;
  box-shadow: 0 1px 4px rgba(0,0,0,0.2);
  pointer-events: all;
  cursor: grab;
}
.range-handle:focus::-webkit-slider-thumb {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
}
```

### Synchronized Input Fields
```tsx
function RangeInputs({ min, max, absoluteMin, absoluteMax, onMinChange, onMaxChange, format }) {
  const [minDraft, setMinDraft] = useState(String(min));
  const [maxDraft, setMaxDraft] = useState(String(max));

  // Sync draft when external value changes (slider drag)
  useEffect(() => setMinDraft(String(min)), [min]);
  useEffect(() => setMaxDraft(String(max)), [max]);

  const commitMin = () => {
    const v = Number(minDraft);
    if (!isNaN(v)) onMinChange(v);
    else setMinDraft(String(min)); // revert invalid input
  };

  const commitMax = () => {
    const v = Number(maxDraft);
    if (!isNaN(v)) onMaxChange(v);
    else setMaxDraft(String(max));
  };

  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
      <input
        type="text"
        inputMode="numeric"
        value={minDraft}
        onChange={e => setMinDraft(e.target.value)}
        onBlur={commitMin}
        onKeyDown={e => e.key === 'Enter' && commitMin()}
        aria-label="Minimum value"
        style={{ width: 80 }}
      />
      <span>–</span>
      <input
        type="text"
        inputMode="numeric"
        value={maxDraft}
        onChange={e => setMaxDraft(e.target.value)}
        onBlur={commitMax}
        onKeyDown={e => e.key === 'Enter' && commitMax()}
        aria-label="Maximum value"
        style={{ width: 80 }}
      />
    </div>
  );
}
```

## Key Rules
- Clamp: min handle cannot exceed `max - step`; max handle cannot go below `min + step`. Handles must never cross.
- Use two overlapping `<input type="range">` elements — this leverages native browser keyboard handling (arrow keys, Home, End) for free.
- `pointer-events: none` on the range input itself, `pointer-events: all` on the thumb via CSS — prevents the invisible input from blocking other elements.
- Numeric input fields use a "draft" pattern: update the input freely, commit on blur/Enter. Direct binding to the range value causes cursor-jump on every keystroke.
- `aria-valuemin` on each handle should reflect the *other handle's current value* as the dynamic boundary, not the absolute min/max.
- Currency format: display as `$1,200` but store as `1200` — apply formatting in `formatValue`, strip it before parsing input.
- `inputMode="numeric"` on text inputs shows the numeric keyboard on mobile without restricting paste.

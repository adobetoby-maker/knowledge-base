# Pattern: Progress Ring

## Overview
A circular progress indicator communicates completion percentage better than a linear bar in space-constrained layouts like dashboards, cards, and avatars. SVG stroke manipulation is the correct implementation: it avoids canvas complexity, scales infinitely, and is styleable with CSS. Getting the math right is essential — most bugs come from misunderstanding the relationship between `stroke-dasharray` and circumference.

## Implementation

### SVG Math
```
radius = (size / 2) - (strokeWidth / 2)   // inset from edge so stroke doesn't clip
circumference = 2 * Math.PI * radius
offset = circumference - (percentage / 100) * circumference
```

Set `stroke-dasharray={circumference}` (one full dash, one full gap = solid circle).
Set `stroke-dashoffset={offset}` — a positive offset hides that much of the dash.
At 0% → offset = circumference (entire dash hidden).
At 100% → offset = 0 (entire dash visible).

### Base Component
```tsx
interface ProgressRingProps {
  percentage: number;      // 0-100
  size?: number;           // px, default 64
  strokeWidth?: number;    // px, default 6
  color?: string;
  trackColor?: string;
  label?: string;
  indeterminate?: boolean;
}

function ProgressRing({
  percentage,
  size = 64,
  strokeWidth = 6,
  color = 'currentColor',
  trackColor = '#e5e7eb',
  label,
  indeterminate = false,
}: ProgressRingProps) {
  const radius = (size / 2) - (strokeWidth / 2);
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (Math.min(100, Math.max(0, percentage)) / 100) * circumference;
  const center = size / 2;

  return (
    <div
      role="progressbar"
      aria-valuenow={indeterminate ? undefined : percentage}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label={label ?? `${percentage}%`}
      style={{ width: size, height: size, position: 'relative', display: 'inline-flex' }}
    >
      <svg
        width={size}
        height={size}
        style={indeterminate ? { animation: 'spin 1.2s linear infinite' } : undefined}
      >
        {/* Track */}
        <circle
          cx={center}
          cy={center}
          r={radius}
          fill="none"
          stroke={trackColor}
          strokeWidth={strokeWidth}
        />
        {/* Progress */}
        <circle
          cx={center}
          cy={center}
          r={radius}
          fill="none"
          stroke={color}
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={indeterminate ? circumference * 0.25 : offset}
          strokeLinecap="round"
          transform={`rotate(-90 ${center} ${center})`}
          style={{ transition: 'stroke-dashoffset 0.4s ease' }}
        />
      </svg>
      {/* Center text */}
      {!indeterminate && (
        <span style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: size * 0.22,
          fontWeight: 600,
        }}>
          {percentage}%
        </span>
      )}
    </div>
  );
}
```

### CSS for indeterminate spin
```css
@keyframes spin {
  from { transform: rotate(0deg); }
  to   { transform: rotate(360deg); }
}
```

### Indeterminate vs Determinate
When progress is unknown (loading, uploading with no server progress event), use `indeterminate`. Remove `aria-valuenow` for indeterminate state — screen readers treat its absence as "unknown progress". Set `strokeDashoffset` to 75% of circumference (short arc that rotates).

## Key Rules
- Always apply `rotate(-90 cx cy)` transform: SVG 0° starts at 3 o'clock; progress rings start at 12 o'clock.
- Clamp percentage to 0–100 before computing offset — negative or >100 values produce visual glitches.
- `strokeLinecap="round"` adds half a stroke width to each end — visually compensate by starting slightly before 12 o'clock if pixel-precision matters.
- Use CSS `transition` on `stroke-dashoffset`, not JS animation, for smooth updates on re-render.
- Never use `stroke-dashoffset` as a negative value — browsers handle it inconsistently.
- For multi-ring (stacked) variants, layer additional SVG circles with different radii and smaller `strokeWidth`.
- Pass `role="progressbar"` on the container div, not on the SVG element — SVG roles have poor support.

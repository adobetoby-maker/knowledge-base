# Pattern: Color Picker

## What This Solves

Color selection appears in brand configuration, category labels, tag colors, and design tools. The spectrum of complexity: a fixed palette (easiest), a hex input field (simple), a full HSL picker (complex). Match the tool to the use case — most business apps need a fixed palette, not a full picker.

## Fixed Palette Picker

```tsx
// components/ColorPalettePicker.tsx
'use client'
import { Check } from 'lucide-react'
import { cn } from '@/lib/utils'

const PALETTE = [
  '#ef4444', '#f97316', '#eab308', '#22c55e',
  '#06b6d4', '#3b82f6', '#8b5cf6', '#ec4899',
  '#6b7280', '#1f2937',
]

interface ColorPalettePickerProps {
  value: string
  onChange: (color: string) => void
}

export function ColorPalettePicker({ value, onChange }: ColorPalettePickerProps) {
  return (
    <div className="flex flex-wrap gap-2">
      {PALETTE.map(color => (
        <button
          key={color}
          type="button"
          className={cn(
            'h-8 w-8 rounded-full border-2 transition-all',
            value === color ? 'border-foreground scale-110' : 'border-transparent hover:scale-105'
          )}
          style={{ backgroundColor: color }}
          onClick={() => onChange(color)}
          aria-label={color}
          aria-pressed={value === color}
        >
          {value === color && (
            <Check
              className="h-4 w-4 mx-auto"
              style={{ color: isLightColor(color) ? '#000' : '#fff' }}
            />
          )}
        </button>
      ))}
    </div>
  )
}

function isLightColor(hex: string): boolean {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return (r * 299 + g * 587 + b * 114) / 1000 > 128
}
```

## Hex Input + Native Picker

```tsx
'use client'
import { useRef, useState } from 'react'
import { Input } from '@/components/ui/input'

interface HexColorInputProps {
  value: string
  onChange: (hex: string) => void
}

export function HexColorInput({ value, onChange }: HexColorInputProps) {
  const [inputValue, setInputValue] = useState(value)
  const nativeRef = useRef<HTMLInputElement>(null)

  const handleTextChange = (raw: string) => {
    setInputValue(raw)
    // Validate: must be valid 6-char hex
    if (/^#[0-9a-fA-F]{6}$/.test(raw)) {
      onChange(raw)
    }
  }

  const handleNativeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const hex = e.target.value
    setInputValue(hex)
    onChange(hex)
  }

  return (
    <div className="flex items-center gap-2">
      {/* Clickable color swatch opens native color picker */}
      <button
        type="button"
        className="h-9 w-9 rounded-md border cursor-pointer shrink-0"
        style={{ backgroundColor: value }}
        onClick={() => nativeRef.current?.click()}
        aria-label="Open color picker"
      />
      {/* Hidden native input */}
      <input
        ref={nativeRef}
        type="color"
        value={value}
        onChange={handleNativeChange}
        className="sr-only"
      />
      {/* Hex text input */}
      <Input
        value={inputValue}
        onChange={e => handleTextChange(e.target.value)}
        placeholder="#000000"
        maxLength={7}
        className="font-mono w-28"
      />
    </div>
  )
}
```

## React Hook Form Integration

```tsx
<Controller
  control={form.control}
  name="brand_color"
  render={({ field }) => (
    <div className="space-y-2">
      <label className="text-sm font-medium">Brand Color</label>
      <ColorPalettePicker value={field.value} onChange={field.onChange} />
      <p className="text-xs text-muted-foreground">
        Selected: <span className="font-mono">{field.value}</span>
      </p>
    </div>
  )}
/>
```

## Color Label Component

Once a color is selected, use it for badges:

```tsx
function CategoryBadge({ label, color }: { label: string; color: string }) {
  const textColor = isLightColor(color) ? '#1f2937' : '#f9fafb'
  return (
    <span
      className="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium"
      style={{ backgroundColor: color, color: textColor }}
    >
      {label}
    </span>
  )
}
```

## Database Storage

Store as a 7-character hex string:
```sql
ALTER TABLE categories ADD COLUMN color char(7) NOT NULL DEFAULT '#6b7280';

-- Validate on insert
ALTER TABLE categories ADD CONSTRAINT valid_color
  CHECK (color ~ '^#[0-9a-fA-F]{6}$');
```

## Accessibility Notes

- The color swatch button must have `aria-label` describing the color
- Don't rely solely on color to convey information (color blindness)
- For category labels: always show text alongside the color
- Checkmark on selected swatch must have sufficient contrast against the background color

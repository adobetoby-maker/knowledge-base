# Pattern: Color Swatch Picker

## Overview
Color pickers that only accept hex input exclude designers who think in HSL and blind users who cannot verify color choices. Showing a contrast ratio on change catches accessibility failures before they ship. CSS custom properties let the preview update instantly without touching the DOM structure. The undo mechanism matters because accidental color changes in theme editors are destructive.

## Bounded Palette + Free Input

```tsx
function ColorSwatchPicker({ value, onChange, palette }: Props) {
  const [mode, setMode] = useState<'palette' | 'custom'>('palette');
  const [hexInput, setHexInput] = useState(value);
  const [history, setHistory] = useState<string[]>([value]);

  function applyColor(hex: string) {
    // Only commit valid hex colors
    if (!isValidHex(hex)) return;
    setHistory(prev => [value, ...prev.slice(0, 9)]); // Keep last 10
    onChange(hex);
  }

  function undo() {
    const [prev, ...rest] = history;
    if (prev) { onChange(prev); setHistory(rest); }
  }

  return (
    <div className="color-picker">
      {/* Palette tab — fastest path for common brand colors */}
      <div className="color-picker__tabs">
        <button onClick={() => setMode('palette')} aria-pressed={mode === 'palette'}>Swatches</button>
        <button onClick={() => setMode('custom')} aria-pressed={mode === 'custom'}>Custom</button>
      </div>

      {mode === 'palette' ? (
        <SwatchGrid colors={palette} selected={value} onSelect={applyColor} />
      ) : (
        <FreeColorInput value={hexInput} onChange={setHexInput} onCommit={applyColor} />
      )}

      <ContrastChecker color={value} />

      <button onClick={undo} disabled={history.length === 0}>
        Undo
      </button>
    </div>
  );
}
```

## Swatch Grid

```tsx
function SwatchGrid({ colors, selected, onSelect }: SwatchGridProps) {
  return (
    <div className="swatch-grid" role="listbox" aria-label="Color palette">
      {colors.map(hex => (
        <button
          key={hex}
          role="option"
          aria-selected={selected === hex}
          aria-label={hex} // Screen reader gets the hex value
          style={{ backgroundColor: hex }}
          className={`swatch ${selected === hex ? 'swatch--selected' : ''}`}
          onClick={() => onSelect(hex)}
        />
      ))}
    </div>
  );
}
```

## Free Input with Format Conversion

```tsx
function FreeColorInput({ value, onChange, onCommit }: FreeInputProps) {
  const [format, setFormat] = useState<'hex' | 'hsl' | 'rgb'>('hex');

  // Convert the canonical hex to the display format
  const displayValue = useMemo(() => {
    if (!isValidHex(value)) return value;
    if (format === 'hsl') return hexToHsl(value);
    if (format === 'rgb') return hexToRgb(value);
    return value;
  }, [value, format]);

  function handleChange(raw: string) {
    // Always store as hex internally — convert on input, display in chosen format
    const hex = format === 'hsl' ? hslToHex(raw) : format === 'rgb' ? rgbToHex(raw) : raw;
    onChange(hex);
  }

  return (
    <div className="free-color-input">
      <div className="color-preview" style={{ backgroundColor: value }} />
      <select value={format} onChange={e => setFormat(e.target.value as typeof format)}>
        <option value="hex">HEX</option>
        <option value="hsl">HSL</option>
        <option value="rgb">RGB</option>
      </select>
      <input
        type="text"
        value={displayValue}
        onChange={e => handleChange(e.target.value)}
        onBlur={() => onCommit(value)} // Commit on blur, not on every keystroke
      />
      {/* Native color input as an alternative picker */}
      <input
        type="color"
        value={isValidHex(value) ? value : '#000000'}
        onChange={e => { handleChange(e.target.value); onCommit(e.target.value); }}
      />
    </div>
  );
}
```

## Contrast Checker

```ts
// WCAG contrast ratio: luminance formula from spec
// Show this on change — catches accessibility failures immediately
function getContrastRatio(hex1: string, hex2: string): number {
  const l1 = getLuminance(hex1);
  const l2 = getLuminance(hex2);
  const [lighter, darker] = l1 > l2 ? [l1, l2] : [l2, l1];
  return (lighter + 0.05) / (darker + 0.05);
}

function getLuminance(hex: string): number {
  const rgb = hexToRgbValues(hex);
  return rgb.map(v => {
    v /= 255;
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  }).reduce((acc, v, i) => acc + v * [0.2126, 0.7152, 0.0722][i], 0);
}

function ContrastChecker({ color }: { color: string }) {
  const onWhite = getContrastRatio(color, '#ffffff');
  const onBlack = getContrastRatio(color, '#000000');
  const passes = (ratio: number) => ratio >= 4.5; // WCAG AA for normal text

  return (
    <div className="contrast-checker">
      <span>On white: {onWhite.toFixed(2)} {passes(onWhite) ? '✓' : '✗ AA fail'}</span>
      <span>On black: {onBlack.toFixed(2)} {passes(onBlack) ? '✓' : '✗ AA fail'}</span>
    </div>
  );
}
```

## CSS Custom Properties for Live Preview

```tsx
// Update a CSS custom property — the entire UI reacts without DOM tree changes
function ThemeColorPicker({ token, value, onChange }: Props) {
  function handleChange(hex: string) {
    // Preview immediately — don't wait for parent state update
    document.documentElement.style.setProperty(`--color-${token}`, hex);
    onChange(hex);
  }

  return <ColorSwatchPicker value={value} onChange={handleChange} palette={BRAND_COLORS} />;
}
```

## Key Rules
- Store colors as hex internally; convert to/from HSL/RGB at the display layer
- Show contrast ratio against white and black on every color change — not just on save
- Use CSS custom properties for live previews — no DOM restructuring needed
- Keep an undo stack (last 10 changes) — color changes in theme editors are hard to reverse
- Offer both a bounded palette and a free-input mode in the same picker
- Commit free-text input on blur, not on every keystroke — partial strings are never valid
- Include `aria-label` with the hex value on each swatch for screen reader users

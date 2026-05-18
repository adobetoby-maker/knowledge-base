# Pattern: Auto-Formatted Number Input (Thousands Separators)

## Problem

Formatting a number as "1,234,567" while the user types causes cursor jump — the cursor position shifts when a comma is inserted mid-string. The correct approach formats on blur, stores the raw numeric value in state (not the formatted string), handles paste of formatted strings, and uses `Intl.NumberFormat` for locale awareness.

## Core Principle: Format on Blur, Not on Keystroke

```tsx
function NumberInput({ value, onChange, locale = 'en-US' }: Props) {
  // Display value: formatted string while idle, raw while editing
  const [displayValue, setDisplayValue] = useState(
    value != null ? formatNumber(value, locale) : ''
  );
  const [editing, setEditing] = useState(false);

  // Sync display when external value changes (e.g., form reset)
  useEffect(() => {
    if (!editing) {
      setDisplayValue(value != null ? formatNumber(value, locale) : '');
    }
  }, [value, editing, locale]);

  function handleFocus() {
    setEditing(true);
    // Show raw number while editing so cursor position is predictable
    setDisplayValue(value != null ? String(value) : '');
  }

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const raw = e.target.value.replace(/[^0-9.-]/g, '');  // strip commas user may paste
    setDisplayValue(e.target.value);
    const n = parseFloat(raw);
    if (!isNaN(n)) onChange(n);
    else if (raw === '' || raw === '-') onChange(null);
  }

  function handleBlur() {
    setEditing(false);
    const n = typeof value === 'number' ? value : null;
    setDisplayValue(n != null ? formatNumber(n, locale) : '');
  }

  return (
    <input
      type="text"          // NOT type="number" — number inputs don't support commas
      inputMode="decimal"  // triggers numeric keyboard on mobile
      value={displayValue}
      onChange={handleChange}
      onFocus={handleFocus}
      onBlur={handleBlur}
    />
  );
}
```

WHY `type="text"` not `type="number"`: `type="number"` browsers reject comma characters entirely, making thousand-separator display impossible. `inputMode="decimal"` gives the mobile numeric keyboard without the restrictions.

## Formatting with Intl.NumberFormat

```ts
function formatNumber(value: number, locale = 'en-US', decimals?: number): string {
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: decimals ?? 0,
    maximumFractionDigits: decimals ?? 2,
  }).format(value);
}

// Examples:
// formatNumber(1234567)         → "1,234,567"
// formatNumber(1234567, 'de-DE') → "1.234.567"  (German: dots as separators)
// formatNumber(1234.5, 'en-US', 2) → "1,234.50"
```

WHY `Intl.NumberFormat` instead of regex: regex hardcodes the comma separator, breaking for German (dots), French (spaces), and other locales.

## Paste Handling

Users paste formatted values like "1,234,567" from spreadsheets. Strip non-numeric characters before parsing:

```ts
function handlePaste(e: React.ClipboardEvent<HTMLInputElement>) {
  e.preventDefault();
  const pasted = e.clipboardData.getData('text');
  const stripped = pasted.replace(/[^0-9.-]/g, '');
  const n = parseFloat(stripped);
  if (!isNaN(n)) {
    onChange(n);
    setDisplayValue(formatNumber(n, locale));
  }
}
```

## Storing Raw Number vs Formatted String

Always store the raw `number` in form state. The formatted string is display-only:

```ts
// form state: { price: 1234567 }  ← raw number
// displayed:  "1,234,567"         ← formatted string in input
```

WHY: You need the raw number for math, API calls, and comparisons. Storing "1,234,567" means re-parsing it everywhere it's used — and re-parsing can silently fail.

## Key Rules

- Format on blur and on external value sync — never mid-keystroke (causes cursor jump)
- Show raw number string while focused, formatted string while blurred
- Use `type="text" inputMode="decimal"`, not `type="number"`
- Use `Intl.NumberFormat(locale)` for locale-correct separators (comma vs dot vs space)
- Strip non-numeric chars from paste via `onPaste` before parsing
- Store raw `number` in state; formatted string is view-only

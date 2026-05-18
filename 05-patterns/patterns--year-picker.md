# Pattern: Year-Only Picker

## Problem

Year pickers appear for birth year, graduation year, founding year, and similar fields. Full `<input type="date">` is overkill and forces users to pick a month and day they don't need. The choices are a `<select>` element (simple, accessible, mobile-friendly) or a custom scrollable grid. The `name` attribute must be present for form submissions.

## Select Element Approach (Recommended for Most Cases)

```tsx
type YearPickerProps = {
  name: string;
  value: number | '';
  onChange: (year: number | '') => void;
  minYear?: number;
  maxYear?: number;
  placeholder?: string;
};

function YearPicker({
  name,
  value,
  onChange,
  minYear = 1900,
  maxYear = new Date().getFullYear(),
  placeholder = 'Select year',
}: YearPickerProps) {
  // Descending order: most recent first (typical for birth year, graduation year)
  const years: number[] = [];
  for (let y = maxYear; y >= minYear; y--) {
    years.push(y);
  }

  return (
    <select
      name={name}
      value={value}
      onChange={e => onChange(e.target.value ? Number(e.target.value) : '')}
      aria-label="Year"
    >
      <option value="">{placeholder}</option>
      {years.map(y => (
        <option key={y} value={y}>{y}</option>
      ))}
    </select>
  );
}
```

WHY descending order: for birth years or graduation years, recent years are more common and should be at the top. For founding years or historical events, ascending may be more appropriate — pass the array order as a prop or sort accordingly.

## Direct Keyboard Input

For power users who want to type "1987" directly, combine a `<select>` with an `<input type="number">` as an alternative entry mode — or use only the number input with validation:

```tsx
function YearInput({ name, value, onChange, min = 1900, max = new Date().getFullYear() }: Props) {
  const [raw, setRaw] = useState(value ? String(value) : '');

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const str = e.target.value;
    setRaw(str);
    const n = parseInt(str, 10);
    if (!str) {
      onChange('');
    } else if (!isNaN(n) && n >= min && n <= max) {
      onChange(n);
    }
    // Do not call onChange for partial input ("19", "198") — let the user finish typing
  }

  function handleBlur() {
    const n = parseInt(raw, 10);
    if (isNaN(n) || n < min || n > max) {
      setRaw(value ? String(value) : '');  // reset on invalid blur
    }
  }

  return (
    <input
      type="number"
      name={name}
      value={raw}
      min={min}
      max={max}
      onChange={handleChange}
      onBlur={handleBlur}
      placeholder={String(max)}
    />
  );
}
```

WHY not call `onChange` on partial input: calling it with `19` when the user is typing `1985` would fire downstream effects (form validation, server calls) with an invalid year.

## Min/Max Constraints

Always constrain both ends:

```ts
// Birth year: reasonable human range
const BIRTH_YEAR_MIN = new Date().getFullYear() - 120;
const BIRTH_YEAR_MAX = new Date().getFullYear() - 13;  // 13+ for COPPA

// Graduation year: past + near future
const GRAD_YEAR_MIN = 1920;
const GRAD_YEAR_MAX = new Date().getFullYear() + 8;
```

## Form Submission

The `name` attribute ensures the value appears in `FormData` and HTML form submissions. Without `name`, the field is invisible to form parsers:

```html
<!-- This works with FormData, server actions, and native form submit -->
<select name="birth_year">...</select>
```

When using controlled React state with a server action, still include `name` — it costs nothing and makes progressive enhancement possible.

## Key Rules

- `<select>` is preferred: it's accessible, mobile-native, and keyboard-navigable with no extra work
- Always include a `name` attribute for form submission compatibility
- Defer `onChange` for number input until the year is complete (4 digits) or on blur
- Validate against explicit `min`/`max` constraints; reset to previous valid value on invalid blur
- Order years descending for biographical fields (birth, graduation); ascending for historical/founding dates

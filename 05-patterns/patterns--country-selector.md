# Pattern: Country Selector

## Overview

Searchable dropdown for selecting a country. Used in address forms, billing, phone inputs, and locale detection. Key considerations: the country list is long (~250 countries), requiring search; common countries should float to top; and the stored value should be ISO 3166-1 alpha-2 codes (`US`, `GB`, `DE`), not display names.

## Recommended: react-select with Custom List

```tsx
import Select from 'react-select'

// Country data: ISO code + name + flag emoji
const COUNTRIES = [
  { value: 'US', label: 'United States', flag: '🇺🇸' },
  { value: 'GB', label: 'United Kingdom', flag: '🇬🇧' },
  { value: 'CA', label: 'Canada', flag: '🇨🇦' },
  // ... all 249 ISO 3166-1 countries
]

// Common countries to pin at top
const PRIORITY_CODES = ['US', 'GB', 'CA', 'AU', 'DE', 'FR', 'JP', 'IN', 'BR']

const sortedCountries = [
  ...COUNTRIES.filter(c => PRIORITY_CODES.includes(c.value)),
  { value: '---', label: '─────────────', isDisabled: true },
  ...COUNTRIES.filter(c => !PRIORITY_CODES.includes(c.value)),
]

function CountrySelect({
  value,
  onChange,
}: {
  value: string
  onChange: (code: string) => void
}) {
  const selected = COUNTRIES.find(c => c.value === value) ?? null

  return (
    <Select
      options={sortedCountries}
      value={selected}
      onChange={option => option && !option.isDisabled && onChange(option.value)}
      formatOptionLabel={option => (
        <span className="flex items-center gap-2">
          <span>{option.flag}</span>
          <span>{option.label}</span>
        </span>
      )}
      filterOption={(option, input) =>
        option.data.label.toLowerCase().includes(input.toLowerCase()) ||
        option.data.value.toLowerCase().includes(input.toLowerCase())
      }
      placeholder="Select country..."
      isSearchable
    />
  )
}
```

## Country Data Source

Use `country-list` or `i18n-iso-countries` npm packages for the full list:

```ts
import countries from 'i18n-iso-countries'
import en from 'i18n-iso-countries/langs/en.json'
countries.registerLocale(en)

const countryOptions = Object.entries(countries.getNames('en'))
  .map(([code, name]) => ({ value: code, label: name }))
  .sort((a, b) => a.label.localeCompare(b.label))
```

## Flag Emojis

Flag emojis from ISO codes — each country code maps to two regional indicator letters:

```ts
function getFlagEmoji(countryCode: string): string {
  return countryCode
    .toUpperCase()
    .replace(/./g, char => String.fromCodePoint(127397 + char.charCodeAt(0)))
}
// 'US' → '🇺🇸'
```

Note: flag emojis don't display on Windows (only shows two letters). Use proper flag SVGs for Windows-critical UIs.

## Without react-select (Native)

For simpler forms or mobile-optimized interfaces, a native `<select>` is often better:

```tsx
<select value={value} onChange={e => onChange(e.target.value)}>
  <option value="">Select country</option>
  {PRIORITY_CODES.map(code => (
    <option key={code} value={code}>{countryName(code)}</option>
  ))}
  <option disabled>──────────</option>
  {allCountries.map(c => (
    <option key={c.value} value={c.value}>{c.label}</option>
  ))}
</select>
```

Native `<select>` is better on mobile because it uses the native OS picker, which is easier to scroll through.

## Key Rules

- Store ISO 3166-1 alpha-2 (2-letter code), not names — names differ between sources and languages.
- Float 6-10 most common countries to the top. Separate with a disabled divider option.
- Search should match both country name and code.
- For billing forms: country selection should trigger state/province field reconfiguration (US needs states, CA needs provinces, most others just need a free-text region).

# Pattern: Two-Column Form Layout

## Overview
Inline labels (label to the left of input) look clean but break on mobile and create misalignment when labels have different lengths. A two-column field grid is not the same as inline labels — it means placing two independent form fields side by side. Getting this wrong forces horizontal scrolling on small screens and breaks keyboard navigation order.

## Implementation

```tsx
// TwoColumnForm.tsx
export function AddressForm() {
  return (
    <form>
      {/* Full-width fields span both columns */}
      <div className="form-grid">

        {/* WRONG: cramming unrelated fields together to fill columns */}
        {/* RIGHT: group semantically related fields, let the layout follow */}

        <fieldset>
          <legend>Personal Information</legend>
          <div className="form-grid">
            {/* First name + Last name: genuinely side-by-side */}
            <FormField label="First name" htmlFor="first-name" required>
              <input id="first-name" name="firstName" type="text" autoComplete="given-name" />
            </FormField>

            <FormField label="Last name" htmlFor="last-name" required>
              <input id="last-name" name="lastName" type="text" autoComplete="family-name" />
            </FormField>
          </div>

          {/* Email is full-width — email addresses are long */}
          <FormField label="Email address" htmlFor="email" required fullWidth>
            <input id="email" name="email" type="email" autoComplete="email" />
          </FormField>
        </fieldset>

        <fieldset>
          <legend>Shipping Address</legend>
          <div className="form-grid">

            {/* Street address: full width */}
            <FormField label="Street address" htmlFor="address" fullWidth>
              <input id="address" name="address" type="text" autoComplete="street-address" />
            </FormField>

            {/* City: wider */}
            <FormField label="City" htmlFor="city" style={{ gridColumn: 'span 1' }}>
              <input id="city" name="city" type="text" autoComplete="address-level2" />
            </FormField>

            {/* State: medium */}
            <FormField label="State" htmlFor="state">
              <select id="state" name="state" autoComplete="address-level1">
                {/* options */}
              </select>
            </FormField>

            {/* ZIP code: short — field width matches expected input length */}
            <FormField label="ZIP code" htmlFor="zip" narrow>
              <input id="zip" name="zip" type="text" autoComplete="postal-code" maxLength={10} />
            </FormField>

          </div>
        </fieldset>

      </div>
    </form>
  )
}
```

```tsx
// FormField.tsx — reusable wrapper
interface FormFieldProps {
  label: string
  htmlFor: string
  required?: boolean
  fullWidth?: boolean
  narrow?: boolean
  children: React.ReactNode
  style?: React.CSSProperties
  error?: string
}

export function FormField({
  label, htmlFor, required, fullWidth, narrow, children, style, error
}: FormFieldProps) {
  return (
    <div
      style={{
        // CSS grid column spanning
        gridColumn: fullWidth ? '1 / -1' : narrow ? 'span 1' : undefined,
        ...style,
      }}
    >
      {/* Label always above the field — never inline/floating */}
      <label htmlFor={htmlFor} style={{ display: 'block', marginBottom: 4, fontWeight: 500 }}>
        {label}
        {required && <span aria-label="required" style={{ color: 'red', marginLeft: 2 }}>*</span>}
      </label>

      {children}

      {error && (
        <p role="alert" style={{ color: 'red', fontSize: 13, marginTop: 4 }}>{error}</p>
      )}
    </div>
  )
}
```

```css
/* form-grid: responsive 2-column layout */
.form-grid {
  display: grid;
  /* Two equal columns on desktop */
  grid-template-columns: 1fr 1fr;
  gap: 16px 24px;      /* row-gap column-gap */
}

/* Single column on mobile — below 640px */
@media (max-width: 640px) {
  .form-grid {
    grid-template-columns: 1fr;
  }

  /* On mobile, full-width fields behave the same as normal fields */
  .form-grid > * {
    grid-column: 1 / -1;
  }
}

/* Narrow variant for short fields like ZIP, phone extension */
.form-grid .field-narrow {
  max-width: 120px;
}

/* Consistent vertical rhythm: all fields same height when possible */
.form-grid input,
.form-grid select,
.form-grid textarea {
  width: 100%;
  height: 40px;
  padding: 8px 12px;
  box-sizing: border-box;
}

/* Textarea breaks the rhythm intentionally */
.form-grid textarea {
  height: auto;
  min-height: 80px;
  resize: vertical;
}
```

## Key Rules
- Label goes above the field, always — never to the left of the input (inline labels fail on narrow containers and wrapping labels misalign the grid).
- Use `<fieldset>` + `<legend>` to group related fields — this gives screen readers section context.
- Field width should reflect expected input length: ZIP code is shorter than street address; reflect that in the layout.
- Mobile (<640px) collapses to single column — never force two columns on mobile.
- Related fields belong side-by-side (first name + last name); unrelated fields sharing a row because there's space left is a mistake.
- Use CSS Grid, not flexbox, for two-column forms — grid handles the spanning and alignment more predictably.
- `autoComplete` attributes are required on address/personal fields — browsers and password managers rely on them.
- Tab order follows DOM order — make sure the visual order matches (`grid-column` reordering can break tab sequence).
- Error messages go directly below their field, not in a summary at the top (users scroll away from the summary before reading it).

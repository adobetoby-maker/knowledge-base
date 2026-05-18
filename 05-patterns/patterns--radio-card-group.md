# Radio Card Group

## Why Cards Instead of Native Radio Buttons

Card-based radio groups give each option a large clickable surface with rich content (icon, description, price). They're common for plan selection, shipping method, or preference pickers. The key challenge is making the large visual card map correctly to an underlying native radio input — without this, keyboard navigation and screen readers break.

## Structure: Visually Hidden Native Input

The native `<input type="radio">` must exist in the DOM for correct keyboard behavior and form submission, but it's visually hidden. The card is a `<label>` wrapping both the hidden input and the visible content. Clicking anywhere on the card activates the input because of the label-input relationship.

```tsx
<fieldset>
  <legend className="sr-only">Select plan</legend>
  <div role="radiogroup" className="grid gap-3 grid-cols-1 sm:grid-cols-3">
    {options.map(option => (
      <label
        key={option.value}
        className={cn(
          'relative flex cursor-pointer rounded-lg border p-4 transition-colors',
          'hover:bg-muted/50',
          selectedValue === option.value
            ? 'border-primary bg-primary/5 ring-2 ring-primary'
            : 'border-border'
        )}
      >
        {/* Visually hidden input — critical for a11y */}
        <input
          type="radio"
          name={name}
          value={option.value}
          checked={selectedValue === option.value}
          onChange={() => onChange(option.value)}
          className="sr-only"
        />
        {/* Visible card content */}
        <div className="flex flex-col gap-1">
          {option.icon && <option.icon className="h-5 w-5 text-primary" />}
          <span className="font-medium text-sm">{option.label}</span>
          {option.description && (
            <span className="text-xs text-muted-foreground">{option.description}</span>
          )}
        </div>
        {/* Selected checkmark */}
        {selectedValue === option.value && (
          <CheckCircle className="absolute top-3 right-3 h-4 w-4 text-primary" />
        )}
      </label>
    ))}
  </div>
</fieldset>
```

## Keyboard Navigation

Native radio inputs in a group respond to arrow keys automatically when they share the same `name` attribute. The browser moves focus and selection together when pressing ArrowLeft/ArrowRight or ArrowUp/ArrowDown. This is why the hidden input approach works without any custom `onKeyDown` handler.

Do not replace this with `role="radio"` + custom key handlers unless you have a specific reason. The native behavior is correct and well-tested; custom implementations regularly miss edge cases (RTL, disabled options).

## The `peer` Tailwind Pattern (CSS-Only Selected State)

If you prefer not to track state in JS (e.g., an uncontrolled form), use the CSS `peer` pattern:

```tsx
<label>
  <input
    type="radio"
    name={name}
    value={value}
    className="peer sr-only"
  />
  <div className="border-2 border-border peer-checked:border-primary peer-checked:bg-primary/5 peer-focus-visible:ring-2 peer-focus-visible:ring-ring ...">
    {/* card content */}
  </div>
</label>
```

`peer-checked:` applies styles to the next sibling when the input is checked. `peer-focus-visible:` shows a ring when the hidden input has keyboard focus — critical for accessibility (WCAG 2.4.7).

The `peer` pattern only works when the input is a *preceding sibling* of the element using `peer-checked:`. If you put the card content before the input in the DOM, it won't work.

## Form Integration

With react-hook-form:

```tsx
<Controller
  control={control}
  name="plan"
  render={({ field }) => (
    <RadioCardGroup
      name={field.name}
      value={field.value}
      onChange={field.onChange}
      options={planOptions}
    />
  )}
/>
```

For uncontrolled forms (e.g., Server Actions), rely on native radio `name`/`value` — the selected value is submitted automatically without any state management.

## Disabled Options

Disabled cards need `cursor-not-allowed opacity-50` on the label and `disabled` attribute on the input. Don't make the entire card `pointer-events-none` — it removes the visual cursor change that signals the option is unavailable.

## Key Rules

- Always use a visually hidden native `<input type="radio">` — never replace with a `div` and custom key handlers; native arrow-key navigation is free and correct
- Wrap the group in `<fieldset>` with `<legend>` — this is what screen readers announce as the group label
- `peer-focus-visible:ring-2` is required on the visible card — without it, keyboard users get no indication of which card has focus
- The `peer` pattern requires the input to appear *before* the styled element in DOM order — reordering breaks it
- For visual-only selected indicators (checkmark icons), supplement with `ring` or `border-color` change — don't rely on color alone (WCAG 1.4.1)

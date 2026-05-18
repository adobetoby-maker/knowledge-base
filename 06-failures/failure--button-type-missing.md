# Failure: Missing type="button" on Buttons Inside Forms

## Overview
The HTML specification defines the default `type` for `<button>` elements inside a `<form>` as `"submit"`. This means every button without an explicit `type` attribute inside a form is a submit button. When a user clicks what appears to be an unrelated button — a delete confirmation, a navigation button, an accordion toggle, a modal opener — the form is submitted. This causes page refreshes, accidental POST requests, data loss (form contents cleared on refresh), and hard-to-reproduce bugs because the behavior depends on the button's position in the DOM.

## The Browser Specification

```html
<!-- Default type="submit" — submits the form on click -->
<button>Click me</button>

<!-- Equivalent explicit declaration -->
<button type="submit">Submit</button>

<!-- Safe: does not submit the form -->
<button type="button">Click me</button>

<!-- Also valid: resets all form inputs to their default values -->
<button type="reset">Clear</button>
```

This applies to all browsers. It is not a quirk — it is the spec.

## Common Manifestations

### Delete Button Inside a Form
```html
<!-- Bug: clicking "Delete Image" submits the parent form -->
<form onSubmit={handleSave}>
  <input name="title" />
  <button onClick={openDeleteConfirm}>Delete Image</button> <!-- submits form! -->
  <button type="submit">Save</button>
</form>

<!-- Fix -->
<button type="button" onClick={openDeleteConfirm}>Delete Image</button>
```

### Accordion Toggle Inside a Form
```typescript
// Bug: clicking accordion header submits the form above it in the DOM
function OrderForm() {
  return (
    <form onSubmit={handleSubmit}>
      <input name="customerName" />
      <Accordion> {/* accordion buttons have no type="button" */}
        <AccordionTrigger>Order Details</AccordionTrigger>
        <AccordionContent>...</AccordionContent>
      </Accordion>
      <button type="submit">Place Order</button>
    </form>
  );
}
```

If `AccordionTrigger` renders a `<button>` without `type="button"`, clicking it submits the form.

### UI Library Components

Many UI libraries render `<button>` elements internally. These buttons often lack `type="button"`:
- Radix UI `<AccordionTrigger>` — renders a `<button>`, defaults to submit
- Headless UI `<Disclosure.Button>` — same issue
- Custom icon buttons in component libraries

Always check what HTML a component library renders when using its components inside forms.

## Detection

```bash
# Find buttons without type attribute in React files
grep -rn "<button" src/ | grep -v 'type=' | grep -v '//'

# Or use ESLint rule:
# react/button-has-type
```

Configure `eslint-plugin-react` with:
```json
{
  "rules": {
    "react/button-has-type": "error"
  }
}
```

This lint rule flags every `<button>` that does not have an explicit `type` attribute.

## The Rule in React

```typescript
// Every button needs explicit type:

// Submits form — intentional submit buttons
<button type="submit">Save Changes</button>

// Does NOT submit form — everything else
<button type="button" onClick={handleDelete}>Delete</button>
<button type="button" onClick={toggleAccordion}>Show Details</button>
<button type="button" onClick={openModal}>Edit</button>
<button type="button" aria-label="Close">&times;</button>
<button type="button" onClick={handlePrev}>←</button>
```

## Component Library Fix

When building reusable components that render a `<button>`:

```typescript
// Always default to type="button" in components — let callers opt into submit
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
}

export function Button({ type = "button", children, ...props }: ButtonProps) {
  return (
    <button type={type} {...props}>
      {children}
    </button>
  );
}

// Caller explicitly opts into submit behavior:
<Button type="submit">Save</Button>
<Button onClick={handleDelete}>Delete</Button> // defaults to type="button"
```

## Key Rules
- Every `<button>` inside a `<form>` must have an explicit `type` attribute
- `type="button"` for any button that is not the form's submit action
- `type="submit"` only for the button that should submit the form
- Enable `react/button-has-type` ESLint rule — catches this at lint time
- Audit UI library components used inside forms — they may render untyped buttons
- Default `type="button"` in all reusable Button components; callers pass `type="submit"` to opt in
- The symptom of this bug: form submits (page reloads, URL changes) when clicking an unrelated button

# Review: Forms QA Checklist

## Validation

- [ ] Required fields validated on submit (not just on blur)
- [ ] Inline field errors shown at the field level, not only as a banner
- [ ] Error messages are specific: "Enter a valid email" not "Invalid input"
- [ ] No double-submit possible (button disabled or `pending` state set)
- [ ] Server-side validation matches client-side (Zod schema reused)
- [ ] Error messages don't expose system details (no SQL errors, stack traces)

## Input Types

- [ ] `type="email"` on email fields (browser validates + mobile keyboard)
- [ ] `type="password"` on password fields (hidden input)
- [ ] `type="tel"` on phone number fields
- [ ] `type="number"` or `inputMode="decimal"` on numeric fields
- [ ] `type="date"` on date fields (or custom picker with `aria-label`)

## Autocomplete

- [ ] `autocomplete="email"` on email inputs
- [ ] `autocomplete="new-password"` on signup password
- [ ] `autocomplete="current-password"` on login password
- [ ] `autocomplete="name"` on name fields
- [ ] `autocomplete="tel"` on phone fields
- [ ] `autocomplete="street-address"` on address fields

## Accessibility

- [ ] Every input has an associated `<label>` (`htmlFor` matches input `id`)
- [ ] `aria-required="true"` on required fields
- [ ] `aria-invalid="true"` on fields with errors
- [ ] `aria-describedby` pointing to the error message element
- [ ] Error messages announced by screen reader when they appear

```tsx
// Accessible input with error
<div>
  <label htmlFor="email" className="text-sm font-medium">Email</label>
  <input
    id="email"
    type="email"
    aria-required="true"
    aria-invalid={!!errors.email}
    aria-describedby={errors.email ? 'email-error' : undefined}
  />
  {errors.email && (
    <p id="email-error" role="alert" className="text-sm text-red-600">
      {errors.email.message}
    </p>
  )}
</div>
```

## Submit Behavior

- [ ] Submit button disabled during submission
- [ ] Loading state shown during submission
- [ ] Success feedback shown after submit (redirect, toast, or inline message)
- [ ] Error feedback shown on failure
- [ ] Form doesn't reset on validation error (user loses their data)
- [ ] Form resets on successful submit

## File Upload Fields (if present)

- [ ] File type restricted (both `accept` attribute and server validation)
- [ ] File size limit communicated and enforced
- [ ] Upload progress shown for large files
- [ ] File preview shown before submit

## Multi-Step Forms

- [ ] State preserved when navigating between steps
- [ ] Back button doesn't clear filled fields
- [ ] Step indicator shows current progress
- [ ] Final review step shows entered data before submit

## Security

- [ ] CSRF protection (Next.js Server Actions provide this automatically)
- [ ] Rate limiting on submission endpoints
- [ ] Sensitive fields (`password`, `card`) not logged anywhere
- [ ] File uploads validated for type and size on server, not just client

## Browser Compatibility

- [ ] Works without JavaScript (Server Action fallback for critical forms)
- [ ] Keyboard navigation through all fields works
- [ ] Tab order is logical
- [ ] Enter key submits the form (default browser behavior)

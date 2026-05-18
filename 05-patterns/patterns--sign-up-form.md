# Pattern: Sign-Up Form

## Why This Pattern Matters

Registration is the highest-friction step in any funnel. Poor UX here abandons users permanently — they won't retry. Every validation delay, unclear error, or missing affordance costs a conversion. The goal is to confirm validity *before* submission, never after.

## Structure

Three fields minimum: email, password, confirm password. Add first name only if your onboarding genuinely needs it — every extra field drops conversion ~5%.

```tsx
const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  confirmPassword: z.string(),
  terms: z.literal(true, { errorMap: () => ({ message: 'You must accept the terms' }) }),
}).refine(d => d.password === d.confirmPassword, {
  message: 'Passwords do not match',
  path: ['confirmPassword'],
});
```

## Email Availability Check

Debounce the server check to avoid hammering the endpoint on every keystroke. 600ms is the right delay — fast enough to feel live, slow enough to batch keystrokes.

```ts
const checkEmail = useDebouncedCallback(async (email: string) => {
  if (!z.string().email().safeParse(email).success) return;
  const taken = await checkEmailAvailability(email);
  if (taken) form.setError('email', { message: 'Email already in use' });
}, 600);
```

Show a spinner in the email field while the check is in flight. Don't block the submit button waiting for it — let the server reject on submit if the race condition fires.

## Real-Time Password Strength Meter

Calculate strength from entropy signals, not just length:

```ts
function strength(pw: string): 0 | 1 | 2 | 3 {
  let score = 0;
  if (pw.length >= 10) score++;
  if (/[A-Z]/.test(pw) && /[a-z]/.test(pw)) score++;
  if (/\d/.test(pw) && /[^A-Za-z0-9]/.test(pw)) score++;
  return score as 0 | 1 | 2 | 3;
}
```

Render a segmented bar (3–4 segments, color-coded weak→strong). Show it only after the user has typed ≥3 characters — showing it immediately on focus is noise. Never hide error messages behind the strength bar.

## Terms Acceptance

Use a `<Checkbox>` not a click-through. Link opens in a new tab — never navigate away from the form. Validation error shows inline below the checkbox, not in a toast.

```tsx
<label className="flex gap-2 items-start text-sm">
  <Checkbox {...form.register('terms')} />
  <span>
    I agree to the{' '}
    <a href="/terms" target="_blank" className="underline">Terms of Service</a>
    {' '}and{' '}
    <a href="/privacy" target="_blank" className="underline">Privacy Policy</a>
  </span>
</label>
```

## Post-Registration Redirect

After successful registration, redirect to the next meaningful step — not the home page. If onboarding is required, go to `/onboarding`. If email verification is needed, go to `/check-email` with the email address in state (not URL, to prevent bookmark spam). Store the intended destination in `searchParams.get('next')` before the form renders so deep links survive registration.

```ts
const next = searchParams.get('next') ?? '/dashboard';
router.replace(next);
```

## Prevent Double-Submit

Disable the submit button after first click and show a spinner. Re-enable only on error response. Never rely on the user not clicking twice.

## Key Rules

- Debounce email availability check: 600ms minimum
- Show password strength only after 3+ characters typed
- Confirm password validates on blur, not on change (avoids premature mismatch error)
- Terms link opens `target="_blank"` — never navigate away
- Redirect to intended destination via `?next=` param, not always `/dashboard`
- Disable submit on first click; re-enable on error
- Server errors (duplicate email race) show in the email field, not a generic toast

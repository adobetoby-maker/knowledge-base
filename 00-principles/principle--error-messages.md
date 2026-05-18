# Error Messages

## The Core Rule

Error messages are for humans, not for developers. They explain what happened, what it means, and what to do next — not which function threw or which line failed.

## Bad vs Good

```
BAD:  "Error: PGRST116"
BAD:  "Uncaught TypeError: Cannot read properties of null"
BAD:  "Something went wrong"  (gives up entirely)
BAD:  "Internal server error"  (defensive, vague)
BAD:  "Invalid input"  (doesn't say what or why)

GOOD: "Couldn't save your changes. Check your internet connection and try again."
GOOD: "That email address is already in use. Sign in instead, or use a different email."
GOOD: "Payment declined. Contact your bank or try a different card."
GOOD: "Invoice #1042 not found. It may have been deleted."
```

## Error Message Formula

For every error, answer: **What happened + Why (if helpful) + What to do**

```
"[Action] failed. [Reason if user-actionable]. [Next step]."

"Couldn't send the email. Check that the address is correct and try again."
"Failed to save. You may have been signed out — refresh the page."
"Payment failed. Your card was declined. Try a different card."
```

Drop the reason if it's technical and not actionable:
```
"Failed to load your invoices. Refresh the page to try again."
// Don't add: "Database connection timeout" — user can't act on this
```

## Form Field Errors

Field-level errors must be specific:
```
BAD:  "Invalid"
BAD:  "This field is required"   (generic)
GOOD: "Email is required"
GOOD: "Password must be at least 8 characters"
GOOD: "Phone number must include area code (e.g., 208-595-2101)"
```

Root-level form errors for submission failures:
```typescript
// After server action returns an error:
form.setError('root', {
  message: 'Couldn\'t create invoice. Check all fields and try again.'
})

// Render it:
{form.formState.errors.root && (
  <Alert variant="destructive">
    <AlertDescription>{form.formState.errors.root.message}</AlertDescription>
  </Alert>
)}
```

## Zod Error Messages

Override defaults for user-facing validation:
```typescript
const schema = z.object({
  email: z.string()
    .min(1, 'Email is required')  // overrides "String must contain at least 1 character(s)"
    .email('Enter a valid email address'),  // overrides "Invalid email"
  phone: z.string()
    .regex(/^\d{10}$/, 'Enter a 10-digit phone number (no dashes)'),
  amount: z.coerce.number()
    .positive('Amount must be greater than $0')
    .max(99999, 'Amount cannot exceed $99,999'),
})
```

## Supabase Error Handling

Supabase returns error codes — map them to user messages:
```typescript
function handleSupabaseError(error: PostgrestError): string {
  switch (error.code) {
    case '23505':  // unique constraint violation
      return 'This record already exists.'
    case '23503':  // foreign key violation
      return 'Cannot delete this record — other data depends on it.'
    case 'PGRST116':  // no rows found
      return 'Record not found.'
    default:
      console.error('Supabase error:', error)
      return 'Something went wrong. Try again in a moment.'
  }
}
```

## Network Errors

```typescript
async function loadData() {
  try {
    return await fetchInvoices()
  } catch (error) {
    if (error instanceof TypeError && error.message.includes('fetch')) {
      // Network error — user is offline or server is down
      return { error: 'Couldn\'t connect. Check your internet and try again.' }
    }
    console.error(error)
    return { error: 'Failed to load data. Refresh the page.' }
  }
}
```

## Error Pages

For 404 and server errors, give context and escape routes:
```typescript
// app/not-found.tsx
export default function NotFound() {
  return (
    <div>
      <h1>Page not found</h1>
      <p>This page doesn't exist or was moved.</p>
      <Link href="/">Go to homepage</Link>
      <Link href="/contact">Contact us</Link>
    </div>
  )
}
```

For local business sites: the 404 page is an opportunity to get the user back on track — include the phone number, navigation links, and a search box if available.

## Never Show

- Stack traces in production
- SQL error text
- Internal error codes (log them, don't display)
- Database table/column names
- Server-side file paths
- Authentication status details ("No user found in DB" is a security leak)

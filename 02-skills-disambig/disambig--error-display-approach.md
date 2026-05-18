# Disambig: Error Display Approach

## The Question

An error occurred — how should it be shown to the user?

## Decision Table

| Error Type | Context | Display Pattern |
|-----------|---------|-----------------|
| Form field validation | User submitting a form | Inline field error (red text below field) |
| Form-level error (e.g., duplicate email) | Form submission | Banner above form submit button |
| Async action failure (e.g., save failed) | After user action | Toast notification |
| Page-level data load failure | Server Component / fetch | Error state with retry button |
| Session expired | Any page | Redirect to login + "session expired" message |
| 404 Not Found | Navigation | Next.js `not-found.tsx` |
| 500 Server Error | Critical failure | Next.js `error.tsx` with boundary |
| Network offline | Any action | Toast with offline indicator |
| Permission denied | User tries forbidden action | Toast "You don't have permission to..." |

## Inline Field Errors

```tsx
<div>
  <Input {...register('email')} />
  {errors.email && (
    <p className="text-sm text-destructive mt-1" role="alert">
      {errors.email.message}
    </p>
  )}
</div>
```

Use for: field-specific validation failures (required, format, range).
Don't use for: server errors that aren't tied to a specific field.

## Form-Level Banner

```tsx
{formError && (
  <div role="alert" className="rounded-md bg-destructive/10 p-3 text-sm text-destructive flex items-start gap-2">
    <AlertCircle className="h-4 w-4 mt-0.5 shrink-0" />
    <span>{formError}</span>
  </div>
)}
```

Use for: errors from server validation that apply to the whole form (duplicate entry, business rule violation).
Place: above the submit button, so it's visible after the user scrolls to submit.

## Toast Notification

```ts
import { toast } from 'sonner'

// Success
toast.success('Invoice saved')

// Error
toast.error('Failed to save — please try again')

// With action
toast.error('Connection lost', {
  action: { label: 'Retry', onClick: handleRetry }
})
```

Use for: async mutations, background operations, confirmations of completed actions.
Don't use for: validation errors that require the user to fix something before continuing.

## Page-Level Error State

```tsx
// In a Server Component:
const { data, error } = await supabase.from('invoices').select('*')
if (error) {
  return (
    <div className="text-center py-12">
      <AlertCircle className="h-8 w-8 text-destructive mx-auto mb-3" />
      <h2 className="font-semibold">Could not load invoices</h2>
      <p className="text-sm text-muted-foreground mt-1">{error.message}</p>
      <Button variant="outline" size="sm" className="mt-4" onClick={() => location.reload()}>
        Try again
      </Button>
    </div>
  )
}
```

Use for: data that the whole page depends on, where there's no partial content to show.

## Empty State vs Error State

Don't conflate these:
- **Empty state**: The query succeeded, but returned 0 results. Show an encouraging "no items yet" message with a CTA.
- **Error state**: The query failed. Show what went wrong and how to resolve it.

```tsx
if (error) return <ErrorState message={error.message} />
if (!invoices?.length) return <EmptyState onAddNew={() => setModalOpen(true)} />
return <InvoiceTable invoices={invoices} />
```

## Error Message Content

**For users**: plain language, describe what happened, offer next steps.
- Bad: "Error: PGRST116 (22P02)"
- Good: "This invoice doesn't exist or was deleted. Return to invoices."

**Never expose**: stack traces, SQL, internal error codes, file paths, `process.env` values.

**Always log to server**: Even if the user sees a friendly message, log the full error on the server for debugging.

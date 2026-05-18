# Plugin: react-hot-toast

## What It Is

Lightweight toast notification library. 5KB. Supports success/error/loading/custom toasts, auto-dismiss, promise toast for async operations, custom positions, and custom renders. Alternative to Sonner for projects that don't use shadcn/ui.

## Installation

```bash
npm install react-hot-toast
```

## Setup

```tsx
// app/layout.tsx
import { Toaster } from 'react-hot-toast'

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Toaster
          position="top-right"
          toastOptions={{
            duration: 4000,
            style: {
              background: '#363636',
              color: '#fff',
              borderRadius: '8px',
            },
            success: { duration: 3000 },
            error: { duration: 5000 },
          }}
        />
      </body>
    </html>
  )
}
```

## Basic Usage

```ts
import toast from 'react-hot-toast'

// Simple
toast('Order saved')
toast.success('Invoice sent!')
toast.error('Failed to save — try again')

// With options
toast.success('Copied!', {
  duration: 2000,
  icon: '📋',
})

// Custom style
toast('Processing...', {
  style: {
    border: '1px solid #2563eb',
    padding: '12px 16px',
    color: '#1d4ed8',
  },
})
```

## Promise Toast (Best Pattern for Async)

```tsx
async function handleSubmit() {
  await toast.promise(
    submitInvoice(invoiceData),
    {
      loading: 'Sending invoice...',
      success: 'Invoice sent!',
      error: 'Failed to send invoice',
    }
  )
}
```

`toast.promise` automatically handles three states: loading while promise is pending, success on resolve, error on reject. Use for any async action.

```tsx
// Dynamic success message (access resolved value)
await toast.promise(
  createInvoice(data),
  {
    loading: 'Creating invoice...',
    success: (invoice) => `Invoice #${invoice.number} created`,
    error: (err) => `Error: ${err.message}`,
  }
)
```

## Custom Toast Component

```tsx
toast.custom((t) => (
  <div
    className={`flex items-center gap-3 bg-white border rounded-lg shadow-lg p-4 max-w-sm
      ${t.visible ? 'animate-enter' : 'animate-leave'}`}
  >
    <div className="text-green-500">✓</div>
    <div>
      <p className="font-medium text-sm">Payment received</p>
      <p className="text-xs text-gray-500">Invoice #1042 — $847.50</p>
    </div>
    <button onClick={() => toast.dismiss(t.id)} className="ml-auto text-gray-400">
      ×
    </button>
  </div>
), { duration: 5000 })
```

## Loading Toast (Manual)

```tsx
async function handleSave() {
  const toastId = toast.loading('Saving...')

  try {
    await saveData()
    toast.success('Saved!', { id: toastId })
  } catch (err) {
    toast.error('Save failed', { id: toastId })
  }
}
```

Using the same `id` replaces the loading toast instead of stacking.

## Dismiss Control

```ts
toast.dismiss()           // Dismiss all toasts
toast.dismiss(toastId)    // Dismiss specific toast

// Auto-dismiss is handled by duration option
```

## When to Use vs Alternatives

| Library | When to use |
|---------|------------|
| `react-hot-toast` | Standalone projects, not using shadcn |
| Sonner (`sonner`) | shadcn/ui projects (style matches) |
| shadcn Toast | When you need full shadcn integration |
| Browser `alert()` | Never — blocks thread, no styling |

For projects using shadcn/ui, prefer Sonner — it's built by the shadcn team and matches the design system. For projects without shadcn, `react-hot-toast` is the lightest option.

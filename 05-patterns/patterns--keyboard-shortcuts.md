# Keyboard Shortcuts

## When to Add Shortcuts

Add keyboard shortcuts for:
- Actions users repeat many times per session (save, new record, search)
- Power-user workflows (next/prev item, toggle view)
- Global navigation (go to invoices, go to customers)

Do NOT add shortcuts for destructive actions (delete) without a confirmation step.

## useHotkeys Pattern

```typescript
import { useHotkeys } from 'react-hotkeys-hook'

// Component-scoped shortcut:
function InvoiceForm() {
  useHotkeys('ctrl+s, meta+s', (e) => {
    e.preventDefault()
    handleSubmit()
  }, { enableOnFormTags: ['INPUT', 'TEXTAREA', 'SELECT'] })
}

// Global navigation shortcut (register once at root):
function AppShell() {
  useHotkeys('g i', () => router.push('/admin/invoices'), { scopes: ['app'] })
  useHotkeys('g c', () => router.push('/admin/customers'), { scopes: ['app'] })
  useHotkeys('/', () => document.getElementById('search-input')?.focus(), {
    preventDefault: true,
  })
}
```

`enableOnFormTags` is required for shortcuts inside form fields — by default, useHotkeys ignores events from inputs to avoid interfering with typing.

## Keyboard Shortcut Map

Define shortcuts in one place, reference everywhere:

```typescript
// lib/shortcuts.ts
export const SHORTCUTS = {
  newInvoice: { keys: 'n', description: 'New invoice', scope: 'invoices' },
  search: { keys: '/', description: 'Focus search', scope: 'global' },
  save: { keys: 'ctrl+s, meta+s', description: 'Save', scope: 'form' },
  escape: { keys: 'esc', description: 'Close / cancel', scope: 'global' },
  nextItem: { keys: 'j', description: 'Next item', scope: 'list' },
  prevItem: { keys: 'k', description: 'Previous item', scope: 'list' },
} as const

// ShortcutHint component (shows in UI):
export function ShortcutHint({ keys }: { keys: string }) {
  const parts = keys.split('+')
  return (
    <span className="text-xs text-muted-foreground flex gap-0.5">
      {parts.map((part, i) => (
        <kbd key={i} className="px-1 py-0.5 bg-muted rounded border border-border font-mono text-[10px]">
          {part === 'meta' ? '⌘' : part === 'ctrl' ? 'Ctrl' : part}
        </kbd>
      ))}
    </span>
  )
}
```

## Shortcut Help Modal

Users forget shortcuts — add a help dialog:

```typescript
function ShortcutsHelp() {
  const [open, setOpen] = useState(false)
  
  useHotkeys('?', () => setOpen(true))
  
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Keyboard Shortcuts</DialogTitle>
        </DialogHeader>
        <div className="grid grid-cols-2 gap-4">
          {Object.entries(SHORTCUTS).map(([key, shortcut]) => (
            <div key={key} className="flex justify-between items-center">
              <span className="text-sm">{shortcut.description}</span>
              <ShortcutHint keys={shortcut.keys} />
            </div>
          ))}
        </div>
      </DialogContent>
    </Dialog>
  )
}
```

## j/k List Navigation

Vim-style navigation for lists of items:

```typescript
function InvoiceList({ invoices }: { invoices: Invoice[] }) {
  const [selected, setSelected] = useState(0)
  const router = useRouter()
  
  useHotkeys('j', () => setSelected(i => Math.min(i + 1, invoices.length - 1)))
  useHotkeys('k', () => setSelected(i => Math.max(i - 1, 0)))
  useHotkeys('enter', () => router.push(`/invoices/${invoices[selected].id}`))
  
  return (
    <ul>
      {invoices.map((invoice, i) => (
        <li
          key={invoice.id}
          className={cn('p-3 cursor-pointer', i === selected && 'bg-accent ring-2 ring-primary')}
          onClick={() => setSelected(i)}
        >
          {invoice.number}
        </li>
      ))}
    </ul>
  )
}
```

## Conflict Rules

- Prefer single letters for list navigation (`j/k/n/e`)
- Use `meta+` (Mac) / `ctrl+` (Windows) for actions that map to OS conventions
- `Escape` = cancel/close, always
- Never override browser shortcuts (`ctrl+t`, `ctrl+w`, `ctrl+r`)
- Test: open DevTools and verify your shortcut doesn't fire inside inputs where it shouldn't

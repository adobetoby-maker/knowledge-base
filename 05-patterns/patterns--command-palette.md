# Command Palette Pattern

## What It Is

A keyboard-driven search modal (⌘K / Ctrl+K) that lets users quickly navigate, search, and execute actions without reaching for the mouse. Common in developer tools, admin panels, and productivity apps.

## Using cmdk (shadcn/ui Command)

shadcn/ui's `Command` component wraps `cmdk`. Install:
```bash
npx shadcn@latest add command dialog
```

## Full Command Palette Implementation

```typescript
'use client'
import * as React from 'react'
import { useRouter } from 'next/navigation'
import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
  CommandShortcut,
} from '@/components/ui/command'
import { FileText, Settings, Users, Plus, Search } from 'lucide-react'

export function CommandPalette() {
  const [open, setOpen] = React.useState(false)
  const router = useRouter()

  // ⌘K to open
  React.useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        setOpen((open) => !open)
      }
    }
    document.addEventListener('keydown', down)
    return () => document.removeEventListener('keydown', down)
  }, [])

  function navigate(path: string) {
    router.push(path)
    setOpen(false)
  }

  return (
    <CommandDialog open={open} onOpenChange={setOpen}>
      <CommandInput placeholder="Type a command or search..." />
      <CommandList>
        <CommandEmpty>No results found.</CommandEmpty>

        <CommandGroup heading="Navigation">
          <CommandItem onSelect={() => navigate('/portal/invoices')}>
            <FileText className="mr-2 h-4 w-4" />
            <span>Invoices</span>
          </CommandItem>
          <CommandItem onSelect={() => navigate('/admin/customers')}>
            <Users className="mr-2 h-4 w-4" />
            <span>Customers</span>
          </CommandItem>
          <CommandItem onSelect={() => navigate('/admin/settings')}>
            <Settings className="mr-2 h-4 w-4" />
            <span>Settings</span>
            <CommandShortcut>⌘S</CommandShortcut>
          </CommandItem>
        </CommandGroup>

        <CommandSeparator />

        <CommandGroup heading="Actions">
          <CommandItem onSelect={() => navigate('/portal/invoices/new')}>
            <Plus className="mr-2 h-4 w-4" />
            <span>New Invoice</span>
            <CommandShortcut>⌘N</CommandShortcut>
          </CommandItem>
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  )
}
```

## Dynamic Search Results

Fetch search results as the user types:
```typescript
export function CommandPaletteWithSearch() {
  const [open, setOpen] = React.useState(false)
  const [query, setQuery] = React.useState('')
  const [results, setResults] = React.useState<SearchResult[]>([])
  const [loading, setLoading] = React.useState(false)

  React.useEffect(() => {
    if (!query.trim()) {
      setResults([])
      return
    }

    const timer = setTimeout(async () => {
      setLoading(true)
      const res = await fetch(`/api/search?q=${encodeURIComponent(query)}`)
      const data = await res.json()
      setResults(data.results)
      setLoading(false)
    }, 200)  // 200ms debounce

    return () => clearTimeout(timer)
  }, [query])

  return (
    <CommandDialog open={open} onOpenChange={setOpen}>
      <CommandInput
        placeholder="Search invoices, customers..."
        value={query}
        onValueChange={setQuery}
      />
      <CommandList>
        {loading && <CommandEmpty>Searching...</CommandEmpty>}
        {!loading && query && results.length === 0 && (
          <CommandEmpty>No results for "{query}"</CommandEmpty>
        )}
        {results.length > 0 && (
          <CommandGroup heading="Results">
            {results.map((result) => (
              <CommandItem key={result.id} onSelect={() => navigate(result.url)}>
                <Search className="mr-2 h-4 w-4" />
                <div>
                  <p>{result.title}</p>
                  <p className="text-xs text-muted-foreground">{result.type}</p>
                </div>
              </CommandItem>
            ))}
          </CommandGroup>
        )}
      </CommandList>
    </CommandDialog>
  )
}
```

## Trigger Button

Add a search trigger button to the navbar:
```typescript
export function SearchTrigger() {
  const [open, setOpen] = React.useState(false)

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="flex items-center gap-2 px-3 py-1.5 text-sm text-muted-foreground border rounded-md hover:bg-accent"
      >
        <Search className="h-4 w-4" />
        <span>Search...</span>
        <kbd className="ml-auto pointer-events-none select-none hidden sm:flex items-center gap-1 rounded border bg-muted px-1.5 text-xs">
          <span>⌘</span>K
        </kbd>
      </button>
      <CommandPalette open={open} onOpenChange={setOpen} />
    </>
  )
}
```

## Placement

Render `CommandPalette` once at the layout level, not inside individual pages. This ensures the keyboard shortcut works everywhere:

```typescript
// app/(portal)/layout.tsx
export default function PortalLayout({ children }) {
  return (
    <>
      <CommandPalette />
      <Sidebar />
      <main>{children}</main>
    </>
  )
}
```

## Accessibility

- `CommandDialog` uses Radix Dialog underneath — focus trap and aria roles are handled
- Keyboard navigation (↑↓ arrows) works automatically via cmdk
- Escape closes the palette
- Ensure `CommandItem` labels are descriptive (screen readers read them)

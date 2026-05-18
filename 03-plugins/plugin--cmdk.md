# Plugin: cmdk (Command Menu)

## Overview

cmdk is the headless primitive behind shadcn/ui's Command component. Provides accessible command palette/combobox: fuzzy search, keyboard navigation, groups, custom rendering. Use directly or via shadcn/ui's `<Command>`.

## Installation

```bash
npm install cmdk
```

## Basic Command Palette

```tsx
import { Command } from 'cmdk'

function CommandPalette({ open, onClose }: { open: boolean; onClose: () => void }) {
  const router = useRouter()

  function navigate(path: string) {
    router.push(path)
    onClose()
  }

  return (
    <div
      className={`fixed inset-0 z-50 bg-black/50 flex items-start justify-center pt-20 ${open ? '' : 'hidden'}`}
      onClick={onClose}
    >
      <Command
        className="w-full max-w-xl bg-white rounded-xl shadow-2xl border overflow-hidden"
        onClick={e => e.stopPropagation()}
      >
        <Command.Input
          placeholder="Search..."
          className="w-full px-4 py-3 text-sm border-b outline-none"
        />
        <Command.List className="max-h-80 overflow-y-auto p-2">
          <Command.Empty className="py-6 text-center text-sm text-gray-500">
            No results found
          </Command.Empty>

          <Command.Group heading="Navigation" className="[&>div]:px-2 [&>div]:py-1 [&>div]:text-xs [&>div]:text-gray-500">
            <Command.Item onSelect={() => navigate('/dashboard')} className="flex items-center gap-2 px-3 py-2 text-sm rounded cursor-pointer aria-selected:bg-gray-100">
              Dashboard
            </Command.Item>
            <Command.Item onSelect={() => navigate('/settings')} className="flex items-center gap-2 px-3 py-2 text-sm rounded cursor-pointer aria-selected:bg-gray-100">
              Settings
            </Command.Item>
          </Command.Group>

          <Command.Separator className="my-1 border-t" />

          <Command.Group heading="Actions">
            <Command.Item onSelect={() => openModal('create')} className="flex items-center gap-2 px-3 py-2 text-sm rounded cursor-pointer aria-selected:bg-gray-100">
              Create new...
            </Command.Item>
          </Command.Group>
        </Command.List>
      </Command>
    </div>
  )
}
```

## Keyboard Shortcut Trigger

```tsx
function App() {
  const [open, setOpen] = useState(false)

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        setOpen(o => !o)
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [])

  return <CommandPalette open={open} onClose={() => setOpen(false)} />
}
```

## Dynamic / Async Search

```tsx
const [search, setSearch] = useState('')
const [results, setResults] = useState<SearchResult[]>([])

useEffect(() => {
  if (!search) { setResults([]); return }
  
  const timer = setTimeout(async () => {
    const data = await searchAPI(search)
    setResults(data)
  }, 150)  // Debounce

  return () => clearTimeout(timer)
}, [search])

<Command shouldFilter={false}>  {/* Disable built-in filtering when you have server results */}
  <Command.Input value={search} onValueChange={setSearch} />
  <Command.List>
    {results.map(r => (
      <Command.Item key={r.id} value={r.id} onSelect={() => navigate(r.url)}>
        {r.title}
      </Command.Item>
    ))}
  </Command.List>
</Command>
```

## shadcn/ui Integration

If using shadcn/ui, the `Command` component wraps cmdk with pre-styled variants:

```tsx
import { Command, CommandInput, CommandList, CommandItem, CommandGroup, CommandEmpty, CommandSeparator } from '@/components/ui/command'
```

Same API — just styled and with Dialog wrapping built in.

## Key Rules

- `aria-selected` is what cmdk adds to the focused item — style using `aria-selected:bg-gray-100` (not `:hover` alone, since keyboard focus doesn't trigger hover).
- `shouldFilter={false}` when results come from a server — otherwise cmdk filters server results against the local list.
- The `value` prop on `Command.Item` is used for filtering and must be unique when `shouldFilter={true}`.
- Trap focus inside the palette when it's open — cmdk handles this with ARIA but you still need the modal overlay to prevent background interaction.

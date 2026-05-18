# Pattern: Command Menu (Cmd+K Palette)

A keyboard-triggered overlay for searching and executing commands. Opens on `Cmd+K` / `Ctrl+K`, shows grouped results with fuzzy search, and closes on action or `Escape`. Different from `patterns--command-palette.md` in that this focuses on the `cmdk` library integration and grouping strategy.

## Why It Matters

Command menus reduce navigation friction for power users. The lookup cost of "remember where this setting lives" drops to zero when any action is one `Cmd+K` away. Key quality factors: instant open, no loading flash, recency sorting, and not accidentally triggering on `K` in form fields.

## cmdk Integration

```tsx
import { Command } from 'cmdk';

function CommandMenu({ open, onClose }: { open: boolean; onClose: () => void }) {
  return (
    <Command.Dialog
      open={open}
      onOpenChange={onClose}
      label="Command menu"
      className="command-menu"
      // cmdk handles all keyboard nav internally
    >
      <Command.Input placeholder="Search commands..." autoFocus />
      <Command.List>
        <Command.Empty>No results found.</Command.Empty>

        <Command.Group heading="Recent">
          {recentCommands.map(cmd => (
            <Command.Item
              key={cmd.id}
              value={cmd.searchValue}
              onSelect={() => { cmd.action(); onClose(); }}
            >
              <cmd.Icon aria-hidden />
              {cmd.label}
              {cmd.shortcut && <kbd>{cmd.shortcut}</kbd>}
            </Command.Item>
          ))}
        </Command.Group>

        <Command.Group heading="Navigation">
          {navCommands.map(cmd => (
            <Command.Item key={cmd.id} value={cmd.searchValue} onSelect={() => { cmd.action(); onClose(); }}>
              {cmd.label}
            </Command.Item>
          ))}
        </Command.Group>
      </Command.List>
    </Command.Dialog>
  );
}
```

## Global Shortcut Handler

Attach at the document level in a layout component or custom hook:

```ts
function useCommandMenu() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    function handler(e: KeyboardEvent) {
      // Don't fire when user is typing in an input/textarea/contenteditable
      const tag = (e.target as HTMLElement).tagName;
      const isEditable = tag === 'INPUT' || tag === 'TEXTAREA' ||
        (e.target as HTMLElement).isContentEditable;
      if (isEditable) return;

      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setOpen(o => !o);
      }
    }
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, []);

  return { open, setOpen };
}
```

The `isEditable` guard is critical. Without it, `Cmd+K` while typing in a form field will steal focus and corrupt the user's input.

## Recent Commands at Top

Track recency in localStorage:

```ts
const RECENT_KEY = 'cmd_recent';
const MAX_RECENT = 5;

function recordCommand(id: string) {
  const recent = getRecent();
  const updated = [id, ...recent.filter(r => r !== id)].slice(0, MAX_RECENT);
  localStorage.setItem(RECENT_KEY, JSON.stringify(updated));
}

function getRecent(): string[] {
  try { return JSON.parse(localStorage.getItem(RECENT_KEY) ?? '[]'); }
  catch { return []; }
}

// Derive recent commands at render time — don't store them in React state
const recentCommands = getRecent()
  .map(id => ALL_COMMANDS.find(c => c.id === id))
  .filter(Boolean);
```

Hide the Recent group when there are no recent items or when the user is actively searching (non-empty query means recency is irrelevant—fuzzy match across all commands instead).

## Grouped Results Strategy

Groups communicate taxonomy. Standard groupings:

```ts
const GROUPS = [
  { id: 'recent',     label: 'Recent',     commands: recentCommands },
  { id: 'navigation', label: 'Navigation', commands: navCommands },
  { id: 'actions',    label: 'Actions',    commands: actionCommands },
  { id: 'settings',   label: 'Settings',   commands: settingsCommands },
];
```

Render groups dynamically—hide any group with zero matching items. `cmdk` handles this automatically when `Command.Item` values don't match the search query.

## Keyboard Navigation

`cmdk` handles all navigation internally:
- `ArrowUp` / `ArrowDown` — move between items
- `Enter` — execute focused item
- `Escape` — close dialog
- Typing — filters in real time via fuzzy match on `value` prop

Don't reimplement any of this. The `value` prop on `Command.Item` is the search target—set it to a concatenation of label + keywords for better matching:

```tsx
<Command.Item value={`${cmd.label} ${cmd.keywords?.join(' ')}`}>
```

## Animation

Wrap `Command.Dialog` in `AnimatePresence` for a smooth open:

```tsx
<AnimatePresence>
  {open && (
    <motion.div
      initial={{ opacity: 0, scale: 0.97 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.97 }}
      transition={{ duration: 0.1 }}
    >
      <Command.Dialog ...>
```

Keep transitions under 150ms—command menus must feel instant.

## Key Rules

- **Guard the shortcut** against firing in editable elements (inputs, textareas, contenteditable).
- **`cmdk` handles all keyboard navigation**—don't add custom arrow-key handlers inside the menu.
- **`value` prop = search target**: include keywords, not just display labels.
- **Hide Recent group** when query is non-empty—recency is irrelevant during search.
- **Record to localStorage** on every command execution to keep recency accurate.
- **Close on action**: call `onClose()` in every `onSelect` handler.
- **Transition ≤150ms**—feels instant, not animated.

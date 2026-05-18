# Pattern: Keyboard Shortcut Registry

## Overview
Ad-hoc keyboard listeners scattered across components conflict, fire inside text inputs, and can't be discovered by users. A central registry prevents double-registration, handles input field suppression uniformly, and enables a discoverable shortcuts modal — the difference between shortcuts that power users love and shortcuts that break typing.

## Implementation

### Central Registry
```typescript
type ShortcutHandler = (event: KeyboardEvent) => void;

interface Shortcut {
  key: string;        // 'k', 'Enter', 'ArrowDown'
  meta?: boolean;     // Cmd on Mac, Ctrl on Win
  shift?: boolean;
  alt?: boolean;
  handler: ShortcutHandler;
  description: string;
  group: string;      // 'Navigation', 'Actions', 'Editor'
  disableInInputs?: boolean; // default true
}

class ShortcutRegistry {
  private shortcuts: Map<string, Shortcut> = new Map();

  register(id: string, shortcut: Shortcut) {
    if (this.shortcuts.has(id)) {
      console.warn(`Shortcut "${id}" already registered — overwriting`);
    }
    this.shortcuts.set(id, shortcut);
  }

  unregister(id: string) {
    this.shortcuts.delete(id);
  }

  getAll(): Shortcut[] {
    return Array.from(this.shortcuts.values());
  }

  getKey(shortcut: Shortcut): string {
    return [
      shortcut.meta ? '⌘' : '',
      shortcut.shift ? '⇧' : '',
      shortcut.alt ? '⌥' : '',
      shortcut.key.toUpperCase(),
    ].filter(Boolean).join('');
  }
}

export const registry = new ShortcutRegistry();
```

### Global Listener
```typescript
function isInputElement(target: EventTarget | null): boolean {
  if (!target) return false;
  const el = target as HTMLElement;
  return (
    el.tagName === 'INPUT' ||
    el.tagName === 'TEXTAREA' ||
    el.tagName === 'SELECT' ||
    el.isContentEditable
  );
}

function handleKeyDown(event: KeyboardEvent) {
  for (const shortcut of registry.getAll()) {
    const disableInInputs = shortcut.disableInInputs !== false; // default true
    if (disableInInputs && isInputElement(event.target)) continue;

    const matches =
      event.key === shortcut.key &&
      !!event.metaKey === !!shortcut.meta &&
      !!event.shiftKey === !!shortcut.shift &&
      !!event.altKey === !!shortcut.alt;

    if (matches) {
      event.preventDefault();
      shortcut.handler(event);
      return; // first match wins
    }
  }
}

document.addEventListener('keydown', handleKeyDown);
```

### React Hook
```typescript
function useKeyboardShortcut(
  id: string,
  shortcut: Omit<Shortcut, 'handler'>,
  handler: ShortcutHandler,
  deps: DependencyList = []
) {
  useEffect(() => {
    registry.register(id, { ...shortcut, handler });
    return () => registry.unregister(id);
  }, deps); // eslint-disable-line react-hooks/exhaustive-deps
}

// Usage
function InvoiceActions() {
  const { openCreateModal } = useInvoiceStore();

  useKeyboardShortcut(
    'invoice:create',
    { key: 'n', meta: true, description: 'New invoice', group: 'Invoices' },
    () => openCreateModal(),
    [openCreateModal]
  );
}
```

### Shortcuts Modal (opened with `?`)
```tsx
function ShortcutsModal() {
  const shortcuts = registry.getAll();
  const grouped = groupBy(shortcuts, s => s.group);

  return (
    <Modal>
      <h2>Keyboard shortcuts</h2>
      {Object.entries(grouped).map(([group, items]) => (
        <section key={group}>
          <h3>{group}</h3>
          {items.map(shortcut => (
            <div key={shortcut.description} className="shortcut-row">
              <span>{shortcut.description}</span>
              <kbd>{registry.getKey(shortcut)}</kbd>
            </div>
          ))}
        </section>
      ))}
    </Modal>
  );
}

// Register the modal trigger
registry.register('shortcuts:modal', {
  key: '?',
  handler: openShortcutsModal,
  description: 'Show keyboard shortcuts',
  group: 'Help',
  disableInInputs: true,
});
```

### Tooltip with Shortcut Hint
```tsx
function ActionButton({ label, shortcut, onClick, children }) {
  return (
    <Tooltip
      content={<>{label} <kbd>{shortcut}</kbd></>}
      delayDuration={1500}  // 1.5s delay — don't show on quick hover
    >
      <button onClick={onClick}>{children}</button>
    </Tooltip>
  );
}
```

## Key Rules
- Central registry — never call `addEventListener('keydown', ...)` directly in components
- Suppress all shortcuts when focus is inside an input, textarea, or contenteditable
- `?` opens a shortcuts modal — this is the universal convention users expect
- Show shortcuts in tooltips with a 1.5-second delay — visible for deliberate hover, not accidental
- Mac uses `⌘`; Windows/Linux uses `Ctrl` — detect platform and render accordingly
- Register/unregister in `useEffect` with a stable ID — prevents duplicates on re-render
- Group shortcuts by category in the modal — flat alphabetical lists are hard to scan
- First registered match wins — document precedence and warn on duplicate registration
- Never intercept browser reserved shortcuts (`⌘W`, `⌘T`, `⌘N`, F5, etc.)
- Test shortcut handlers don't fire during form submission (`Enter` in inputs)

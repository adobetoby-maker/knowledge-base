# Pattern: Arrow-Key Navigable List (Combobox, Menu, Listbox)

## Problem

Dropdown lists, comboboxes, and menus must be fully keyboard navigable: arrow keys move focus, Enter selects, Escape closes, and type-ahead jumps to the matching option. The two main patterns — `aria-activedescendant` vs roving tabindex — serve different use cases. Getting ARIA roles wrong causes screen readers to announce the wrong thing.

## ARIA Role Choices

| Widget | Container role | Item role | Focus model |
|---|---|---|---|
| Combobox dropdown | `listbox` | `option` | aria-activedescendant |
| Menu (actions) | `menu` | `menuitem` | roving tabindex |
| Select replacement | `listbox` | `option` | aria-activedescendant |
| Tab list | `tablist` | `tab` | roving tabindex |

WHY two patterns: `aria-activedescendant` keeps focus on the input/control and announces the "active" item virtually — ideal when you don't want focus to physically move (combobox). Roving tabindex actually moves `tabIndex=0` between items — ideal for menus where physical focus movement is expected.

## aria-activedescendant (Combobox/Listbox)

Focus stays on the input. The active item is communicated via `aria-activedescendant`:

```tsx
function Listbox({ options, value, onChange }: Props) {
  const [activeIdx, setActiveIdx] = useState(-1);
  const inputRef = useRef<HTMLDivElement>(null);

  function handleKeyDown(e: React.KeyboardEvent) {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setActiveIdx(i => Math.min(i + 1, options.length - 1));
        break;
      case 'ArrowUp':
        e.preventDefault();
        setActiveIdx(i => Math.max(i - 1, 0));
        break;
      case 'Home':
        e.preventDefault();
        setActiveIdx(0);
        break;
      case 'End':
        e.preventDefault();
        setActiveIdx(options.length - 1);
        break;
      case 'Enter':
        if (activeIdx >= 0) onChange(options[activeIdx]);
        break;
      case 'Escape':
        setActiveIdx(-1);
        break;
    }
  }

  return (
    <div
      ref={inputRef}
      tabIndex={0}
      role="listbox"
      aria-label="Options"
      aria-activedescendant={activeIdx >= 0 ? `option-${activeIdx}` : undefined}
      onKeyDown={handleKeyDown}
      className="rounded border focus:outline-none focus-visible:ring-2"
    >
      {options.map((opt, i) => (
        <div
          key={opt.value}
          id={`option-${i}`}
          role="option"
          aria-selected={value === opt.value}
          onClick={() => onChange(opt)}
          className={`cursor-pointer px-3 py-2 ${
            i === activeIdx ? 'bg-indigo-100' : ''
          } ${value === opt.value ? 'font-semibold' : ''}`}
        >
          {opt.label}
        </div>
      ))}
    </div>
  );
}
```

## Roving Tabindex (Menu)

One item has `tabIndex={0}` at a time; all others have `tabIndex={-1}`. Keyboard focus physically moves between items:

```tsx
function Menu({ items, onSelect }: Props) {
  const [focusedIdx, setFocusedIdx] = useState(0);
  const itemRefs = useRef<(HTMLButtonElement | null)[]>([]);

  function moveFocus(idx: number) {
    const bounded = Math.max(0, Math.min(idx, items.length - 1));
    setFocusedIdx(bounded);
    itemRefs.current[bounded]?.focus();
  }

  function handleKeyDown(e: React.KeyboardEvent, idx: number) {
    switch (e.key) {
      case 'ArrowDown': e.preventDefault(); moveFocus(idx + 1); break;
      case 'ArrowUp':   e.preventDefault(); moveFocus(idx - 1); break;
      case 'Home':      e.preventDefault(); moveFocus(0); break;
      case 'End':       e.preventDefault(); moveFocus(items.length - 1); break;
    }
  }

  return (
    <ul role="menu">
      {items.map((item, i) => (
        <li key={item.id} role="none">
          <button
            ref={el => { itemRefs.current[i] = el; }}
            role="menuitem"
            tabIndex={i === focusedIdx ? 0 : -1}
            onKeyDown={e => handleKeyDown(e, i)}
            onClick={() => onSelect(item)}
          >
            {item.label}
          </button>
        </li>
      ))}
    </ul>
  );
}
```

WHY `role="none"` on `<li>`: `<ul role="menu">` expects only `menuitem` children; `<li>` is an implicit `listitem` role which is invalid inside `menu`. Suppress it with `role="none"`.

## Type-Ahead Character Search

On character key press, jump to the first option starting with that character:

```ts
function handleTypeAhead(char: string, options: Option[], currentIdx: number): number {
  const lower = char.toLowerCase();
  // Search from current position + 1, wrapping around
  const start = currentIdx + 1;
  for (let i = 0; i < options.length; i++) {
    const idx = (start + i) % options.length;
    if (options[idx].label.toLowerCase().startsWith(lower)) {
      return idx;
    }
  }
  return currentIdx; // no match, stay put
}
```

## Scroll Active Item into View

When arrow-navigating through a long list, scroll the active item into view:

```ts
useEffect(() => {
  document.getElementById(`option-${activeIdx}`)?.scrollIntoView({ block: 'nearest' });
}, [activeIdx]);
```

## Key Rules

- `aria-activedescendant` for combobox/listbox (focus stays on container); roving tabindex for menus (focus moves physically)
- `role="listbox"` + `role="option"` for selection lists; `role="menu"` + `role="menuitem"` for action lists
- `role="none"` on `<li>` inside `role="menu"` to suppress invalid listitem role
- Implement Home/End in addition to ArrowUp/Down — many keyboard users rely on them
- Type-ahead search wraps around from current position, not always from the top
- `scrollIntoView({ block: 'nearest' })` on active item to prevent the list from scrolling the active item out of view

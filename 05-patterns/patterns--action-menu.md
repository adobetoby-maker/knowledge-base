# Pattern: Three-Dot Kebab Action Menu

## Overview

The kebab menu (⋮) is a compact way to expose row-level or item-level actions without cluttering the UI. It needs to be keyboard-navigable, have destructive actions visually distinct, handle disabled states with explanatory tooltips, and be positioned correctly so it doesn't clip against viewport edges. Radix `DropdownMenu` handles focus management and ARIA wiring — don't build this from scratch.

## Implementation

```tsx
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@radix-ui/react-dropdown-menu'
import { Tooltip, TooltipContent, TooltipTrigger } from '@radix-ui/react-tooltip'

type Action = {
  label: string
  icon?: React.ReactNode
  onSelect: () => void
  disabled?: boolean
  disabledReason?: string
  destructive?: boolean
}

type ActionMenuProps = {
  actions: Action[]
  label?: string  // accessible name for trigger button
}

export function ActionMenu({ actions, label = 'Actions' }: ActionMenuProps) {
  const normalActions = actions.filter(a => !a.destructive)
  const destructiveActions = actions.filter(a => a.destructive)

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          aria-label={label}
          className="action-menu-trigger"
        >
          <DotsVerticalIcon aria-hidden="true" />
        </button>
      </DropdownMenuTrigger>

      <DropdownMenuContent
        align="end"       // right-align under the trigger
        sideOffset={4}    // 4px gap between trigger and menu
        collisionPadding={8}  // viewport edge padding
      >
        {normalActions.map(action => (
          <ActionMenuItem key={action.label} action={action} />
        ))}

        {destructiveActions.length > 0 && normalActions.length > 0 && (
          <DropdownMenuSeparator />
        )}

        {destructiveActions.map(action => (
          <ActionMenuItem key={action.label} action={action} />
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

function ActionMenuItem({ action }: { action: Action }) {
  const item = (
    <DropdownMenuItem
      onSelect={action.disabled ? undefined : action.onSelect}
      disabled={action.disabled}
      className={action.destructive ? 'menu-item--destructive' : undefined}
    >
      {action.icon && <span aria-hidden="true" className="menu-item-icon">{action.icon}</span>}
      {action.label}
    </DropdownMenuItem>
  )

  // Wrap disabled items in a tooltip explaining why
  if (action.disabled && action.disabledReason) {
    return (
      <Tooltip>
        <TooltipTrigger asChild>
          {/* Tooltip needs a non-disabled element to attach to */}
          <span>{item}</span>
        </TooltipTrigger>
        <TooltipContent>{action.disabledReason}</TooltipContent>
      </Tooltip>
    )
  }

  return item
}
```

## Keyboard Navigation

Radix `DropdownMenu` handles this automatically:
- `Space` / `Enter` on trigger opens menu
- `↑` / `↓` navigate items
- `Enter` / `Space` selects focused item
- `Escape` closes and returns focus to trigger
- `Tab` closes (does not navigate items — menus are not tab stops)

**Why not build this manually:** Focus management, ARIA attributes (`role="menu"`, `aria-haspopup`, `aria-expanded`), and `roving tabindex` within the menu are complex to implement correctly. Radix has ~3 years of accessibility testing behind it.

## Destructive Action Styling

```css
.menu-item--destructive {
  color: hsl(0 72% 51%);  /* red */
}

.menu-item--destructive:focus {
  background: hsl(0 72% 51% / 0.1);
  color: hsl(0 72% 51%);
}
```

Place destructive actions at the bottom, separated by a divider. This prevents accidental clicks when the user is scanning the top of the list. Never put delete as the first item.

## Disabled Items and Tooltips

`<DropdownMenuItem disabled>` sets `aria-disabled="true"` and blocks `onSelect`. But disabled elements can't receive `:hover` events, so tooltips won't fire. Wrap the disabled item in a `<span>` before attaching the tooltip — the span is hoverable even when the child is disabled.

## Positioning and Viewport Collision

`collisionPadding={8}` tells Radix to flip/shift the menu when it would overflow the viewport. Without this, menus in the last row of a table clip against the bottom edge. `align="end"` right-aligns the menu under the trigger, which is standard for row actions.

## Usage

```tsx
<ActionMenu
  label={`Actions for ${item.name}`}
  actions={[
    { label: 'Edit', icon: <EditIcon />, onSelect: () => onEdit(item) },
    { label: 'Duplicate', icon: <CopyIcon />, onSelect: () => onDuplicate(item) },
    {
      label: 'Export',
      icon: <DownloadIcon />,
      onSelect: () => onExport(item),
      disabled: !item.canExport,
      disabledReason: 'Export requires Pro plan',
    },
    {
      label: 'Delete',
      icon: <TrashIcon />,
      onSelect: () => onDelete(item),
      destructive: true,
    },
  ]}
/>
```

## Key Rules

- Use Radix `DropdownMenu` — not a `<select>` or custom implementation — ARIA and focus management are built in
- Place destructive actions last with a separator — prevents accidents when scanning from the top
- Wrap disabled items in a `<span>` for tooltip attachment — disabled elements don't receive hover events
- Always provide `aria-label` on the trigger that names the context ("Actions for Invoice #123"), not just "Actions"
- Use `collisionPadding` — menus in table rows need viewport-aware positioning
- `disabledReason` is required when an action is disabled — users deserve to know why they can't do something

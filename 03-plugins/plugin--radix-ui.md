# Plugin: Radix UI

## What It Is

Radix UI is an unstyled, accessible component library. Provides headless primitives (Dialog, Dropdown, Tooltip, etc.) with built-in accessibility (ARIA, keyboard, focus management). shadcn/ui is built on Radix primitives. Use Radix directly when you need custom styling that shadcn doesn't support, or when not using shadcn.

## Installation

Install only the primitives you need:

```bash
npm install @radix-ui/react-dialog
npm install @radix-ui/react-dropdown-menu
npm install @radix-ui/react-tooltip
npm install @radix-ui/react-popover
npm install @radix-ui/react-select
npm install @radix-ui/react-checkbox
npm install @radix-ui/react-radio-group
npm install @radix-ui/react-switch
npm install @radix-ui/react-tabs
npm install @radix-ui/react-accordion
npm install @radix-ui/react-avatar
npm install @radix-ui/react-toast
npm install @radix-ui/react-progress
npm install @radix-ui/react-slider
```

## Dialog (Modal)

```tsx
import * as Dialog from '@radix-ui/react-dialog'

function DeleteConfirmDialog({ onConfirm }: { onConfirm: () => void }) {
  return (
    <Dialog.Root>
      <Dialog.Trigger asChild>
        <button className="text-red-600">Delete</button>
      </Dialog.Trigger>

      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 bg-black/50 animate-fade-in" />
        <Dialog.Content className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-lg p-6 shadow-xl w-full max-w-md">
          <Dialog.Title className="text-lg font-semibold">Delete item?</Dialog.Title>
          <Dialog.Description className="text-gray-600 mt-2">
            This action cannot be undone.
          </Dialog.Description>

          <div className="flex gap-3 justify-end mt-6">
            <Dialog.Close asChild>
              <button className="btn-secondary">Cancel</button>
            </Dialog.Close>
            <button onClick={onConfirm} className="btn-destructive">Delete</button>
          </div>

          <Dialog.Close asChild>
            <button className="absolute top-4 right-4" aria-label="Close">×</button>
          </Dialog.Close>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}
```

`Dialog.Portal` renders outside the current DOM tree (appended to `document.body`) — prevents z-index stacking context issues.

## Dropdown Menu

```tsx
import * as DropdownMenu from '@radix-ui/react-dropdown-menu'

function RowActions({ onEdit, onDelete }: Actions) {
  return (
    <DropdownMenu.Root>
      <DropdownMenu.Trigger asChild>
        <button aria-label="Row actions">⋯</button>
      </DropdownMenu.Trigger>

      <DropdownMenu.Portal>
        <DropdownMenu.Content
          className="bg-white border rounded-lg shadow-lg p-1 min-w-[160px]"
          align="end"
        >
          <DropdownMenu.Item
            className="px-3 py-2 rounded cursor-pointer hover:bg-gray-100 outline-none"
            onSelect={onEdit}
          >
            Edit
          </DropdownMenu.Item>
          <DropdownMenu.Separator className="h-px bg-gray-200 my-1" />
          <DropdownMenu.Item
            className="px-3 py-2 rounded cursor-pointer hover:bg-red-50 text-red-600 outline-none"
            onSelect={onDelete}
          >
            Delete
          </DropdownMenu.Item>
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  )
}
```

`onSelect` fires when item is selected (keyboard or click). Automatically closes the menu.

## Tooltip

```tsx
import * as Tooltip from '@radix-ui/react-tooltip'

// Wrap app in provider once
function App() {
  return (
    <Tooltip.Provider delayDuration={300}>
      <RestOfApp />
    </Tooltip.Provider>
  )
}

// Use anywhere
function CopyButton({ text }: { text: string }) {
  return (
    <Tooltip.Root>
      <Tooltip.Trigger asChild>
        <button onClick={() => navigator.clipboard.writeText(text)}>
          Copy
        </button>
      </Tooltip.Trigger>
      <Tooltip.Portal>
        <Tooltip.Content
          className="bg-gray-900 text-white text-sm px-2 py-1 rounded"
          sideOffset={4}
        >
          Copy to clipboard
          <Tooltip.Arrow className="fill-gray-900" />
        </Tooltip.Content>
      </Tooltip.Portal>
    </Tooltip.Root>
  )
}
```

## Switch

```tsx
import * as Switch from '@radix-ui/react-switch'

function NotificationToggle({ checked, onCheckedChange }: SwitchProps) {
  return (
    <label className="flex items-center gap-2">
      <Switch.Root
        checked={checked}
        onCheckedChange={onCheckedChange}
        className="w-10 h-6 bg-gray-300 rounded-full data-[state=checked]:bg-blue-600"
      >
        <Switch.Thumb className="block w-4 h-4 bg-white rounded-full shadow transition-transform data-[state=checked]:translate-x-5 translate-x-1" />
      </Switch.Root>
      <span>Email notifications</span>
    </label>
  )
}
```

`data-[state=checked]` uses Radix's data attributes — style active state without JavaScript state in CSS.

## `asChild` Pattern

```tsx
// WITHOUT asChild — wraps in button, creates nested button
<Dialog.Trigger>
  <button>Open</button>  // div > button > button (invalid HTML)
</Dialog.Trigger>

// WITH asChild — merges props onto existing element
<Dialog.Trigger asChild>
  <button>Open</button>  // div > button (correct)
</Dialog.Trigger>
```

`asChild` merges Radix behavior (onClick, aria, ref) onto the child element instead of wrapping it. Use whenever the trigger needs to be a specific element type.

## Accessibility Built-In

Radix handles automatically:
- `role` attributes
- `aria-expanded`, `aria-controls`, `aria-haspopup`
- Keyboard navigation (arrows, Enter, Escape)
- Focus trapping (Dialog)
- Focus restoration after close
- `inert` on background content when modal is open

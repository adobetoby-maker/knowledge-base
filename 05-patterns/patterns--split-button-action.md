# Pattern: Split Button Action

## Overview
A split button presents a primary action prominently while making alternatives available without cluttering the UI with multiple buttons. The two zones (action and chevron) have distinct affordances — the primary action is wide and named; the chevron is narrow and triggers a menu. Conflating them into a single dropdown makes the primary action slower to trigger and the affordance ambiguous. Keyboard users expect Enter on the primary zone and arrow-down on the chevron zone to open the menu.

## Implementation

### Component
```tsx
import { useState, useRef, useEffect } from 'react'

interface SplitButtonOption {
  label: string
  action: () => void
  disabled?: boolean
}

interface SplitButtonProps {
  primary: SplitButtonOption
  alternatives: SplitButtonOption[]
  loading?: boolean
  disabled?: boolean
}

function SplitButton({ primary, alternatives, loading, disabled }: SplitButtonProps) {
  const [open, setOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const chevronRef = useRef<HTMLButtonElement>(null)

  // Close menu on outside click
  useEffect(() => {
    if (!open) return
    const handler = (e: MouseEvent) => {
      if (!menuRef.current?.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [open])

  // Keyboard: Escape closes menu
  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setOpen(false)
        chevronRef.current?.focus()
      }
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [open])

  const isDisabled = disabled || loading

  return (
    <div className="relative inline-flex" ref={menuRef}>
      {/* Primary action button */}
      <button
        type="button"
        onClick={primary.action}
        disabled={isDisabled}
        aria-busy={loading}
        className={[
          'inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600',
          'rounded-l-md border border-blue-600 hover:bg-blue-700 focus:outline-none',
          'focus:ring-2 focus:ring-blue-500 focus:ring-offset-1',
          'disabled:opacity-50 disabled:cursor-not-allowed',
        ].join(' ')}
      >
        {loading ? (
          <>
            <span className="sr-only">Loading...</span>
            <Spinner className="w-4 h-4 mr-2" aria-hidden="true" />
          </>
        ) : null}
        {primary.label}
      </button>

      {/* Chevron / menu trigger */}
      <button
        ref={chevronRef}
        type="button"
        disabled={isDisabled}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label="More actions"
        onClick={() => setOpen(!open)}
        onKeyDown={(e) => {
          if (e.key === 'ArrowDown') {
            e.preventDefault()
            setOpen(true)
          }
        }}
        className={[
          'inline-flex items-center px-2 py-2 text-sm text-white bg-blue-600',
          'rounded-r-md border border-l border-blue-500 hover:bg-blue-700',
          'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-1',
          'disabled:opacity-50 disabled:cursor-not-allowed',
        ].join(' ')}
      >
        <svg
          aria-hidden="true"
          className={`w-4 h-4 transition-transform duration-150 ${open ? 'rotate-180' : ''}`}
          fill="currentColor"
          viewBox="0 0 20 20"
        >
          <path fillRule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clipRule="evenodd" />
        </svg>
      </button>

      {/* Dropdown menu */}
      {open && (
        <div
          role="menu"
          aria-orientation="vertical"
          className="absolute right-0 top-full mt-1 w-48 bg-white rounded-md shadow-lg border border-gray-200 z-50"
        >
          {alternatives.map((option, i) => (
            <button
              key={i}
              role="menuitem"
              type="button"
              disabled={option.disabled}
              onClick={() => {
                option.action()
                setOpen(false)
              }}
              className={[
                'w-full text-left px-4 py-2 text-sm hover:bg-gray-50',
                option.disabled ? 'text-gray-300 cursor-not-allowed' : 'text-gray-700',
              ].join(' ')}
            >
              {option.label}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
```

### Usage
```tsx
<SplitButton
  primary={{ label: 'Save', action: handleSave }}
  alternatives={[
    { label: 'Save & Publish', action: handleSaveAndPublish },
    { label: 'Save as Draft', action: handleSaveAsDraft },
    { label: 'Save & New', action: handleSaveAndNew },
  ]}
  loading={saving}
/>
```

## Key Rules
- The two segments must be visually separated with a divider line — same color background but a 1px lighter border between them makes each zone's affordance clear
- `aria-haspopup="menu"` belongs on the chevron button, NOT on the primary action — the primary action is not a menu trigger
- `aria-expanded` on the chevron reflects menu open state
- Primary button disabled during `loading` state — show spinner inline, not as a separate overlay
- Keyboard: pressing Enter on the primary button fires the action; pressing arrow-down on the chevron opens the menu (matches select/combobox convention)
- Menu items are `role="menuitem"` inside `role="menu"` — not a listbox
- Close the menu on: outside click, Escape, selecting any menu item
- Do not put a destructive action as the primary button — split buttons typically wrap "save" variants, not "delete"

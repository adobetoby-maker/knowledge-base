# Pattern: Virtualized Combobox for Large Lists

## Overview
Rendering 5,000 options in a dropdown freezes the browser's main thread on open. Virtualization renders only the visible items (plus overscan buffer), keeping the DOM lean. Filtering must happen before virtualization — you virtualize the filtered subset, not the full list. Scroll-to-selected on open is required otherwise the user lands at the top of the list when the selected item is in the middle.

## Implementation

```tsx
// VirtualizedCombobox.tsx
// Uses TanStack Virtual + cmdk (Command) for the accessible combobox behavior
import { useVirtualizer } from '@tanstack/react-virtual'
import { Command } from 'cmdk'
import { useEffect, useMemo, useRef, useState } from 'react'

interface Option {
  value: string
  label: string
  group?: string
}

interface VirtualizedComboboxProps {
  options: Option[]
  value?: string
  onChange: (value: string) => void
  placeholder?: string
  label: string
  itemHeight?: number   // px — for uniform height virtualization
}

export function VirtualizedCombobox({
  options,
  value,
  onChange,
  placeholder = 'Search…',
  label,
  itemHeight = 36,
}: VirtualizedComboboxProps) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const listRef = useRef<HTMLDivElement>(null)

  // Filter BEFORE passing to virtualizer
  // Virtualizer handles layout, not filtering
  const filtered = useMemo(() => {
    if (!query) return options
    const q = query.toLowerCase()
    return options.filter(o =>
      o.label.toLowerCase().includes(q) ||
      o.value.toLowerCase().includes(q)
    )
  }, [options, query])

  const virtualizer = useVirtualizer({
    count: filtered.length,
    getScrollElement: () => listRef.current,
    estimateSize: () => itemHeight,
    overscan: 5,  // render 5 items beyond viewport edge in each direction
    // Use this when items have variable heights
    // measureElement: el => el.getBoundingClientRect().height,
  })

  // Scroll to selected item when dropdown opens
  useEffect(() => {
    if (!open || !value) return
    const selectedIndex = filtered.findIndex(o => o.value === value)
    if (selectedIndex >= 0) {
      // Small delay to allow the list to mount first
      requestAnimationFrame(() => {
        virtualizer.scrollToIndex(selectedIndex, { align: 'center' })
      })
    }
  }, [open, value, filtered, virtualizer])

  const selectedOption = options.find(o => o.value === value)

  return (
    <div>
      <label id={`${label}-label`}>{label}</label>

      {/* Trigger button */}
      <button
        onClick={() => setOpen(true)}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-labelledby={`${label}-label`}
      >
        {selectedOption?.label ?? placeholder}
        <span aria-hidden>▼</span>
      </button>

      {/* Popover — only mounted when open to save memory */}
      {open && (
        <div
          style={{
            position: 'absolute',
            zIndex: 50,
            background: 'white',
            border: '1px solid #ddd',
            borderRadius: 6,
            boxShadow: '0 8px 24px rgba(0,0,0,0.15)',
            width: 320,
          }}
          onKeyDown={e => e.key === 'Escape' && setOpen(false)}
        >
          {/* cmdk provides accessible command input + navigation */}
          <Command shouldFilter={false}>  {/* We handle filtering ourselves */}
            <Command.Input
              value={query}
              onValueChange={setQuery}
              placeholder="Type to filter…"
              autoFocus
            />

            <Command.Empty>No results for "{query}"</Command.Empty>

            {/* Fixed-height scroll container for virtualizer */}
            <div
              ref={listRef}
              style={{
                height: Math.min(filtered.length * itemHeight, 280), // cap at 280px
                overflow: 'auto',
              }}
              role="listbox"
              aria-label={label}
            >
              {/* Virtualizer spacer — sets total scroll height */}
              <div style={{ height: virtualizer.getTotalSize(), position: 'relative' }}>
                {virtualizer.getVirtualItems().map(virtualItem => {
                  const option = filtered[virtualItem.index]
                  const isSelected = option.value === value

                  return (
                    <div
                      key={option.value}
                      role="option"
                      aria-selected={isSelected}
                      data-index={virtualItem.index}
                      // Absolute positioning — virtualizer provides top/height
                      style={{
                        position: 'absolute',
                        top: virtualItem.start,
                        left: 0,
                        right: 0,
                        height: virtualItem.size,
                        display: 'flex',
                        alignItems: 'center',
                        padding: '0 12px',
                        cursor: 'pointer',
                        background: isSelected ? '#f0f9ff' : undefined,
                        fontWeight: isSelected ? 600 : 400,
                      }}
                      onClick={() => {
                        onChange(option.value)
                        setQuery('')
                        setOpen(false)
                      }}
                    >
                      {isSelected && <span aria-hidden style={{ marginRight: 8 }}>✓</span>}
                      {option.label}
                    </div>
                  )
                })}
              </div>
            </div>
          </Command>
        </div>
      )}

      {/* Backdrop */}
      {open && (
        <div
          style={{ position: 'fixed', inset: 0, zIndex: 49 }}
          onClick={() => { setOpen(false); setQuery('') }}
          aria-hidden
        />
      )}
    </div>
  )
}
```

```tsx
// Variable height items — use measureElement instead of estimateSize
const virtualizer = useVirtualizer({
  count: filtered.length,
  getScrollElement: () => listRef.current,
  estimateSize: () => 40,  // initial estimate
  overscan: 5,
  // measureElement reads the actual rendered height
  measureElement: el => el.getBoundingClientRect().height,
})

// Items need ref={virtualizer.measureElement} to be measured
{virtualizer.getVirtualItems().map(virtualItem => (
  <div
    key={filtered[virtualItem.index].value}
    ref={virtualizer.measureElement}
    data-index={virtualItem.index}
    style={{
      position: 'absolute',
      top: virtualItem.start,
      // height: NOT set here — virtualizer measures it
    }}
  >
    {/* variable-height content */}
  </div>
))}
```

## Key Rules
- Filter the list before passing to the virtualizer — `filtered.length` determines the virtual row count, not `options.length`.
- Set `overscan: 5` — render 5 extra items beyond the visible boundary to prevent flash-of-empty on fast scrolling.
- Cap the dropdown height in CSS (`max-height: 280px`) and let the virtualizer fill it — the scroll container height must be bounded.
- Scroll to the selected item on open (`virtualizer.scrollToIndex`) — without this, the list opens at the top even if the selection is at item 2000.
- Only mount the dropdown when `open === true` — this avoids virtualizing 5000 rows on page load.
- Use `shouldFilter={false}` with cmdk when handling filtering manually — don't double-filter.
- Virtualized items must use `position: absolute` with `top: virtualItem.start` — this is how the virtualizer positions them.
- The scroll container needs an explicit height, not just `max-height` — some virtualizers require a known container size to calculate layouts.
- Variable-height items require `measureElement` — uniform heights allow the simpler `estimateSize` approach.

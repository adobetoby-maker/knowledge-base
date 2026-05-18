# Pattern: Autocomplete Input

## Overview
An autocomplete built with `<div>` and `<ul>` fails keyboard-only and screen reader users — they can't navigate to, select, or understand the suggestions. The ARIA combobox pattern requires specific roles and attributes that explicitly communicate state to assistive technologies. Opening on click instead of on type forces users to clear and retype to see new suggestions.

## Implementation

```tsx
// Autocomplete.tsx — ARIA combobox pattern
import { useId, useRef, useState, useCallback } from 'react'

interface AutocompleteProps<T> {
  options: T[]
  getLabel: (option: T) => string
  getValue: (option: T) => string
  onSelect: (option: T) => void
  placeholder?: string
  label: string
  isLoading?: boolean
  onInputChange?: (value: string) => void  // for async search
}

export function Autocomplete<T>({
  options,
  getLabel,
  getValue,
  onSelect,
  placeholder,
  label,
  isLoading,
  onInputChange,
}: AutocompleteProps<T>) {
  const [inputValue, setInputValue] = useState('')
  const [isOpen, setIsOpen] = useState(false)
  const [activeIndex, setActiveIndex] = useState(-1)

  const inputId = useId()
  const listboxId = useId()
  const inputRef = useRef<HTMLInputElement>(null)

  // IDs for aria-activedescendant — tracks which option is keyboard-highlighted
  function getOptionId(index: number) {
    return `${listboxId}-option-${index}`
  }

  const handleInput = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value
    setInputValue(val)
    setActiveIndex(-1)

    // Open on any input — not on click
    // Empty input might still show recent searches or top options
    setIsOpen(true)
    onInputChange?.(val)
  }, [onInputChange])

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (!isOpen) {
      if (e.key === 'ArrowDown') setIsOpen(true)
      return
    }

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault()
        setActiveIndex(prev => Math.min(prev + 1, options.length - 1))
        break

      case 'ArrowUp':
        e.preventDefault()
        setActiveIndex(prev => Math.max(prev - 1, -1))
        break

      case 'Enter':
        e.preventDefault()
        if (activeIndex >= 0 && options[activeIndex]) {
          selectOption(options[activeIndex])
        }
        break

      case 'Escape':
        // Escape clears input and closes — not just closes
        setInputValue('')
        setIsOpen(false)
        setActiveIndex(-1)
        break

      case 'Tab':
        // Tab closes without selecting — user is moving focus away
        setIsOpen(false)
        break
    }
  }, [isOpen, options, activeIndex])

  function selectOption(option: T) {
    setInputValue(getLabel(option))
    setIsOpen(false)
    setActiveIndex(-1)
    onSelect(option)
    inputRef.current?.focus()
  }

  function handleBlur(e: React.FocusEvent) {
    // Only close if focus moved outside the entire widget
    if (!e.currentTarget.contains(e.relatedTarget)) {
      setIsOpen(false)
    }
  }

  const showList = isOpen && (options.length > 0 || isLoading)

  return (
    <div onBlur={handleBlur} style={{ position: 'relative' }}>
      <label htmlFor={inputId}>{label}</label>

      <input
        ref={inputRef}
        id={inputId}
        type="text"
        value={inputValue}
        onChange={handleInput}
        onKeyDown={handleKeyDown}
        placeholder={placeholder}
        autoComplete="off"

        // ARIA combobox pattern — required attributes
        role="combobox"
        aria-autocomplete="list"     // suggests from a list
        aria-haspopup="listbox"      // the popup is a listbox
        aria-expanded={showList}
        aria-controls={listboxId}
        // Points to the currently highlighted option by ID
        aria-activedescendant={activeIndex >= 0 ? getOptionId(activeIndex) : undefined}
      />

      {showList && (
        <ul
          id={listboxId}
          role="listbox"
          aria-label={label}
          style={{
            position: 'absolute',
            top: '100%',
            left: 0,
            right: 0,
            zIndex: 50,
            background: 'white',
            border: '1px solid #ddd',
            borderRadius: 4,
            maxHeight: 240,
            overflowY: 'auto',
            padding: 0,
            margin: 0,
            listStyle: 'none',
          }}
        >
          {isLoading && (
            <li style={{ padding: '8px 12px', color: '#999' }} aria-live="polite">
              Loading…
            </li>
          )}

          {!isLoading && options.map((option, index) => (
            <li
              key={getValue(option)}
              id={getOptionId(index)}
              role="option"
              aria-selected={index === activeIndex}
              onClick={() => selectOption(option)}
              onMouseEnter={() => setActiveIndex(index)}
              style={{
                padding: '8px 12px',
                cursor: 'pointer',
                // Highlight follows keyboard AND mouse
                background: index === activeIndex ? '#f0f0f0' : undefined,
              }}
            >
              {getLabel(option)}
            </li>
          ))}

          {!isLoading && options.length === 0 && inputValue && (
            <li style={{ padding: '8px 12px', color: '#999' }}>No results</li>
          )}
        </ul>
      )}
    </div>
  )
}
```

```tsx
// Usage — with async search (debounced)
import { useDebouncedCallback } from 'use-debounce'

function UserSearch() {
  const [options, setOptions] = useState<User[]>([])
  const [loading, setLoading] = useState(false)

  const search = useDebouncedCallback(async (query: string) => {
    if (!query) { setOptions([]); return }
    setLoading(true)
    const results = await fetchUsers(query)
    setOptions(results)
    setLoading(false)
  }, 200)  // debounce 200ms — prevents API call on every keystroke

  return (
    <Autocomplete
      options={options}
      getLabel={u => u.name}
      getValue={u => u.id}
      onSelect={user => console.log('selected', user)}
      label="Search users"
      isLoading={loading}
      onInputChange={search}
    />
  )
}
```

## Key Rules
- Use `role="combobox"` on the input, `role="listbox"` on the list, `role="option"` on each item.
- Set `aria-expanded` on the input to communicate open/closed state to screen readers.
- Track the highlighted option with `aria-activedescendant` pointing to the option's ID — this is how screen readers announce which option is focused.
- Open on typing, not on click — click-to-open forces users to clear and retype to filter.
- Keyboard: ArrowDown/Up navigates, Enter selects, Escape clears input and closes, Tab closes without selecting.
- Do not move actual DOM focus to the options — `aria-activedescendant` handles the announcement, focus stays in the input.
- Debounce async search calls (200ms) — never call the API on every keystroke.
- Close only when focus leaves the entire widget, not when focus shifts from input to the list.
- Never use `onBlur` on the input alone for closing — it fires when user clicks an option, closing before the click registers.

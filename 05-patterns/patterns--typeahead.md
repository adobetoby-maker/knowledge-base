# Pattern: Typeahead / Autocomplete

## Overview

Input that shows a dropdown of suggestions as the user types. Covers: debounced search, keyboard navigation, accessibility, and async suggestions.

## Core Hook

```ts
'use client'
import { useState, useRef, useEffect, useCallback } from 'react'

interface UseTypeaheadOptions<T> {
  fetchSuggestions: (query: string) => Promise<T[]>
  minChars?: number
  debounceMs?: number
}

export function useTypeahead<T>({
  fetchSuggestions,
  minChars = 2,
  debounceMs = 200,
}: UseTypeaheadOptions<T>) {
  const [query, setQuery] = useState('')
  const [suggestions, setSuggestions] = useState<T[]>([])
  const [loading, setLoading] = useState(false)
  const [open, setOpen] = useState(false)
  const [activeIndex, setActiveIndex] = useState(-1)
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const abortRef = useRef<AbortController | null>(null)

  useEffect(() => {
    if (query.length < minChars) {
      setSuggestions([])
      setOpen(false)
      return
    }

    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(async () => {
      abortRef.current?.abort()
      abortRef.current = new AbortController()

      setLoading(true)
      try {
        const results = await fetchSuggestions(query)
        setSuggestions(results)
        setOpen(results.length > 0)
        setActiveIndex(-1)
      } catch (err) {
        if ((err as Error).name !== 'AbortError') {
          setSuggestions([])
        }
      } finally {
        setLoading(false)
      }
    }, debounceMs)

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current)
    }
  }, [query, minChars, debounceMs, fetchSuggestions])

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (!open) return
      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault()
          setActiveIndex((i) => Math.min(i + 1, suggestions.length - 1))
          break
        case 'ArrowUp':
          e.preventDefault()
          setActiveIndex((i) => Math.max(i - 1, -1))
          break
        case 'Escape':
          setOpen(false)
          setActiveIndex(-1)
          break
        case 'Enter':
          if (activeIndex >= 0) {
            e.preventDefault()
            return suggestions[activeIndex]  // Return the selected item
          }
      }
    },
    [open, suggestions, activeIndex],
  )

  return {
    query, setQuery,
    suggestions, loading, open, activeIndex,
    handleKeyDown,
    close: () => setOpen(false),
  }
}
```

## Accessible Combobox Component

```tsx
import { useId } from 'react'
import { useTypeahead } from './useTypeahead'

interface TypeaheadProps<T> {
  fetchSuggestions: (q: string) => Promise<T[]>
  getLabel: (item: T) => string
  getValue: (item: T) => string
  onSelect: (item: T) => void
  placeholder?: string
}

export function Typeahead<T>({
  fetchSuggestions,
  getLabel,
  getValue,
  onSelect,
  placeholder = 'Search...',
}: TypeaheadProps<T>) {
  const listboxId = useId()
  const { query, setQuery, suggestions, loading, open, activeIndex, handleKeyDown, close } =
    useTypeahead({ fetchSuggestions })

  function handleSelect(item: T) {
    setQuery(getLabel(item))
    onSelect(item)
    close()
  }

  return (
    <div className="relative">
      <input
        type="text"
        role="combobox"
        aria-expanded={open}
        aria-controls={listboxId}
        aria-activedescendant={activeIndex >= 0 ? `option-${activeIndex}` : undefined}
        aria-autocomplete="list"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onKeyDown={handleKeyDown}
        onBlur={() => setTimeout(close, 150)}  // Delay to allow click
        placeholder={placeholder}
        className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
      />

      {loading && (
        <div className="absolute right-3 top-1/2 -translate-y-1/2">
          <div className="w-4 h-4 border-2 border-blue-600 border-t-transparent rounded-full animate-spin" />
        </div>
      )}

      {open && (
        <ul
          id={listboxId}
          role="listbox"
          className="absolute z-50 w-full mt-1 bg-white border rounded-lg shadow-lg max-h-60 overflow-auto"
        >
          {suggestions.map((item, index) => (
            <li
              key={getValue(item)}
              id={`option-${index}`}
              role="option"
              aria-selected={index === activeIndex}
              onMouseDown={() => handleSelect(item)}  // mousedown fires before blur
              className={`px-3 py-2 cursor-pointer text-sm
                ${index === activeIndex ? 'bg-blue-50 text-blue-900' : 'hover:bg-gray-50'}`}
            >
              {getLabel(item)}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
```

`onMouseDown` instead of `onClick` on list items is important. `onBlur` on the input fires before `onClick`, causing the dropdown to close before the click registers. `mousedown` fires before `blur`.

## Usage Example

```tsx
interface City {
  id: string
  name: string
  country: string
}

async function fetchCities(query: string): Promise<City[]> {
  const res = await fetch(`/api/cities?q=${encodeURIComponent(query)}`)
  return res.json()
}

<Typeahead<City>
  fetchSuggestions={fetchCities}
  getLabel={(city) => `${city.name}, ${city.country}`}
  getValue={(city) => city.id}
  onSelect={(city) => setSelectedCity(city)}
  placeholder="Search cities..."
/>
```

## Static Suggestions (No API)

For filtering a static list (e.g., a dropdown with 50 items):

```ts
function useStaticTypeahead<T>(items: T[], getSearchText: (item: T) => string) {
  const [query, setQuery] = useState('')

  const suggestions = useMemo(() => {
    if (!query) return []
    const lower = query.toLowerCase()
    return items.filter((item) => getSearchText(item).toLowerCase().includes(lower)).slice(0, 10)
  }, [items, query, getSearchText])

  return { query, setQuery, suggestions }
}
```

Don't use the debounced async version for static data — synchronous `useMemo` filtering is instant and simpler.

## Highlight Matching Text

```tsx
function HighlightMatch({ text, query }: { text: string; query: string }) {
  const index = text.toLowerCase().indexOf(query.toLowerCase())
  if (index === -1) return <span>{text}</span>

  return (
    <span>
      {text.slice(0, index)}
      <mark className="bg-yellow-100 font-medium">{text.slice(index, index + query.length)}</mark>
      {text.slice(index + query.length)}
    </span>
  )
}
```

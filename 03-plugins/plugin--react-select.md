# Plugin: react-select

## Overview

Feature-rich select/combobox with search, multi-select, async options, custom rendering, and groups. Use when the native `<select>` doesn't meet requirements. Avoid adding it just for styling — a styled native select is lighter. Add react-select when you need: search filtering, multi-select, async option loading, or custom option rendering.

## Installation

```bash
npm install react-select
```

## Basic Usage

```tsx
import Select from 'react-select'

interface Option {
  value: string
  label: string
}

const options: Option[] = [
  { value: 'js', label: 'JavaScript' },
  { value: 'ts', label: 'TypeScript' },
  { value: 'py', label: 'Python' },
]

function TechSelect({ value, onChange }: {
  value: string
  onChange: (v: string) => void
}) {
  const selected = options.find(o => o.value === value) ?? null

  return (
    <Select
      options={options}
      value={selected}
      onChange={option => option && onChange(option.value)}
      placeholder="Select language..."
      isClearable
    />
  )
}
```

## Multi-Select

```tsx
import Select, { MultiValue } from 'react-select'

function TagSelector({ values, onChange }: {
  values: string[]
  onChange: (v: string[]) => void
}) {
  const selected = options.filter(o => values.includes(o.value))

  return (
    <Select
      options={options}
      value={selected}
      onChange={(newValue: MultiValue<Option>) => onChange(newValue.map(o => o.value))}
      isMulti
      placeholder="Add tags..."
    />
  )
}
```

## Async Options (API Search)

```tsx
import AsyncSelect from 'react-select/async'

function UserSearch({ onSelect }: { onSelect: (userId: string) => void }) {
  async function loadOptions(inputValue: string): Promise<Option[]> {
    if (!inputValue || inputValue.length < 2) return []
    const users = await searchUsers(inputValue)
    return users.map(u => ({ value: u.id, label: u.name }))
  }

  return (
    <AsyncSelect
      loadOptions={loadOptions}
      onChange={option => option && onSelect(option.value)}
      placeholder="Search users..."
      noOptionsMessage={({ inputValue }) =>
        inputValue.length < 2 ? 'Type at least 2 characters' : 'No users found'
      }
      loadingMessage={() => 'Searching...'}
    />
  )
}
```

## Styling with Tailwind

react-select uses its own CSS-in-JS. Override with `classNames` prop for Tailwind:

```tsx
<Select
  classNames={{
    control: (state) =>
      `border rounded-md ${state.isFocused ? 'border-blue-500 ring-1 ring-blue-500' : 'border-gray-300'}`,
    menu: () => 'bg-white border border-gray-200 rounded-md shadow-lg mt-1',
    option: (state) =>
      `px-3 py-2 cursor-pointer text-sm ${state.isSelected ? 'bg-blue-600 text-white' : state.isFocused ? 'bg-gray-50' : ''}`,
    multiValue: () => 'bg-gray-100 rounded px-1 mr-1 my-0.5',
    multiValueLabel: () => 'text-sm',
    multiValueRemove: () => 'hover:bg-gray-200 rounded-r px-1 cursor-pointer',
    placeholder: () => 'text-gray-400 text-sm',
    input: () => 'text-sm',
  }}
  unstyled  // Remove react-select's built-in styles
/>
```

## Grouped Options

```tsx
const groupedOptions = [
  {
    label: 'Frontend',
    options: [
      { value: 'react', label: 'React' },
      { value: 'vue', label: 'Vue' },
    ],
  },
  {
    label: 'Backend',
    options: [
      { value: 'node', label: 'Node.js' },
      { value: 'python', label: 'Python' },
    ],
  },
]
```

## react-hook-form Integration

```tsx
import { Controller } from 'react-hook-form'

<Controller
  name="category"
  control={control}
  render={({ field }) => (
    <Select
      {...field}
      options={options}
      value={options.find(o => o.value === field.value) ?? null}
      onChange={option => field.onChange(option?.value)}
    />
  )}
/>
```

## Key Rules

- Always store the raw value (`string`/`number`), not the full `{value, label}` object — label is presentation logic.
- Set `menuPortalTarget={document.body}` when inside a modal or overflow-hidden container to prevent clipping.
- `isSearchable={false}` for short option lists (< 8 items) — the search input adds noise without value.
- `cacheOptions` with AsyncSelect to avoid re-fetching the same query.

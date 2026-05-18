# Pattern: Color Theme Picker

## Overview
A color theme picker must apply changes immediately (preview on hover, commit on click) because users cannot evaluate a theme from a tiny swatch — they need to see it in context. Persisting to both localStorage and the backend ensures the theme is available on first paint (from localStorage, avoiding flash) and cross-device (from the database). A "System default" option that defers to the OS preference respects users who want automatic light/dark switching.

## Implementation

### Theme Definition
```tsx
interface ColorTheme {
  id: string
  label: string
  // CSS custom property values applied to :root
  variables: Record<string, string>
  // Hex for swatch preview
  swatchColor: string
  isSystemDefault?: boolean
}

const THEMES: ColorTheme[] = [
  {
    id: 'system',
    label: 'System default',
    swatchColor: 'transparent',
    variables: {},
    isSystemDefault: true,
  },
  {
    id: 'blue',
    label: 'Ocean',
    swatchColor: '#2563eb',
    variables: {
      '--color-primary': '#2563eb',
      '--color-primary-hover': '#1d4ed8',
      '--color-primary-light': '#dbeafe',
    },
  },
  {
    id: 'green',
    label: 'Forest',
    swatchColor: '#16a34a',
    variables: {
      '--color-primary': '#16a34a',
      '--color-primary-hover': '#15803d',
      '--color-primary-light': '#dcfce7',
    },
  },
  // ...more themes
]
```

### Apply Theme to DOM
```tsx
function applyTheme(theme: ColorTheme) {
  const root = document.documentElement

  if (theme.isSystemDefault) {
    // Remove all custom properties — let the CSS media query take over
    THEMES.filter((t) => !t.isSystemDefault).forEach((t) => {
      Object.keys(t.variables).forEach((key) => root.style.removeProperty(key))
    })
    return
  }

  Object.entries(theme.variables).forEach(([key, value]) => {
    root.style.setProperty(key, value)
  })
}
```

### Persistence Hook
```tsx
const THEME_KEY = 'app-color-theme'

function useColorTheme() {
  const [activeId, setActiveId] = useState<string>(() => {
    // Read from localStorage on first render to avoid flash
    return localStorage.getItem(THEME_KEY) ?? 'system'
  })

  // Apply on mount and when activeId changes
  useEffect(() => {
    const theme = THEMES.find((t) => t.id === activeId) ?? THEMES[0]
    applyTheme(theme)
  }, [activeId])

  const selectTheme = async (id: string) => {
    setActiveId(id)
    localStorage.setItem(THEME_KEY, id)

    // Persist cross-device
    try {
      await updateUserPreference('colorTheme', id)
    } catch {
      // Fail silently — localStorage is the source of truth for this session
    }
  }

  const [hovered, setHovered] = useState<string | null>(null)

  // Preview on hover without committing
  useEffect(() => {
    const theme = THEMES.find((t) => t.id === (hovered ?? activeId))
    if (theme) applyTheme(theme)
  }, [hovered, activeId])

  return { activeId, hovered, selectTheme, setHovered }
}
```

### Picker UI
```tsx
function ColorThemePicker() {
  const { activeId, hovered, selectTheme, setHovered } = useColorTheme()

  return (
    <fieldset>
      <legend className="text-sm font-medium text-gray-700 mb-3">
        Color theme
      </legend>
      <div className="flex flex-wrap gap-3">
        {THEMES.map((theme) => {
          const isActive = theme.id === activeId

          return (
            <label
              key={theme.id}
              className="flex flex-col items-center gap-1 cursor-pointer group"
              onMouseEnter={() => setHovered(theme.id)}
              onMouseLeave={() => setHovered(null)}
            >
              <input
                type="radio"
                name="color-theme"
                value={theme.id}
                checked={isActive}
                onChange={() => selectTheme(theme.id)}
                className="sr-only"
              />
              <div
                aria-hidden="true"
                className={[
                  'w-8 h-8 rounded-full border-2 flex items-center justify-center transition-transform group-hover:scale-110',
                  isActive ? 'border-gray-900 scale-110' : 'border-transparent',
                  theme.isSystemDefault
                    ? 'bg-gradient-to-br from-gray-100 to-gray-300 border-gray-300'
                    : '',
                ].join(' ')}
                style={
                  !theme.isSystemDefault
                    ? { backgroundColor: theme.swatchColor }
                    : undefined
                }
              >
                {isActive && (
                  <svg
                    aria-hidden="true"
                    className="w-4 h-4 text-white"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                )}
              </div>
              <span className="text-xs text-gray-600">{theme.label}</span>
            </label>
          )
        })}
      </div>
    </fieldset>
  )
}
```

### Hex Input Option
```tsx
function CustomHexInput({ onApply }: { onApply: (hex: string) => void }) {
  const [value, setValue] = useState('')
  const isValid = /^#[0-9a-f]{6}$/i.test(value)

  return (
    <div className="flex gap-2 mt-3">
      <input
        type="text"
        placeholder="#2563eb"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        maxLength={7}
        className="border rounded px-2 py-1 text-sm font-mono w-28"
        aria-label="Custom hex color"
      />
      <button
        type="button"
        disabled={!isValid}
        onClick={() => isValid && onApply(value)}
        className="text-sm px-3 py-1 bg-blue-600 text-white rounded disabled:opacity-40"
      >
        Apply
      </button>
    </div>
  )
}
```

## Key Rules
- Apply theme to `document.documentElement` via CSS custom properties — this avoids re-rendering the entire component tree
- Preview on hover by temporarily applying the theme; restore on mouse-leave if the user doesn't click
- Persist to `localStorage` synchronously before the async DB call — the async call can fail without losing the selection
- Read from `localStorage` on initial render to prevent flash of default theme before user preference loads
- "System default" removes all custom properties instead of setting them — this allows CSS `prefers-color-scheme` to take over
- Use `<input type="radio">` visually hidden + a styled `<label>` — proper radio semantics work with keyboard and screen readers
- Active swatch should show a visible checkmark indicator, not only a border change — borders are hard to see on colored swatches
- Scale-up active swatch slightly (e.g., `transform: scale(1.1)`) for clear visual selection state

# Pattern: Settings Toggle Switch

## Overview

A toggle switch is not a checkbox. It represents a binary on/off state that takes immediate effect (no submit button), and its accessibility semantics are `role="switch"` with `aria-checked`, not `role="checkbox"`. The key interaction challenges: the API call may fail (requiring rollback), the call may be slow (requiring a loading state), and the label must be clickable without special CSS tricks.

## Base Toggle Component

```tsx
interface ToggleProps {
  checked: boolean
  onChange: (checked: boolean) => void
  label: string
  description?: string
  disabled?: boolean
  loading?: boolean
  id?: string
}

function Toggle({ checked, onChange, label, description, disabled, loading, id }: ToggleProps) {
  const toggleId = id ?? useId()

  return (
    <div className="flex items-center justify-between gap-4">
      <div>
        <label
          htmlFor={toggleId}
          className="font-medium cursor-pointer select-none"
        >
          {label}
        </label>
        {description && (
          <p id={`${toggleId}-desc`} className="text-sm text-gray-500">{description}</p>
        )}
      </div>

      <button
        id={toggleId}
        role="switch"
        aria-checked={checked}
        aria-label={label}
        aria-describedby={description ? `${toggleId}-desc` : undefined}
        aria-busy={loading}
        disabled={disabled || loading}
        onClick={() => onChange(!checked)}
        className={`
          relative inline-flex h-6 w-11 items-center rounded-full transition-colors
          focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2
          ${checked ? 'bg-blue-600' : 'bg-gray-200'}
          ${disabled || loading ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
        `}
      >
        <span
          className={`
            inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform
            ${checked ? 'translate-x-6' : 'translate-x-1'}
          `}
        />
        {loading && <span className="sr-only">Saving...</span>}
      </button>
    </div>
  )
}
```

## Settings Toggle with Optimistic Update + Error Recovery

The most important behavior: when the API call fails, revert the toggle back to its original state. Never leave it in a state that doesn't match the server.

```tsx
function EmailNotificationToggle() {
  const { data: settings } = useSettings()
  const updateSetting = useUpdateSetting()

  // Optimistic local state
  const [optimisticValue, setOptimisticValue] = useState<boolean | null>(null)
  const displayValue = optimisticValue ?? settings?.emailNotifications ?? false

  async function handleChange(newValue: boolean) {
    const previous = displayValue
    setOptimisticValue(newValue)  // Show new value immediately

    try {
      await updateSetting.mutateAsync({ emailNotifications: newValue })
      setOptimisticValue(null)    // Settled — let server state take over
    } catch {
      setOptimisticValue(previous)  // Revert
      toast.error('Failed to save. Try again.')
    }
  }

  return (
    <Toggle
      checked={displayValue}
      onChange={handleChange}
      label="Email notifications"
      description="Receive updates about your account activity"
      loading={updateSetting.isPending}
    />
  )
}
```

Why `optimisticValue` instead of just mutating the cache: separating local optimistic state from server cache state makes the revert simpler. If the mutation fails, set `optimisticValue` back to the previous value — no cache surgery needed.

## Loading State Behavior

While saving, the toggle should:
- Be visually disabled (`opacity-50`, `cursor-not-allowed`)
- Show `aria-busy="true"` for screen readers
- Show a spinner or subtle loading indicator
- Not be clickable (prevent double-firing)

Do not defer showing the new state until the API resolves — that creates a lag that feels broken. Show the optimistic state immediately and roll it back on failure.

## Disabled State

```tsx
<Toggle
  checked={notificationsEnabled}
  onChange={handleChange}
  label="Push notifications"
  disabled={!pushPermissionGranted}
  description={!pushPermissionGranted ? 'Enable browser push permission first' : undefined}
/>
```

A disabled toggle should still communicate *why* it's disabled, either via description text or a tooltip.

## Accessibility Details

- `role="switch"` announces as "Email notifications switch, on/off" to screen readers.
- `aria-checked` must be a boolean (`true`/`false`), not a string.
- The `<label>` with `htmlFor` linking to the button's `id` makes the label text clickable.
- `aria-busy="true"` during the API call tells screen readers "this control is updating".

## Key Rules

- Use `role="switch"` + `aria-checked`, not `role="checkbox"` for settings toggles — they have different interaction semantics.
- Always revert on API failure with a toast explaining what happened.
- Show optimistic state immediately; waiting for the API response before reflecting the change feels broken.
- `aria-busy="true"` during save, not just `disabled` — screen readers need to know why.
- The `<label>` element must be connected via `htmlFor` to make the label text clickable.
- The toggle button must show the current visual state even during loading (not revert to the old state while the API is in flight).

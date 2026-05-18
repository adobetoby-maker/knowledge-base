# Pattern: Form with Smart Defaults

## Overview
Forms that pre-fill from a user's history reduce entry time and error rate for repeat users. The key is to make the pre-fill visible and easy to override — a field that looks empty but is silently pre-filled is confusing. Storing last-used values per field type (not per specific form) means the "Billing address" field uses the same history whether the user is checking out, creating a quote, or updating a profile. A "Clear" button lets users start fresh without losing the pre-fill for future visits.

## Implementation

### Last-Used Value Store
```tsx
// Store per field TYPE, not per form instance
// Keys: 'address', 'payment_method', 'currency', 'country', etc.
const STORAGE_KEY = 'form-smart-defaults'

type SmartDefaults = Record<string, unknown>

function getSmartDefaults(): SmartDefaults {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '{}')
  } catch {
    return {}
  }
}

function saveSmartDefault(fieldType: string, value: unknown) {
  const current = getSmartDefaults()
  const updated = { ...current, [fieldType]: value }
  localStorage.setItem(STORAGE_KEY, JSON.stringify(updated))
}

// Also persist to user profile for cross-device
async function syncSmartDefaultsToProfile(fieldType: string, value: unknown) {
  try {
    await fetch('/api/user/preferences', {
      method: 'PATCH',
      body: JSON.stringify({ smartDefaults: { [fieldType]: value } }),
      headers: { 'Content-Type': 'application/json' },
    })
  } catch {
    // Local storage is fallback — server sync is best-effort
  }
}
```

### Smart Default Field Hook
```tsx
interface SmartFieldOptions {
  fieldType: string          // e.g. 'billing_country', 'currency', 'contact_email'
  serverDefault?: unknown    // from user profile (cross-device)
}

function useSmartDefault<T>(options: SmartFieldOptions) {
  const { fieldType, serverDefault } = options

  // Priority: server (cross-device) > localStorage > undefined
  const initialValue = (serverDefault ?? getSmartDefaults()[fieldType]) as T | undefined

  const [value, setValue] = useState<T | undefined>(initialValue)
  const [isPreFilled, setIsPreFilled] = useState(!!initialValue)

  const update = (newValue: T) => {
    setValue(newValue)
    setIsPreFilled(false) // User has now modified it
    saveSmartDefault(fieldType, newValue)
    syncSmartDefaultsToProfile(fieldType, newValue) // fire-and-forget
  }

  const clear = () => {
    setValue(undefined)
    setIsPreFilled(false)
  }

  return { value, isPreFilled, update, clear }
}
```

### Smart Field Component
```tsx
function SmartTextField({
  label,
  fieldType,
  serverDefault,
  onValue,
  ...inputProps
}: {
  label: string
  fieldType: string
  serverDefault?: string
  onValue?: (v: string) => void
} & React.InputHTMLAttributes<HTMLInputElement>) {
  const { value, isPreFilled, update, clear } = useSmartDefault<string>({
    fieldType,
    serverDefault,
  })

  return (
    <div>
      <div className="flex items-center justify-between mb-1">
        <label className="text-sm font-medium text-gray-700">{label}</label>
        {value && (
          <button
            type="button"
            onClick={clear}
            className="text-xs text-gray-400 hover:text-gray-600"
          >
            Clear
          </button>
        )}
      </div>

      <div className="relative">
        <input
          {...inputProps}
          value={value ?? ''}
          onChange={(e) => {
            update(e.target.value)
            onValue?.(e.target.value)
          }}
          className={[
            'w-full border rounded-md px-3 py-2 text-sm',
            isPreFilled ? 'border-blue-300 bg-blue-50' : 'border-gray-300',
            inputProps.className ?? '',
          ].join(' ')}
        />

        {isPreFilled && value && (
          <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-blue-500">
            last used
          </span>
        )}
      </div>

      {isPreFilled && value && (
        <p className="text-xs text-blue-500 mt-1">
          Pre-filled from your last entry. Press Enter to accept or type to change.
        </p>
      )}
    </div>
  )
}
```

### Accept Pre-Fill with Enter
```tsx
function SmartFormField({ fieldType, serverDefault, label }: SmartFieldProps) {
  const { value, isPreFilled, update } = useSmartDefault<string>({ fieldType, serverDefault })
  const [inputValue, setInputValue] = useState(value ?? '')
  const [accepted, setAccepted] = useState(false)

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && isPreFilled && !accepted) {
      e.preventDefault()
      setAccepted(true)
      // Move focus to next field
      const form = e.currentTarget.closest('form')
      const fields = Array.from(form?.elements ?? []) as HTMLElement[]
      const idx = fields.indexOf(e.currentTarget)
      fields[idx + 1]?.focus()
    }
  }

  return (
    <input
      value={inputValue}
      onChange={(e) => {
        setInputValue(e.target.value)
        update(e.target.value)
      }}
      onKeyDown={handleKeyDown}
    />
  )
}
```

### Server-Side Pre-Fill (on page load)
```tsx
// Fetch user's stored smart defaults from profile at page load
// Pass as props to form so SSR can render pre-filled values without flash
async function getUserSmartDefaults(userId: string): Promise<SmartDefaults> {
  const profile = await db.profiles.findById(userId)
  return profile?.smartDefaults ?? {}
}

// In the form component
function CheckoutForm({ userDefaults }: { userDefaults: SmartDefaults }) {
  return (
    <form>
      <SmartTextField
        label="Country"
        fieldType="billing_country"
        serverDefault={userDefaults.billing_country as string}
      />
      <SmartTextField
        label="Email"
        fieldType="contact_email"
        serverDefault={userDefaults.contact_email as string}
      />
    </form>
  )
}
```

## Key Rules
- Store last-used values per field TYPE, not per form — the same "billing country" value applies across checkout, quotes, and profile forms
- Visual differentiation between pre-filled and user-typed: blue border + "(last used)" hint is the convention
- Always show a "Clear" button when a field has a pre-filled value — users must be able to start fresh
- Accept with Enter moves focus to the next field — this lets power users tab-accept through a pre-filled form in seconds
- Server sync is fire-and-forget — localStorage is the authoritative local source; server sync enables cross-device
- Never silently pre-fill without showing the user what was pre-filled — hidden pre-fill leads to submitting stale values
- Priority order: server profile > localStorage > component default — server wins because it's cross-device
- Clear means "clear for this session" — the last-used value remains in storage for next time; the field just empties

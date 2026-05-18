# User Preferences

## Storage Hierarchy

Three places to store preferences — pick based on scope and persistence:

| Location | Scope | Persists | Auth required |
|---|---|---|---|
| `localStorage` | Browser only | Yes | No |
| Supabase `profiles` table | Cross-device | Yes | Yes |
| URL params | Session only | Navigates away | No |

Rule: store in localStorage first for immediate feedback, sync to Supabase for logged-in users.

## Profiles Table

```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS preferences jsonb DEFAULT '{}';

-- Or individual columns for frequently-queried preferences:
ALTER TABLE profiles ADD COLUMN theme text DEFAULT 'system';
ALTER TABLE profiles ADD COLUMN timezone text DEFAULT 'America/New_York';
ALTER TABLE profiles ADD COLUMN date_format text DEFAULT 'MM/DD/YYYY';
ALTER TABLE profiles ADD COLUMN notifications_enabled boolean DEFAULT true;
ALTER TABLE profiles ADD COLUMN items_per_page integer DEFAULT 20;
```

Use individual columns for preferences you'll filter/sort on; use `jsonb` for everything else.

## usePreferences Hook

```typescript
// hooks/usePreferences.ts
import { useState, useEffect, useCallback } from 'react'
import { supabase } from '@/lib/supabase/client'
import { useAuth } from '@/state/auth-state'

interface Preferences {
  theme: 'light' | 'dark' | 'system'
  itemsPerPage: 10 | 20 | 50
  timezone: string
  emailNotifications: boolean
}

const DEFAULTS: Preferences = {
  theme: 'system',
  itemsPerPage: 20,
  timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  emailNotifications: true,
}

const LS_KEY = 'user-preferences'

export function usePreferences() {
  const { user } = useAuth()
  const [prefs, setPrefs] = useState<Preferences>(() => {
    // Initialize from localStorage immediately (no flash):
    try {
      const stored = localStorage.getItem(LS_KEY)
      return stored ? { ...DEFAULTS, ...JSON.parse(stored) } : DEFAULTS
    } catch {
      return DEFAULTS
    }
  })
  
  // On mount, fetch from Supabase and merge:
  useEffect(() => {
    if (!user) return
    
    supabase
      .from('profiles')
      .select('preferences')
      .eq('id', user.id)
      .single()
      .then(({ data }) => {
        if (data?.preferences) {
          const merged = { ...DEFAULTS, ...data.preferences }
          setPrefs(merged)
          localStorage.setItem(LS_KEY, JSON.stringify(merged))
        }
      })
  }, [user?.id])
  
  const updatePreference = useCallback(async <K extends keyof Preferences>(
    key: K,
    value: Preferences[K]
  ) => {
    const updated = { ...prefs, [key]: value }
    
    // Optimistic local update:
    setPrefs(updated)
    localStorage.setItem(LS_KEY, JSON.stringify(updated))
    
    // Persist to Supabase if logged in:
    if (user) {
      await supabase
        .from('profiles')
        .update({ preferences: updated })
        .eq('id', user.id)
    }
  }, [prefs, user])
  
  return { prefs, updatePreference }
}
```

## Preferences Settings Page

```typescript
function PreferencesPage() {
  const { prefs, updatePreference } = usePreferences()
  
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="font-medium">Items per page</p>
          <p className="text-sm text-muted-foreground">Table and list pagination</p>
        </div>
        <Select
          value={String(prefs.itemsPerPage)}
          onValueChange={(v) => updatePreference('itemsPerPage', Number(v) as 10 | 20 | 50)}
        >
          <SelectTrigger className="w-24">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {[10, 20, 50].map(n => (
              <SelectItem key={n} value={String(n)}>{n}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      
      <div className="flex items-center justify-between">
        <div>
          <p className="font-medium">Email notifications</p>
          <p className="text-sm text-muted-foreground">Receive updates by email</p>
        </div>
        <Switch
          checked={prefs.emailNotifications}
          onCheckedChange={(v) => updatePreference('emailNotifications', v)}
        />
      </div>
    </div>
  )
}
```

## Timezone Handling

Store the IANA timezone string (`America/New_York`) in preferences. Apply on display:

```typescript
function formatInUserTimezone(date: Date, timezone: string): string {
  return new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}
```

Never store UTC offsets (`-05:00`) — they break during DST transitions.

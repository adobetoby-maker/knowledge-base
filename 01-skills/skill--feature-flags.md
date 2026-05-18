# Feature Flags

## When to Use Feature Flags

Feature flags (feature toggles) let you deploy code without activating it. Use when:
- Rolling out to a percentage of users (gradual rollout)
- A/B testing different UIs
- Hiding incomplete features from production while in development
- Giving early access to specific users

Do NOT use feature flags as a substitute for proper development workflow. Flags add complexity — clean them up after rollout.

## Simple Flag Implementation (No External Service)

For projects without a dedicated flag service, use Supabase or environment variables:

### Environment Variable Flags (Build-Time)
```typescript
// Simple on/off flags baked into the build
// .env.local
NEXT_PUBLIC_FEATURE_NEW_INVOICE_UI=true
NEXT_PUBLIC_FEATURE_ANALYTICS=false

// Usage
const NEW_INVOICE_UI = process.env.NEXT_PUBLIC_FEATURE_NEW_INVOICE_UI === 'true'

export function InvoicePage() {
  if (NEW_INVOICE_UI) return <NewInvoiceUI />
  return <LegacyInvoiceUI />
}
```

Limitation: changing requires a redeploy. Use for features under active development.

### Database Flags (Runtime, Per-User)
```sql
CREATE TABLE feature_flags (
  key TEXT PRIMARY KEY,           -- 'new_invoice_ui', 'ai_suggestions'
  enabled_for_all BOOLEAN DEFAULT false,
  enabled_user_ids UUID[] DEFAULT '{}',  -- early-access users
  rollout_percentage INTEGER DEFAULT 0   -- 0-100
);
```

```typescript
// lib/flags.ts
import { createClient } from '@/lib/supabase/server'

export async function isFeatureEnabled(key: string, userId?: string): Promise<boolean> {
  const supabase = createClient()
  const { data: flag } = await supabase
    .from('feature_flags')
    .select('enabled_for_all, enabled_user_ids, rollout_percentage')
    .eq('key', key)
    .single()

  if (!flag) return false
  if (flag.enabled_for_all) return true
  if (userId && flag.enabled_user_ids.includes(userId)) return true
  if (flag.rollout_percentage > 0 && userId) {
    // Deterministic: same user always gets same result
    const hash = hashUserId(userId)
    return (hash % 100) < flag.rollout_percentage
  }
  return false
}

// Deterministic hash for consistent rollout
function hashUserId(userId: string): number {
  return userId.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0)
}
```

### Using Flags in Server Components
```typescript
// app/(portal)/invoices/page.tsx
import { isFeatureEnabled } from '@/lib/flags'
import { getUser } from '@/lib/supabase/server'

export default async function InvoicesPage() {
  const user = await getUser()
  const showNewUI = await isFeatureEnabled('new_invoice_ui', user?.id)

  return showNewUI ? <NewInvoiceList /> : <LegacyInvoiceList />
}
```

### Caching Flag Lookups

Flag checks on every request are expensive. Cache with `unstable_cache`:
```typescript
import { unstable_cache } from 'next/cache'

const getFeatureFlags = unstable_cache(
  async () => {
    const supabase = createAdminClient()
    const { data } = await supabase.from('feature_flags').select('*')
    return data ?? []
  },
  ['feature-flags'],
  {
    revalidate: 60,  // refetch every 60 seconds
    tags: ['feature-flags'],
  }
)

// After updating a flag in admin:
revalidateTag('feature-flags')
```

## GrowthBook (External Flag Service)

For projects needing A/B testing or advanced targeting, GrowthBook is the open-source choice:

```bash
npm install @growthbook/growthbook-react
```

```typescript
// lib/growthbook.ts
import { GrowthBook } from '@growthbook/growthbook-react'

export function createGrowthBook(userId?: string) {
  return new GrowthBook({
    apiHost: process.env.NEXT_PUBLIC_GROWTHBOOK_API_HOST,
    clientKey: process.env.NEXT_PUBLIC_GROWTHBOOK_CLIENT_KEY,
    attributes: {
      id: userId,
      // Add any targeting attributes
    },
  })
}
```

## Flag Cleanup

Feature flags are technical debt. When a rollout completes:
1. Remove the flag check from code
2. Delete the flag from the database/service
3. Remove any A/B tracking code

Set a reminder: "Remove `new_invoice_ui` flag after 2026-06-01 full rollout."

## Admin Panel for Flags

In manage-worker-bee, add a simple flags page:
```
/admin/flags → list all flags with toggle switches
```

This lets you enable/disable features without a deploy. Log all flag changes with `who` and `when`.

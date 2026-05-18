# Agent Code Generation Patterns

## Context Before Code

Always load context before generating code. An agent that writes code without reading existing code creates divergent patterns.

**Required reads before generating any new file:**
1. CLAUDE.md or project-level documentation
2. An existing similar file in the same location
3. Any type files that the new code will reference

```
// Before generating app/(portal)/appointments/page.tsx:
Read: CLAUDE.md (project rules)
Read: app/(portal)/invoices/page.tsx (existing portal page pattern)
Read: lib/types.ts (for Appointment type)
```

## Pattern Matching

Generated code should match the existing codebase's patterns:

**Check before generating:**
- How are imports organized? (grouped: framework, third-party, local)
- What's the component naming convention? (PascalCase component file = function name)
- How are types defined? (inline vs exported from `lib/types.ts`)
- How is data fetched? (direct supabase calls vs through lib functions)
- What error handling pattern is used?

**Example: matching the pattern**
```typescript
// Existing pattern (read from invoices/page.tsx):
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { InvoiceList } from '@/components/portal/InvoiceList'

export default async function InvoicesPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  
  const { data: invoices } = await supabase.from('invoices').select('...')
  return <InvoiceList invoices={invoices ?? []} />
}

// Generated new page matches exact pattern:
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { AppointmentList } from '@/components/portal/AppointmentList'

export default async function AppointmentsPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  
  const { data: appointments } = await supabase.from('appointments').select('...')
  return <AppointmentList appointments={appointments ?? []} />
}
```

## Type-First Generation

Generate types before implementation. Code that references types that don't exist yet fails TypeScript compilation.

Order:
1. Database types / Supabase generated types
2. Domain types in `lib/types.ts`
3. API response types
4. Component prop types
5. Implementation code

```typescript
// Step 1: Add to lib/types.ts
export interface Appointment {
  id: string
  customer_id: string
  service_type: string
  scheduled_at: string
  status: 'scheduled' | 'completed' | 'cancelled'
  notes?: string
}

// Step 2: Now generate components that use Appointment
```

## Test-First for Business Logic

For functions with complex logic (calculations, transformations, validation):
1. Write the test describing expected behavior
2. Write the implementation
3. Run the test to verify

```typescript
// Step 1: test file
describe('calculateDiscount', () => {
  it('applies 20% discount', () => {
    expect(calculateDiscount(100, { type: 'percent', value: 20 })).toBe(80)
  })
})

// Step 2: implementation
export function calculateDiscount(total: number, discount: Discount): number {
  if (discount.type === 'percent') return total * (1 - discount.value / 100)
  return Math.max(0, total - discount.value)
}
```

## Generating Route Handlers

Standard Route Handler template:
```typescript
// app/api/[section]/[resource]/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
// Import correct auth for the section:
import { validateAdminSession } from '@/lib/adminAuth'  // for admin
// OR
import { createClient } from '@/lib/supabase/server'    // for portal

export async function GET(req: NextRequest) {
  // 1. Auth
  const isAdmin = await validateAdminSession(req)
  if (!isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  
  // 2. Parse params
  const { searchParams } = new URL(req.url)
  const page = parseInt(searchParams.get('page') ?? '1')
  
  // 3. Fetch
  const supabase = createAdminClient()
  const { data, error } = await supabase.from('table').select('*')
  
  if (error) return NextResponse.json({ error: 'Failed to fetch' }, { status: 500 })
  
  // 4. Return
  return NextResponse.json({ data })
}

export async function POST(req: NextRequest) {
  // 1. Auth
  // 2. Validate input with Zod
  const body = await req.json()
  const result = Schema.safeParse(body)
  if (!result.success) return NextResponse.json({ error: result.error.issues }, { status: 400 })
  
  // 3. Insert
  // 4. Return
}
```

## Avoid Generating Configuration Files

When generating code, don't regenerate or modify:
- `next.config.ts` (unless specifically asked)
- `tailwind.config.ts`
- `package.json` (use npm install command instead)
- `.env.local` (describe what vars are needed, don't write the file)

These files are configuration — wrong changes break the whole project.

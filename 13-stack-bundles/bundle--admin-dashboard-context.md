# Bundle: Admin Dashboard Context

## Architecture

Admin dashboards in this stack use cookie-based auth (not Supabase JWT). This is intentional: admin access is for internal users, not the public, and cookie auth is simpler to implement and audit.

## Auth System (admin only)

```ts
// lib/adminAuth.ts — the complete admin auth module
import { NextRequest, NextResponse } from 'next/server'
import { SignJWT, jwtVerify } from 'jose'

const ADMIN_SECRET = process.env.ADMIN_SECRET!
const COOKIE_NAME = 'admin_session'
const ADMINS_FILE = 'data/admins.json'

interface AdminSession {
  username: string
  issuedAt: number
}

export async function validateAdminSession(
  request: NextRequest
): Promise<AdminSession | null> {
  const cookie = request.cookies.get(COOKIE_NAME)
  if (!cookie) return null

  try {
    const { payload } = await jwtVerify(
      cookie.value,
      new TextEncoder().encode(ADMIN_SECRET),
      { algorithms: ['HS256'] }
    )
    return payload as unknown as AdminSession
  } catch {
    return null  // Expired, invalid, tampered
  }
}

export async function signAdminIn(
  username: string,
  password: string
): Promise<string | null> {
  const admins = JSON.parse(await fs.promises.readFile(ADMINS_FILE, 'utf-8'))
  const admin = admins.find((a: { username: string; passwordHash: string }) =>
    a.username === username
  )
  if (!admin) return null

  const valid = await bcrypt.compare(password, admin.passwordHash)
  if (!valid) return null

  const token = await new SignJWT({ username, issuedAt: Date.now() })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('8h')
    .sign(new TextEncoder().encode(ADMIN_SECRET))

  return token
}
```

## Route Protection Pattern

```ts
// Every admin Route Handler starts the same way:
export async function GET(request: NextRequest) {
  const session = await validateAdminSession(request)
  if (!session) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }
  // ... rest of handler
}

// For admin Server Components (page.tsx):
import { redirect } from 'next/navigation'
import { validateAdminSession } from '@/lib/adminAuth'
import { cookies } from 'next/headers'

export default async function AdminPage() {
  const cookieStore = await cookies()
  const sessionCookie = cookieStore.get('admin_session')

  // Build a mock request to reuse validateAdminSession
  const mockReq = new Request('http://localhost', {
    headers: { cookie: `admin_session=${sessionCookie?.value ?? ''}` }
  })
  const session = await validateAdminSession(mockReq as NextRequest)
  if (!session) redirect('/admin/login')

  // ... render admin content
}
```

## Admin Layout Structure

```
app/
  admin/
    layout.tsx          → AdminLayout with sidebar
    login/page.tsx      → Login form (no auth check)
    page.tsx            → Dashboard overview
    invoices/
      page.tsx          → Invoice list
      [id]/page.tsx     → Invoice detail
    clients/
      page.tsx          → Client list
    settings/page.tsx   → Settings
```

```tsx
// app/admin/layout.tsx
export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen">
      <AdminSidebar />
      <main className="flex-1 p-6 overflow-auto">
        {children}
      </main>
    </div>
  )
}
```

## Dashboard Data Fetching

All admin data fetches use the service role client:

```ts
// Always use supabaseAdmin — admin bypasses RLS
import { supabaseAdmin } from '@/lib/supabase/admin'

// Dashboard metrics
async function getDashboardStats() {
  const [invoiceStats, clientCount, recentActivity] = await Promise.all([
    supabaseAdmin
      .from('invoices')
      .select('status, total_cents')
      .gte('created_at', startOfMonth.toISOString()),
    supabaseAdmin
      .from('clients')
      .select('id', { count: 'exact', head: true }),
    supabaseAdmin
      .from('audit_log')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(10),
  ])

  return {
    invoiceStats: invoiceStats.data ?? [],
    clientCount: clientCount.count ?? 0,
    recentActivity: recentActivity.data ?? [],
  }
}
```

## Admin-Specific Patterns

**Data table with bulk actions**:
```tsx
const [selected, setSelected] = useState<Set<string>>(new Set())

// Header checkbox selects all
// Row checkboxes select individual
// Bulk action bar appears when selected.size > 0
```

**Confirm before destructive action**:
```tsx
// Always use ConfirmDialog before delete, cancel, void operations
const [confirmOpen, setConfirmOpen] = useState(false)
```

**Audit every mutation**:
```ts
// After every admin write operation:
await supabaseAdmin.from('audit_log').insert({
  entity_type: 'invoice',
  entity_id: invoiceId,
  actor_id: null,  // admin — no user ID in cookie auth
  action: 'voided',
  description: `Invoice #${number} voided by admin`,
})
```

## Never Use Admin Client Client-Side

`lib/supabase/admin.ts` must contain `import 'server-only'` at the top. It bypasses ALL row-level security. If it were imported in a client bundle, any user could call admin operations from the browser console.

```ts
// lib/supabase/admin.ts
import 'server-only'
// This throws at build time if imported in any file that runs client-side
```

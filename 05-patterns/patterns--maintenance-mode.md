# Pattern: Maintenance Mode

## Overview
Maintenance mode requires serving a response even when the application server itself may be partially or fully unavailable. The maintenance page must be served statically or from a layer that doesn't depend on the app being healthy. Middleware-based approaches work for routine maintenance; CDN-based approaches work when the origin is fully down.

## Implementation

### Middleware-based (Next.js / app layer)

```ts
// middleware.ts
import { NextRequest, NextResponse } from 'next/server'

const BYPASS_COOKIE = 'maintenance_bypass'
const BYPASS_SECRET = process.env.MAINTENANCE_BYPASS_SECRET!

export function middleware(req: NextRequest) {
  const maintenanceMode = process.env.MAINTENANCE_MODE === 'true'
  if (!maintenanceMode) return NextResponse.next()

  // Allow bypass via secret cookie (for team testing)
  const bypassCookie = req.cookies.get(BYPASS_COOKIE)
  if (bypassCookie?.value === BYPASS_SECRET) {
    return NextResponse.next()
  }

  // Don't redirect the maintenance page itself (infinite loop)
  if (req.nextUrl.pathname === '/maintenance') {
    return NextResponse.next()
  }

  // Allow static assets through
  if (req.nextUrl.pathname.startsWith('/_next/')) {
    return NextResponse.next()
  }

  return NextResponse.redirect(new URL('/maintenance', req.url))
}

export const config = {
  matcher: ['/((?!api/health|_next/static|_next/image|favicon.ico).*)'],
}
```

### Setting the bypass cookie (admin route)

```ts
// app/api/maintenance-bypass/route.ts
export async function GET(req: Request) {
  const { searchParams } = new URL(req.url)
  const secret = searchParams.get('secret')
  
  if (secret !== process.env.MAINTENANCE_BYPASS_SECRET) {
    return new Response('Unauthorized', { status: 401 })
  }

  const res = new Response('Bypass cookie set. You can now view the site.')
  res.headers.set('Set-Cookie', 
    `maintenance_bypass=${secret}; Path=/; HttpOnly; SameSite=Lax; Max-Age=86400`
  )
  return res
}
```

### Static maintenance page

```html
<!-- public/maintenance.html — pure HTML, no app server needed -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scheduled Maintenance</title>
  <style>
    body { font-family: system-ui, sans-serif; display: grid; 
           place-items: center; min-height: 100vh; margin: 0; background: #f8fafc; }
    .card { max-width: 480px; padding: 2rem; text-align: center; }
    h1 { font-size: 1.5rem; margin-bottom: .5rem; }
  </style>
</head>
<body>
  <div class="card">
    <h1>We'll be right back</h1>
    <p>Scheduled maintenance is in progress. Estimated completion: <strong id="eta"></strong></p>
    <p>Subscribe for updates: 
      <form><input type="email" placeholder="your@email.com"><button>Notify me</button></form>
    </p>
  </div>
  <script>
    // ETA injected at deploy time or fetched from a static JSON
    document.getElementById('eta').textContent = 
      new Date('2026-01-01T14:00:00Z').toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  </script>
</body>
</html>
```

### Vercel / CDN approach (origin fully down)

```json
// vercel.json — redirect everything to maintenance page at CDN edge
{
  "redirects": [
    {
      "source": "/((?!maintenance|_next/static|favicon).*)",
      "destination": "/maintenance",
      "permanent": false
    }
  ]
}
```

### Turning maintenance mode on/off

```bash
# Via environment variable (requires redeploy or runtime env support)
MAINTENANCE_MODE=true

# Via KV store (no redeploy needed)
# In middleware: const flag = await kv.get('maintenance_mode')
```

## Key Rules
- The maintenance page must not depend on the database, auth, or app server being available
- Always provide a bypass mechanism so you can test the site during maintenance
- Show estimated return time — "We'll be back soon" without a time is frustrating
- Include a status page link or email subscription for updates
- Return HTTP 503 (Service Unavailable) with `Retry-After` header — not 200
- Don't redirect `/api/health` — monitoring systems need to reach it
- After maintenance ends, test that the bypass cookie is removed or expired

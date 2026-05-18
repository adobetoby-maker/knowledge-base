# Failure: CORS Errors

**Symptom:** Browser console shows `Access to fetch at 'X' from origin 'Y' has been blocked by CORS policy`. The API call fails.

**Cause:** CORS (Cross-Origin Resource Sharing) is a browser security mechanism. The server hasn't told the browser it's allowed to receive requests from your origin.

## Important: CORS Is a Browser-Only Problem
CORS errors only happen in the browser. If you call the same API from Node.js (server), there's no CORS issue.
This is why: making the API call from your server (Route Handler, Server Component) instead of the browser fixes CORS entirely.

## Fix 1 — Call from the Server (Best Fix)
```typescript
// WRONG — browser calls external API directly → CORS error
// In a React component:
const response = await fetch('https://external-api.com/data')

// RIGHT — Route Handler proxies the call server-side → no CORS
// app/api/proxy/route.ts
export async function GET() {
  const response = await fetch('https://external-api.com/data', {
    headers: { 'Authorization': `Bearer ${process.env.API_KEY}` }
  })
  const data = await response.json()
  return NextResponse.json(data)
}

// Browser calls YOUR API instead:
const response = await fetch('/api/proxy')
```

## Fix 2 — Cloudflare Worker as Proxy
For external APIs you don't control:
```typescript
// Cloudflare Worker
export default {
  async fetch(request: Request, env: Env) {
    const response = await fetch('https://external-api.com/data')
    const data = await response.json()

    return new Response(JSON.stringify(data), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': 'https://yoursite.com',
        'Access-Control-Allow-Methods': 'GET, POST',
      }
    })
  }
}
```

## Fix 3 — Add CORS Headers to YOUR API
If you control the API that's being called:
```typescript
// app/api/data/route.ts
export async function GET(req: NextRequest) {
  const data = await getData()
  return NextResponse.json(data, {
    headers: {
      'Access-Control-Allow-Origin': 'https://yourfrontend.com',  // specific domain
      // OR:
      'Access-Control-Allow-Origin': '*',  // any origin (only for public APIs)
    }
  })
}

// Handle preflight OPTIONS request
export async function OPTIONS() {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    }
  })
}
```

## CORS vs 401 vs Network Error
```
CORS error:    "blocked by CORS policy" — server doesn't allow this origin
401 error:     "Unauthorized" — request got through but auth failed  
Network error: "Failed to fetch" — could be DNS, offline, or a CORS preflight failure
```

## The Preflight Request
For non-simple requests (with headers, or non-GET/POST), browsers send an OPTIONS "preflight" first.
If the server doesn't respond to OPTIONS with the right headers, the actual request never fires.
Always handle OPTIONS in your Route Handlers if you're getting CORS issues with POST/PUT.

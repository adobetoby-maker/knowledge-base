# Next.js Route Handlers — Advanced Patterns

## Request Parsing

```typescript
export async function POST(request: Request) {
  // JSON body
  const body = await request.json()
  
  // Form data
  const formData = await request.formData()
  const name = formData.get('name') as string
  const file = formData.get('file') as File
  
  // URL search params
  const url = new URL(request.url)
  const page = Number(url.searchParams.get('page') ?? '1')
  
  // Headers
  const authHeader = request.headers.get('authorization')
  const contentType = request.headers.get('content-type')
  
  // Cookies
  const cookies = request.headers.get('cookie')
}
```

## Dynamic Route Segments

```typescript
// app/api/invoices/[id]/route.ts
export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params  // Must await — Promise in Next.js 15+
}
```

## Streaming Response

For long-running operations, stream results as they become available:

```typescript
export async function GET() {
  const encoder = new TextEncoder()
  
  const stream = new ReadableStream({
    async start(controller) {
      for (let i = 0; i <= 100; i += 10) {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({ progress: i })}\n\n`))
        await new Promise(r => setTimeout(r, 500))
      }
      controller.close()
    }
  })
  
  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    }
  })
}
```

## Caching Route Handlers

By default, route handlers with GET methods are NOT cached. To cache:

```typescript
// Force cache for static data
export const revalidate = 3600  // revalidate every hour

export async function GET() {
  const data = await getPublicData()
  return Response.json(data)
}
```

To disable caching explicitly:
```typescript
export const dynamic = 'force-dynamic'
```

## Redirects

```typescript
import { redirect } from 'next/navigation'

export async function GET(request: Request) {
  const url = new URL(request.url)
  const code = url.searchParams.get('code')
  
  if (!code) {
    return Response.redirect(new URL('/login', request.url))
  }
  
  // ... or from Server Components:
  redirect('/dashboard')
}
```

Use `Response.redirect()` in Route Handlers, `redirect()` from `next/navigation` in Server Components.

## CORS Headers

```typescript
export async function OPTIONS(request: Request) {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': process.env.NEXT_PUBLIC_URL!,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    }
  })
}

function corsHeaders(response: Response) {
  response.headers.set('Access-Control-Allow-Origin', process.env.NEXT_PUBLIC_URL!)
  return response
}
```

Handle `OPTIONS` preflight requests for CORS-enabled endpoints.

## File Download Response

```typescript
export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const invoice = await getInvoice(id)
  const pdfBuffer = await generatePDF(invoice)
  
  return new Response(pdfBuffer, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="invoice-${id}.pdf"`,
      'Content-Length': String(pdfBuffer.byteLength),
    }
  })
}
```

## Webhook Pattern with Signature Verification

```typescript
// app/api/webhooks/stripe/route.ts
import Stripe from 'stripe'

export async function POST(request: Request) {
  const body = await request.text()  // Must be text, not json() — signature is over raw body
  const sig = request.headers.get('stripe-signature')
  
  if (!sig) return new Response('Missing signature', { status: 400 })
  
  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!)
  } catch (err) {
    return new Response('Invalid signature', { status: 400 })
  }
  
  // Handle event
  await processStripeEvent(event)
  
  return new Response('OK', { status: 200 })
}

// Critical: webhooks cannot use body parsing — raw text required
export const config = { api: { bodyParser: false } }
```

## Rate Limiting Pattern

```typescript
import { headers } from 'next/headers'

export async function POST(request: Request) {
  const headersList = await headers()
  const ip = headersList.get('x-forwarded-for') ?? 'anonymous'
  
  // Check rate limit (using Upstash or in-memory for simple cases)
  const allowed = await checkRateLimit(ip)
  if (!allowed) {
    return Response.json({ error: 'Too many requests' }, {
      status: 429,
      headers: { 'Retry-After': '60' }
    })
  }
  
  // Process request
}
```

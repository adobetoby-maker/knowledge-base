# Failure: Edge Runtime Missing Node.js APIs

## Overview
Edge functions (Vercel Edge Functions, Cloudflare Workers, Next.js middleware) run on V8-based runtimes, not Node.js. They don't have `fs`, `path`, `crypto.createCipher`, `Buffer`, `child_process`, `process.env` (in some runtimes), or any Node built-in that requires OS access. Code that runs fine in a regular server-side function will silently fail or throw at edge runtime. Check the compatibility table before using any Node.js API in edge code.

## What's Missing

```ts
// MISSING in Edge Runtime
import fs from 'fs'                          // No filesystem
import path from 'path'                       // No path module (use URL instead)
import { createCipher } from 'crypto'        // No legacy crypto (use Web Crypto)
import { exec } from 'child_process'         // No child processes
import { createServer } from 'http'          // No raw HTTP server
import { Buffer } from 'buffer'              // No Buffer (use Uint8Array)

// process.env — available in Vercel Edge, but use env() in Cloudflare Workers
// process.cwd() — NOT available
// __dirname, __filename — NOT available
```

## Crypto: Web Crypto API Instead

```ts
// BAD — Node.js crypto
import { createHash, createHmac } from 'crypto'
const hash = createHash('sha256').update(data).digest('hex')

// GOOD — Web Crypto API (available in all edge runtimes)
async function sha256(data: string): Promise<string> {
  const encoder = new TextEncoder()
  const hashBuffer = await crypto.subtle.digest('SHA-256', encoder.encode(data))
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

// HMAC signing (e.g., for webhook verification)
async function verifyHmac(secret: string, payload: string, signature: string): Promise<boolean> {
  const encoder = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['verify']
  )
  const sigBuffer = Uint8Array.from(Buffer.from(signature, 'hex'))
  return crypto.subtle.verify('HMAC', key, sigBuffer, encoder.encode(payload))
}
```

## Buffer → Uint8Array

```ts
// BAD
const buf = Buffer.from(base64String, 'base64')
const str = buf.toString('utf8')

// GOOD
function base64ToUint8Array(base64: string): Uint8Array {
  const binary = atob(base64)
  return new Uint8Array([...binary].map(c => c.charCodeAt(0)))
}

function uint8ArrayToString(bytes: Uint8Array): string {
  return new TextDecoder().decode(bytes)
}

// Or: in Cloudflare Workers, Buffer IS available as a polyfill
// but not in Vercel Edge — check your target runtime
```

## process.env in Edge Runtimes

```ts
// Vercel Edge Functions — process.env works
export const config = { runtime: 'edge' }
export default function handler(req: Request) {
  const key = process.env.API_KEY  // works in Vercel Edge
}

// Cloudflare Workers — use env parameter
export default {
  async fetch(request: Request, env: Env) {
    const key = env.API_KEY  // env bindings, not process.env
  }
}

// Next.js middleware (edge) — process.env works for NEXT_PUBLIC_ and server vars
```

## Path Manipulation Without `path` Module

```ts
// BAD
import path from 'path'
const filename = path.basename(req.url)

// GOOD — use URL API (available everywhere)
const url = new URL(req.url)
const segments = url.pathname.split('/')
const filename = segments[segments.length - 1]
```

## Detecting Missing APIs at Build Time

```ts
// next.config.js — force edge runtime for a route
// app/api/edge-route/route.ts
export const runtime = 'edge'

// TypeScript: add edge types to tsconfig
{
  "compilerOptions": {
    "lib": ["ES2022", "WebWorker"]  // WebWorker has edge-compatible types
  }
}
```

If you use a Node API that doesn't exist in edge, Next.js will error at build time with `Module not found: Can't resolve 'fs'` or similar.

## Runtime Compatibility Tables

- Vercel Edge: https://edge-runtime.vercel.app/features/available-apis
- Cloudflare Workers: https://developers.cloudflare.com/workers/runtime-apis/
- Next.js Edge: https://nextjs.org/docs/app/api-reference/edge

## Key Rules
- Check the compatibility table for ANY Node.js API before using it in edge code
- Use Web Crypto (`crypto.subtle`) instead of Node `crypto` module
- Use `Uint8Array` and `TextEncoder`/`TextDecoder` instead of `Buffer`
- Use `URL` and string manipulation instead of `path` module
- Set `export const runtime = 'edge'` explicitly in Next.js routes — this enables build-time compatibility checks
- Test edge functions in the actual edge runtime, not Node.js — some things work in Node but fail at edge
- If you need Node APIs, don't use edge runtime — use regular serverless (Node.js)

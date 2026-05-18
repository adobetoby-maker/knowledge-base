# Failure: Next.js Server Component / Client Component Import Errors

## Overview
Next.js App Router has two component environments: Server Components (run only on the server, can use Node.js APIs, cannot use browser APIs) and Client Components (run on both server and browser, can use React hooks and browser APIs). The import boundary between these two environments is strict and one-directional. Importing client-only code into a Server Component, or importing server-only code into a Client Component, produces runtime errors that are often confusing because they surface as module resolution failures or "window is not defined" errors, not as clear boundary violations.

## The Import Rules

```
Server Components → Can import Client Components ✓
Client Components → Cannot import Server Components ✗
Server Components → Cannot use browser APIs ✗
Client Components → Cannot use Node.js-only modules (fs, crypto) ✗
```

```
app/
  page.tsx              ← Server Component by default
  components/
    Header.tsx          ← 'use client' → Client Component
    ServerList.tsx      ← Server Component (no directive)
    DataTable.tsx       ← 'use client' → Client Component
```

A Server Component can render a Client Component:
```typescript
// app/page.tsx (Server Component)
import { DataTable } from "@/components/DataTable"; // 'use client' — OK
import { ServerList } from "@/components/ServerList"; // Server Component — OK

export default async function Page() {
  const data = await db.query(...); // OK: server-only DB call
  return <DataTable data={data} />; // OK: passing serializable data to client component
}
```

A Client Component cannot import a Server Component:
```typescript
// components/DataTable.tsx
"use client";
import { ServerList } from "./ServerList"; // ← WRONG: importing Server Component into Client

// Fix: pass ServerList as a prop (children) instead
// The parent Server Component renders ServerList, passes it as children
```

## The "Barrel File" Trap

The most common trigger for this error is barrel files (`index.ts`) that export both server and client components:

```typescript
// components/index.ts — DANGEROUS barrel file
export { DataTable } from "./DataTable"; // 'use client'
export { ServerList } from "./ServerList"; // Server Component — uses db client
export { Header } from "./Header"; // 'use client'

// When a Client Component imports from this barrel:
// import { DataTable } from "@/components"; // also imports ServerList's db client → error
```

Fix: do not use barrel files that mix server and client components. Import directly from the file:
```typescript
import { DataTable } from "@/components/DataTable";
```

Or use two separate barrel files: `components/client/index.ts` and `components/server/index.ts`.

## The `server-only` Package

For modules that must never run in the browser (database clients, admin secrets), use the `server-only` package to get a clear error at build time instead of a cryptic runtime error:

```typescript
// lib/db.ts
import "server-only"; // throws build error if this file is imported by client code

import { createClient } from "@supabase/supabase-js";
export const db = createClient(process.env.SUPABASE_URL!, process.env.SERVICE_ROLE_KEY!);
```

Similarly, `client-only` for browser-only code:
```typescript
// lib/analytics.ts
import "client-only"; // throws if imported in Server Component

import mixpanel from "mixpanel-browser";
```

## Common Error Messages and Their Causes

| Error | Cause |
|---|---|
| `window is not defined` | Browser API in Server Component |
| `localStorage is not defined` | Browser API in Server Component |
| `useEffect is not defined` | Hook in Server Component (missing `'use client'`) |
| `Cannot read properties of undefined (reading 'createContext')` | React context in Server Component |
| Module build failed importing `fs` | Node.js module imported into client bundle |

## Data Passing From Server to Client

Data flows from Server Component to Client Component via props. The data must be serializable (no functions, class instances, Dates as objects — convert to ISO strings):

```typescript
// Server Component
const orders = await db.orders.findMany(); // Date objects from Prisma

// Wrong: Date objects are not serializable
return <OrderTable orders={orders} />;

// Right: serialize dates
return <OrderTable orders={orders.map(o => ({
  ...o,
  createdAt: o.createdAt.toISOString(), // string, serializable
}))} />;
```

## Key Rules
- Server Components can import Client Components; the reverse is not allowed
- Barrel files that mix server and client components cause hard-to-debug errors
- Use `import "server-only"` in any file that must stay server-side
- Database clients, service role keys, `fs`, Node crypto → server only, never in client bundle
- Data passed as props from Server → Client must be serializable (strings, numbers, plain objects)
- Browser APIs (`window`, `localStorage`, `navigator`) → always in Client Components or `useEffect`
- React hooks (`useState`, `useEffect`, `useContext`) require `'use client'`

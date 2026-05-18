# Plugin: openapi-fetch

## Overview

`openapi-fetch` generates a type-safe fetch client from an OpenAPI schema. Every endpoint, parameter, and response is typed — no manual interface definitions, no runtime validation needed beyond what the schema enforces. Works with `openapi-typescript` to generate types from a schema URL or local file.

## Installation

```bash
npm install openapi-fetch
npm install -D openapi-typescript
```

## Generate Types from Schema

```bash
# From URL
npx openapi-typescript https://api.example.com/openapi.yaml -o src/types/api.d.ts

# From local file
npx openapi-typescript openapi.yaml -o src/types/api.d.ts
```

## Create Client

```ts
// lib/api.ts
import createClient from 'openapi-fetch'
import type { paths } from '@/types/api'

export const api = createClient<paths>({
  baseUrl: process.env.NEXT_PUBLIC_API_URL ?? 'https://api.example.com',
})
```

## Typed Requests

```ts
// GET with typed params and response
const { data, error } = await api.GET('/users/{id}', {
  params: {
    path: { id: '123' },          // TypeScript error if id is wrong type
    query: { include: 'orders' }, // TypeScript error if param doesn't exist
  },
})

if (error) {
  // error is typed from the schema's error responses
  console.error(error.message)
  return
}

// data is fully typed — no casting needed
console.log(data.name)
```

```ts
// POST with typed body
const { data, error } = await api.POST('/orders', {
  body: {
    userId: '123',
    items: [{ productId: 'abc', quantity: 2 }],
    // TypeScript enforces the schema shape
  },
})
```

## With Auth Headers

```ts
// lib/api.ts
export const api = createClient<paths>({
  baseUrl: process.env.NEXT_PUBLIC_API_URL!,
  headers: {
    Authorization: `Bearer ${getToken()}`,
  },
})

// Or with middleware for dynamic tokens
const authMiddleware: Middleware = {
  async onRequest({ request }) {
    const token = await getToken()
    request.headers.set('Authorization', `Bearer ${token}`)
    return request
  },
}

api.use(authMiddleware)
```

## TanStack Query Integration

```tsx
function useUser(id: string) {
  return useQuery({
    queryKey: ['users', id],
    queryFn: async () => {
      const { data, error } = await api.GET('/users/{id}', {
        params: { path: { id } },
      })
      if (error) throw error
      return data
    },
  })
}

function useCreateOrder() {
  return useMutation({
    mutationFn: async (body: CreateOrderBody) => {
      const { data, error } = await api.POST('/orders', { body })
      if (error) throw error
      return data
    },
  })
}
```

## Error Handling Pattern

```ts
type ApiResult<T> =
  | { data: T; error: undefined }
  | { data: undefined; error: ApiError }

async function safeGet<T>(call: () => Promise<ApiResult<T>>): Promise<T> {
  const { data, error } = await call()
  if (error) {
    // error.status, error.message from schema
    throw new AppError(error.message, error.status)
  }
  return data
}

const user = await safeGet(() => api.GET('/users/{id}', { params: { path: { id } } }))
```

## Local Development with Mock

```ts
// In test/mock setup
import { createServer } from 'msw/node'
import { http, HttpResponse } from 'msw'

const server = createServer(
  http.get('https://api.example.com/users/:id', ({ params }) => {
    return HttpResponse.json({ id: params.id, name: 'Test User' })
  })
)
```

## Key Rules

- Re-run `openapi-typescript` after any schema change — types go stale silently.
- `{ data, error }` is always returned — never throws. Check `error` before using `data`.
- `data` and `error` are mutually exclusive: if `error` is defined, `data` is `undefined`, and vice versa.
- For internal APIs, generate the schema from your route handlers (e.g., `zod-to-openapi` or `@asteasolutions/zod-to-openapi`) to keep types in sync automatically.
- Don't wrap `openapi-fetch` in another abstraction layer — the typed client is the abstraction.

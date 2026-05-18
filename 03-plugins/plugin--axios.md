# Plugin: axios

## Overview

HTTP client for Node.js and browser. In most modern contexts, `fetch` is sufficient and preferred over axios — but axios adds value for: request/response interceptors, automatic JSON transform, request cancellation with CancelToken, upload progress tracking, and older browser support (though this is rarely needed today).

## When to Choose axios over fetch

| Need | axios | fetch |
|---|---|---|
| Request interceptors | ✓ Built-in | Manual wrapper needed |
| Upload progress | ✓ `onUploadProgress` | Manual with XMLHttpRequest |
| Automatic JSON parsing | ✓ | Manual `res.json()` |
| Older browser support | ✓ | Needs polyfill |
| Bundle size | +14KB | 0KB (native) |
| Timeout | ✓ `timeout` option | `AbortSignal.timeout()` |

For most API calls in a modern Next.js app: use `fetch`. Use axios when you need interceptors for auth token injection or upload progress.

## Installation

```bash
npm install axios
```

## Typed API Client

```ts
import axios from 'axios'

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  timeout: 10_000,
  headers: { 'Content-Type': 'application/json' },
})

// Request interceptor — inject auth token
api.interceptors.request.use(config => {
  const token = getAuthToken()
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// Response interceptor — handle auth errors globally
api.interceptors.response.use(
  response => response,
  async error => {
    if (error.response?.status === 401) {
      await refreshAuthToken()
      return api.request(error.config)  // Retry with new token
    }
    return Promise.reject(error)
  }
)

export default api
```

## Request and Response Types

```ts
interface User { id: string; name: string; email: string }

// Typed response
const { data } = await api.get<User>('/users/me')
data.name  // TypeScript knows this is string

// Typed request body
const { data: newUser } = await api.post<User>('/users', { name, email } as Partial<User>)
```

## Upload Progress

This is axios's clearest advantage over fetch:

```ts
async function uploadFile(file: File, onProgress: (percent: number) => void) {
  const formData = new FormData()
  formData.append('file', file)

  const { data } = await api.post('/upload', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
    onUploadProgress: event => {
      const percent = Math.round((event.loaded * 100) / (event.total ?? event.loaded))
      onProgress(percent)
    },
  })

  return data.url
}
```

## Error Handling

```ts
import { isAxiosError } from 'axios'

try {
  await api.post('/orders', orderData)
} catch (err) {
  if (isAxiosError(err)) {
    const status = err.response?.status
    const message = err.response?.data?.message ?? err.message
    // Handle API errors
  }
  // Non-axios errors (network, timeout) also land here
  throw err
}
```

## Cancellation

```ts
const controller = new AbortController()

const request = api.get('/search', {
  params: { q: query },
  signal: controller.signal,  // Modern way (same as fetch)
})

// Cancel when component unmounts or query changes
return () => controller.abort()
```

## Key Rules

- Create a shared instance (`axios.create(...)`) — don't use the default `axios` import directly in components.
- Don't use axios for simple GET requests that don't need interceptors — `fetch` is cleaner.
- Interceptors run globally — keep them thin, no business logic.
- Axios auto-parses JSON; accessing `.data` is the response body, not `.body`.

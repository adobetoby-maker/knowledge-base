# Native fetch vs axios

## Why This Decision Matters

`axios` is a third-party HTTP client that predates native `fetch` becoming broadly available. It was indispensable in 2015 when `XMLHttpRequest` was the alternative. In 2024+, `fetch` is available in all modern browsers, Node.js 18+, Deno, Bun, Cloudflare Workers, and every edge runtime. The default answer has flipped: start with `fetch` and reach for `axios` only when you need something specific it provides.

## What axios Still Does Better

**Request/response interceptors.** axios has a clean middleware pipeline: `axios.interceptors.request.use(fn)` and `axios.interceptors.response.use(fn)`. This makes it easy to attach auth headers globally, log all requests, or retry on 401 in one place. With `fetch`, you implement this pattern yourself (a wrapper function, or a `ky` library).

**Automatic JSON serialization/deserialization.** `axios.post(url, data)` serializes `data` to JSON and sets `Content-Type: application/json` automatically. `response.data` is already parsed. `fetch` requires `JSON.stringify(body)` on the way out and `await response.json()` on the way in — two extra lines every time.

**Automatic error throwing on non-2xx status.** axios throws for 4xx/5xx responses. `fetch` resolves successfully for any response where the network request completed — a 404 is not an error in `fetch`'s model unless you check `response.ok`.

**Upload progress.** axios supports `onUploadProgress` callbacks via `XMLHttpRequest`. `fetch` with the Streams API can report download progress, but upload progress is still not natively available in all environments.

## Where fetch Wins

**Edge and serverless runtimes.** Cloudflare Workers, Vercel Edge Functions, and Deno only support `fetch`. axios uses Node.js's `http` module under the hood and will not run in V8-isolate environments without a polyfill. For any code that runs on the edge, `fetch` is the only choice.

**Bundle size.** axios adds ~15 KB gzipped to a client bundle. `fetch` is zero bytes — it is a browser/runtime native. In performance-sensitive SPAs or edge workers, this matters.

**Request cancellation.** `AbortController` + `signal` is the standard cross-runtime cancellation mechanism and works natively with `fetch`. axios has its own cancellation API (`CancelToken`) which is deprecated in favor of `AbortController` as well — but the integration is less clean.

**Timeout.** `fetch` has no built-in `timeout` option, but `AbortController` with `AbortSignal.timeout(ms)` solves this in one line. axios's `timeout` option is simpler to read but does the same thing.

## Practical Recommendation

Use `fetch` for:
- Any code that runs on Cloudflare Workers, edge functions, or non-Node runtimes
- Simple GET/POST in a modern codebase where you are not already using axios
- Server Components and Route Handlers in Next.js (Node.js fetch is standard there)

Use axios (or `ky`) for:
- Client-side code where you need global interceptors (auth token injection, global error handling)
- Large existing codebases already using axios extensively — consistency outweighs the switch
- Projects where upload progress events are required

A thin wrapper around `fetch` handles 90% of what axios provides without the dependency:

```ts
async function apiFetch<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...init?.headers },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`);
  return res.json() as Promise<T>;
}
```

## Key Rules

- **Never import axios in Cloudflare Worker or edge runtime code** — it will fail at runtime.
- **Always check `response.ok`** when using `fetch` — a 4xx/5xx does not throw by default.
- Use `AbortSignal.timeout(ms)` for fetch timeouts — do not implement timeout with `setTimeout` + manual abort unless you need pre-Node 20 compatibility.
- If adding global auth headers, write a single wrapper rather than spreading `headers` across every call site.
- Do not mix axios and fetch in the same project — pick one HTTP strategy per layer (client vs server).

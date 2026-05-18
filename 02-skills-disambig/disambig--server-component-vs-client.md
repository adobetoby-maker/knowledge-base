# RSC vs Client Component

## The Mental Model Shift

React Server Components (RSC) do not run in the browser. They execute on the server during the request, produce HTML, and send it to the client. They never hydrate. They have no JavaScript bundle impact. They cannot use `useState`, `useEffect`, event handlers, or browser APIs.

Client Components run in both places: on the server during SSR (for initial HTML) and in the browser (for interactivity). They are what React components have always been. The `"use client"` directive marks where the server-client boundary is.

The confusion is that this is a boundary, not a binary — RSCs can render Client Components as children, but Client Components cannot import RSCs (only pass them as props).

## Why RSCs Exist: The Bundle Problem

Before RSC, data fetching and heavy dependencies (markdown parsers, date libraries, syntax highlighters) were bundled to the client even when they only ran once at render time. A page that fetches data, formats dates, and highlights code was shipping those libraries to every browser.

RSCs solve this by keeping heavy dependencies on the server. A syntax highlighter used only in an RSC contributes zero bytes to the client bundle. Data fetching in RSC eliminates a client-side waterfall (component mounts → fetch request → render) by making data available before the response is sent.

## RSC: When to Use

Use RSC for components that:
- Fetch data from a database, API, or filesystem
- Use large dependencies that don't need to be interactive (markdown, syntax highlighting, PDF processing)
- Render static or non-interactive UI (layout shells, navigation that doesn't respond to interaction state, content pages)
- Access server-only resources (environment variables, private APIs)

RSCs compose well for data fetching — each component in a tree can fetch its own data in parallel without a central data-fetching layer or prop drilling.

## Client Component: When to Use

Use `"use client"` only when the component needs:
- `useState` or `useReducer`
- `useEffect` or any lifecycle behavior
- Event handlers (`onClick`, `onChange`, `onSubmit`)
- Browser APIs (`window`, `document`, `localStorage`, `IntersectionObserver`)
- Third-party libraries that use the above (most animation libraries, drag-and-drop, rich text editors)

## The "Push to the Leaves" Strategy

The most common RSC mistake is adding `"use client"` at a high level in the tree because one interactive element needs it. This converts the entire subtree to client components, losing the bundle and data-fetching benefits of RSC for everything above.

The correct strategy: keep the outer component as RSC, extract the interactive part into its own small Client Component, and pass data down as props or use Server Component composition.

```
// Bad: entire page becomes client because of one button
"use client"
export default function ProductPage() { /* fetches data, renders content, has one interactive button */ }

// Good: push the client boundary to the leaf
// ProductPage.tsx — RSC, fetches data
// AddToCartButton.tsx — "use client", handles click state
```

## Passing Data Across the Boundary

Props passed from RSC to Client Components must be serializable — plain objects, arrays, strings, numbers, booleans. Functions, class instances, Date objects (non-serializable), and non-serializable browser objects cannot be passed as props across the boundary.

If a Client Component needs a callback, define it inside the Client Component. If it needs a server action, import the server action directly (server actions are serializable references).

## Key Rules

- Default to RSC; add `"use client"` only when the component genuinely needs interactivity or browser APIs
- Never add `"use client"` to a file just because a child needs it — extract the child instead
- Data fetching belongs in RSC unless the data must refresh in response to user interaction without a navigation
- `useState` + fetch inside `useEffect` is the old pattern; in the RSC model, move that fetch into a Server Component
- Client Components that import heavy libraries (charting, rich text, video) should be lazy-loaded with `next/dynamic` to defer their bundle
- Treat the RSC/Client boundary as an API surface — keep it explicit and minimal

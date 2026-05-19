# ADR: Next.js 16 — What Actually Changed From Training Data

**Applies to:** jrs-auto-repair, manage-worker-bee, silver-creek-logistics, orthobiologic-pathways, tobyandertonmd, willie-elam
**Warning:** LLM training data is Next.js 13/14. Read `node_modules/next/dist/docs/` before writing any Next.js code.

## The Single Most Important Rule

**Before writing any Next.js code, check:**
```
node_modules/next/dist/docs/
```

This directory contains the actual docs bundled with the installed version. If the installed version differs from your training data, this directory tells you the ground truth.

## Breaking Changes to Watch For

### React 19 + Next.js 16

React 19 shipped with Next.js 16. Key differences:
- `use client` and `use server` directives work differently in the App Router
- Async Server Components are stable but have different rules than Next.js 14
- `cache()` function behavior changed
- Concurrent features affect rendering order

### `NEXT_PUBLIC_` vs Server Env Vars

- `NEXT_PUBLIC_*` is exposed to the browser bundle — only use for non-secret values
- Server env vars (no prefix) are never sent to the browser
- In language-lens-elite (TanStack Start), it's `VITE_*` not `NEXT_PUBLIC_*` — don't confuse the two

### `generateStaticParams` vs `getStaticPaths`

`getStaticPaths` is Pages Router. In App Router it's `generateStaticParams`:
```ts
// App Router (correct)
export async function generateStaticParams() {
  return articles.map(a => ({ slug: a.slug }));
}
```

### Server Components vs Client Components

- Default is Server Component — no `useState`, no `useEffect`, no browser APIs
- `"use client"` at the top makes it a Client Component
- Can't import `lib/supabase/admin.ts` in any file with `"use client"` — service role key would leak to browser bundle

### `next/image` Changes

- `fill` prop replaces `layout="fill"` — use `fill style={{ objectFit: "cover" }}`
- `priority` prop for above-the-fold images (LCP optimization)
- `unoptimized` bypasses Next.js image optimization — use for external images or when format control is needed

### Route Handlers vs API Routes

- `app/api/route.ts` not `pages/api/handler.ts`
- Export named functions: `export async function GET(request: Request) { ... }`
- No `req`/`res` — use Web API `Request`/`Response`

### `metadata` Export

```ts
// app/page.tsx
export const metadata = {
  title: "Page Title",
  description: "Page description",
};
```
This replaces `<Head>` from Pages Router. Works statically and dynamically via `generateMetadata()`.

## Env Var Patterns by Project

| Project | Pattern | Example |
|---|---|---|
| jrs-auto-repair | `NEXT_PUBLIC_` for browser, bare for server | `NEXT_PUBLIC_SUPABASE_URL` |
| manage-worker-bee | All server-side (no browser Supabase) | `SUPABASE_SERVICE_ROLE_KEY` |
| silver-creek-logistics | Same as jrs | `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| language-lens-elite | `VITE_*` (not Next.js) | `VITE_SUPABASE_URL` |

## The "Check the Installed Docs" Habit

When something isn't working and you're unsure if it's a Next.js API change:
```bash
ls node_modules/next/dist/docs/
# or
grep -r "generateStaticParams" node_modules/next/dist/docs/ --include="*.md" -l
```

This surfaces the actual behavior of the installed version, not training-data Next.js.

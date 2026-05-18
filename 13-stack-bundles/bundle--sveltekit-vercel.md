# SvelteKit on Vercel

## Stack Overview

SvelteKit is a fullstack framework built on Svelte 5. Unlike Next.js, there is no virtual DOM — Svelte compiles components to vanilla JS that surgically updates the DOM. The result is smaller bundles, no reconciliation overhead, and a different mental model: reactivity via declarations and runes, not hooks.

`adapter-vercel` deploys SvelteKit to Vercel's edge/serverless infrastructure with zero configuration. Install it, set `adapter: vercel()` in `svelte.config.js`, and deploy.

## File Structure

SvelteKit uses a file-based routing system with co-located server and client files:

```
src/routes/
  +layout.svelte          // persistent shell (nav, providers)
  +layout.server.ts       // load function for layout data (runs on server)
  invoices/
    +page.svelte          // client component — renders the page
    +page.server.ts       // load function + form actions (runs on server only)
    [id]/
      +page.svelte
      +page.server.ts
```

The `+page.server.ts` suffix means "never shipped to the browser." Everything in it runs server-side. There is no `"use server"` directive — the file suffix is the contract.

## Load Functions

Load functions run before the page renders and supply data to the component via the `data` prop.

```ts
// src/routes/invoices/+page.server.ts
import type { PageServerLoad } from './$types';
import { db } from '$lib/db';

export const load: PageServerLoad = async ({ locals, url }) => {
  const session = await locals.auth();
  if (!session) redirect(302, '/login');

  return {
    invoices: await db.invoice.findMany({ where: { userId: session.user.id } }),
  };
};
```

```svelte
<!-- src/routes/invoices/+page.svelte -->
<script lang="ts">
  let { data } = $props();  // Svelte 5 rune syntax
</script>

{#each data.invoices as invoice}
  <div>{invoice.id}</div>
{/each}
```

The `$props()` rune replaces the old `export let data` pattern in Svelte 5.

## Form Actions — No Client JS Required

SvelteKit's form actions handle POST requests without any client-side JavaScript. This is progressive enhancement: the form works with JS disabled, and `enhance` makes it feel like an SPA when JS is available.

```ts
// src/routes/invoices/+page.server.ts
import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';

export const actions: Actions = {
  create: async ({ request, locals }) => {
    const session = await locals.auth();
    const data = await request.formData();
    const amount = Number(data.get('amount'));

    if (isNaN(amount) || amount <= 0) {
      return fail(422, { error: 'Invalid amount' });
    }

    await db.invoice.create({ data: { amount, userId: session.user.id } });
    redirect(302, '/invoices');
  },
};
```

```svelte
<form method="POST" action="?/create" use:enhance>
  <input name="amount" type="number" />
  <button type="submit">Create</button>
</form>
```

`use:enhance` (from `$app/forms`) intercepts the submit, does the POST via `fetch`, and handles the redirect/error response client-side without a full page reload. Remove it and the form still works with a full reload.

## Key Differences from Next.js

**No `useState`** — Svelte reactivity uses `$state()` rune (Svelte 5) or `let` declarations (Svelte 4).

**No `useEffect`** — use `$effect()` rune for side effects that run when reactive values change.

**Reactive declarations with `$derived`** (Svelte 5) or `$:` label (Svelte 4):
```svelte
let count = $state(0);
let doubled = $derived(count * 2);  // Svelte 5
// $: doubled = count * 2;           // Svelte 4
```

**No API routes as separate files** — mutations go through form actions in `+page.server.ts`. REST endpoints live in `+server.ts` files (the equivalent of Next.js Route Handlers).

## adapter-vercel Configuration

```ts
// svelte.config.js
import adapter from '@sveltejs/adapter-vercel';
export default {
  kit: {
    adapter: adapter({
      runtime: 'nodejs22.x',  // or 'edge' for edge functions
    }),
  },
};
```

Individual routes can override to edge runtime with `export const config = { runtime: 'edge' }` in the route file.

## Key Rules

- **Use `+page.server.ts` for all data access and mutations** — never import database clients in `+page.svelte`.
- **Use `fail()` to return validation errors** from actions — throwing an error causes a 500; `fail(422, data)` returns structured error data the component can display.
- **Use `use:enhance` on forms** to get SPA behavior without losing progressive enhancement.
- In Svelte 5, use `$props()`, `$state()`, `$derived()`, `$effect()` runes — the old `export let`, `$:`, and `onMount` patterns still work but are legacy.
- `locals` is the per-request store for auth sessions — populate it in `hooks.server.ts` via `handle()`, read it in every load function and action.

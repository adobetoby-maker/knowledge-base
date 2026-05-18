# Stack Bundle: Nuxt 3 + Supabase

## Overview
The `@nuxtjs/supabase` module removes most of the boilerplate for Supabase integration in Nuxt 3 —
it handles auth session synchronization, provides composables, and enables SSR-safe session access.
Understanding the split between server-rendered context and client-hydration prevents auth state
mismatches that manifest as flash-of-unauthenticated-content.

## Implementation

### Module Setup
```ts
// nuxt.config.ts
export default defineNuxtConfig({
  modules: ['@nuxtjs/supabase'],

  supabase: {
    url: process.env.SUPABASE_URL,
    key: process.env.SUPABASE_KEY,
    serviceKey: process.env.SUPABASE_SERVICE_KEY,  // server only, never exposed
    redirectOptions: {
      login: '/auth/login',
      callback: '/auth/confirm',
      exclude: ['/', '/about', '/blog/*'],  // public routes — no redirect
    },
  },

  runtimeConfig: {
    supabaseServiceKey: process.env.SUPABASE_SERVICE_KEY,  // server-only
    public: {
      supabaseUrl: process.env.SUPABASE_URL,
      supabaseKey: process.env.SUPABASE_KEY,
    },
  },
});
```

### useSupabaseClient() Composable
```ts
// Works in components, pages, composables, plugins
// Returns a Supabase client scoped to the current user session
const supabase = useSupabaseClient();
const user = useSupabaseUser();   // reactive ref — null when not logged in

// In a component
const { data: posts } = await supabase
  .from('posts')
  .select('id, title, created_at')
  .eq('user_id', user.value?.id)
  .order('created_at', { ascending: false });
```

### Server Routes for API
```ts
// server/api/posts.get.ts
import { serverSupabaseClient } from '#supabase/server';

export default defineEventHandler(async (event) => {
  const client = await serverSupabaseClient(event);  // uses session from cookie

  const { data, error } = await client
    .from('posts')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) throw createError({ statusCode: 500, message: error.message });
  return data;
});

// server/api/admin/users.get.ts — service role for admin operations
import { serverSupabaseServiceRole } from '#supabase/server';

export default defineEventHandler(async (event) => {
  const client = serverSupabaseServiceRole(event);  // bypasses RLS

  // Protect this route — service role client should ONLY be used in protected routes
  const user = await serverSupabaseUser(event);
  if (!user || user.role !== 'admin') {
    throw createError({ statusCode: 403 });
  }

  return client.from('users').select('*');
});
```

### SSR-Safe Session Handling
```ts
// pages/dashboard.vue
// @nuxtjs/supabase handles session SSR automatically via cookies
// useSupabaseUser() returns the server-hydrated user on first render — no flash

const user = useSupabaseUser();

// Redirect if not logged in (middleware approach preferred)
// middleware/auth.ts
export default defineNuxtRouteMiddleware(() => {
  const user = useSupabaseUser();
  if (!user.value) {
    return navigateTo('/auth/login');
  }
});
```
```ts
// Apply middleware per-page
definePageMeta({
  middleware: 'auth',
});
```

### Row-Level Security
```sql
-- Always enable RLS on every table
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Users can only read their own posts
CREATE POLICY "Users read own posts" ON posts
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own posts
CREATE POLICY "Users insert own posts" ON posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```
RLS is enforced server-side in PostgreSQL — it cannot be bypassed from the client even if RLS
is not enforced in the application code. The `serviceKey` bypasses RLS — never expose it to the client.

### Nitro for Edge Deployment
```ts
// nuxt.config.ts — deploy to Cloudflare Pages/Workers
export default defineNuxtConfig({
  nitro: {
    preset: 'cloudflare-pages',
    // or: 'vercel-edge', 'netlify-edge', 'aws-lambda'
  },
});
```
```bash
npx nuxi build          # builds for target preset
npx nuxi preview        # test production build locally
```

## Key Rules
- Never import `serverSupabaseServiceRole` in anything that runs client-side — it uses the service key
- `useSupabaseUser()` returns a reactive ref — use `.value` to access the user object
- Route middleware with `useSupabaseUser()` is the correct pattern for protected pages — not page-level conditionals
- Always enable RLS before inserting any real data — adding RLS later to a populated table requires testing all policies
- The `redirectOptions.exclude` list must cover all public routes or unauthenticated users will get redirect loops
- `serverSupabaseClient` uses the user's session (respects RLS); `serverSupabaseServiceRole` bypasses RLS — choose carefully
- Nuxt's `useAsyncData` caches results by key — include user ID in the key for user-specific data to prevent cross-user cache hits

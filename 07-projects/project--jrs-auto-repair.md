# Project: jrs-auto-repair

**Path:** `/Users/drive/jrs-auto-repair/`
**Deployed:** `jrsautorepair.worker-bee.app`
**Stack:** Next.js 16, React 19, Supabase, Vitest
**Client:** Pablo Zaldivar | 417 Main Ave E, Twin Falls, ID | (208) 595-2101
**Tagline:** "Honest work, fair prices, done right the first time. Serving downtown Twin Falls for over 13 years."

## Commands
```bash
npm run dev        # localhost:3000
npm run build
npm run lint
npm run test       # Vitest, all tests
npm run seed       # seed Supabase via scripts/seed.ts
```

## Auth — Two Systems, Never Mix
1. **Admin** (`/admin`) — cookie `admin_session`, signed with `ADMIN_SECRET`. Users in `data/admins.json`. Logic in `lib/adminAuth.ts`.
2. **Portal** (`/portal`) — Supabase JWT. `proxy.ts` refreshes sessions and redirects.

Never import admin auth into portal routes. Never use Supabase session for admin routes.

## Three Supabase Clients
- `lib/supabase/client.ts` — browser only
- `lib/supabase/server.ts` — Server Components / Route Handlers
- `lib/supabase/admin.ts` — service role, bypasses RLS. **Never import client-side.**

## Static Content Pattern
Blog articles → `lib/articles.ts` (TypeScript array, never markdown files)
How-to guides → `lib/howtos.ts`
Business info → `lib/shopInfo.ts` (single source of truth: name, phone, address, hours, services)

Blog route: `/blog` (NOT `/articles`)

## SEO Geo-Targeting
Primary: Twin Falls, ID + Magic Valley (both names together in all content)
Key phrases: `"auto repair Twin Falls ID"`, `"mechanic Magic Valley Idaho"`, `"mechanic near me Twin Falls"`
Surrounding cities: Jerome, Kimberly, Filer, Buhl, Hansen, Wendell, Gooding, Shoshone, Burley, Rupert, Hagerman

## Env Vars
```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
ANTHROPIC_API_KEY           # AI chatbot — uses claude-haiku-4-5
ADMIN_SECRET                # admin session cookie signing
```

## Known Patterns / Gotchas
- `verifyAdminSession` does NOT exist — it was never created. Use the actual adminAuth.ts functions.
- Supabase admin client uses lazy init to avoid build-time crash (missing env vars during build)
- Blog uses ISR — `revalidate: 3600` on article pages
- AI chatbot is claude-haiku-4-5 (not Sonnet) — keep costs low

## Adding a Blog Article
Edit `lib/articles.ts` — add to the array:
```typescript
{
  slug: "url-slug-here",
  title: "Article Title",
  excerpt: "150 char excerpt",
  category: "oil-change" | "brakes" | "tires" | "maintenance" | "engine",
  date: "2026-05-17",
  readTime: "5 min read",
  body: `Full article content in markdown-ish format...`
}
```

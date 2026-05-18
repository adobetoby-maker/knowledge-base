# Stack Bundle: Jr.'s Auto Repair — Full Project Context

## Project Identity

**Client:** Pablo Zaldivar
**Business:** Jr.'s Auto Repair
**Address:** 417 Main Ave E, Twin Falls, ID 83301
**Phone:** (208) 595-2101
**Hours:** Mon–Sat 9AM–5PM
**Rating:** 4.8★ · 146 reviews
**Tagline:** "Honest work, fair prices, done right the first time. Serving downtown Twin Falls for over 13 years."

## Technical Stack

- **Framework:** Next.js 16 + React 19 (App Router)
- **Database:** Supabase (PostgreSQL)
- **Auth:** Two systems (admin cookie + Supabase JWT — never mix)
- **Testing:** Vitest
- **Deployed:** jrsautorepair.worker-bee.app (Vercel)
- **AI:** Anthropic claude-haiku-4-5 (chatbot)

## The Two Auth Systems

**Admin** (`/admin/*`): Cookie-based, `data/admins.json`, `lib/adminAuth.ts`, `verifyAdmin()`
**Portal** (`/portal/*`): Supabase JWT, `supabase.auth.getUser()`

Never use admin auth on portal routes or vice versa.

## Three Supabase Clients

- `lib/supabase/client.ts` — browser
- `lib/supabase/server.ts` — Server Components / Route Handlers
- `lib/supabase/admin.ts` — service role, NEVER client-side

## Content Rules

- Blog lives at `/blog` not `/articles`
- Articles stored in `lib/articles.ts` as TypeScript objects (NOT markdown files)
- Business info: `lib/shopInfo.ts` is the SINGLE source of truth
- How-tos: `lib/howtos.ts`

## SEO Keywords

Primary: `"auto repair Twin Falls ID"`, `"mechanic Magic Valley Idaho"`, `"mechanic near me Twin Falls"`

Surrounding cities to mention: Jerome, Kimberly, Filer, Buhl, Hansen, Wendell, Gooding, Shoshone, Burley, Rupert, Hagerman

## Dev Commands

```bash
cd /Users/drive/jrs-auto-repair
npm run dev          # localhost:3000
npm run build
npm run lint
npm run test         # Vitest, all tests
npx vitest run lib/invoices/calculate.test.ts  # single test file
npm run seed         # seed Supabase via scripts/seed.ts
```

## Env Variables

```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
ANTHROPIC_API_KEY
ADMIN_SECRET
```

## Article Object Structure

```typescript
{
  slug: 'brake-pad-replacement-twin-falls',  // kebab-case, unique
  title: 'Brake Pad Replacement in Twin Falls ID: Cost and Signs',  // 50-60 chars
  excerpt: '150-160 char meta description with keyword',
  category: 'repairs',  // maintenance | repairs | diagnostics | seasonal | buying-guide
  date: '2026-05-18',
  readTime: '5 min read',
  body: `...markdown content...`
}
```

## Known Rules (from corrections-log)

- Use `verifyAdmin` (not `verifyAdminSession` — doesn't exist)
- Use `getUser()` not `getSession()` for security checks
- `lib/adminAuth.ts` contains the admin auth logic
- `params` is a Promise in Next.js 15+: `const { slug } = await params`
- `admin.ts` client NEVER imported in any file that could run client-side

## Chatbot

The chatbot uses Claude Haiku 4.5. The system prompt lives in the chat route handler. It identifies as "Jr.'s Auto Repair assistant" and always directs people to call (208) 595-2101 for appointments.

## Deployment

Vercel auto-deploys from `main` branch push. Preview URLs created for every branch. Env vars set in Vercel dashboard.

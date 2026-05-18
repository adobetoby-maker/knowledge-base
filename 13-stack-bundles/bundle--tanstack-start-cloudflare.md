# Stack Bundle: TanStack Start + Cloudflare Workers (language-lens-elite)

**Use when:** Working on language-lens-elite specifically. This project uses TanStack Start, NOT Next.js.
**Replaces:** project--language-lens-elite.md + skill--cloudflare-workers-expert.md + react--state-management.md

---

## Critical: This Is NOT Next.js

```
Stack: TanStack Start (React Router v7) + Vite + Cloudflare Workers
        via @cloudflare/vite-plugin
Deploy: Cloudflare Pages (not Vercel)

NEVER USE:
  next/image, next/link, next/navigation, next/headers
  useRouter from 'next/navigation'
  App Router file conventions (page.tsx, layout.tsx, loading.tsx)

USE INSTEAD:
  React Router v7 routing (createFileRoute, createRootRoute)
  TanStack Router Link, useNavigate, useParams
  Server functions via createServerFn
```

## Project Structure
```
src/
  routes/
    __root.tsx          ← root layout with all providers
    index.tsx           ← home route
    api.tutor.ts        ← server function (runs on CF Worker)
    api.speak.ts        ← server function
    api.discussion.ts   ← server function
  state/
    app-state.tsx       ← XP, tier, streak, selected language
    auth-state.tsx      ← Supabase auth session
    grammar-state.tsx
    speak-state.tsx
    [etc per domain]
  components/
    tab-registry.ts     ← TabKey → Component mapping
    TabShell.tsx        ← renders active tab
```

## Provider Stack — ORDER MATTERS
In `src/routes/__root.tsx`:
```
AuthProvider
  → AppProvider
    → LibraryProvider
      → NotesProvider
        → GrammarProvider
          → SpeechProvider
            → SpeakProvider
              → TutorProvider
                → MatchProvider
                  → LeaderboardProvider
                    → {children}
```
Do NOT change order. AuthProvider must wrap AppProvider (app state reads auth state).

## Two Tier Systems — Never Mix
```
XP Tier (learning progress):
  Beginner🌱 → Apprentice📖 → Scholar🎓 → Linguist🗣️ → Maestro✦
  Computed from XP in app-state.tsx
  Stored in Supabase profiles table

Rank Tier (multiplayer matchmaking):
  Bronze → Silver → Gold → Platinum → Diamond → Champion → Unreal
  Stored separately, managed in match-state.tsx
```

## Adding a Tab — Two File Changes Required
1. Add `TabKey` union in `src/state/app-state.tsx`:
```typescript
type TabKey = 'reader' | 'kana' | 'grammar' | 'speak' | /* ... */ | 'your-new-tab'
```

2. Add to `TAB_COMPONENTS` in `src/components/tab-registry.ts`:
```typescript
const TAB_COMPONENTS: Record<TabKey, ComponentType> = {
  reader: ParallelReader,
  // ...
  'your-new-tab': YourNewTabComponent,
}
```
TypeScript enforces exhaustiveness — both must match.

## Server Functions (AI calls)
```typescript
// src/routes/api.tutor.ts
import { createServerFn } from '@tanstack/start'
import Anthropic from '@anthropic-ai/sdk'
import { z } from 'zod'

const TutorRequestSchema = z.object({
  message: z.string(),
  language: z.string()
})

export const tutorFn = createServerFn({ method: 'POST' })
  .validator(TutorRequestSchema)
  .handler(async ({ data }) => {
    const client = new Anthropic()
    const response = await client.messages.create({
      model: 'claude-haiku-4-5',
      max_tokens: 1024,
      messages: [{ role: 'user', content: data.message }]
    })
    return { response: response.content[0].type === 'text' ? response.content[0].text : '' }
  })
```

## Supabase Client (Lazy Proxy Pattern)
```typescript
// src/integrations/supabase/client.ts
import { createClient } from '@supabase/supabase-js'

let _client: ReturnType<typeof createClient> | null = null

export function getSupabase() {
  if (!_client) {
    _client = createClient(
      import.meta.env.VITE_SUPABASE_URL,
      import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY
    )
  }
  return _client
}
```
Lazy pattern avoids init errors when env vars aren't available at module load time.

## Env Vars
```
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
VITE_SUPABASE_PROJECT_ID
ANTHROPIC_API_KEY   ← server-side only (Worker env)
```

## Dev and Build
```bash
npm run dev    # Vite dev server with CF Workers runtime emulation
npm run build  # builds for CF Pages
npm run lint   # ESLint
npm run format # Prettier
```

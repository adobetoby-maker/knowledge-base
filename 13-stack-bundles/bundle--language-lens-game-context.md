# Stack Bundle: Language Lens Game Architecture

Load this before working on game features, XP, tabs, or state in language-lens-elite.

## Stack

TanStack Start (NOT Next.js). React Router v7 + Vite + Cloudflare Workers.

Key differences from Next.js:
- Route files: `$slug.tsx` not `[slug].tsx`  
- Env vars: `import.meta.env.VITE_*` not `process.env.NEXT_PUBLIC_*`
- No `'use client'` directive
- Server functions: `createServerFn` not Route Handlers or Server Actions
- Supabase: `VITE_SUPABASE_URL` + `VITE_SUPABASE_PUBLISHABLE_KEY`

## File Structure

```
src/
  routes/
    __root.tsx           → root layout, all providers stacked here
    index.tsx            → / (main app with TabShell)
    api.tutor.ts         → server function for AI tutor
    api.speak.ts         → server function for AI speech eval
    api.discussion.ts    → server function for AI discussion
  state/
    app-state.tsx        → XP, tier, streak, achievements, active tab
    auth-state.tsx       → Supabase auth session
    match-state.tsx      → multiplayer matchmaking
    grammar-state.tsx    → grammar exercises
    speak-state.tsx      → speaking practice
    library-state.tsx    → book library
    notes-state.tsx      → learner notes
    tutor-state.tsx      → AI tutor session
    leaderboard-state.tsx
    speech-state.tsx
  components/
    tab-registry.ts      → maps TabKey → ComponentType
    TabShell.tsx         → renders active tab from app-state
```

## Provider Stack (ORDER MATTERS)

All providers in `src/routes/__root.tsx`:

```tsx
<AuthProvider>
  <AppProvider>
    <LibraryProvider>
      <NotesProvider>
        <GrammarProvider>
          <SpeechProvider>
            <SpeakProvider>
              <TutorProvider>
                <MatchProvider>
                  <LeaderboardProvider>
                    <Outlet />
                  </LeaderboardProvider>
                </MatchProvider>
              </TutorProvider>
            </SpeakProvider>
          </SpeechProvider>
        </GrammarProvider>
      </NotesProvider>
    </LibraryProvider>
  </AppProvider>
</AuthProvider>
```

AuthProvider must be outermost (others may read auth state).

## XP Tier System

Tiers are computed from XP in app-state, not stored separately:

```typescript
type XPTier = 'Beginner' | 'Apprentice' | 'Scholar' | 'Linguist' | 'Maestro'

function computeTier(xp: number): XPTier {
  if (xp < 100) return 'Beginner'
  if (xp < 500) return 'Apprentice'
  if (xp < 2000) return 'Scholar'
  if (xp < 5000) return 'Linguist'
  return 'Maestro'
}

// Tier icons: Beginner🌱 Apprentice📖 Scholar🎓 Linguist🗣️ Maestro✦
```

Completely separate from Match rank tier (Bronze → Champion → Unreal) — stored differently, displayed in different UI contexts.

## Tab System

Adding a tab requires updating BOTH:
1. `TabKey` union type in `src/state/app-state.tsx`
2. `TAB_COMPONENTS` map in `src/components/tab-registry.ts`

```typescript
// app-state.tsx:
type TabKey = 'reader' | 'kana' | 'grammar' | 'speak' | 'discussions' | 'library' | 'notes' | 'tutor' | 'match' | 'leaderboard' | 'dashboard'

// tab-registry.ts:
export const TAB_COMPONENTS: Record<TabKey, ComponentType> = {
  reader: ParallelReader,
  kana: KanaPad,
  grammar: GrammarTab,
  // ... etc — TypeScript enforces exhaustiveness
}
```

## Server Functions

AI features use TanStack Start server functions, not Next.js Server Actions:

```typescript
// src/routes/api.tutor.ts
import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'
import Anthropic from '@anthropic-ai/sdk'

const TutorRequestSchema = z.object({
  message: z.string(),
  language: z.string(),
  level: z.string(),
})

export const tutorChat = createServerFn({ method: 'POST' })
  .validator(TutorRequestSchema)
  .handler(async ({ data }) => {
    const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })
    const response = await anthropic.messages.create({
      model: 'claude-haiku-4-5',
      // ...
    })
    return response.content[0].type === 'text' ? response.content[0].text : ''
  })
```

## Supabase Client Pattern

```typescript
// src/integrations/supabase/client.ts
import { createClient } from '@supabase/supabase-js'

let _client: ReturnType<typeof createClient> | null = null

function getClient() {
  if (_client) return _client
  const url = import.meta.env.VITE_SUPABASE_URL ?? process.env.VITE_SUPABASE_URL
  const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? process.env.VITE_SUPABASE_PUBLISHABLE_KEY
  _client = createClient(url, key)
  return _client
}

export const supabase = new Proxy({} as ReturnType<typeof createClient>, {
  get: (_, prop) => (getClient() as any)[prop],
})
```

The `?? process.env.VITE_*` fallback handles SSR where `import.meta.env` is unavailable.

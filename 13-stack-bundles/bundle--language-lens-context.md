# Stack Bundle: language-lens-elite Context

> Pre-merged context for local models or agents working on language-lens-elite (LinguaLens).
> Load this file instead of reading multiple separate files.

## Project Overview

LinguaLens at `/Users/drive/language-lens-elite`. **NOT Next.js** — TanStack Start (React Router v7 + Vite + Cloudflare Workers).

## Stack Differences vs Next.js

| Next.js | TanStack Start |
|---|---|
| `'use client'` directive | Not used — different pattern |
| `process.env.NEXT_PUBLIC_*` | `import.meta.env.VITE_*` |
| `app/page.tsx` | `src/routes/index.tsx` |
| Route Handlers | TanStack Start server functions |
| `params.slug` | `Route.useParams().slug` or `$slug` in filename |
| `generateStaticParams` | `loader` function |

## Environment Variables

```
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY      # public key (not ANON_KEY naming)
VITE_SUPABASE_PROJECT_ID
ANTHROPIC_API_KEY                  # server-side only (tutor, speak, kana)
```

## Supabase Client

```typescript
// src/integrations/supabase/client.ts
// Uses lazy-proxy pattern to avoid init errors at module load time
// Access: import { supabase } from '@/integrations/supabase/client'
// Uses import.meta.env.VITE_SUPABASE_URL (falls back to process.env for SSR)
```

## Provider Stack (Root Route)

All providers stack at `src/routes/index.tsx` in this order:
```
AuthProvider
  AppProvider
    LibraryProvider
      NotesProvider
        GrammarProvider
          SpeechProvider
            SpeakProvider
              TutorProvider
                MatchProvider
                  LeaderboardProvider
                    {children}
```

## State Architecture

```
src/state/
  app-state.tsx         → XP, tier, streak, achievements, active tab, language/level
  auth-state.tsx        → Supabase auth session
  match-state.tsx       → multiplayer matchmaking, rank tier
  grammar-state.tsx
  speak-state.tsx
  library-state.tsx
  notes-state.tsx
  tutor-state.tsx
  leaderboard-state.tsx
  speech-state.tsx
```

## XP Tier System

```typescript
// src/state/app-state.tsx
// Tiers recomputed from xp on every ADD_XP dispatch
type XPTier = 'Beginner🌱' | 'Apprentice📖' | 'Scholar🎓' | 'Linguist🗣️' | 'Maestro✦'
```

Separate from multiplayer rank tier (Bronze → Silver → Gold → Platinum → Diamond → Champion → Unreal).

## Tab System

```typescript
// src/components/tab-registry.ts
// TypeScript Record<TabKey, ComponentType> — exhaustive
type TabKey = 'reader' | 'kana' | 'grammar' | 'speak' | 'discussions' | 
              'library' | 'notes' | 'tutor' | 'match' | 'leaderboard' | 'dashboard'

// Adding a tab requires BOTH:
// 1. Add to TabKey union in app-state.tsx
// 2. Add to TAB_COMPONENTS in tab-registry.ts
```

## AI Server Functions

```typescript
// src/routes/api.tutor.ts    — Anthropic SDK server function
// src/routes/api.speak.ts    — Anthropic SDK server function
// src/routes/api.discussion.ts — Anthropic SDK server function
// src/fns/kana-convert.functions.ts — kanji conversion via Haiku
```

All AI calls run server-side via TanStack Start server functions (validated with Zod).

## KanaPad

Japanese input system in `src/components/kana/KanaPad.tsx`:
- Pure client-side romaji → hiragana/katakana in `src/lib/romaji-to-kana.ts`
- Kanji conversion via AI server function
- Tab key: `"kana"`

## ParallelReader (Dual-Pane)

```typescript
// src/components/ParallelReader.tsx
// Furigana toggle: 'off' | 'above' | 'inline'
// Persisted to localStorage:
//   lingualens.reader.furigana.v1
//   lingualens.reader.romaja.v1
// Click → word card lookup via ClickableText.tsx
```

## Dev Commands

```bash
# From /Users/drive/language-lens-elite
npm run dev      # Vite dev server (CF Workers runtime)
npm run build
npm run lint     # ESLint
npm run format   # Prettier
```

## Deployment

Deployed via Cloudflare Workers using `@cloudflare/vite-plugin`. Not Vercel. No `next.config.ts`.

## Critical Rules

1. No `'use client'` — TanStack Start has its own client/server model
2. Environment variables are `import.meta.env.VITE_*`, NOT `process.env.NEXT_PUBLIC_*`
3. Route params use `$slug` file naming convention, not `[slug]`
4. AI calls go in server functions, not Route Handlers
5. Supabase client uses lazy-proxy — don't initialize at module level

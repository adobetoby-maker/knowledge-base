# Project: language-lens-elite (LinguaLens)

**Path:** `/Users/drive/language-lens-elite/`
**Deployed:** `language-lens-elite.worker-bee.app`
**Stack:** TanStack Start (React Router v7 + Vite + Cloudflare Workers via @cloudflare/vite-plugin)
**NOT Next.js** — do not apply Next.js patterns here.

## Commands
```bash
npm run dev     # Vite dev server (Cloudflare Workers runtime)
npm run build
npm run lint    # ESLint
npm run format  # Prettier
```

## Provider Stack (ORDER MATTERS)
All providers are stacked at the root route `src/routes/index.tsx` in this exact order:
```
AuthProvider → AppProvider → LibraryProvider → NotesProvider →
GrammarProvider → SpeechProvider → SpeakProvider → TutorProvider →
MatchProvider → LeaderboardProvider
```
If you change the order, context dependencies break. Add new providers to the end unless you understand the dependency graph.

## State Architecture
State lives in `src/state/` — per-domain context, not a global store:
- `app-state.tsx` — XP, XP tier, streak, achievements, notes, active tab, selected language/level
- `auth-state.tsx` — Supabase auth session
- `match-state.tsx` — multiplayer matchmaking + rank tier (separate from XP tier)
- Per-feature: `grammar-state.tsx`, `speak-state.tsx`, `library-state.tsx`, `notes-state.tsx`, `tutor-state.tsx`, `leaderboard-state.tsx`, `speech-state.tsx`

## Two Tier Systems (Do Not Mix)
**XP Tier** (learning progress):
`Beginner🌱 → Apprentice📖 → Scholar🎓 → Linguist🗣️ → Maestro✦`
Recomputed from XP on every ADD_XP dispatch. Stored in Supabase `profiles`.

**Rank Tier** (multiplayer competitive):
`Bronze → Silver → Gold → Platinum → Diamond → Champion → Unreal`
Stored separately. Nothing to do with XP.

## Tab System (Critical Pattern)
`src/components/tab-registry.ts` maps every `TabKey` to a component.
**TypeScript enforces exhaustiveness** — adding a tab requires both:
1. Add to `TabKey` union in `app-state.tsx`
2. Add to `TAB_COMPONENTS` in `tab-registry.ts`

Current tabs: Reader, Kana Pad, Grammar, Speak, Discussions, Library, Notes, Tutor, Match, Leaderboard, Dashboard.

## AI Server Functions
All AI calls run server-side via TanStack Start server functions:
- `api.tutor.ts`, `api.speak.ts`, `api.discussion.ts` — Anthropic SDK, validated with Zod
- `src/fns/kana-convert.functions.ts` — Claude Haiku for kanji conversion

## Supabase Client
`src/integrations/supabase/client.ts` — uses lazy-proxy pattern to avoid init errors at module load.
Env: `VITE_SUPABASE_URL` / `VITE_SUPABASE_PUBLISHABLE_KEY` (falls back to `process.env` for SSR).

## Env Vars
```
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
VITE_SUPABASE_PROJECT_ID
ANTHROPIC_API_KEY    # server-side only: tutor, speak, discussion, kana
```

## Key Gotchas
- This is NOT Next.js. No `app/` directory, no `page.tsx`, no Route Handlers.
- Routes are in `src/routes/` using TanStack Router file-based routing.
- Cloudflare Workers runtime — no Node.js APIs available.
- The `@cloudflare/vite-plugin` makes local dev behave like Workers runtime.

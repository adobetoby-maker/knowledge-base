# ADR: Language Lens Elite — Provider Stack Order is Load-Bearing

**Project:** language-lens-elite
**Path:** `/Users/drive/language-lens-elite/`
**Stack:** TanStack Start (NOT Next.js), Vite, Cloudflare Workers

## This is Not Next.js

The single most important thing to know before touching language-lens-elite: it runs TanStack Start with React Router v7, served by Cloudflare Workers via `@cloudflare/vite-plugin`. It is not Next.js. There is no App Router, no `app/` directory, no Server Components, no `next.config.js`.

Env vars are `import.meta.env.VITE_*` (not `process.env.NEXT_PUBLIC_*`). The dev server is Vite (not Next.js dev server). Deployment is Cloudflare Workers (not Vercel or Next.js edge functions).

The reason for TanStack Start instead of Next.js: Cloudflare Workers have specific constraints around Node.js APIs, and the `@cloudflare/vite-plugin` integration with TanStack Start/React Router v7 is cleaner than the opennextjs adapter for this use case (lots of real-time features, WebSockets, streaming).

## The Provider Stack

All state providers are stacked at the root route (`src/routes/index.tsx`) in a specific order:

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
                    {children}
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

**This order is not arbitrary.** The rules:

1. `AuthProvider` must be outermost — every other provider may read the auth session (user ID for Supabase queries, etc.)
2. `AppProvider` wraps everything because it holds global learner state (XP, tier, streak, active tab, selected language) — providers that need to read or write learner state must be inside it
3. Feature providers (`LibraryProvider`, `NotesProvider`, etc.) are independent of each other but must be inside `AppProvider`
4. `MatchProvider` and `LeaderboardProvider` are innermost because they depend on both auth (for the current user) and app state (for language/level selection)

If you move a provider above one of its dependencies, the app will crash with "cannot read properties of undefined" on the context value.

## Two Tier Systems — Never Conflate Them

There are two completely separate tier/rank systems in this codebase. Mixing them up causes silent data corruption.

**XP Tier** (in `app-state.tsx`):
- Derived from cumulative XP points
- Beginner🌱 → Apprentice📖 → Scholar🎓 → Linguist🗣️ → Maestro✦
- Stored in Supabase `profiles` table
- Recomputed from `xp` on every `ADD_XP` dispatch
- Used in the main learner UI, achievements, and progress tracking

**Match Rank** (in `match-state.tsx`):
- Derived from matchmaking performance
- Bronze → Silver → Gold → Platinum → Diamond → Champion → Unreal
- Stored separately from XP
- Used only in the multiplayer Match tab
- Has no relation to XP accumulation

They live in different context files, different Supabase columns, different UI components. Never use XP tier to gate matchmaking features. Never display match rank in the learner progress UI.

## Tab Registry — Exhaustiveness is Enforced

The tab system uses a `Record<TabKey, ComponentType>` in `src/components/tab-registry.ts`. TypeScript enforces exhaustiveness: if you add a tab key to the `TabKey` union in `app-state.tsx` but don't add it to `TAB_COMPONENTS` in `tab-registry.ts`, it's a type error.

This means: **adding a tab requires two changes, always:**
1. Add to `TabKey` union in `app-state.tsx`
2. Add to `TAB_COMPONENTS` in `tab-registry.ts`

Forget either one and the build fails. This is intentional — it prevents tabs from existing in the system without a component to render.

Current tabs: `Reader`, `KanaPad`, `Grammar`, `Speak`, `Discussions`, `Library`, `Notes`, `Tutor`, `Match`, `Leaderboard`, `Dashboard`.

## Furigana/Romaja Toggle — Three Modes

The reader has a three-mode toggle stored in localStorage:

- `"off"` — no annotations
- `"above"` — floating above the text
- `"inline"` — overlaid on the characters

Storage keys:
- `lingualens.reader.furigana.v1` (Japanese)
- `lingualens.reader.romaja.v1` (Korean)

The `v1` suffix is intentional versioning. If the schema changes, bump to `v2` — don't read stale values from `v1`.

## Supabase Client — Lazy Proxy Pattern

```ts
// src/integrations/supabase/client.ts
let _client: SupabaseClient | null = null;
export function getSupabase() {
  if (!_client) _client = createClient(url, key);
  return _client;
}
```

Why lazy: TanStack Start with Cloudflare Workers initializes modules at Worker startup, not at request time. If Supabase client initialization is eager (at module load), it crashes when env vars aren't available during the Workers startup phase. The lazy proxy defers initialization to the first actual call, by which point the runtime context is fully established.

## AI Server Functions

All Anthropic API calls are server functions in `src/routes/`:
- `api.tutor.ts` — language tutoring responses
- `api.speak.ts` — speech pattern analysis  
- `api.discussion.ts` — discussion thread responses
- `src/fns/kana-convert.functions.ts` — kanji conversion with word-level breakdown (Haiku)

These use TanStack Start's server function pattern, not Next.js Server Actions. They're validated with Zod before the Anthropic call. The kanji converter uses Haiku (cost-sensitive, called frequently). The tutor/speak/discussion use Sonnet (quality-sensitive, called less frequently).

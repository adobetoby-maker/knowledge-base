# Project: manage-worker-bee

**Path:** `/Users/drive/manage-worker-bee/`
**Deployed:** `manage.worker-bee.app`
**Stack:** Next.js 16, Supabase, @xyflow/react
**Purpose:** Internal dashboard — manage client sites, blueprints, credentials, mods pipeline.

## Commands
```bash
npm run dev        # localhost:3000
npm run build
# No lint or test scripts
```

## Auth
Auth is DISABLED in `proxy.ts` — open internal tool, no login required.
Uses single service-role Supabase client (`lib/supabase.ts`) — no SSR cookie variants needed.

## Key Stores

### Blueprint Store (`lib/blueprintStore.ts`)
Reads/writes `{siteId}.json` to Supabase Storage (`blueprints` bucket).
Data model:
```typescript
{
  currentBranch: string,
  branches: Record<string, {
    nodes: Node[],
    edges: Edge[],
    updatedAt: string
  }>,
  summary: string
}
```
Legacy format (flat `{nodes, edges}`) is migrated on read automatically.

### Vault Store (`lib/vaultStore.ts`)
AES-256-GCM encrypted credential store.
Categories: `login | api-key | database | ssh | env | note`
Master password stored encrypted in `vault_session` cookie using `ADMIN_SECRET`.
Any server instance can reconstruct vault without re-login.

### Supabase Client (`lib/supabase.ts`)
Single service-role client. Uses proxy pattern — defers init to avoid build-time crash.
NEVER create a second Supabase client in this project.

## Routes
```
/(dashboard)/sites/           — client site list and detail (blueprint canvas)
/(dashboard)/configurator/    — generates CLAUDE.md + settings.json for new clients
/(dashboard)/vault/           — encrypted credential manager
/(dashboard)/submissions/     — incoming client blueprint submissions
/plan                         — public client blueprint submission form

/api/blueprints/*             — blueprint CRUD
/api/credentials/*            — vault CRUD
/api/blueprint-cleanup        — text normalization / design spec cleanup
/api/blueprint-wizard         — AI blueprint generation/refinement
/api/image-gen                — ComfyUI proxy
/api/mods                     — Pronto mods dispatch pipeline
```

## Mods Pipeline
POST `/api/mods` with:
```typescript
{
  siteId: string,
  modType: "translate" | "remove" | "swap" | "request",
  // translate: targetLanguage, targetLocale
  // remove: removeTerm
  // swap: fromTerm, toTerm
  // request: requestDescription
}
```

## Image Gen API
POST `/api/image-gen`:
```typescript
// Request
{ prompt: string, width?: number, height?: number, steps?: number, checkpoint?: string }
// Response
{ image: "data:image/png;base64,...", filename: string, prompt_id: string }
```

## Blueprint Progress API
```bash
curl -s -X POST https://manage.worker-bee.app/api/blueprints/update \
  -H "x-api-key: 9fd6a40a79137d7fdb4ea7dc97d7c40478af2fae339dc8b25cc4595bd8dd1747" \
  -H "content-type: application/json" \
  -d '{ "siteId": "<UUID>", "nodes": [...], "edges": [...], "summary": "..." }'
```

## Env Vars
```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY   # browser auth fallback only
SUPABASE_SERVICE_ROLE_KEY       # primary — all server DB access
ADMIN_SECRET                    # vault session cookie signing
```

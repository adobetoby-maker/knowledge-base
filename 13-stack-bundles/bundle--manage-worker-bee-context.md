# Stack Bundle: manage-worker-bee — Full Project Context

## What It Is

Internal dashboard for managing client sites and credentials. Not customer-facing. Auth is disabled (open internal tool for Drive/Toby only).

**Path:** `/Users/drive/manage-worker-bee`
**Deployed:** manage.worker-bee.app (Vercel)
**Stack:** Next.js 16, Supabase (service role only), @xyflow/react

## Architecture Rules

- **Single service-role Supabase client** (`lib/supabase.ts`) — no SSR cookie variants needed
- Auth is disabled in `proxy.ts` — all routes are open (internal tool)
- No NEXT_PUBLIC_SUPABASE_ANON_KEY dependency for core functionality

## Key Stores

### blueprintStore.ts
Reads/writes `{siteId}.json` to Supabase Storage (`blueprints` bucket).

Data model:
```typescript
interface Blueprint {
  currentBranch: string
  branches: Record<string, {
    nodes: Node[]    // @xyflow/react nodes
    edges: Edge[]    // @xyflow/react edges
    updatedAt: string
  }>
  summary: string
}
```

Handles legacy migration from flat `{nodes, edges}` format — old files exist without `branches` wrapper.

### vaultStore.ts
AES-256-GCM encrypted credential store. Master password stored encrypted in `vault_session` cookie using `ADMIN_SECRET`.

Categories: `login | api-key | database | ssh | env | note`

The vault can be decrypted by any server instance that has `ADMIN_SECRET` — no re-login needed across sessions.

## Routes

```
/(dashboard)/sites/           ← client site list and detail
/(dashboard)/sites/[id]       ← site detail with blueprint canvas
/(dashboard)/configurator/    ← generates CLAUDE.md + settings.json for new projects
/(dashboard)/vault/           ← encrypted credential manager
/(dashboard)/submissions/     ← incoming client blueprint submissions
/plan                         ← PUBLIC client blueprint submission form
/api/blueprints/*             ← blueprint CRUD
/api/credentials/*            ← vault CRUD
/api/blueprint-cleanup        ← text normalization endpoint
/api/blueprint-wizard         ← AI blueprint generation
/api/image-gen                ← ComfyUI proxy
```

## API Key

The manage-worker-bee API is used by other systems for blueprint updates:
```bash
curl -X POST https://manage.worker-bee.app/api/blueprints/update \
  -H "x-api-key: 9fd6a40a79137d7fdb4ea7dc97d7c40478af2fae339dc8b25cc4595bd8dd1747" \
  -H "content-type: application/json" \
  -d '{"siteId": "...", "nodes": [...], "edges": [...], "summary": "..."}'
```

## Image Generation

ComfyUI proxy at `/api/image-gen`:
```typescript
// Request
POST /api/image-gen
{
  prompt: string
  width?: number
  height?: number
  steps?: number
  checkpoint?: string
}

// Response
{
  image: "data:image/png;base64,...",
  filename: string,
  prompt_id: string
}
```

## Dev Commands

```bash
cd /Users/drive/manage-worker-bee
npm run dev    # localhost:3000
npm run build
# No lint or test scripts
```

## Env Variables

```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY  # used only for browser auth fallback
SUPABASE_SERVICE_ROLE_KEY      # primary — all server DB access
ADMIN_SECRET                   # vault session cookie signing
```

## Supabase Tables

- `sites` — client site registry (id, name, url, siteId for blueprint bucket lookup)
- `vault_items` — encrypted credentials (linked to sites)
- `submissions` — incoming blueprint form submissions

## @xyflow/react Canvas

The blueprint canvas uses React Flow with custom node types. Node state persists to Supabase Storage on explicit save. The canvas is Client Component (`'use client'`), wrapped in a Server Component page that fetches the initial blueprint data.

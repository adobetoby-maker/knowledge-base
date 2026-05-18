# Project: Worker Bee Platform

## Overview

Worker Bee is the deployment and management infrastructure that hosts all client sites. Each client site runs under the `worker-bee.app` domain as a subdomain.

## Architecture

```
worker-bee.app → Cloudflare Pages (static routing)
  ↓
jrs.worker-bee.app      → Vercel (Next.js 16)
manage.worker-bee.app   → Vercel (Next.js 16)
language-lens-elite.worker-bee.app → Cloudflare Workers (TanStack Start + Vite)
silvercreeklogistics.worker-bee.app → Vercel (Next.js 16)
climb-brasil.worker-bee.app  → (if not on custom domain)
```

Each subdomain is a separate project with its own:
- Vercel/Cloudflare deployment
- Supabase project (or shared Supabase with separate schemas)
- Environment variables

## manage.worker-bee.app

The management dashboard for all client sites. Key features:

**Blueprint Canvas** (`@xyflow/react`)
- Sites are represented as node graphs
- Nodes: service modules (Blog, Contact Form, CRM, etc.)
- Edges: data flows between modules
- Branches: named versions of the blueprint (e.g., "phase1", "phase2")
- Storage: `blueprints` bucket in Supabase Storage as `{siteId}.json`

**Vault** (Encrypted Credential Store)
- AES-256-GCM encryption
- Categories: login, api-key, database, ssh, env, note
- Master password stored encrypted in `vault_session` cookie via `ADMIN_SECRET`
- Same master password works across any server instance (server-stateless)

**Configurator**
- Generates `CLAUDE.md` + `settings.json` for new client projects
- Templates: Next.js, WordPress, general
- Output is the bootstrap context for a new Claude Code session on that project

**Sites Table** (Supabase)
```sql
CREATE TABLE sites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  domain text,
  status text DEFAULT 'active',
  tech_stack text,
  notes text,
  created_at timestamptz DEFAULT now()
);
```

**Blueprint Update API**
```bash
curl -X POST https://manage.worker-bee.app/api/blueprints/update \
  -H "x-api-key: 9fd6a40a79137d7fdb4ea7dc97d7c40478af2fae339dc8b25cc4595bd8dd1747" \
  -H "content-type: application/json" \
  -d '{"siteId": "...", "nodes": [...], "edges": [...], "summary": "..."}'
```

Used at the end of significant work sessions to update the project's blueprint in manage.worker-bee.app.

## Supabase Client Pattern (manage-worker-bee)

manage-worker-bee uses a single service-role client — there's no user auth:

```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js'

let _client: ReturnType<typeof createClient> | null = null

export function supabase() {
  if (_client) return _client
  _client = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )
  return _client
}
```

No SSR cookie client needed because there's no user session — all operations are server-to-server.

## Deployment

```bash
# manage-worker-bee:
cd /Users/drive/manage-worker-bee
npm run dev    # localhost:3000
npm run build  # verify before deploying

# Deploy: push to main → Vercel auto-deploys
# No lint or test scripts — verify manually
```

## Image Generation (ComfyUI Proxy)

```typescript
// POST /api/image-gen
// Body: { prompt, width?, height?, steps?, checkpoint? }
// Response: { image: "data:image/png;base64,...", filename, prompt_id }
```

Proxies to a local ComfyUI instance. Used for generating site images, social preview images, etc.

# ADR: manage-worker-bee Architecture — Why It Works the Way It Does

**Project:** manage-worker-bee
**Path:** `/Users/drive/manage-worker-bee/`
**Deployed:** `manage.worker-bee.app`

## What This Tool Actually Is

manage-worker-bee is the internal control panel for managing all client sites. It handles:
- Blueprint canvas (visual site-build flow using @xyflow/react)
- Encrypted credential vault
- Client submissions (public `/plan` form → internal review)
- AI blueprint generation and cleanup
- ComfyUI image generation proxy

It is an internal tool. There is no customer-facing auth. Auth is deliberately disabled in `proxy.ts`.

## Why Auth is Disabled

This was a conscious decision, not an oversight. The tool runs on `manage.worker-bee.app` — not a public URL, not indexed, not linked from anywhere. Access is by URL knowledge only.

Adding Supabase auth would require login sessions, which adds friction for the primary user (Drive/Toby) who uses it dozens of times per day. The credential vault has its own AES-256-GCM encryption with a master password — that's the security layer for sensitive data. The blueprint and site data are internal operational information, not customer PII.

If this ever becomes multi-user or externally facing, auth must be added. Until then, the security model is: URL obscurity + vault encryption for sensitive fields.

## Single Service-Role Supabase Client

Unlike JRS (which has three clients for browser/server/admin contexts), manage-worker-bee uses one client everywhere:

```ts
// lib/supabase.ts
export const supabaseAdmin = new SupabaseClient(url, serviceRoleKey, { ... });
```

Why: there's no end-user browser session to manage. Every operation is an admin operation. The lazy proxy pattern (`if (!_client) _client = new SupabaseClient(...)`) defers initialization to avoid build-time crashes when env vars aren't present during Vercel build.

**Never** add `NEXT_PUBLIC_SUPABASE_ANON_KEY` usage to server routes here. It's set as an env var for historical reasons but the service role key is always correct for this tool.

## Blueprint Store — The Branch Model

The blueprint data model evolved. Understanding both formats is critical.

**Legacy format (flat):**
```json
{ "nodes": [...], "edges": [...] }
```

**Current format (branch model):**
```json
{
  "currentBranch": "main",
  "branches": {
    "main": { "nodes": [...], "edges": [...], "updatedAt": "..." },
    "v2-redesign": { "nodes": [...], "edges": [...], "updatedAt": "..." }
  },
  "summary": "Short description of current state"
}
```

`lib/blueprintStore.ts` handles migration transparently: if it reads a flat format, it wraps it in the branch model with `currentBranch: "main"`. Never write code that assumes the legacy format is gone — old Supabase Storage blobs may still be flat.

The storage key is `{siteId}.json` in the `blueprints` bucket. Reads and writes go through `blueprintStore.ts` exclusively — never write directly to Supabase Storage for blueprints.

## Vault Architecture — Why AES-256-GCM

The vault stores credentials (logins, API keys, database strings, SSH keys, env vars, notes) encrypted at rest.

The encryption chain:
1. User enters a master password on `/vault`
2. Master password is hashed → encryption key
3. All vault entries encrypted with AES-256-GCM using that key
4. The master password is stored **encrypted** in the `vault_session` cookie, signed with `ADMIN_SECRET`

Why store the master password in the cookie at all? So any server instance can reconstruct the vault decryption key without the user re-entering the password on every request. The cookie is HTTP-only, signed, and the master password is itself encrypted (not plaintext in the cookie).

The consequence: if `ADMIN_SECRET` rotates, existing vault sessions break. Users must re-enter the master password. This is acceptable — it's a security property, not a bug.

## `/api/image-gen` — ComfyUI Proxy

This endpoint proxies image generation to a local ComfyUI instance:

```
POST /api/image-gen
{ prompt, width?, height?, steps?, checkpoint? }
→ { image: "data:image/png;base64,...", filename, prompt_id }
```

ComfyUI must be running locally on the expected port. If it's not running, the endpoint returns a 503. This is not a background service — it's a local development tool that requires manual startup.

The image is returned as base64 to avoid needing a separate file upload step. This is fine for the internal use case (generating blueprint mockup images) but would be inappropriate for a customer-facing product.

## The `/plan` → Submission Flow

The public client form at `/plan` accepts blueprint data from clients. Submissions land in the Supabase `submissions` table. The internal dashboard at `/(dashboard)/submissions/` reviews them.

This is an asymmetric flow: the public form uses the anon key (no auth required for submission), the internal review uses the service role client. Never swap these — service role on the public form would be a critical security mistake.

## Blueprint Cleanup and Wizard

Two AI endpoints exist for blueprint processing:

- `/api/blueprint-cleanup` — normalizes and formats raw blueprint text (removes filler, standardizes terminology)
- `/api/blueprint-wizard` — generates or refines a blueprint from a description

Both use Anthropic claude-sonnet-4-6. These are generation tasks requiring reasoning — Haiku would produce noticeably worse blueprint structure.

## The External Blueprint Update API

Other tools can push blueprint updates via:
```
POST https://manage.worker-bee.app/api/blueprints/update
x-api-key: 9fd6a40a79137d7fdb4ea7dc97d7c40478af2fae339dc8b25cc4595bd8dd1747
{ siteId, nodes, edges, summary }
```

This is used at the end of significant work sessions on any tracked project. The siteId is a UUID from the `sites` table. Resolve it with:
```ts
supabaseAdmin.from('sites').select('id,name').eq('name', 'project-name')
```

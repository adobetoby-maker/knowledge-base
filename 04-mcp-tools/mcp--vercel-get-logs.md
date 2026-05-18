# MCP Tool: vercel / get_runtime_logs

**Plugin:** `plugin:vercel:vercel` (Claude.ai Vercel integration)
**Tool name:** `mcp__claude_ai_Vercel__get_runtime_logs`
**What it does:** Retrieves runtime logs from a Vercel deployment. Useful for debugging production errors.

## Parameters
```json
{
  "url": "string (required) — the Vercel deployment URL or production URL",
  "limit": "number (optional) — max log lines to return, default 100"
}
```

## When to Use
- Production API route is returning 500 errors
- Vercel function is timing out
- Need to trace a specific user request
- Environment variable not loading in production
- Function crash without local reproduction

## Companion Tool: get_deployment_build_logs
For build-time errors (next build failed), use this instead:
```javascript
mcp__claude_ai_Vercel__get_deployment_build_logs({ 
  deployment_id: "dpl_xxxxxxxxxxxx" 
})
```

## Getting Deployment ID
```javascript
// List recent deployments to find ID
mcp__claude_ai_Vercel__list_deployments({ 
  project_id: "project-name-or-id",
  limit: 10
})
// Returns deployments with id field: "dpl_xxxxxxxxxxxx"
```

## Log Output Format
Logs come as timestamped entries:
```
2026-05-18T10:23:45.123Z [info] GET /api/users 200 45ms
2026-05-18T10:23:46.456Z [error] TypeError: Cannot read property 'id' of undefined
  at getUserById (src/lib/users.ts:23)
2026-05-18T10:23:46.457Z [error] POST /api/users/profile 500 12ms
```

## Common Issues Found in Logs

### Missing env var
```
[error] SUPABASE_SERVICE_ROLE_KEY is not defined
```
Fix: Add the env var in Vercel dashboard → Project → Settings → Environment Variables.

### Cold start timeout
```
[error] Task timed out after 10.00 seconds
```
Fix: Increase function timeout in vercel.json, or optimize the slow operation.

### Module not found
```
[error] Cannot find module 'some-package'
```
Fix: Package isn't in `dependencies` (only devDependencies). Move it.

## Related Tools
- `mcp__claude_ai_Vercel__get_deployment` — deployment status and metadata
- `mcp__claude_ai_Vercel__list_deployments` — find deployment IDs
- `mcp__claude_ai_Vercel__get_project` — project configuration

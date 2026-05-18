# MCP Tool: vercel / deploy_to_vercel

**Plugin:** `claude.ai Vercel`
**Tool name:** `mcp__claude_ai_Vercel__deploy_to_vercel`
**What it does:** Triggers a deployment to Vercel from the current code state.

## Parameters
```json
{
  "project_name": "string (required) — Vercel project name",
  "environment": "production | preview (optional, default: preview)"
}
```

## Usage
```javascript
// Deploy to preview (safe, non-production)
mcp__claude_ai_Vercel__deploy_to_vercel({
  project_name: "jrs-auto-repair",
  environment: "preview"
})

// Deploy to production (confirm with user first)
mcp__claude_ai_Vercel__deploy_to_vercel({
  project_name: "jrs-auto-repair",
  environment: "production"
})
```

## Before Deploying
Always run these first:
```bash
npm run build     # confirm build passes locally
npm run lint      # no lint errors  
npx tsc --noEmit  # no TypeScript errors
```
If any fail, fix first. Don't deploy broken code.

## Deployment Stages
```
Code pushed → Vercel build triggered → Build logs available → Deployed to URL
```

## Monitoring a Deployment
```javascript
// Get deployment status
mcp__claude_ai_Vercel__list_deployments({
  project_id: "project-name",
  limit: 1
})
// Returns: [{ id, url, state, createdAt }]

// Watch build logs
mcp__claude_ai_Vercel__get_deployment_build_logs({
  deployment_id: "dpl_xxxxxxxxxxxx"
})
```

## Deployment States
```
QUEUED      → in queue, not started
BUILDING    → build running
READY       → deployed successfully
ERROR       → build or runtime error
CANCELED    → canceled before completion
```

## Preview vs Production
```
Preview:    unique URL per deployment, safe to test, no traffic impact
Production: replaces the live site — confirms with main domain

DEFAULT: always deploy to preview first
PRODUCTION: only when explicitly requested by user
```

## Rollback
If production deployment causes issues:
```javascript
// List recent deployments
mcp__claude_ai_Vercel__list_deployments({ project_id: "...", limit: 5 })

// Promote an older deployment to production via Vercel dashboard
// Or: git revert + redeploy
```

## Environment Variables
Changes to env vars don't take effect until redeployed.
After changing an env var in Vercel dashboard → trigger a new deployment.

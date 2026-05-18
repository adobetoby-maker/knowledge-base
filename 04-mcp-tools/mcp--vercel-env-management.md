# Vercel Environment Variable Management via MCP

## What the Vercel MCP Provides

The Vercel MCP (`mcp__claude_ai_Vercel__*`) provides access to Vercel projects including environment variables, deployment status, logs, and build information.

## Getting a Project

```
mcp__claude_ai_Vercel__get_project
{
  "projectId": "project-name-or-id"
}
```

## Listing Deployments

```
mcp__claude_ai_Vercel__list_deployments
{
  "projectId": "jrs-auto-repair"
}
```

## Getting Deployment Logs

For debugging failed builds:
```
mcp__claude_ai_Vercel__get_deployment_build_logs
{
  "deploymentId": "dpl_xxx"
}
```

## Getting Runtime Logs

For debugging runtime errors in production:
```
mcp__claude_ai_Vercel__get_runtime_logs
{
  "projectId": "jrs-auto-repair",
  "since": "2026-05-18T00:00:00Z"
}
```

## Deploying to Vercel

```
mcp__claude_ai_Vercel__deploy_to_vercel
{
  "projectId": "project-name",
  "ref": "main"
}
```

## Checking Domain Status

```
mcp__claude_ai_Vercel__check_domain_availability_and_price
{
  "domain": "jrsautorepair.com"
}
```

## Searching Vercel Documentation

```
mcp__claude_ai_Vercel__search_vercel_documentation
{
  "query": "environment variables preview deployments"
}
```

## Vercel Project Structure (for the Projects in This Stack)

| Project | Vercel Project ID | Branch |
|---|---|---|
| jrs-auto-repair | jrs-auto-repair | main |
| manage-worker-bee | manage-worker-bee | main |
| silver-creek-logistics | silver-creek-logistics | main |
| orthobiologic-pathways | orthobiologicpathways | main |
| tobyandertonmd | tobyandertonmd | main |

Note: `language-lens-elite` and `climb-*` sites deploy via Cloudflare Workers, not Vercel.

## Environment Variables Checklist

Before deploying a new feature, verify these are set in Vercel:

For jrs-auto-repair:
```
NEXT_PUBLIC_SUPABASE_URL ✓
NEXT_PUBLIC_SUPABASE_ANON_KEY ✓
SUPABASE_SERVICE_ROLE_KEY ✓
ADMIN_SECRET ✓
ANTHROPIC_API_KEY ✓
```

For silver-creek-logistics:
```
NEXT_PUBLIC_SUPABASE_URL ✓
NEXT_PUBLIC_SUPABASE_ANON_KEY ✓
SUPABASE_SERVICE_ROLE_KEY ✓
ADMIN_SECRET ✓
ANTHROPIC_API_KEY ✓
CRON_SECRET ✓
GMAIL_USER ✓
GMAIL_APP_PASSWORD ✓
TWILIO_ACCOUNT_SID ✓
TWILIO_AUTH_TOKEN ✓
TWILIO_FROM ✓
TWILIO_DISPATCH_PHONES ✓
QB_CLIENT_ID ✓
QB_CLIENT_SECRET ✓
QB_REDIRECT_URI ✓
QB_ENVIRONMENT ✓
```

## Common Deployment Issues

**Build fails with "module not found"**: env var missing from Vercel but present in `.env.local`
→ Check Vercel project settings → Environment Variables → Production

**`NEXT_PUBLIC_*` change not reflected**: these are baked at build time
→ Trigger a new deployment after changing them

**Runtime error on `/api/...`**: function timeout or missing env var
→ Check runtime logs with get_runtime_logs MCP tool

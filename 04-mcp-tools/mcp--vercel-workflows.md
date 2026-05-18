# MCP: Vercel — Common Workflows

## Tool Reference

```
list_projects
get_project(project_id_or_name)
list_deployments(project_id, limit)
get_deployment(deployment_id)
get_deployment_build_logs(deployment_id)
get_runtime_logs(project_id, deployment_id)
deploy_to_vercel(project_path, project_name, team_id)
list_teams
```

## Deployment Diagnosis Workflow

When a deployment fails or behaves unexpectedly:

1. `list_deployments(project_id, 5)` — get recent deployment IDs
2. `get_deployment(deployment_id)` — check status, readyState, errorMessage
3. `get_deployment_build_logs(deployment_id)` — see build output and errors
4. `get_runtime_logs(project_id, deployment_id)` — see runtime errors after deploy

## Common Build Log Patterns

**Type error:**
```
Type error: Type 'string' is not assignable to type 'Promise<{ slug: string }>'
```
→ params is a Promise in Next.js 15+. Fix: `const { slug } = await params`

**Module not found:**
```
Module not found: Can't resolve '@/components/Button'
```
→ Case sensitivity on Linux. Check actual filename casing.

**Missing env var:**
```
Error: NEXT_PUBLIC_SUPABASE_URL is not defined
```
→ Env var not added to Vercel project settings. Add it and redeploy.

## Checking Project Configuration

```
get_project("jrs-auto-repair")
```

Returns:
- Framework detection (next, tanstack-start, etc.)
- Build command
- Output directory
- Root directory (for monorepos)
- Node.js version
- Environment variables (names only, not values)

## Toolbar and Preview Deployments

```
list_toolbar_threads(project_id)           -- UI feedback threads
get_toolbar_thread(thread_id)              -- specific thread details
reply_to_toolbar_thread(thread_id, text)   -- respond to feedback
```

Vercel Toolbar threads appear when reviewers leave feedback on preview deployments. Check these before declaring a feature complete.

## Deploy from Code

```
deploy_to_vercel(
  project_path="/Users/drive/jrs-auto-repair",
  project_name="jrs-auto-repair",
  team_id="team_xxx"
)
```

This triggers a deployment from the local project. Only use when you have made changes that need to be deployed immediately. For normal workflow, push to git and let CI deploy.

## Runtime Log Analysis

```
get_runtime_logs(project_id, deployment_id)
```

Look for:
- `500` errors with stack traces
- `FUNCTION_INVOCATION_TIMEOUT` → function exceeded time limit
- `FUNCTION_INVOCATION_FAILED` → unhandled exception
- Supabase errors → RLS, missing env vars, connection issues

## Vercel Environment Variables

Vercel has three environments: Production, Preview, Development.

Add all required env vars to Production + Preview. Development is for local `vercel dev` usage.

`NEXT_PUBLIC_*` variables are baked into the JavaScript bundle at build time. Changing them requires a new deployment — they cannot be hot-updated.

## Project URL Patterns

- Production: `project-name.vercel.app` or custom domain
- Preview: `project-name-git-branch-name-team.vercel.app`
- Build preview: Vercel generates a URL for each commit

Use preview URLs for testing before merging to main. Share with clients for review.

## Searching Vercel Docs

```
search_vercel_documentation("edge functions cache headers")
```

Searches the official Vercel documentation. Use when encountering framework behavior or configuration questions.

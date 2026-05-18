# MCP: Vercel Preview Deployment Inspection

## When to Use

After a push or PR, use Vercel MCP tools to:
- Find the preview deployment URL
- Check if build succeeded or failed
- Read build logs for TypeScript or compilation errors
- Check runtime logs for server errors during testing

## Get Latest Deployment for a Branch

```typescript
// mcp__claude_ai_Vercel__list_deployments
// Parameters:
{
  app: "jrs-auto-repair",  // project name in Vercel
  limit: 5,
  target: "preview"        // "preview" or "production"
}
// Returns: array of deployments with url, state, createdAt, meta.githubCommitRef
```

Filter by branch name in the `meta.githubCommitRef` field.

## Check Deployment Status

```typescript
// mcp__claude_ai_Vercel__get_deployment
{
  deploymentIdOrUrl: "dpl_xxx"  // or the deployment URL
}
// Returns: { state: "READY" | "ERROR" | "BUILDING" | "QUEUED", ... }
```

States:
- `QUEUED` — waiting to build
- `BUILDING` — in progress
- `READY` — deployed successfully
- `ERROR` — build or deployment failed

## Read Build Logs (On Error)

```typescript
// mcp__claude_ai_Vercel__get_deployment_build_logs
{
  deploymentId: "dpl_xxx"
}
// Returns: log lines from the build process
// Contains: npm install, Next.js build output, TypeScript errors
```

Look for: `Type error:`, `Error:`, `Build failed` in the logs.

## Read Runtime Logs

```typescript
// mcp__claude_ai_Vercel__get_runtime_logs
{
  projectId: "prj_xxx",
  deploymentId: "dpl_xxx"  // optional — filter to specific deployment
}
// Returns: server-side logs from function invocations
```

Use after testing the preview URL to see Server Component errors, API route exceptions, and auth failures.

## Get Project Info (IDs)

```typescript
// mcp__claude_ai_Vercel__get_project
{
  projectId: "jrs-auto-repair"  // can use project name or ID
}
// Returns: { id, name, framework, defaultBranch, latestDeployments }
```

## Project IDs for This Workspace

From CLAUDE.md context, the projects are:
- `jrs-auto-repair` — deployed at jrsautorepair.worker-bee.app
- `manage-worker-bee` — manage.worker-bee.app
- `language-lens-elite` — language-lens-elite.worker-bee.app
- `silver-creek-logistics` — silvercreeklogistics.worker-bee.app
- `orthobiologic-pathways` — orthobiologicpathways.com
- `tobyandertonmd` — tobyandertonmd.vercel.app

## Workflow: Debug a Failed Preview

1. `list_deployments` with the project name → find the failing deployment ID
2. `get_deployment` with ID → confirm state is `ERROR`
3. `get_deployment_build_logs` → read TypeScript/build errors
4. Fix the error in code
5. Push — Vercel auto-triggers new deployment
6. `list_deployments` again → verify new deployment is `READY`

## Check Production vs Preview

```typescript
// mcp__claude_ai_Vercel__list_deployments
{
  app: "jrs-auto-repair",
  target: "production",  // last production deployment
  limit: 1
}
```

Production deployment: the one serving your main domain. Preview: per-branch/PR.

## Access Vercel URL (Browser Fetch)

```typescript
// mcp__claude_ai_Vercel__web_fetch_vercel_url
{
  url: "https://jrs-auto-repair-git-feature-xyz.vercel.app/api/health"
}
// Fetches the URL with Vercel auth — can access password-protected preview URLs
```

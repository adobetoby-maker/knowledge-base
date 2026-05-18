# MCP: Vercel Project Management

## Tool Reference

| Tool | Purpose |
|---|---|
| `list_projects` | List all projects in the Vercel account |
| `get_project` | Get details for a specific project |
| `list_deployments` | List recent deployments with status |
| `get_deployment` | Get details and status of one deployment |
| `get_deployment_build_logs` | Read build output for debugging |
| `get_runtime_logs` | Read function logs for a deployment |
| `get_project_url` | Get the production URL for a project |
| `deploy_to_vercel` | Trigger a new deployment |

## Finding a Project

```
list_projects
→ Returns all projects with their IDs and latest deployment info
→ Note the project ID for subsequent calls

get_project("jrs-auto-repair")
→ Returns: projectId, name, framework, domains, env vars (names only, not values), gitRepo
```

## Checking Deployment Status

```
list_deployments({
  projectId: "prj_xxx",
  limit: 5
})
→ Returns: url, state (READY | ERROR | BUILDING | QUEUED), createdAt, branch

State meanings:
- QUEUED: waiting to start
- BUILDING: currently building
- READY: deployed and live
- ERROR: build or deploy failed
```

## Debugging a Failed Build

```
1. get_deployment({ deploymentId: "dpl_xxx" })
   → Check: readyState, errorCode, errorMessage

2. get_deployment_build_logs({ deploymentId: "dpl_xxx" })
   → Full build output — look for the first ERROR line
   → Common: missing env var, type error, lint error, missing dependency
```

## Reading Runtime Logs

For deployed function errors (500s, thrown exceptions):

```
get_runtime_logs({
  deploymentId: "dpl_xxx",
  since: "1h"  // last hour
})
→ Returns: timestamp, level (error/info), message, requestPath
```

Look for:
- `Error: Cannot find module` — missing dependency
- `TypeError: Cannot read properties of undefined` — null check issue
- `500 Internal Server Error` + stack trace — uncaught error in Route Handler

## Inspecting Environment Variables

```
get_project({ projectId: "prj_xxx" })
→ env field lists variable names (NOT values for security)
→ Verify a variable is set without seeing the value
```

To check if a specific variable is present:
```
The env list should include:
- NEXT_PUBLIC_SUPABASE_URL
- NEXT_PUBLIC_SUPABASE_ANON_KEY
- SUPABASE_SERVICE_ROLE_KEY
- ANTHROPIC_API_KEY
```

Variables not in the list need to be added via Vercel dashboard → Settings → Environment Variables.

## Vercel MCP Auth

The Vercel MCP requires authentication. If tools return auth errors:

```
Use mcp__plugin_vercel_vercel__authenticate
→ Opens OAuth flow
→ Copy the URL shown and open in browser
→ After approval, use mcp__plugin_vercel_vercel__complete_authentication
```

## Project URLs

```
get_project_url({ projectId: "prj_xxx" })
→ Returns: https://jrs-auto-repair.vercel.app (production URL)

For custom domains, check:
get_project({ projectId: "prj_xxx" })
→ domains field: ["jrsautorepair.worker-bee.app", "www.jrsautorepair.com"]
```

## Deployment Workflow

When a deployment fails:
1. `list_deployments` → find the failed deployment ID
2. `get_deployment_build_logs` → read the build error
3. Fix the issue locally
4. Commit and push → Vercel auto-deploys
5. `list_deployments` → confirm new deployment is READY

When runtime errors occur:
1. `get_runtime_logs` → find the error
2. Identify the endpoint or component throwing
3. Fix the code
4. Re-deploy

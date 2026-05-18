# MCP: Vercel Deployment Tools

## Overview
The Vercel MCP tools let you deploy, inspect, and debug projects without leaving the assistant context. The primary value is correlating a deploy failure with its build logs and environment in one session—no browser tab switching. Always confirm the project ID via `get_project` before any destructive operation; project names are not globally unique but IDs are.

## Core Tools

| Tool | When to Use |
|---|---|
| `get_project` | Confirm project ID and current settings before deploy |
| `list_deployments` | Find the most recent deployment for a branch |
| `deploy_to_vercel` | Trigger a deployment programmatically |
| `get_deployment` | Check deployment status (BUILDING, READY, ERROR) |
| `get_deployment_build_logs` | Debug build failures—TypeScript errors, missing deps |
| `get_runtime_logs` | Debug runtime errors—crashed API routes, env var issues |

## Workflow: Deploy and Verify
```
1. get_project(name: "my-project")
   → confirm id, framework, rootDirectory

2. deploy_to_vercel(projectId: "prj_xxx", ref: "main")
   → returns deploymentId: "dpl_yyy"

3. get_deployment(deploymentId: "dpl_yyy")
   → poll until state === "READY" or "ERROR"

4. If ERROR:
   get_deployment_build_logs(deploymentId: "dpl_yyy")
   → scan for: "Type error", "Module not found", "Cannot find module"
```

## Workflow: Debug a Runtime Error
```
1. list_deployments(projectId: "prj_xxx", limit: 5)
   → find the deployment that went live around the incident time

2. get_runtime_logs(deploymentId: "dpl_yyy", since: "2026-05-18T10:00:00Z")
   → look for: unhandled promise rejections, env var undefined errors,
     cold start timeouts, function size limit exceeded
```

## Common Build Failure Patterns
```
"Type error: Property 'X' does not exist on type 'Y'"
→ TypeScript error; fix types locally, push again

"Cannot find module '@/components/X'"
→ Case-sensitive import on Linux build server vs macOS dev; fix casing

"Error: Function payload size limit exceeded"
→ Node modules bundled into function; use next.config serverExternalPackages

"NEXT_PUBLIC_X is not defined"
→ Env var not set in Vercel project settings for the target environment
```

## Key Rules
- **`get_project` first** — verifies the project ID before deploying; names can collide across teams.
- **`get_deployment_build_logs` for build errors** — build failures are in build logs, not runtime logs.
- **`get_runtime_logs` for production errors** — 500 errors, crashes, and env var issues appear here.
- **`list_deployments` to find incident-era deployment** — correlate a user-reported time with a specific deployment.
- **Deploy branch, not main directly** — use `ref` parameter to deploy a feature branch for preview first.

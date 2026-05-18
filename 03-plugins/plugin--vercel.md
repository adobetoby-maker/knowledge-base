# Plugin: vercel@claude-plugins-official

**What it provides:** Vercel platform access — deployments, logs, projects, documentation, toolbar comments.
**When to reach for it:** Debugging production issues, checking deploy status, reading runtime errors, searching Vercel docs.

## Key Skills

| Skill | When to Use |
|-------|-------------|
| `vercel:deploy` | Deploy current project to Vercel production |
| `vercel:status` | Check recent deployments, current status |
| `vercel:env` | Manage environment variables |
| `vercel:bootstrap` | Set up a new Vercel project from scratch |
| `vercel:nextjs` | Next.js-specific Vercel patterns |
| `vercel:ai-sdk` | AI SDK patterns with Vercel |
| `vercel:runtime-cache` | Cache strategy guidance |
| `vercel:routing-middleware` | Middleware and routing configuration |
| `vercel:vercel-functions` | Serverless function configuration |
| `vercel:deployments-cicd` | CI/CD pipeline setup |
| `vercel:vercel-cli` | CLI usage patterns |
| `vercel:knowledge-update` | Latest Vercel platform changes (read when unsure about current features) |

## Key MCP Tools

### Deployments
- `list_deployments` — recent deploys for a project, with status
- `get_deployment` — details of a specific deployment
- `get_deployment_build_logs` — build output for a failed deploy
- `get_runtime_logs` — live/recent runtime errors in production

### Projects
- `list_projects` — all projects in your team
- `get_project` — project config, framework, build settings
- `list_teams` — your Vercel teams

### Documentation
- `search_vercel_documentation` — search Vercel docs directly. Use before guessing.

### Toolbar
- `list_toolbar_threads`, `get_toolbar_thread` — view toolbar comments on a deployment
- `reply_to_toolbar_thread` — respond to comments

## Common Workflows

**Production error investigation:**
```
1. list_deployments → get current deployment ID
2. get_runtime_logs → find the error
3. get_deployment_build_logs → if it's a build failure
4. Fix locally → push branch → check preview deployment
```

**New project setup:**
```
Skill("vercel:bootstrap") → walks through project creation
Then: vercel env pull → get env vars locally
```

**Check if a deployment is healthy:**
```
mcp__claude_ai_Vercel__list_deployments({ projectId: "..." })
→ status: "READY" = good, "ERROR" = failed, "BUILDING" = in progress
```

## Schema Loading
```javascript
ToolSearch("select:mcp__claude_ai_Vercel__get_runtime_logs,mcp__claude_ai_Vercel__list_deployments")
```

## Important Context (2026)
- Fluid Compute is the default (replaces Edge Functions for most use cases)
- Node.js 24 LTS is the default runtime
- Default function timeout: 300s
- `vercel.ts` replaces `vercel.json` for typed config
- Vercel Postgres and KV are gone — use Marketplace integrations

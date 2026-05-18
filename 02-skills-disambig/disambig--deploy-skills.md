# Disambiguation — Deploy and Ship Skills

**Problem:** Multiple overlapping deploy/ship paths. Wrong choice wastes time or breaks things.

## The Options

| Skill / Tool | What It Does |
|-------------|-------------|
| `/ship` (gstack) | Full deploy flow: review + PR + merge. Runs checks before pushing. |
| `/vercel-deployment` | Deep Vercel-specific guidance: build config, env vars, domains, functions. |
| `/vercel-automation` | Automates Vercel CLI operations: project setup, env management, deploy triggers. |
| `/vercel:deploy` | Vercel plugin deploy skill — runs `vercel --prod` with proper config. |
| `/vercel:status` | Check current deployment status, recent deployments, build logs. |
| `/setup-deploy` | First-time project deploy setup: wires up CI/CD, env vars, Vercel project. |
| `/deployment-validation-config-validate` | Validates deployment config before deploying — catches misconfigs. |
| `/deployment-engineer` | Full deployment pipeline design: CI/CD, rollback strategy, health checks. |
| `Vercel MCP tools` | Direct API: `list_deployments`, `get_deployment`, `get_runtime_logs`, `get_build_logs` |

## Quick Decision Tree
```
First time deploying a project → /setup-deploy
Normal "deploy this to prod" → /ship or /vercel:deploy
Something broke in production → Vercel MCP get_runtime_logs → /investigate
Vercel build failing → Vercel MCP get_deployment_build_logs
Setting up env vars → /vercel:env or /vercel-automation
Checking if deploy succeeded → /vercel:status or Vercel MCP list_deployments
CI/CD pipeline design → /deployment-engineer
```

## The Safe Deploy Sequence
1. Run build locally: `npm run build`
2. Check for type errors: `npx tsc --noEmit`
3. Run lint: `npm run lint`
4. Commit to a branch (not main)
5. Push branch — Vercel creates preview deployment automatically
6. Check preview URL
7. Merge to main — triggers production deploy
8. Verify with `/vercel:status`

## Vercel MCP — Key Tools
Load schema first: `ToolSearch("select:mcp__claude_ai_Vercel__get_runtime_logs")`
```
mcp__claude_ai_Vercel__list_deployments({ projectId: "..." })
mcp__claude_ai_Vercel__get_deployment({ deploymentId: "..." })
mcp__claude_ai_Vercel__get_runtime_logs({ deploymentId: "..." })
mcp__claude_ai_Vercel__get_deployment_build_logs({ deploymentId: "..." })
```

## Anti-Pattern
Pushing directly to main to "fix" a broken build.
If main is already broken, this makes it harder to track what changed.
Branch → fix → preview → merge.

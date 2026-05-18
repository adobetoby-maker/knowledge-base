# Disambiguation — Agent Types

**Problem:** 15+ agent types available via the Agent tool. Most sessions use the wrong one or default to `claude` for everything.

## The Agent Types and Their Superpower

| Agent Type | When to Use |
|------------|-------------|
| `Explore` | Find files, grep for symbols, answer "where is X defined?" Read-only. Fast. Use before coding. |
| `Plan` | Design implementation strategy, identify critical files, architectural tradeoffs. Does NOT write code. |
| `feature-dev:code-explorer` | Deep analysis of how an existing feature works. Traces execution paths. |
| `feature-dev:code-architect` | Design a new feature architecture based on existing codebase patterns. |
| `feature-dev:code-reviewer` | Review a specific feature for bugs, security, conventions. |
| `coderabbit:code-reviewer` | Thorough PR-style review with inline comments. |
| `vercel:ai-architect` | AI/ML feature architecture on Vercel — AI SDK, streaming, agents. |
| `vercel:deployment-expert` | CI/CD, preview URLs, production rollbacks, env vars. |
| `vercel:performance-optimizer` | Core Web Vitals, rendering strategies, bundle size. |
| `pr-review-toolkit:code-reviewer` | Review for style guide, conventions, project patterns. |
| `pr-review-toolkit:silent-failure-hunter` | Find silent errors, swallowed exceptions, bad fallbacks. |
| `pr-review-toolkit:type-design-analyzer` | TypeScript type quality — encapsulation, invariants. |
| `claude` (default) | General tasks that don't fit a specialized type. |
| `general-purpose` | Research, multi-step tasks, codebase exploration that spans many queries. |

## Quick Decision Tree
```
"Where is X in the codebase?" → Explore
"How should I build X?" → Plan or feature-dev:code-architect
"How does existing X work?" → feature-dev:code-explorer
"Review what I just wrote" → feature-dev:code-reviewer
"Full PR review before merge" → coderabbit:code-reviewer
"Why is this Vercel deploy slow?" → vercel:performance-optimizer
"Set up CI/CD" → vercel:deployment-expert
"Find hidden bugs in error handling" → pr-review-toolkit:silent-failure-hunter
"Research topic X across the web" → general-purpose
```

## Agent Tool Syntax
```javascript
// Read-only research — never writes files
Agent({ subagent_type: "Explore", description: "Find auth middleware", prompt: "..." })

// Architecture planning
Agent({ subagent_type: "Plan", description: "Plan feature X", prompt: "..." })

// Parallel research (send all at once)
Agent({ subagent_type: "Explore", prompt: "Find all Supabase client usage" })
Agent({ subagent_type: "Explore", prompt: "Find all admin auth routes" })

// Specialized review
Agent({ subagent_type: "feature-dev:code-reviewer", prompt: "Review this feature..." })
```

## Key Constraint
Explore agent: cannot write files — research only.
Plan agent: cannot write files — design only.
All others: can read and write.

## Haiku Routing for Agents
Mechanical research tasks can use cheaper models:
```javascript
Agent({ subagent_type: "Explore", model: "haiku", prompt: "List all .env variables used" })
```

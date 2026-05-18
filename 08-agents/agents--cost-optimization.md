# Agent Cost Optimization

**When:** Using the Agent tool frequently or running overnight batch operations.
**Rule:** Model selection is the biggest cost lever. Haiku costs ~1/10 of Sonnet. Route mechanical tasks to Haiku and reclaim that budget for complex reasoning.

## Cost Tiers (approximate relative cost)
```
Haiku 4.5     — 1x   (baseline)
Sonnet 4.6    — 10x
Opus 4.7      — 100x
```

## Haiku Agent Tasks — Always Safe
```typescript
// File operations
Agent({ model: "haiku", prompt: "Rename all .js files to .ts in src/utils/" })
Agent({ model: "haiku", prompt: "Add 'export' keyword to all functions in lib/" })

// String replacements
Agent({ model: "haiku", prompt: "Replace 'http:' with 'https:' in all config files" })
Agent({ model: "haiku", prompt: "Update all imports from '@/components/old' to '@/components/ui'" })

// Mechanical generation
Agent({ model: "haiku", prompt: "Generate TypeScript interfaces for these 5 JSON schemas: ..." })
Agent({ model: "haiku", prompt: "Write CSS for these 8 utility classes: ..." })

// Git operations
Agent({ model: "haiku", prompt: "Stage all .ts files and create a commit message for these changes" })

// Build/lint tasks
Agent({ model: "haiku", prompt: "Run npm run lint --fix and report what was changed" })
```

## Sonnet Agent Tasks — Default for Code Work
```typescript
// Architecture decisions
Agent({ prompt: "Design the data model for a multi-tenant SaaS with orgs, users, and billing" })

// Debugging
Agent({ prompt: "The auth system is returning null for valid sessions. Trace the issue." })

// Multi-file features
Agent({ prompt: "Add a dashboard page that shows invoice statistics with charts" })

// Content writing
Agent({ prompt: "Write a 1200-word SEO article about brake maintenance for Twin Falls drivers" })
```

## Opus Agent Tasks — Use Sparingly
```typescript
// Only for high-stakes decisions
Agent({ model: "opus", prompt: "Review our entire auth architecture and identify security risks" })

// Complex product decisions
Agent({ model: "opus", prompt: "Design a pricing strategy for this SaaS product" })
```

## Context Window Cost
Context tokens cost money too. When spawning agents:
- Keep the prompt focused — don't include full file contents unless necessary
- Pass file paths, not file contents, when the agent can read them
- Use stack bundles for local models instead of 10 individual files
- Summarize prior context rather than repeating verbatim

## Parallel vs Sequential — Time vs Cost
```
Parallel: 3 Haiku agents simultaneously = 3x Haiku cost, 1x time
Sequential: 1 Haiku agent run 3 times = 3x Haiku cost, 3x time

→ Always prefer parallel for independent tasks
→ Parallel Haiku is cheaper than sequential Sonnet for the same output
```

## The 80/20 Rule for Model Routing
```
80% of agent tasks: file edits, research, generation → Haiku
15% of agent tasks: reasoning, architecture, debugging → Sonnet
5% of agent tasks: strategic decisions, security audits → Opus
```

## Cost Per Run Patterns
Typical costs (approximate, scale with tokens):
```
"Rename 50 files"              → Haiku, ~50 tokens/file → very cheap
"Write 10 blog posts"          → Haiku, ~1000 tokens/post → cheap
"Architect new feature"        → Sonnet, ~5000 tokens → moderate
"Full codebase security audit" → Opus + Sonnet agents → expensive, deliberate use
```

## Monitoring Cost
Use `ruflo-cost-tracker:cost-analyst` to track token usage across sessions:
```
/ruflo-cost-tracker:ruflo-cost
```

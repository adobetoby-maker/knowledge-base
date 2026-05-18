# When to Spawn an Agent vs Do It Inline

**When:** Deciding whether a task needs an Agent tool call or can be done directly.
**Rule:** Spawn an agent when the task needs deep codebase exploration, would consume too much of your context, or benefits from specialization. Do it inline for simple, targeted operations.

## Spawn an Agent When

**The work is research-heavy:**
- "Find all places in the codebase that use Supabase admin client"
- "Understand how the blueprint store works before I modify it"
- The task needs to read 5+ files to answer a question

**The work benefits from specialization:**
- Code review → `feature-dev:code-reviewer`
- Architecture design → `feature-dev:code-architect` or `Plan`
- PR review → `coderabbit:code-reviewer`
- Deployment issues → `vercel:deployment-expert`

**The work is independent and parallel:**
- Two separate features can be built simultaneously
- Research in multiple areas at once
- Multiple files that don't interact

**The context cost is too high:**
- A full codebase audit would flood your context with file contents
- Deep investigation of a bug spanning many files
- Anything that would need to read more than ~10 files

## Do It Inline When

**It's targeted and you already know where:**
- "Edit this specific line in this specific file" → use Edit tool
- "Run npm install" → use Bash tool
- "Read this file" → use Read tool

**It's mechanical:**
- String replacements across files → Bash grep + sed, or Edit
- Moving a file → Bash mv
- Running a test → Bash npm test

**Context cost is low:**
- The answer will fit in a short response
- You're reading one or two files

## Parallel Agent Pattern
```javascript
// These are independent — send in ONE message for parallel execution
Agent({ description: "Research auth patterns", prompt: "Find all auth-related files in /Users/drive/jrs-auto-repair..." })
Agent({ description: "Research DB schema", prompt: "Find and document the Supabase table structure..." })
Agent({ description: "Research API routes", prompt: "List all Route Handlers and their purposes..." })
```

## Sequential Agent Pattern
```javascript
// Must be sequential — second depends on first
const exploration = await Agent({ subagent_type: "feature-dev:code-explorer", prompt: "Understand the blueprint store pattern..." })
// Use exploration.output to inform the next agent
const architecture = await Agent({ subagent_type: "feature-dev:code-architect", prompt: `Based on this exploration: ${exploration.output}\n\nDesign how to add versioning to the blueprint store...` })
```

## Context Protection
Agents run in their own context — they don't pollute your main conversation.
If a task would dump 5000 lines of code into your context, an Explore agent reads it and returns a summary instead.
This keeps your main context clean for reasoning.

## The Cost Check
Each agent spawn costs tokens for setup + execution.
Don't spawn an agent for: finding one file, reading one file, making one edit.
Do spawn an agent for: understanding a system, exploring a codebase, parallel work.

# Plugin: feature-dev@claude-plugins-official

**What it provides:** Specialized agents for feature development: exploring codebases, architecting features, reviewing code.
**When to reach for it:** Any time you're building or reviewing a feature in an existing codebase. These agents understand project conventions, not just generic patterns.

## The Three Agents

### feature-dev:code-explorer
**Purpose:** Understand how an existing feature works before modifying it.
**Use when:** "How does the auth system work?" "How does blueprint storage work?" "What does clicking this button actually do?"
**Does:** Traces execution paths, maps architecture layers, identifies all files involved, documents dependencies.
**Does NOT write code.**

```javascript
Agent({
  subagent_type: "feature-dev:code-explorer",
  description: "Trace the auth flow",
  prompt: "Trace the complete authentication flow in /Users/drive/jrs-auto-repair. Start from the admin login form, follow through adminAuth.ts, and document every file involved and what each does."
})
```

### feature-dev:code-architect
**Purpose:** Design how to build a new feature.
**Use when:** "I need to add X — what files do I touch, what do I create, how should it work?"
**Does:** Analyzes existing patterns, provides blueprint with specific files to create/modify, data flows, build sequence.
**Does NOT write implementation code.**

```javascript
Agent({
  subagent_type: "feature-dev:code-architect",
  description: "Architect feedback form feature",
  prompt: "Design how to add a customer feedback form to /Users/drive/jrs-auto-repair. It should store submissions in Supabase and show them in the admin panel. Analyze existing patterns and provide specific files to create/modify."
})
```

### feature-dev:code-reviewer
**Purpose:** Review a specific feature for bugs, logic errors, security, and project conventions.
**Use when:** You've finished building a feature and want a second opinion before shipping.
**Does:** Checks logic, security, conventions, catches common bugs, reports only high-confidence issues.

```javascript
Agent({
  subagent_type: "feature-dev:code-reviewer",
  description: "Review new feedback form",
  prompt: "Review the feedback form feature just added to /Users/drive/jrs-auto-repair. Check app/api/feedback/route.ts, app/feedback/page.tsx, and app/admin/feedback/page.tsx for bugs, security issues, and adherence to project patterns (two-auth system, three Supabase clients, no admin.ts client-side)."
})
```

## The Ideal Workflow for a New Feature
```
1. code-explorer  → understand existing patterns
2. code-architect → design the implementation
3. implement     → write the actual code
4. code-reviewer → review before shipping
```

## Key Instruction: Give Them Context
These agents are smart but start cold.
Always include in the prompt:
- Exact file paths to look at
- The specific question or goal
- Any constraints or patterns to follow (e.g., "this project uses the two-auth pattern")

Vague prompts produce vague output. Specific prompts produce specific, actionable output.

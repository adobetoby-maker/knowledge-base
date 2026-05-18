# MCP: Greptile Patterns

## Overview

Greptile provides semantic search over codebases indexed in the cloud. Ask natural language questions about a codebase and get specific file + line answers — without reading every file locally. Use it for: onboarding to unfamiliar repos, cross-repo dependency analysis, finding implementation examples.

## Authentication

```
Tool: greptile.authenticate → returns login URL
Tool: greptile.complete_authentication (code from redirect)
```

Greptile requires a GitHub/GitLab repo to be indexed first via the Greptile dashboard. The MCP then queries that index.

## Core Use Cases

### 1. Find Where Something Is Implemented

Instead of `grep -r "function foo"`, ask semantically:

```
Tool: greptile.query
  repository: "owner/repo"
  question: "Where is the invoice calculation logic?"
  
→ Returns: file paths, line numbers, code snippets with explanation
```

The answer returns specific file locations, not just a description.

### 2. Understand an Unfamiliar Codebase

Use Greptile to understand architecture before making changes:

```
Questions to ask when starting on a new repo:
- "How is authentication handled?"
- "What is the data flow for user signup?"
- "Where are environment variables validated?"
- "What database ORM is used and where are models defined?"
- "How are API errors returned to the client?"
```

Each answer points to specific files — then read those files with the Read tool for full context.

### 3. Find Usage Examples

Before implementing a pattern, find existing examples:

```
Tool: greptile.query
  question: "Show me examples of how pagination is implemented in this codebase"

→ Returns 3-5 examples from actual files with line numbers
```

Consistency with existing patterns is more valuable than using the theoretically best pattern.

### 4. Dependency Analysis

```
Tool: greptile.query
  question: "What code uses the UserService class?"

→ Returns all callers with file + line locations
```

Critical before refactoring — know all the blast radius before changing an interface.

### 5. Security Review Assistance

```
Tool: greptile.query
  question: "Where is user input passed to database queries without parameterization?"

→ Points to potential SQL injection risks
```

Greptile understands code semantics, not just text matching — "database query" finds calls even if variable names vary.

## Query Phrasing

Results improve with specific queries:

| Vague | Better |
|-------|--------|
| "Find auth code" | "Where does the app verify JWT tokens?" |
| "Database queries" | "Which functions query the users table?" |
| "Error handling" | "How are Stripe webhook errors caught and logged?" |
| "Config" | "Where are environment variables read and what are the required ones?" |

Include context about what you're trying to accomplish:
- "I'm adding a new payment method — where do I need to add the new type?"
- "I'm debugging a 401 error — trace the auth middleware chain"

## Multi-Repository Queries

If Greptile has multiple repos indexed:

```
Tool: greptile.query
  repository: "owner/repo1,owner/repo2"
  question: "How do the frontend and backend communicate — what API contracts exist?"
```

Useful for: microservices, frontend/backend split repos, shared library dependencies.

## Combining with Direct File Reading

Greptile points you to the right place — read the full file for complete context:

```
1. greptile.query → "The payment logic is in lib/payments/charge.ts:45-90"
2. Read("lib/payments/charge.ts", offset: 30, limit: 80) → full context
3. Make the change with full understanding
```

Never make changes based only on the Greptile snippet — the snippet is navigation, not the full picture.

## Limitations

- Index freshness: Greptile indexes on demand or schedule — very recent commits may not be indexed yet
- Private repos: Requires OAuth with repo access
- Code in comments or strings may not be semantically indexed
- Minified or generated code doesn't produce useful results
- Max response contains ~5-10 code examples per query — for exhaustive search, run multiple specific queries

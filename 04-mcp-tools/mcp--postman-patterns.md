# MCP: Postman Patterns

## Overview

Postman MCP enables API readiness analysis, OpenAPI spec scanning, and agent-compatibility assessment. Use it for: evaluating APIs before building integrations, identifying spec quality issues, ensuring APIs follow standards that make them work well with AI agents.

## Authentication

```
Tool: postman.authenticate → returns login URL
Tool: postman.complete_authentication (code from redirect)
```

Connects to the user's Postman account and its associated APIs and collections.

## Core Use Cases

### 1. API Agent-Readiness Analysis

Before building an agent integration, check if the API is well-designed for AI use:

```
Tool: postman.analyze_api
  spec: <OpenAPI spec content or URL>

→ Returns: scores across 8 pillars, specific issues, recommendations
```

8 pillars evaluated:
1. **Descriptions** — endpoints and parameters have clear descriptions
2. **Examples** — request/response examples exist
3. **Errors** — error responses are documented
4. **Auth** — authentication scheme is documented
5. **Pagination** — pagination patterns are standard and documented
6. **Idempotency** — mutating operations are idempotent
7. **Versioning** — version strategy is clear
8. **Naming** — consistent naming conventions

### 2. OpenAPI Spec Validation

Before publishing an API, validate the spec:

```
Tool: postman.validate_spec
  spec: <OpenAPI 3.0 content>

→ Returns: validation errors, warnings, suggestions
```

Common issues caught:
- Missing `operationId` on endpoints (agents use this to identify which tool to call)
- Undocumented `400`/`422`/`500` responses
- Parameters without descriptions
- Inconsistent casing in field names
- Missing required fields in schemas

### 3. Comparing Spec to Implementation

Check if the documented spec matches actual API behavior:

```
Tool: postman.run_collection
  collection_id: "<postman collection ID>"
  environment: "<env ID>"

→ Returns: pass/fail per request, response validation against schema
```

Gaps between spec and reality break AI agents that rely on the spec for tool definitions.

## Key Things to Fix Before AI Integration

If the readiness score is below 70, prioritize:

### Missing operationId

Without `operationId`, agents can't reliably identify which endpoint to call. Every operation needs a unique, descriptive ID:

```yaml
# Bad
paths:
  /users/{id}:
    get:
      summary: Get user

# Good
paths:
  /users/{id}:
    get:
      operationId: getUserById
      summary: Get a user by their unique ID
```

### Undocumented Error Responses

Agents need to handle errors. Document all error codes:

```yaml
responses:
  '200':
    description: Success
  '400':
    description: Invalid input — check request body format
  '401':
    description: Authentication required
  '404':
    description: User not found
  '429':
    description: Rate limit exceeded — retry after {Retry-After} seconds
```

### Missing Parameter Descriptions

Parameters must explain what they accept:

```yaml
# Bad
- name: status
  in: query
  schema:
    type: string

# Good
- name: status
  in: query
  description: Filter by invoice status. One of: draft, pending, paid, overdue
  schema:
    type: string
    enum: [draft, pending, paid, overdue]
```

## Analysis Output Interpretation

Score ranges:
- **90-100**: Ready for AI agent integration
- **70-89**: Usable but some issues will cause agent confusion
- **50-69**: Agents will struggle — fix critical issues first
- **Below 50**: Not suitable for agent use without major improvements

Focus on descriptions and errors first — these have the highest impact on agent reliability.

## When to Run Analysis

- Before building a new integration
- When an agent is making incorrect API calls (may indicate spec issues)
- After a major API update (spec may have drifted from implementation)
- During API design review (catch issues before publishing)

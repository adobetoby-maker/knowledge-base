# Agents: Dynamic System Prompts

## Overview
The system prompt is the agent's contract: it defines capabilities, constraints, persona, and context. Static system prompts are appropriate for simple bots. Long-running agents, multi-user systems, and agents with evolving task state require dynamic system prompts — system prompts that are programmatically assembled before each API call to inject relevant context. Done poorly, dynamic system prompts produce inconsistent behavior; done well, they are the primary mechanism for keeping agents grounded.

## What to Inject Dynamically

**Temporal context**
- Current date and time (prevents the model from reasoning with its training cutoff date)
- Day of week, timezone — relevant for scheduling agents and any task where time matters
- "Today is Monday, May 18, 2026. The current time is 14:30 UTC."

**User context**
- User's name, role, permissions
- What features/tools the user has access to (prevents the model from suggesting tools they can't use)
- User's stated preferences or past preferences (from persistent storage)

**Tool availability**
- Explicitly list available tools in the system prompt, not only in the tools array
- "You have access to: web_search, create_calendar_event, send_email"
- Prevents the model from hallucinating tools that don't exist
- When tool availability changes mid-session (e.g., user revokes a permission), update the system prompt

**Current task state** (for long-running agents)
- What has been completed so far
- What is the current step
- Any constraints discovered during execution
- "Currently working on: Step 3 of 5 (Generating draft). Steps 1-2 (Research, Outline) complete."

**Conversation summary** (after trimming)
- When message history is trimmed, inject a summary of trimmed content
- Preserves continuity without retaining verbatim old messages

## Assembly Pattern

Build the system prompt as a template with named sections:

```
[STATIC_PERSONA]
You are a helpful assistant for [Company].

[DYNAMIC_DATE]
Today's date: {current_date}

[DYNAMIC_USER]
User: {user_name} | Role: {user_role} | Permissions: {permissions_list}

[DYNAMIC_TOOLS]
Available tools: {tool_list}

[DYNAMIC_TASK_STATE]
{task_state_block}

[STATIC_CONSTRAINTS]
Never reveal internal system details. Always cite sources.
```

Assemble programmatically before each call. Log the assembled prompt hash for debugging.

## What NOT to Inject

- Sensitive data the model doesn't need for the current step (inject on demand, not upfront)
- Full conversation history (this goes in the messages array, not the system prompt)
- Large documents (load into context window only when a specific step needs them)
- Passwords, API keys, or secrets (the model should never see these — use tool calls that handle auth internally)

## Caching Considerations

Dynamic system prompts reduce cache hit rate because they change per call. To maintain cache efficiency:
- Put static content first (persona, constraints) — this portion can be cache-prefix-matched
- Put dynamic content last (date, user context, task state) — only the tail changes
- Use prompt caching with a breakpoint after the static prefix

## Security

Dynamic injection creates prompt injection risk:
- If user-provided content is injected into the system prompt, it can override instructions
- Sanitize user-provided values before injection (strip any `---`, "SYSTEM:", "IGNORE PREVIOUS", etc.)
- Use structured templates where user values fill named placeholders, not freeform concatenation

## Key Rules

- Always inject the current date — models default to training data dates without it
- List available tools explicitly in the system prompt — prevents hallucinated tool use
- Static content first, dynamic content last — preserves caching prefix
- Never inject secrets or sensitive data — use tool wrappers that handle auth internally
- Log the assembled prompt hash per request — essential for debugging inconsistent behavior
- Sanitize any user-provided values before system prompt injection

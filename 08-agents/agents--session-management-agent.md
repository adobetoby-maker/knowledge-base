# Agent Session Management

Agent sessions maintain continuity across multiple request-response cycles for the same user or task. Without proper session management, every request starts cold — no history, no progress, no context. Sessions also isolate concurrent users so one person's state never bleeds into another's.

## What a Session Stores

A session is a container for:
- **Conversation history** — prior messages to maintain coherence
- **Task state** — where the agent is in a multi-step flow
- **Accumulated context** — facts gathered, documents loaded, results from prior tool calls
- **Metadata** — session ID, user ID, created/updated timestamps, expiry

Keep sessions lean. Do not store full tool responses in history if a summary suffices. Bloated sessions slow down every subsequent request.

## Session ID Propagation

Generate session IDs at session creation, not per-request. Use a cryptographically random string (UUID v4 or similar — 128-bit entropy minimum).

The client sends the session ID on every request, typically as a header or request body field:

```
POST /api/agent
x-session-id: sess_7f3a2e1b-...
```

The server validates the session ID belongs to the authenticated user before loading state. Never accept a session ID without verifying ownership — otherwise users can hijack each other's sessions by guessing IDs.

## Persistence with Redis

Redis is the right default for session storage — fast reads, TTL support, simple data model.

```python
import json
import redis

r = redis.Redis(host='localhost', port=6379, decode_responses=True)

SESSION_TTL = 3600  # 1 hour

def load_session(session_id: str) -> dict | None:
    data = r.get(f"session:{session_id}")
    return json.loads(data) if data else None

def save_session(session_id: str, state: dict) -> None:
    r.setex(f"session:{session_id}", SESSION_TTL, json.dumps(state))

def delete_session(session_id: str) -> None:
    r.delete(f"session:{session_id}")
```

Always use a prefixed key (`session:`) — it separates sessions from other Redis keys and makes bulk operations safe.

## Session Expiry

Sessions must expire. A session that never expires is both a security risk and a storage leak.

Set TTL based on expected interaction duration. For interactive chat: 30–60 minutes of inactivity is reasonable. For long-running background tasks: tie TTL to expected task completion time plus a buffer.

Reset the TTL on every write — `SETEX` overwrites the existing TTL. This implements sliding expiry: sessions stay alive as long as the user is active, and expire after a period of inactivity.

When a session expires, return a clear error so the client can prompt the user to start a new session rather than silently failing.

```python
if not session:
    return {"error": "session_expired", "message": "Session expired. Start a new conversation."}
```

## Resuming Interrupted Sessions

Long-running agent tasks may be interrupted (network failure, process restart, browser close). Design sessions so they can be resumed:

1. Persist task state after every significant step, not just at completion
2. Store the current step name or index in the session
3. On resume, read `session.current_step` and continue from there
4. Mark completed steps so the agent doesn't re-execute them

```python
session['task_state'] = {
    'current_step': 'awaiting_tool_result',
    'steps_completed': ['classify', 'retrieve_context'],
    'pending_tool_call': { 'name': 'search', 'args': {...} }
}
save_session(session_id, session)
```

This is especially important for tasks that call expensive external APIs — you don't want to re-execute a paid API call because a network blip interrupted the response.

## Multi-User Session Isolation

Every session must be scoped to a user ID. Validate ownership on every load:

```python
def get_session_for_user(session_id: str, user_id: str) -> dict | None:
    session = load_session(session_id)
    if not session:
        return None
    if session.get('user_id') != user_id:
        return None  # ownership mismatch — treat as not found
    return session
```

Returning `None` instead of a 403 prevents user enumeration — the caller can't tell whether the session doesn't exist or belongs to someone else.

For multi-tenant systems, also scope by tenant ID. A session valid for user A in tenant X should not be accessible to user A in tenant Y.

## Context Window Management in Sessions

Session history grows unboundedly. Before passing history to the model, trim it:

1. Keep the system prompt and first user message (establishes task context)
2. Keep the last N turns (recent context)
3. If a summary exists from a prior compression step, inject it between the first message and recent turns

Never let the full session history exceed the model's context window — truncation mid-history produces incoherent responses.

## Key Rules

- Generate session IDs with cryptographic randomness — UUIDs are fine
- Always validate that the requesting user owns the session before loading state
- Use sliding TTL: reset expiry on every write, not just session creation
- Return a clear `session_expired` error so clients can handle gracefully
- Persist task state after each significant step to enable safe resumption
- Scope sessions by both user ID and tenant ID in multi-tenant systems
- Trim conversation history before each model call — never let it grow unboundedly
- Never log full session state to application logs — it may contain sensitive conversation content

# MCP: Slack Patterns

## Overview

The Slack MCP enables sending messages, reading channels, and managing notifications from agent workflows. Primary use: status updates, alerts, approvals, async communication in automated pipelines.

## Authentication First

```
Slack MCP requires OAuth authentication before any tool call:
1. Call authenticate → get login URL
2. User opens URL and authorizes
3. Call complete_authentication with returned code
4. Store session — valid until revoked
```

Authentication is per-workspace. Multi-workspace requires separate auth flows.

## Core Use Cases

### 1. Status Updates from Long Jobs

When a batch job or deploy completes, post a summary:

```
Tool: slack.send_message
Channel: #deployments
Message: "✅ Deploy complete: v2.4.1 to production
- 47 files changed
- Build: 2m 34s
- URL: https://myapp.com"
```

Keep messages structured. Use `\n` for line breaks. Attach thread replies for details rather than long initial messages.

### 2. Error Alerts

```
Tool: slack.send_message
Channel: #alerts
Message: ":rotating_light: Error in payment processor
Job: daily-reconciliation
Error: Connection timeout to Stripe API
Time: 2026-05-18 03:45 UTC
Action required: Manual retry or investigate API status"
```

Always include: what failed, when, what action is needed.

### 3. Approval Workflows

Post a request, poll for reaction or reply:

```
Step 1: send_message with approval request
Step 2: Note the message timestamp (ts)
Step 3: Poll for reactions on that ts
Step 4: :white_check_mark: = approved, :x: = rejected
```

Reactions are faster than waiting for text replies. Use :white_check_mark: and :x: as the convention and document it in the message.

### 4. Reading Recent Messages

Use `search_messages` or `list_messages` to pull context before acting:

```
Tool: slack.list_messages
Channel: #incidents
Limit: 20
```

Parse the result for keywords before deciding on agent action. Useful for: checking if someone already reported the issue, seeing what the team is discussing.

## Message Formatting

Slack uses `mrkdwn` (not standard markdown):

| Effect | Syntax |
|--------|--------|
| Bold | `*text*` |
| Italic | `_text_` |
| Code inline | `` `code` `` |
| Code block | ` ```code``` ` |
| Link | `<https://url\|label>` |
| User mention | `<@USERID>` |
| Channel mention | `<#CHANNELID>` |

Blocks API gives richer formatting but requires structured JSON payload — use for dashboards or rich cards only.

## Channel vs DM

- Use **channels** for team-visible updates, alerts, status
- Use **DMs** only for user-specific sensitive info or personal notifications
- Prefer `#bot-alerts` or `#deployments` over DMs for operational messages — team needs visibility

## Rate Limiting

Slack enforces per-method rate limits (typically Tier 3: 50/min for `chat.postMessage`). In overnight batch jobs:
- Don't send one message per record
- Batch into summaries: "Processed 1,847 invoices. 12 failed. See thread."
- Post failures as thread replies under the summary message

## Thread Replies

Use `thread_ts` to reply to an existing message instead of cluttering the channel:

```
Tool: slack.send_message
Channel: #deployments
ThreadTs: <original message ts>
Message: "Error details: ..."
```

Top-level message = summary. Thread = details. This keeps channels readable.

## Anti-Patterns

- Never post secrets, API keys, or PII to Slack (logs, IDs, emails only if channel is private)
- Don't use Slack as a job queue — messages can be missed, have no delivery guarantee for this use case
- Don't send more than 3-4 messages per automated task — notify once with a summary
- Avoid `@here` or `@channel` from bots — triggers notifications for everyone

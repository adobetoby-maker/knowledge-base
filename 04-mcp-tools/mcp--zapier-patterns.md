# MCP: Zapier Patterns

## Overview

Zapier MCP enables triggering automations, reading Zap data, and integrating with 7,000+ apps through Zapier's platform. Use it for: triggering existing Zaps, passing data to no-code workflows, connecting to apps without native MCPs.

## Authentication

```
Tool: zapier.authenticate → returns login URL
Tool: zapier.complete_authentication (code from redirect)
```

Authentication is per-user. The MCP operates under the authenticated user's Zapier account and can only trigger Zaps that user owns or has access to.

## Core Use Cases

### 1. Triggering Existing Zaps

The most reliable pattern — build the Zap in Zapier, trigger it from the MCP:

```
Tool: zapier.trigger_zap
  zap_id: "12345678"
  data: {
    "customer_name": "Jane Smith",
    "email": "jane@example.com",
    "order_id": "ORD-4521"
  }
```

The Zap handles the downstream: sending email, adding to CRM, creating task, etc.

### 2. Passing Data to Webhooks

Zapier Zaps often use "Webhooks by Zapier" as a trigger. Find the webhook URL in the Zap editor, then:

```
Tool: zapier.send_to_webhook
  webhook_url: "https://hooks.zapier.com/hooks/catch/..."
  payload: {
    "event": "user_signup",
    "user_id": "u_abc123",
    "plan": "pro"
  }
```

Webhook Zaps are the most flexible — they accept any JSON payload and map fields in Zapier's UI.

### 3. Reading Zap History

Check if a recent Zap run succeeded:

```
Tool: zapier.get_zap_history
  zap_id: "12345678"
  limit: 10

→ Returns: recent runs with status (success/error), timestamps, data
```

Useful for: confirming an automated notification was sent, debugging why a workflow didn't fire.

## Design Principle: Build in Zapier, Trigger from MCP

Don't try to replicate Zapier's logic in the agent. Build the complete workflow in Zapier (multi-step, filters, branching) and call it as a single trigger from the agent.

```
Wrong:
  1. agent sends email via SendGrid MCP
  2. agent creates CRM contact via HubSpot MCP  
  3. agent adds tag via Mailchimp MCP
  4. agent creates task via Asana MCP

Right:
  1. agent triggers Zapier "new-customer" Zap
  (Zap handles: email + CRM + Mailchimp + Asana in sequence)
```

The agent doesn't need to know about downstream integrations. Zapier handles failures, retries, and the integration complexity.

## Data Passing Best Practices

Pass structured data, not instructions:

```
Wrong:
  data: { "message": "Send a welcome email to the new user" }

Right:
  data: {
    "user_email": "jane@example.com",
    "first_name": "Jane",
    "plan": "pro",
    "signup_date": "2026-05-18"
  }
```

The Zap maps specific fields. "Instructions" in data are meaningless to Zapier's field mapping.

## Zap Discovery

```
Tool: zapier.list_zaps

→ Returns: zap_id, name, status (on/off), last_run
```

Call this at session start to know what's available. Cache the list — it doesn't change often.

## Error Handling

Zapier Zap triggers are fire-and-forget by default. To confirm delivery:

```
1. trigger_zap
2. Wait 5-10 seconds
3. get_zap_history (limit: 1) → check latest run status
```

If status is "error", check the Zap error details in Zapier dashboard for the full error context.

## When NOT to Use Zapier MCP

- If the target app has its own MCP (Slack, GitHub, Stripe) — use that directly
- If you need synchronous response data — Zapier triggers are async; no return value
- If you need sub-second latency — Zap execution takes 2-30 seconds
- If you need to pass >5MB of data — use a storage URL instead

## Anti-Patterns

- Don't trigger the same Zap multiple times in quick succession — Zapier may throttle
- Don't pass sensitive data (tokens, passwords) through Zapier — it stores run history
- Don't rely on Zap field names staying stable — someone may rename a field in the Zapier UI

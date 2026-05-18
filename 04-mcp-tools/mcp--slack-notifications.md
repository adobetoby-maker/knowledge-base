# MCP: Slack Notifications

## Overview
Slack MCP enables deployment notifications, error alerts, and progress updates from within an automated workflow session. The key design principle is message durability: use ephemeral messages for transient status ("deploying now...") and persistent channel messages for outcomes ("deployed successfully" or "deploy failed"). Thread replies keep channels clean for high-frequency update streams.

## Authentication
```
slack authenticate
→ prompts OAuth flow, stores credentials
→ only needed once per session setup
```

## Channel Selection by Audience
```
#deploys          → release notifications (production and staging)
#alerts           → errors, monitoring triggers, on-call
#engineering      → code review requests, PR status
#general          → major milestones only (not noisy)
DM to @username   → personal task completions, sensitive issues
```

## Deployment Notification Pattern
```
// 1. Send "in progress" at deploy start
slack send message:
  channel: "#deploys"
  text: ":hourglass: Deploying v1.3.0 to production..."

// Save the message timestamp (ts) for threading
→ { ts: "1716000000.123456", channel: "C0123456" }

// 2. Thread reply with progress
slack reply:
  channel: "C0123456"
  thread_ts: "1716000000.123456"
  text: "Build completed. Running migrations..."

// 3. Final status update (reply in same thread)
slack reply:
  channel: "C0123456"
  thread_ts: "1716000000.123456"
  text: ":white_check_mark: v1.3.0 deployed successfully. https://yourapp.com"
```

## Error Alert Pattern
```
// Structured error alert with context
slack send message:
  channel: "#alerts"
  blocks:
    - type: "header"
      text: ":red_circle: Production Error"
    - type: "section"
      fields:
        - "Service: payment-api"
        - "Error: STRIPE_WEBHOOK_SIGNATURE_INVALID"
        - "Count: 47 in last 5 minutes"
        - "First seen: 2026-05-18T10:23:00Z"
    - type: "actions"
      elements:
        - type: "button"
          text: "View Logs"
          url: "https://vercel.com/project/logs"
```

## Finding the Right Channel
```
// Search for a channel by purpose
slack list channels filter: "deploys"
→ returns channel IDs and membership

// Find recent discussions about a topic
slack search messages query: "payment webhook error" in: "#engineering"
→ returns thread context for recent issues
```

## Progress Update Pattern for Long Tasks
```
// Task starts
slack send message:
  channel: "@drive"  // DM for personal tasks
  text: "Starting: batch migration of 50,000 user records"
→ { ts: "1716000100.000000" }

// Incremental updates in thread
slack reply thread_ts: "1716000100.000000":
  "Progress: 12,500 / 50,000 (25%)"

slack reply thread_ts: "1716000100.000000":
  "Progress: 25,000 / 50,000 (50%)"

// Completion
slack reply thread_ts: "1716000100.000000":
  ":white_check_mark: Done. 50,000 records migrated. 3 errors logged to #alerts."
```

## Key Rules
- **Thread for updates, channel for status** — send one message to the channel, then all updates as thread replies; don't flood the channel with 10 separate messages.
- **Save `ts` for threading** — the message timestamp is the thread parent ID; always save it from the send response.
- **Channel IDs over names for API calls** — channel names can change; IDs (`C0123456`) are stable.
- **DM for personal/sensitive tasks** — deploys that might fail, credential rotation, billing issues shouldn't go to #general.
- **Structured blocks for alert messages** — plain text alerts get missed; use header + section fields for critical errors.
- **Mention `@oncall` or `@team-lead` in alerts** — alerts without mentions are ignored during high-volume periods.

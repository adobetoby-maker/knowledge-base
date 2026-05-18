# Skill: Slack Bot Integration

## Overview
Slack bots extend workflows into the tool teams already live in — approvals, alerts, commands, and interactive messages without switching context. Slack Bolt SDK handles the event/action routing complexity. The critical decision is Socket Mode (for development, no public URL needed) vs. Request URLs (for production, webhook-based). Store the Slack user ID alongside your app's user ID from first interaction, or matching users later becomes painful.

## Setup with Slack Bolt

```bash
npm install @slack/bolt
```

Create a Slack App at https://api.slack.com/apps — enable Socket Mode for dev, or set a Request URL for production.

```ts
// lib/slack-app.ts
import { App } from '@slack/bolt'

export const slackApp = new App({
  token: process.env.SLACK_BOT_TOKEN,         // Bot token (xoxb-)
  signingSecret: process.env.SLACK_SIGNING_SECRET,
  socketMode: process.env.NODE_ENV === 'development',
  appToken: process.env.SLACK_APP_TOKEN,       // App-level token (xapp-) for Socket Mode
})
```

## Slash Command Handler

```ts
slackApp.command('/deploy', async ({ command, ack, respond }) => {
  // Always ack() within 3 seconds or Slack shows an error
  await ack()

  const branch = command.text.trim() || 'main'
  const userId = command.user_id

  // Do async work after ack
  await respond({
    response_type: 'in_channel',  // visible to everyone in channel
    text: `<@${userId}> triggered deploy for branch \`${branch}\``,
    blocks: [
      {
        type: 'section',
        text: { type: 'mrkdwn', text: `Deploy of \`${branch}\` started by <@${userId}>` },
      },
    ],
  })

  await triggerDeploy(branch, userId)
})
```

The 3-second ack deadline is hard. If work takes longer, ack immediately then post a follow-up message.

## Button Interaction Handler

```ts
// Triggered when user clicks a button in a Block Kit message
slackApp.action('approve_request', async ({ action, ack, body, client }) => {
  await ack()

  const requestId = (action as any).value
  const approverId = body.user.id

  await approveRequest(requestId, approverId)

  // Update the original message to reflect new state
  await client.chat.update({
    channel: body.channel!.id,
    ts: body.message!.ts,
    text: 'Request approved',
    blocks: [
      {
        type: 'section',
        text: { type: 'mrkdwn', text: `:white_check_mark: Approved by <@${approverId}>` },
      },
    ],
  })
})
```

Always update or replace the message after an action — the original buttons remain clickable until you remove them.

## Message Event Handler

```ts
// Triggered when the bot is @-mentioned
slackApp.event('app_mention', async ({ event, client }) => {
  const userId = event.user

  // Link Slack user to app user on first mention
  await upsertSlackUser(userId, event.channel)

  await client.chat.postMessage({
    channel: event.channel,
    thread_ts: event.ts,  // reply in thread
    text: `Hello <@${userId}>! Here's what I can do...`,
  })
})
```

## Storing Slack User IDs

Store at first contact — not just when they authenticate:

```sql
ALTER TABLE users ADD COLUMN slack_user_id TEXT UNIQUE;
CREATE INDEX ON users (slack_user_id);
```

```ts
async function upsertSlackUser(slackUserId: string, channelId: string) {
  // Try to match by email if available
  const slackProfile = await slackApp.client.users.info({ user: slackUserId })
  const email = slackProfile.user?.profile?.email

  if (email) {
    await db.users.update({
      where: { email },
      data: { slack_user_id: slackUserId },
    })
  }
}
```

## Socket Mode vs Request URL

| | Socket Mode | Request URL |
|---|---|---|
| Use case | Local development | Production |
| Requires public URL | No | Yes (ngrok or deployed) |
| Connection | Persistent WebSocket | HTTP POST per event |
| Token needed | `xapp-` app-level token | Just signing secret |
| Latency | ~50ms | Depends on server |

## Key Rules
- Always call `ack()` first — before any async operations — within 3 seconds
- Validate the Slack signing secret on every incoming request (Bolt does this automatically)
- Use `response_type: 'ephemeral'` for sensitive outputs (visible only to the user who ran the command)
- Store Slack user IDs from day one — retrofitting user matching is expensive
- Slash commands, shortcuts, and interactions all have separate OAuth scopes — request only what you need
- Block Kit builder (https://app.slack.com/block-kit-builder) is the fastest way to design messages
- Rate limits: Tier 1 (1/min) to Tier 4 (100+/min) per method — check before looping over users

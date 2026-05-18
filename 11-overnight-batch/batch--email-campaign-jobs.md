# Batch: Email Campaign Jobs

## What This Solves

Bulk email operations — sending campaign emails, generating personalized content, checking deliverability — run overnight when API rate limits and user traffic are low. The key challenges: rate limiting to avoid getting blocked, tracking delivery status, and not re-sending to the same recipient.

## Email Batch Sender

```ts
// scripts/send-campaign.ts
import Resend from 'resend'
import { supabaseAdmin } from '../lib/supabase/admin'

const resend = new Resend(process.env.RESEND_API_KEY!)

interface CampaignRecipient {
  id: string
  email: string
  name: string
  metadata: Record<string, string>
}

const CAMPAIGN_ID = process.env.CAMPAIGN_ID!
const BATCH_SIZE = 10          // Resend supports 100/batch; use 10 for safety
const DELAY_BETWEEN_BATCHES_MS = 1000  // 1 second between batches

async function main() {
  // Load recipients not yet sent to for this campaign
  const { data: recipients } = await supabaseAdmin
    .from('campaign_recipients')
    .select('id, email, name, metadata')
    .eq('campaign_id', CAMPAIGN_ID)
    .is('sent_at', null)
    .limit(5000)

  if (!recipients || recipients.length === 0) {
    console.log('No pending recipients')
    return
  }

  console.log(`Sending to ${recipients.length} recipients`)
  let sent = 0
  let failed = 0

  for (let i = 0; i < recipients.length; i += BATCH_SIZE) {
    const batch = recipients.slice(i, i + BATCH_SIZE)

    try {
      const { data, error } = await resend.batch.send(
        batch.map(recipient => ({
          from: 'JR\'s Auto Repair <notifications@jrsautorepair.com>',
          to: recipient.email,
          subject: generateSubject(recipient),
          html: generateEmailHtml(recipient),
          tags: [
            { name: 'campaign_id', value: CAMPAIGN_ID },
            { name: 'recipient_id', value: recipient.id },
          ],
        }))
      )

      if (error) throw error

      // Mark as sent
      const sentIds = batch.map(r => r.id)
      await supabaseAdmin
        .from('campaign_recipients')
        .update({ sent_at: new Date().toISOString() })
        .in('id', sentIds)

      sent += batch.length
      console.log(`Progress: ${sent}/${recipients.length}`)

    } catch (err) {
      failed += batch.length
      console.error(`Batch ${i / BATCH_SIZE} failed:`, err)

      // Continue with next batch — don't abort the whole run on one batch failure
    }

    // Rate limiting: pause between batches
    if (i + BATCH_SIZE < recipients.length) {
      await new Promise(resolve => setTimeout(resolve, DELAY_BETWEEN_BATCHES_MS))
    }
  }

  console.log(`Done. Sent: ${sent}, Failed: ${failed}`)
}

main().catch(console.error)
```

## Personalized Content Generation

For campaigns where each email needs unique content:

```ts
async function generatePersonalizedContent(recipient: CampaignRecipient): Promise<string> {
  // Use Haiku for cost efficiency — this is mechanical personalization
  const msg = await client.messages.create({
    model: 'claude-haiku-4-5',
    max_tokens: 500,
    messages: [{
      role: 'user',
      content: `Write a 2-paragraph follow-up email for ${recipient.name}.
Context: ${JSON.stringify(recipient.metadata)}
Keep it under 150 words. Professional, friendly tone.`,
    }]
  })
  return msg.content[0].type === 'text' ? msg.content[0].text : ''
}
```

Pre-generate all content first, review a sample, then send. Don't generate and send in the same step for personalized campaigns.

## Idempotency: The Dedup Table

```sql
CREATE TABLE campaign_email_sends (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id text NOT NULL,
  recipient_email text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  resend_message_id text,
  UNIQUE (campaign_id, recipient_email)  -- Prevents duplicates
);
```

Before sending:
```ts
const { data: existing } = await supabaseAdmin
  .from('campaign_email_sends')
  .select('id')
  .eq('campaign_id', CAMPAIGN_ID)
  .eq('recipient_email', email)
  .single()

if (existing) continue  // Already sent — skip
```

## Delivery Status Tracking

Resend sends webhooks for email events. Store delivery status:

```ts
// app/api/webhooks/resend/route.ts
export async function POST(request: NextRequest) {
  const event = await request.json()

  if (event.type === 'email.delivered') {
    await supabaseAdmin
      .from('campaign_email_sends')
      .update({ delivered_at: event.created_at })
      .eq('resend_message_id', event.data.email_id)
  }

  if (event.type === 'email.bounced') {
    // Mark email as undeliverable — don't send to it again
    await supabaseAdmin
      .from('contacts')
      .update({ email_status: 'bounced' })
      .eq('email', event.data.to[0])
  }

  return NextResponse.json({ ok: true })
}
```

## Rate Limits

Resend limits:
- 2 emails/second on free plan
- 10 emails/second on pro plan
- 100 recipients per batch request

Stay well under limits. At 10 emails/second with 1s delay between 10-batch = safe.

## Safe vs Unsafe Operations

**Safe to run overnight:**
- Sending to opted-in subscribers
- Transactional emails (invoices, confirmations)
- Campaign to existing customers

**Require human review first:**
- First campaign to a new list
- Any email with personalized AI-generated content
- Re-engagement to list that hasn't been emailed in 6+ months (high bounce risk)

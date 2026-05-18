# Batch Job: Content Moderation

## Overview

Automatically flag user-generated content (comments, posts, reviews, usernames) for policy violations overnight or as a backfill. Combines fast rule-based checks (regex for slurs, spam patterns) with model-based classification for nuanced cases. Human review queue for borderline cases.

## Two-Stage Pipeline

```
Stage 1: Rule-based (instant, < 1ms)
  → Hard block: spam patterns, known slurs, malicious links
  → Always fast, always deterministic

Stage 2: Model-based (for content that passes Stage 1)
  → Classify toxicity, harassment, NSFW
  → Required only for ambiguous content
```

## Stage 1: Rule-Based Pre-Filter

```ts
const SPAM_PATTERNS = [
  /\b(buy|sell|free|cheap|discount)\s+(v[i!]agra|c[i!]al[i!]s|med[s]?)\b/i,
  /https?:\/\/[^\s]+\.(xyz|top|click|info)\b/i,  // Spam TLD
  /(\w)\1{8,}/,  // Repeated characters: aaaaaaaaaa
  /\b(click here|act now|limited time|free money)\b/i,
]

const BLOCKLIST = new Set(['...'])  // Load from DB or file

function ruleBasedCheck(text: string): {
  action: 'approve' | 'block' | 'review'
  reason?: string
} {
  const lower = text.toLowerCase()

  // Blocklist check
  for (const term of BLOCKLIST) {
    if (lower.includes(term)) return { action: 'block', reason: 'blocklist_term' }
  }

  // Spam pattern check
  for (const pattern of SPAM_PATTERNS) {
    if (pattern.test(text)) return { action: 'block', reason: 'spam_pattern' }
  }

  // Very short content
  if (text.trim().length < 2) return { action: 'approve' }

  return { action: 'review' }  // Needs model check
}
```

## Stage 2: Model Classification

```ts
const MODERATION_PROMPT = `Classify the following user-generated content.
Return JSON only — no other text.

{
  "safe": true | false,
  "categories": {
    "toxic": 0.0-1.0,
    "harassment": 0.0-1.0,
    "spam": 0.0-1.0,
    "nsfw": 0.0-1.0,
    "hate_speech": 0.0-1.0
  },
  "action": "approve" | "flag" | "remove",
  "reason": "brief reason if flagging or removing"
}

Thresholds: flag if any category > 0.5, remove if any category > 0.85

Content:
{text}

JSON:`

async function modelModerate(text: string): Promise<{
  safe: boolean
  action: 'approve' | 'flag' | 'remove'
  reason?: string
  scores: Record<string, number>
}> {
  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1',
      prompt: MODERATION_PROMPT.replace('{text}', text.slice(0, 2000)),
      stream: false,
      options: { temperature: 0, num_predict: 256 },
    }),
  })

  const data = await response.json()
  const match = data.response.match(/\{[\s\S]*\}/)
  if (!match) return { safe: true, action: 'approve', scores: {} }

  const parsed = JSON.parse(match[0])
  return {
    safe: Boolean(parsed.safe),
    action: parsed.action ?? 'approve',
    reason: parsed.reason,
    scores: parsed.categories ?? {},
  }
}
```

## Combined Pipeline

```ts
async function moderateContent(contentId: string, text: string): Promise<void> {
  // Stage 1: Rule-based
  const ruleResult = ruleBasedCheck(text)
  if (ruleResult.action === 'block') {
    await db.update(content).set({
      status: 'removed',
      moderationReason: ruleResult.reason,
      moderatedAt: new Date(),
    }).where(eq(content.id, contentId))
    return
  }
  if (ruleResult.action === 'approve') {
    await db.update(content).set({ status: 'approved' }).where(eq(content.id, contentId))
    return
  }

  // Stage 2: Model-based
  const modelResult = await modelModerate(text)

  if (modelResult.action === 'remove') {
    await db.update(content).set({ status: 'removed', moderationReason: modelResult.reason }).where(eq(content.id, contentId))
  } else if (modelResult.action === 'flag') {
    // Queue for human review
    await db.update(content).set({ status: 'under_review' }).where(eq(content.id, contentId))
    await createModerationTask({ contentId, scores: modelResult.scores })
  } else {
    await db.update(content).set({ status: 'approved' }).where(eq(content.id, contentId))
  }
}
```

## Batch Processing Overnight

```ts
async function runModerationBatch(): Promise<void> {
  const pending = await db.query.content.findMany({
    where: eq(content.status, 'pending'),
    limit: 10000,
  })

  console.log(`Moderating ${pending.length} items`)

  for (const item of pending) {
    await moderateContent(item.id, item.text)
    await new Promise(r => setTimeout(r, 50))  // Throttle
  }
}
```

## Key Rules

- Rule-based first — it's 1000x faster and catches clear violations without model overhead.
- Model scores of 0.5-0.85 should go to human review, not auto-remove — false positives damage trust.
- Store moderation scores alongside the decision for audit trail and model retraining.
- Maintain a model performance log: track false positive rate (approved content later reported) and false negative rate (removed content appealed successfully).

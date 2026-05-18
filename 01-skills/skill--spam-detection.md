# Skill: Spam Detection

## Overview

User-generated content (comments, reviews, forum posts) attracts spam. A multi-layer detection stack works better than any single technique: server-side honeypot fields catch bots, rate limiting catches flooding, content heuristics catch low-effort spam, and an AI classifier catches sophisticated spam.

## Layer 1: Honeypot Fields

```tsx
// Hidden field that humans never fill, bots do
function ContactForm() {
  return (
    <form>
      {/* Visible fields */}
      <input name="email" type="email" required />
      <textarea name="message" required />

      {/* Honeypot: hidden via CSS, NOT type="hidden" — bots ignore display:none */}
      <input
        name="website"
        tabIndex={-1}
        autoComplete="off"
        style={{ position: 'absolute', left: '-9999px', opacity: 0 }}
        aria-hidden="true"
      />
    </form>
  )
}
```

```ts
// Server: reject if honeypot is filled
export async function POST(req: Request) {
  const data = await req.formData()
  if (data.get('website')) {
    return new Response(null, { status: 200 })  // Silently drop — don't tell bots they failed
  }
  // proceed with legitimate submission
}
```

## Layer 2: Rate Limiting

```ts
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(5, '60 s'),  // 5 submissions per minute
})

export async function POST(req: Request) {
  const ip = req.headers.get('x-forwarded-for') ?? '127.0.0.1'
  const { success } = await ratelimit.limit(ip)

  if (!success) {
    return Response.json({ error: 'Too many submissions' }, { status: 429 })
  }
}
```

## Layer 3: Content Heuristics

```ts
interface SpamSignal {
  score: number
  reason: string
}

function checkHeuristics(content: string): SpamSignal[] {
  const signals: SpamSignal[] = []

  // Excessive links
  const urlCount = (content.match(/https?:\/\//gi) || []).length
  if (urlCount > 3) signals.push({ score: 0.5, reason: `${urlCount} links` })

  // All caps
  const upperRatio = content.replace(/[^A-Z]/g, '').length / content.replace(/[^a-zA-Z]/g, '').length
  if (upperRatio > 0.7 && content.length > 20) signals.push({ score: 0.3, reason: 'all caps' })

  // Repeated characters (aaaa, !!!!)
  if (/(.)\1{4,}/.test(content)) signals.push({ score: 0.3, reason: 'repeated chars' })

  // Known spam patterns
  const spamKeywords = ['buy now', 'click here', 'free offer', 'make money fast', 'weight loss']
  const found = spamKeywords.filter(k => content.toLowerCase().includes(k))
  if (found.length > 0) signals.push({ score: found.length * 0.4, reason: `spam keywords: ${found.join(', ')}` })

  // No spaces (wall of text)
  const words = content.trim().split(/\s+/).length
  const charsPerWord = content.length / words
  if (charsPerWord > 15) signals.push({ score: 0.4, reason: 'no word spacing' })

  return signals
}

function isSpam(content: string, threshold = 0.8): boolean {
  const signals = checkHeuristics(content)
  const totalScore = signals.reduce((sum, s) => sum + s.score, 0)
  return totalScore >= threshold
}
```

## Layer 4: AI Classifier (for high-volume cases)

```ts
async function classifyWithAI(content: string): Promise<'spam' | 'ham' | 'unsure'> {
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-5',
    max_tokens: 10,
    messages: [
      {
        role: 'user',
        content: `Is this comment spam? Reply with exactly one word: "spam", "ham", or "unsure".\n\nComment: ${content}`,
      },
    ],
  })

  const result = (response.content[0] as TextBlock).text.trim().toLowerCase()
  if (result === 'spam') return 'spam'
  if (result === 'ham') return 'ham'
  return 'unsure'
}
```

## Full Pipeline

```ts
async function checkSubmission(content: string, ip: string): Promise<'allow' | 'block' | 'review'> {
  // Layer 1 & 2 are checked in middleware before reaching this function

  // Layer 3: Heuristics (fast, synchronous)
  if (isSpam(content)) return 'block'

  // Layer 4: AI for borderline content (async, skip for obvious ham)
  const signals = checkHeuristics(content)
  const borderline = signals.some(s => s.score > 0.2) && signals.reduce((s, x) => s + x.score, 0) < 0.8

  if (borderline) {
    const aiResult = await classifyWithAI(content)
    if (aiResult === 'spam') return 'block'
    if (aiResult === 'unsure') return 'review'
  }

  return 'allow'
}
```

## Spam Queue for Review

```ts
// Store borderline content for human review
await db.insert(spamQueue).values({
  contentType: 'comment',
  contentId: comment.id,
  signals: JSON.stringify(checkHeuristics(content)),
  status: 'pending',
})
```

## Key Rules

- Return HTTP 200 for honeypot triggers — telling bots they failed trains them to adapt. Silently drop or mark as spam.
- Rate limit by IP and by user_id separately — logged-in users can still spam from many accounts; IPs can be shared.
- Never solely rely on AI classification — it's expensive, slow, and has false positive rates. Use it as a final layer only.
- Store detected spam for review rather than deleting immediately — false positives on real users are costly to recover.
- Heuristics should be tunable thresholds, not hard-coded booleans — spam patterns evolve, you'll need to adjust.

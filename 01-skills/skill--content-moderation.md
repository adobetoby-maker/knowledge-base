# Content Moderation

## When to Add Moderation

User-generated content (reviews, comments, forum posts, contact form text) can contain spam, profanity, or harmful content. Moderate before publishing or storing.

## Server-Side Validation (First Line)

Before calling AI moderation, apply rule-based checks for obvious patterns:

```typescript
// lib/moderation/rules.ts
const SPAM_PATTERNS = [
  /\b(buy|sell)\s+(cheap|discount|wholesale)\b/i,
  /\$\$\$\$+/,
  /click\s+here\s+to\s+(claim|win|get)/i,
  /https?:\/\/[^\s]{50,}/,  // very long URLs — often spam
]

const PHONE_PATTERN = /\b(\+1|1\s)?[\(]?\d{3}[\)\s.-]?\d{3}[\s.-]?\d{4}\b/

export function quickCheck(text: string): { ok: boolean; reason?: string } {
  for (const pattern of SPAM_PATTERNS) {
    if (pattern.test(text)) {
      return { ok: false, reason: 'Contains spam pattern' }
    }
  }
  
  if (text.length > 5000) {
    return { ok: false, reason: 'Text too long' }
  }
  
  return { ok: true }
}
```

## AI Moderation with Haiku

For semantic content moderation (context-aware spam, inappropriate content), use Claude Haiku — it's fast and cheap enough for real-time use:

```typescript
// lib/moderation/ai-check.ts
import Anthropic from '@anthropic-ai/sdk'

const client = new Anthropic()

interface ModerationResult {
  approved: boolean
  reason?: string
  confidence: number
}

export async function moderateContent(
  text: string,
  context: 'review' | 'comment' | 'contact'
): Promise<ModerationResult> {
  const contextDescriptions = {
    review: 'a customer review for an auto repair shop',
    comment: 'a public comment on a blog post about auto repair',
    contact: 'a customer contact form message to an auto repair shop',
  }
  
  const response = await client.messages.create({
    model: 'claude-haiku-4-5',
    max_tokens: 100,
    messages: [{
      role: 'user',
      content: `Is this text appropriate for ${contextDescriptions[context]}? Reply JSON only: {"approved": true/false, "reason": "brief reason if rejected", "confidence": 0.0-1.0}

Text: "${text.substring(0, 500)}"`,
    }],
  })
  
  try {
    return JSON.parse(response.content[0].text) as ModerationResult
  } catch {
    return { approved: true, confidence: 0 }  // fail open if can't parse
  }
}
```

## Review Submission Flow

```typescript
// app/api/reviews/route.ts
export async function POST(req: NextRequest) {
  const body = await req.json()
  const { text, rating, customerName } = ReviewSchema.parse(body)
  
  // 1. Quick rule-based check:
  const quickResult = quickCheck(text)
  if (!quickResult.ok) {
    return NextResponse.json({ error: 'Review contains prohibited content' }, { status: 400 })
  }
  
  // 2. AI moderation:
  const moderationResult = await moderateContent(text, 'review')
  
  if (!moderationResult.approved && moderationResult.confidence > 0.8) {
    // High confidence rejection:
    return NextResponse.json({ error: 'Review not approved for publication' }, { status: 400 })
  }
  
  // 3. Store — with moderation status:
  await supabase.from('reviews').insert({
    text,
    rating,
    customer_name: customerName,
    moderation_status: moderationResult.approved ? 'approved' : 'pending_review',
    moderation_confidence: moderationResult.confidence,
    moderation_reason: moderationResult.reason,
  })
  
  return NextResponse.json({ success: true })
}
```

## Contact Form Moderation

For contact forms, don't reject on moderation failure — just flag for admin review:

```typescript
// Instead of rejecting, flag:
const needsReview = !moderationResult.approved

await supabase.from('contact_submissions').insert({
  name, email, message,
  needs_moderation_review: needsReview,
  moderation_flag: moderationResult.reason,
})

// In admin panel, show flagged submissions separately for human review
```

## Rate Limiting as Moderation

Rate limiting prevents brute-force spam before moderation even runs:

```typescript
// In Route Handler — check rate limit by IP before moderation:
const ip = req.headers.get('x-forwarded-for') ?? 'unknown'
const rateLimitKey = `review-submission:${ip}`

const submissions = await redis.incr(rateLimitKey)
if (submissions === 1) await redis.expire(rateLimitKey, 3600)  // 1 hour window

if (submissions > 3) {
  return NextResponse.json({ error: 'Too many submissions. Try again later.' }, { status: 429 })
}
```

## Admin Review Queue

For content that's flagged but not definitively rejected:

```sql
-- Query pending moderation:
SELECT * FROM reviews
WHERE moderation_status = 'pending_review'
ORDER BY created_at DESC;

-- Approve manually:
UPDATE reviews
SET moderation_status = 'approved', approved_at = now(), approved_by = $userId
WHERE id = $reviewId;
```

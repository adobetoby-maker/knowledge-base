# Skill: Net Promoter Score (NPS) Collection

## Overview
NPS is a leading indicator of retention and word-of-mouth growth. Its value comes not from the number itself but from the follow-through: responding to detractors stops churn, and understanding promoters reveals what to double down on. The trigger moment — when you ask — determines whether you get honest signal or irritated noise.

## Implementation / Key Points

### When to Trigger the Survey
Trigger after a "value moment" — when the user has experienced enough to have an opinion:
- SaaS: after user completes their 3rd session or first meaningful action
- E-commerce: 7 days after delivery confirmation
- B2B: after 30 days of active use

**Never** trigger on first login, immediately after payment, or during an error state.

```ts
function shouldShowNPS(user: User): boolean {
  const daysSinceSignup = daysBetween(user.createdAt, new Date());
  const hasCompletedAction = user.actionsCount >= 3;
  const notShownRecently = !user.lastNpsShownAt
    || daysBetween(user.lastNpsShownAt, new Date()) > 90;
  return daysSinceSignup >= 14 && hasCompletedAction && notShownRecently;
}
```

### Survey Design
```
Q1: "How likely are you to recommend [Product] to a friend or colleague?" (0–10)
Q2: (optional) "What's the main reason for your score?" (free text, 1–2 sentences max)
```
Only one required question. Optional comment must stay optional — mandatory comments reduce completion rate by ~40%.

### Storing the Response
```ts
interface NPSResponse {
  userId: string;
  score: number;          // 0-10
  comment?: string;
  plan: string;           // capture plan at time of survey
  segment: string;        // role/industry if you have it
  respondedAt: string;    // ISO timestamp
  surveyVersion: string;  // '2024-Q1' — lets you compare consistent periods
}

// Score classification
function classify(score: number): 'promoter' | 'passive' | 'detractor' {
  if (score >= 9) return 'promoter';
  if (score >= 7) return 'passive';
  return 'detractor';
}

// NPS = % promoters - % detractors (range: -100 to +100)
function calculateNPS(responses: NPSResponse[]): number {
  const total = responses.length;
  const promoters = responses.filter(r => r.score >= 9).length;
  const detractors = responses.filter(r => r.score <= 6).length;
  return Math.round(((promoters - detractors) / total) * 100);
}
```

### Closing the Loop
```ts
// After saving the response, trigger follow-up:
if (classify(score) === 'detractor') {
  // Email from a human (CS or founder) within 24 hours
  enqueueEmail({ template: 'nps-detractor-followup', userId, comment });
}
if (classify(score) === 'promoter') {
  // Invite to case study or referral program
  enqueueEmail({ template: 'nps-promoter-referral', userId });
}
```

### CRM Integration
Write the NPS score and classification back to the user record in the CRM so sales and CS can see it on the account page. Segment on score in your email automation platform for re-engagement flows.

### Industry Benchmarks
- Software/SaaS: average NPS ≈ 31–41 (good > 50, excellent > 70)
- E-commerce: average NPS ≈ 45
- Calculate monthly with a rolling 90-day window to smooth sample size variation.

## Key Rules
- Ask at the value moment, not on signup or checkout.
- Re-survey no more than once every 90 days per user.
- Store plan and segment with every response — otherwise you can't analyze "do enterprise users rate us higher?"
- Always respond to detractors personally within 24 hours.
- NPS is a lagging indicator of what you shipped 30–60 days ago; pair it with in-app feedback for faster signal.
- Never show NPS during an error state or immediately after a negative interaction.

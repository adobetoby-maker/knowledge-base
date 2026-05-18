# Pattern: Guided Onboarding Checklist

## Overview
Onboarding checklists stored in localStorage get lost when users switch devices or browsers, defeating the purpose. Checking a step manually (rather than detecting the action) lets users game it — they check without actually completing the feature. Steps that auto-complete on action feel like magic; manual checkboxes feel like homework.

## Implementation

```sql
-- Database table: track steps per user, not per browser
CREATE TABLE onboarding_steps (
  user_id     UUID REFERENCES users(id),
  step_key    TEXT NOT NULL,      -- e.g. 'upload_logo', 'invite_member'
  completed   BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, step_key)
);
```

```typescript
// lib/onboarding.ts — step definitions
export const ONBOARDING_STEPS = [
  {
    key: 'complete_profile',
    label: 'Complete your profile',
    description: 'Add your name, photo, and bio.',
    href: '/settings/profile',
    required: true,   // required steps block progress percentage from reaching 100%
  },
  {
    key: 'invite_teammate',
    label: 'Invite a teammate',
    description: 'Collaborate with your team.',
    href: '/settings/team',
    required: false,
  },
  {
    key: 'create_first_project',
    label: 'Create your first project',
    description: 'Start building something.',
    href: '/projects/new',
    required: true,
  },
  {
    key: 'connect_integration',
    label: 'Connect an integration',
    description: 'Sync with your existing tools.',
    href: '/integrations',
    required: false,
  },
] as const

export type StepKey = typeof ONBOARDING_STEPS[number]['key']
```

```typescript
// lib/onboarding-service.ts — server-side step completion
// Called from within the action that performs the actual work,
// NOT from a separate "mark as done" endpoint

export async function markStepComplete(userId: string, stepKey: StepKey) {
  await db
    .insertInto('onboarding_steps')
    .values({
      user_id: userId,
      step_key: stepKey,
      completed: true,
      completed_at: new Date(),
    })
    .onConflict(oc => oc.columns(['user_id', 'step_key']).doUpdateSet({
      completed: true,
      completed_at: new Date(),
    }))
    .execute()
}

// Example: inside the profile update route handler
// app/api/profile/route.ts
export async function PATCH(req: Request) {
  const user = await getUser(req)
  const data = await req.json()

  await updateProfile(user.id, data)

  // Auto-complete step when action succeeds — not a manual checkbox
  if (data.name && data.avatar_url) {
    await markStepComplete(user.id, 'complete_profile')
  }

  return Response.json({ ok: true })
}
```

```tsx
// OnboardingChecklist.tsx
interface OnboardingChecklistProps {
  steps: Array<{ key: string; completed: boolean; label: string; href: string; required: boolean }>
}

export function OnboardingChecklist({ steps }: OnboardingChecklistProps) {
  const completed = steps.filter(s => s.completed).length
  const total = steps.length
  const pct = Math.round((completed / total) * 100)
  const allDone = pct === 100

  // Collapse the widget after completion (don't remove it — users may want to revisit)
  const [dismissed, setDismissed] = useState(false)

  if (allDone && dismissed) return null

  return (
    <div aria-label="Getting started checklist">
      {/* Progress ring */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <ProgressRing value={pct} size={48} />
        <div>
          <strong>{completed}/{total} complete</strong>
          {allDone && <p>You're all set! <button onClick={() => setDismissed(true)}>Dismiss</button></p>}
        </div>
      </div>

      <ul style={{ listStyle: 'none', padding: 0 }}>
        {steps.map(step => (
          <li key={step.key} style={{ marginBottom: 8 }}>
            <a
              href={step.href}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                opacity: step.completed ? 0.5 : 1,
                // Completed steps still linkable for review, just muted
                textDecoration: step.completed ? 'line-through' : 'none',
                pointerEvents: step.completed ? 'none' : 'auto',
              }}
              aria-disabled={step.completed}
            >
              {/* Visual check — not an interactive checkbox */}
              <span aria-hidden style={{ color: step.completed ? 'green' : '#ccc', fontSize: 18 }}>
                {step.completed ? '✓' : '○'}
              </span>
              <span>{step.label}</span>
              {step.required && !step.completed && (
                <span style={{ fontSize: 11, color: '#888' }}>Required</span>
              )}
            </a>
          </li>
        ))}
      </ul>
    </div>
  )
}
```

```tsx
// ProgressRing.tsx — SVG-based progress ring
function ProgressRing({ value, size = 48 }: { value: number; size?: number }) {
  const r = (size - 4) / 2
  const circumference = 2 * Math.PI * r
  const offset = circumference * (1 - value / 100)

  return (
    <svg width={size} height={size} role="img" aria-label={`${value}% complete`}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="#eee" strokeWidth={3} />
      <circle
        cx={size/2} cy={size/2} r={r}
        fill="none"
        stroke="#22c55e"
        strokeWidth={3}
        strokeDasharray={circumference}
        strokeDashoffset={offset}
        strokeLinecap="round"
        transform={`rotate(-90 ${size/2} ${size/2})`}
        style={{ transition: 'stroke-dashoffset 400ms ease' }}
      />
      <text x="50%" y="50%" textAnchor="middle" dominantBaseline="middle" fontSize={size * 0.25}>
        {value}%
      </text>
    </svg>
  )
}
```

## Key Rules
- Store completion state in the database, not localStorage — must survive device switches and browser clears.
- Auto-complete steps from within the action handler, not via a separate "mark done" endpoint users can game.
- Show a progress percentage ring, not just a list — the visual motivates completion (progress principle).
- Steps link to the action that completes them — each step is an invitation, not just an instruction.
- Required steps should be visually distinguished (e.g., "Required" tag) but don't block access to optional steps.
- Collapse (not remove) the widget after 100% — add a Dismiss button instead of auto-hiding.
- Completed steps should be visually muted (strikethrough, opacity) but still visible — users like to see their history.
- Never use manual checkboxes for onboarding steps — if a user can check without doing, they will.

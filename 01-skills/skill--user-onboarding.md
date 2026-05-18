# Skill: User Onboarding

## What This Covers

New user setup flow after registration: profile creation, preferences, tutorial steps, first-action prompting. Good onboarding reduces churn in the first 24 hours.

## Onboarding State in DB

```sql
CREATE TABLE user_onboarding (
  user_id        UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  step           TEXT NOT NULL DEFAULT 'profile',  -- current step
  completed_at   TIMESTAMPTZ,                       -- NULL = not complete
  profile_done   BOOLEAN DEFAULT FALSE,
  preferences_done BOOLEAN DEFAULT FALSE,
  first_action_done BOOLEAN DEFAULT FALSE,
  created_at     TIMESTAMPTZ DEFAULT now()
);
```

Track individual steps so users can return and complete partially-done onboarding.

## Redirect New Users to Onboarding

```ts
// In middleware or after login callback
const { data: onboarding } = await supabase
  .from('user_onboarding')
  .select('completed_at')
  .eq('user_id', user.id)
  .single()

if (!onboarding?.completed_at) {
  return NextResponse.redirect(`${origin}/onboarding`)
}
```

## Multi-Step Onboarding Component

```tsx
'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'

const STEPS = ['profile', 'preferences', 'first-action'] as const
type Step = typeof STEPS[number]

interface StepConfig {
  title: string
  description: string
}

const STEP_CONFIG: Record<Step, StepConfig> = {
  'profile': {
    title: 'Set up your profile',
    description: 'Add your name and photo',
  },
  'preferences': {
    title: 'Customize your experience',
    description: 'Set your preferences',
  },
  'first-action': {
    title: 'Create your first invoice',
    description: 'Send your first invoice in under 2 minutes',
  },
}

export function OnboardingFlow({ initialStep = 'profile' }: { initialStep: Step }) {
  const [currentStep, setCurrentStep] = useState<Step>(initialStep)
  const [completedSteps, setCompletedSteps] = useState<Set<Step>>(new Set())
  const router = useRouter()

  async function completeStep(step: Step, data?: unknown) {
    await fetch('/api/onboarding/complete-step', {
      method: 'POST',
      body: JSON.stringify({ step, data }),
    })

    setCompletedSteps((prev) => new Set([...prev, step]))

    const nextIdx = STEPS.indexOf(step) + 1
    if (nextIdx < STEPS.length) {
      setCurrentStep(STEPS[nextIdx])
    } else {
      // All done
      await fetch('/api/onboarding/complete', { method: 'POST' })
      router.push('/dashboard?onboarding=complete')
    }
  }

  const currentIdx = STEPS.indexOf(currentStep)

  return (
    <div className="max-w-lg mx-auto py-12">
      {/* Progress bar */}
      <div className="flex items-center gap-2 mb-8">
        {STEPS.map((step, i) => (
          <div key={step} className="flex items-center gap-2">
            <div
              className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium
                ${completedSteps.has(step) ? 'bg-green-500 text-white' :
                  step === currentStep ? 'bg-blue-600 text-white' :
                  'bg-gray-200 text-gray-500'}`}
            >
              {completedSteps.has(step) ? '✓' : i + 1}
            </div>
            {i < STEPS.length - 1 && (
              <div className={`flex-1 h-0.5 ${completedSteps.has(step) ? 'bg-green-500' : 'bg-gray-200'}`} />
            )}
          </div>
        ))}
      </div>

      {/* Step content */}
      <div className="text-center mb-8">
        <h2 className="text-2xl font-bold">{STEP_CONFIG[currentStep].title}</h2>
        <p className="text-gray-600 mt-2">{STEP_CONFIG[currentStep].description}</p>
      </div>

      {currentStep === 'profile' && (
        <ProfileStep onComplete={(data) => completeStep('profile', data)} />
      )}
      {currentStep === 'preferences' && (
        <PreferencesStep onComplete={(data) => completeStep('preferences', data)} />
      )}
      {currentStep === 'first-action' && (
        <FirstActionStep onComplete={() => completeStep('first-action')} onSkip={() => completeStep('first-action')} />
      )}
    </div>
  )
}
```

## First Action Step (Most Important)

The "first action" step is critical — users who complete one core action have 3-5x higher retention:

```tsx
function FirstActionStep({ onComplete, onSkip }: { onComplete: () => void; onSkip: () => void }) {
  return (
    <div className="space-y-4">
      <div className="bg-blue-50 border border-blue-200 rounded-xl p-6 text-center">
        <div className="text-4xl mb-3">🎉</div>
        <h3 className="font-semibold text-lg">Create your first invoice</h3>
        <p className="text-gray-600 mt-2 text-sm">
          Takes less than 2 minutes. We'll walk you through it.
        </p>
        <button onClick={onComplete} className="mt-4 btn-primary w-full">
          Create Invoice
        </button>
      </div>
      <button onClick={onSkip} className="text-sm text-gray-500 w-full text-center hover:underline">
        Skip for now
      </button>
    </div>
  )
}
```

## Completion Handler

```ts
// app/api/onboarding/complete/route.ts
export async function POST(request: NextRequest) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  await supabase
    .from('user_onboarding')
    .update({ completed_at: new Date().toISOString() })
    .eq('user_id', user.id)

  // Optional: send welcome email now that user is fully onboarded
  await sendWelcomeEmail(user.email!)

  return NextResponse.json({ ok: true })
}
```

## Checklist-Style Onboarding (Alternative)

For feature-rich apps, a persistent checklist works better than a linear wizard:

```tsx
// Always-visible onboarding checklist in dashboard
const CHECKLIST_ITEMS = [
  { id: 'profile', label: 'Complete your profile', href: '/settings/profile' },
  { id: 'first-invoice', label: 'Create your first invoice', href: '/invoices/new' },
  { id: 'add-client', label: 'Add a client', href: '/clients/new' },
  { id: 'connect-payment', label: 'Connect payment method', href: '/settings/payments' },
]

function OnboardingChecklist({ completed }: { completed: string[] }) {
  const pct = Math.round((completed.length / CHECKLIST_ITEMS.length) * 100)

  return (
    <div className="bg-white rounded-xl border p-6">
      <div className="flex justify-between mb-4">
        <h3 className="font-semibold">Get started ({pct}%)</h3>
      </div>
      <div className="h-2 bg-gray-100 rounded-full mb-4">
        <div className="h-2 bg-blue-600 rounded-full" style={{ width: `${pct}%` }} />
      </div>
      <ul className="space-y-2">
        {CHECKLIST_ITEMS.map((item) => (
          <li key={item.id} className="flex items-center gap-3">
            <span className={`w-5 h-5 rounded-full flex items-center justify-center text-xs
              ${completed.includes(item.id) ? 'bg-green-500 text-white' : 'border-2 border-gray-300'}`}>
              {completed.includes(item.id) ? '✓' : ''}
            </span>
            <a href={item.href} className="text-sm hover:underline">{item.label}</a>
          </li>
        ))}
      </ul>
    </div>
  )
}
```

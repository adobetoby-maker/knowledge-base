# Multi-Step Wizard Pattern

## When to Use

Multi-step wizards are appropriate when:
- A form has 5+ fields and grouping into steps reduces cognitive load
- Steps have different data dependencies (step 2 options depend on step 1 selection)
- Some steps are optional or conditional

NOT appropriate for:
- Simple forms with 4 or fewer fields — just show them all
- When users need to jump between sections freely (use tabs instead)

## State: Keep Wizard State in URL

URL state makes wizards resumable and shareable:
```
/onboarding?step=2&plan=pro
```

```typescript
'use client'
import { useRouter, useSearchParams, usePathname } from 'next/navigation'

export function useWizard(totalSteps: number) {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()

  const currentStep = parseInt(searchParams.get('step') ?? '1')

  function goToStep(step: number) {
    const params = new URLSearchParams(searchParams.toString())
    params.set('step', String(Math.min(Math.max(step, 1), totalSteps)))
    router.push(`${pathname}?${params.toString()}`)
  }

  const next = () => goToStep(currentStep + 1)
  const prev = () => goToStep(currentStep - 1)

  return { currentStep, next, prev, goToStep, totalSteps }
}
```

## Wizard Shell Component

```typescript
export function WizardShell({ steps }: { steps: WizardStep[] }) {
  const { currentStep, next, prev, totalSteps } = useWizard(steps.length)
  const activeStep = steps[currentStep - 1]

  return (
    <div className="max-w-2xl mx-auto">
      {/* Progress indicator */}
      <div className="mb-8">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm text-muted-foreground">
            Step {currentStep} of {totalSteps}
          </span>
          <span className="text-sm font-medium">{activeStep.title}</span>
        </div>
        <div className="h-2 bg-muted rounded-full">
          <div
            className="h-2 bg-primary rounded-full transition-all"
            style={{ width: `${(currentStep / totalSteps) * 100}%` }}
          />
        </div>
      </div>

      {/* Step content */}
      <div className="mb-8">
        <h2 className="text-2xl font-semibold mb-1">{activeStep.title}</h2>
        {activeStep.description && (
          <p className="text-muted-foreground mb-6">{activeStep.description}</p>
        )}
        <activeStep.component onNext={next} onPrev={prev} />
      </div>

      {/* Navigation */}
      <div className="flex justify-between">
        <button
          onClick={prev}
          disabled={currentStep === 1}
          className="px-4 py-2 border rounded-md disabled:opacity-50"
        >
          Back
        </button>
        {/* Steps control their own Next button to handle validation */}
      </div>
    </div>
  )
}
```

## Step Component Pattern

Each step controls its own validation and Next button:
```typescript
interface StepProps {
  onNext: () => void
  onPrev: () => void
}

function BusinessInfoStep({ onNext }: StepProps) {
  const form = useForm<BusinessInfo>({
    resolver: zodResolver(businessInfoSchema),
  })

  async function handleSubmit(data: BusinessInfo) {
    // Persist to localStorage or server before advancing
    localStorage.setItem('wizard-business', JSON.stringify(data))
    onNext()
  }

  return (
    <form onSubmit={form.handleSubmit(handleSubmit)}>
      <FormField
        control={form.control}
        name="businessName"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Business Name</FormLabel>
            <FormControl><Input {...field} /></FormControl>
            <FormMessage />
          </FormItem>
        )}
      />
      {/* More fields */}
      <div className="flex justify-end mt-6">
        <Button type="submit">Continue</Button>
      </div>
    </form>
  )
}
```

## Persisting Wizard State

For wizards that take multiple sessions to complete, persist state server-side:
```typescript
// Save each step's data as it's completed
async function saveStepData(step: number, data: unknown) {
  await fetch('/api/onboarding/save', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ step, data }),
  })
}

// On return visit, restore position
// app/(onboarding)/page.tsx
export default async function OnboardingPage() {
  const user = await getUser()
  const { data: progress } = await supabase
    .from('onboarding_progress')
    .select('current_step, step_data')
    .eq('user_id', user.id)
    .single()

  // Redirect to the step they left off at
  if (progress) {
    redirect(`/onboarding?step=${progress.current_step}`)
  }
}
```

## Conditional Steps

Skip steps based on earlier selections:
```typescript
function buildSteps(plan: string): WizardStep[] {
  const baseSteps = [accountStep, businessInfoStep]

  if (plan === 'pro') {
    baseSteps.push(billingStep)
  }

  baseSteps.push(confirmationStep)
  return baseSteps
}
```

Recalculate steps when the selection changes. Ensure `useWizard(steps.length)` uses the updated length.

## Final Step: Submit All Data

The last step collects all wizard data and submits to the server:
```typescript
function ConfirmationStep({ onPrev }: StepProps) {
  const searchParams = useSearchParams()
  const [submitting, setSubmitting] = useState(false)

  async function handleConfirm() {
    setSubmitting(true)
    // Gather all data from localStorage or accumulated state
    const allData = {
      business: JSON.parse(localStorage.getItem('wizard-business') ?? '{}'),
      plan: searchParams.get('plan'),
    }
    const result = await createAccount(allData)
    if (result.success) {
      router.push('/portal/dashboard')
    }
    setSubmitting(false)
  }

  return (
    <div>
      {/* Show summary of all steps */}
      <Button onClick={handleConfirm} disabled={submitting}>
        {submitting ? 'Creating account...' : 'Create Account'}
      </Button>
    </div>
  )
}
```

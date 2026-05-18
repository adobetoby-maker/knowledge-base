# Pattern: Stepper Wizard

## When to Use

Multi-step wizard with back/forward navigation, step validation before proceeding, and state preserved across steps. Use for: checkout flows, onboarding (5+ fields), invoice creation with client lookup, any form with 4+ sections.

## State: One Object, Multiple Steps

```tsx
'use client'
import { useState } from 'react'

// Define the complete form shape upfront
interface InvoiceWizardState {
  // Step 1
  clientId: string
  clientName: string
  // Step 2
  lineItems: LineItem[]
  dueDate: string
  // Step 3
  notes: string
  sendImmediately: boolean
}

const INITIAL_STATE: InvoiceWizardState = {
  clientId: '',
  clientName: '',
  lineItems: [],
  dueDate: '',
  notes: '',
  sendImmediately: false,
}

type StepId = 'client' | 'items' | 'review'

const STEPS: { id: StepId; title: string }[] = [
  { id: 'client', title: 'Client' },
  { id: 'items', title: 'Line Items' },
  { id: 'review', title: 'Review & Send' },
]
```

Store all wizard state in a single object — don't split across separate useState calls. Makes serialization (URL state, localStorage) and submission straightforward.

## Wizard Shell

```tsx
export function InvoiceWizard() {
  const [step, setStep] = useState(0)
  const [state, setState] = useState<InvoiceWizardState>(INITIAL_STATE)
  const [submitting, setSubmitting] = useState(false)

  function update(partial: Partial<InvoiceWizardState>) {
    setState((prev) => ({ ...prev, ...partial }))
  }

  function next() {
    setStep((s) => Math.min(s + 1, STEPS.length - 1))
  }

  function back() {
    setStep((s) => Math.max(s - 1, 0))
  }

  async function submit() {
    setSubmitting(true)
    try {
      await createInvoice(state)
      router.push('/invoices?created=true')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="max-w-xl mx-auto">
      {/* Step indicator */}
      <StepIndicator steps={STEPS} currentStep={step} />

      {/* Step content */}
      <div className="mt-8">
        {step === 0 && (
          <ClientStep
            value={{ clientId: state.clientId, clientName: state.clientName }}
            onChange={(v) => update(v)}
            onNext={next}
          />
        )}
        {step === 1 && (
          <LineItemsStep
            value={{ lineItems: state.lineItems, dueDate: state.dueDate }}
            onChange={(v) => update(v)}
            onNext={next}
            onBack={back}
          />
        )}
        {step === 2 && (
          <ReviewStep
            state={state}
            onBack={back}
            onSubmit={submit}
            submitting={submitting}
          />
        )}
      </div>
    </div>
  )
}
```

## Step Component Pattern

Each step owns its own validation:

```tsx
interface ClientStepProps {
  value: { clientId: string; clientName: string }
  onChange: (v: { clientId: string; clientName: string }) => void
  onNext: () => void
}

function ClientStep({ value, onChange, onNext }: ClientStepProps) {
  const [error, setError] = useState('')

  function handleNext() {
    if (!value.clientId) {
      setError('Select a client to continue')
      return
    }
    setError('')
    onNext()
  }

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-semibold">Select a client</h2>

      <ClientSearch
        value={value}
        onChange={onChange}
      />

      {error && <p className="text-red-600 text-sm">{error}</p>}

      <div className="flex justify-end">
        <button onClick={handleNext} className="btn-primary">
          Continue →
        </button>
      </div>
    </div>
  )
}
```

Validate in the step's `handleNext`, not the wizard shell. The step knows its own required fields.

## Step Indicator Component

```tsx
interface StepIndicatorProps {
  steps: { id: string; title: string }[]
  currentStep: number
}

function StepIndicator({ steps, currentStep }: StepIndicatorProps) {
  return (
    <nav aria-label="Progress">
      <ol className="flex items-center">
        {steps.map((step, i) => (
          <li key={step.id} className={`flex items-center ${i < steps.length - 1 ? 'flex-1' : ''}`}>
            <div className="flex items-center gap-2">
              <span
                className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium
                  ${i < currentStep ? 'bg-blue-600 text-white' :
                    i === currentStep ? 'bg-blue-100 text-blue-600 border-2 border-blue-600' :
                    'bg-gray-100 text-gray-400'}`}
                aria-current={i === currentStep ? 'step' : undefined}
              >
                {i < currentStep ? '✓' : i + 1}
              </span>
              <span
                className={`text-sm ${i === currentStep ? 'font-semibold text-gray-900' : 'text-gray-500'}`}
              >
                {step.title}
              </span>
            </div>
            {i < steps.length - 1 && (
              <div className={`flex-1 h-0.5 mx-3 ${i < currentStep ? 'bg-blue-600' : 'bg-gray-200'}`} />
            )}
          </li>
        ))}
      </ol>
    </nav>
  )
}
```

## URL State for Wizard Steps

For wizards where users might refresh or share URLs:

```ts
// Keep step in URL
const searchParams = useSearchParams()
const router = useRouter()

const stepParam = parseInt(searchParams.get('step') ?? '0')
const [step, setStep] = useState(stepParam)

function next() {
  const newStep = step + 1
  setStep(newStep)
  router.push(`?step=${newStep}`, { scroll: false })
}
```

## When NOT to Use a Wizard

- Less than 4 fields: use a single form
- Fields that aren't grouped by theme: use a single long form with sections
- Fields that are all equally important: single form with section dividers (`<hr>` or headings)

Wizards hide information and increase click-through. Only use when the steps have a clear, logical sequence and each step is meaningful on its own.

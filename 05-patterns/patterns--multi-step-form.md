# Multi-Step Form

## When to Use

Use a multi-step form when:
- The form has > 10 fields (split into logical groups reduces cognitive load)
- Some fields depend on previous answers (conditional section flow)
- The process has natural phases (contact info → service selection → confirm)
- Completion rate matters (shorter perceived steps = higher completion)

Keep all fields in one page when:
- < 8 fields and they're all required
- The user expects a simple form (login, contact message)

## Step State Management

```typescript
// State: tracks current step + all form data
interface MultiStepFormState {
  step: number
  data: Partial<FormValues>
}

// Keep form data as user moves between steps — don't reset:
const [state, setState] = useState<MultiStepFormState>({ step: 0, data: {} })

function nextStep(stepData: Partial<FormValues>) {
  setState(prev => ({
    step: prev.step + 1,
    data: { ...prev.data, ...stepData },
  }))
}

function prevStep() {
  setState(prev => ({ ...prev, step: prev.step - 1 }))
}
```

## Step Components

Each step is a self-contained form with its own Zod schema:

```typescript
// schemas.ts
export const Step1Schema = z.object({
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  email: z.string().email(),
})

export const Step2Schema = z.object({
  service: z.enum(['oil-change', 'brakes', 'tires', 'other']),
  vehicleYear: z.coerce.number().min(1990).max(2026),
  vehicleMake: z.string().min(1),
})

export const Step3Schema = z.object({
  preferredDate: z.coerce.date(),
  notes: z.string().optional(),
})

// Combined:
export const AppointmentFormSchema = Step1Schema.merge(Step2Schema).merge(Step3Schema)
```

```typescript
// steps/Step1.tsx
function Step1({ defaultValues, onNext }: { defaultValues: Partial<Step1Values>; onNext: (data: Step1Values) => void }) {
  const form = useForm<Step1Values>({
    resolver: zodResolver(Step1Schema),
    defaultValues,
  })
  
  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onNext)} className="space-y-4">
        <FormField control={form.control} name="firstName" render={({ field }) => (
          <FormItem>
            <FormLabel>First name</FormLabel>
            <FormControl><Input {...field} /></FormControl>
            <FormMessage />
          </FormItem>
        )} />
        {/* more fields */}
        <Button type="submit">Continue</Button>
      </form>
    </Form>
  )
}
```

## Progress Indicator

```typescript
function StepIndicator({ currentStep, totalSteps, labels }: {
  currentStep: number
  totalSteps: number
  labels: string[]
}) {
  return (
    <div className="flex items-center gap-0">
      {labels.map((label, i) => (
        <React.Fragment key={i}>
          <div className="flex flex-col items-center">
            <div className={cn(
              'w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium',
              i < currentStep ? 'bg-primary text-primary-foreground' :
              i === currentStep ? 'bg-primary text-primary-foreground ring-2 ring-primary ring-offset-2' :
              'bg-muted text-muted-foreground'
            )}>
              {i < currentStep ? <Check className="h-4 w-4" /> : i + 1}
            </div>
            <span className="text-xs mt-1 text-muted-foreground">{label}</span>
          </div>
          {i < totalSteps - 1 && (
            <div className={cn('h-0.5 flex-1 mx-2', i < currentStep ? 'bg-primary' : 'bg-border')} />
          )}
        </React.Fragment>
      ))}
    </div>
  )
}
```

## Orchestrating Steps

```typescript
const STEPS = ['Contact', 'Service', 'Schedule', 'Confirm']

export function AppointmentForm() {
  const [state, setState] = useState({ step: 0, data: {} as Partial<AppointmentFormValues> })
  const router = useRouter()
  
  function handleNext(stepData: object) {
    if (state.step < STEPS.length - 2) {
      setState(prev => ({ step: prev.step + 1, data: { ...prev.data, ...stepData } }))
    } else {
      // Last real step — submit:
      handleSubmit({ ...state.data, ...stepData } as AppointmentFormValues)
    }
  }
  
  async function handleSubmit(data: AppointmentFormValues) {
    const result = await createAppointment(data)
    if (result.success) {
      setState(prev => ({ ...prev, step: STEPS.length - 1 }))  // confirmation step
    }
  }
  
  return (
    <div className="max-w-lg mx-auto">
      <StepIndicator currentStep={state.step} totalSteps={STEPS.length} labels={STEPS} />
      <div className="mt-8">
        {state.step === 0 && <Step1 defaultValues={state.data} onNext={handleNext} />}
        {state.step === 1 && <Step2 defaultValues={state.data} onNext={handleNext} onBack={() => setState(prev => ({ ...prev, step: 0 }))} />}
        {state.step === 2 && <Step3 defaultValues={state.data} onNext={handleNext} onBack={() => setState(prev => ({ ...prev, step: 1 }))} />}
        {state.step === 3 && <ConfirmationStep />}
      </div>
    </div>
  )
}
```

## URL-Based Step State

For forms where users might share or bookmark mid-progress, put step in the URL:

```typescript
const searchParams = useSearchParams()
const step = parseInt(searchParams.get('step') ?? '0')

function goToStep(n: number) {
  router.push(`/schedule?step=${n}`, { scroll: false })
}
```

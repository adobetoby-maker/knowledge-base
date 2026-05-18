# Pattern: Multi-Step Wizard Navigation

A step-by-step wizard with progress indicator, per-step validation gates, back navigation that preserves data, and support for both linear and non-linear flows.

## Why Wizards Fail

Most wizard implementations fail in one of three ways:
1. **Back destroys data** — step state lives in the step component, not the parent, so it's destroyed on unmount
2. **No validation gate** — users skip required fields by clicking Next
3. **No progress indicator** — users don't know how many steps remain and abandon midway

All three are architectural decisions made at the start.

## Wizard State Architecture

Every step's data lives at the wizard level. Steps receive their data via props and call back with updates.

```tsx
type WizardData = {
  step1?: Step1Data;
  step2?: Step2Data;
  step3?: Step3Data;
};

type WizardState = {
  currentStep: number;
  data: WizardData;
  visitedSteps: Set<number>; // tracks which steps have been touched
};

function Wizard() {
  const [state, setState] = useState<WizardState>({
    currentStep: 0,
    data: {},
    visitedSteps: new Set([0]),
  });

  const goToStep = (step: number) => {
    setState(s => ({
      ...s,
      currentStep: step,
      visitedSteps: new Set([...s.visitedSteps, step]),
    }));
  };

  const updateData = <K extends keyof WizardData>(key: K, value: WizardData[K]) => {
    setState(s => ({ ...s, data: { ...s.data, [key]: value } }));
  };
```

## Progress Indicator

```tsx
const STEPS = [
  { label: 'Account', description: 'Basic info' },
  { label: 'Profile', description: 'About you' },
  { label: 'Preferences', description: 'Customize' },
  { label: 'Review', description: 'Confirm' },
];

function WizardProgress({ currentStep, visitedSteps, onStepClick, isStepValid }: {
  currentStep: number;
  visitedSteps: Set<number>;
  onStepClick: (step: number) => void;
  isStepValid: (step: number) => boolean;
}) {
  return (
    <nav aria-label="Wizard progress" className="flex items-center gap-0">
      {STEPS.map((step, i) => {
        const isCompleted = visitedSteps.has(i) && isStepValid(i);
        const isCurrent = i === currentStep;
        const isReachable = isCompleted || i === currentStep || (i > 0 && isStepValid(i - 1));

        return (
          <React.Fragment key={i}>
            <button
              onClick={() => isReachable && onStepClick(i)}
              disabled={!isReachable}
              aria-current={isCurrent ? 'step' : undefined}
              className={cn(
                'flex flex-col items-center gap-1',
                isReachable ? 'cursor-pointer' : 'cursor-default opacity-50'
              )}
            >
              <div className={cn(
                'w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium border-2',
                isCurrent && 'border-primary bg-primary text-primary-foreground',
                isCompleted && !isCurrent && 'border-primary bg-primary/10 text-primary',
                !isCurrent && !isCompleted && 'border-muted text-muted-foreground'
              )}>
                {isCompleted ? <CheckIcon size={14} /> : i + 1}
              </div>
              <span className="text-xs hidden sm:block">{step.label}</span>
            </button>
            {i < STEPS.length - 1 && (
              <div className={cn('flex-1 h-0.5 mx-2', isCompleted ? 'bg-primary' : 'bg-muted')} />
            )}
          </React.Fragment>
        );
      })}
    </nav>
  );
}
```

`aria-current="step"` on the active step is the ARIA pattern for wizard navigation.

## Validation Gate

Prevent forward navigation until the current step is valid. Use react-hook-form and expose validity via the `formState`.

```tsx
function Step1({ defaultValues, onComplete }: {
  defaultValues?: Step1Data;
  onComplete: (data: Step1Data) => void;
}) {
  const form = useForm<Step1Data>({
    resolver: zodResolver(Step1Schema),
    defaultValues: defaultValues ?? {},
    mode: 'onChange',
  });

  return (
    <form onSubmit={form.handleSubmit(onComplete)} className="space-y-4">
      {/* fields */}
      <div className="flex justify-end">
        <Button type="submit" disabled={!form.formState.isValid}>
          Continue
        </Button>
      </div>
    </form>
  );
}
```

The step calls `onComplete` only on `handleSubmit`, which runs validation. The button is disabled when the form is invalid. Clicking Continue while invalid triggers inline field errors.

## Back Navigation With Data Preservation

```tsx
function WizardShell() {
  const renderStep = () => {
    switch (state.currentStep) {
      case 0:
        return (
          <Step1
            defaultValues={state.data.step1}  // ← pre-populate from saved data
            onComplete={data => {
              updateData('step1', data);
              goToStep(1);
            }}
          />
        );
      case 1:
        return (
          <Step2
            defaultValues={state.data.step2}  // ← same for every step
            onComplete={data => {
              updateData('step2', data);
              goToStep(2);
            }}
          />
        );
    }
  };

  return (
    <div>
      <WizardProgress ... />
      {renderStep()}
      {state.currentStep > 0 && (
        <Button variant="ghost" onClick={() => goToStep(state.currentStep - 1)}>
          Back
        </Button>
      )}
    </div>
  );
}
```

## Non-Linear vs Linear Flows

**Linear**: Users can only move forward (or one step back). Clicking a completed step label jumps back. This is appropriate for flows where step N depends on step N-1 data.

**Non-Linear**: Users can jump to any visited+valid step. Appropriate when steps are independent (e.g., a settings wizard where each section is self-contained). Implement by checking `isReachable` in the progress indicator and allowing clicks to any valid step.

The `visitedSteps` set enables non-linear navigation: a step is reachable if it's been visited before, regardless of current position.

## Key Rules

- All step data lives in the parent wizard state — step components are controlled
- Pass `defaultValues` from saved state to each step form so back navigation restores fields
- Validate before advancing: use `handleSubmit` which runs the schema validator, not manual checks
- `aria-current="step"` on the active progress step is the correct ARIA attribute
- Track `visitedSteps` separately from `currentStep` to enable non-linear navigation
- The Back button must not re-validate — it navigates unconditionally to the previous step

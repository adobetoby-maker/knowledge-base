# Pattern: Step Progress Tracker

## Overview

Step progress trackers visualize position in a multi-step process (checkout, onboarding, form wizard). They're distinct from `<progress>` bars — each step is named and has a state (completed, current, upcoming). The common mistakes are: not communicating step status to screen readers, not allowing navigation back to completed steps, and coupling the tracker component to the wizard's form state.

## Data Model

Keep the tracker stateless — it receives step definitions and current index, renders accordingly:

```ts
type StepStatus = 'completed' | 'current' | 'upcoming'

type Step = {
  id: string
  label: string
  description?: string  // optional subtitle
}

function getStatus(index: number, currentIndex: number): StepStatus {
  if (index < currentIndex) return 'completed'
  if (index === currentIndex) return 'current'
  return 'upcoming'
}
```

## Component

```tsx
import { CheckIcon } from 'lucide-react'

type StepProgressProps = {
  steps: Step[]
  currentIndex: number
  onStepClick?: (index: number) => void  // if navigation to completed steps is allowed
}

export function StepProgress({ steps, currentIndex, onStepClick }: StepProgressProps) {
  return (
    <nav aria-label="Progress">
      <ol className="step-progress">
        {steps.map((step, index) => {
          const status = getStatus(index, currentIndex)
          const clickable = status === 'completed' && !!onStepClick

          return (
            <li
              key={step.id}
              className={`step step--${status}`}
              aria-current={status === 'current' ? 'step' : undefined}
            >
              <div className="step-connector" aria-hidden="true" />

              <button
                type="button"
                className="step-indicator"
                onClick={clickable ? () => onStepClick(index) : undefined}
                disabled={!clickable}
                aria-label={`${step.label}${status === 'completed' ? ' (completed)' : status === 'current' ? ' (current)' : ' (not started)'}`}
              >
                {status === 'completed' ? (
                  <CheckIcon size={16} aria-hidden="true" />
                ) : (
                  <span aria-hidden="true">{index + 1}</span>
                )}
              </button>

              <div className="step-content">
                <span className="step-label">{step.label}</span>
                {step.description && (
                  <span className="step-description">{step.description}</span>
                )}
              </div>
            </li>
          )
        })}
      </ol>
    </nav>
  )
}
```

**Why `aria-current="step"`:** The ARIA spec defines `aria-current="step"` specifically for progress steps. It's announced by screen readers as "current step." Using `aria-current="page"` is incorrect here; that's for navigation links.

**Why `<nav>` wrapper:** The step tracker is navigational — users can jump to completed steps. Wrapping in `<nav aria-label="Progress">` creates a landmark that screen reader users can jump to directly.

## Styling

```css
.step-progress {
  display: flex;
  align-items: flex-start;
  gap: 0;
  list-style: none;
  padding: 0;
  margin: 0;
}

.step {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
  position: relative;
}

/* Horizontal connector line between steps */
.step-connector {
  position: absolute;
  top: 20px;  /* vertically centered with step indicators */
  left: -50%;
  right: 50%;
  height: 2px;
  background: var(--step-connector-color, #e5e7eb);
}

.step:first-child .step-connector { display: none; }

.step--completed .step-connector {
  background: var(--color-primary, #6366f1);
}

.step-indicator {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2px solid transparent;
  font-weight: 600;
  font-size: 0.875rem;
}

.step--completed .step-indicator {
  background: var(--color-primary);
  color: white;
  cursor: pointer;
}

.step--current .step-indicator {
  border-color: var(--color-primary);
  color: var(--color-primary);
}

.step--upcoming .step-indicator {
  border-color: #e5e7eb;
  color: #9ca3af;
  cursor: default;
}
```

## Vertical Layout

For mobile or side-panel use, swap to vertical:

```css
@media (max-width: 640px) {
  .step-progress {
    flex-direction: column;
    gap: 0;
  }

  .step {
    flex-direction: row;
    align-items: center;
    gap: 1rem;
    flex: unset;
  }

  .step-connector {
    position: absolute;
    left: 19px;  /* center of 40px indicator */
    top: -50%;
    bottom: 50%;
    width: 2px;
    height: auto;
  }
}
```

## Integration with Multi-Step Wizard

```tsx
export function CheckoutWizard() {
  const [currentStep, setCurrentStep] = useState(0)
  const steps = [
    { id: 'cart', label: 'Cart Review' },
    { id: 'shipping', label: 'Shipping' },
    { id: 'payment', label: 'Payment' },
    { id: 'confirm', label: 'Confirmation' },
  ]

  return (
    <div>
      <StepProgress
        steps={steps}
        currentIndex={currentStep}
        onStepClick={i => i < currentStep && setCurrentStep(i)}  // only back navigation
      />
      <StepContent step={steps[currentStep]} onNext={() => setCurrentStep(i => i + 1)} />
    </div>
  )
}
```

Only allow clicking to navigate *backward* — never let users jump ahead past unvisited steps.

## Key Rules

- Use `aria-current="step"` on the current step — `aria-current="page"` is incorrect for this pattern
- Wrap in `<nav aria-label="Progress">` — creates an accessible landmark for screen reader navigation
- Allow back-navigation to completed steps — users need to review/edit earlier choices
- Block forward-jumping — skipping ahead past incomplete steps creates invalid state
- Connector line uses the same color as completed indicators — visual trail of progress
- Keep the component stateless — it receives `currentIndex`, doesn't own step state

# Pattern: Step Completion Indicator

## Overview
Discrete step indicators communicate where a user is in a multi-step process with a precision that a progress bar cannot — a bar says "40% done" while steps say "you're on step 2 of 5 and step 1 is complete." Color progression (gray → active blue → complete green) uses the traffic-light mental model users already have. Completed steps must be clickable to allow edits; locking completed steps frustrates users who catch a mistake on step 4 and need to fix step 2.

## Implementation

### Step Data Model
```tsx
type StepStatus = 'upcoming' | 'active' | 'complete' | 'error'

interface Step {
  id: string
  label: string
  status: StepStatus
  description?: string
}
```

### Status Color Map
```tsx
const STATUS_STYLES: Record<StepStatus, {
  circle: string
  label: string
  line: string
}> = {
  upcoming: {
    circle: 'bg-gray-200 text-gray-500 border-gray-200',
    label: 'text-gray-400',
    line: 'bg-gray-200',
  },
  active: {
    circle: 'bg-blue-600 text-white border-blue-600',
    label: 'text-blue-700 font-semibold',
    line: 'bg-gray-200',
  },
  complete: {
    circle: 'bg-green-600 text-white border-green-600 cursor-pointer hover:bg-green-700',
    label: 'text-gray-700 cursor-pointer',
    line: 'bg-green-500',
  },
  error: {
    circle: 'bg-red-600 text-white border-red-600',
    label: 'text-red-600',
    line: 'bg-gray-200',
  },
}
```

### Step Indicator Component
```tsx
function StepCompletionIndicator({
  steps,
  onStepClick,
}: {
  steps: Step[]
  onStepClick?: (stepId: string) => void
}) {
  const activeRef = useRef<HTMLLIElement>(null)

  // Scroll active step into view on mobile
  useEffect(() => {
    activeRef.current?.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' })
  }, [steps])

  return (
    <nav aria-label="Progress">
      <ol
        role="list"
        className="flex items-center overflow-x-auto gap-0 scrollbar-none"
      >
        {steps.map((step, index) => {
          const styles = STATUS_STYLES[step.status]
          const isComplete = step.status === 'complete'
          const isLast = index === steps.length - 1

          return (
            <li
              key={step.id}
              ref={step.status === 'active' ? activeRef : undefined}
              className="flex items-center min-w-max"
            >
              <div className="flex flex-col items-center gap-1">
                {/* Circle */}
                <button
                  type="button"
                  aria-current={step.status === 'active' ? 'step' : undefined}
                  aria-label={
                    isComplete
                      ? `${step.label} — completed, click to edit`
                      : step.label
                  }
                  disabled={!isComplete}
                  onClick={() => isComplete && onStepClick?.(step.id)}
                  className={[
                    'w-8 h-8 rounded-full border-2 flex items-center justify-center text-sm font-medium transition-colors',
                    styles.circle,
                    !isComplete ? 'cursor-default' : '',
                  ].join(' ')}
                >
                  {step.status === 'complete' ? (
                    <svg aria-hidden="true" className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                    </svg>
                  ) : step.status === 'error' ? (
                    <span aria-hidden="true">!</span>
                  ) : (
                    <span aria-hidden="true">{index + 1}</span>
                  )}
                </button>

                {/* Label */}
                <span
                  className={['text-xs text-center whitespace-nowrap', styles.label].join(' ')}
                >
                  {step.label}
                </span>
              </div>

              {/* Connector line */}
              {!isLast && (
                <div
                  aria-hidden="true"
                  className={['h-0.5 w-12 mx-2 flex-shrink-0', styles.line].join(' ')}
                />
              )}
            </li>
          )
        })}
      </ol>
    </nav>
  )
}
```

### Deriving Step State
```tsx
function deriveSteps(
  definitions: { id: string; label: string }[],
  currentIndex: number,
  completedIds: Set<string>,
  errorIds: Set<string>
): Step[] {
  return definitions.map((def, i) => {
    if (errorIds.has(def.id)) return { ...def, status: 'error' }
    if (completedIds.has(def.id)) return { ...def, status: 'complete' }
    if (i === currentIndex) return { ...def, status: 'active' }
    return { ...def, status: 'upcoming' }
  })
}
```

## Key Rules
- Use discrete numbered steps, not a progress bar — steps tell users exactly where they are and what remains
- Color convention: gray = upcoming, blue = active, green = complete, red = error — do not invent alternatives
- Completed steps must be clickable to return and edit — disable only the active and upcoming ones
- `aria-current="step"` goes on the active step circle — this is the correct ARIA attribute for multi-step navigation
- Scroll the active step into view on mobile — horizontal scroll containers hide steps off-screen on small devices
- Never show a progress percentage alongside steps — it creates conflicting signals
- Step descriptions (optional) appear below the label, not in a tooltip — tooltips don't work on touch devices
- The connector line between steps should fill green only when the left-side step is complete — partial fill is misleading

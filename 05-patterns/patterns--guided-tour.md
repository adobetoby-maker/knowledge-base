# Pattern: Guided Product Tour

## Overview

Onboarding tooltip sequence that highlights UI elements and explains features. Key challenge: positioning tooltips relative to arbitrary target elements across a complex layout. Libraries like `react-joyride` handle this well; a custom implementation needs fixed/absolute positioning with scroll-into-view.

## Using react-joyride

```tsx
import Joyride, { Step, CallBackProps, STATUS } from 'react-joyride'

const TOUR_STEPS: Step[] = [
  {
    target: '[data-tour="create-button"]',
    title: 'Create your first project',
    content: 'Click here to start a new project. You can add team members later.',
    placement: 'bottom',
  },
  {
    target: '[data-tour="sidebar-nav"]',
    title: 'Navigate your workspace',
    content: 'Use the sidebar to switch between projects, settings, and reports.',
    placement: 'right',
  },
  {
    target: '[data-tour="notifications"]',
    title: 'Stay informed',
    content: "You'll get notified here when team members comment or complete tasks.",
    placement: 'bottom-end',
  },
]

function GuidedTour() {
  const [run, setRun] = useState(false)

  // Start tour for new users
  useEffect(() => {
    const seen = localStorage.getItem('tour-completed')
    if (!seen) setRun(true)
  }, [])

  function handleCallback(data: CallBackProps) {
    const { status } = data
    if ([STATUS.FINISHED, STATUS.SKIPPED].includes(status)) {
      localStorage.setItem('tour-completed', 'true')
      setRun(false)
    }
  }

  return (
    <Joyride
      steps={TOUR_STEPS}
      run={run}
      continuous
      showSkipButton
      showProgress
      callback={handleCallback}
      styles={{
        options: {
          primaryColor: '#3b82f6',
          zIndex: 10000,
        },
      }}
    />
  )
}
```

Add `data-tour="..."` attributes to target elements:

```tsx
<button data-tour="create-button" className="btn-primary">
  New Project
</button>
```

## Custom Simple Implementation

For a lightweight in-place tooltip without a library:

```tsx
interface TourStep {
  targetSelector: string
  title: string
  body: string
}

function useTour(steps: TourStep[]) {
  const [stepIndex, setStepIndex] = useState<number | null>(null)
  const [position, setPosition] = useState({ top: 0, left: 0 })

  function start() { setStepIndex(0) }
  function next() { setStepIndex(i => i === null || i >= steps.length - 1 ? null : i + 1) }
  function end() { setStepIndex(null) }

  useEffect(() => {
    if (stepIndex === null) return
    const step = steps[stepIndex]
    const target = document.querySelector(step.targetSelector)
    if (!target) return

    target.scrollIntoView({ block: 'center', behavior: 'smooth' })
    const rect = target.getBoundingClientRect()
    setPosition({ top: rect.bottom + window.scrollY + 8, left: rect.left + window.scrollX })
  }, [stepIndex, steps])

  const currentStep = stepIndex !== null ? steps[stepIndex] : null
  return { start, next, end, currentStep, stepIndex, position, total: steps.length }
}
```

## Persistence

Track which users have completed the tour:

```ts
// Store completion per user, not just per browser
await db.update(users)
  .set({ tourCompletedAt: new Date() })
  .where(eq(users.id, userId))
```

Use DB storage for consistency across devices; use `localStorage` as a fallback for unauthenticated flows.

## Key Rules

- Keep tours short: 3-5 steps maximum. Long tours are abandoned.
- Always include "Skip" option on first step — forcing the tour creates resentment.
- Don't highlight things the user can't interact with yet (disabled buttons, empty states).
- Re-trigger option in settings ("Show me around again") — some users skip and regret it.
- Test with and without the tour target elements visible — tour should handle missing elements gracefully (skip step rather than crash).

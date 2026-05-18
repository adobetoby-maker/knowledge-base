# Pattern: Progress Indicators

## What This Solves

Progress indicators communicate where a user is in a multi-step process (wizard, setup flow, checkout). Three variants: linear progress bar (for processes with known completion %), step indicator (for wizard steps), and indeterminate loading (for unknown duration).

## Step Indicator (Wizard Progress)

```tsx
// components/StepIndicator.tsx
import { Check } from 'lucide-react'
import { cn } from '@/lib/utils'

interface Step {
  label: string
  description?: string
}

interface StepIndicatorProps {
  steps: Step[]
  currentStep: number   // 0-indexed
}

export function StepIndicator({ steps, currentStep }: StepIndicatorProps) {
  return (
    <nav aria-label="Progress">
      <ol className="flex items-center">
        {steps.map((step, index) => {
          const status =
            index < currentStep ? 'complete' :
            index === currentStep ? 'current' : 'upcoming'

          return (
            <li key={step.label} className={cn('flex items-center', index < steps.length - 1 && 'flex-1')}>
              {/* Step circle */}
              <div className="flex flex-col items-center">
                <div
                  className={cn(
                    'flex h-8 w-8 items-center justify-center rounded-full text-sm font-medium',
                    status === 'complete' && 'bg-primary text-primary-foreground',
                    status === 'current' && 'border-2 border-primary bg-background text-primary',
                    status === 'upcoming' && 'border-2 border-muted bg-background text-muted-foreground'
                  )}
                  aria-current={status === 'current' ? 'step' : undefined}
                >
                  {status === 'complete' ? (
                    <Check className="h-4 w-4" aria-hidden />
                  ) : (
                    <span aria-hidden>{index + 1}</span>
                  )}
                  <span className="sr-only">Step {index + 1}: {step.label}{status === 'current' ? ' (current)' : ''}</span>
                </div>
                <span className={cn(
                  'mt-1 text-xs font-medium hidden sm:block',
                  status === 'current' ? 'text-primary' : 'text-muted-foreground'
                )}>
                  {step.label}
                </span>
              </div>

              {/* Connector line between steps */}
              {index < steps.length - 1 && (
                <div
                  className={cn(
                    'mx-2 h-0.5 flex-1',
                    index < currentStep ? 'bg-primary' : 'bg-muted'
                  )}
                  aria-hidden
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

Usage:
```tsx
const STEPS = [
  { label: 'Business info' },
  { label: 'Services' },
  { label: 'Review' },
  { label: 'Publish' },
]

<StepIndicator steps={STEPS} currentStep={1} />
// Shows: ✓ Business info → [2] Services → 3 Review → 4 Publish
```

## Linear Progress Bar

```tsx
// components/ProgressBar.tsx
interface ProgressBarProps {
  value: number      // 0–100
  label?: string
  showPercent?: boolean
  variant?: 'default' | 'success' | 'warning'
  size?: 'sm' | 'md' | 'lg'
}

export function ProgressBar({
  value,
  label,
  showPercent = false,
  variant = 'default',
  size = 'md',
}: ProgressBarProps) {
  const clamped = Math.min(100, Math.max(0, value))

  const heightClass = { sm: 'h-1', md: 'h-2', lg: 'h-3' }[size]
  const colorClass = {
    default: 'bg-primary',
    success: 'bg-green-500',
    warning: 'bg-amber-500',
  }[variant]

  return (
    <div className="space-y-1">
      {(label || showPercent) && (
        <div className="flex justify-between text-sm">
          {label && <span className="text-muted-foreground">{label}</span>}
          {showPercent && <span className="font-medium">{Math.round(clamped)}%</span>}
        </div>
      )}
      <div
        className={cn('w-full rounded-full bg-muted overflow-hidden', heightClass)}
        role="progressbar"
        aria-valuenow={clamped}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={label}
      >
        <div
          className={cn('h-full rounded-full transition-all duration-300', colorClass)}
          style={{ width: `${clamped}%` }}
        />
      </div>
    </div>
  )
}
```

## Upload Progress

```tsx
function UploadProgress({ progress }: { progress: number }) {
  return (
    <div className="space-y-2">
      <ProgressBar
        value={progress}
        label={progress < 100 ? 'Uploading...' : 'Upload complete'}
        showPercent
        variant={progress === 100 ? 'success' : 'default'}
      />
    </div>
  )
}

// Tracking upload progress with XMLHttpRequest (fetch doesn't support progress):
function uploadWithProgress(file: File, url: string, onProgress: (n: number) => void): Promise<void> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.upload.addEventListener('progress', e => {
      if (e.lengthComputable) onProgress((e.loaded / e.total) * 100)
    })
    xhr.addEventListener('load', () => resolve())
    xhr.addEventListener('error', () => reject(new Error('Upload failed')))
    xhr.open('PUT', url)
    xhr.send(file)
  })
}
```

## Indeterminate Progress (Unknown Duration)

Use for operations where you can't report percentage:

```tsx
// Just animate the width back and forth
<div className="h-1 w-full overflow-hidden rounded-full bg-muted">
  <div className="h-full w-1/3 rounded-full bg-primary animate-[indeterminate_1.5s_ease-in-out_infinite]" />
</div>
```

CSS animation:
```css
@keyframes indeterminate {
  0% { transform: translateX(-100%); }
  100% { transform: translateX(400%); }
}
```

Or use shadcn/ui Progress without a `value` prop — it renders an indeterminate state automatically.

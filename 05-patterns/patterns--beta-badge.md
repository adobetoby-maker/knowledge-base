# Pattern: Beta Badge

## Overview
Beta badges signal that a feature is available but may change, inviting user feedback before the feature is finalized. The main risks are: forgetting to remove the badge after the feature stabilizes (badge rot), and applying beta badges to features that are actually production-ready (diluting meaning). Automatic expiry prevents both.

## Implementation

### Badge component with automatic expiry

```tsx
interface BetaBadgeProps {
  expiresAt?: string   // ISO date — badge auto-hides after this
  label?: 'Beta' | 'New' | 'Preview'
  feedbackUrl?: string
  tooltip?: string
}

function BetaBadge({
  expiresAt,
  label = 'Beta',
  feedbackUrl,
  tooltip = 'This feature is in beta — feedback welcome, behavior may change',
}: BetaBadgeProps) {
  // Auto-expire: don't show badge past expiry date
  if (expiresAt && new Date() > new Date(expiresAt)) {
    return null
  }

  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>
          <a
            href={feedbackUrl}
            target="_blank"
            rel="noreferrer"
            onClick={(e) => { if (!feedbackUrl) e.preventDefault() }}
            className="inline-flex items-center rounded-full bg-blue-100 px-2 py-0.5 
                       text-xs font-medium text-blue-700 ring-1 ring-blue-200 
                       hover:bg-blue-200 transition-colors"
          >
            {label}
          </a>
        </TooltipTrigger>
        <TooltipContent>
          <p className="max-w-xs text-xs">{tooltip}</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  )
}
```

### Nav item with badge

```tsx
function NavItem({ href, label, beta }: NavItemProps) {
  return (
    <Link href={href} className="flex items-center gap-2 px-3 py-2 rounded-md hover:bg-gray-100">
      {label}
      {beta && (
        <BetaBadge
          expiresAt={beta.expiresAt}
          feedbackUrl={beta.feedbackUrl}
        />
      )}
    </Link>
  )
}

// Usage — expiry forces a code review when the date passes
<NavItem
  href="/analytics/ai-insights"
  label="AI Insights"
  beta={{ expiresAt: '2026-09-01', feedbackUrl: '/feedback/ai-insights' }}
/>
```

### Feature header with badge

```tsx
function FeatureHeader({ title, description, betaUntil }: Props) {
  return (
    <div>
      <div className="flex items-center gap-3">
        <h1 className="text-2xl font-bold">{title}</h1>
        <BetaBadge expiresAt={betaUntil} feedbackUrl="/feedback" />
      </div>
      <p className="text-gray-500 mt-1">{description}</p>
    </div>
  )
}
```

### Tracking exposure for feedback solicitation

```ts
// Track when a user first encounters a beta feature
function trackBetaExposure(featureKey: string) {
  const key = `beta_exposure_${featureKey}`
  if (!localStorage.getItem(key)) {
    localStorage.setItem(key, new Date().toISOString())
    analytics.track('beta_feature_first_seen', { feature: featureKey })
  }
}

// After N days of exposure, prompt for feedback
function useBetaFeedbackPrompt(featureKey: string, daysBeforePrompt = 7) {
  const [showPrompt, setShowPrompt] = useState(false)

  useEffect(() => {
    const key = `beta_exposure_${featureKey}`
    const firstSeen = localStorage.getItem(key)
    if (!firstSeen) return

    const daysSinceExposure = (Date.now() - new Date(firstSeen).getTime()) / 86400000
    const dismissed = localStorage.getItem(`beta_feedback_dismissed_${featureKey}`)
    
    if (daysSinceExposure >= daysBeforePrompt && !dismissed) {
      setShowPrompt(true)
    }
  }, [featureKey, daysBeforePrompt])

  return { showPrompt, dismiss: () => {
    localStorage.setItem(`beta_feedback_dismissed_${featureKey}`, 'true')
    setShowPrompt(false)
  }}
}
```

## Key Rules
- Always set `expiresAt` — every beta badge must have a planned graduation date
- The expiry date should be in the future and represent a real team commitment to decide
- "Beta" = may change; "New" = recently launched, stable; "Preview" = early access
- Badge links to a feedback form — make it frictionless (pre-filled form, not email)
- Remove the badge from code when the feature graduates — don't just let it auto-expire silently
- Never put a beta badge on payment flows, data deletion, or anything with irreversible effects
- Run a periodic audit (`grep -r 'expiresAt' --include="*.tsx"`) to find expired badge config

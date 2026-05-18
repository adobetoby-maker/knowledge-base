# Pattern: PWA Install Prompt

## Overview

Progressive Web Apps can be installed to the home screen. On Android/Chrome, the browser fires `beforeinstallprompt` which lets you defer and customize when to show the prompt. On iOS Safari, there is no install prompt API — users must be told manually. The failure mode is showing the install banner on every visit, or showing it too soon before the user has seen any value.

## Capturing and Deferring the Prompt

The `beforeinstallprompt` event fires before the browser would show its own install UI. To customize the moment, prevent default and store the event:

```ts
// hooks/useInstallPrompt.ts
export function useInstallPrompt() {
  const [deferredPrompt, setDeferredPrompt] = useState<BeforeInstallPromptEvent | null>(null)
  const [isInstalled, setIsInstalled] = useState(false)

  useEffect(() => {
    // Already installed — running in standalone mode
    if (window.matchMedia('(display-mode: standalone)').matches) {
      setIsInstalled(true)
      return
    }

    function handleBeforeInstall(e: Event) {
      e.preventDefault()  // Suppress browser's default timing
      setDeferredPrompt(e as BeforeInstallPromptEvent)
    }

    function handleAppInstalled() {
      setIsInstalled(true)
      setDeferredPrompt(null)
      localStorage.setItem('pwa-installed', '1')
    }

    window.addEventListener('beforeinstallprompt', handleBeforeInstall)
    window.addEventListener('appinstalled', handleAppInstalled)
    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstall)
      window.removeEventListener('appinstalled', handleAppInstalled)
    }
  }, [])

  async function triggerInstall(): Promise<'accepted' | 'dismissed' | null> {
    if (!deferredPrompt) return null
    deferredPrompt.prompt()
    const { outcome } = await deferredPrompt.userChoice
    setDeferredPrompt(null)
    return outcome
  }

  return { canInstall: Boolean(deferredPrompt), isInstalled, triggerInstall }
}

// TypeScript: BeforeInstallPromptEvent is not in lib.dom.d.ts
interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}
```

## Install Banner Component

Show the banner after a user engagement threshold (not immediately on page load):

```tsx
function InstallBanner() {
  const { canInstall, isInstalled, triggerInstall } = useInstallPrompt()
  const [dismissed, setDismissed] = useState(() =>
    localStorage.getItem('install-banner-dismissed') === '1'
  )
  const [pageViews, setPageViews] = useState(() =>
    Number(sessionStorage.getItem('page-views') ?? 0)
  )

  useEffect(() => {
    const views = pageViews + 1
    setPageViews(views)
    sessionStorage.setItem('page-views', String(views))
  }, [])

  // Show only after 2+ page views and not dismissed
  const shouldShow = canInstall && !isInstalled && !dismissed && pageViews >= 2

  if (!shouldShow) return null

  async function handleInstall() {
    const outcome = await triggerInstall()
    if (outcome === 'dismissed') {
      setDismissed(true)
      localStorage.setItem('install-banner-dismissed', '1')
    }
  }

  function handleDismiss() {
    setDismissed(true)
    localStorage.setItem('install-banner-dismissed', '1')
  }

  return (
    <div role="banner" className="fixed bottom-0 inset-x-0 p-4 bg-white border-t shadow-lg flex items-center gap-3">
      <AppIcon />
      <div className="flex-1">
        <p className="font-medium text-sm">Add to Home Screen</p>
        <p className="text-xs text-gray-500">For the best experience, install the app</p>
      </div>
      <button type="button" onClick={handleInstall} className="bg-blue-600 text-white px-3 py-1.5 rounded text-sm">
        Install
      </button>
      <button type="button" onClick={handleDismiss} aria-label="Dismiss install prompt">
        <XIcon />
      </button>
    </div>
  )
}
```

## iOS Safari: Manual Instructions

iOS Safari doesn't support `beforeinstallprompt`. Detect iOS and show manual steps:

```tsx
function useIsIOS() {
  return /iphone|ipad|ipod/i.test(navigator.userAgent) &&
    !window.MSStream  // rule out Windows Phone
}

function IOSInstallInstructions() {
  const isIOS = useIsIOS()
  const isStandalone = window.matchMedia('(display-mode: standalone)').matches
  const [show, setShow] = useState(false)

  if (!isIOS || isStandalone) return null

  return (
    <>
      <button type="button" onClick={() => setShow(true)}>
        Install App
      </button>
      {show && (
        <div role="dialog" aria-label="How to install">
          <p>To install:</p>
          <ol>
            <li>Tap the Share button <ShareIcon /> in Safari</li>
            <li>Scroll down and tap <strong>"Add to Home Screen"</strong></li>
            <li>Tap <strong>"Add"</strong> in the top right</li>
          </ol>
          <button type="button" onClick={() => setShow(false)}>Done</button>
        </div>
      )}
    </>
  )
}
```

## Already Installed Detection

`(display-mode: standalone)` returns true when the app is running as an installed PWA. Check this before showing any install UI. Also check `localStorage.getItem('pwa-installed')` as a fallback for cases where the media query behaves unexpectedly.

## Key Rules

- Always call `e.preventDefault()` on `beforeinstallprompt` to take control of the timing.
- Never show the install banner on the first page load — show it after meaningful engagement (2+ pages, completed an action).
- Respect dismissal: if the user closes the banner, don't show it again (persist to localStorage).
- iOS requires entirely separate manual instruction UI — `beforeinstallprompt` never fires on iOS Safari.
- Use `window.matchMedia('(display-mode: standalone)')` to detect if the app is already installed before showing any install UI.
- The `BeforeInstallPromptEvent` type must be declared manually — it's not in TypeScript's standard DOM types.

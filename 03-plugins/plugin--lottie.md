# Plugin: Lottie Animations (react-lottie-player)

## Overview

Lottie renders After Effects animations exported as JSON in the browser. Use for high-quality micro-animations, loading states, success/error feedback, and illustrations that need to look polished. File sizes can be large — always check the JSON size before shipping.

## Installation

```bash
npm install @lottiefiles/react-lottie-player
# or the lighter alternative:
npm install lottie-react
```

## Basic Usage

```tsx
import { Player } from '@lottiefiles/react-lottie-player'

// Option A: Local JSON file
import successAnimation from './animations/success.json'

function SuccessState() {
  return (
    <Player
      autoplay
      keepLastFrame  // Pause on final frame instead of looping
      src={successAnimation}
      style={{ height: 200, width: 200 }}
    />
  )
}

// Option B: Remote URL (lazy-load animation data)
function LoadingSpinner() {
  return (
    <Player
      autoplay
      loop
      src="https://assets9.lottiefiles.com/packages/lf20_..."
      style={{ height: 64, width: 64 }}
    />
  )
}
```

## With lottie-react (Smaller Bundle)

```tsx
import Lottie from 'lottie-react'
import loadingData from './loading.json'

function Loading() {
  return <Lottie animationData={loadingData} loop style={{ width: 80, height: 80 }} />
}
```

`lottie-react` is lighter but has fewer controls. Use `@lottiefiles/react-lottie-player` when you need play/pause control.

## Programmatic Control

```tsx
import { Player } from '@lottiefiles/react-lottie-player'
import { useRef } from 'react'

function AnimatedButton() {
  const playerRef = useRef<Player>(null)

  function handleHover() {
    playerRef.current?.play()
  }

  function handleLeave() {
    playerRef.current?.stop()
  }

  return (
    <button onMouseEnter={handleHover} onMouseLeave={handleLeave}>
      <Player
        ref={playerRef}
        src={iconAnimation}
        style={{ width: 24, height: 24 }}
        keepLastFrame
      />
      Submit
    </button>
  )
}
```

## Lazy Loading Large Animations

Don't import large JSON statically if it's below the fold:

```tsx
import { useEffect, useState } from 'react'

function LazyLottie({ src }: { src: string }) {
  const [animationData, setAnimationData] = useState<object | null>(null)

  useEffect(() => {
    fetch(src)
      .then(r => r.json())
      .then(setAnimationData)
  }, [src])

  if (!animationData) return <div className="w-20 h-20 bg-gray-100 rounded animate-pulse" />

  return <Lottie animationData={animationData} loop style={{ width: 80, height: 80 }} />
}
```

## File Size Guidelines

| Animation type | Acceptable size |
|---|---|
| Icon micro-animation | < 20KB |
| Loading spinner | < 50KB |
| Onboarding illustration | < 200KB |
| Hero animation | < 500KB |

Lottie JSON files from LottieFiles marketplace often contain embedded assets (PNG/SVG) that bloat size. Strip these or use `optimizeLottie` to reduce before shipping.

## Fallback for Reduced Motion

```tsx
const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches

// Show static image fallback
if (prefersReduced) return <img src={staticFallback} alt={altText} />
return <Lottie animationData={data} loop />
```

## Key Rules

- Always set an explicit `width`/`height` on the player — without it, Lottie fills its container, which is usually wrong.
- `keepLastFrame` is better than `loop` for success/completion states.
- Lottie files from third-party sites may have fonts embedded as bitmaps — check file size before including.
- Don't use Lottie for loading spinners where a CSS spinner would work — 50KB for a spinner is overkill.

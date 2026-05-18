# Pattern: Hover Video Preview (Thumbnail Play)

## Overview
Hover-to-play video previews appear in content grids (courses, reels, product demos) to convey content without requiring a click. The pattern must solve two competing concerns: start playing quickly enough to feel responsive, without burning bandwidth on videos the user merely passed over. The implementation details — especially `preload="none"`, reset on leave, and the no-autoplay constraint — exist because browsers treat `autoplay` as a strong signal to eagerly load, which defeats the purpose.

## Implementation

### Basic Component
```tsx
import { useRef } from 'react';

interface VideoPreviewProps {
  src: string;
  poster: string;
  alt: string;
  muted?: boolean;
}

function VideoPreview({ src, poster, alt, muted = true }: VideoPreviewProps) {
  const videoRef = useRef<HTMLVideoElement>(null);

  const handleMouseEnter = () => {
    const v = videoRef.current;
    if (!v) return;
    // Play returns a Promise — must handle rejection (e.g., if interrupted)
    v.play().catch(() => {});
  };

  const handleMouseLeave = () => {
    const v = videoRef.current;
    if (!v) return;
    v.pause();
    v.currentTime = 0;
  };

  return (
    <div
      style={{ position: 'relative', cursor: 'pointer' }}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      <video
        ref={videoRef}
        src={src}
        poster={poster}
        muted={muted}
        loop
        playsInline
        preload="none"       // Do not fetch until hover — key to bandwidth control
        aria-label={alt}
        style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
      />
    </div>
  );
}
```

### Touch Device Support
Touch devices have no hover state. Provide tap-to-toggle instead:
```tsx
const [playing, setPlaying] = useState(false);

const handleTap = () => {
  const v = videoRef.current;
  if (!v) return;
  if (playing) {
    v.pause();
    v.currentTime = 0;
    setPlaying(false);
  } else {
    v.play().then(() => setPlaying(true)).catch(() => {});
  }
};

// Use onTouchStart/onTouchEnd for toggle on mobile
// onMouseEnter/onMouseLeave still handle desktop
```

### Intersection Observer for Off-Screen Pause
Pause video when the card scrolls off screen (prevents audio/CPU waste on looping videos):
```tsx
useEffect(() => {
  const v = videoRef.current;
  if (!v) return;
  const observer = new IntersectionObserver(
    ([entry]) => {
      if (!entry.isIntersecting) {
        v.pause();
        v.currentTime = 0;
      }
    },
    { threshold: 0 }
  );
  observer.observe(v);
  return () => observer.disconnect();
}, []);
```

### Preload Strategy: "metadata" vs "none"
- `preload="none"` — nothing fetched until user hovers. Best for grids with many videos.
- `preload="metadata"` — fetches first few KB for duration/dimensions. Useful if you need the aspect ratio before play.
- Never use `preload="auto"` in a grid — the browser may eagerly buffer all videos.

### Avoiding the autoplay Attribute
Do not set `autoplay` attribute. `autoplay` on a video element causes the browser to attempt play on mount, which:
1. Fails on mobile (requires user gesture).
2. Triggers network fetches even with `preload="none"`.
3. Causes battery drain when many cards are rendered.

Instead, call `video.play()` imperatively in the event handler.

### Reduced Motion
```tsx
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

const handleMouseEnter = () => {
  if (prefersReducedMotion) return;
  videoRef.current?.play().catch(() => {});
};
```

## Key Rules
- Always set `muted` — browsers block autoplay with audio; muted play is always allowed.
- Always set `loop` — hover previews that end and show a black frame feel broken.
- Always set `preload="none"` in grids — not `preload="auto"`.
- Reset `currentTime = 0` on mouse leave — next hover starts from the beginning.
- Wrap `play()` in `.catch(() => {})` — it throws if interrupted (user moves mouse quickly).
- `playsInline` is required on iOS — without it, video goes fullscreen.
- Do not call `play()` in the `poster` image load event — poster load is not a user gesture on all browsers.

# Pattern: Video Call Interface

## Overview
Video call UIs fail most often at state synchronization: the UI says "muted" but the track is still live, or a layout shift during speaking detection causes jarring reflows. The browser's media APIs are asynchronous and device-access can fail silently — every state change must be driven by the actual track state, not by optimistic flag-flipping.

## Media Setup

```ts
// Always check track.enabled AFTER getUserMedia resolves — never before
async function initMedia() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { width: 1280, height: 720 },
      audio: true,
    });
    // Store reference to individual tracks, not just the stream
    // Tracks can be individually stopped without killing the stream
    localVideoRef.current.srcObject = stream;
    audioTrackRef.current = stream.getAudioTracks()[0];
    videoTrackRef.current = stream.getVideoTracks()[0];
  } catch (err) {
    // NotAllowedError = user denied, NotFoundError = no device
    // Surface device-specific error messages, not generic "error"
    handleMediaError(err);
  }
}

// Mute by disabling the track — do NOT stop() the track
// stop() releases the device (camera light goes off) and cannot be restarted
// enabled = false keeps the device acquired but sends silence/black frames
function toggleMute() {
  const track = audioTrackRef.current;
  if (!track) return;
  track.enabled = !track.enabled;
  // Derive state from the track, not a separate boolean
  setIsMuted(!track.enabled);
}
```

## Layout: Grid vs Spotlight

```tsx
// Grid layout: all participants equal size
// Spotlight: one participant large, rest in a strip
// Switch based on participant count or when someone is screen-sharing

const isSpotlight = participants.length > 4 || hasActiveSpeaker;

<div
  className={isSpotlight ? 'spotlight-layout' : 'grid-layout'}
  style={{
    // CSS grid adapts automatically — avoid JS-computed sizes
    '--participant-count': participants.length,
  } as React.CSSProperties}
>
  {participants.map(p => (
    <VideoTile
      key={p.id}
      participant={p}
      // Only add speaking border via class, not inline style changes
      // Inline style thrashes layout; a CSS class is cheaper
      isSpeaking={activeSpeakerId === p.id}
      isSpotlighted={spotlightId === p.id}
    />
  ))}
</div>
```

```css
/* Spotlight: large primary, small strip */
.spotlight-layout {
  display: grid;
  grid-template-columns: 1fr 160px;
  grid-template-rows: 1fr;
}

/* Speaking indicator — border, not box-shadow (avoids repaint) */
.video-tile--speaking {
  outline: 3px solid #22c55e;
  outline-offset: -3px;
}
```

## Speaking Detection

```ts
// AudioContext-based volume detection — not WebRTC getStats()
// getStats() is heavy; AudioContext AnalyserNode is cheap and runs off-thread
function createSpeakingDetector(stream: MediaStream, onSpeaking: (v: boolean) => void) {
  const ctx = new AudioContext();
  const source = ctx.createMediaStreamSource(stream);
  const analyser = ctx.createAnalyser();
  analyser.fftSize = 256;
  source.connect(analyser);

  const buf = new Uint8Array(analyser.frequencyBinCount);
  const THRESHOLD = 20; // Tune: below this = silence
  const HYSTERESIS_MS = 800; // Don't flip speaking off immediately

  let speakingTimer: ReturnType<typeof setTimeout>;
  let isSpeaking = false;

  function check() {
    analyser.getByteFrequencyData(buf);
    const avg = buf.reduce((a, b) => a + b, 0) / buf.length;
    if (avg > THRESHOLD && !isSpeaking) {
      isSpeaking = true;
      clearTimeout(speakingTimer);
      onSpeaking(true);
    } else if (avg <= THRESHOLD && isSpeaking) {
      clearTimeout(speakingTimer);
      // Delay turning off to avoid flicker during natural speech pauses
      speakingTimer = setTimeout(() => { isSpeaking = false; onSpeaking(false); }, HYSTERESIS_MS);
    }
    requestAnimationFrame(check);
  }
  check();

  return () => { ctx.close(); clearTimeout(speakingTimer); };
}
```

## End Call Confirmation

```tsx
// Don't end the call on first click — confirm to prevent accidental hangs
// But don't use a modal; use an inline popover on the button
function EndCallButton() {
  const [confirming, setConfirming] = useState(false);

  return confirming ? (
    <div className="end-confirm">
      <span>Leave call?</span>
      <button onClick={endCall}>Leave</button>
      <button onClick={() => setConfirming(false)}>Stay</button>
    </div>
  ) : (
    <button onClick={() => setConfirming(true)} className="btn-end-call">
      End
    </button>
  );
}
```

## Cleanup

```ts
// Always clean up tracks on unmount — omitting this keeps the camera LED on
useEffect(() => {
  return () => {
    localStream?.getTracks().forEach(t => t.stop());
    peerConnection?.close();
  };
}, []);
```

## Key Rules
- Drive mute/video state from `track.enabled`, never from a separate boolean
- Use `track.enabled = false` to mute; use `track.stop()` only on disconnect
- Speaking detection: AudioContext AnalyserNode with hysteresis, not continuous state flips
- Apply speaking border via CSS class, not inline style, to avoid layout thrash
- Confirm before ending; use inline confirm popover, not a full modal
- Always stop all tracks in cleanup — browsers keep camera open until tracks are stopped
- For grid layouts, use CSS grid with custom properties rather than JS-computed sizes

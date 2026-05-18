# Failure: iOS Audio Unlock

iOS Safari blocks audio playback until a user gesture has occurred within the page. This applies to `<audio>` elements, the Web Audio API (`AudioContext`), and any library built on top of these (Tone.js, Howler.js, Web Speech API). The restriction exists to prevent autoplay audio from interrupting phone calls and system audio without the user's consent.

## What Fails Without Unlocking

- `audioContext.state === 'suspended'` on load — audio nodes produce no output.
- `audio.play()` returns a Promise that rejects with `NotAllowedError`.
- Background music set to autoplay never starts.
- Sound effects work on desktop but silently fail on iOS.

The failure is iOS-specific and does not reproduce on Android Chrome or desktop browsers, which makes it easy to ship broken audio and only discover it on real devices.

## Unlocking AudioContext

`AudioContext` starts in `'suspended'` state on iOS. It must be resumed from inside a user gesture handler (touch, click, keydown) — the browser enforces that the resume call traces back synchronously to the event.

```ts
const audioContext = new AudioContext();

async function unlockAudio() {
  if (audioContext.state === 'suspended') {
    await audioContext.resume();
  }
}

document.addEventListener('touchstart', unlockAudio, { once: true });
document.addEventListener('click', unlockAudio, { once: true });
```

`{ once: true }` removes the listener after the first trigger — you only need to unlock once per page load. After `resume()` resolves, `audioContext.state` will be `'running'` and all subsequent audio playback works without further user gestures.

## Unlocking `<audio>` Elements

For `<audio>` elements, the equivalent is to call `.play()` (and immediately `.pause()` if needed) inside a user gesture:

```ts
const audio = document.getElementById('bg-music') as HTMLAudioElement;
let unlocked = false;

function unlockAndPlay() {
  if (unlocked) return;
  unlocked = true;
  audio.play().then(() => {
    audio.pause();    // pause immediately if not ready to start yet
    audio.currentTime = 0;
  }).catch(() => {}); // ignore — already unlocked or unsupported
}

document.addEventListener('touchstart', unlockAndPlay, { once: true });
```

## The Background Music Pattern

Background music that should start from a play button (the correct UX for iOS):

```ts
let audioUnlocked = false;
const bgMusic = new Audio('/music/background.mp3');
bgMusic.loop = true;

playButton.addEventListener('click', () => {
  if (!audioUnlocked) {
    // First tap unlocks AND starts music simultaneously
    audioUnlocked = true;
  }
  bgMusic.play().catch(console.error);
});
```

Key principle: the play button click IS the user gesture. Do not try to start music on page load or on scroll. Design the UX so that the intentional "start music" action also serves as the unlock gesture.

For AudioContext-based music (Web Audio API, Tone.js):

```ts
import * as Tone from 'tone';

playButton.addEventListener('click', async () => {
  await Tone.start(); // Tone.js wraps AudioContext.resume()
  Tone.Transport.start();
});
```

## Detecting iOS for Targeted Handling

Rather than applying unlock logic everywhere, detect iOS and branch:

```ts
const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
  (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

if (isIOS) {
  document.addEventListener('touchstart', unlockAudio, { once: true });
}
```

The second condition catches iPads running iPadOS 13+ which report as `MacIntel`.

## Key Rules

- Never rely on autoplay for audio that must work on iOS — always require a user gesture.
- Resume `AudioContext` in the first user event handler; check `audioContext.state` before resuming.
- Use `{ once: true }` on unlock listeners to avoid repeat calls.
- Design play buttons to double as the unlock gesture — this is idiomatic iOS UX, not a workaround.
- Test on a real iOS device or BrowserStack with device emulation; iOS Simulator does not enforce audio restrictions.
- Third-party audio libraries (Tone.js, Howler.js) have their own unlock wrappers — use them (`Tone.start()`, `Howler.ctx.resume()`) rather than reaching for the raw `AudioContext` API.

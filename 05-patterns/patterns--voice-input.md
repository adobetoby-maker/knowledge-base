# Pattern: Voice Input Button (Web Speech API)

## Problem

Voice input requires a browser feature check (Safari's implementation differs from Chrome's), distinguishing interim from final transcripts, requesting microphone permission with graceful error handling, and visual feedback during the listening state. All of these fail silently without explicit handling.

## Browser Support Check

```ts
const SpeechRecognition =
  (window as any).SpeechRecognition ||
  (window as any).webkitSpeechRecognition;

const isSpeechSupported = Boolean(SpeechRecognition);
```

WHY check both names: Chrome/Edge ship it as `webkitSpeechRecognition`; the standard `SpeechRecognition` exists only in some browsers. Without the fallback, the component crashes on Chrome.

If unsupported, hide the voice button rather than showing a disabled state — an always-disabled affordance is confusing.

## Interim vs Final Results

The API fires `onresult` repeatedly during speech. `event.results[i].isFinal` tells you whether the segment is done. Display interim results as gray/muted placeholder text; only commit final results:

```ts
function handleResult(event: SpeechRecognitionEvent) {
  let interimTranscript = '';
  let finalTranscript = '';

  for (let i = event.resultIndex; i < event.results.length; i++) {
    const result = event.results[i];
    if (result.isFinal) {
      finalTranscript += result[0].transcript;
    } else {
      interimTranscript += result[0].transcript;
    }
  }

  if (finalTranscript) {
    onChange(prev => prev + finalTranscript);
  }
  setInterim(interimTranscript);
}
```

## Error Handling

```ts
recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
  setListening(false);
  setInterim('');

  switch (event.error) {
    case 'not-allowed':
    case 'service-not-allowed':
      setError('Microphone access denied. Check your browser permissions.');
      break;
    case 'no-speech':
      setError('No speech detected. Try again.');
      break;
    case 'network':
      setError('Network error. Check your connection.');
      break;
    default:
      setError('Voice input failed. Please type instead.');
  }
};
```

WHY handle `not-allowed` specifically: it's the most common failure and needs a user-actionable message. Generic "failed" messages leave users stuck.

## Full Hook

```tsx
function useVoiceInput(onChange: (val: string) => void) {
  const [listening, setListening] = useState(false);
  const [interim, setInterim] = useState('');
  const [error, setError] = useState<string | null>(null);
  const recRef = useRef<any>(null);

  function start() {
    if (!SpeechRecognition) return;
    setError(null);

    const rec = new SpeechRecognition();
    rec.continuous = false;
    rec.interimResults = true;
    rec.lang = 'en-US';

    rec.onstart = () => setListening(true);
    rec.onend   = () => { setListening(false); setInterim(''); };
    rec.onresult = handleResult;
    rec.onerror = (e: any) => handleError(e, setListening, setInterim, setError);

    recRef.current = rec;
    rec.start();
  }

  function stop() {
    recRef.current?.stop();
  }

  return { listening, interim, error, start, stop, supported: isSpeechSupported };
}
```

## Visual Feedback

```tsx
function VoiceInputButton({ onTranscript }: { onTranscript: (s: string) => void }) {
  const { listening, interim, error, start, stop, supported } = useVoiceInput(onTranscript);

  if (!supported) return null;

  return (
    <div>
      <button
        type="button"
        onClick={listening ? stop : start}
        aria-label={listening ? 'Stop voice input' : 'Start voice input'}
        className={listening ? 'animate-pulse text-red-500' : 'text-gray-400'}
      >
        🎤
      </button>
      {interim && <span className="text-gray-400 italic text-sm">{interim}</span>}
      {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
    </div>
  );
}
```

## Key Rules

- Check both `window.SpeechRecognition` and `window.webkitSpeechRecognition`; hide the button if unsupported
- Display interim results as muted/italic placeholder text; only commit `isFinal` transcripts to state
- Handle `not-allowed`, `no-speech`, and `network` errors with actionable messages
- `animate-pulse` or a pulsing ring gives clear visual feedback that the mic is active
- Use `role="alert"` on error messages so screen readers announce them immediately

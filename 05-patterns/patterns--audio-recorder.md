# Pattern: Audio Recorder

## Overview

Record audio from the microphone using MediaRecorder API. Common uses: voice memos, dictation, voice messages. Same stream/permission pattern as webcam — always stop tracks on unmount, handle permission denial gracefully.

## Core Implementation

```tsx
type RecorderState = 'idle' | 'requesting' | 'recording' | 'stopped' | 'denied'

interface AudioRecording {
  blob: Blob
  url: string
  duration: number  // seconds
}

function AudioRecorder({ onComplete }: { onComplete: (recording: AudioRecording) => void }) {
  const [state, setState] = useState<RecorderState>('idle')
  const [duration, setDuration] = useState(0)
  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const chunksRef = useRef<Blob[]>([])
  const streamRef = useRef<MediaStream | null>(null)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const startTimeRef = useRef(0)

  useEffect(() => () => {
    stopStream()
    if (timerRef.current) clearInterval(timerRef.current)
  }, [])

  function stopStream() {
    streamRef.current?.getTracks().forEach(t => t.stop())
    streamRef.current = null
  }

  async function startRecording() {
    setState('requesting')
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      streamRef.current = stream

      const mimeType = getSupportedMimeType()
      const recorder = new MediaRecorder(stream, { mimeType })
      mediaRecorderRef.current = recorder
      chunksRef.current = []

      recorder.ondataavailable = e => {
        if (e.data.size > 0) chunksRef.current.push(e.data)
      }

      recorder.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: mimeType })
        const url = URL.createObjectURL(blob)
        onComplete({ blob, url, duration: Math.round((Date.now() - startTimeRef.current) / 1000) })
        stopStream()
        setState('stopped')
      }

      recorder.start(250)  // ondataavailable every 250ms for real-time upload option
      startTimeRef.current = Date.now()

      timerRef.current = setInterval(() => {
        setDuration(Math.floor((Date.now() - startTimeRef.current) / 1000))
      }, 1000)

      setState('recording')
    } catch (err) {
      if (err instanceof DOMException && err.name === 'NotAllowedError') {
        setState('denied')
      } else {
        setState('idle')
      }
    }
  }

  function stopRecording() {
    if (timerRef.current) clearInterval(timerRef.current)
    mediaRecorderRef.current?.stop()
  }

  function getSupportedMimeType(): string {
    const types = ['audio/webm;codecs=opus', 'audio/webm', 'audio/ogg', 'audio/mp4']
    return types.find(t => MediaRecorder.isTypeSupported(t)) ?? ''
  }

  if (state === 'denied') {
    return <p className="text-sm text-red-600">Microphone access denied. Check browser settings.</p>
  }

  return (
    <div className="flex items-center gap-3">
      {state === 'idle' && (
        <button onClick={startRecording} className="btn-primary flex items-center gap-2">
          🎙 Record
        </button>
      )}
      {state === 'recording' && (
        <>
          <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
          <span className="font-mono text-sm">{formatDuration(duration)}</span>
          <button onClick={stopRecording} className="btn-secondary">Stop</button>
        </>
      )}
      {state === 'requesting' && <span className="text-sm text-gray-500">Requesting mic...</span>}
    </div>
  )
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60).toString().padStart(2, '0')
  const s = (seconds % 60).toString().padStart(2, '0')
  return `${m}:${s}`
}
```

## Audio Playback

```tsx
function AudioPlayer({ url }: { url: string }) {
  return (
    <audio controls src={url} className="w-full">
      Your browser does not support audio playback.
    </audio>
  )
}
```

The native `<audio>` element with `controls` covers all use cases — don't build a custom player unless brand requirements demand it.

## Upload After Recording

```ts
async function uploadRecording(blob: Blob): Promise<string> {
  const formData = new FormData()
  formData.append('audio', blob, `recording-${Date.now()}.webm`)
  
  const res = await fetch('/api/recordings/upload', {
    method: 'POST',
    body: formData,
  })
  const { url } = await res.json()
  return url
}
```

## Key Rules

- `audio/webm;codecs=opus` is highest quality with smallest file size; not supported on Safari — always fall back through multiple types.
- Collect data every 250ms (`recorder.start(250)`) to enable real-time streaming upload if needed.
- Maximum recording length: enforce a hard limit (e.g., 5 minutes) to prevent runaway recordings.
- Revoke `URL.createObjectURL` URLs when done: `URL.revokeObjectURL(url)` to free memory.

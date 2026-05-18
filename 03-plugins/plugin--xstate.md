# Plugin: XState

## Overview

XState is a finite state machine library for managing complex UI state that has too many boolean flags. If you have more than 3 `isLoading / isError / isSuccess / isRetrying` flags, they're probably a state machine in disguise. XState v5 is a significant rewrite — use `createMachine` + `useMachine` from `@xstate/react`.

## When to Use

**Good fit:**
- Multi-step forms or wizards
- Upload flow with retry, progress, and cancel
- Authentication flow (idle → checking → authenticated → logging out)
- Media player (idle → buffering → playing → paused → ended)
- Long-running async operations with multiple states

**Skip XState for:**
- Simple toggle/boolean state
- Server state (use TanStack Query instead)
- Global app state without transitions (use Zustand or Jotai)

## Installation

```bash
npm install xstate @xstate/react
```

## Basic Machine

```ts
import { createMachine, assign } from 'xstate'

interface UploadContext {
  file: File | null
  progress: number
  error: string | null
  uploadedUrl: string | null
}

const uploadMachine = createMachine({
  id: 'upload',
  initial: 'idle',
  context: {
    file: null,
    progress: 0,
    error: null,
    uploadedUrl: null,
  } as UploadContext,

  states: {
    idle: {
      on: {
        SELECT_FILE: {
          target: 'selected',
          actions: assign({ file: ({ event }) => event.file }),
        },
      },
    },
    selected: {
      on: {
        UPLOAD:  { target: 'uploading' },
        CLEAR:   { target: 'idle', actions: assign({ file: null }) },
      },
    },
    uploading: {
      on: {
        PROGRESS: { actions: assign({ progress: ({ event }) => event.progress }) },
        SUCCESS:  {
          target: 'success',
          actions: assign({ uploadedUrl: ({ event }) => event.url, progress: 100 }),
        },
        ERROR: {
          target: 'error',
          actions: assign({ error: ({ event }) => event.message }),
        },
        CANCEL: { target: 'idle', actions: assign({ file: null, progress: 0 }) },
      },
    },
    success: {
      on: {
        RESET: { target: 'idle', actions: assign({ file: null, progress: 0, uploadedUrl: null }) },
      },
    },
    error: {
      on: {
        RETRY:  { target: 'uploading', actions: assign({ error: null, progress: 0 }) },
        CANCEL: { target: 'idle', actions: assign({ file: null, error: null }) },
      },
    },
  },
})
```

## In React with useMachine

```tsx
import { useMachine } from '@xstate/react'

export function FileUploader() {
  const [state, send] = useMachine(uploadMachine)
  const { file, progress, error, uploadedUrl } = state.context

  const handleUpload = async () => {
    if (!file) return
    send({ type: 'UPLOAD' })

    try {
      await uploadFile(file, {
        onProgress: (pct) => send({ type: 'PROGRESS', progress: pct }),
      })
      const url = await getUploadUrl(file.name)
      send({ type: 'SUCCESS', url })
    } catch (err) {
      send({ type: 'ERROR', message: (err as Error).message })
    }
  }

  return (
    <div>
      {state.matches('idle') && (
        <input type="file" onChange={e => {
          const f = e.target.files?.[0]
          if (f) send({ type: 'SELECT_FILE', file: f })
        }} />
      )}

      {state.matches('selected') && (
        <div>
          <p>{file?.name}</p>
          <button onClick={handleUpload}>Upload</button>
          <button onClick={() => send({ type: 'CLEAR' })}>Cancel</button>
        </div>
      )}

      {state.matches('uploading') && (
        <div>
          <progress value={progress} max={100} />
          <button onClick={() => send({ type: 'CANCEL' })}>Cancel</button>
        </div>
      )}

      {state.matches('success') && (
        <div>
          <a href={uploadedUrl!}>View file</a>
          <button onClick={() => send({ type: 'RESET' })}>Upload another</button>
        </div>
      )}

      {state.matches('error') && (
        <div>
          <p className="text-red-600">{error}</p>
          <button onClick={() => send({ type: 'RETRY' })}>Retry</button>
          <button onClick={() => send({ type: 'CANCEL' })}>Cancel</button>
        </div>
      )}
    </div>
  )
}
```

## Guards (Conditional Transitions)

```ts
states: {
  selected: {
    on: {
      UPLOAD: {
        target: 'uploading',
        guard: ({ context }) => context.file !== null && context.file.size < 50_000_000,
      },
    },
  },
}
```

## Key Rules

- State machines eliminate impossible states — you can't be `isLoading && isError && isSuccess` simultaneously.
- Define all valid transitions explicitly — anything not defined is ignored, which prevents accidental state bugs.
- `context` holds data; `state` holds the current node — keep business data in context, not state name.
- Use `state.matches('uploading')` not `state.value === 'uploading'` — `matches` handles nested states.
- XState v5 breaking changes from v4: `assign` takes a function, `send` is second element of `useMachine`, `context` is typed via generics.

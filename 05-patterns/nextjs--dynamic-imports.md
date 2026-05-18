# Next.js — Dynamic Imports

**When:** A component uses browser-only APIs, is large and not needed immediately, or crashes during SSR.
**Rule:** Use dynamic imports with `ssr: false` for browser-only code. Use without `ssr: false` for code-splitting large components.

## The Two Use Cases

### Use Case 1: Browser-Only Code (requires ssr: false)
Some libraries use `window`, `document`, `localStorage`, or WebGL — they don't exist on the server.
If you import them normally, SSR crashes.

```typescript
import dynamic from 'next/dynamic'

// THREE.js, chart libraries, map components, GSAP with DOM refs
const Map = dynamic(() => import('./MapComponent'), { ssr: false })
const Chart = dynamic(() => import('./ChartComponent'), { ssr: false })
const ThreeScene = dynamic(() => import('./ThreeScene'), { ssr: false })

// The component won't render server-side — shows loading state until client hydrates
export default function Page() {
  return <Map />  // works — no SSR crash
}
```

### Use Case 2: Code Splitting (no ssr: false)
Large components that aren't needed on first load can be split into separate chunks.
Browser downloads them only when needed.

```typescript
const HeavyEditor = dynamic(() => import('./HeavyEditor'), {
  loading: () => <div>Loading editor...</div>
})

// Only loads the editor bundle when the user opens it
function Page() {
  const [showEditor, setShowEditor] = useState(false)
  return (
    <>
      <button onClick={() => setShowEditor(true)}>Open Editor</button>
      {showEditor && <HeavyEditor />}
    </>
  )
}
```

## The Loading State
Always provide a loading state to prevent layout shift:
```typescript
const Map = dynamic(() => import('./Map'), {
  ssr: false,
  loading: () => <div style={{ height: 400, background: '#f3f4f6' }} />
  // Placeholder matches the component's approximate size — prevents CLS
})
```

## Named Exports
```typescript
// Component uses named export
const { FeatureComponent } = dynamic(
  () => import('./features').then(mod => ({ default: mod.FeatureComponent }))
)
```

## Common Failure Mode
```typescript
// WRONG — crashes SSR because window is accessed at module level
import Chart from 'chart.js'  // accesses window immediately

// RIGHT — delay import until client
const Chart = dynamic(() => import('./ChartWrapper'), { ssr: false })
// ChartWrapper.tsx imports chart.js internally
```

## When NOT to Use
Don't dynamic import small components (< 10kb). The overhead of the extra network request often outweighs the savings.
Dynamic imports add a network round trip — only worth it for chunks > ~50kb.

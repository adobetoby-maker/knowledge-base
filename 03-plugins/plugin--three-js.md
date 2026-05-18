# Three.js / React Three Fiber

## When to Use

Three.js (via `@react-three/fiber`) is used in `orthobiologic-pathways` for 3D medical visualizations. Use for:
- 3D product/anatomical visualizations
- Interactive 3D scenes
- Particle effects and immersive backgrounds

For simple CSS animations or scroll effects, use Framer Motion instead.

## Installation

```bash
npm install three @react-three/fiber @react-three/drei
npm install -D @types/three
```

## Basic 3D Scene

```typescript
'use client'
import { Canvas } from '@react-three/fiber'
import { OrbitControls, Environment } from '@react-three/drei'

export function Scene3D() {
  return (
    <Canvas
      camera={{ position: [0, 0, 5], fov: 45 }}
      style={{ height: '100vh' }}
    >
      {/* Lighting */}
      <ambientLight intensity={0.5} />
      <directionalLight position={[10, 10, 5]} intensity={1} />
      
      {/* Environment (background + lighting from HDRI) */}
      <Environment preset="studio" />
      
      {/* Camera controls */}
      <OrbitControls enableZoom={false} autoRotate autoRotateSpeed={0.5} />
      
      {/* Your 3D content */}
      <mesh>
        <sphereGeometry args={[1, 32, 32]} />
        <meshStandardMaterial color="#4f46e5" roughness={0.3} metalness={0.7} />
      </mesh>
    </Canvas>
  )
}
```

## Loading 3D Models (GLTF)

```typescript
'use client'
import { useGLTF, Stage } from '@react-three/drei'
import { Canvas } from '@react-three/fiber'
import { Suspense } from 'react'

function Model({ url }: { url: string }) {
  const { scene } = useGLTF(url)
  return <primitive object={scene} />
}

export function ModelViewer({ modelUrl }: { modelUrl: string }) {
  return (
    <Canvas>
      <Suspense fallback={null}>
        <Stage environment="studio" intensity={0.6}>
          <Model url={modelUrl} />
        </Stage>
      </Suspense>
    </Canvas>
  )
}
```

`Suspense` is required when loading async resources (GLTF files). Without it, the component throws during the loading phase.

## Animations with useFrame

```typescript
'use client'
import { useFrame, useRef } from '@react-three/fiber'
import type { Mesh } from 'three'

function RotatingMesh() {
  const meshRef = useRef<Mesh>(null)

  useFrame((_, delta) => {
    if (!meshRef.current) return
    meshRef.current.rotation.y += delta * 0.5  // rotate 0.5 rad/sec
  })

  return (
    <mesh ref={meshRef}>
      <boxGeometry args={[1, 1, 1]} />
      <meshStandardMaterial color="orange" />
    </mesh>
  )
}
```

`delta` is the time since last frame in seconds — always multiply rotation by `delta` for frame-rate-independent animation.

## Particles

```typescript
'use client'
import { Points, PointMaterial } from '@react-three/drei'
import { useMemo } from 'react'

function Particles({ count = 5000 }: { count?: number }) {
  const positions = useMemo(() => {
    const arr = new Float32Array(count * 3)
    for (let i = 0; i < count; i++) {
      arr[i * 3] = (Math.random() - 0.5) * 10
      arr[i * 3 + 1] = (Math.random() - 0.5) * 10
      arr[i * 3 + 2] = (Math.random() - 0.5) * 10
    }
    return arr
  }, [count])

  return (
    <Points positions={positions} stride={3}>
      <PointMaterial
        transparent
        color="#888"
        size={0.02}
        sizeAttenuation
        depthWrite={false}
      />
    </Points>
  )
}
```

## Performance

- Use `instancedMesh` for many identical objects (not separate `<mesh>` for each)
- `useMemo` for geometry and material to prevent recreation on each render
- `Canvas` has `dpr` (device pixel ratio) — cap it: `dpr={[1, 2]}`
- Dispose of geometry/material on unmount to prevent GPU memory leaks:

```typescript
useEffect(() => {
  return () => {
    geometry.dispose()
    material.dispose()
  }
}, [])
```

## orthobiologic-pathways Stack

```typescript
// Uses Three.js + Framer Motion together
// Three.js: 3D anatomical models
// Framer Motion: page transitions and 2D UI animations
// react-three/drei: helpers (Stage, Environment, OrbitControls, Html)

// Three.js canvas fills a section, not the full page
// <Canvas> inside a <div> with defined height
```

## SSR Compatibility

Three.js requires the browser's WebGL context — it cannot run on the server. Lazy-load with `next/dynamic` and `ssr: false`:

```typescript
import dynamic from 'next/dynamic'

const Scene3D = dynamic(() => import('@/components/Scene3D'), {
  ssr: false,
  loading: () => <div className="h-[500px] bg-black animate-pulse" />,
})
```

Without `ssr: false`, the server render crashes because `window` and `WebGLRenderingContext` don't exist.

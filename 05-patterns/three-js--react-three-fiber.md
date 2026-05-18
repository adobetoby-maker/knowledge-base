# React Three Fiber (3D in React)

**When:** Adding 3D graphics to a React application. Used in orthobiologic-pathways for 3D medical visualizations.
**Rule:** Three.js is large (~600KB). Always lazy load with `ssr: false`. Never import it in Server Components.

## Installation
```bash
npm install three @react-three/fiber @react-three/drei
npm install -D @types/three
```

## Basic 3D Scene
```typescript
'use client'
import { Canvas } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'

function RotatingBox() {
  return (
    <mesh rotation={[0, Math.PI / 4, 0]}>
      <boxGeometry args={[1, 1, 1]} />
      <meshStandardMaterial color="hotpink" />
    </mesh>
  )
}

export function Scene3D() {
  return (
    <Canvas camera={{ position: [0, 0, 5], fov: 45 }}>
      <ambientLight intensity={0.5} />
      <directionalLight position={[10, 10, 5]} intensity={1} />
      <RotatingBox />
      <OrbitControls />  {/* allows user to orbit around scene */}
    </Canvas>
  )
}
```

## CRITICAL: Lazy Load in Next.js
Three.js MUST be lazy loaded — it uses browser APIs not available on server:
```typescript
// page.tsx or wherever you use it
import dynamic from 'next/dynamic'

const Scene3D = dynamic(
  () => import('./Scene3D'),
  {
    ssr: false,  // REQUIRED — Three.js won't work with SSR
    loading: () => <div className="flex h-96 items-center justify-center">
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
    </div>
  }
)
```

## Animation with useFrame
```typescript
import { useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import type { Mesh } from 'three'

function AnimatedSphere() {
  const meshRef = useRef<Mesh>(null)
  
  useFrame((state, delta) => {
    if (!meshRef.current) return
    meshRef.current.rotation.y += delta * 0.5  // smooth 60fps rotation
  })
  
  return (
    <mesh ref={meshRef}>
      <sphereGeometry args={[1, 32, 32]} />
      <meshStandardMaterial color="#3b82f6" metalness={0.3} roughness={0.4} />
    </mesh>
  )
}
```

## Useful @react-three/drei Helpers
```typescript
import { 
  OrbitControls,    // user-controlled camera orbit
  PerspectiveCamera, // camera component
  Environment,      // HDR environment for reflections
  Text,             // 3D text rendering
  Sphere, Box, Cylinder,  // ready-made shapes
  Html,             // render HTML inside 3D scene
  useGLTF,          // load GLTF/GLB 3D model files
  useTexture,       // load textures
  Float,            // gentle floating animation
} from '@react-three/drei'
```

## Loading a 3D Model
```typescript
import { useGLTF } from '@react-three/drei'

function HumanBody({ part = 'knee' }: { part: string }) {
  const { scene } = useGLTF(`/models/${part}.glb`)
  return <primitive object={scene} />
}

// Preload the model
useGLTF.preload('/models/knee.glb')
```

## Performance Notes
- Three.js canvas renders 60fps — each frame runs your JavaScript
- Keep `useFrame` callbacks fast — avoid allocation (new Vector3() etc) inside them
- Use `dispose()` when removing geometries/materials: `mesh.geometry.dispose()`
- Use `<Suspense>` to handle async model loading
- Canvas pixel ratio: `<Canvas dpr={[1, 2]}>` — caps at 2x for retina (don't go higher)

## Where Used
`/Users/drive/orthobiologic-pathways` — see `components/` for 3D anatomical viewer patterns specific to that project.

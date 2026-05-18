# Plugin: Konva (react-konva)

## Overview

Konva is a canvas library for React. It provides a declarative API over the HTML5 canvas — `Layer`, `Group`, `Rect`, `Circle`, `Text`, `Image`, `Line`, `Transformer`. Use it when you need interactive canvas: drag/drop shapes, resize handles, custom drawing tools, image editors, whiteboard.

## Install

```bash
npm install konva react-konva
```

## Basic Stage

```tsx
import { Stage, Layer, Rect, Circle, Text } from 'react-konva'

export function CanvasEditor() {
  return (
    <Stage width={window.innerWidth} height={window.innerHeight}>
      <Layer>
        <Rect
          x={50}
          y={50}
          width={100}
          height={80}
          fill="#3b82f6"
          cornerRadius={4}
          draggable
        />
        <Circle
          x={250}
          y={100}
          radius={50}
          fill="#10b981"
          draggable
        />
        <Text
          x={50}
          y={180}
          text="Hello, Konva"
          fontSize={20}
          fill="#111827"
        />
      </Layer>
    </Stage>
  )
}
```

## Draggable Shapes with State

```tsx
interface ShapeData {
  id: string
  x: number
  y: number
  width: number
  height: number
  fill: string
}

function DraggableRect({ shape, onDragEnd }: { shape: ShapeData; onDragEnd: (id: string, x: number, y: number) => void }) {
  return (
    <Rect
      id={shape.id}
      x={shape.x}
      y={shape.y}
      width={shape.width}
      height={shape.height}
      fill={shape.fill}
      draggable
      onDragEnd={(e) => onDragEnd(shape.id, e.target.x(), e.target.y())}
    />
  )
}
```

## Selection + Transformer

```tsx
import { Transformer } from 'react-konva'

function SelectableShape({ shapeId, isSelected, onSelect }: SelectableShapeProps) {
  const shapeRef = useRef<Konva.Rect>(null)
  const transformerRef = useRef<Konva.Transformer>(null)

  useEffect(() => {
    if (isSelected && transformerRef.current && shapeRef.current) {
      transformerRef.current.nodes([shapeRef.current])
      transformerRef.current.getLayer()?.batchDraw()
    }
  }, [isSelected])

  return (
    <>
      <Rect
        ref={shapeRef}
        onClick={onSelect}
        onTap={onSelect}
        {...shapeProps}
        draggable
      />
      {isSelected && <Transformer ref={transformerRef} />}
    </>
  )
}
```

Transformer provides resize handles automatically — attach it to any node to enable resize/rotate.

## Image Display

```tsx
import { Image as KonvaImage } from 'react-konva'
import useImage from 'use-image'

function CanvasImage({ src, x, y }: { src: string; x: number; y: number }) {
  const [image, status] = useImage(src)
  if (status !== 'loaded') return null

  return (
    <KonvaImage
      image={image}
      x={x}
      y={y}
      width={200}
      height={150}
      draggable
    />
  )
}
```

`use-image` handles the async image loading — returns the HTMLImageElement once loaded. Never pass a raw URL string to Konva's `image` prop.

## Export Canvas to Image

```ts
const stageRef = useRef<Konva.Stage>(null)

function exportToPng() {
  if (!stageRef.current) return
  const uri = stageRef.current.toDataURL({ pixelRatio: 2 })  // 2x for retina
  const link = document.createElement('a')
  link.download = 'canvas.png'
  link.href = uri
  link.click()
}

<Stage ref={stageRef} ...>
```

## Responsive Stage

```tsx
function ResponsiveStage({ children }: { children: React.ReactNode }) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [size, setSize] = useState({ width: 800, height: 600 })

  useEffect(() => {
    const observer = new ResizeObserver(entries => {
      const { width, height } = entries[0].contentRect
      setSize({ width, height })
    })
    if (containerRef.current) observer.observe(containerRef.current)
    return () => observer.disconnect()
  }, [])

  return (
    <div ref={containerRef} style={{ width: '100%', height: '100%' }}>
      <Stage width={size.width} height={size.height}>
        {children}
      </Stage>
    </div>
  )
}
```

## Key Rules

- `Stage` requires explicit `width` and `height` — it does not respond to CSS sizing. Use ResizeObserver to sync with container dimensions.
- Always wrap shapes in a `Layer` — shapes rendered directly in `Stage` are invisible.
- `use-image` is the correct way to load images — Konva's `Image` component requires an `HTMLImageElement`, not a URL.
- `Transformer` must be re-attached via `useEffect` when the selected node changes — it doesn't auto-follow React re-renders.
- Canvas renders are not in the React tree — DevTools won't show canvas elements; use Konva's `getChildren()` for debugging.

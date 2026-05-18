# Pattern: Image Annotation Tool

## Overview
Image annotation (placing labeled markers on an image) is used for product feedback, medical imaging, quality control, and content tagging. Storing coordinates as normalized values (0–1 range relative to image dimensions) rather than absolute pixels means annotations remain valid when the image is displayed at different sizes. Mobile users need tap-to-annotate with the same UX as click-to-annotate on desktop.

## Implementation

### Coordinate System
```tsx
// Always store in normalized form — convert from/to pixel on render
interface AnnotationPoint {
  id: string
  x: number          // 0–1 relative to image width
  y: number          // 0–1 relative to image height
  label: string
  category: string
  createdAt: string
}

function toNormalized(
  clientX: number,
  clientY: number,
  imgRect: DOMRect
): { x: number; y: number } {
  return {
    x: (clientX - imgRect.left) / imgRect.width,
    y: (clientY - imgRect.top) / imgRect.height,
  }
}

function toPixel(
  normalized: { x: number; y: number },
  imgRect: DOMRect
): { left: number; top: number } {
  return {
    left: normalized.x * imgRect.width,
    top: normalized.y * imgRect.height,
  }
}
```

### Annotation State
```tsx
function useImageAnnotation(initialAnnotations: AnnotationPoint[] = []) {
  const [annotations, setAnnotations] = useState(initialAnnotations)
  const [editing, setEditing] = useState<string | null>(null)
  const [pendingPoint, setPendingPoint] = useState<{ x: number; y: number } | null>(null)

  const addAnnotation = (point: { x: number; y: number }, label: string, category: string) => {
    const annotation: AnnotationPoint = {
      id: crypto.randomUUID(),
      ...point,
      label,
      category,
      createdAt: new Date().toISOString(),
    }
    setAnnotations((prev) => [...prev, annotation])
    setPendingPoint(null)
  }

  const updateAnnotation = (id: string, updates: Partial<AnnotationPoint>) => {
    setAnnotations((prev) =>
      prev.map((a) => (a.id === id ? { ...a, ...updates } : a))
    )
  }

  const deleteAnnotation = (id: string) => {
    setAnnotations((prev) => prev.filter((a) => a.id !== id))
    if (editing === id) setEditing(null)
  }

  return {
    annotations,
    editing,
    pendingPoint,
    setEditing,
    setPendingPoint,
    addAnnotation,
    updateAnnotation,
    deleteAnnotation,
  }
}
```

### Annotatable Image
```tsx
function AnnotatableImage({
  src,
  alt,
  annotations,
  onImageClick,
  onMarkerClick,
}: {
  src: string
  alt: string
  annotations: AnnotationPoint[]
  onImageClick: (point: { x: number; y: number }) => void
  onMarkerClick: (id: string) => void
}) {
  const imgRef = useRef<HTMLImageElement>(null)

  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    // Ignore clicks on markers
    if ((e.target as HTMLElement).dataset.marker) return
    const rect = imgRef.current?.getBoundingClientRect()
    if (!rect) return
    onImageClick(toNormalized(e.clientX, e.clientY, rect))
  }

  // Mobile: same handler for touch
  const handleTouchEnd = (e: React.TouchEvent<HTMLDivElement>) => {
    const touch = e.changedTouches[0]
    const rect = imgRef.current?.getBoundingClientRect()
    if (!rect || !touch) return
    onImageClick(toNormalized(touch.clientX, touch.clientY, rect))
  }

  return (
    <div
      className="relative inline-block cursor-crosshair select-none"
      onClick={handleClick}
      onTouchEnd={handleTouchEnd}
    >
      <img ref={imgRef} src={src} alt={alt} className="block max-w-full" draggable={false} />

      {/* Annotation overlay */}
      {annotations.map((annotation) => {
        const rect = imgRef.current?.getBoundingClientRect()
        if (!rect) return null
        const { left, top } = toPixel(annotation, {
          width: rect.width,
          height: rect.height,
          // Use 0,0 offsets since we're positioning within the container
          left: 0, top: 0, right: 0, bottom: 0, x: 0, y: 0, toJSON: () => {}
        } as DOMRect)

        return (
          <AnnotationMarker
            key={annotation.id}
            annotation={annotation}
            left={left}
            top={top}
            onClick={() => onMarkerClick(annotation.id)}
          />
        )
      })}
    </div>
  )
}
```

### Annotation Marker
```tsx
function AnnotationMarker({
  annotation,
  left,
  top,
  onClick,
}: {
  annotation: AnnotationPoint
  left: number
  top: number
  onClick: () => void
}) {
  return (
    <button
      data-marker="true"
      type="button"
      onClick={(e) => { e.stopPropagation(); onClick() }}
      aria-label={`Annotation: ${annotation.label}`}
      style={{ left, top, transform: 'translate(-50%, -50%)' }}
      className="absolute z-10 w-5 h-5 rounded-full bg-yellow-400 border-2 border-yellow-600 flex items-center justify-center hover:scale-125 transition-transform"
    >
      <span className="sr-only">{annotation.label}</span>
    </button>
  )
}
```

### JSON Export
```tsx
function exportAnnotations(annotations: AnnotationPoint[]): string {
  // Already in normalized form — export as-is
  return JSON.stringify({
    version: '1.0',
    annotations: annotations.map(({ id, x, y, label, category, createdAt }) => ({
      id, x, y, label, category, createdAt,
      // Coordinates are 0-1 normalized — not pixel values
    })),
  }, null, 2)
}
```

## Key Rules
- Store coordinates in 0–1 normalized form — pixel coordinates break when the image is resized or displayed at different dimensions
- Click event target check: ignore clicks that land on existing markers (use `data-marker` attribute check) — clicking a marker to edit it should not create a new annotation
- `e.stopPropagation()` on marker click prevents the image click handler from firing simultaneously
- Mobile: use `touchend` event, not `click` — `click` on touch fires with 300ms delay unless `touch-action: manipulation` is set
- Marker size must be at least 44×44px touch target on mobile — a 20px dot is too small
- Position markers with `transform: translate(-50%, -50%)` so the marker center aligns to the click point, not the marker corner
- Export includes `version` field — annotation formats evolve; versioning lets you migrate old data
- Edit/delete UI should appear in a popover on marker click, not inline in the image overlay — inline UI shifts layout

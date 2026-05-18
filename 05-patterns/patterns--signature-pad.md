# Pattern: Signature Pad

## Overview

Capture handwritten signatures on touch or mouse devices. Use `react-signature-canvas` (wraps signature_pad library). Output as PNG data URL for storage, or SVG for scalability. Critical behaviors: clear button, undo (remove last stroke), and validation that the pad isn't empty before submission.

## Setup

```bash
npm install react-signature-canvas
npm install -D @types/react-signature-canvas
```

## Component

```tsx
import SignatureCanvas from 'react-signature-canvas'

interface SignaturePadProps {
  onSave: (dataUrl: string) => void
  label?: string
}

export function SignaturePad({ onSave, label = 'Signature' }: SignaturePadProps) {
  const padRef = useRef<SignatureCanvas>(null)
  const [isEmpty, setIsEmpty] = useState(true)
  const containerRef = useRef<HTMLDivElement>(null)
  const [size, setSize] = useState({ width: 500, height: 200 })

  // Responsive canvas size
  useEffect(() => {
    if (!containerRef.current) return
    const ro = new ResizeObserver(entries => {
      const { width } = entries[0].contentRect
      setSize({ width, height: Math.round(width * 0.35) })
    })
    ro.observe(containerRef.current)
    return () => ro.disconnect()
  }, [])

  const handleClear = () => {
    padRef.current?.clear()
    setIsEmpty(true)
  }

  const handleUndo = () => {
    const data = padRef.current?.toData()
    if (!data?.length) return
    data.pop()
    padRef.current?.fromData(data)
    setIsEmpty(data.length === 0)
  }

  const handleSave = () => {
    if (!padRef.current || padRef.current.isEmpty()) return

    // Trim whitespace and get PNG at 2x resolution for retina
    const trimmed = padRef.current.getTrimmedCanvas()
    const dataUrl = trimmed.toDataURL('image/png')
    onSave(dataUrl)
  }

  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-2">{label}</label>

      <div ref={containerRef} className="w-full">
        <div className="border-2 border-gray-300 rounded-lg bg-gray-50 touch-none overflow-hidden">
          <SignatureCanvas
            ref={padRef}
            canvasProps={{
              width: size.width,
              height: size.height,
              className: 'w-full h-full',
              style: { touchAction: 'none' },
            }}
            onBegin={() => setIsEmpty(false)}
            penColor="#1e293b"
            dotSize={2}
            minWidth={1}
            maxWidth={3}
            velocityFilterWeight={0.7}
          />
        </div>

        {/* Baseline indicator */}
        <div className="mt-1 border-t border-dashed border-gray-400 mx-2" />
        <p className="text-xs text-gray-400 text-center mt-1">Sign above</p>
      </div>

      <div className="flex gap-2 mt-3">
        <button
          type="button"
          onClick={handleClear}
          disabled={isEmpty}
          className="px-3 py-1.5 text-sm border rounded hover:bg-gray-50 disabled:opacity-40"
        >
          Clear
        </button>
        <button
          type="button"
          onClick={handleUndo}
          disabled={isEmpty}
          className="px-3 py-1.5 text-sm border rounded hover:bg-gray-50 disabled:opacity-40"
        >
          Undo
        </button>
        <button
          type="button"
          onClick={handleSave}
          disabled={isEmpty}
          className="ml-auto px-4 py-1.5 text-sm bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-40"
        >
          Save signature
        </button>
      </div>
    </div>
  )
}
```

## Storage Pattern

Store as PNG data URL in the database or convert to file upload:

```ts
async function saveSignature(entityId: string, dataUrl: string): Promise<string> {
  // Convert data URL to Blob
  const res = await fetch(dataUrl)
  const blob = await res.blob()

  // Upload to storage
  const key = `signatures/${entityId}-${Date.now()}.png`
  await uploadToStorage(key, blob, 'image/png')

  // Return persistent URL (not data URL — data URLs are large)
  return getPublicUrl(key)
}
```

## In a Form

```tsx
function ContractForm() {
  const [signatureUrl, setSignatureUrl] = useState<string | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!signatureUrl) {
      alert('Please provide your signature')
      return
    }
    await submitContract({ signatureUrl })
  }

  return (
    <form onSubmit={handleSubmit}>
      {/* ... other fields ... */}
      <SignaturePad
        onSave={async (dataUrl) => {
          const url = await saveSignature(contractId, dataUrl)
          setSignatureUrl(url)
        }}
      />
      {signatureUrl && (
        <p className="text-sm text-green-600 mt-1">✓ Signature captured</p>
      )}
      <button type="submit" disabled={!signatureUrl}>Submit</button>
    </form>
  )
}
```

## Key Rules

- `touch-none` / `touchAction: 'none'` on the canvas is required — otherwise iOS scroll events intercept drawing.
- Use `getTrimmedCanvas()` before saving to remove empty padding — smaller file size and better rendering.
- Store as a file in object storage (S3/R2), not a base64 data URL in the DB — data URLs are 30-50% larger.
- Validate `padRef.current.isEmpty()` server-side too — a blank white PNG passes the client check if canvas was cleared then submitted.
- Accessibility: provide an alternative upload field for users with motor disabilities ("Upload image of signature").

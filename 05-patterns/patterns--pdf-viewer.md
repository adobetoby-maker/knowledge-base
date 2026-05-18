# Pattern: PDF Viewer

## Overview

Render PDF files in-browser without native `<embed>` or `<iframe>` limitations. Use `react-pdf` (backed by PDF.js) for full control over rendering, text selection, and page navigation. `<iframe src="file.pdf">` works but gives zero control over UI, loading states, or mobile behavior.

## Basic Setup

```tsx
import { Document, Page, pdfjs } from 'react-pdf'
import 'react-pdf/dist/Page/AnnotationLayer.css'
import 'react-pdf/dist/Page/TextLayer.css'

// Required: set worker source
pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  'pdfjs-dist/build/pdf.worker.min.mjs',
  import.meta.url,
).toString()

interface PdfViewerProps {
  url: string
  className?: string
}

export function PdfViewer({ url, className }: PdfViewerProps) {
  const [numPages, setNumPages] = useState<number>(0)
  const [pageNumber, setPageNumber] = useState(1)
  const [scale, setScale] = useState(1.0)
  const containerRef = useRef<HTMLDivElement>(null)
  const [containerWidth, setContainerWidth] = useState<number>()

  useEffect(() => {
    if (!containerRef.current) return
    const observer = new ResizeObserver(entries => {
      setContainerWidth(entries[0].contentRect.width)
    })
    observer.observe(containerRef.current)
    return () => observer.disconnect()
  }, [])

  return (
    <div ref={containerRef} className={className}>
      <div className="flex items-center gap-2 p-2 border-b">
        <button
          onClick={() => setPageNumber(p => Math.max(1, p - 1))}
          disabled={pageNumber <= 1}
        >
          ←
        </button>
        <span>{pageNumber} / {numPages}</span>
        <button
          onClick={() => setPageNumber(p => Math.min(numPages, p + 1))}
          disabled={pageNumber >= numPages}
        >
          →
        </button>
        <button onClick={() => setScale(s => Math.min(3, s + 0.25))}>+</button>
        <span>{Math.round(scale * 100)}%</span>
        <button onClick={() => setScale(s => Math.max(0.5, s - 0.25))}>−</button>
      </div>

      <Document
        file={url}
        onLoadSuccess={({ numPages }) => setNumPages(numPages)}
        loading={<div className="p-8 text-center">Loading PDF…</div>}
        error={<div className="p-8 text-center text-red-600">Failed to load PDF.</div>}
      >
        <Page
          pageNumber={pageNumber}
          scale={scale}
          width={containerWidth}
          renderTextLayer
          renderAnnotationLayer
        />
      </Document>
    </div>
  )
}
```

## All Pages Scrollable

For document reading rather than page-flip navigation:

```tsx
function PdfScrollViewer({ url }: { url: string }) {
  const [numPages, setNumPages] = useState(0)

  return (
    <div className="overflow-auto max-h-screen">
      <Document file={url} onLoadSuccess={({ numPages }) => setNumPages(numPages)}>
        {Array.from({ length: numPages }, (_, i) => (
          <Page
            key={i + 1}
            pageNumber={i + 1}
            renderTextLayer
            renderAnnotationLayer
            className="mb-4 shadow-md"
          />
        ))}
      </Document>
    </div>
  )
}
```

## Worker Configuration (Next.js)

In `next.config.ts`:

```ts
// next.config.ts
const nextConfig = {
  webpack: config => {
    config.resolve.alias.canvas = false  // pdfjs needs this
    return config
  },
}
```

Alternatively, serve the worker from a CDN (simpler but adds external dependency):

```ts
pdfjs.GlobalWorkerOptions.workerSrc = `//unpkg.com/pdfjs-dist@${pdfjs.version}/build/pdf.worker.min.mjs`
```

## Lazy Load the Component

PDF.js is ~1MB. Never import it at the top level:

```tsx
const PdfViewer = dynamic(() => import('@/components/PdfViewer'), {
  loading: () => <div className="h-96 bg-gray-100 animate-pulse rounded" />,
  ssr: false,
})
```

## Authenticated PDFs

For PDFs behind auth, proxy through an API route rather than exposing signed S3 URLs to the client — signed URLs expire and may leak in browser history:

```tsx
// Use a route that streams the PDF with auth check
<Document file="/api/documents/123/pdf" />

// api/documents/[id]/pdf/route.ts
export async function GET(req, { params }) {
  const user = await requireAuth(req)
  const doc = await db.query.documents.findFirst({
    where: and(eq(documents.id, params.id), eq(documents.userId, user.id)),
  })
  if (!doc) return new Response(null, { status: 404 })

  const buffer = await getFromStorage(doc.storageKey)
  return new Response(buffer, {
    headers: { 'Content-Type': 'application/pdf' },
  })
}
```

## Key Rules

- Import CSS layers (`AnnotationLayer.css`, `TextLayer.css`) or text selection and links won't work.
- Worker path must be set before first render — component-level is fine but module-level is safer.
- `width={containerWidth}` (not CSS width) keeps PDF sharp at all zoom levels — CSS scaling blurs the canvas.
- Never render all pages upfront for large PDFs; render on-demand or use virtualization.
- `ssr: false` for dynamic import — PDF.js uses browser globals.

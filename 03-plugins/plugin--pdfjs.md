# Plugin: PDF.js (PDF Viewer)

## What It Is

PDF.js is Mozilla's open-source PDF viewer. Renders PDFs in the browser without plugins. Used for: invoice preview, document viewer, lease/contract display. Works client-side only.

## Installation

```bash
npm install pdfjs-dist
npm install --save-dev @types/pdfjs-dist
```

## React PDF Viewer Component

```tsx
'use client'
import { useEffect, useRef, useState } from 'react'
import * as pdfjsLib from 'pdfjs-dist'

// Set worker source — must be served as a static file
pdfjsLib.GlobalWorkerOptions.workerSrc = '/pdf.worker.min.js'

interface PDFViewerProps {
  url: string
}

export function PDFViewer({ url }: PDFViewerProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [numPages, setNumPages] = useState(0)
  const [currentPage, setCurrentPage] = useState(1)
  const [scale, setScale] = useState(1.5)

  useEffect(() => {
    let cancelled = false

    async function renderPage() {
      const pdf = await pdfjsLib.getDocument(url).promise
      setNumPages(pdf.numPages)

      const page = await pdf.getPage(currentPage)
      const viewport = page.getViewport({ scale })

      const canvas = canvasRef.current
      if (!canvas || cancelled) return

      const context = canvas.getContext('2d')!
      canvas.height = viewport.height
      canvas.width = viewport.width

      await page.render({ canvasContext: context, viewport }).promise
    }

    renderPage()

    return () => { cancelled = true }
  }, [url, currentPage, scale])

  return (
    <div className="flex flex-col items-center gap-3">
      <canvas ref={canvasRef} className="shadow-lg border rounded" />

      {numPages > 1 && (
        <div className="flex items-center gap-3">
          <button
            onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
            disabled={currentPage === 1}
            className="px-3 py-1.5 border rounded disabled:opacity-40"
          >
            ←
          </button>
          <span className="text-sm text-gray-600">
            Page {currentPage} of {numPages}
          </span>
          <button
            onClick={() => setCurrentPage((p) => Math.min(numPages, p + 1))}
            disabled={currentPage === numPages}
            className="px-3 py-1.5 border rounded disabled:opacity-40"
          >
            →
          </button>
        </div>
      )}

      {/* Zoom controls */}
      <div className="flex items-center gap-2">
        <button onClick={() => setScale((s) => Math.max(0.5, s - 0.25))} className="px-2 py-1 border rounded">−</button>
        <span className="text-sm">{Math.round(scale * 100)}%</span>
        <button onClick={() => setScale((s) => Math.min(3, s + 0.25))} className="px-2 py-1 border rounded">+</button>
      </div>
    </div>
  )
}
```

## Worker Setup

PDF.js requires a Web Worker for heavy processing. Copy the worker to `public/`:

```bash
# Copy worker file to public directory
cp node_modules/pdfjs-dist/build/pdf.worker.min.js public/
```

Or configure Next.js to serve it:

```ts
// next.config.ts
const nextConfig = {
  async headers() {
    return [
      {
        source: '/pdf.worker.min.js',
        headers: [{ key: 'Content-Type', value: 'application/javascript' }],
      },
    ]
  },
}
```

## Dynamic Import (Required for Next.js)

PDF.js uses browser APIs — can't SSR:

```tsx
import dynamic from 'next/dynamic'

const PDFViewer = dynamic(
  () => import('@/components/PDFViewer').then((m) => m.PDFViewer),
  { ssr: false, loading: () => <div className="h-96 animate-pulse bg-gray-100 rounded" /> }
)
```

## Simple Alternative: `react-pdf`

For simpler use cases:

```bash
npm install react-pdf
```

```tsx
import { Document, Page } from 'react-pdf'
import 'react-pdf/dist/Page/AnnotationLayer.css'
import 'react-pdf/dist/Page/TextLayer.css'

function PDFPreview({ url }: { url: string }) {
  const [numPages, setNumPages] = useState(0)

  return (
    <Document
      file={url}
      onLoadSuccess={({ numPages }) => setNumPages(numPages)}
    >
      {Array.from({ length: numPages }, (_, i) => (
        <Page key={i + 1} pageNumber={i + 1} width={600} />
      ))}
    </Document>
  )
}
```

`react-pdf` wraps PDF.js with a simpler React API. The tradeoff: less control over rendering, but easier to implement.

## Inline PDF Embed (No Library)

For simple cases where browser support is sufficient:

```tsx
<iframe
  src={`${pdfUrl}#toolbar=0`}  // Hide browser PDF toolbar
  className="w-full h-[600px] border rounded-xl"
  title="Invoice PDF"
/>
```

Works in Chrome/Edge (built-in PDF viewer). Firefox shows download prompt by default. iOS Safari uses Quick Look.

## When to Use PDF.js vs Embed

- Full control over rendering, annotations, search → PDF.js
- Just need to show a PDF in a frame → `<iframe>` embed
- Generate PDF on server, show preview → `<iframe>` with route handler URL
- Annotate/highlight PDF → PDF.js with annotation layer

# Pattern: QR Code Generation

## Library

```bash
npm install qrcode
npm install --save-dev @types/qrcode
```

## Server-Side: Generate as Buffer

```ts
// lib/qr.ts
import QRCode from 'qrcode'

export async function generateQRCode(text: string): Promise<Buffer> {
  return QRCode.toBuffer(text, {
    errorCorrectionLevel: 'H',  // High error correction (30% damage tolerance)
    type: 'png',
    width: 300,
    margin: 2,
    color: {
      dark: '#000000',
      light: '#ffffff',
    },
  })
}

export async function generateQRCodeDataUrl(text: string): Promise<string> {
  return QRCode.toDataURL(text, {
    errorCorrectionLevel: 'M',
    width: 200,
    margin: 1,
  })
}

export async function generateQRCodeSvg(text: string): Promise<string> {
  return QRCode.toString(text, { type: 'svg' })
}
```

`errorCorrectionLevel`:
- `L` — 7% correction (smallest, densest)
- `M` — 15% correction (default)
- `Q` — 25% correction
- `H` — 30% correction (use when logo overlay blocks center)

## Route Handler: Serve QR Image

```ts
// app/api/qr/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { generateQRCode } from '@/lib/qr'
import { z } from 'zod'

const schema = z.object({
  url: z.string().url().max(500),
})

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const result = schema.safeParse({ url: searchParams.get('url') })

  if (!result.success) {
    return new NextResponse('Invalid URL', { status: 400 })
  }

  const buffer = await generateQRCode(result.data.url)

  return new NextResponse(buffer, {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=86400',  // Cache 24h (QR for same URL never changes)
    },
  })
}
```

## Client-Side: Canvas Rendering

```tsx
'use client'
import { useEffect, useRef } from 'react'
import QRCode from 'qrcode'

interface QRCodeCanvasProps {
  value: string
  size?: number
}

export function QRCodeCanvas({ value, size = 200 }: QRCodeCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    if (!canvasRef.current) return

    QRCode.toCanvas(canvasRef.current, value, {
      width: size,
      margin: 1,
      errorCorrectionLevel: 'M',
    })
  }, [value, size])

  return <canvas ref={canvasRef} />
}
```

For Next.js server components, use the Route Handler approach (`<img src="/api/qr?url=...">`) to avoid including the `qrcode` library in the client bundle.

## QR Code in PDF (Invoice/Receipt)

```ts
import QRCode from 'qrcode'

// In invoice HTML template
const paymentUrl = `https://yourdomain.com/pay/${invoice.id}`
const qrDataUrl = await QRCode.toDataURL(paymentUrl, { width: 120, margin: 1 })

// Embed in HTML template
const qrSection = `<img src="${qrDataUrl}" width="120" height="120" alt="Pay invoice QR code" />`
```

Data URLs work in PDF HTML templates — no external image requests needed.

## QR with Logo Overlay

```ts
// Requires canvas manipulation — use on server only
import { createCanvas, loadImage } from '@napi-rs/canvas'
import QRCode from 'qrcode'

async function generateQRWithLogo(text: string, logoPath: string): Promise<Buffer> {
  // Generate QR on canvas
  const size = 300
  const canvas = createCanvas(size, size)
  await QRCode.toCanvas(canvas as any, text, {
    width: size,
    errorCorrectionLevel: 'H',  // High — logo covers center
  })

  const ctx = canvas.getContext('2d')

  // Draw logo in center
  const logo = await loadImage(logoPath)
  const logoSize = size * 0.25  // 25% of QR size
  const logoX = (size - logoSize) / 2
  const logoY = (size - logoSize) / 2

  // White background for logo
  ctx.fillStyle = '#ffffff'
  ctx.fillRect(logoX - 4, logoY - 4, logoSize + 8, logoSize + 8)
  ctx.drawImage(logo, logoX, logoY, logoSize, logoSize)

  return canvas.toBuffer('image/png')
}
```

Always use `errorCorrectionLevel: 'H'` when overlaying a logo — the logo physically obscures QR data modules.

## Download Button

```tsx
function DownloadQRButton({ value, filename }: { value: string; filename: string }) {
  async function download() {
    const dataUrl = await QRCode.toDataURL(value, { width: 512, margin: 2 })
    const a = document.createElement('a')
    a.href = dataUrl
    a.download = `${filename}.png`
    a.click()
  }

  return (
    <button onClick={download} className="btn-secondary">
      Download QR Code
    </button>
  )
}
```

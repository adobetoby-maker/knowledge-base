# Plugin: QR Code Generation

## Overview

Generate QR codes for: sharing URLs, mobile app deep links, contact information, WiFi credentials, invoice payment links. Two main libraries: `qrcode` (Node.js + browser, PNG/SVG) and `react-qr-code` (React, SVG only).

## Install

```bash
# Node.js + browser (PNG, SVG, data URL)
npm install qrcode
npm install --save-dev @types/qrcode

# React SVG component (simpler for React)
npm install react-qr-code
```

## React Component (react-qr-code)

```tsx
import QRCode from 'react-qr-code'

export function InvoiceQRCode({ paymentUrl }: { paymentUrl: string }) {
  return (
    <div className="flex flex-col items-center gap-2 p-4 bg-white rounded-lg">
      <QRCode
        value={paymentUrl}
        size={180}
        level="M"  // Error correction: L(7%), M(15%), Q(25%), H(30%)
        fgColor="#000000"
        bgColor="#ffffff"
      />
      <p className="text-xs text-gray-500">Scan to pay</p>
    </div>
  )
}
```

`level="M"` is the right default — adds 15% error correction (survives minor damage/dirt), keeps the code simple enough to scan quickly. Use `H` only when the QR code will be on physical materials that may get damaged.

## Generating PNG in Node.js

```ts
import QRCode from 'qrcode'

// Generate PNG buffer
async function generateQRCodeBuffer(text: string): Promise<Buffer> {
  return await QRCode.toBuffer(text, {
    width: 300,
    margin: 2,
    errorCorrectionLevel: 'M',
    color: {
      dark: '#000000',
      light: '#ffffff',
    },
  })
}

// Generate as data URL (for HTML img src)
async function generateQRCodeDataUrl(text: string): Promise<string> {
  return await QRCode.toDataURL(text, {
    width: 300,
    margin: 2,
    errorCorrectionLevel: 'M',
  })
}
```

## Generating SVG in Node.js

```ts
async function generateQRCodeSvg(text: string): Promise<string> {
  return await QRCode.toString(text, {
    type: 'svg',
    width: 300,
    margin: 2,
    errorCorrectionLevel: 'M',
  })
}
```

SVG is infinitely scalable — use for print materials. PNG is fine for on-screen display.

## Route Handler (Download QR Code)

```ts
// app/api/qrcode/route.ts
import QRCode from 'qrcode'

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url)
  const url = searchParams.get('url')

  if (!url) {
    return Response.json({ error: 'url param required' }, { status: 400 })
  }

  // Validate URL to prevent abuse
  try {
    new URL(url)
  } catch {
    return Response.json({ error: 'Invalid URL' }, { status: 400 })
  }

  const buffer = await QRCode.toBuffer(url, {
    width: 400,
    margin: 2,
    errorCorrectionLevel: 'M',
  })

  return new Response(buffer, {
    headers: {
      'Content-Type': 'image/png',
      'Content-Disposition': 'attachment; filename="qr-code.png"',
      'Cache-Control': 'public, max-age=86400',
    },
  })
}
```

## QR Code Content Formats

Different content types have format conventions that QR code scanner apps understand:

```ts
// URL (most common)
const url = 'https://mysite.com/invoice/123?token=abc'

// WiFi credentials
const wifi = 'WIFI:T:WPA;S:MyNetwork;P:password123;H:false;;'

// Email
const email = 'mailto:support@example.com?subject=Invoice%20123'

// Phone
const phone = 'tel:+12085952101'

// vCard (contact info)
const vcard = `BEGIN:VCARD
VERSION:3.0
FN:JR's Auto Repair
TEL;TYPE=WORK:+12085952101
ADR:;;417 Main Ave E;Twin Falls;ID;83301;US
END:VCARD`
```

## QR Code in PDF

When generating invoices or receipts as PDFs, embed the QR code as an image:

```ts
import QRCode from 'qrcode'
import { PDFDocument } from 'pdf-lib'

async function embedQRCode(pdfDoc: PDFDocument, url: string) {
  const qrBuffer = await QRCode.toBuffer(url, { width: 150, margin: 1 })
  const qrImage = await pdfDoc.embedPng(qrBuffer)
  
  const page = pdfDoc.getPages()[0]
  page.drawImage(qrImage, {
    x: 400,
    y: 50,
    width: 100,
    height: 100,
  })
}
```

## QR Code Size Guidelines

| Use case | Minimum size | Recommended |
|----------|-------------|-------------|
| Screen display | 100×100px | 200×200px |
| Print (label) | 1cm × 1cm | 2cm × 2cm |
| Print (poster) | 3cm × 3cm | 5cm × 5cm |
| Billboard | 10cm × 10cm | 15cm × 15cm |

Scanning distance ≈ 10× the QR code size. A 2cm QR code is scannable from ~20cm.

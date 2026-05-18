# plugin--react-pdf (@react-pdf/renderer)

`@react-pdf/renderer` generates PDF documents using React-like component syntax. It renders to a PDF binary — not to the DOM. There is no HTML or CSS parser involved; it implements its own layout engine based on Yoga (Flexbox).

## Core Primitives

The only valid elements inside a `Document` are the built-in primitives. No HTML tags, no custom DOM elements.

```tsx
import { Document, Page, View, Text, Image, StyleSheet, pdf } from '@react-pdf/renderer';

const styles = StyleSheet.create({
  page: { padding: 40, fontFamily: 'Helvetica' },
  heading: { fontSize: 24, fontWeight: 'bold', marginBottom: 12 },
  row: { flexDirection: 'row', gap: 8 },
});

const MyDoc = () => (
  <Document>
    <Page size="A4" style={styles.page}>
      <Text style={styles.heading}>Invoice #1001</Text>
      <View style={styles.row}>
        <Text>Item</Text>
        <Text>Price</Text>
      </View>
      <Image src="/path/to/logo.png" style={{ width: 80, height: 40 }} />
    </Page>
  </Document>
);
```

- `Document` — root wrapper, required
- `Page` — each page; set `size` (`"A4"`, `"LETTER"`, or `{ width, height }`) and `orientation` (`"portrait"` or `"landscape"`)
- `View` — equivalent to `div`; all layout uses Flexbox
- `Text` — all text must be inside `Text`; nested `Text` for inline spans
- `Image` — accepts a URL, a local path, or a base64 data URI

## StyleSheet.create

Styles are defined as plain JS objects — no CSS strings, no class names. `StyleSheet.create()` validates keys at development time and is the correct pattern (mirrors React Native's approach).

Supported properties are a subset of CSS: Flexbox layout, margins/padding, colors, font sizes, borders, `position: 'absolute'`, `position: 'relative'`. Unsupported: `grid`, `overflow`, `box-shadow`, `transform` (limited), pseudo-classes, media queries, animations.

When a style property does nothing, check the [official style reference](https://react-pdf.org/styling) — properties silently ignored are a common source of confusion.

## Server-Side Rendering with renderToStream

On the server (Node.js / Next.js Route Handler), use `renderToStream` for streaming delivery or `renderToBuffer` for in-memory usage. Do not use `PDFViewer` or `BlobProvider` on the server — those are browser-only.

```ts
// Next.js App Router Route Handler
import { renderToStream } from '@react-pdf/renderer';
import { NextResponse } from 'next/server';

export async function GET() {
  const stream = await renderToStream(<MyDoc />);
  return new NextResponse(stream as unknown as ReadableStream, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'attachment; filename="invoice.pdf"',
    },
  });
}
```

`renderToBuffer` returns a `Buffer` — useful when you need to upload the PDF to S3 or attach it to an email. `renderToStream` is better for HTTP responses to avoid holding the whole document in memory.

## Font Registration

Helvetica, Times-Roman, and Courier are built in. Custom fonts must be registered before use:

```ts
import { Font } from '@react-pdf/renderer';

Font.register({
  family: 'Inter',
  fonts: [
    { src: '/fonts/Inter-Regular.ttf' },
    { src: '/fonts/Inter-Bold.ttf', fontWeight: 'bold' },
    { src: '/fonts/Inter-Italic.ttf', fontStyle: 'italic' },
  ],
});
```

Register fonts at module initialization, before any rendering. On the server, `src` can be an absolute file path or a URL that the Node process can fetch. On the client (browser PDF generation), use URLs. Font files must be `.ttf` or `.otf` — `.woff`/`.woff2` are not supported.

## Limitations

- **No HTML rendering** — `<div>`, `<table>`, `<ul>` do not work. Use `View`/`Text` equivalents.
- **No CSS-in-JS passthrough** — Tailwind class names, styled-components, and emotion have no effect.
- **No CSS variables or calc()** — all values must be static numbers or strings.
- **Images from external URLs** — require the server to fetch them; add a timeout strategy.
- **Page breaks** — use `break` prop on `View`: `<View break>` to force a new page, or `wrap={false}` to prevent splitting a `View` across pages.
- **Unicode/CJK** — requires a registered font that includes those glyphs; built-in fonts are Latin-only.

## Key Rules

- **Primitives only** — `Document`, `Page`, `View`, `Text`, `Image`; no HTML tags ever
- **`StyleSheet.create()`** for all styles — validates properties and aids debugging
- **`renderToStream` on servers** — avoids buffering the full PDF in memory for large documents
- **Register fonts before rendering** — unregistered font families silently fall back to Helvetica
- **`wrap={false}`** on `View` to prevent mid-element page breaks
- No CSS features beyond Flexbox, box model, and basic typography — check the style reference before debugging

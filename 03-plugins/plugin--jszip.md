# Plugin: JSZip (ZIP File Generation)

## Overview

JSZip creates and reads ZIP archives in the browser or Node.js. Common uses: batch file downloads (CSV + images), generating reports with attachments, packaging user data exports. Browser-side ZIP generation avoids server round-trips for file assembly.

## Installation

```bash
npm install jszip
npm install file-saver @types/file-saver  # For browser download
```

## Create and Download ZIP

```ts
import JSZip from 'jszip'
import { saveAs } from 'file-saver'

async function downloadFilesAsZip(files: Array<{ name: string; content: string | Uint8Array | Blob }>) {
  const zip = new JSZip()

  for (const file of files) {
    zip.file(file.name, file.content)
  }

  const blob = await zip.generateAsync({
    type: 'blob',
    compression: 'DEFLATE',
    compressionOptions: { level: 6 },  // 1-9, 6 is balanced
  })

  saveAs(blob, 'export.zip')
}

// Usage
await downloadFilesAsZip([
  { name: 'report.csv', content: csvString },
  { name: 'data.json', content: JSON.stringify(data, null, 2) },
  { name: 'README.txt', content: 'This export contains...' },
])
```

## Nested Folders

```ts
const zip = new JSZip()

// Create folder structure
const imagesFolder = zip.folder('images')!
const docsFolder = zip.folder('docs')!

imagesFolder.file('logo.png', logoBlob)
imagesFolder.file('banner.jpg', bannerBlob)
docsFolder.file('guide.md', markdownContent)
zip.file('README.md', readmeContent)
```

## Fetching Remote Files into ZIP

```ts
async function addRemoteFile(zip: JSZip, filename: string, url: string) {
  const response = await fetch(url)
  const blob = await response.blob()
  zip.file(filename, blob)
}

// Add multiple remote files
const zip = new JSZip()
await Promise.all(
  attachments.map(a => addRemoteFile(zip, a.filename, a.url))
)
const blob = await zip.generateAsync({ type: 'blob' })
```

## Progress Tracking

```ts
const blob = await zip.generateAsync(
  { type: 'blob', compression: 'DEFLATE' },
  (metadata) => {
    setProgress(Math.round(metadata.percent))
    // metadata.currentFile — currently processing file name
  }
)
```

## Reading / Extracting a ZIP

```ts
async function extractZip(file: File): Promise<Map<string, string>> {
  const zip = await JSZip.loadAsync(file)
  const contents = new Map<string, string>()

  for (const [filename, zipEntry] of Object.entries(zip.files)) {
    if (!zipEntry.dir) {
      const text = await zipEntry.async('string')
      contents.set(filename, text)
    }
  }

  return contents
}
```

## Node.js: Write to File System

```ts
import JSZip from 'jszip'
import { writeFile } from 'fs/promises'

async function createZipFile(outputPath: string, files: Record<string, string>) {
  const zip = new JSZip()
  
  for (const [name, content] of Object.entries(files)) {
    zip.file(name, content)
  }

  const buffer = await zip.generateAsync({ type: 'nodebuffer' })
  await writeFile(outputPath, buffer)
}
```

## Key Rules

- `type: 'blob'` for browser download; `type: 'nodebuffer'` for Node.js file system.
- `DEFLATE` compression at level 6 is a good default — text files compress well (CSV, JSON, HTML).
- `STORE` (no compression) is faster for already-compressed files (JPEG, PNG, MP4).
- `saveAs` from `file-saver` uses the browser's download mechanism — no server needed.
- For very large ZIPs (>100MB), consider streaming: `StreamSaver.js` + `zip-stream` for memory efficiency.

# Pattern: File Preview Panel

A panel that renders a meaningful preview of an uploaded or selected file before or after upload. The challenge is handling five distinct media types with different APIs, plus a graceful fallback for unsupported formats—without loading heavy libraries for types that aren't present.

## Why It Matters

Users need to confirm they're uploading the right file before committing. A preview panel reduces wrong-file errors for images and documents, and provides filename/size confirmation for binary formats. The preview should use local object URLs—never re-upload just to preview.

## Type Detection

```ts
type PreviewType = 'image' | 'pdf' | 'video' | 'text' | 'unsupported';

function getPreviewType(file: File): PreviewType {
  if (file.type.startsWith('image/')) return 'image';
  if (file.type === 'application/pdf') return 'pdf';
  if (file.type.startsWith('video/')) return 'video';
  if (file.type.startsWith('text/') || file.name.match(/\.(txt|md|csv|json|xml|yaml|yml|env)$/i))
    return 'text';
  return 'unsupported';
}
```

Use `file.type` as the primary signal but fall back to extension—some systems return `""` for MIME type.

## Object URL Lifecycle

```tsx
function useObjectUrl(file: File | null) {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    if (!file) { setUrl(null); return; }
    const objectUrl = URL.createObjectURL(file);
    setUrl(objectUrl);
    // Critical: revoke to release memory
    return () => URL.revokeObjectURL(objectUrl);
  }, [file]);

  return url;
}
```

**Revoke on cleanup**—object URLs hold a reference to the file buffer in memory. Without revocation, a user who selects 20 images will leak 20 buffers. The cleanup function in `useEffect` handles this automatically.

## Image Preview

```tsx
function ImagePreview({ file }: { file: File }) {
  const url = useObjectUrl(file);
  if (!url) return <Spinner />;
  return (
    <img
      src={url}
      alt={file.name}
      className="preview-image"
      style={{ maxWidth: '100%', maxHeight: 400, objectFit: 'contain' }}
    />
  );
}
```

## PDF Preview

Two approaches:

**Option A: iframe** (simplest, browser-native):
```tsx
function PdfPreview({ file }: { file: File }) {
  const url = useObjectUrl(file);
  if (!url) return null;
  return (
    <iframe
      src={url}
      title={file.name}
      className="preview-pdf"
      style={{ width: '100%', height: 500, border: 'none' }}
    />
  );
}
```

**Option B: pdfjs** (more control, required for custom rendering or mobile):
```tsx
// Lazy-load pdfjs only when a PDF is selected
async function renderPdfThumbnail(file: File, canvas: HTMLCanvasElement) {
  const { getDocument, GlobalWorkerOptions } = await import('pdfjs-dist');
  GlobalWorkerOptions.workerSrc = '/pdf.worker.min.js';

  const arrayBuffer = await file.arrayBuffer();
  const pdf = await getDocument({ data: arrayBuffer }).promise;
  const page = await pdf.getPage(1);
  const viewport = page.getViewport({ scale: 1.5 });

  canvas.width = viewport.width;
  canvas.height = viewport.height;
  await page.render({ canvasContext: canvas.getContext('2d')!, viewport }).promise;
}
```

Use the iframe approach for simplicity unless you need page navigation or custom rendering.

## Text File Preview

```tsx
function TextPreview({ file }: { file: File }) {
  const [content, setContent] = useState<string | null>(null);
  const MAX_CHARS = 5000; // don't render entire large files

  useEffect(() => {
    const reader = new FileReader();
    reader.onload = e => {
      const text = e.target?.result as string;
      setContent(text.slice(0, MAX_CHARS) + (text.length > MAX_CHARS ? '\n...' : ''));
    };
    reader.readAsText(file);
    return () => reader.abort();
  }, [file]);

  if (content === null) return <Spinner />;
  return (
    <pre className="preview-text">
      <code>{content}</code>
    </pre>
  );
}
```

Cap text preview at ~5000 characters—rendering a 10MB CSV as a single `<pre>` freezes the browser.

## Video Preview

```tsx
function VideoPreview({ file }: { file: File }) {
  const url = useObjectUrl(file);
  if (!url) return null;
  return (
    <video
      src={url}
      controls
      preload="metadata"  // load enough for duration/thumbnail, not full video
      className="preview-video"
      style={{ maxWidth: '100%', maxHeight: 400 }}
    />
  );
}
```

`preload="metadata"` loads only the first few KB (duration, dimensions, first frame) instead of buffering the entire video.

## Fallback for Unsupported Types

```tsx
function UnsupportedPreview({ file }: { file: File }) {
  const ext = file.name.split('.').pop()?.toUpperCase() ?? 'FILE';
  const sizeMB = (file.size / 1024 / 1024).toFixed(2);

  return (
    <div className="preview-unsupported">
      <FileIcon className="preview-unsupported__icon" aria-hidden />
      <p className="preview-unsupported__name">{file.name}</p>
      <p className="preview-unsupported__meta">{ext} · {sizeMB} MB</p>
      <p className="preview-unsupported__note">Preview not available</p>
    </div>
  );
}
```

## Composing the Panel

```tsx
function FilePreview({ file }: { file: File }) {
  const type = getPreviewType(file);

  return (
    <div className="file-preview">
      {type === 'image'       && <ImagePreview file={file} />}
      {type === 'pdf'         && <PdfPreview file={file} />}
      {type === 'video'       && <VideoPreview file={file} />}
      {type === 'text'        && <TextPreview file={file} />}
      {type === 'unsupported' && <UnsupportedPreview file={file} />}
    </div>
  );
}
```

## Key Rules

- **Revoke object URLs on cleanup**—memory leak if skipped, especially with repeated file selection.
- **`preload="metadata"` on video**—not `preload="auto"`, which buffers the full file.
- **Cap text preview** at ~5000 chars—never dump a full large file into a `<pre>`.
- **Lazy-load pdfjs**—only import when a PDF is actually selected.
- **Use `file.type` + extension fallback**—MIME type can be empty string on some platforms.
- **Show filename + size in the fallback**—users still need confirmation they selected the right file.
- **Never re-upload to preview**—always use `URL.createObjectURL` for local preview.

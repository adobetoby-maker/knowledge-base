# Pattern: Single Image Upload with Preview

## Overview
Single image upload with preview is deceptively complex: the user must see their selection immediately (before upload), be able to change their mind, and only commit the upload on form submission — not on selection. Premature upload (uploading immediately on file selection) wastes server storage for abandoned forms and makes replacing the image confusing. The preview is local-only until submit.

## Implementation

### State Management
```tsx
interface ImageUploadState {
  preview: string | null;       // Object URL (local preview, never sent to server)
  file: File | null;            // The actual file, uploaded on form submit
  uploadedUrl: string | null;   // URL after successful upload (stored in form value)
  error: string | null;
}
```

### Component
```tsx
function ImageUploadField({
  value,             // current saved image URL (from form/server)
  onChange,          // callback with new URL after upload
  onClear,
  maxSizeMB = 5,
  aspectRatio,       // e.g., '1/1', '16/9', or undefined (free)
}: {
  value?: string;
  onChange: (url: string) => void;
  onClear: () => void;
  maxSizeMB?: number;
  aspectRatio?: string;
}) {
  const [preview, setPreview] = useState<string | null>(null);
  const [pendingFile, setPendingFile] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Cleanup Object URL on unmount
  useEffect(() => {
    return () => { if (preview) URL.revokeObjectURL(preview); };
  }, [preview]);

  const handleSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate type
    if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(file.type)) {
      setError('Please select a JPEG, PNG, WebP, or GIF image.');
      return;
    }

    // Validate size
    if (file.size > maxSizeMB * 1024 * 1024) {
      setError(`Image must be smaller than ${maxSizeMB} MB.`);
      return;
    }

    setError(null);

    // Revoke previous preview
    if (preview) URL.revokeObjectURL(preview);

    const objectUrl = URL.createObjectURL(file);
    setPreview(objectUrl);
    setPendingFile(file);

    // Reset input so same file can be re-selected
    e.target.value = '';
  };

  const handleRemove = () => {
    if (preview) {
      URL.revokeObjectURL(preview);
      setPreview(null);
    }
    setPendingFile(null);
    onClear();
  };

  // Called from parent form's submit handler
  const upload = async (): Promise<string | null> => {
    if (!pendingFile) return value ?? null;

    const formData = new FormData();
    formData.append('file', pendingFile);
    const res = await fetch('/api/upload', { method: 'POST', body: formData });
    const { url } = await res.json();
    URL.revokeObjectURL(preview!);
    setPreview(null);
    setPendingFile(null);
    onChange(url);
    return url;
  };

  // Expose upload function via ref for parent form
  useImperativeHandle(ref, () => ({ upload }));

  const displaySrc = preview ?? value ?? null;

  return (
    <div>
      <input
        ref={inputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif"
        onChange={handleSelect}
        style={{ display: 'none' }}
        aria-label="Upload image"
      />

      {displaySrc ? (
        <div style={{ position: 'relative', display: 'inline-block' }}>
          <img
            src={displaySrc}
            alt="Upload preview"
            style={{
              maxWidth: 240,
              aspectRatio: aspectRatio ?? 'auto',
              objectFit: 'cover',
              borderRadius: 8,
              display: 'block',
            }}
          />
          <button
            type="button"
            onClick={handleRemove}
            aria-label="Remove image"
            style={{ position: 'absolute', top: 4, right: 4 }}
          >
            ✕
          </button>
          <button
            type="button"
            onClick={() => inputRef.current?.click()}
            style={{ position: 'absolute', bottom: 4, right: 4 }}
          >
            Change
          </button>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          style={{
            border: '2px dashed #d1d5db',
            borderRadius: 8,
            padding: '24px 48px',
            cursor: 'pointer',
            background: 'transparent',
            aspectRatio: aspectRatio,
          }}
          aria-label="Click to upload image"
        >
          Click or drag to upload
        </button>
      )}

      {error && <p role="alert" style={{ color: '#ef4444', fontSize: 14 }}>{error}</p>}
    </div>
  );
}
```

### Drag-and-Drop Support
```tsx
const handleDrop = (e: React.DragEvent) => {
  e.preventDefault();
  const file = e.dataTransfer.files[0];
  if (file) {
    // Reuse the same validation logic by constructing a synthetic event or calling directly
    processFile(file);
  }
};

<div onDragOver={e => e.preventDefault()} onDrop={handleDrop}>
```

## Key Rules
- Upload happens on form submit, not on file selection — premature upload wastes storage and complicates rollback.
- Always revoke Object URLs: on file replacement, on remove, and on component unmount.
- Reset `input.value = ''` after selection — prevents "same file selected again" from not firing onChange.
- Validate type and size client-side before creating Object URL — no point previewing a 50 MB video.
- The "remove" button must be `type="button"` — default type is "submit", which would submit the form.
- Provide `aria-label` on the hidden file input — even though it's hidden, it may still be discoverable.
- For crop functionality, use react-image-crop: show the crop UI after selection, before the preview is finalized. The crop output is a new File/Blob that replaces `pendingFile`.

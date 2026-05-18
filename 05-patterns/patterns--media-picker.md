# Pattern: Media Picker (Library + Upload)

## Overview
A media picker combining an existing library with an upload tab is far more useful than a plain file input — users frequently want to reuse a previously uploaded image rather than re-upload it. The library tab enables search and reuse; the upload tab handles new assets. Upload progress should be visible in the library tab immediately after upload completes, so users know their asset is available. Maximum selection count and file type filtering prevent invalid selections before the user hits submit.

## Implementation

### Picker State
```tsx
type MediaPickerTab = 'library' | 'upload'
type MediaType = 'image' | 'video' | 'document' | 'any'

interface MediaAsset {
  id: string
  url: string
  thumbnailUrl: string
  name: string
  type: MediaType
  size: number
  uploadedAt: string
}

interface MediaPickerState {
  tab: MediaPickerTab
  searchQuery: string
  selected: Set<string>
  uploadQueue: UploadItem[]
}

interface UploadItem {
  id: string
  file: File
  progress: number      // 0–100
  status: 'uploading' | 'complete' | 'error'
  asset?: MediaAsset    // set on complete
  error?: string
}
```

### Upload with Progress
```tsx
function uploadFile(
  file: File,
  onProgress: (pct: number) => void
): { promise: Promise<MediaAsset>; abort: () => void } {
  const controller = new AbortController()

  const promise = new Promise<MediaAsset>(async (resolve, reject) => {
    const formData = new FormData()
    formData.append('file', file)

    // XHR gives us upload progress — fetch doesn't
    const xhr = new XMLHttpRequest()

    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable) {
        onProgress(Math.round((e.loaded / e.total) * 100))
      }
    })

    xhr.addEventListener('load', () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve(JSON.parse(xhr.responseText) as MediaAsset)
      } else {
        reject(new Error(`Upload failed: ${xhr.status}`))
      }
    })

    xhr.addEventListener('error', () => reject(new Error('Network error')))

    controller.signal.addEventListener('abort', () => {
      xhr.abort()
      reject(new DOMException('Aborted', 'AbortError'))
    })

    xhr.open('POST', '/api/media/upload')
    xhr.send(formData)
  })

  return { promise, abort: () => controller.abort() }
}
```

### Drag and Drop Upload Zone
```tsx
function UploadDropZone({
  onFiles,
  accept,
  maxFiles,
}: {
  onFiles: (files: File[]) => void
  accept: string   // e.g. "image/*,video/*"
  maxFiles: number
}) {
  const [dragging, setDragging] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setDragging(false)
    const files = Array.from(e.dataTransfer.files).slice(0, maxFiles)
    onFiles(files)
  }

  return (
    <div
      onDragEnter={(e) => { e.preventDefault(); setDragging(true) }}
      onDragLeave={() => setDragging(false)}
      onDragOver={(e) => e.preventDefault()}
      onDrop={handleDrop}
      onClick={() => inputRef.current?.click()}
      role="button"
      aria-label="Drop files here or click to upload"
      className={[
        'border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors',
        dragging ? 'border-blue-400 bg-blue-50' : 'border-gray-300 hover:border-gray-400',
      ].join(' ')}
    >
      <p className="text-sm text-gray-500">
        Drag & drop here, or <span className="text-blue-600 underline">browse</span>
      </p>
      <p className="text-xs text-gray-400 mt-1">
        {accept.replace(/\*/g, 'files').replace(/,/g, ', ')} · Max {maxFiles} files
      </p>
      <input
        ref={inputRef}
        type="file"
        accept={accept}
        multiple={maxFiles > 1}
        className="sr-only"
        onChange={(e) => {
          const files = Array.from(e.target.files ?? []).slice(0, maxFiles)
          onFiles(files)
          e.target.value = '' // Reset so same file can be re-selected
        }}
      />
    </div>
  )
}
```

### Media Picker Component
```tsx
function MediaPicker({
  maxSelection = 1,
  accept = 'image/*',
  onConfirm,
  onCancel,
}: {
  maxSelection?: number
  accept?: string
  onConfirm: (assets: MediaAsset[]) => void
  onCancel: () => void
}) {
  const [tab, setTab] = useState<MediaPickerTab>('library')
  const [searchQuery, setSearchQuery] = useState('')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [uploadQueue, setUploadQueue] = useState<UploadItem[]>([])

  const { data: library = [] } = useQuery({
    queryKey: ['media-library', searchQuery],
    queryFn: () => fetchMediaLibrary({ query: searchQuery }),
  })

  const toggleSelect = (id: string) => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) {
        next.delete(id)
      } else if (next.size < maxSelection) {
        next.add(id)
      }
      return next
    })
  }

  const handleUpload = async (files: File[]) => {
    const items: UploadItem[] = files.map((f) => ({
      id: crypto.randomUUID(),
      file: f,
      progress: 0,
      status: 'uploading' as const,
    }))

    setUploadQueue((prev) => [...prev, ...items])

    for (const item of items) {
      const { promise } = uploadFile(item.file, (pct) => {
        setUploadQueue((prev) =>
          prev.map((u) => u.id === item.id ? { ...u, progress: pct } : u)
        )
      })

      try {
        const asset = await promise
        setUploadQueue((prev) =>
          prev.map((u) => u.id === item.id ? { ...u, status: 'complete', asset, progress: 100 } : u)
        )
        // Auto-switch to library tab to show the newly uploaded asset
        setTab('library')
      } catch {
        setUploadQueue((prev) =>
          prev.map((u) => u.id === item.id ? { ...u, status: 'error', error: 'Upload failed' } : u)
        )
      }
    }
  }

  const selectedAssets = library.filter((a) => selected.has(a.id))

  return (
    <div className="flex flex-col h-full">
      {/* Tabs */}
      <div role="tablist" className="flex border-b">
        {(['library', 'upload'] as const).map((t) => (
          <button
            key={t}
            role="tab"
            aria-selected={tab === t}
            onClick={() => setTab(t)}
            className={[
              'px-4 py-2 text-sm capitalize border-b-2 -mb-px transition-colors',
              tab === t ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-600',
            ].join(' ')}
          >
            {t}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div className="flex-1 overflow-y-auto p-3">
        {tab === 'library' ? (
          <>
            <input
              type="search"
              placeholder="Search media..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full border rounded-md px-3 py-1.5 text-sm mb-3"
              aria-label="Search media library"
            />

            <div
              role="listbox"
              aria-label="Media library"
              aria-multiselectable={maxSelection > 1}
              className="grid grid-cols-3 gap-2"
            >
              {library.map((asset) => (
                <button
                  key={asset.id}
                  role="option"
                  aria-selected={selected.has(asset.id)}
                  onClick={() => toggleSelect(asset.id)}
                  disabled={!selected.has(asset.id) && selected.size >= maxSelection}
                  className={[
                    'relative aspect-square rounded overflow-hidden border-2 transition-colors',
                    selected.has(asset.id) ? 'border-blue-500' : 'border-transparent hover:border-gray-300',
                    !selected.has(asset.id) && selected.size >= maxSelection ? 'opacity-40 cursor-not-allowed' : '',
                  ].join(' ')}
                >
                  <img src={asset.thumbnailUrl} alt={asset.name} className="w-full h-full object-cover" />
                  {selected.has(asset.id) && (
                    <div className="absolute inset-0 bg-blue-500/20 flex items-center justify-center">
                      <span className="bg-blue-600 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs">✓</span>
                    </div>
                  )}
                </button>
              ))}
            </div>

            {/* In-progress uploads shown in library tab */}
            {uploadQueue.filter((u) => u.status === 'uploading').map((u) => (
              <div key={u.id} className="flex items-center gap-2 mt-2 text-xs text-gray-500">
                <div className="flex-1 h-1 bg-gray-200 rounded overflow-hidden">
                  <div className="h-full bg-blue-500 transition-all" style={{ width: `${u.progress}%` }} />
                </div>
                <span>{u.progress}% · {u.file.name}</span>
              </div>
            ))}
          </>
        ) : (
          <UploadDropZone onFiles={handleUpload} accept={accept} maxFiles={maxSelection} />
        )}
      </div>

      {/* Footer */}
      <div className="border-t px-3 py-2 flex items-center justify-between">
        <span className="text-xs text-gray-500">
          {selected.size} of {maxSelection} selected
        </span>
        <div className="flex gap-2">
          <button type="button" onClick={onCancel} className="px-3 py-1.5 text-sm border rounded">
            Cancel
          </button>
          <button
            type="button"
            disabled={selected.size === 0}
            onClick={() => onConfirm(selectedAssets)}
            className="px-3 py-1.5 text-sm bg-blue-600 text-white rounded disabled:opacity-40"
          >
            Confirm
          </button>
        </div>
      </div>
    </div>
  )
}
```

## Key Rules
- Use XHR for uploads, not fetch — only XHR exposes `xhr.upload.progress` events needed for progress tracking
- Auto-switch to the library tab after a successful upload — users expect to see their uploaded asset immediately available for selection
- Show upload progress indicators in the library tab, not just the upload tab — this confirms the asset is being added to their library
- `role="listbox"` + `role="option"` + `aria-selected` on the grid — correct ARIA for a visual multi-select grid
- Disable unselected items (with visual feedback) when `maxSelection` is reached — don't silently ignore clicks beyond the limit
- Reset `input[type=file].value` after selecting — allows re-selecting the same file after clearing
- File type filtering via `accept` attribute on the input — also filter drag-and-drop files with MIME type checks
- The "Confirm" button stays disabled until at least one item is selected — submitting an empty picker is a user error

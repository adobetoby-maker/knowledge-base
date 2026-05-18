# plugin--excalidraw

Excalidraw is an open-source whiteboard/diagramming component with a hand-drawn aesthetic. The `@excalidraw/excalidraw` package exposes the full editor as a React component.

## Basic Component Setup

```tsx
import { Excalidraw } from '@excalidraw/excalidraw';
import '@excalidraw/excalidraw/index.css'; // required — includes fonts and base styles

<Excalidraw
  onChange={(elements, appState, files) => {
    // called on every change — elements are the shapes, appState is viewport/selection
    saveToDatabase({ elements, appState, files });
  }}
  initialData={{ elements: savedElements, appState: savedAppState, files: savedFiles }}
/>
```

The component is uncontrolled by design — it manages its own internal state and notifies you via `onChange`. Do not try to pass `elements` as a controlled prop on every render; that causes cursor jumps and re-render loops.

## onChange for State Persistence

`onChange` fires on every pointer event during drawing, which can be hundreds of times per second. Never write directly to a database on every `onChange` call. Debounce or throttle:

```ts
const debouncedSave = useMemo(
  () => debounce((elements, appState, files) => {
    saveToDatabase({ elements, appState, files });
  }, 1000),
  []
);
```

The `elements` array is serializable JSON — store it as-is. `appState` contains viewport position, scroll, zoom, and selection — include it to restore the user's exact view. `files` is a map of binary file content (embedded images) keyed by fileId.

## initialData to Restore Saved State

Pass saved data to `initialData` once on mount. Since the component is uncontrolled, this is the only time the initial state is applied:

```tsx
const [initialData, setInitialData] = useState(null);

useEffect(() => {
  loadFromDatabase().then((data) => setInitialData(data));
}, []);

if (!initialData) return <Spinner />;

return <Excalidraw initialData={initialData} onChange={...} />;
```

Render the component only after `initialData` is ready. Rendering with `initialData={null}` then updating it later does not re-initialize the canvas — the component ignores `initialData` changes after mount. This is the correct gate pattern.

## Exporting to SVG and PNG

Use the imperative export utilities, not the UI export button:

```ts
import { exportToSvg, exportToBlob } from '@excalidraw/excalidraw';

// SVG export
const svg = await exportToSvg({
  elements,
  appState: { ...appState, exportWithDarkMode: false },
  files,
  exportPadding: 16,
});
const svgString = new XMLSerializer().serializeToString(svg);

// PNG export (as Blob)
const blob = await exportToBlob({
  elements,
  appState,
  files,
  mimeType: 'image/png',
  quality: 1,
  getDimensions: () => ({ width: 1920, height: 1080, scale: 2 }), // 2x for retina
});
const url = URL.createObjectURL(blob);
```

`exportToSvg` returns an SVG DOM element. `exportToBlob` returns a PNG/JPEG Blob. Both are async. These functions work outside the component context — useful for server-side thumbnail generation if you persist the elements.

## Embedding in a Modal Without Full-Screen Takeover

The component defaults to filling its container. To embed in a modal, constrain the container:

```tsx
<div style={{ width: '100%', height: '600px', position: 'relative' }}>
  <Excalidraw
    UIOptions={{
      canvasActions: { saveToActiveFile: false, loadScene: false }, // remove file menu items
    }}
  />
</div>
```

The `UIOptions.canvasActions` prop lets you hide toolbar items that don't make sense in an embedded context (save, load, export, theme toggle). Without this, the full VS Code-like toolbar appears, which looks odd in a dialog.

Set the container to `position: relative` — the component uses absolute positioning internally and needs a positioned ancestor to constrain itself. If the parent doesn't have a defined height, the canvas collapses to 0px.

## Key Rules

- **`onChange` is high-frequency** — always debounce before any I/O (1000ms is a good starting point)
- **Render after `initialData` is ready** — conditionally render the component; updating `initialData` post-mount has no effect
- **Persist `elements`, `appState`, AND `files`** — missing `files` drops embedded images on restore
- **Container needs explicit height and `position: relative`** — or the canvas collapses
- **Use `UIOptions.canvasActions`** to remove irrelevant toolbar actions in embedded contexts
- `exportToSvg` / `exportToBlob` for programmatic export — accessible outside the component with just the persisted elements

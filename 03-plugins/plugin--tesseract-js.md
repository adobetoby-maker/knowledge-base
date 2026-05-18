# plugin--tesseract-js

Tesseract.js is a pure-JavaScript port of the Tesseract OCR engine. It runs in both Node.js and browsers, downloading language data packs on first use. It recognizes printed text in images and returns words with bounding boxes.

## createWorker with Language Pack

```ts
import Tesseract from 'tesseract.js';

const worker = await Tesseract.createWorker('eng', 1, {
  logger: (m) => console.log(m), // progress events: loading, recognizing 0.75, etc.
  workerPath: ...,   // optional: override CDN path for worker script
  langPath: ...,     // optional: override CDN path for language data
  corePath: ...,     // optional: override CDN path for core WASM
});
```

The second argument is the OEM (OCR Engine Mode): `1` = LSTM neural net (most accurate for modern Tesseract), `0` = legacy, `3` = both. Use `1` for general use. Language packs download automatically from jsDelivr CDN on first `createWorker`. In offline or restricted environments, host the `.traineddata` files yourself and set `langPath`.

Language codes: `'eng'` (English), `'jpn'` (Japanese), `'chi_sim'` (Simplified Chinese), `'deu'` (German). Multiple languages: `'eng+deu'`.

## recognize() — Words and Bounding Boxes

```ts
const { data } = await worker.recognize('/path/to/image.png');

// Full text
console.log(data.text);

// Word-level with bounding boxes
data.words.forEach((word) => {
  console.log(word.text, word.confidence);
  console.log(word.bbox); // { x0, y0, x1, y1 } in pixels
});

// Block/paragraph/line hierarchy also available:
// data.blocks, data.paragraphs, data.lines
```

`confidence` is 0–100 — below ~70, treat the result as uncertain. For document parsing (e.g., structured forms), use bounding boxes to assign words to rows/columns by comparing `y0` proximity.

## Preprocessing for Better Accuracy

Tesseract's LSTM model works best on high-contrast, horizontal, printed text. Image quality is the single largest factor in accuracy.

```ts
// Using Sharp for preprocessing before passing to Tesseract
import sharp from 'sharp';

const preprocessed = await sharp(imageBuffer)
  .greyscale()                         // remove color noise
  .normalise()                         // stretch contrast to full range
  .threshold(128)                      // binarize: pixels above 128 → white, below → black
  .resize({ width: 2000, withoutEnlargement: false }) // Tesseract works better at ~300 DPI equivalent
  .png()
  .toBuffer();

const { data } = await worker.recognize(preprocessed);
```

When to apply each step:
- **Greyscale** — almost always; color adds noise without helping OCR
- **Threshold / binarize** — helps with low-contrast or watermarked images; hurts on photos with gradient backgrounds
- **Upscale** — Tesseract performs well at ~300 DPI; phone photos at full resolution are usually fine, but small thumbnails need upscaling
- **Deskew** — skewed text (scanned at an angle) dramatically lowers accuracy. Sharp's `rotate` with auto-detect, or `sharp.stats()` to detect angle, helps here

## Memory Cleanup with worker.terminate()

Each `createWorker` call spawns a background thread (Web Worker in browser, worker thread in Node). These are not garbage collected automatically.

```ts
const worker = await Tesseract.createWorker('eng');
try {
  const { data } = await worker.recognize(image);
  return data.text;
} finally {
  await worker.terminate(); // releases the worker thread and downloaded language data
}
```

In a server processing many images, reuse a worker pool rather than creating one per image — worker initialization (language pack loading) takes 1–3 seconds. Terminate workers on server shutdown (`SIGTERM`).

For browser use, create one worker on mount and terminate on component unmount:
```ts
useEffect(() => {
  const init = async () => { workerRef.current = await Tesseract.createWorker('eng'); };
  init();
  return () => { workerRef.current?.terminate(); };
}, []);
```

## Accuracy Limitations

Tesseract.js is not a production-grade document intelligence solution. Know its limits:
- **Handwriting**: very poor — use a specialized model
- **Rotated/curved text**: fails without preprocessing
- **Tables**: no native table structure recognition; use bounding box geometry to reconstruct
- **Mixed languages on one page**: accuracy degrades; specify all languages in the language string
- **PDFs**: convert to images first (e.g., with `pdf2pic` or `pdfjs-dist`); Tesseract cannot process PDF directly
- **Confidence threshold**: reject words below 60–70 confidence rather than using them as-is

## Key Rules

- **OEM mode `1`** (LSTM) for best accuracy on modern printed text
- **Preprocess images**: greyscale + normalize + threshold before recognition
- **Always `worker.terminate()`** in `finally` — workers are not GC'd automatically
- **Reuse workers** in servers — initialization is 1–3s; don't create per request
- **Bounding boxes** are in pixel coordinates relative to the input image — account for any resize/crop done during preprocessing
- Do not use for handwriting, curved text, or PDFs without image conversion

# Pattern: Image Upload with Inline Crop

## Why This Pattern Matters

Showing a crop step before upload prevents round-trips: the user sees exactly what will be saved and adjusts it in-browser before any bytes hit the server. Without this, users upload, see a badly framed avatar, and upload again — worse UX and unnecessary storage costs.

## Library: react-image-crop

Use `react-image-crop` for the crop UI. It provides a draggable/resizable crop selection over the image and tracks the crop in pixel coordinates.

```tsx
import ReactCrop, { type Crop, type PixelCrop } from 'react-image-crop';
import 'react-image-crop/dist/ReactCrop.css';

const [imgSrc, setImgSrc] = useState('');
const [crop, setCrop] = useState<Crop>();
const imgRef = useRef<HTMLImageElement>(null);
```

File selection → read as data URL → show crop UI → user adjusts → export via canvas → upload.

## File Input to DataURL

```ts
function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
  const file = e.target.files?.[0];
  if (!file) return;

  // Validate file type
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
    setError('Only JPEG, PNG, and WebP images are supported');
    return;
  }

  const reader = new FileReader();
  reader.onload = () => setImgSrc(reader.result as string);
  reader.readAsDataURL(file);
}
```

Show the crop UI only after `imgSrc` is set — don't show an empty crop component.

## Enforcing Aspect Ratio

Pass `aspect` prop to `ReactCrop` for locked ratios (1 for square avatars, 16/9 for banners):

```tsx
<ReactCrop
  crop={crop}
  onChange={setCrop}
  aspect={1}       // square crop
  circularCrop     // optional: circular preview for avatars
  minWidth={100}   // minimum crop dimensions
  minHeight={100}
>
  <img ref={imgRef} src={imgSrc} onLoad={onImageLoad} />
</ReactCrop>
```

On `onLoad`, set a default centered crop that fills most of the image so the user sees a reasonable default rather than an empty selection:

```ts
function onImageLoad(e: React.SyntheticEvent<HTMLImageElement>) {
  const { naturalWidth: w, naturalHeight: h } = e.currentTarget;
  const crop = centerCrop(makeAspectCrop({ unit: '%', width: 90 }, 1, w, h), w, h);
  setCrop(crop);
}
```

## Exporting Cropped Pixels via Canvas

The crop coordinates from `ReactCrop` are relative to the displayed image, not the natural size. Scale them up before drawing.

```ts
async function getCroppedBlob(
  image: HTMLImageElement,
  pixelCrop: PixelCrop,
): Promise<Blob> {
  const canvas = document.createElement('canvas');
  const scaleX = image.naturalWidth / image.width;
  const scaleY = image.naturalHeight / image.height;

  canvas.width = pixelCrop.width * scaleX;
  canvas.height = pixelCrop.height * scaleY;

  const ctx = canvas.getContext('2d')!;
  ctx.drawImage(
    image,
    pixelCrop.x * scaleX, pixelCrop.y * scaleY,
    pixelCrop.width * scaleX, pixelCrop.height * scaleY,
    0, 0, canvas.width, canvas.height,
  );

  return new Promise(res => canvas.toBlob(b => res(b!), 'image/jpeg', 0.9));
}
```

## Minimum Resolution Validation

After computing natural crop dimensions, reject if below threshold:

```ts
const croppedWidth = pixelCrop.width * scaleX;
const croppedHeight = pixelCrop.height * scaleY;
if (croppedWidth < 200 || croppedHeight < 200) {
  setError('Crop area is too small. Minimum 200×200px.');
  return;
}
```

## Upload Flow

Crop is shown in a modal. "Apply" exports via canvas and closes the modal. The preview thumbnail updates immediately (optimistic). The actual upload fires to your storage endpoint with `FormData`. On error, revert the thumbnail.

## Key Rules

- Scale crop coordinates by `naturalWidth/displayWidth` before canvas draw
- Enforce minimum crop dimensions before upload, not after server response
- Default crop is centered and fills 90% — never start with empty crop selection
- `circularCrop` prop for avatar contexts; `aspect={1}` for square enforcement
- Canvas export uses `toBlob` with `image/jpeg` at 0.9 quality — not `toDataURL` (it's slower and produces base64 strings)
- Modal closes only after successful export — not before
- File type validation client-side, MIME type validation server-side (client can lie)

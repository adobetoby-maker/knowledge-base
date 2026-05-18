# Pattern: GIF Picker (Giphy/Tenor Integration)

## Problem

GIF pickers need debounced search to avoid hammering the API, infinite-scroll results in a grid layout, a `prefers-reduced-motion` check that substitutes static thumbnails, and file size awareness before insertion since GIFs can be very large.

## API Setup (Giphy)

```ts
const GIPHY_BASE = 'https://api.giphy.com/v1/gifs';
const API_KEY = process.env.NEXT_PUBLIC_GIPHY_KEY!;

type GifResult = {
  id: string;
  title: string;
  images: {
    fixed_height: { url: string; width: string; height: string; size: string };
    fixed_height_still: { url: string };  // static thumbnail for reduced-motion
    original: { size: string; url: string };
  };
};

async function searchGifs(query: string, offset = 0, limit = 20): Promise<{ data: GifResult[]; total: number }> {
  const url = query
    ? `${GIPHY_BASE}/search?api_key=${API_KEY}&q=${encodeURIComponent(query)}&offset=${offset}&limit=${limit}&rating=g`
    : `${GIPHY_BASE}/trending?api_key=${API_KEY}&offset=${offset}&limit=${limit}&rating=g`;

  const res = await fetch(url);
  const json = await res.json();
  return { data: json.data, total: json.pagination.total_count };
}
```

Show trending GIFs when the search query is empty — an empty grid is a poor first impression.

## Debounced Search

```tsx
function useGifSearch() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<GifResult[]>([]);
  const [offset, setOffset] = useState(0);
  const [loading, setLoading] = useState(false);

  // Debounce: wait 400ms after last keystroke before searching
  useEffect(() => {
    const id = setTimeout(async () => {
      setLoading(true);
      setOffset(0);
      const { data } = await searchGifs(query, 0);
      setResults(data);
      setLoading(false);
    }, 400);
    return () => clearTimeout(id);
  }, [query]);

  async function loadMore() {
    const nextOffset = offset + 20;
    setLoading(true);
    const { data } = await searchGifs(query, nextOffset);
    setResults(prev => [...prev, ...data]);
    setOffset(nextOffset);
    setLoading(false);
  }

  return { query, setQuery, results, loading, loadMore };
}
```

WHY 400ms debounce: shorter (200ms) fires too often on fast typists; longer feels sluggish. 400ms is the sweet spot for search UIs.

## Reduced-Motion: Static Thumbnails

Animated GIFs can cause vestibular issues. Check `prefers-reduced-motion` and show the static thumbnail:

```tsx
function GifItem({ gif, onSelect }: { gif: GifResult; onSelect: (gif: GifResult) => void }) {
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const src = reducedMotion
    ? gif.images.fixed_height_still.url   // static PNG thumbnail
    : gif.images.fixed_height.url;        // animated GIF

  return (
    <button
      type="button"
      onClick={() => onSelect(gif)}
      className="relative overflow-hidden rounded"
      aria-label={gif.title || 'GIF'}
    >
      <img src={src} alt={gif.title} loading="lazy" className="h-32 w-full object-cover" />
      {reducedMotion && (
        <span className="absolute bottom-1 right-1 rounded bg-black/50 px-1 text-xs text-white">GIF</span>
      )}
    </button>
  );
}
```

## Size Limit Check Before Insert

Inserting a 10MB GIF into a chat message is bad. Check `original.size` before accepting:

```ts
const MAX_GIF_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB

function handleSelect(gif: GifResult, onInsert: (url: string) => void) {
  const sizeBytes = parseInt(gif.images.original.size ?? '0', 10);
  if (sizeBytes > MAX_GIF_SIZE_BYTES) {
    toast.error(`GIF is too large (${(sizeBytes / 1024 / 1024).toFixed(1)} MB). Maximum is 5 MB.`);
    return;
  }
  onInsert(gif.images.fixed_height.url);
}
```

WHY use `fixed_height` URL, not `original`: `fixed_height` GIFs are typically 60–90% smaller than the original while looking identical at 200px display width.

## Infinite Scroll Grid

```tsx
function GifPicker({ onSelect }: { onSelect: (url: string) => void }) {
  const { query, setQuery, results, loading, loadMore } = useGifSearch();
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const io = new IntersectionObserver(([e]) => { if (e.isIntersecting) loadMore(); });
    if (bottomRef.current) io.observe(bottomRef.current);
    return () => io.disconnect();
  }, [results]);

  return (
    <div className="w-72 rounded-xl border bg-white shadow-lg">
      <div className="p-2">
        <input
          type="search"
          placeholder="Search GIFs..."
          value={query}
          onChange={e => setQuery(e.target.value)}
          className="w-full rounded-md border px-3 py-1.5 text-sm"
        />
      </div>
      <div className="grid grid-cols-2 gap-1 max-h-80 overflow-y-auto p-2">
        {results.map(gif => (
          <GifItem key={gif.id} gif={gif} onSelect={g => handleSelect(g, onSelect)} />
        ))}
        <div ref={bottomRef} />
      </div>
      {loading && <p className="py-2 text-center text-xs text-gray-400">Loading...</p>}
    </div>
  );
}
```

## Key Rules

- Show trending GIFs when query is empty, not an empty grid
- Debounce search input at 400ms; reset offset to 0 on new query
- Check `prefers-reduced-motion` — show static thumbnail, not animated GIF
- Enforce a size limit (5 MB) using the API's `size` field before inserting
- Use `fixed_height` variant for display, not `original` — much smaller file
- `loading="lazy"` on every `<img>` to defer off-screen GIF loading

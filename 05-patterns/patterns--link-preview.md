# Pattern: URL Unfurl / Link Preview Card

## Overview
Fetching OG metadata from the client hits CORS walls on most sites and exposes the server-side fetch as a scraping vector. Doing it server-side with caching prevents redundant fetches, keeps response times fast, and lets you sanitize before rendering. The pattern exists to prevent XSS from arbitrary fetched HTML and to give users a meaningful preview without blocking the paste action.

## Server-Side Fetch Endpoint

```ts
// POST /api/link-preview
// Body: { url: string }
// Never trust the client to fetch OG data — CORS blocks it and you lose control
export async function POST(req: Request) {
  const { url } = await req.json();

  // Validate protocol first — block file://, javascript:, data:, ftp://
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return Response.json({ error: 'invalid_url' }, { status: 400 });
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    return Response.json({ error: 'disallowed_protocol' }, { status: 400 });
  }

  // Check cache before fetching — OG data rarely changes
  const cacheKey = `og:${url}`;
  const cached = await db.linkPreviews.findUnique({ where: { url } });
  if (cached && Date.now() - cached.fetchedAt.getTime() < 1000 * 60 * 60 * 24) {
    // Cache for 24 hours — OG tags don't change often
    return Response.json(cached);
  }

  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': 'LinkPreviewBot/1.0' },
      signal: AbortSignal.timeout(5000), // Don't hang on slow sites
    });
    const html = await res.text();
    const meta = parseOGTags(html); // Extract only known safe fields
    await db.linkPreviews.upsert({
      where: { url },
      create: { url, ...meta, fetchedAt: new Date() },
      update: { ...meta, fetchedAt: new Date() },
    });
    return Response.json(meta);
  } catch {
    // Return partial data — better to show the URL than nothing
    return Response.json({ url, title: null, description: null, image: null });
  }
}
```

## OG Tag Extraction

```ts
function parseOGTags(html: string) {
  // Use regex on the <head> only — avoid parsing full HTML (slow, error-prone)
  const head = html.match(/<head[^>]*>([\s\S]*?)<\/head>/i)?.[1] ?? '';

  function og(property: string) {
    return (
      head.match(new RegExp(`<meta[^>]+property=["']og:${property}["'][^>]+content=["']([^"']+)["']`, 'i'))?.[1] ??
      head.match(new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:${property}["']`, 'i'))?.[1] ??
      null
    );
  }

  const title = og('title') ?? head.match(/<title[^>]*>([^<]+)<\/title>/i)?.[1]?.trim() ?? null;

  return {
    title: title?.slice(0, 200) ?? null,          // Truncate — don't store unlimited text
    description: og('description')?.slice(0, 500) ?? null,
    image: og('image') ?? null,                   // Raw URL — validate before rendering
    siteName: og('site_name') ?? null,
  };
}
```

## Client Component

```tsx
function LinkPreviewCard({ url }: { url: string }) {
  const [preview, setPreview] = useState<OGData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/link-preview', {
      method: 'POST',
      body: JSON.stringify({ url }),
      headers: { 'Content-Type': 'application/json' },
    })
      .then(r => r.json())
      .then(data => { setPreview(data); setLoading(false); });
  }, [url]);

  if (loading) return <LinkPreviewSkeleton />;

  // Fallback: show URL with domain icon when no OG data
  if (!preview?.title) {
    return (
      <a href={url} className="link-preview link-preview--minimal" target="_blank" rel="noopener noreferrer">
        <span className="link-preview__url">{new URL(url).hostname}</span>
      </a>
    );
  }

  return (
    <a href={url} className="link-preview" target="_blank" rel="noopener noreferrer">
      {preview.image && (
        // NEVER set innerHTML or use an iframe for the fetched image
        // Use a standard <img> — the src is a URL, not raw HTML
        <img
          src={preview.image}
          alt=""
          className="link-preview__image"
          onError={e => (e.currentTarget.style.display = 'none')}
        />
      )}
      <div className="link-preview__body">
        <p className="link-preview__title">{preview.title}</p>
        {preview.description && <p className="link-preview__desc">{preview.description}</p>}
        <span className="link-preview__domain">{new URL(url).hostname}</span>
      </div>
    </a>
  );
}
```

## Key Rules
- Always fetch OG data server-side — client-side fetch fails CORS on most origins
- Validate URL protocol before fetching — block `javascript:`, `data:`, `file:`
- Cache results in the database with a TTL (24h is reasonable)
- Truncate all stored strings — prevent unbounded DB column growth
- Render the image with `<img src>`, never `innerHTML` — the content is untrusted
- Show a skeleton state while loading, and a minimal fallback when OG data is absent
- Set a fetch timeout (5s) to prevent hanging on unresponsive URLs
- Add `rel="noopener noreferrer"` on all external links from previews

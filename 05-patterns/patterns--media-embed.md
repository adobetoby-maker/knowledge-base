# Pattern: Media Embed (YouTube / Vimeo / Tweet)

## Overview
Loading the full YouTube or Twitter widget JS on page load adds hundreds of KB and triggers third-party cookie consent issues, even for embeds the user never interacts with. The pattern renders a poster image with a play button — loading the actual embed iframe only when clicked. URL sanitization against an allowlist prevents iframe injection with arbitrary URLs (file://, data:, javascript: URLs).

## URL Extraction and Validation

```ts
// Extract embed ID from the URL — never trust the full URL as the iframe src
// Always reconstruct the embed URL from the extracted ID and a hardcoded base

type EmbedType = 'youtube' | 'vimeo' | 'tweet' | null;

interface EmbedInfo {
  type: EmbedType;
  id: string;
  embedUrl: string;
  thumbnailUrl: string;
}

// Allowlisted embed URL constructors — the ONLY valid sources
const EMBED_CONSTRUCTORS: Record<NonNullable<EmbedType>, (id: string) => string> = {
  youtube: (id) => `https://www.youtube-nocookie.com/embed/${id}?autoplay=1`,
  vimeo:   (id) => `https://player.vimeo.com/video/${id}?autoplay=1`,
  tweet:   (id) => `https://platform.twitter.com/embed/Tweet.html?id=${id}`,
};

function parseMediaUrl(url: string): EmbedInfo | null {
  // Validate URL is safe before processing
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) return null;

  // YouTube: youtube.com/watch?v=ID or youtu.be/ID
  const ytMatch =
    parsed.hostname.endsWith('youtube.com') && parsed.searchParams.get('v') ||
    parsed.hostname === 'youtu.be' && parsed.pathname.slice(1);
  if (ytMatch && /^[\w-]{11}$/.test(ytMatch)) {
    return {
      type: 'youtube',
      id: ytMatch,
      embedUrl: EMBED_CONSTRUCTORS.youtube(ytMatch),
      // youtube-nocookie thumbnail works the same as regular youtube
      thumbnailUrl: `https://img.youtube.com/vi/${ytMatch}/hqdefault.jpg`,
    };
  }

  // Vimeo: vimeo.com/ID
  const vimeoMatch = parsed.hostname === 'vimeo.com' && parsed.pathname.match(/^\/(\d+)/)?.[1];
  if (vimeoMatch) {
    return {
      type: 'vimeo',
      id: vimeoMatch,
      embedUrl: EMBED_CONSTRUCTORS.vimeo(vimeoMatch),
      // Vimeo thumbnail requires an API call — use a placeholder initially
      thumbnailUrl: `/api/vimeo-thumb/${vimeoMatch}`,
    };
  }

  // Twitter/X: twitter.com/anything/status/ID
  const tweetMatch = (parsed.hostname === 'twitter.com' || parsed.hostname === 'x.com')
    && parsed.pathname.match(/\/status\/(\d+)/)?.[1];
  if (tweetMatch) {
    return {
      type: 'tweet',
      id: tweetMatch,
      embedUrl: EMBED_CONSTRUCTORS.tweet(tweetMatch),
      thumbnailUrl: '', // Tweets don't have thumbnails
    };
  }

  return null; // Unsupported URL — don't render
}
```

## Lazy-Load Embed Component

```tsx
function MediaEmbed({ url }: { url: string }) {
  const embed = useMemo(() => parseMediaUrl(url), [url]);
  const [active, setActive] = useState(false);

  if (!embed) {
    // Unsupported URL: render as a plain link — never as an iframe
    return <a href={url} target="_blank" rel="noopener noreferrer">{url}</a>;
  }

  return (
    <div
      className="media-embed"
      style={{
        // Responsive aspect ratio container — 16:9 for video, auto for tweets
        aspectRatio: embed.type === 'tweet' ? 'auto' : '16 / 9',
        position: 'relative',
        overflow: 'hidden',
        background: '#000',
        borderRadius: 8,
      }}
    >
      {active ? (
        // Only create the iframe when user explicitly clicks play
        // This prevents the page from loading YouTube JS for every embed on load
        <iframe
          src={embed.embedUrl}
          className="media-embed__iframe"
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', border: 'none' }}
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowFullScreen
          title={`${embed.type} embed`}
          // sandbox attribute limits iframe capabilities
          sandbox="allow-scripts allow-same-origin allow-presentation allow-popups"
        />
      ) : (
        // Poster image with play button — no third-party JS loaded at all
        <button
          className="media-embed__poster"
          onClick={() => setActive(true)}
          aria-label={`Play ${embed.type} video`}
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', padding: 0, border: 'none', cursor: 'pointer' }}
        >
          {embed.thumbnailUrl && (
            <img
              src={embed.thumbnailUrl}
              alt=""
              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
              loading="lazy"
            />
          )}
          <div className="media-embed__play-icon" aria-hidden="true">▶</div>
        </button>
      )}
    </div>
  );
}
```

## Sandbox Attribute

```
// sandbox values — grant minimum needed permissions:
// allow-scripts       — required for the embed player to function
// allow-same-origin   — required for Vimeo/YouTube cookies/auth
// allow-presentation  — required for fullscreen
// allow-popups        — required for Twitter share buttons

// Do NOT include: allow-forms, allow-top-navigation, allow-downloads
// These allow the embed to navigate away from your page or submit forms
```

## Supported Embed Types

```ts
// Extend by adding to EMBED_CONSTRUCTORS and parseMediaUrl
// Never add a catch-all "any URL as iframe" fallback — that defeats the allowlist
const SUPPORTED_DOMAINS = [
  'youtube.com', 'youtu.be',     // YouTube
  'vimeo.com',                    // Vimeo
  'twitter.com', 'x.com',        // Twitter/X
  // 'loom.com',                  // Add as needed
];
```

## Key Rules
- Parse the URL and reconstruct the embed URL from a hardcoded template — never use the raw URL as `src`
- Maintain an allowlist of embed domains — reject anything not on the list
- Validate URL protocol before processing — reject `javascript:`, `data:`, `file:`
- Use `www.youtube-nocookie.com` for YouTube embeds — reduces cookie footprint
- Load the iframe only on click (poster image first) — prevents loading third-party JS for every embed on page load
- Add `sandbox` attribute with minimum required permissions — blocks navigation and form submission from the iframe
- Use `aspect-ratio: 16/9` container for video embeds — no `padding-bottom: 56.25%` hacks
- Render unsupported URLs as plain `<a>` links, not iframes

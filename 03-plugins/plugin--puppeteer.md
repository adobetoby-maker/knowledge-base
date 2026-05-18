# plugin--puppeteer

Puppeteer is a headless Chromium automation library for scraping, screenshot capture, PDF generation, and end-to-end browser testing. It controls Chrome via the DevTools Protocol.

## Launch Configuration

```ts
import puppeteer from 'puppeteer';
const browser = await puppeteer.launch({
  headless: 'new',        // use 'new' headless mode — legacy `true` is deprecated
  args: ['--no-sandbox', '--disable-setuid-sandbox'], // required in Docker/Lambda
});
const page = await browser.newPage();
```

`headless: 'new'` uses the real headless Chromium architecture (not the legacy `--headless` flag). On CI or containerized environments, `--no-sandbox` is required because root containers lack the kernel namespace support Chrome's sandbox depends on. Do not use `--no-sandbox` in development environments where it is unnecessary.

## waitFor Strategies — Choose the Right One

Choosing the wrong wait strategy is the most common source of flaky Puppeteer code.

| Strategy | When to use |
|---|---|
| `waitForSelector(selector)` | Waiting for a specific element to appear — most reliable |
| `waitUntil: 'domcontentloaded'` | Synchronous content that doesn't need JS execution |
| `waitUntil: 'networkidle0'` | Pages that fire XHR/fetch before rendering — waits until no network requests for 500ms |
| `waitUntil: 'networkidle2'` | Less strict — allows up to 2 in-flight requests (better for pages with analytics pings) |

```ts
await page.goto(url, { waitUntil: 'networkidle0' });
// OR for a specific element:
await page.waitForSelector('.main-content', { timeout: 10_000 });
```

Avoid `page.waitForTimeout()` (fixed sleep). It either over-waits or fails under load. Always wait for a condition, not a duration. `networkidle0` is not always appropriate — SPA frameworks that long-poll will never reach idle; use `waitForSelector` instead.

## Screenshot and PDF Generation

```ts
// Screenshot
await page.setViewport({ width: 1280, height: 900 });
const screenshot = await page.screenshot({
  type: 'png',
  fullPage: true,          // capture full scrollable page
  path: '/tmp/out.png',    // omit to get Buffer instead
});

// PDF (Chrome-only — not available on Firefox)
const pdf = await page.pdf({
  format: 'A4',
  printBackground: true,   // include CSS background colors/images
  margin: { top: '1cm', bottom: '1cm', left: '1cm', right: '1cm' },
});
```

PDF generation ignores viewport — it uses `@page` CSS rules and print media queries. Set `printBackground: true` or colored sections will be white. PDF returns a `Buffer` directly.

## Memory Leaks from Unclosed Browsers

Every `puppeteer.launch()` spawns a Chromium process. Failing to call `browser.close()` leaks the process permanently. The pattern to follow:

```ts
let browser;
try {
  browser = await puppeteer.launch({ headless: 'new' });
  const page = await browser.newPage();
  // ... work ...
} finally {
  if (browser) await browser.close();
}
```

In a long-running server, reuse a browser instance across requests with a pool (e.g., `puppeteer-cluster` or `generic-pool`). Opening and closing per-request is expensive (~200ms). Opening once and sharing risks a crashed tab bringing down the browser — implement health checks and restart logic.

## Running in Docker and Lambda

**Docker:** Use the official `ghcr.io/puppeteer/puppeteer` image, which ships Chromium with the correct shared libraries. When using a custom image, `apt-get install -y chromium` and pass `executablePath` to `launch()`. Always add `--no-sandbox --disable-setuid-sandbox` to args.

**Lambda / serverless:** Use `@sparticuz/chromium` (a lightweight, compressed Chromium binary for Lambda). It self-extracts to `/tmp`. Lambda's ephemeral filesystem and 512MB default memory are limiting — increase to at least 1024MB and set the function timeout to ≥30s for page loads.

```ts
import chromium from '@sparticuz/chromium';
const browser = await puppeteer.launch({
  args: chromium.args,
  executablePath: await chromium.executablePath(),
  headless: chromium.headless,
});
```

Do not bundle a full local Chromium in Lambda — the function package size limit (250MB unzipped) will be exceeded.

## Key Rules

- **`headless: 'new'`** — legacy `true` is deprecated and produces inconsistent behavior
- **`--no-sandbox` in containers** — required; Chrome's sandbox needs kernel namespaces root containers lack
- **Never `waitForTimeout()`** — wait for conditions (selector, network, navigation), never fixed sleeps
- **Always `browser.close()` in `finally`** — leaked browser processes accumulate silently
- **Reuse browser instances** in servers — per-request launch/close is too slow and memory-heavy
- **Lambda**: use `@sparticuz/chromium`, increase memory to ≥1024MB, extend timeout

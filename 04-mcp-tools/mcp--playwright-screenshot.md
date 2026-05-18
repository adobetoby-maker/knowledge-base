# MCP Tool: playwright / browser_take_screenshot

**Plugin:** `plugin:playwright:playwright`
**Tool name:** `mcp__plugin_playwright_playwright__browser_take_screenshot`
**What it does:** Captures the current browser state as a PNG image. Returns file path.

## Parameters
```json
{
  "fullPage": "boolean (optional) — capture entire scrollable page, default false"
}
```

## Basic Usage
```javascript
// Navigate first, then screenshot
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3000" })
mcp__plugin_playwright_playwright__browser_take_screenshot({})
// → returns: { path: "/tmp/screenshot-1234.png" }

// Full page capture
mcp__plugin_playwright_playwright__browser_take_screenshot({ fullPage: true })
```

## Mobile Screenshot
```javascript
// Resize viewport first for mobile view
mcp__plugin_playwright_playwright__browser_resize({ width: 375, height: 812 })
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3000" })
mcp__plugin_playwright_playwright__browser_take_screenshot({})
```

## Tablet Screenshot
```javascript
mcp__plugin_playwright_playwright__browser_resize({ width: 768, height: 1024 })
mcp__plugin_playwright_playwright__browser_take_screenshot({})
```

## Desktop Screenshot
```javascript
mcp__plugin_playwright_playwright__browser_resize({ width: 1280, height: 800 })
mcp__plugin_playwright_playwright__browser_take_screenshot({})
```

## Three-Width QA Loop
```javascript
const widths = [375, 768, 1280]
for (const width of widths) {
  await browser_resize({ width, height: 800 })
  await browser_navigate({ url })
  await browser_take_screenshot({})  // save/read each
}
```

## Response Shape
```json
{ "path": "/tmp/playwright-screenshot-abc123.png" }
```
Use `Read` tool on the path to view the image in context.

## When to Use vs screenshot.js
```
screenshot.js (node ~/screenshot.js 3000 0,540,1080):
  ✓ Multiple scroll positions in one command
  ✓ Outputs to /tmp/preview/ for easy bulk review
  ✗ Can't interact with page, can't click things

playwright browser_take_screenshot:
  ✓ Captures after real browser interactions
  ✓ Can take screenshot after clicking, filling forms
  ✓ More accurate rendering (real browser)
  ✗ One position at a time
```

## Common Failure
If screenshot is blank: page may still be loading. Add a wait:
```javascript
mcp__plugin_playwright_playwright__browser_wait_for({ 
  selector: "h1",  // wait for element to appear
  timeout: 5000 
})
mcp__plugin_playwright_playwright__browser_take_screenshot({})
```

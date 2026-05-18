# Screenshot Before Judging Your Own Code

**When:** After writing or modifying any UI code.
**Rule:** Take a screenshot before declaring the UI work done. What you think you built and what the browser renders are frequently different.

## Why This Matters
Mental models of CSS layout are unreliable. A flex container that "should" center its children often doesn't. A z-index that "should" work is getting trapped in a stacking context. The only source of truth is the rendered pixel.

## The Screenshot Workflow

### Option 1 — screenshot.js (fastest)
```bash
# Start your dev server first
cd /Users/drive/<project> && npx next dev -H 0.0.0.0 -p <port>

# Capture at multiple scroll depths (home, mid-page, footer)
node ~/screenshot.js <port> 0,540,1080

# Output goes to /tmp/preview/
open /tmp/preview/
```

### Option 2 — Chrome DevTools MCP (interactive)
```javascript
// Navigate to the page
mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page({ url: "http://localhost:3000" })

// Take screenshot
mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot({})
```

### Option 3 — Playwright (automated)
```javascript
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3000" })
mcp__plugin_playwright_playwright__browser_take_screenshot({})
// Resize to check mobile
mcp__plugin_playwright_playwright__browser_resize({ width: 375, height: 812 })
mcp__plugin_playwright_playwright__browser_take_screenshot({})
```

## What to Check in the Screenshot

**Layout:**
- Does the hero fill the viewport correctly?
- Are elements aligned as intended?
- Is there unexpected overflow or scroll on mobile?

**Typography:**
- Is the text readable at this size?
- Are line lengths reasonable (45-75 characters)?
- Is there hierarchy between heading levels?

**Spacing:**
- Are margins/padding consistent?
- Does it breathe without too much wasted space?

**Mobile (375px):**
- Does anything overflow horizontally?
- Are touch targets big enough?
- Is text not too small to read?

## Common Things Screenshots Catch
- `overflow: hidden` missing on a parent (content bleeds out)
- Background image not loading (path wrong or public/ prefix missing)
- Font not loading (FOUT flash, wrong weight)
- Elements overlapping due to stacking context
- Mobile: fixed-width elements causing horizontal scroll
- Dark mode: forgotten hardcoded colors (`text-gray-800` visible on dark background)

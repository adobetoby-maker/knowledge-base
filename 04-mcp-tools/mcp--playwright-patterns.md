# MCP: Playwright Patterns

## Tool Reference

| Tool | Purpose |
|------|---------|
| `mcp__plugin_playwright_playwright__browser_navigate` | Load a URL |
| `mcp__plugin_playwright_playwright__browser_take_screenshot` | Screenshot the page |
| `mcp__plugin_playwright_playwright__browser_snapshot` | Get accessibility tree (for analysis) |
| `mcp__plugin_playwright_playwright__browser_click` | Click an element |
| `mcp__plugin_playwright_playwright__browser_fill` | Fill an input |
| `mcp__plugin_playwright_playwright__browser_evaluate` | Run JavaScript |
| `mcp__plugin_playwright_playwright__browser_wait_for` | Wait for element/condition |
| `mcp__plugin_playwright_playwright__browser_console_messages` | Read console logs |
| `mcp__plugin_playwright_playwright__browser_network_requests` | See network traffic |

## Visual QA Pattern

```
1. Navigate to the page URL
2. Take screenshot at scroll 0
3. Scroll to 50%, take screenshot
4. Scroll to 100%, take screenshot
5. Review all screenshots for: layout issues, broken images, text overflow
```

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3001" })
mcp__plugin_playwright_playwright__browser_take_screenshot({ filename: "top.png" })
mcp__plugin_playwright_playwright__browser_evaluate({ script: "window.scrollTo(0, document.body.scrollHeight / 2)" })
mcp__plugin_playwright_playwright__browser_take_screenshot({ filename: "mid.png" })
mcp__plugin_playwright_playwright__browser_evaluate({ script: "window.scrollTo(0, document.body.scrollHeight)" })
mcp__plugin_playwright_playwright__browser_take_screenshot({ filename: "bottom.png" })
```

## Mobile Viewport QA

```
mcp__plugin_playwright_playwright__browser_resize({
  width: 390,
  height: 844  // iPhone 14 Pro
})
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3001" })
mcp__plugin_playwright_playwright__browser_take_screenshot({ filename: "mobile.png" })
```

## Form Testing Pattern

```
1. Navigate to form page
2. Fill in each field
3. Submit
4. Verify success state / error messages
```

```
mcp__plugin_playwright_playwright__browser_fill({
  selector: "[name='email']",
  value: "test@example.com"
})
mcp__plugin_playwright_playwright__browser_fill({
  selector: "[name='message']",
  value: "Test message content"
})
mcp__plugin_playwright_playwright__browser_click({
  selector: "[type='submit']"
})
mcp__plugin_playwright_playwright__browser_wait_for({
  selector: ".success-message",
  timeout: 5000
})
mcp__plugin_playwright_playwright__browser_take_screenshot({ filename: "form-success.png" })
```

## Checking for Console Errors

After navigating to a page, check for JS errors:

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3001" })
mcp__plugin_playwright_playwright__browser_console_messages()
→ Look for: Error, Warning, Uncaught exceptions, Failed to fetch
```

Common errors to look for:
- `Hydration failed` — server/client render mismatch
- `Cannot read properties of undefined` — null check missing
- `Failed to fetch` — API call failing
- `Warning: Each child in a list should have a unique "key"` — missing key props

## Checking Network Requests

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3001" })
mcp__plugin_playwright_playwright__browser_network_requests()
→ Look for: 404s, 500s, slow requests, missing images
```

## Accessibility Snapshot

For checking aria labels, roles, and structure:

```
mcp__plugin_playwright_playwright__browser_snapshot()
→ Returns accessibility tree with roles, labels, and states
```

Use to verify:
- Buttons have accessible labels
- Images have alt text
- Form inputs are labeled
- Headings are hierarchical (h1 → h2 → h3)

## Automation: Lighthouse Audit

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3001" })
mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit({
  categories: ["performance", "accessibility", "best-practices", "seo"],
  strategy: "mobile"
})
→ Returns Lighthouse scores and specific recommendations
```

## When to Use Playwright MCP vs record.js

**Use Playwright MCP when:**
- Testing form submissions
- Checking for JS console errors
- Verifying specific UI states after interaction
- Automated accessibility checks

**Use `record.js` when:**
- Reviewing scroll animations, parallax, and transitions
- General visual review of a whole page
- Checking hover states and motion effects
- Getting a video artifact to review async

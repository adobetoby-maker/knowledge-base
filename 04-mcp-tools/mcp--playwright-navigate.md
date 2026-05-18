# MCP Tool: playwright / browser_navigate

**Plugin:** `plugin:playwright:playwright`
**Tool name:** `mcp__plugin_playwright_playwright__browser_navigate`
**What it does:** Navigates the browser to a URL. Waits for page load before returning.

## Parameters
```json
{
  "url": "string (required) — full URL including protocol"
}
```

## Usage
```javascript
// Local dev server
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3000" })

// Specific route
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3000/dashboard" })

// With port
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3007/services/oil-change" })
```

## Typical QA Sequence
```javascript
// 1. Navigate
browser_navigate({ url: "http://localhost:3000" })

// 2. Wait for key content
browser_wait_for({ selector: "[data-testid='hero']", timeout: 5000 })

// 3. Screenshot
browser_take_screenshot({})

// 4. Check for console errors
browser_console_messages({})

// 5. Check network
browser_network_requests({})
```

## After Navigation
After `browser_navigate` returns, the page DOM is available. Use:
- `browser_snapshot({})` — get full accessibility tree (for reading page content without screenshot)
- `browser_take_screenshot({})` — visual verification
- `browser_evaluate({ script: "..." })` — run JS in page context
- `browser_click({ selector: "..." })` — interact with elements

## Failures
- **Timeout**: Page didn't load in time. Check dev server is running.
- **ERR_CONNECTION_REFUSED**: No server on that port. Start the dev server first.
- **Navigate to about:blank**: Use full URL with `http://` prefix.

## Dev Server Status Check
```bash
# Before navigating, verify dev server is running
lsof -ti :3000  # returns PID if something is listening, empty if not
```

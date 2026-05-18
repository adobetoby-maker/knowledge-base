# Plugin: playwright@claude-plugins-official

**What it provides:** Real browser automation — navigate, click, fill forms, take screenshots, run tests.
**When to reach for it:** Visual QA, end-to-end testing, scraping JavaScript-heavy sites, verifying UI after deploy.

## Key Skills
- `playwright-skill` — core Playwright patterns and test writing
- `e2e-testing-patterns` — end-to-end test design
- `browser-automation` — general browser automation guidance
- `qa` (gstack) — full QA run against a staging URL

## Key MCP Tools

```javascript
// Load schemas
ToolSearch("playwright browser navigate")

// Navigate to a page
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3000" })

// Take a screenshot
mcp__plugin_playwright_playwright__browser_take_screenshot({})

// Click an element
mcp__plugin_playwright_playwright__browser_click({ selector: "button[type='submit']" })

// Fill a form
mcp__plugin_playwright_playwright__browser_fill_form({ fields: { "#email": "test@example.com", "#password": "password123" } })

// Get page snapshot (accessibility tree)
mcp__plugin_playwright_playwright__browser_snapshot({})

// Wait for element
mcp__plugin_playwright_playwright__browser_wait_for({ selector: ".success-message" })

// Get console errors
mcp__plugin_playwright_playwright__browser_console_messages({})

// Navigate back
mcp__plugin_playwright_playwright__browser_navigate_back({})
```

## Visual QA Workflow
```
1. Start dev server locally
2. browser_navigate to the page
3. browser_take_screenshot → inspect visually
4. browser_snapshot → get element tree for assertions
5. browser_click through key flows
6. browser_console_messages → check for JS errors
7. browser_take_screenshot → final state
```

## vs Chrome DevTools MCP
Both can automate a browser. Key differences:
- **Playwright** — headless by default, better for testing, consistent across runs
- **Chrome DevTools MCP** — connects to YOUR running Chrome, sees your real session state, better for inspecting live sites

## vs Screenshot Tool (screenshot.js)
- `screenshot.js` — simpler, just captures scrolled positions, no interaction
- Playwright — full interaction, can click, fill, navigate

## Selector Strategy (in order of preference)
1. `[data-testid="..."]` — explicit test IDs, best
2. Role + name: `[role="button"][name="Submit"]`
3. Text content: `text=Sign In`
4. CSS selector — last resort, brittle

## Common Failure Mode
Playwright tries to interact before page is ready.
Fix: always `browser_wait_for` before clicking on dynamic elements.

# MCP: Browser Automation — Playwright and Chrome DevTools

## Available Tools

Two browser automation MCPs are available:

**Playwright MCP** (`mcp__plugin_playwright_*`): Full browser automation — navigation, interaction, screenshots, network inspection.

**Chrome DevTools MCP** (`mcp__plugin_chrome-devtools-mcp_chrome-devtools__*`): Real Chrome instance — similar capabilities but uses DevTools Protocol directly.

Use Playwright for: automated testing, scraping, interaction flows.
Use Chrome DevTools for: performance profiling, memory analysis, Lighthouse audits.

## Playwright Core Workflow

```
browser_navigate("https://jrsautorepair.worker-bee.app")
browser_snapshot()         → ARIA tree of page (DOM structure, roles, text)
browser_take_screenshot()  → visual screenshot
```

Always take a snapshot first — it gives you the element structure needed for reliable interactions.

## Element Interaction

```
browser_click(selector)
browser_fill(selector, value)
browser_type(selector, text)
browser_select_option(selector, value)
browser_hover(selector)
browser_press_key("Enter")
browser_press_key("Tab")
```

Selector priority (most to least reliable):
1. Accessible name: `[aria-label="Submit"]`
2. Role: `[role="button"][name="Submit"]`
3. Test ID: `[data-testid="submit-btn"]`
4. CSS: `.submit-button` (fragile, avoid)

## Form Testing Pattern

```
browser_navigate("https://jrsautorepair.worker-bee.app/contact")
browser_snapshot()  → verify form is present

browser_fill("[name='name']", "Test User")
browser_fill("[name='email']", "test@example.com")
browser_fill("[name='message']", "Test message for QA")
browser_click("[type='submit']")

browser_wait_for("[role='alert']", { state: "visible" })
browser_snapshot()  → verify success message appeared
```

## Network Inspection

```
browser_navigate(url)
browser_network_requests()  → all network calls made during navigation
```

Look for:
- Failed requests (status 4xx, 5xx)
- Missing API calls (feature not triggering its API)
- CORS errors (request blocked, not even reaching server)

## Console Log Capture

```
browser_navigate(url)
browser_console_messages()
```

Returns all console output including errors. Check after any interaction that should trigger JavaScript.

## Lighthouse Audit

Via Chrome DevTools MCP:
```
mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page(url)
mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit({
  categories: ['performance', 'accessibility', 'seo']
})
```

Returns scores and diagnostics for each category. Compare against baselines:
- Performance: target 90+ for production pages
- Accessibility: target 100 (anything less = real user barrier)
- SEO: target 100 (any missing meta, schema issues show here)

## Screenshot for UI Review

```
browser_navigate("http://localhost:3333")
browser_take_screenshot()
```

Or use the local screenshot script for multiple scroll positions:
```bash
node ~/screenshot.js 3007 0,540,810
```

For animated/motion content, use the video recorder:
```bash
node ~/record.js 3007
```

Screenshots freeze mid-animation. Never use screenshots to review scroll animations, transitions, or Framer Motion sequences.

## Mobile Viewport Testing

```
browser_resize(390, 844)    # iPhone 14 Pro
browser_navigate(url)
browser_take_screenshot()

# Or with Chrome DevTools:
mcp__plugin_chrome-devtools-mcp_chrome-devtools__emulate({ device: "iPhone 14 Pro" })
```

## Testing Auth Flows

```
# Navigate to protected route
browser_navigate("https://jrsautorepair.worker-bee.app/portal/dashboard")
# If redirects to login:
browser_snapshot()  → verify login page
browser_fill("[name='email']", "test@example.com")
browser_fill("[name='password']", "testpassword")
browser_click("[type='submit']")
browser_wait_for({ url: "**/portal/dashboard" })
browser_snapshot()  → verify dashboard loaded
```

## When Browser Automation is NOT the Right Tool

Do NOT use browser automation for:
- Reading the codebase (use Read/Grep tools)
- Checking API responses (use Bash with curl)
- Database inspection (use Supabase MCP)

Browser automation is expensive (slow, uses significant resources). Use it only for: visual verification, interaction testing, and UI-dependent debugging.

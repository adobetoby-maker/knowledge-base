# Plugin: chrome-devtools-mcp@claude-plugins-official

**What it provides:** Live control of YOUR running Chrome browser — inspect, click, screenshot, audit, profile.
**When to reach for it:** Debugging a live site you're already looking at, Lighthouse audits, performance profiling, inspecting network requests.

## Key Skills
- `chrome-devtools-mcp:chrome-devtools` — general guidance
- `chrome-devtools-mcp:chrome-devtools-cli` — CLI-style operations
- `chrome-devtools-mcp:debug-optimize-lcp` — LCP performance debugging
- `chrome-devtools-mcp:memory-leak-debugging` — find memory leaks
- `chrome-devtools-mcp:a11y-debugging` — accessibility issues
- `chrome-devtools-mcp:troubleshooting` — general debugging

## Key MCP Tools

```javascript
// List open pages
mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_pages({})

// Select a page to work with
mcp__plugin_chrome-devtools-mcp_chrome-devtools__select_page({ pageId: "..." })

// Take screenshot
mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot({})

// Navigate
mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page({ url: "http://localhost:3000" })

// Run Lighthouse audit
mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit({ categories: ["performance", "accessibility", "seo"] })

// Get console messages
mcp__plugin_chrome-devtools-mcp_chrome-devtools__get_console_message({ level: "error" })

// Get network requests
mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_network_requests({})

// Evaluate JS
mcp__plugin_chrome-devtools-mcp_chrome-devtools__evaluate_script({ script: "document.title" })

// Performance trace
mcp__plugin_chrome-devtools-mcp_chrome-devtools__performance_start_trace({})
// ... do things ...
mcp__plugin_chrome-devtools-mcp_chrome-devtools__performance_stop_trace({})
mcp__plugin_chrome-devtools-mcp_chrome-devtools__performance_analyze_insight({})
```

## vs Playwright
- **Chrome DevTools** — connects to YOUR Chrome, sees your login state, real data, live site
- **Playwright** — headless, clean state, better for reproducible automated tests

Use Chrome DevTools when: you're already looking at the page, it requires auth, you need real production data.
Use Playwright when: you need reproducible tests, clean state, or CI.

## Lighthouse Audit Workflow
```
1. navigate_page to the URL you want to audit
2. lighthouse_audit({ categories: ["performance", "seo", "accessibility", "best-practices"] })
3. Result includes score 0-100 for each + specific failing checks
4. Fix the top 3 issues, re-audit
```

## Performance Debug Workflow
```
1. performance_start_trace
2. navigate_page to the page with the performance issue
3. performance_stop_trace
4. performance_analyze_insight → identifies bottlenecks
```

## Network Debug Workflow
```
1. navigate_page to the failing page
2. list_network_requests → find 404s, slow requests, failed API calls
3. get_network_request({ requestId: "..." }) → full request/response details
```

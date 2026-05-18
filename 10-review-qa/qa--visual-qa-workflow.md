# Visual QA Workflow

**When:** After any UI change, before shipping to production.
**Rule:** Visual QA is always a screenshot + look, not "the code looks right."

## Three-Tool Visual QA Stack

### Tool 1: screenshot.js (fastest, bulk)
Best for: checking multiple scroll depths at once, comparing before/after
```bash
# 1. Ensure dev server is running
cd /Users/drive/<project> && npx next dev -H 0.0.0.0 -p 3007

# 2. Capture three scroll positions
node ~/screenshot.js 3007 0,540,1080

# 3. Review in /tmp/preview/
open /tmp/preview/

# 4. Check mobile width (edit screenshot.js or use a second call with viewport flag)
```

### Tool 2: Chrome DevTools MCP (interactive, precise)
Best for: clicking through flows, checking network requests, Lighthouse scores
```javascript
// Navigate and screenshot
mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page({ url: "http://localhost:3007" })
mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot({})

// Check for console errors
mcp__plugin_chrome-devtools-mcp_chrome-devtools__get_console_message({ level: "error" })

// Check network (look for 404s, slow requests)
mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_network_requests({})

// Run Lighthouse
mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit({
  categories: ["performance", "accessibility", "seo", "best-practices"]
})
```

### Tool 3: Playwright (automated, reproducible)
Best for: full user flow testing, mobile simulation
```javascript
// Desktop
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3007" })
mcp__plugin_playwright_playwright__browser_take_screenshot({})

// Mobile (375px)
mcp__plugin_playwright_playwright__browser_resize({ width: 375, height: 812 })
mcp__plugin_playwright_playwright__browser_navigate({ url: "http://localhost:3007" })
mcp__plugin_playwright_playwright__browser_take_screenshot({})

// Tablet (768px)
mcp__plugin_playwright_playwright__browser_resize({ width: 768, height: 1024 })
mcp__plugin_playwright_playwright__browser_take_screenshot({})
```

## The Visual QA Checklist

**Above the fold (first view):**
- [ ] Hero content visible immediately (no large loading spinner)
- [ ] Navigation is correct and functional
- [ ] CTA is visible and properly styled
- [ ] No horizontal scroll on mobile

**Typography:**
- [ ] Heading hierarchy is clear (H1 > H2 > H3)
- [ ] Body text is readable (min 16px on mobile)
- [ ] No text overflow or truncation that hides content
- [ ] Contrast ratio meets WCAG AA (4.5:1 minimum for body text)

**Spacing:**
- [ ] Consistent padding/margin — nothing looks cramped or floating
- [ ] Sections have enough vertical breathing room

**Images:**
- [ ] All images load (no broken image icons)
- [ ] Images fit their containers
- [ ] Alt text exists for content images

**Interactive:**
- [ ] Buttons respond to hover/active states
- [ ] Forms have visible labels and validation states
- [ ] Links work

**Performance signal:**
- [ ] Lighthouse Performance score > 80 for new pages
- [ ] LCP element loads quickly (no long spinner before hero)

## Sending Screenshots via iMessage
After a QA pass, can send results to phone:
```javascript
mcp__plugin_playwright_playwright__browser_take_screenshot({})  // returns path
mcp__plugin_imessage_imessage__reply({
  chat_id: "...",
  message_id: "...",
  text: "QA complete. Mobile looks good:",
  files: ["/tmp/screenshot.png"]
})
```

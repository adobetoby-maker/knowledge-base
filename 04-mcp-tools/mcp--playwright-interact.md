# MCP Tool: playwright / browser interactions

**Plugin:** `plugin:playwright:playwright`
**Tools:** click, fill, type, select_option, hover, press_key, browser_snapshot
**What they do:** Interact with a page like a real user — click buttons, fill forms, check state.

## Clicking Elements
```javascript
// Click by CSS selector
mcp__plugin_playwright_playwright__browser_click({ selector: "button[type='submit']" })
mcp__plugin_playwright_playwright__browser_click({ selector: ".cta-button" })
mcp__plugin_playwright_playwright__browser_click({ selector: "#login-btn" })

// Click by text content
mcp__plugin_playwright_playwright__browser_click({ selector: "text=Book Appointment" })

// Click by test ID
mcp__plugin_playwright_playwright__browser_click({ selector: "[data-testid='nav-menu']" })
```

## Filling Forms
```javascript
// Fill a single input
mcp__plugin_playwright_playwright__browser_fill({
  selector: "input[name='email']",
  value: "test@example.com"
})

// Fill a form (multiple fields at once)
mcp__plugin_playwright_playwright__browser_fill_form({
  fields: {
    "input[name='email']": "user@example.com",
    "input[name='password']": "password123",
    "textarea[name='message']": "Hello, I need an oil change"
  }
})
```

## Getting Page State (without screenshot)
```javascript
// snapshot returns accessibility tree — all text and interactive elements
// Faster than screenshot for reading page content
const snapshot = mcp__plugin_playwright_playwright__browser_snapshot({})
// Returns: structured tree of all visible elements with their text and roles
```

## Key Presses
```javascript
mcp__plugin_playwright_playwright__browser_press_key({ key: "Enter" })
mcp__plugin_playwright_playwright__browser_press_key({ key: "Tab" })
mcp__plugin_playwright_playwright__browser_press_key({ key: "Escape" })
```

## Select Dropdown
```javascript
mcp__plugin_playwright_playwright__browser_select_option({
  selector: "select[name='service']",
  value: "oil-change"
})
```

## Wait for Element
```javascript
// Wait for element to appear (after navigation or loading)
mcp__plugin_playwright_playwright__browser_wait_for({
  selector: "[data-testid='success-message']",
  timeout: 5000  // ms
})

// Wait for navigation to complete
mcp__plugin_playwright_playwright__browser_wait_for({
  url: "http://localhost:3000/confirmation",
  timeout: 10000
})
```

## Full Flow Testing Pattern
```javascript
// 1. Navigate
browser_navigate({ url: "http://localhost:3000/book" })

// 2. Wait for form to load
browser_wait_for({ selector: "form[data-testid='booking-form']" })

// 3. Fill form
browser_fill_form({
  fields: {
    "input[name='name']": "John Smith",
    "input[name='phone']": "208-555-0100",
    "select[name='service']": "oil-change"
  }
})

// 4. Submit
browser_click({ selector: "button[type='submit']" })

// 5. Verify success
browser_wait_for({ selector: "text=Appointment confirmed", timeout: 5000 })

// 6. Screenshot to confirm
browser_take_screenshot({})
```

## Console Errors Check
Always check for JS errors after interactions:
```javascript
mcp__plugin_playwright_playwright__browser_console_messages({})
// Returns: array of { type, text } — look for type === 'error'
```

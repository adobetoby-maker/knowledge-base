# MCP: Playwright Testing (MCP Tools)

## Overview
The Playwright MCP tools let you interact with a real browser from within a session—navigating, clicking, filling forms, taking screenshots, and evaluating JavaScript. The primary use case is validating UI changes immediately after code edits, without switching to a separate terminal or browser window. The secondary use case is debugging layout issues that screenshots alone can't diagnose, by inspecting the live DOM via `evaluate`.

## Core Tools

| Tool | Purpose |
|---|---|
| `browser_navigate` | Load a URL |
| `browser_snapshot` | Get accessibility tree (structure without screenshot) |
| `browser_take_screenshot` | Capture visual state |
| `browser_click` | Click an element |
| `browser_fill` | Type into an input |
| `browser_fill_form` | Fill multiple fields at once |
| `browser_evaluate` | Run JavaScript in page context |
| `browser_wait_for` | Wait for selector or network idle |

## Workflow: Validate UI After Code Change

```
1. browser_navigate(url: "http://localhost:3000/dashboard")

2. browser_take_screenshot()
   → visually verify the page loaded correctly

3. browser_snapshot()
   → get accessibility tree to find element selectors

4. browser_click(selector: "button[aria-label='Add user']")

5. browser_wait_for(selector: "[role='dialog']", state: "visible")

6. browser_take_screenshot()
   → verify modal appeared correctly
```

## Workflow: Debug a Form Submission
```
1. browser_navigate(url: "http://localhost:3000/checkout")

2. browser_fill_form(fields: {
     "input[name='email']": "test@example.com",
     "input[name='card']": "4242424242424242",
     "input[name='expiry']": "12/27",
     "input[name='cvc']": "123"
   })

3. browser_click(selector: "button[type='submit']")

4. browser_wait_for(selector: ".success-message", timeout: 5000)

5. browser_evaluate(expression: "document.querySelector('.order-id')?.textContent")
   → verify order ID was generated
```

## Workflow: Inspect Layout Issues
```
1. browser_navigate(url: "http://localhost:3000/pricing")

2. browser_evaluate(expression: `
     const card = document.querySelector('.pricing-card');
     const rect = card.getBoundingClientRect();
     return {
       width: rect.width,
       height: rect.height,
       top: rect.top,
       visible: rect.width > 0 && rect.height > 0
     };
   `)
   → diagnose overflow, zero-height, or off-screen elements

3. browser_evaluate(expression: `
     const el = document.querySelector('.pricing-card');
     return window.getComputedStyle(el).display;
   `)
   → verify display property when visual inspection is ambiguous
```

## Workflow: Take Screenshots at Multiple Scroll Positions
```
1. browser_navigate(url: "http://localhost:3007")

2. browser_take_screenshot()   // top of page

3. browser_evaluate(expression: "window.scrollTo(0, 540)")
   browser_take_screenshot()   // middle of page

4. browser_evaluate(expression: "window.scrollTo(0, 1080)")
   browser_take_screenshot()   // bottom section
```

## Testing Authentication Flows
```
1. browser_navigate(url: "http://localhost:3000/login")
2. browser_fill(selector: "input[name='email']", value: "admin@example.com")
3. browser_fill(selector: "input[name='password']", value: "test-password")
4. browser_click(selector: "button[type='submit']")
5. browser_wait_for(url: "http://localhost:3000/dashboard")
6. browser_take_screenshot()   // verify redirect to dashboard
```

## Key Rules
- **`browser_snapshot` before `browser_click`** — the snapshot reveals the actual selector structure; don't guess selectors.
- **`browser_wait_for` after navigation or actions** — don't screenshot immediately after click; wait for the expected state.
- **`browser_evaluate` for computed layout** — screenshots show what things look like; evaluate reveals why (computed styles, dimensions, DOM state).
- **Use `localhost`, not production** — testing code changes against localhost prevents accidental production data mutations.
- **`browser_fill_form` over multiple `browser_fill` calls** — fills multiple fields atomically, reducing tool call count.
- **Always screenshot before and after** — establishes a baseline and confirms the change had the expected visual effect.

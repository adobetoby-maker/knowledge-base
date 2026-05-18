# MCP: Filesystem Patterns (Read / Write / Edit / Glob / Grep)

## Overview
The file system tools form a hierarchy of specificity: Glob for discovery, Grep for symbol search, Read for full file content, Edit for targeted changes, Write for new files. Choosing the wrong tool costs tokens and time—using Read when Grep suffices, or Write when Edit would show a clean diff. The invariant is: always Read before Write for existing files; never Write to create a file when Edit on an existing file would accomplish the same goal.

## Tool Selection Guide

| Tool | When to Use | When NOT to Use |
|---|---|---|
| Glob | Discover files matching a pattern | When you already know the exact path |
| Grep | Find where a symbol, pattern, or string lives | When you need the full file context |
| Read | Get full content of a known file | Searching for a pattern across files |
| Edit | Change specific text in an existing file | Creating a new file from scratch |
| Write | Create a new file / full rewrite | Changing part of an existing file |

## Glob — Discovery by Pattern
```
// Find all TypeScript route handlers
glob("**/*.ts", { cwd: "/Users/drive/jrs-auto-repair/app/api" })

// Find files containing "supabase" in their name
glob("**/supabase*.ts", { cwd: "/Users/drive/jrs-auto-repair" })

// Find all test files
glob("**/*.test.{ts,tsx}", { cwd: "/Users/drive/jrs-auto-repair" })

// Find config files at project root
glob("{*.json,*.config.{ts,js},*.env*}", { cwd: "/Users/drive/jrs-auto-repair" })
```

## Grep — Symbol and Pattern Search
```
// Find where a function is defined
grep("export function calculateInvoiceTotal", "/Users/drive/jrs-auto-repair")

// Find all imports of a module
grep("from '@/lib/adminAuth'", "/Users/drive/jrs-auto-repair")

// Find all uses of an env var
grep("process.env.ADMIN_SECRET", "/Users/drive/jrs-auto-repair")

// Find all Supabase client imports (diagnose wrong client usage)
grep("from '@/lib/supabase/", "/Users/drive/jrs-auto-repair/app")

// Case-insensitive search
grep("todo|fixme|hack", "/Users/drive/jrs-auto-repair", { caseInsensitive: true })
```

## Read — Full File Context
```
// Read a specific file (always use absolute path)
read("/Users/drive/jrs-auto-repair/lib/adminAuth.ts")

// Read a portion of a large file (offset = line number, limit = number of lines)
read("/Users/drive/jrs-auto-repair/lib/articles.ts", { offset: 1, limit: 50 })

// Read before Edit — required to understand surrounding context
read("/Users/drive/jrs-auto-repair/lib/shopInfo.ts")
// → then edit with confidence about what's there
```

## Edit — Targeted Change to Existing File
```
// Change a specific string (must be unique in file)
edit("/Users/drive/jrs-auto-repair/lib/shopInfo.ts"):
  old_string: 'phone: "(208) 555-0100"'
  new_string: 'phone: "(208) 595-2101"'

// Change a function signature (include enough context to be unique)
edit("/Users/drive/jrs-auto-repair/app/api/chat/route.ts"):
  old_string: |
    export async function POST(request: Request) {
      const { message } = await request.json();
  new_string: |
    export async function POST(request: Request) {
      const { message, sessionId } = await request.json();
```

## Write — New Files Only
```
// Only use Write for files that don't exist yet
// Always verify the file doesn't exist first
glob("**/lib/analytics.ts", { cwd: "/Users/drive/jrs-auto-repair" })
// → if empty result → safe to Write
// → if found → use Edit instead

write("/Users/drive/jrs-auto-repair/lib/analytics.ts"):
  content: "..."
```

## Workflow: Finding and Fixing a Bug
```
1. Grep for the error message or function name
   grep("calculateTotal", "/Users/drive/jrs-auto-repair/lib")

2. Read the file(s) returned
   read("/Users/drive/jrs-auto-repair/lib/invoices/calculate.ts")

3. Edit the specific bug location
   edit — target the exact incorrect lines with enough context for uniqueness

4. Grep again to confirm no other callsites need updating
   grep("calculateTotal(", "/Users/drive/jrs-auto-repair")
```

## Key Rules
- **Read before Write** — Write without reading overwrites unknown content; always establish current state.
- **Edit over Write for existing files** — Edit sends only the diff; Write sends the entire file even for a one-line change.
- **Absolute paths always** — relative paths fail when the working directory changes between calls.
- **Grep before Read for large codebases** — reading 200 files to find one function is expensive; Grep narrows it to 1-3 files.
- **Glob with specific patterns** — `**/*` in a large project can return thousands of files; use file extension and directory filtering.
- **`old_string` must be unique** — if Edit's `old_string` matches multiple locations, the edit fails or makes unintended changes; add more surrounding context.

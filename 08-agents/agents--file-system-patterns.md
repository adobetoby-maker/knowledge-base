# Agent: File System Patterns

## Reading Before Writing

Always read a file before writing to it. This is both a tool requirement (Write throws if the file hasn't been read) and good practice (confirms the current state before modifying).

```
Read: /Users/drive/jrs-auto-repair/lib/articles.ts
→ understand current structure, last article format, array conventions

Then: Edit or Write with full awareness of context
```

For large files (> 500 lines), read the relevant section:
- For array files: read the last 30 lines to understand the latest entry format
- For config files: read the full file (usually short)
- For long source files: read the function you're modifying + its neighbors

## Appending to TypeScript Arrays

The pattern for adding items to existing TypeScript exports:

```typescript
// Current file ends with:
  {
    slug: 'last-article',
    title: 'Last Article',
    // ...
    body: `...content...`,
  },
]

// Append before the closing bracket:
// Find the last `},` before `]` and add after it:
  {
    slug: 'new-article',
    title: 'New Article',
    // ...
  },
]
```

Use Edit (not Write) for this — Edit sends only the diff. Write resends the entire file, which is wasteful for a large articles.ts.

## Finding Files

Don't assume file paths — verify:

```bash
# Find a file you're not sure about:
find /Users/drive/jrs-auto-repair/src -name "*.ts" | grep auth
find /Users/drive -name "articles.ts" -not -path "*/node_modules/*"

# Confirm directory structure before working in it:
ls /Users/drive/jrs-auto-repair/lib/
```

## Creating New Files

Before creating a file, check if it exists and if there's a similar file to use as a template:

```bash
# Check if file exists:
ls /Users/drive/jrs-auto-repair/lib/articles.ts

# Find similar files for template reference:
ls /Users/drive/jrs-auto-repair/lib/
# → articles.ts, howtos.ts, services.ts, shopInfo.ts
# Template: match the export pattern of the most similar file
```

## Path Conventions

All paths in tool calls should be absolute. Never use relative paths:

```
CORRECT: /Users/drive/jrs-auto-repair/lib/articles.ts
WRONG: ./lib/articles.ts
WRONG: ~/jrs-auto-repair/lib/articles.ts (~ not expanded in tools)
```

## Handling Large Files

For files > 2000 lines:
1. Read a section at a time using `offset` and `limit` parameters
2. Use Bash + grep to find the specific section first
3. Read only the lines you need to modify

```bash
# Find line number of a specific slug:
grep -n 'slug.*brake-service' /Users/drive/jrs-auto-repair/lib/articles.ts
# → 234: slug: 'brake-service-twin-falls',

# Then read just that section:
Read(file, offset=230, limit=30)
```

## Progress Files for Long Operations

When processing many files, write progress to avoid re-doing work on failure:

```typescript
const PROGRESS_FILE = '/tmp/article-generation-progress.json'

interface Progress {
  completed: string[]  // slugs that are done
  failed: Array<{ slug: string; error: string }>
  startedAt: string
}

async function loadProgress(): Promise<Progress> {
  try {
    return JSON.parse(await fs.readFile(PROGRESS_FILE, 'utf8'))
  } catch {
    return { completed: [], failed: [], startedAt: new Date().toISOString() }
  }
}

async function saveProgress(p: Progress): Promise<void> {
  await fs.writeFile(PROGRESS_FILE, JSON.stringify(p, null, 2))
}
```

This pattern enables resuming a batch job at the exact point it left off.

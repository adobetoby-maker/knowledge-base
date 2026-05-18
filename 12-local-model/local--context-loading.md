# Local Model Context Loading

## Why Context Loading Matters More for Local Models

Cloud models have large context windows (200k+ tokens). Local models are smaller and have shorter effective contexts. On an 8B or 13B model, quality degrades significantly past 8,000–16,000 tokens. Loading the right context — not all context — is critical.

## Selective Context Loading

Instead of dumping the entire codebase, load only what's relevant:

```typescript
// local-agent/context-loader.ts
interface ContextPiece {
  source: string
  content: string
  tokens: number
}

function loadContextForTask(task: string, projectPath: string): ContextPiece[] {
  const pieces: ContextPiece[] = []
  
  // Always include: project CLAUDE.md
  const claudeMd = readFile(`${projectPath}/CLAUDE.md`)
  if (claudeMd) pieces.push({ source: 'CLAUDE.md', content: claudeMd, tokens: estimateTokens(claudeMd) })
  
  // Task-specific: relevant files
  if (task.includes('invoice') || task.includes('billing')) {
    const files = [
      'lib/invoices/',
      'app/(portal)/invoices/',
      'app/api/admin/invoices/',
    ]
    for (const f of files) {
      const content = readDirectory(`${projectPath}/${f}`)
      if (content) pieces.push({ source: f, content, tokens: estimateTokens(content) })
    }
  }
  
  if (task.includes('auth') || task.includes('login') || task.includes('session')) {
    const files = ['lib/adminAuth.ts', 'lib/supabase/server.ts', 'middleware.ts']
    for (const f of files) {
      const content = readFile(`${projectPath}/${f}`)
      if (content) pieces.push({ source: f, content, tokens: estimateTokens(content) })
    }
  }
  
  return pieces
}
```

## Context Budget Management

Local models perform best when total context is under 4,000 tokens (input + output). The system prompt consumes tokens too.

```typescript
const TOKEN_BUDGET = 3000  // leave 1000 for output

function buildPromptWithBudget(
  taskDescription: string,
  contextPieces: ContextPiece[]
): string {
  let usedTokens = estimateTokens(taskDescription) + 500  // system prompt overhead
  const selectedPieces: ContextPiece[] = []

  // Sort by priority (CLAUDE.md first, then task-relevant files)
  for (const piece of contextPieces) {
    if (usedTokens + piece.tokens <= TOKEN_BUDGET) {
      selectedPieces.push(piece)
      usedTokens += piece.tokens
    } else {
      console.log(`Skipping ${piece.source}: would exceed budget (${piece.tokens} tokens)`)
    }
  }

  return `
${selectedPieces.map(p => `
### ${p.source}
\`\`\`
${p.content}
\`\`\`
`).join('\n')}

## Task
${taskDescription}
`
}

function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4)  // rough estimate: 4 chars per token
}
```

## Pre-Built Context Bundles

For recurring tasks, pre-build context bundles (see `13-stack-bundles/`):

```typescript
// 13-stack-bundles/bundle--jrs-auth-context.md
// Contains: adminAuth.ts, middleware.ts, both Supabase clients, all in one file
// ~1200 tokens vs loading 4 separate files

const BUNDLES = {
  'jrs-auth': '/knowledge-base/13-stack-bundles/bundle--jrs-auth-context.md',
  'jrs-invoice': '/knowledge-base/13-stack-bundles/bundle--jrs-invoice-context.md',
  'supabase-rls': '/knowledge-base/13-stack-bundles/bundle--supabase-rls-guide.md',
}
```

## Knowledge Base as Structured Context

For local models, the knowledge base files in `~/knowledge-base/` are pre-formatted to load as context:

```typescript
async function getKnowledgeForTask(task: string): Promise<string> {
  // Map task keywords to knowledge base files
  const relevantFiles: string[] = []
  
  if (task.match(/middleware|redirect|session/i)) {
    relevantFiles.push('/knowledge-base/06-failures/failure--middleware-issues.md')
  }
  if (task.match(/auth|login|session|cookie/i)) {
    relevantFiles.push('/knowledge-base/02-skills-disambig/disambig--which-auth-pattern.md')
  }
  if (task.match(/supabase|database|query/i)) {
    relevantFiles.push('/knowledge-base/02-skills-disambig/disambig--which-supabase-operation.md')
  }
  
  return relevantFiles
    .map(f => fs.readFileSync(f, 'utf-8'))
    .join('\n\n---\n\n')
}
```

## Chunked Reading for Large Files

When a file is too large to include entirely, extract the relevant section:

```typescript
function extractSection(fileContent: string, heading: string): string {
  const lines = fileContent.split('\n')
  const startLine = lines.findIndex(l => l.includes(heading))
  if (startLine === -1) return ''
  
  // Find the next heading of same or higher level
  const level = heading.match(/^#{1,6}/)?.[0].length ?? 2
  const endLine = lines.slice(startLine + 1)
    .findIndex(l => l.match(new RegExp(`^#{1,${level}} `)))
  
  const sectionLines = endLine === -1
    ? lines.slice(startLine)
    : lines.slice(startLine, startLine + 1 + endLine)
  
  return sectionLines.join('\n')
}

// Usage:
const authSection = extractSection(claudeMdContent, '## Architecture')
```

## Context Freshness

For overnight batch jobs, context loaded at the start may become stale if the batch modifies files. Reload affected context pieces between task steps:

```typescript
// After step modifies lib/invoices/calculate.ts, reload it for the next step
const freshContext = readFile(`${projectPath}/lib/invoices/calculate.ts`)
contextPieces = contextPieces.map(p => 
  p.source === 'lib/invoices/calculate.ts' 
    ? { ...p, content: freshContext }
    : p
)
```

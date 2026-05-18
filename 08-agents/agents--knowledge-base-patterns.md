# Agents: Knowledge Base Integration Patterns

## What This Solves

Agents working on large codebases or document repositories need to retrieve relevant context without loading everything into the context window. Knowledge base integration gives agents selective access to a large corpus through search, then loads only the relevant pieces.

## Pattern 1: Search-Then-Read

The agent is given a search tool and a read tool. It searches first to find relevant files, then reads only those files:

```ts
const tools = [
  {
    name: 'search_knowledge_base',
    description: 'Search the knowledge base for information relevant to a topic. Returns file paths and short excerpts.',
    input_schema: {
      type: 'object' as const,
      properties: {
        query: { type: 'string', description: 'Search query' },
        limit: { type: 'number', description: 'Max results to return', default: 5 },
      },
      required: ['query'],
    },
  },
  {
    name: 'read_knowledge_file',
    description: 'Read the full content of a knowledge base file by its path.',
    input_schema: {
      type: 'object' as const,
      properties: {
        path: { type: 'string', description: 'File path returned from search_knowledge_base' },
      },
      required: ['path'],
    },
  },
]

// Tool implementations:
async function searchKnowledgeBase(query: string, limit = 5) {
  // Use semantic search (claude-flow memory search, or vector DB)
  const results = await vectorSearch(query, limit)
  return results.map(r => ({ path: r.path, excerpt: r.content.slice(0, 200) }))
}

async function readKnowledgeFile(path: string) {
  return fs.readFileSync(path, 'utf-8')
}
```

## Pattern 2: Pre-Loaded Context Injection

For agents that always need the same subset of knowledge, inject it at session start rather than requiring search:

```ts
// Load the most-relevant knowledge files at prompt construction time
async function buildAgentPrompt(task: string): Promise<string> {
  // Determine which bundles are relevant to this task type
  const relevantBundles = await selectRelevantBundles(task)

  const contextFiles = await Promise.all(
    relevantBundles.map(path => fs.promises.readFile(path, 'utf-8'))
  )

  return `
# Context
${contextFiles.join('\n\n---\n\n')}

# Task
${task}
`
}

// Heuristic bundle selection
function selectRelevantBundles(task: string): string[] {
  const lower = task.toLowerCase()
  const bundles: string[] = ['13-stack-bundles/bundle--supabase-auth-context.md']

  if (lower.includes('invoice') || lower.includes('payment')) {
    bundles.push('13-stack-bundles/bundle--invoice-system-context.md')
  }
  if (lower.includes('deploy') || lower.includes('vercel')) {
    bundles.push('04-mcp-tools/mcp--vercel-project-management.md')
  }
  if (lower.includes('cloudflare') || lower.includes('worker')) {
    bundles.push('04-mcp-tools/mcp--cloudflare-deployment.md')
  }

  return bundles.map(b => path.join(KB_PATH, b))
}
```

## Pattern 3: Chunked RAG Pipeline

For large document sets, use vector embeddings for retrieval:

```ts
// 1. Index: run once (or on document changes)
async function indexKnowledgeBase() {
  const files = await glob('~/knowledge-base/**/*.md')

  for (const file of files) {
    const content = await fs.promises.readFile(file, 'utf-8')
    const chunks = splitIntoChunks(content, 500)  // 500-token chunks

    for (const [i, chunk] of chunks.entries()) {
      const embedding = await getEmbedding(chunk)
      await vectorDB.upsert({
        id: `${file}#${i}`,
        vector: embedding,
        metadata: { file, chunk_index: i, content: chunk },
      })
    }
  }
}

// 2. Retrieve: at query time
async function retrieveRelevant(query: string, topK = 5): Promise<string[]> {
  const queryEmbedding = await getEmbedding(query)
  const results = await vectorDB.query({ vector: queryEmbedding, topK })
  return results.map(r => r.metadata.content)
}
```

## Pattern 4: Tiered Knowledge Loading

Load knowledge at three tiers based on confidence:

```ts
async function buildContextForAgent(task: string) {
  // Tier 1: Always-included core context (small, always relevant)
  const coreContext = await readFile('memory/core-memories.md')

  // Tier 2: Task-type context (medium, loaded based on task keywords)
  const taskContext = await selectRelevantBundles(task)

  // Tier 3: On-demand (large, only loaded when agent explicitly requests via tool)
  // → available via search_knowledge_base tool, not pre-loaded

  return {
    system: `${coreContext}\n\n${taskContext.join('\n\n')}`,
    tools: [searchKnowledgeBaseTool, readKnowledgeFileTool],
  }
}
```

## Context Window Budget for Knowledge

Reserve space proportionally:
```
Total context:      200,000 tokens
Task instruction:     2,000 tokens
Core context:         5,000 tokens
Task bundles:        15,000 tokens
Tool results:        10,000 tokens
Agent output:       168,000 tokens remaining
```

If bundles + core context exceed 30% of the context window, summarize or trim less-relevant sections.

## Updating Knowledge During Agent Run

When an agent discovers new information that should persist:

```ts
// Agent tool: add to knowledge base
{
  name: 'add_to_memory',
  description: 'Store an important finding or decision for future sessions.',
  input_schema: {
    properties: {
      key: { type: 'string', description: 'Unique identifier for this memory' },
      content: { type: 'string', description: 'What to remember' },
      namespace: { type: 'string', enum: ['decisions', 'facts', 'errors', 'todo'] },
    },
    required: ['key', 'content', 'namespace'],
  },
}
```

Implementation appends to the appropriate `.md` file in the knowledge base, which gets picked up on the next session's context injection.

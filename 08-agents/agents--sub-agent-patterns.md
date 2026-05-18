# Agent: Sub-Agent Patterns

## Sub-Agent vs Inline Tool Call

A sub-agent is worth spawning when:
- The task is self-contained and won't need iteration
- The result will only be used once (no back-and-forth)
- The data collected would pollute the main context
- The task can run while other work happens

Keep in main context when:
- You'll need to ask follow-up questions based on the result
- The result will shape many subsequent steps
- The task is < 5 tool calls

## Specialist Sub-Agent

Send a sub-agent to become an expert on one thing:

```
Agent({
  description: 'Analyze JRS article structure',
  prompt: `Read lib/articles.ts in /Users/drive/jrs-auto-repair.
  
  Analyze the article structure and report:
  1. Average word count (estimate from string length)
  2. HTML tags used in body field
  3. How "Twin Falls" and "Magic Valley" appear
  4. CTA format (how phone number is presented)
  5. FAQ structure (HTML used)
  
  Return a structured analysis, not code. Under 400 words.`,
  model: 'haiku',  // cheap — just reading + analysis
})
```

## Validator Sub-Agent

Use a fresh sub-agent as an independent reviewer — it has no context of how the work was done, so it catches things the original agent would defend:

```
Agent({
  description: 'Validate generated article',
  prompt: `Read this file: /tmp/generated-article.html
  
  Check for all of these issues:
  - Does it mention "Twin Falls" at least once?
  - Does it mention "Magic Valley" at least once?
  - Does it include a phone number (208) 595-2101?
  - Does it have an FAQ section (h2 or h3 with "FAQ" or "Frequently")?
  - Is it at least 800 words? (estimate from length)
  - Are there any HTML syntax errors (unclosed tags)?
  
  Return: { passed: boolean, issues: string[] }
  Return ONLY JSON.`,
  model: 'haiku',
})
```

## Transformer Sub-Agent

For pure transformations (one format → another), sub-agents are ideal:

```
Agent({
  description: 'Convert HTML articles to TypeScript',
  prompt: `Read the HTML files in /tmp/generated-articles/.
  
  For each file:
  1. Extract content from the HTML body
  2. Generate an Article object matching this TypeScript type:
     { slug: string, title: string, excerpt: string, category: string, date: string, readTime: number, body: string }
  3. Set slug = filename without .html extension
  4. Set title = text of first <h1> tag
  5. Set excerpt = first <p> content, truncated to 160 chars
  6. Set category = 'maintenance' if no obvious category
  7. Set date = today's date (2025-09-15)
  8. Set readTime = Math.ceil(wordCount / 200)
  9. Set body = full HTML as a TypeScript template literal string
  
  Append ALL articles to /Users/drive/jrs-auto-repair/lib/articles.ts as array entries.
  Read the current file first to understand the format, then append.`,
})
```

## Concurrency and Isolation

Sub-agents run in isolation — no shared memory with parent or with each other. For parallel sub-agents that need to share data, use files:

```typescript
// Parent sets up coordination:
await writeFile('/tmp/shared-context.json', JSON.stringify({ 
  baseArticleCount: articles.length,
  targetArticleCount: articles.length + 10,
}))

// Parallel sub-agents read context, write their results to separate files:
await Promise.all([
  Agent({ prompt: `...write to /tmp/batch-1-results.json...` }),
  Agent({ prompt: `...write to /tmp/batch-2-results.json...` }),
])

// Parent reads and merges:
const results1 = JSON.parse(await readFile('/tmp/batch-1-results.json'))
const results2 = JSON.parse(await readFile('/tmp/batch-2-results.json'))
```

## Sub-Agent Failure Handling

Sub-agents can fail. Handle gracefully:

```typescript
const results = await Promise.allSettled([
  Agent({ description: 'Task 1', prompt: '...' }),
  Agent({ description: 'Task 2', prompt: '...' }),
  Agent({ description: 'Task 3', prompt: '...' }),
])

const successes = results.filter(r => r.status === 'fulfilled').map(r => r.value)
const failures = results.filter(r => r.status === 'rejected')

if (failures.length > 0) {
  console.log(`${failures.length} sub-agent(s) failed — continuing with ${successes.length} results`)
}
```

## Avoiding Sub-Agent Over-Use

Sub-agents add overhead: initialization time, context setup, potential for misunderstanding the task.

Too many agents is a code smell:
- If you're spawning agents for 2-3 tool calls each, merge them into one agent
- If results need extensive reconciliation, the tasks weren't independent
- If agents frequently fail or return wrong format, the task wasn't scoped correctly

One well-scoped agent with clear output format > five small agents with complex merge logic.

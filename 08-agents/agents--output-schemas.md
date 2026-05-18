# Agent Output Schemas

## Why Structured Output Matters

An agent that returns prose requires another agent (or human) to parse the prose. An agent that returns structured JSON can be consumed programmatically. Structured output enables agent pipelines.

## Vercel AI SDK: generateObject

The cleanest approach — the model is constrained to produce valid JSON matching a Zod schema.

```typescript
import { generateObject } from 'ai'
import { anthropic } from '@anthropic-ai/sdk'
import { z } from 'zod'

const articleSchema = z.object({
  title: z.string().describe('SEO-optimized article title, 50-60 characters'),
  slug: z.string().describe('URL-safe slug, lowercase with hyphens'),
  excerpt: z.string().describe('150-160 character meta description'),
  body: z.string().describe('Full article body in markdown, 800-1200 words'),
  category: z.enum(['maintenance', 'repair', 'seasonal', 'how-to']),
  keywords: z.array(z.string()).min(3).max(8).describe('Target SEO keywords'),
})

export async function generateArticle(topic: string) {
  const { object } = await generateObject({
    model: anthropic('claude-haiku-4-5'),
    schema: articleSchema,
    prompt: `Write an SEO article about: ${topic}
    
Context: Auto repair shop in Twin Falls, Idaho. 
Target audience: Car owners in Magic Valley.
Voice: Friendly, knowledgeable, honest. Like a trusted mechanic neighbor.`,
  })
  
  return object  // TypeScript knows this is z.infer<typeof articleSchema>
}
```

## Multi-Step Pipeline with Schemas

Each step has a defined output schema that becomes the next step's input:

```typescript
// Step 1: Research
const researchSchema = z.object({
  keywords: z.array(z.string()),
  userIntent: z.string(),
  competitorGaps: z.array(z.string()),
})

// Step 2: Outline (uses Step 1 output)
const outlineSchema = z.object({
  title: z.string(),
  sections: z.array(z.object({
    heading: z.string(),
    keyPoints: z.array(z.string()),
    wordTarget: z.number(),
  })),
})

// Step 3: Article (uses Step 2 output)
const articleSchema = z.object({
  title: z.string(),
  body: z.string(),
  metadata: z.object({ description: z.string(), keywords: z.array(z.string()) }),
})

async function generateArticlePipeline(topic: string) {
  const { object: research } = await generateObject({
    model: anthropic('claude-haiku-4-5'),
    schema: researchSchema,
    prompt: `Research SEO opportunity for "${topic}" for an auto repair shop.`,
  })
  
  const { object: outline } = await generateObject({
    model: anthropic('claude-haiku-4-5'),
    schema: outlineSchema,
    prompt: `Create article outline for "${topic}".
    Target keywords: ${research.keywords.join(', ')}
    User intent: ${research.userIntent}
    Cover these gaps vs competitors: ${research.competitorGaps.join(', ')}`,
  })
  
  const { object: article } = await generateObject({
    model: anthropic('claude-sonnet-4-6'),  // More capable model for writing
    schema: articleSchema,
    prompt: `Write the article following this outline:
    ${JSON.stringify(outline, null, 2)}`,
  })
  
  return article
}
```

## Batch Schema for Multiple Items

```typescript
const batchArticleSchema = z.object({
  articles: z.array(z.object({
    slug: z.string(),
    title: z.string(),
    excerpt: z.string(),
  })).length(5).describe('Exactly 5 article ideas'),
  rationale: z.string().describe('Why these topics were selected'),
})

const { object } = await generateObject({
  model: anthropic('claude-haiku-4-5'),
  schema: batchArticleSchema,
  prompt: 'Generate 5 article topic ideas for an auto repair shop in Twin Falls, ID.',
})

// object.articles is typed as an array of exactly 5 items
```

## Decision Schema

For agents that need to make a routing decision:

```typescript
const routingDecision = z.object({
  action: z.enum(['create_file', 'modify_file', 'needs_human', 'skip']),
  target: z.string().optional().describe('File path if action is create or modify'),
  reason: z.string(),
  priority: z.enum(['high', 'medium', 'low']),
})

const { object: decision } = await generateObject({
  model: anthropic('claude-haiku-4-5'),
  schema: routingDecision,
  prompt: `Given this task: "${task}", what action should be taken?
  Available files: ${availableFiles.join(', ')}`,
})

switch (decision.action) {
  case 'create_file': await createFile(decision.target!) ; break
  case 'modify_file': await modifyFile(decision.target!) ; break
  case 'needs_human': await writeToNeedsHuman(task, decision.reason) ; break
  case 'skip': break
}
```

## Schema Design Rules

**Use `.describe()` on fields** — description goes into the model prompt context; it's the prompt for that field.

**Use enums for controlled values** — `z.enum(['pending', 'paid'])` is better than `z.string().describe('status, either pending or paid')`.

**Specify array lengths** when you need exactly N items — `.min(3).max(5)` prevents the model from taking shortcuts.

**Nest schemas** for grouped data rather than flat strings — easier to consume in code.

**Avoid overly strict constraints** early in development — if the model can't satisfy a constraint, generateObject throws. Start loose, tighten after confirming the model can satisfy the schema.

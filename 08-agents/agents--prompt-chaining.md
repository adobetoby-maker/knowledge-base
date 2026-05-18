# Agent Pattern: Prompt Chaining

## Overview

Prompt chaining breaks a complex task into a sequence of simpler prompts where each output feeds the next. Better results than one complex prompt because each step gets focused context without distraction from unrelated instructions.

## When to Chain vs. Single Prompt

Use chaining when:
- Task has distinct sequential phases (plan → execute → review)
- Early steps determine the shape of later steps
- Context from step N is a subset of what step N+1 needs
- Different steps benefit from different instructions (write vs. verify)

Use a single prompt when:
- Task is fully contained — a single question with a structured output
- Steps don't have conditional branches
- Latency matters more than quality

## Basic Chain Structure

```ts
interface ChainStep<TInput, TOutput> {
  name: string
  prompt: (input: TInput) => string
  parse: (raw: string) => TOutput
  validate?: (output: TOutput) => boolean
}

async function runChain<T>(
  steps: ChainStep<unknown, unknown>[],
  initialInput: T,
): Promise<unknown[]> {
  const results: unknown[] = []
  let currentInput: unknown = initialInput

  for (const step of steps) {
    const prompt = step.prompt(currentInput)
    const raw = await callModel(prompt)
    const output = step.parse(raw)

    if (step.validate && !step.validate(output)) {
      throw new Error(`Chain step "${step.name}" validation failed`)
    }

    results.push(output)
    currentInput = output  // Pass to next step
  }

  return results
}
```

## Example: Blog Post Generation Chain

```ts
const BLOG_CHAIN = [
  {
    name: 'outline',
    prompt: (topic: string) => `
Create an outline for a blog post about: "${topic}"

The post should be:
- 1500-2000 words
- Targeting someone searching: "${topic} guide"
- Include: introduction, 4-6 main sections with subpoints, conclusion

Return JSON: { title, sections: [{ heading, subpoints: string[] }] }
`,
    parse: (raw: string) => JSON.parse(raw.match(/\{[\s\S]*\}/)?.[0] ?? '{}'),
  },

  {
    name: 'draft',
    prompt: (outline: BlogOutline) => `
Write a full blog post from this outline:
${JSON.stringify(outline, null, 2)}

Requirements:
- Conversational but authoritative tone
- Each section 250-300 words
- Use specific examples where applicable
- End with a clear call to action

Write the full post in markdown.
`,
    parse: (raw: string) => raw,
  },

  {
    name: 'seo-optimize',
    prompt: ({ outline, draft }: { outline: BlogOutline; draft: string }) => `
Review this blog post draft and optimize for SEO.

Target keyword: "${outline.title.toLowerCase()}"

1. Ensure keyword appears in: first paragraph, 2-3 headings, last paragraph
2. Check for: natural keyword variation, related terms
3. Verify meta description potential (the first paragraph should work as one)
4. Check internal link opportunities (suggest 3 places to add internal links)

Return the optimized draft in markdown, followed by:
---
SUGGESTIONS:
[list of 3 internal link suggestions]
`,
    parse: (raw: string) => {
      const [content, suggestions] = raw.split('\n---\n')
      return { optimizedContent: content.trim(), suggestions }
    },
  },
]
```

## Branching Chains

```ts
type ChainBranch<T> = {
  condition: (input: T) => boolean
  steps: ChainStep<unknown, unknown>[]
}

async function runBranchingChain<T>(
  input: T,
  branches: ChainBranch<T>[],
  defaultSteps: ChainStep<unknown, unknown>[],
): Promise<unknown[]> {
  const matchedBranch = branches.find((b) => b.condition(input))
  const steps = matchedBranch?.steps ?? defaultSteps
  return runChain(steps, input)
}

// Example: route based on content type
const branches = [
  {
    condition: (input: { type: string }) => input.type === 'technical',
    steps: TECHNICAL_BLOG_CHAIN,
  },
  {
    condition: (input: { type: string }) => input.type === 'local',
    steps: LOCAL_SEO_BLOG_CHAIN,
  },
]
```

## Passing Partial Context

Don't pass the full output of every step to every subsequent step. Pass only what's needed:

```ts
// BAD — step 3 gets everything from steps 1 and 2 (bloats context)
const step3Input = { step1Output, step2Output, originalInput }

// GOOD — step 3 gets only what it needs
const step3Input = {
  outline: step1Output.sections,      // Just the structure
  wordCount: step2Output.split(' ').length,  // Just the metric
  targetKeyword: originalInput.keyword,
}
```

Context bloat is the most common chain failure mode. Each extra sentence in the prompt reduces model focus on the actual task.

## Parallelizing Independent Steps

```ts
// Steps that don't depend on each other can run in parallel
const [seoAnalysis, toneAnalysis, factCheck] = await Promise.all([
  runStep(SEO_STEP, draft),
  runStep(TONE_STEP, draft),
  runStep(FACT_CHECK_STEP, draft),
])

// Merge results into final revision prompt
const revision = await runStep(REVISION_STEP, {
  draft,
  seoIssues: seoAnalysis.issues,
  toneNotes: toneAnalysis.suggestions,
  factErrors: factCheck.errors,
})
```

This is the most impactful optimization for multi-step chains — parallel review steps cut wall-clock time by the number of parallel branches.

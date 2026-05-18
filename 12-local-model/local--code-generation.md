# Local Model: Code Generation

## Overview

Use local models (via Ollama) for code generation tasks that don't require API key management: template scaffolding, boilerplate generation, migration writing, and test stub creation. Models like `codellama:13b`, `deepseek-coder:6.7b`, and `qwen2.5-coder:7b` run on consumer hardware and are sufficient for these tasks.

## Model Selection

| Task | Model | Why |
|---|---|---|
| TypeScript functions | `qwen2.5-coder:7b` | Strong TS support, fast |
| SQL migrations | `codellama:7b` | Good SQL, smaller |
| Documentation | `llama3.1:8b` | Better prose |
| Complex multi-file | `deepseek-coder:33b` | More context, slower |

```bash
# Pull models
ollama pull qwen2.5-coder:7b
ollama pull codellama:7b
```

## Prompt for Deterministic Code Generation

Temperature 0 for consistent, reproducible output:

```ts
async function generateCode(prompt: string, context?: string): Promise<string> {
  const systemPrompt = context
    ? `You are a TypeScript code generator. ${context}\nGenerate only the requested code. No explanation, no markdown fences.`
    : 'You are a TypeScript code generator. Generate only the requested code. No explanation, no markdown fences.'

  const res = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'qwen2.5-coder:7b',
      prompt: `${systemPrompt}\n\n${prompt}`,
      stream: false,
      options: {
        temperature: 0,
        num_predict: 2048,
        stop: ['```', '// END'],
      },
    }),
  })

  const data = await res.json()
  return data.response.trim()
}
```

## Scaffold Generation Example

Generate CRUD route handlers from a schema:

```ts
interface RouteScaffoldInput {
  tableName: string
  columns: { name: string; type: string; nullable: boolean }[]
  primaryKey: string
}

async function generateCrudRoutes(input: RouteScaffoldInput): Promise<string> {
  const columnList = input.columns.map(c => `${c.name}: ${c.type}${c.nullable ? ' | null' : ''}`).join('\n  ')

  const prompt = `
Generate a Next.js 14 App Router route handler file for the "${input.tableName}" table.

Table interface:
interface ${toPascalCase(input.tableName)} {
  ${input.primaryKey}: string
  ${columnList}
}

Generate:
1. GET handler - fetch by ID
2. PATCH handler - partial update  
3. DELETE handler - soft delete (set deleted_at = now())

Use Drizzle ORM. Include proper error handling (404 if not found).
Export named functions: GET, PATCH, DELETE.
`

  return generateCode(prompt, `Codebase uses Drizzle ORM with PostgreSQL. Table is "${input.tableName}".`)
}
```

## Test Stub Generation

```ts
async function generateTestStubs(
  functionName: string,
  functionCode: string
): Promise<string> {
  const prompt = `
Generate Vitest unit test stubs for this function:

\`\`\`typescript
${functionCode}
\`\`\`

Create:
- Happy path test
- Edge case: empty input
- Edge case: invalid input
- Use vi.mock() for external dependencies
- Use describe/it blocks
- Don't implement assertions — just stubs with TODO comments
`

  return generateCode(prompt)
}
```

## Migration Generation

```ts
async function generateMigration(description: string, existingSchema: string): Promise<string> {
  const prompt = `
Generate a SQL migration for this change: "${description}"

Existing relevant schema:
${existingSchema}

Requirements:
- Use IF NOT EXISTS / IF EXISTS for safety
- Include both UP and DOWN migrations (comment them: -- UP: and -- DOWN:)
- Use appropriate PostgreSQL types
- Add indexes for foreign keys
`

  const result = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'codellama:7b',
      prompt,
      stream: false,
      options: { temperature: 0 },
    }),
  })

  return (await result.json()).response
}
```

## Post-Processing Generated Code

Always validate and clean generated output:

```ts
function cleanGeneratedCode(raw: string): string {
  return raw
    .replace(/^```(?:typescript|ts|javascript|js|sql)?\n?/i, '')
    .replace(/```\s*$/i, '')
    .replace(/^(Here'?s?|This is|Below is|The following)[^:]*:\s*/i, '')
    .trim()
}

function validateTypeScriptSyntax(code: string): boolean {
  // Quick heuristic checks — full TS compilation for production validation
  const hasUnclosedBraces = (code.match(/{/g)?.length ?? 0) !== (code.match(/}/g)?.length ?? 0)
  const hasUnclosedParens = (code.match(/\(/g)?.length ?? 0) !== (code.match(/\)/g)?.length ?? 0)
  return !hasUnclosedBraces && !hasUnclosedParens
}
```

## Key Rules

- Temperature 0 for code generation — you want consistency, not creativity.
- Always post-process: strip markdown fences, remove explanation text.
- Validate generated code before using: at minimum check bracket balance; for production use TypeScript compiler.
- Few-shot examples improve accuracy: include 1-2 examples of the expected output format in the prompt.
- Local models are slower than API models — use for batch/offline generation, not real-time user requests.

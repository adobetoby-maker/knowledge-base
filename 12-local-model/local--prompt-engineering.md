# Local Model Prompt Engineering

## What Changes Between Cloud and Local Models

Cloud models (Claude, GPT-4) are fine-tuned for instruction-following and handle vague prompts gracefully. Local models (Llama, DeepSeek, Qwen) require more explicit prompting:

- More literal interpretation of instructions
- Less inference of missing context
- Formatting instructions must be explicit
- System prompts require structured role definition
- JSON output requires explicit format specification and often a few-shot example

## System Prompt Structure for Local Models

```
You are [specific role]. You [capabilities]. You [constraints].

When asked to [task type], always [specific behavior].
Output format: [exact format description].
```

Example for code generation:
```
You are a TypeScript code generator for Next.js applications. You write clean, typed code.

When asked to generate code:
- Always include TypeScript types (no 'any')
- Follow React functional component patterns
- Use async/await, not .then()
- Return ONLY the code, no explanations

Output format: Raw TypeScript code block, no markdown fences.
```

## JSON Output Extraction

Local models frequently include prose around requested JSON. Extract programmatically:

```typescript
function extractJSON(text: string): unknown | null {
  // Try to find JSON object
  const objectMatch = text.match(/\{[\s\S]*\}/)
  if (objectMatch) {
    try { return JSON.parse(objectMatch[0]) } catch {}
  }
  
  // Try to find JSON array
  const arrayMatch = text.match(/\[[\s\S]*\]/)
  if (arrayMatch) {
    try { return JSON.parse(arrayMatch[0]) } catch {}
  }
  
  return null
}
```

For more robust extraction, ask the model to wrap its JSON in a delimiter:

```
Return your answer as JSON wrapped in <result> tags:
<result>
{"key": "value"}
</result>
```

```typescript
function extractTaggedJSON(text: string, tag: string): unknown | null {
  const regex = new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`)
  const match = text.match(regex)
  if (!match) return null
  try { return JSON.parse(match[1].trim()) } catch { return null }
}

const result = extractTaggedJSON(response, 'result')
```

## Few-Shot Prompting

Local models benefit more from examples than cloud models. Show the exact format you want:

```
Generate article metadata from the article title.

Example:
INPUT: "How to Change Your Oil in 5 Easy Steps"
OUTPUT: {"slug": "how-to-change-your-oil", "readTime": 5, "category": "how-to"}

Example:
INPUT: "Signs Your Car Needs New Brakes"
OUTPUT: {"slug": "signs-car-needs-new-brakes", "readTime": 4, "category": "repair"}

Now generate for:
INPUT: "Winter Tire Storage Tips for Idaho"
OUTPUT:
```

## Shorter, More Direct Instructions

Local models do better with shorter prompts. Trim everything non-essential:

```
# BAD — verbose
Please write a comprehensive meta description for this article that is 150-160 characters 
long and includes the primary keyword naturally, while also being compelling enough to 
generate clicks from search results, and should accurately represent the article content...

# GOOD — direct
Write a 150-160 character meta description for:
Title: {title}
Include keyword: {keyword}
Output only the description.
```

## Temperature and Parameters

For structured output tasks: `temperature: 0` or very low (0.1-0.2)
For creative writing: `temperature: 0.7-0.9`
For factual Q&A: `temperature: 0.3-0.5`

```typescript
// Ollama API example
const response = await fetch('http://localhost:11434/api/generate', {
  method: 'POST',
  body: JSON.stringify({
    model: 'llama3.1:8b',
    prompt: prompt,
    options: {
      temperature: 0,        // deterministic for structured output
      num_predict: 512,      // limit output length
      stop: ['</result>'],   // stop at delimiter
    },
    stream: false,
  }),
})
```

## Model Selection by Task

| Task | Recommended model | Notes |
|------|-----------------|-------|
| JSON extraction/classification | Llama 3.1 8B | Fast, good at structured output |
| Code generation | DeepSeek Coder 6.7B | Purpose-trained for code |
| Text summarization | Qwen 2.5 7B | Strong multilingual support |
| Creative writing | Llama 3.1 70B | Better quality, slower |
| Reasoning/analysis | DeepSeek R1 7B | Chain-of-thought capable |

## Validation After Generation

Local models are less reliable than cloud models. Always validate output:

```typescript
async function generateWithRetry<T>(
  prompt: string,
  schema: z.ZodType<T>,
  maxRetries = 3
): Promise<T | null> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const raw = await callLocalModel(prompt)
    const json = extractJSON(raw)
    
    if (!json) {
      console.log(`Attempt ${attempt + 1}: No JSON found`)
      continue
    }
    
    const result = schema.safeParse(json)
    if (result.success) return result.data
    
    console.log(`Attempt ${attempt + 1}: Schema validation failed:`, result.error.flatten())
  }
  
  return null  // give up after retries
}
```

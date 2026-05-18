# Local Model: Function Calling

## Overview
Function calling with local models requires a different approach than hosted APIs because native tool use support varies significantly by model. Models like llama3.1+, Qwen2.5, and Mistral-Nemo support tool use in their chat templates. Older or smaller models do not, requiring JSON grammar sampling or few-shot prompting as fallbacks. The output always needs Zod validation before being used—local models hallucinate JSON keys, wrong types, and extra fields more often than hosted models.

## Approach 1: Native Tool Use (llama3.1+ via Ollama)

```ts
import Ollama from 'ollama';

const tools = [{
  type: 'function',
  function: {
    name: 'get_weather',
    description: 'Get current weather for a city',
    parameters: {
      type: 'object',
      properties: {
        city: { type: 'string', description: 'City name' },
        units: { type: 'string', enum: ['celsius', 'fahrenheit'] },
      },
      required: ['city'],
    },
  },
}];

const response = await ollama.chat({
  model: 'llama3.1:8b',
  messages: [{ role: 'user', content: 'What is the weather in Boise?' }],
  tools,
});

if (response.message.tool_calls?.length) {
  const call = response.message.tool_calls[0];
  const args = call.function.arguments; // already parsed object
  const result = await getWeather(args.city, args.units ?? 'celsius');

  // Send result back for final response
  const finalResponse = await ollama.chat({
    model: 'llama3.1:8b',
    messages: [
      { role: 'user', content: 'What is the weather in Boise?' },
      response.message,
      { role: 'tool', content: JSON.stringify(result) },
    ],
  });
}
```

## Approach 2: JSON Grammar Sampling (llama.cpp)

```ts
// llama.cpp server supports grammar-constrained generation
// Guarantees syntactically valid JSON even from models without native tool support

const schema = {
  type: 'object',
  properties: {
    action: { type: 'string', enum: ['search', 'lookup', 'summarize'] },
    query: { type: 'string' },
    maxResults: { type: 'number' },
  },
  required: ['action', 'query'],
};

const response = await fetch('http://localhost:8080/completion', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    prompt: `Extract the user's intent as JSON: "Find me 5 articles about TypeScript"`,
    grammar: buildGBNFFromSchema(schema), // convert JSON Schema → GBNF grammar
    temperature: 0.1,
    max_tokens: 200,
  }),
});

const { content } = await response.json();
const parsed = JSON.parse(content); // guaranteed to parse due to grammar
```

## Approach 3: Few-Shot Prompting (Models Without Tool Support)

```ts
const systemPrompt = `You are a function call extractor. When given a user request,
respond ONLY with a JSON object matching this schema. No explanation, no markdown.

Schema: { "tool": "search"|"lookup", "query": string, "limit": number }

Examples:
User: "Find articles about React hooks"
Response: {"tool":"search","query":"React hooks","limit":10}

User: "Look up the user with ID 123"
Response: {"tool":"lookup","query":"123","limit":1}`;

const response = await ollama.generate({
  model: 'mistral:7b',
  prompt: systemPrompt + '\n\nUser: "' + userInput + '"\nResponse:',
  options: { temperature: 0.05, stop: ['\n', 'User:'] },
});

// Validate output — few-shot can still produce malformed JSON
const result = safeParseToolCall(response.response);
```

## Always Validate with Zod

```ts
import { z } from 'zod';

const ToolCallSchema = z.object({
  tool: z.enum(['search', 'lookup', 'summarize']),
  query: z.string().min(1),
  limit: z.number().int().min(1).max(100).optional().default(10),
});

function safeParseToolCall(raw: string) {
  try {
    // Strip markdown code fences if model adds them
    const cleaned = raw.replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();
    const parsed = JSON.parse(cleaned);
    return ToolCallSchema.parse(parsed);
  } catch {
    return null; // caller handles null = parsing failed
  }
}
```

## Fallback Strategy

```ts
async function callWithTools(model: string, prompt: string, schema: z.ZodSchema) {
  // Try 3 times with increasing temperature
  for (const temp of [0.05, 0.1, 0.2]) {
    const raw = await generate(model, prompt, { temperature: temp });
    const result = safeParseToolCall(raw);
    if (result) return result;
  }

  // If all attempts fail, return null and log for quality monitoring
  logger.warn('Function call parsing failed after 3 attempts', { model, prompt });
  return null;
}
```

## Key Rules
- **Check model capability before choosing approach** — llama3.1+, Qwen2.5, Mistral support native tools; older models need grammar/few-shot.
- **Always validate with Zod** — local models hallucinate keys and wrong types even with grammar constraints.
- **Low temperature for structured output** — 0.05–0.2; higher temperatures produce more creative but less structured JSON.
- **Strip markdown fences** — models often wrap JSON in `\`\`\`json ... \`\`\`` even when instructed not to.
- **Grammar sampling > few-shot > prompt engineering** — in terms of reliability; invest in grammar sampling for production use.
- **Few-shot examples must be exact** — the model pattern-matches your examples; off-by-one whitespace or quoting inconsistency degrades accuracy.

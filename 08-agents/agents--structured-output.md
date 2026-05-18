# Structured Output from Agents

Getting reliable, parseable JSON from an LLM requires explicit enforcement, not hope. Models are trained on human text and will add prose explanations, trailing commas, comments, or markdown code fences unless structural guarantees are in place.

## `response_format: { type: "json_object" }`

When the API supports a `response_format` parameter, use it. This constrains the model's output to valid JSON at the decoding layer — it's not a prompt instruction that can be ignored, it's a hard constraint. This eliminates:
- Markdown fences around JSON (` ```json ... ``` `)
- Prose preamble ("Here is the JSON you requested:")
- Trailing text after the closing brace

For models that don't support `response_format`, the next best option is to end the user prompt with `Respond with valid JSON only. No preamble, no markdown, no trailing text.` and then strip everything before the first `{` and after the last `}` before parsing.

## Zod Schema Definition

Define the expected shape with Zod (TypeScript) or Pydantic (Python) before writing the prompt. Benefits:
- The schema is the single source of truth for both the prompt (describe the shape) and the parser (validate the output).
- Type inference gives the rest of the codebase typed data automatically.
- `.safeParse()` distinguishes valid-but-wrong from parse-error, enabling targeted error messages.

Put the JSON shape directly in the prompt as a TypeScript interface or JSON Schema snippet. Models that have seen these formats extensively produce outputs that match them more reliably than natural-language descriptions of the same shape.

## Retry on Parse Failure

Parse failures are expected at low rate (~1–5% in practice). Handle them:

```typescript
for (let attempt = 0; attempt < 3; attempt++) {
  const raw = await callModel(prompt);
  const result = schema.safeParse(JSON.parse(raw));
  if (result.success) return result.data;
  // On retry, include the parse error in the prompt:
  prompt = appendParseError(prompt, raw, result.error);
}
throw new Error("Structured output failed after 3 attempts");
```

On the retry pass, show the model what it produced and specifically what was wrong. "Your output was missing the `items` array required by the schema" produces a correct retry ~90% of the time. A generic "try again" does not.

## Function Calling vs. JSON Prompting

Function calling (tool use) is more reliable than JSON prompting for structured output because:
- The output routing is enforced at the API level, not inferred from text.
- Tool schemas are typed — the model has been specifically trained on producing arguments that match tool schemas.
- The response comes back in a structured envelope (`tool_use` block), not as a string requiring parse.

When the task is fundamentally "extract structured data from the model's response," model that as a tool call where the tool is `record_result(field1, field2, ...)`. The model fills in arguments; you receive typed data. This is more robust than `JSON.parse(response.text)`.

Use JSON prompting only when you can't use function calling (e.g., streaming, some provider constraints) or when the schema is dynamic enough that defining a static tool schema is impractical.

## Key Rules

- Use `response_format: { type: "json_object" }` when the API supports it — it's a hard constraint, not a hint.
- Define the schema with Zod/Pydantic first; derive the prompt description from the schema, not vice versa.
- Strip prose preamble/suffix before parsing if `response_format` isn't available.
- Retry on parse failure with the specific error message included in the retry prompt.
- Prefer function calling over JSON prompting for structured extraction — it's enforced at the API layer.
- Cap retries at 3; if it fails after 3 attempts, log and raise, don't keep retrying.

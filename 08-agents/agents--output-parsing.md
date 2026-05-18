# Agent: Output Parsing

Agent outputs are text. Extracting structured data from that text reliably requires defensive parsing strategies, because model outputs vary in format, include surrounding prose, and occasionally violate their own declared structure. Robust parsing handles the happy path and the edge cases without crashing.

## Extracting JSON from Markdown Code Blocks

Models often wrap JSON in markdown code fences, especially when instructed to produce structured output. The raw response might be:

```
Here is the analysis:

```json
{"score": 8, "issues": ["missing error handling", "no input validation"]}
```

This JSON represents the review.
```

Extract the JSON by targeting the code block, not attempting to parse the entire response:

```ts
function extractJSON(text: string): unknown {
  // Match ```json ... ``` or ``` ... ``` blocks
  const codeBlockMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (codeBlockMatch) {
    return JSON.parse(codeBlockMatch[1].trim());
  }
  // Fall back to finding a bare JSON object/array
  const jsonMatch = text.match(/(\{[\s\S]*\}|\[[\s\S]*\])/);
  if (jsonMatch) {
    return JSON.parse(jsonMatch[1]);
  }
  throw new Error('No JSON found in response');
}
```

Try the code block first — it's the most deliberate structure. The bare JSON fallback catches responses where the model skipped the fences. Both can fail; wrap in try/catch.

## Regex for Structured Patterns

When the output isn't JSON but follows a predictable pattern, use targeted regex:

```ts
// Extract confidence score: "Confidence: 0.87" or "confidence: 87%"
const confidenceMatch = text.match(/confidence[:\s]+([0-9.]+)%?/i);
const confidence = confidenceMatch
  ? parseFloat(confidenceMatch[1]) / (confidenceMatch[0].includes('%') ? 100 : 1)
  : null;

// Extract a list of items under a header
const sectionMatch = text.match(/(?:Issues?|Problems?)[:\n]+((?:[-•*]\s*.+\n?)+)/i);
const items = sectionMatch
  ? sectionMatch[1].split('\n').map(l => l.replace(/^[-•*]\s*/, '').trim()).filter(Boolean)
  : [];
```

Write regex defensively: case-insensitive, allow for whitespace variation, don't assume exact label spelling. Models paraphrase.

## Retry with Format Reminder on Parse Failure

When parsing fails, don't discard the attempt — retry with the original output and an explicit correction prompt:

```ts
async function parseWithRetry(
  generate: () => Promise<string>,
  parse: (text: string) => T,
  maxRetries = 2
): Promise<T> {
  let lastText = '';
  for (let i = 0; i <= maxRetries; i++) {
    try {
      lastText = await generate();
      return parse(lastText);
    } catch (err) {
      if (i === maxRetries) throw err;
      // Modify the generation prompt to include the failed output and a correction request
      generate = () => retryWithFormatReminder(lastText);
    }
  }
  throw new Error('unreachable');
}

function retryWithFormatReminder(failedOutput: string): Promise<string> {
  return callModel(`Your previous response could not be parsed as JSON:
---
${failedOutput}
---
Please respond ONLY with valid JSON, no prose, no code fences.`);
}
```

The format reminder includes the failed output so the model can see what it produced wrong. Without this context, a retry often produces the same malformed output.

## Partial Extraction for Large Outputs

Large outputs (multi-section reports, long lists) may have parsing failures in one section that should not prevent extraction of the rest. Use a section-by-section approach:

```ts
const sections = ['summary', 'issues', 'recommendations'];
const result: Record<string, unknown> = {};

for (const section of sections) {
  try {
    result[section] = extractSection(text, section);
  } catch {
    result[section] = null; // partial success — note the failure
    result[`${section}_error`] = 'parse failed';
  }
}
```

Partial extraction is better than all-or-nothing for long outputs. A complete failure because one section had a formatting anomaly is worse than returning most of the data with a noted gap.

## Validation After Parsing

Parse produces a raw value; validation confirms it matches the expected schema. These are separate steps. A response that parses as valid JSON can still be structurally wrong:

```ts
import { z } from 'zod';

const ReviewSchema = z.object({
  score: z.number().min(0).max(10),
  issues: z.array(z.string()),
  verdict: z.enum(['pass', 'fail', 'review']),
});

const raw = extractJSON(text);
const validated = ReviewSchema.safeParse(raw);

if (!validated.success) {
  // Schema validation failed — retry with schema description appended to prompt
}
```

Validation errors are more specific than parse errors and produce better retry prompts ("missing required field 'verdict'" vs "invalid JSON").

## Key Rules

- Always extract JSON from code blocks first; fall back to bare JSON extraction second.
- Retry with the failed output included in the retry prompt — models correct themselves better with context.
- Limit retries to 2; a third failure on the same input usually indicates a prompt design problem, not a transient error.
- Use `safeParse` (Zod) or equivalent to validate structure after successful JSON parsing.
- For large outputs, extract section by section; partial success is better than total failure.
- Never assume the model used the exact label you specified — write regex case-insensitively and with whitespace tolerance.

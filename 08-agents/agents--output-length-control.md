# Agent Pattern: Output Length Control

## Overview
Without explicit length constraints, agent outputs drift long. A one-sentence question gets a five-paragraph answer. A simple code change gets wrapped in extensive explanation. Long outputs delay the useful content, consume tokens, and — in streaming contexts — make users wait. Length constraints in prompts produce consistently appropriately-sized responses.

## Implementation

### Length Specifications in Prompts

**For prose output:**
```
Summarize this error in 2 sentences. No background, no suggestions — just what failed and where.
```

```
Write a commit message. Maximum 72 characters for the subject line, no body.
```

```
Explain this function's behavior. Target: 100-150 words. Assume the reader knows JavaScript.
```

**For code output:**
```
Fix only the failing test. Do not refactor other tests, add comments, or improve formatting in other functions.
```

```
Return the SQL query only. No explanation before or after.
```

**For structured data:**
```
Return a JSON array of at most 5 items. Each item: { name: string, reason: string (max 20 words) }.
```

### Response Length Calibration

| Task type | Target length | Prompt constraint |
|---|---|---|
| One-line answer | < 20 words | "Answer in one sentence" |
| Quick explanation | 50-100 words | "Explain concisely (50-100 words)" |
| Standard | 200-400 words | (default, no constraint) |
| Detailed analysis | 400-800 words | "Full analysis" |
| Comprehensive | 800+ words | "Comprehensive coverage" |

### Schema-Based Length Control
For structured outputs, enforce length at the schema level:
```typescript
const responseSchema = z.object({
  summary: z.string().max(200),
  recommendations: z.array(
    z.object({
      action: z.string().max(100),
      priority: z.enum(["high", "medium", "low"]),
    })
  ).max(5),                        // at most 5 recommendations
});
```

### When Length Control Matters Most

**High value:**
- Summaries and digests that will be read in full
- Commit messages and PR descriptions (have enforced limits)
- API responses that will be processed by code
- Notifications or messages users receive

**Lower value:**
- Long-form analysis where completeness matters
- Code generation (the code should be as long as needed, not padded or truncated)
- Debugging output where full context is valuable

### Common Length Anti-Patterns to Avoid
- **Prefix bloat**: "Certainly! I'd be happy to help with that. Let me explain..." → just answer
- **Suffix hedging**: "...but these are just suggestions and you should consider your specific context." → cut after the content
- **Over-explanation of obvious steps**: documenting what each line does when the code is self-explanatory
- **Repeating the question**: restating the task before answering it

## Key Rules
- Specify length in the prompt rather than relying on implicit norms — agents calibrate to prompt specificity
- For code generation, constrain scope ("only fix the failing function") not character count — code should be as long as correct, no more
- For prose, word count targets work better than "be concise" (vague) or "be brief" (triggers overcorrection)
- Partial results delivered quickly are often more useful than complete results delivered slowly — consider streaming for long tasks
- The right output length is determined by what the consumer needs, not by what would be impressive or thorough
- When the prompt doesn't specify length, the default drifts long — add explicit constraints for any repeated or automated use

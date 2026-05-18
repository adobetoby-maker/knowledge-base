# Agent Pattern: Dynamic Prompt Construction

## Why Build Prompts at Runtime

A static system prompt is a lowest-common-denominator prompt — it tries to handle every case and therefore handles none of them perfectly. Prompts constructed at runtime from components are narrower, more precise, and easier to maintain: each component is independently testable, versioned, and swappable without touching the rest of the prompt.

The cost is complexity. Dynamic construction is worth it when: the task type varies significantly across invocations, persona or tone must adapt to user context, or the set of available tools changes based on configuration.

## The Four Components

Every prompt can be decomposed into:

**Persona** — who the agent is, what expertise it brings, what style it uses. Do not use vague labels ("you are a helpful assistant"). Be specific: domain, perspective, what the agent should and should not sound like. Example: "You are a senior backend engineer reviewing a pull request. You focus on correctness and security; style comments belong in a linter."

**Task** — what the agent must produce for this specific invocation. Not what it is (that is persona); what it must do right now. Include output format expectations here.

**Constraints** — what the agent must not do. Explicitly listing prohibitions is more reliable than relying on persona to imply them. "Do not suggest changes outside the scope of the PR." "Do not reference libraries not already in the dependency list."

**Examples** — 1-3 input/output pairs that calibrate the expected register and depth. Examples do more work than instructions because they show rather than tell. The model will pattern-match to examples even when instructions are ambiguous.

## Template Interpolation

```typescript
function buildPrompt(config: PromptConfig): string {
  const parts = [
    PERSONAS[config.persona],
    buildTaskSection(config.task, config.outputFormat),
    config.constraints.length > 0 ? buildConstraints(config.constraints) : '',
    config.examples.length > 0 ? buildExamples(config.examples) : '',
  ]
  return parts.filter(Boolean).join('\n\n')
}
```

Each component function owns its section header and formatting. The assembly function knows nothing about content — it only concatenates. This separation makes each component independently testable.

## Prompt Versioning

Store prompt components in a versioned registry, not inline strings:

```
prompts/
  personas/
    backend-reviewer.v2.txt
    legal-analyst.v1.txt
  tasks/
    pr-review.txt
    contract-summary.txt
  examples/
    pr-review-examples.json
```

Version only when the behavior change is intentional and observable. A version bump with no regression test is just noise. When a component changes:

1. Keep the previous version in the registry
2. Run both versions against the eval suite
3. Promote the new version only if it improves on the metric that motivated the change

Never edit a deployed version in place — always create a new version number.

## Testing Prompts Systematically

Static prompts are tested by eyeballing. Dynamic prompts must be tested programmatically:

**Component unit tests** — given known inputs, does the assembled prompt contain the right persona, task, constraints? Test the string, not the model response.

**Regression eval** — a fixed set of inputs with expected output characteristics (not exact text). Characteristics might be: "response is < 300 words", "response does not recommend X", "response includes a numbered list".

**A/B comparison** — run v1 and v2 on the same inputs and diff outputs. Human review is still required for quality, but diffs surface unexpected behavioral changes automatically.

The eval suite is the most important investment. Without it, prompt changes are guesswork.

## When Dynamic Construction Goes Wrong

**Too many components** — prompts assembled from 8+ fragments become incoherent. The model cannot honor conflicting constraints from different components. Keep it to: one persona, one task, constraints, examples.

**Interpolated user data in instructions** — never put unvalidated user input in the system prompt or in instruction sections. It becomes a prompt injection vector. User data belongs only in clearly delimited content sections.

**Persona conflicts** — if the task section implies different behavior from the persona section, the model will pick one and ignore the other unpredictably. Run components through a consistency check before deployment.

## Key Rules

- Four components: persona, task, constraints, examples — that is the complete list
- Examples do more work than instructions; always include at least one
- Store components in versioned files, not inline strings
- Never edit a deployed version — create a new version number
- Test components independently before testing assembled output
- Never interpolate unvalidated user input into instruction sections
- Eval suite is mandatory; without it you cannot safely iterate on prompts

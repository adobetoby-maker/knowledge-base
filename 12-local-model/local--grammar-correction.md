# Grammar and Style Correction with Local Models

Grammar correction is a deceptively hard task for local models because "correct" is context-dependent. A sentence that is grammatically wrong in formal prose may be intentionally stylized in marketing copy, dialogue, or brand voice. The model needs a way to distinguish errors from choices — and the output format needs to surface what changed so humans can review it.

## Diff-Based Output

Never instruct the model to return only the corrected text. If you do, reviewers have to read both versions and manually spot differences — which defeats the purpose of automation. Instead, request a structured diff:

```
Original: She don't know the answer yet.
Correction: She doesn't know the answer yet.
Change: "don't" → "doesn't" (subject-verb agreement)
```

Or in a structured format:
```json
{
  "original": "She don't know the answer yet.",
  "corrected": "She doesn't know the answer yet.",
  "changes": [{"from": "don't", "to": "doesn't", "reason": "subject-verb agreement"}]
}
```

The diff format forces the model to be explicit about what it changed and why, which also improves correction quality — the model that has to justify a change makes fewer spurious ones.

## Style Guide Injection

Local models have no knowledge of your organization's style guide. Inject the relevant rules as a concise list in the system prompt:

```
Style rules:
- Use "we" not "I" for company communications
- Oxford comma required
- Avoid passive voice in CTAs
- Numbers below 10 are spelled out
- "login" is a noun; "log in" is a verb
```

Keep the injected rules under 300 tokens. Longer style guides cause the model to drop rules from working memory. For large guides, select the most commonly violated rules (analyze a sample of past edits) rather than including everything.

## Distinguishing Errors from Intentional Style

The model must be told when deviation from standard grammar is acceptable. Without this, it will "fix" brand voice, poetic constructions, dialogue, and marketing fragments.

Explicit instruction: "Correct grammatical errors and typos only. Do not change sentence fragments if they are intentionally used for emphasis. Do not change non-standard capitalization in brand names or product names. Preserve colloquial phrasing in dialogue."

When in doubt, the model should flag rather than fix: "POSSIBLE_STYLE: [fragment]" — letting a human decide rather than silently rewriting.

## Common Failure Modes

**Over-correction**: the model rewrites content beyond grammar, changing word choice, sentence structure, or tone. Prevent this with: "Fix only clear errors. Do not rephrase, restructure, or improve style."

**False corrections on domain jargon**: medical, legal, or technical terms get flagged as errors. Inject a glossary or domain context in the system prompt: "This is a medical document. Treat clinical terminology as correct."

**Missed agreement errors with unusual names**: local models sometimes misparse sentences with proper nouns. Include examples of this failure mode in few-shot if it appears in your data.

## Key Rules

- Always request diff-based output, not just corrected text
- Inject style guide rules as a short, explicit list in the system prompt
- Explicitly tell the model not to change intentional stylistic choices
- Include a POSSIBLE_STYLE flag for ambiguous cases rather than forcing a correction
- Test on a sample with known intentional fragments and brand phrases before deployment
- Cap style guide injection at ~300 tokens; prioritize commonly violated rules

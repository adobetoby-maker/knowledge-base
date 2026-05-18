# Skill: Prompt Version Management

## Overview
Prompts are code. Treating them as hardcoded strings causes "prompt drift" — small edits accumulate with no audit trail, rollback is impossible, and A/B testing requires code deploys. Storing prompts in versioned files gives you history, review processes, and reproducible evals. The discipline pays off the first time a prompt regression breaks a feature in prod.

## Implementation

### 1. Directory structure
```
prompts/
  v1/
    system.txt           ← production (current)
    user-template.txt
  v2/
    system.txt           ← candidate (in eval)
    user-template.txt
  shared/
    format-instructions.txt  ← shared across versions
```

### 2. Load prompts from files
```ts
import { readFileSync } from 'fs';
import { join } from 'path';

const PROMPT_VERSION = process.env.PROMPT_VERSION ?? 'v1';

function loadPrompt(name: string, version = PROMPT_VERSION): string {
  const filePath = join(process.cwd(), 'prompts', version, `${name}.txt`);
  try {
    return readFileSync(filePath, 'utf-8').trim();
  } catch {
    // Fall back to v1 if version not found
    return readFileSync(join(process.cwd(), 'prompts', 'v1', `${name}.txt`), 'utf-8').trim();
  }
}

// Templates with variable substitution
function renderPrompt(template: string, vars: Record<string, string>): string {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => vars[key] ?? '');
}

// Usage
const systemPrompt = loadPrompt('system');
const userPrompt = renderPrompt(loadPrompt('user-template'), {
  userName: user.name,
  context: documentText,
});
```

### 3. Eval suite structure
```ts
// evals/run.ts — run against all test cases before promoting v2 to prod
interface EvalCase {
  id: string;
  input: string;
  expectedBehaviors: string[];  // things that should be true about output
  forbiddenPatterns: string[];  // things that must not appear
}

const evalCases: EvalCase[] = [
  {
    id: 'basic-summary',
    input: '...',
    expectedBehaviors: ['mentions key dates', 'under 100 words'],
    forbiddenPatterns: ['I cannot', 'As an AI'],
  },
];

async function runEvals(version: string) {
  const results = await Promise.all(evalCases.map(async (c) => {
    const output = await callLLM(c.input, version);
    const passed = c.expectedBehaviors.every(b => scoreOutput(output, b));
    const clean = c.forbiddenPatterns.every(p => !output.includes(p));
    return { id: c.id, passed: passed && clean, output };
  }));
  
  const passRate = results.filter(r => r.passed).length / results.length;
  console.log(`Version ${version}: ${(passRate * 100).toFixed(1)}% pass rate`);
  return passRate;
}

// Gate promotion: v2 must match or beat v1
async function promoteIfBetter() {
  const [v1Score, v2Score] = await Promise.all([runEvals('v1'), runEvals('v2')]);
  if (v2Score >= v1Score) {
    console.log('v2 passes — update PROMPT_VERSION=v2 in env');
  } else {
    console.error(`v2 regression: ${v2Score} < ${v1Score}`);
    process.exit(1);
  }
}
```

### 4. Rollback is a config change
```bash
# Deploy v2 (set env var, no code change required)
vercel env add PROMPT_VERSION v2

# Rollback to v1 (instant, no redeploy needed if using edge config)
vercel env rm PROMPT_VERSION
# or
vercel env add PROMPT_VERSION v1
```

### 5. Commit message convention for prompt changes
```
feat(prompts): add v2 system prompt with improved JSON extraction

- Adds explicit JSON output instruction
- Removes ambiguous "be concise" phrasing that caused long responses
- Eval: v2 scores 94% vs v1 83% on summary-quality test suite
```

## Key Rules
- **Never hardcode prompts in business logic files** — they get lost in code reviews and can't be evaluated independently.
- **Version by filename/directory, not database rows** — file-based versions live in git, get reviewed in PRs, have blame history.
- **Eval before promoting** — never ship a new prompt version that hasn't passed the eval suite. Even "obvious improvements" can regress edge cases.
- Use `{{variable}}` templates in prompt files; render at runtime — keeps prompts readable without string concatenation in code.
- Shared instructions (formatting, safety rules) go in `shared/` and are composed, not duplicated, across versions.
- Treat prompt version as a deploy variable — rollback should not require a code change.
- Log which prompt version was used for each LLM call — critical for debugging production regressions later.

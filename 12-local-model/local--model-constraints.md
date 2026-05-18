# Local Model Constraints and Compensation Strategies

**When:** Running any task on a local model (Llama, DeepSeek, Qwen, Mistral, etc.).
**Rule:** Local models are weaker at ambiguity resolution, long-horizon reasoning, and instruction following. Compensate by making instructions more explicit, shorter, and more prescriptive.

## Common Local Models and Their Strengths

| Model | Context | Best For |
|-------|---------|---------|
| Llama 3.3 70B | 128k | Architecture, code generation, reasoning |
| DeepSeek Coder V2 | 128k | Code specifically — very strong at TypeScript/Python |
| Qwen2.5 72B | 128k | Multi-lingual, general coding, instruction following |
| Llama 3.2 3B | 128k | Mechanical tasks: rename, replace, format |
| Phi-4 14B | 16k | Strong reasoning for its size |
| Mistral 7B | 32k | Fast, good for summaries and classification |

## What Breaks Compared to Claude

### Ambiguity handling
Claude: "Fix the auth bug" → figures out what's wrong from context
Local model: "Fix the auth bug" → may guess wrong or ask for clarification that never comes

**Compensate:** Be specific. "In `/Users/drive/jrs-auto-repair/lib/adminAuth.ts:45`, the `verifyAdmin()` function is returning null even when a valid cookie exists. Fix this."

### Multi-step planning
Claude: can hold a complex plan across 20 steps
Local model: loses track after 3-4 steps without reinforcement

**Compensate:** Break into smaller tasks. One task = one file = one outcome. Load the relevant knowledge files as system prompt.

### Instruction following
Claude: follows formatting and process instructions reliably
Local model: may not follow NEEDS_HUMAN.md pattern, may commit anyway, may use wrong format

**Compensate:** Put critical instructions in ALL CAPS or in the first 100 tokens. Repeat critical rules.

## Prompt Patterns That Work Better on Local Models

### Explicit "if...then" instructions
```
# WRONG for local models (too implicit)
"Make this better"

# RIGHT for local models (explicit decision tree)
"IF the component uses useState → it must have 'use client' at the top.
IF the file is in the app/ directory AND does not use hooks → remove 'use client'.
ONLY modify files in src/components/. DO NOT touch app/ directory files."
```

### Constrained output format
```
"Respond ONLY with the complete modified file content.
Do not include explanations, markdown formatting, or code fences.
Start your response directly with the first line of the file."
```

### Step-by-step with verification
```
"Step 1: Read /Users/drive/jrs-auto-repair/lib/adminAuth.ts
Step 2: Find the function called verifyAdmin
Step 3: Check if the cookie parsing handles the case where the cookie value has quotes around it
Step 4: If it does not → add handling for quoted values
Step 5: Write the complete updated file"
```

## Temperature Settings for Code Work
- **Temperature 0** — fully deterministic, best for: code edits, refactors, mechanical tasks
- **Temperature 0.1–0.3** — slight creativity, best for: code generation with some design choices
- **Temperature 0.7+** — avoid for code — introduces bugs and hallucinations

## Context Window Management for Local Models
Most local models degrade in quality past 8k tokens in the context, even with 128k window.
Load no more than 3-4 knowledge files for a local model task.
Use `13-stack-bundles/` — pre-merged, dense, relevant context in one file.

## Verifying Local Model Output
Never trust local model code without verification:
```bash
npm run build    # catches import and syntax errors
npx tsc --noEmit # catches type errors
```
Local models hallucinate API shapes and library names more often than Claude.
Always verify that imported functions exist.

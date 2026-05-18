# Agent Pattern: Progress Checkpoints

## Overview
Long-running agent tasks (migrations, large refactors, multi-file rewrites) lose all progress if the process is interrupted — by a timeout, error, context limit, or network issue. Checkpointing writes durable progress markers after each completed step, enabling resumption from the last successful point rather than a full restart.

## Implementation

### Define Milestones Upfront
At the start of a long task, define discrete, verifiable milestones:
```
Task: Migrate 50 components from class components to function components

Milestones:
1. [ ] Audit: list all class components with their file paths
2. [ ] Migrate: components/Button.tsx
3. [ ] Migrate: components/Modal.tsx
...
50. [ ] Migrate: pages/Dashboard.tsx
51. [ ] Verify: all tests pass
52. [ ] Cleanup: remove any remaining class component imports
```

### Checkpoint File Pattern
Write a checkpoint file after each milestone:
```typescript
// checkpoint.json
{
  "task": "class-to-function-migration",
  "startedAt": "2026-05-18T10:00:00Z",
  "lastUpdated": "2026-05-18T10:47:00Z",
  "completed": [
    "audit",
    "components/Button.tsx",
    "components/Modal.tsx"
  ],
  "remaining": [
    "components/Input.tsx",
    "pages/Dashboard.tsx"
  ],
  "errors": [
    {
      "file": "components/LegacyChart.tsx",
      "error": "Uses deprecated lifecycle method that has no hook equivalent",
      "skipped": true
    }
  ]
}
```

### Resumption Logic
At task start, check for an existing checkpoint:
```
IF checkpoint.json exists:
  READ completed milestones
  SKIP completed milestones
  RESUME from first incomplete milestone
  LOG "Resuming from checkpoint: completed X of Y steps"
ELSE:
  START from beginning
  CREATE checkpoint.json with empty completed array
```

### Granularity Guidelines
Checkpoint granularity depends on step cost:
- File-by-file migration: checkpoint per file
- Database migration: checkpoint per table/batch
- API integration setup: checkpoint per step (auth, schema, endpoints, tests)
- Too granular: checkpointing every line edit — overhead outweighs benefit
- Too coarse: checkpointing only at the end — defeats the purpose

### When Checkpointing Matters Most
- Tasks touching 10+ files
- Tasks that run external commands (database migrations, builds, deploys)
- Tasks that modify data (not just code)
- Tasks running autonomously without a human monitoring each step

## Key Rules
- Write the checkpoint AFTER verifying the step succeeded, not before — a checkpoint of an unverified step can cause resumption to skip a broken step
- Include errors and skipped items in the checkpoint — they're part of the task state
- Checkpoint files should be human-readable (JSON or YAML) so a human can inspect progress without running the agent
- At resumption, log what's being skipped and why — the human needs to know the task didn't start over
- Delete the checkpoint file when the task is fully complete — stale checkpoints confuse future runs
- For tasks that run commands, checkpoint after the command succeeds, not after issuing it

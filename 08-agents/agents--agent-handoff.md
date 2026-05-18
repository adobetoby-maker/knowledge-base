# Agents: Agent Handoff

## Overview
Agent handoff occurs when one agent (or session) transfers work to another agent (or a new session). This happens in multi-agent systems when a specialist agent takes over from an orchestrator, when a session ends and a new one begins on the same task, or when a human-in-the-loop pause separates two agent runs. The single biggest handoff failure is assuming context transfers automatically — it does not. Everything the receiving agent needs must be explicitly written in the handoff.

## What Must Be In the Handoff

**Completed work summary**
- What was accomplished, in concrete terms
- Deliverables produced: files written, APIs called, decisions made
- Not "I did research" — "I retrieved 8 documents about X and identified the following key points: ..."

**Current state**
- What step is in progress or was the last step completed
- What data or artifacts exist and where they are located (file paths, database rows, API resources)
- Any state variables the receiving agent needs (counters, flags, current config)

**Blockers encountered**
- Problems that prevented full completion
- Errors returned by tools, with specifics
- Ambiguities in the original instructions that were assumed one way

**Next steps**
- The specific next action the receiving agent should take
- Not vague ("continue the task") — specific ("read /tmp/research.json, synthesize findings into a 500-word summary, save to /tmp/summary.md")
- Ordered list if multiple steps remain

**Constraints discovered**
- New constraints found during execution that weren't in the original instructions
- "The API does not support batch requests — must be done one at a time"
- "The user confirmed they want the report in British English"

## Handoff Document Format

Write the handoff as if the recipient has no prior context:

```
# Task Handoff

## Goal
[Original task goal — repeated verbatim]

## Completed
- [Specific action 1]
- [Specific action 2]

## Current State
- Status: [in progress / blocked / 80% complete]
- Artifacts: [location of any files, resources, data produced]
- Last successful step: [description]

## Blockers / Issues
- [Issue and what was tried]

## Next Steps (in order)
1. [Specific action]
2. [Specific action]

## Constraints Discovered
- [Constraint 1]
- [Constraint 2]
```

## Session Handoff (New Conversation)

When a task must pause and resume in a new conversation context (new session):
- Write the handoff document to a file or persistent store before the session ends
- The new session begins by reading the handoff document, not by trying to reconstruct context from conversation history (which won't be present)
- The handoff document IS the memory bridge between sessions

## Quality Check Before Handoff

Before completing a handoff, verify:
- [ ] A new agent with zero prior context could read this and continue without ambiguity
- [ ] All file paths and resource identifiers are absolute (not relative)
- [ ] All decisions made are documented with the rationale
- [ ] Next steps are ordered and specific enough to act on immediately
- [ ] Blockers are specific (not "it didn't work") — include error messages, responses received

## Key Rules

- Never assume context transfers — write everything the receiving agent needs
- Completed work must be specific and verifiable, not narrative
- Next steps must be executable without clarification
- Blockers need specifics: exact error, exact response, what was tried
- Handoff document lives in persistent storage (file, database) — not in the session that's ending
- New agents begin by reading the handoff document as their first action

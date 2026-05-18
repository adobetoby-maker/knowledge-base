# Principle: Code Review Principles

## What Code Review Is For

Code review is not a gatekeeping ritual. It is the main channel for knowledge transfer, catching defects before they reach production, and maintaining architectural coherence as a codebase grows. A review that only catches typos is not review — it is editing. A review that only asks "does this work?" misses the harder questions about whether it works in every case and whether it fits the system.

The standard is not perfection. It is: would merging this make things worse? If no, approve with comments. If yes, block with specific, actionable feedback.

## The Right Things to Review

**Correctness** — does the code do what it claims? Does it handle edge cases: empty input, concurrent access, network failure, authorization edge cases? Read the code as an adversary: what input would make this wrong? Correctness issues are the highest-priority blockers.

**Design fit** — does this change fit the existing architecture, or does it fight it? A new pattern introduced without explanation is a signal to pause. Is this an intentional evolution or drift? If the PR author intended to introduce a new pattern, it should say so. Design issues are worth a conversation before block.

**Security** — does this code cross trust boundaries correctly? Is user input validated before use? Are secrets handled safely? Does the new endpoint have authorization? Are SQL queries parameterized? Security issues are blockers regardless of how minor they look — small gaps compound.

**Testability and coverage** — are the right things tested? New business logic without a test is incomplete. A PR that adds behavior and removes tests is a red flag regardless of the explanation.

## What NOT to Review

**Style** — use a linter and formatter. If the CI pipeline enforces style, do not comment on it in review. Style comments waste reviewer time, make authors defensive, and crowd out substantive feedback. Configure Prettier, ESLint, or whatever the project uses, and let it enforce automatically.

**Personal preference** — "I would have done this differently" is not a review comment. If there are two valid approaches and the PR uses one, that is fine. Reserve feedback for cases where the chosen approach creates a problem.

**Implementation details that do not affect the outcome** — variable names inside a private function, the order of operations when they do not affect behavior, using a for-loop vs. map when both are readable. These are editorial judgments, not review.

## Tone: Ask Questions, Do Not Dictate

A review comment phrased as a question surfaces information and invites dialogue. A review comment phrased as a directive shuts down dialogue and breeds resentment.

Wrong: "Change this to use the repository pattern."
Right: "Could this benefit from going through the repository layer for consistency with how we handle other entities? Or is there a reason to keep it direct?"

Wrong: "This is slow."
Right: "I'm concerned this might be slow at scale — this runs inside the loop, so for 10K records it will be N queries. Have you benchmarked this, or should we discuss an alternative?"

The goal is shared understanding, not authority. A comment that reads as "you're wrong" will be defended against. A comment that reads as "I'm uncertain, let's talk" gets responded to honestly.

## Approving With Comments

Not every comment requires a change before merging. Distinguish:
- **Blockers** — must be addressed before merge
- **Non-blocking suggestions** — worth considering but not required
- **Questions for understanding** — the reviewer is learning, not requiring changes

Label them. "Blocker:" vs. "Suggestion:" vs. "Question:" at the start of a comment saves back-and-forth about whether a response is required.

## Key Rules

- Review correctness, design fit, security, and test coverage — in that priority order
- Do not review style in comments; enforce it automatically via linters
- Ask questions rather than issue directives — dialogue surfaces better outcomes
- Label comments as blockers, suggestions, or questions to set clear expectations
- Personal preference for an alternative approach is not a reason to block
- Small security gaps are blockers regardless of apparent severity — they compound
- A review that only approves without reading is not a review; it is a rubber stamp

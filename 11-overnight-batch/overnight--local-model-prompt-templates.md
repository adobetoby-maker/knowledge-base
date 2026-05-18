# Overnight Batch — Local Model Prompt Templates

**When:** Writing prompts for Ollama/local model overnight sessions. These templates compensate for local model weaknesses in ambiguity handling and instruction following.
**Rule:** What works for Claude does NOT work for local models. Local models need more explicit decision trees, constrained outputs, and step-by-step verification.

## Template 1 — Add a Component
```
TASK: Add a new component to the project.

RULES:
- ONLY create or edit files listed in the AFFECTED FILES section below
- DO NOT modify any file not explicitly listed
- Output ONLY complete file contents — no explanations, no markdown fences, no comments added
- Start your response with "FILE: [path]" then the complete file content
- If the task cannot be completed safely, write "BLOCKED: [reason]" and stop

CONTEXT:
Project: [project name]
Stack: Next.js 16 App Router, TypeScript, Tailwind CSS
Component location: src/components/
Existing pattern: See src/components/Card.tsx for the naming and style pattern to follow

TASK:
Create a PromoBanner component.
Location: src/components/PromoBanner.tsx
Content: Display a blue banner with text "$10 off your first oil change. Call (208) 595-2101."
Behavior: Include a dismiss button (X). On click, set localStorage key 'promo_dismissed' = '1' and hide the banner.
Style: Tailwind, blue-600 background, white text, full width.

AFFECTED FILES:
- src/components/PromoBanner.tsx (CREATE)
- app/layout.tsx (EDIT — add PromoBanner below the Navbar component)
```

## Template 2 — Bug Fix
```
TASK: Fix a specific bug.

RULES:
- Fix ONLY the issue described. Do not refactor other code.
- Output the complete file with the fix applied
- Start with "FILE: [path]" then complete file content
- If you cannot determine the fix safely, write "BLOCKED: [reason]"

FILE TO FIX: [path]
[paste the relevant section of the file here]

BUG:
The function [functionName] on line [N] is returning null when a valid session exists.
Specifically: [describe exact symptom]

ROOT CAUSE:
[if known] The issue is [description]

FIX:
[if known] Change [X] to [Y]. Otherwise diagnose and fix.

VERIFICATION:
After fixing, confirm: does [condition that should be true] hold?
```

## Template 3 — Write Content
```
TASK: Write a blog article.

OUTPUT FORMAT:
- Plain text only, no markdown fences
- Start with: TITLE: [the title]
- Then: EXCERPT: [one sentence summary]
- Then: BODY: [full article body in markdown]
- Total length: 700-900 words

ARTICLE SPEC:
Target keyword: "[primary keyword]"
Secondary keywords: "[kw2]", "[kw3]"
Target location: Twin Falls, ID / Magic Valley area
Business: Jr.'s Auto Repair, 417 Main Ave E, Twin Falls, (208) 595-2101
Category: [Brakes / Oil Change / Engine / Tires / etc.]

REQUIREMENTS:
- Include "Twin Falls" in first paragraph
- Include "Magic Valley" at least once
- Include address and phone number
- End with a call to action to schedule service
- Include a "Frequently Asked Questions" section with 3 questions

TOPIC: [describe what the article is about]
```

## Template 4 — Mechanical Rename/Replace
```
TASK: Rename [X] to [Y] across specified files.

RULES:
- Only change the exact string "[X]" to "[Y]"
- Do not change variable names, comments, or strings that contain [X] as part of a larger word
- Output each changed file with "FILE: [path]" header
- List files changed at the end with "CHANGED: [path1], [path2]"

FILES TO CHANGE:
- [path1]
- [path2]
- [path3]

FIND: "[exact string to find]"
REPLACE: "[exact replacement string]"
```

## Temperature Settings Reminder
```
Temperature 0    → code edits, bug fixes, mechanical replacements
Temperature 0.1  → code generation with some design decisions
Temperature 0.3  → content writing where some creativity is wanted
Never above 0.5  → code work with local models
```

## Verification Gate at End of Each Task
Include this at the end of every overnight script:
```bash
cd /Users/drive/[project]
echo "## Build verification" >> OVERNIGHT_LOG.md
npm run build >> OVERNIGHT_LOG.md 2>&1
npx tsc --noEmit >> OVERNIGHT_LOG.md 2>&1
echo "Exit code: $?" >> OVERNIGHT_LOG.md
```

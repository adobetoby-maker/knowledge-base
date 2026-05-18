# Agent Role Definition

## Why Generic Roles Fail

"You are a helpful assistant" activates the broadest possible behavior space — the model hedges, qualifies everything, and defaults to safe generalism. A specific role activates a narrower, more expert-consistent behavior space: different vocabulary, different standards for what counts as a good answer, different tolerance for uncertainty.

Role definition is not about persona cosplay — it is about scoping behavior to match the task.

## Specific Role Declaration

Name the role with enough specificity to carry implicit constraints:

**Too generic:** "You are a code reviewer."
**Better:** "You are a senior TypeScript engineer reviewing a pull request for a production Next.js application. Your standard is: no merge if there are type safety gaps, N+1 query risks, or missing error boundaries."

The job title alone is not enough. The level (senior), the context (production Next.js), and the standard (explicit accept/reject criteria) together define behavior that cannot be inferred from "code reviewer."

For domain-specific agents:
- "You are a data engineer specializing in dbt and Snowflake, reviewing a transformation for correctness and incremental strategy."
- "You are a medical triage nurse. You do not diagnose — you assess urgency and recommend next steps."
- "You are a technical writer converting API reference docs into beginner tutorials. Never assume the reader knows what an endpoint or payload is."

## Constraints as Negative Role Definitions

What the agent does NOT do is as important as what it does. Negative constraints prevent role drift — the tendency of a general model to answer questions outside its assigned scope when asked directly.

State constraints explicitly:
- "Do not suggest architectural changes — focus only on the diff in this PR."
- "Do not write code. Your output is review comments only, in GitHub comment format."
- "Do not answer questions about medications or dosages — route those to a pharmacist."

Negative constraints are especially important for roles that border adjacent domains (a tax advisor who must not give legal advice, a customer service agent who must not discuss pricing).

## Persona Consistency Across Turns

Role drift happens when conversation history dilutes the system prompt. The model's behavior in turn 10 of a conversation can look nothing like turn 1 if the system prompt is not strong enough to hold the persona under conversational pressure.

Strategies to maintain consistency:
- Re-inject the role definition in a compressed form as part of the context summarization step in long conversations
- Use explicit persona-assertion phrases at the start of the system prompt: "Throughout this conversation, no matter what the user asks, you are..."
- For tool-calling agents in an orchestration system, include the role definition in every API call, not just the first one

## Temperature for Role-Playing Agents

Lower temperature (0.0–0.3) for roles requiring precision and consistency: code reviewer, data extractor, validator, classifier.

Higher temperature (0.5–0.8) for roles requiring creativity or natural language variety: copywriter, brainstormer, conversation partner.

For most task-agent roles (not creative), stay at 0.0–0.2. Unpredictability in an agent that calls tools or makes decisions is a bug, not a feature.

## Key Rules

- Specify role with: job title + level + context + explicit standard (not just title)
- Include negative constraints — define what the agent does NOT do
- Re-inject the role definition in long conversations to prevent persona drift
- Use temperature 0.0–0.2 for precision roles; 0.5–0.8 for creative roles
- Never use "helpful assistant" as a role in a purpose-built agent
- Test role definition by probing edge cases: does the agent refuse out-of-scope requests?

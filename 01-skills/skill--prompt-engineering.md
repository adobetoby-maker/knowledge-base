# Skill: prompt-engineering

**Trigger:** Designing prompts for AI features in applications (chatbots, AI forms, content generators). Need to get consistent, structured, or high-quality output from AI calls.
**Invoke:** `/prompt-engineering`
**Returns:** Prompt design patterns, system prompt templates, chain-of-thought techniques, output formatting, evaluation methods.

## When to Invoke
- Building a chatbot system prompt
- Getting inconsistent AI output and need to stabilize it
- Need the AI to always output a specific JSON structure
- Want the AI to follow a specific persona or tone
- Writing prompts for overnight batch processing

## Core Principles

### Be Specific About Output Format
```
WEAK: "Analyze this customer review"
STRONG: "Analyze this customer review. Return JSON with:
  - sentiment: 'positive' | 'neutral' | 'negative'
  - summary: one sentence (under 100 chars)
  - action_required: boolean
  - urgency: 1-5 scale"
```

### Give Examples (Few-Shot)
```
WEAK: "Format addresses consistently"
STRONG: "Format addresses consistently. Examples:
  Input: 'twin falls idaho 83301 main ave'
  Output: '417 Main Ave, Twin Falls, ID 83301'
  
  Input: '1234 center st jerome id'
  Output: '1234 Center St, Jerome, ID 83338'
  
  Now format: [address]"
```

### Constrain the Output
```
"Respond with ONLY the JSON object. No explanation, no markdown, no preamble.
Start your response with '{' and end with '}'."
```

### Role Assignment
```
"You are a helpful service advisor at Jr.'s Auto Repair in Twin Falls, ID.
You answer questions about car maintenance and repair.
You recommend scheduling an appointment for specific repairs.
Phone: (208) 595-2101. Hours: Mon-Sat 9AM-5PM.
You do NOT diagnose issues definitively — always recommend inspection."
```

## Chain-of-Thought for Complex Analysis
```
"Think step by step:
1. First, identify what service the customer is asking about
2. Then, determine if this is something we can help with
3. Then, provide the relevant information or recommendation
4. Finally, include a call to action"
```

## Temperature by Task
```
Temperature 0:    JSON extraction, classification, formatting — deterministic
Temperature 0.3:  Analysis, summaries — slight variation acceptable
Temperature 0.7:  Creative content, marketing copy — variety wanted
Temperature 1.0+: Brainstorming, creative writing — maximum variety
```

## Reducing Hallucination
```
- "If you don't know, say 'I don't have that information' — do not guess"
- "Only use facts from the context provided below. Do not add information."
- "If the answer is not in the context, respond: 'I couldn't find that in our records.'"
- Use temperature 0 for factual tasks
```

## System Prompt Template for Chatbots
```
You are [name], [role] at [business].

CAPABILITIES:
- [what you can help with]
- [what you can help with]

LIMITATIONS:
- You do NOT [limit 1]
- You do NOT [limit 2]

TONE: [friendly/professional/casual]
RESPONSE LENGTH: [short/medium/detailed]

BUSINESS INFO:
[address, phone, hours, key services]

When unsure: [fallback behavior]
```

## What Skill Returns
Advanced prompt design patterns, evaluation rubrics, A/B testing prompts, structured output patterns, multi-turn conversation design, and safety guardrails.

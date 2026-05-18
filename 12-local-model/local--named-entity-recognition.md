# Extracting Named Entities with Local Models

## Why Prompt-Based NER

Traditional NER libraries (spaCy, Stanford NER) use pre-trained statistical models that excel on newswire text but struggle with domain-specific entities — medical dosages, product SKUs, legal citations. A local LLM with domain-specific prompting handles novel entity types without fine-tuning, at the cost of higher latency than a dedicated NLP model.

Use prompt-based NER when: entity types are domain-specific, you need flexible span boundaries, or you need to extract relationships between entities at the same time.

Use a dedicated NLP model when: you need sub-50ms latency on commodity hardware, entity types are standard (PER/ORG/LOC/DATE), and domain shift is minimal.

## Entity Types

Define your entity taxonomy explicitly in the prompt. Standard types:
- `PERSON` — full or partial human names
- `ORG` — companies, agencies, institutions
- `LOCATION` — cities, countries, addresses, geographic features
- `DATE` — absolute dates, relative dates ("next Tuesday"), date ranges
- `MONEY` — currency amounts with or without symbol
- `PRODUCT` — product names, SKUs, model numbers
- `EVENT` — named events, conferences, incidents

Add domain-specific types as needed. Each addition reduces model accuracy on the others — test carefully before expanding beyond 8 types.

## Structured Output Format

Always request JSON output. Prose entity lists are fragile to parse. Use a schema like:

```json
{
  "entities": [
    { "text": "Apple Inc.", "type": "ORG", "start": 0, "end": 10 },
    { "text": "Tim Cook", "type": "PERSON", "start": 24, "end": 32 }
  ]
}
```

Include character offsets if you need to highlight spans in the source text. Compute them by finding the first occurrence of `entity.text` in the input string after the previous entity's end position (handles repeated entity text correctly).

Request JSON with a system prompt constraint: "Respond with only valid JSON. No explanation." Validate the output with a JSON parser before using it — local models sometimes add prose before or after the JSON block.

## Handling Multi-Token Entities

Multi-word entities are where prompt-based NER earns its keep over token classifiers. The entity `"New York City Department of Education"` spans 8 tokens; a token-level model might split it at "Department".

In your prompt, instruct: "Capture the full entity span including determiners and modifiers. 'The European Central Bank' → 'European Central Bank' (drop 'The')." Give examples of common span boundaries for your domain.

Titles that are part of a name present the same issue. `"Dr. Sarah Chen"` — include the title (`"Dr. Sarah Chen"`) when it's used as part of identification. Use consistent rules and bake them into examples.

## Post-Processing: Alias Resolution

The same real-world entity appears in many surface forms: `"Apple"`, `"Apple Inc."`, `"Apple Computer"`, `"AAPL"`. Raw NER gives you each separately. Post-processing unifies them.

**Canonical form**: Define one canonical name per entity in your domain. Map variants to it via:
1. Exact match lookup (fast path)
2. Edit-distance or token overlap for fuzzy matches
3. Embedding similarity for semantic aliases ("Big Blue" → IBM)

Store canonical → aliases as a dictionary. Update it as new aliases appear in production data. This is a domain knowledge problem, not a model problem — don't expect the model to resolve aliases it's never seen.

**Coreference**: "Microsoft announced... The company then..." — "The company" refers to Microsoft. Full coreference resolution requires another pass or a larger model. For most extraction tasks, resolve only within a sentence to keep complexity manageable.

## Prompt Template

```
Extract named entities from the text below. 
Entity types: PERSON, ORG, LOCATION, DATE, MONEY.
Return JSON: {"entities": [{"text": "...", "type": "...", "start": N, "end": N}]}
Do not include character offsets if you are uncertain of their values.

Text: {input_text}
```

## Key Rules

- Request JSON output and validate it — never trust prose entity lists for downstream processing.
- Include character offsets in the schema; compute them in post-processing, not in the model response, for accuracy.
- Limit entity taxonomy to 8 types maximum before testing impact on existing types.
- Do alias resolution in a deterministic post-processing step, not inside the model prompt.
- Use domain-specific examples in few-shot prompts; standard examples produce standard-domain accuracy.
- For high-throughput NER, benchmark against a dedicated NLP model — the latency difference may dominate.

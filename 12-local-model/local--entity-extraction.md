# Local Models: Entity Extraction

## Overview

Extract structured data from unstructured text — names, dates, addresses, product SKUs, email addresses, phone numbers, or custom domain entities. Local models excel at this: no data leaves your network, runs overnight on large datasets, and smaller models (7B) are often sufficient for well-defined entity types.

## Prompt Design

```ts
const ENTITY_EXTRACTION_PROMPT = `Extract all entities from the text below.
Return valid JSON matching this exact structure:

{
  "people": ["name1", "name2"],
  "organizations": ["org1", "org2"],
  "dates": ["YYYY-MM-DD format"],
  "amounts": [{"value": 1000, "currency": "USD", "context": "invoice amount"}],
  "locations": ["city, country"],
  "emails": ["email@domain.com"],
  "phones": ["+1-555-0100"]
}

Return empty arrays for categories with no matches.
Return ONLY valid JSON, no other text.

Text:
---
{text}
---

JSON:`
```

## Implementation

```ts
interface ExtractedEntities {
  people: string[]
  organizations: string[]
  dates: string[]
  amounts: Array<{ value: number; currency: string; context: string }>
  locations: string[]
  emails: string[]
  phones: string[]
}

async function extractEntities(text: string): Promise<ExtractedEntities> {
  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1',
      prompt: ENTITY_EXTRACTION_PROMPT.replace('{text}', text),
      stream: false,
      options: {
        temperature: 0,  // Deterministic extraction
        num_predict: 1024,
      },
    }),
  })

  const data = await response.json()
  const raw = data.response.trim()

  // Extract JSON from potential surrounding text
  const jsonMatch = raw.match(/\{[\s\S]*\}/)
  if (!jsonMatch) throw new Error('No JSON in response')

  const parsed = JSON.parse(jsonMatch[0])

  return {
    people: Array.isArray(parsed.people) ? parsed.people : [],
    organizations: Array.isArray(parsed.organizations) ? parsed.organizations : [],
    dates: Array.isArray(parsed.dates) ? parsed.dates : [],
    amounts: Array.isArray(parsed.amounts) ? parsed.amounts : [],
    locations: Array.isArray(parsed.locations) ? parsed.locations : [],
    emails: Array.isArray(parsed.emails) ? parsed.emails : [],
    phones: Array.isArray(parsed.phones) ? parsed.phones : [],
  }
}
```

## Regex Post-Processing

For high-precision fields (email, phone, dates), validate model output with regex:

```ts
function validateExtracted(entities: ExtractedEntities): ExtractedEntities {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  const phoneRegex = /^\+?[\d\s\-().]{7,}$/
  const dateRegex = /^\d{4}-\d{2}-\d{2}$/

  return {
    ...entities,
    emails: entities.emails.filter(e => emailRegex.test(e)),
    phones: entities.phones.filter(p => phoneRegex.test(p.replace(/\s/g, ''))),
    dates: entities.dates.filter(d => dateRegex.test(d) && !isNaN(Date.parse(d))),
  }
}
```

Regex catches model hallucinations — common for emails and phone numbers.

## Domain-Specific Entities

For specialized extraction (medical codes, product SKUs, legal terms), provide examples in the prompt:

```ts
const MEDICAL_ENTITY_PROMPT = `Extract medical entities from the text below.

Entity types to find:
- diagnoses: ICD-10 codes or plain descriptions of conditions
- medications: drug names and dosages
- procedures: treatment or procedure names
- dates: treatment or appointment dates (YYYY-MM-DD)

Examples:
Text: "Patient prescribed metformin 500mg twice daily for T2DM, follow-up in 3 months"
Output: {
  "diagnoses": ["T2DM (Type 2 Diabetes Mellitus)"],
  "medications": ["metformin 500mg twice daily"],
  "procedures": [],
  "dates": []
}

Text to process:
{text}

Output JSON:`
```

## Batch Processing

```ts
async function batchExtract(texts: Array<{ id: string; text: string }>) {
  const results = []

  for (const item of texts) {
    try {
      const entities = await extractEntities(item.text)
      results.push({ id: item.id, entities })
    } catch (err) {
      results.push({ id: item.id, error: String(err) })
    }

    // Throttle to avoid overloading the model server
    await new Promise(r => setTimeout(r, 100))
  }

  return results
}
```

## Key Rules

- Temperature 0 is critical for extraction — any randomness produces inconsistent output.
- Always validate high-precision fields (email, phone, dates) with regex after extraction.
- Smaller context windows need chunking for long documents — extract per paragraph, then merge.
- Instruct the model to return empty arrays rather than `null` — `null` breaks downstream array operations.
- Return `JSON only` in the prompt — models often add explanatory text before/after JSON without explicit instruction.

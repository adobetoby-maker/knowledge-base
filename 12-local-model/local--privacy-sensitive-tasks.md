# Local Model: Privacy-Sensitive Tasks

## When to Use Local Models for Privacy

Send to local model (not cloud API) when the content contains:
- PII: names, emails, phone numbers, addresses
- Medical records, diagnoses, prescriptions
- Financial data: account numbers, SSNs, exact balances
- Internal business documents not intended for third parties
- Legal correspondence
- HR records, performance reviews

Cloud API providers have data retention policies and legal obligations. Local models process data entirely on the machine — no data leaves.

## Classification Logic

```ts
function requiresLocalModel(content: string): boolean {
  const PII_PATTERNS = [
    /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/,        // Phone numbers
    /\b\d{3}-\d{2}-\d{4}\b/,                  // SSN pattern
    /\b[A-Z]{1,2}\d{6,9}\b/i,                 // Passport/ID numbers
    /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/, // Credit card
  ]

  const SENSITIVE_KEYWORDS = [
    'diagnosis', 'prescription', 'medical record', 'patient',
    'salary', 'compensation', 'performance review',
    'confidential', 'attorney', 'privileged',
  ]

  const hasPII = PII_PATTERNS.some((p) => p.test(content))
  const hasSensitiveKeywords = SENSITIVE_KEYWORDS.some((kw) =>
    content.toLowerCase().includes(kw)
  )

  return hasPII || hasSensitiveKeywords
}

// Route the request
async function processDocument(content: string, task: string): Promise<string> {
  if (requiresLocalModel(content)) {
    console.log('Privacy-sensitive content: routing to local model')
    return callLocalModel({ content, task })
  }
  return callCloudModel({ content, task })
}
```

## Local Model for PII Extraction

```ts
interface PIIExtractResult {
  names: string[]
  emails: string[]
  phones: string[]
  addresses: string[]
}

async function extractPIILocally(text: string): Promise<PIIExtractResult> {
  const prompt = `Extract all personally identifiable information from this text.
Return only JSON, no explanation.

Text: ${text}

Return format:
{"names":[],"emails":[],"phones":[],"addresses":[]}`

  const response = await callOllama({
    model: 'llama3.2:3b',  // Small model sufficient for extraction
    prompt,
    options: { temperature: 0 },
  })

  try {
    const json = response.match(/\{[\s\S]*\}/)
    return JSON.parse(json?.[0] ?? '{}')
  } catch {
    return { names: [], emails: [], phones: [], addresses: [] }
  }
}
```

## Anonymization Before Cloud Processing

When you need cloud model quality but have PII:

```ts
async function anonymizeAndProcess(text: string, task: string): Promise<string> {
  // Step 1: Extract PII locally
  const pii = await extractPIILocally(text)

  // Step 2: Replace PII with tokens
  const tokenMap: Record<string, string> = {}
  let anonymized = text

  pii.names.forEach((name, i) => {
    const token = `[PERSON_${i + 1}]`
    tokenMap[token] = name
    anonymized = anonymized.replace(new RegExp(name, 'g'), token)
  })

  pii.emails.forEach((email, i) => {
    const token = `[EMAIL_${i + 1}]`
    tokenMap[token] = email
    anonymized = anonymized.replace(new RegExp(email, 'g'), token)
  })

  // Step 3: Process anonymized text with cloud model
  const result = await callCloudModel({ content: anonymized, task })

  // Step 4: Re-inject PII into result (if present in output)
  let deanonymized = result
  for (const [token, original] of Object.entries(tokenMap)) {
    deanonymized = deanonymized.replace(new RegExp(token.replace('[', '\\[').replace(']', '\\]'), 'g'), original)
  }

  return deanonymized
}
```

Anonymize before sending to cloud, re-inject tokens after. This enables cloud model quality without exposing PII.

## Medical Record Summarization (Local Only)

```ts
// Always local for medical content
async function summarizeMedicalRecord(record: string): Promise<string> {
  const prompt = `Summarize this medical record for a physician:

${record}

Provide: Chief complaint, key findings, medications, follow-up plan.
Be concise. Preserve medical terminology.`

  return callOllama({
    model: 'medllama2:7b',  // Medical fine-tuned model if available
    // Fall back to: 'llama3.2:8b'
    prompt,
    options: {
      temperature: 0.1,  // Low temperature for factual accuracy
      num_predict: 512,
    },
  })
}
```

## Audit Trail for Privacy Routing

Log routing decisions for compliance audits:

```ts
await supabase.from('processing_log').insert({
  document_id: doc.id,
  task_type: task,
  model_used: requiresLocalModel(content) ? 'local:llama3.2' : 'cloud:claude-sonnet',
  privacy_routed: requiresLocalModel(content),
  pii_detected: pii ? pii : null,
  processed_at: new Date().toISOString(),
})
```

## Data Minimization Before Processing

Don't send more than needed:

```ts
// For a task that only needs the subject line — don't send the full email
async function classifyEmailUrgency(email: { subject: string; body: string }) {
  // Only send subject for classification
  return callCloudModel({
    content: email.subject,  // Not email.body (may contain PII)
    task: 'classify urgency as: urgent/normal/low',
  })
}
```

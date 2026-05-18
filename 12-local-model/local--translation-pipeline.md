# Local Models: Translation Pipeline

## Overview

Translate content offline using local models. Use cases: bulk content translation, privacy-sensitive documents, cost-sensitive high-volume translation. Local model quality is below Google Translate/DeepL for complex text but acceptable for structured content (UI strings, product descriptions, short articles). For high-quality translation at scale, use a managed API.

## Quality Guidance

| Content type | Local model | Managed API |
|---|---|---|
| UI strings | ✓ Acceptable | Unnecessary |
| Product descriptions | ✓ Acceptable | Preferred |
| Legal/medical documents | ✗ Too risky | Required |
| Literary/nuanced content | ✗ Loses nuance | Required |
| High volume (>1M words) | ✓ Cost effective | Too expensive |

## Single Translation

```ts
const TRANSLATE_PROMPT = `Translate the following text from {source_lang} to {target_lang}.

Requirements:
- Preserve formatting (line breaks, markdown, HTML tags)
- Keep proper nouns, brand names, and technical terms as-is unless they have accepted translations
- Do not add explanations or notes
- Return ONLY the translated text

Text to translate:
{text}

Translation:`

async function translate(
  text: string,
  targetLang: string,
  sourceLang = 'English',
): Promise<string> {
  const prompt = TRANSLATE_PROMPT
    .replace('{source_lang}', sourceLang)
    .replace('{target_lang}', targetLang)
    .replace('{text}', text)

  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1',
      prompt,
      stream: false,
      options: { temperature: 0.1 },
    }),
  })

  const data = await response.json()
  return data.response.trim()
}
```

## Batch Translation

```ts
interface TranslationJob {
  key: string     // Identifies the string (e.g., 'nav.home', 'cta.signup')
  source: string  // English text
}

interface TranslationResult {
  key: string
  translation: string
  error?: string
}

async function translateBatch(
  items: TranslationJob[],
  targetLang: string,
  concurrency = 3,
): Promise<TranslationResult[]> {
  const results: TranslationResult[] = []

  for (let i = 0; i < items.length; i += concurrency) {
    const batch = items.slice(i, i + concurrency)

    const batchResults = await Promise.allSettled(
      batch.map(async item => ({
        key: item.key,
        translation: await translate(item.source, targetLang),
      }))
    )

    for (const [j, result] of batchResults.entries()) {
      if (result.status === 'fulfilled') {
        results.push(result.value)
      } else {
        results.push({
          key: batch[j].key,
          translation: batch[j].source,  // Fallback to English
          error: String(result.reason),
        })
      }
    }

    console.log(`Translated ${Math.min(i + concurrency, items.length)}/${items.length}`)
  }

  return results
}
```

## JSON i18n File Translation

```ts
async function translateI18nFile(
  sourceMessages: Record<string, string>,
  targetLang: string,
): Promise<Record<string, string>> {
  const jobs: TranslationJob[] = Object.entries(sourceMessages).map(([key, source]) => ({ key, source }))
  const results = await translateBatch(jobs, targetLang)

  return Object.fromEntries(results.map(r => [r.key, r.translation]))
}

// Usage: translate English i18n file to Spanish
const en = JSON.parse(await readFile('./messages/en.json', 'utf8'))
const es = await translateI18nFile(en, 'Spanish')
await writeFile('./messages/es.json', JSON.stringify(es, null, 2))
```

## Quality Validation

After translation, validate key properties:

```ts
function validateTranslation(source: string, translation: string): string[] {
  const issues: string[] = []

  // Check for placeholder preservation
  const placeholders = source.match(/\{[^}]+\}/g) ?? []
  for (const ph of placeholders) {
    if (!translation.includes(ph)) {
      issues.push(`Missing placeholder: ${ph}`)
    }
  }

  // Check HTML tags preserved
  const htmlTags = source.match(/<[^>]+>/g) ?? []
  for (const tag of htmlTags) {
    if (!translation.includes(tag)) {
      issues.push(`Missing HTML tag: ${tag}`)
    }
  }

  // Check not untranslated (same as source for non-English)
  if (translation === source && source.length > 20) {
    issues.push('Translation matches source — may not have translated')
  }

  return issues
}
```

## Recommended Models for Translation

- `llama3.1:8b` — Supports many European languages well
- `command-r` — Strong multilingual support
- `aya-expanse` — Purpose-built for multilingual tasks

For Japanese, Chinese, Korean, Arabic — larger models (70B) perform significantly better.

## Key Rules

- `temperature: 0.1` not `0` for translation — slight creativity allows for natural phrasing.
- Validate placeholder `{name}` and `{count}` preservation — model frequently drops or translates them.
- Keep source text under ~2000 words per call — longer passages lose translation quality.
- For critical content, validate with a second model or back-translate (translate back to source and compare).

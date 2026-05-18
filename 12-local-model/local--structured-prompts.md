# Local Model Structured Prompts

## The Problem with Unstructured Prompts

Local models are sensitive to prompt format. The same instruction phrased differently produces wildly different quality and reliability.

Unstructured prompt → variable output format → harder to parse → more failures in batch jobs.

Structured prompts → consistent output format → easier to parse → fewer failures.

## The XML-Delimited Prompt Pattern

```typescript
// UNSTRUCTURED (fragile with local models):
const prompt = `Write a blog post about oil changes for an auto repair shop in Twin Falls, Idaho.`

// STRUCTURED (more reliable):
const prompt = `<task>
Write a blog post section

<context>
Business: Jr.'s Auto Repair, Twin Falls, Idaho
Phone: (208) 595-2101
Audience: Car owners in Magic Valley
</context>

<goal>
Write the "Signs You Need an Oil Change" section (3-5 bullet points).
Each point should be concrete and actionable.
</goal>

<constraints>
- Maximum 200 words
- Include Twin Falls or Magic Valley
- No prices
- No generic phrases like "as soon as possible"
</constraints>

<output_format>
Return ONLY a JSON object: {"bullets": ["point 1", "point 2", ...]}
No preamble, no explanation.
</output_format>
</task>`
```

## Section-by-Section Article Generation

Local models handle short, focused tasks much better than "write a complete article." Break article generation into sections:

```typescript
interface ArticleSection {
  section: string
  wordTarget: number
  prompt: string
}

const sections: ArticleSection[] = [
  {
    section: 'intro',
    wordTarget: 80,
    prompt: `Write a 2-sentence intro for a blog post about brake inspection. Mention Twin Falls, Idaho. Speak to car owners who hear grinding noises.`,
  },
  {
    section: 'signs_you_need_brakes',
    wordTarget: 150,
    prompt: `List 5 signs that a car needs brake inspection. Each sign should be concrete and observable by a driver. Format as bullet points.`,
  },
  {
    section: 'our_process',
    wordTarget: 100,
    prompt: `Describe what Jr.'s Auto Repair does during a brake inspection. 3-4 sentences. Professional but approachable tone.`,
  },
  {
    section: 'call_to_action',
    wordTarget: 50,
    prompt: `Write a 2-sentence CTA for brake service at Jr.'s Auto Repair. Include (208) 595-2101. Mention Twin Falls.`,
  },
]

async function generateArticle(): Promise<string> {
  const parts: string[] = []
  
  for (const section of sections) {
    const response = await ollamaGenerate(section.prompt, 'llama3.1:8b')
    const text = extractText(response, { minLength: 50 })
    if (text) parts.push(text)
    await new Promise(r => setTimeout(r, 500))
  }
  
  return parts.join('\n\n')
}
```

## The Constraint List Pattern

Local models respect explicit lists of constraints better than prose instructions:

```typescript
const constraints = [
  'Maximum 150 words',
  'Include phone number (208) 595-2101',
  'Mention Twin Falls, Idaho',
  'No prices or cost estimates',
  'Professional but conversational tone',
  'No exclamation marks',
].map(c => `- ${c}`).join('\n')

const prompt = `${instruction}\n\nConstraints:\n${constraints}\n\nOutput:`
```

The trailing `\nOutput:` acts as a completion starter — many models will continue the output rather than adding preamble.

## Persona Injection

Local models benefit from role-priming at the start of the prompt:

```typescript
const systemPrompt = `You are a copywriter for Jr.'s Auto Repair, an auto shop in Twin Falls, Idaho that has served the Magic Valley community for 13 years. You write clear, honest content that helps car owners understand their vehicles without being condescending or overly technical.`

const prompt = `${systemPrompt}

Task: ${taskDescription}`
```

## Few-Shot Examples

For consistent format, include one or two examples of good output:

```typescript
const prompt = `Write a service description for our oil change service.

Example output format:
{"title": "Oil Change Service", "tagline": "Quick, clean, done right.", "bullets": ["Full synthetic or conventional oil", "New filter installed", "30-point inspection included"]}

Now write for our brake service:
{"title": "`
// Many models will continue completing the JSON from the partial example
```

The partial completion trick: start the output format and let the model complete it.

## Prompt Length Guide for Local Models

| Model | Max reliable prompt | Quality starts degrading |
|---|---|---|
| llama3.2:3b | 1000 tokens | 500 tokens |
| llama3.1:8b | 3000 tokens | 2000 tokens |
| qwen2.5-coder:7b | 4000 tokens | 3000 tokens |
| codellama:13b | 6000 tokens | 4000 tokens |

For batch jobs: keep prompts under these thresholds to maintain consistent output quality across all tasks.

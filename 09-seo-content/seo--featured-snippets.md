# Featured Snippets and Answer Engine Optimization

## What Featured Snippets Are

Featured snippets appear above organic results in a box. For local business sites, they're achievable for "how to" and "what is" queries related to your services.

Types:
1. **Paragraph** — answers "what is" and "how does" questions
2. **List** — answers "steps", "ways", or "types" questions  
3. **Table** — answers comparison and spec questions

## Paragraph Snippet Formula

Answer the question directly in the first sentence after the `<h2>` heading, then elaborate:

```html
<h2>How often should you change your oil?</h2>
<p>
  Most vehicles need an oil change every 5,000 to 7,500 miles, or every 6 months, 
  whichever comes first. However, older vehicles or those driven in severe conditions 
  (frequent short trips, extreme temperatures, towing) may need oil changes every 
  3,000 miles.
</p>
```

The first sentence is the snippet candidate. It:
- Directly answers the question (not "it depends" as the opener)
- Contains the key numbers (5,000–7,500)
- Is under 50 words

## List Snippet Formula

For "how to" and "signs of" content:

```html
<h2>Signs you need new brakes</h2>
<ul>
  <li>Squealing or grinding noise when braking</li>
  <li>Brake pedal feels spongy or goes to the floor</li>
  <li>Vehicle pulls to one side when braking</li>
  <li>Vibration in steering wheel or brake pedal</li>
  <li>Warning light on dashboard (most vehicles 2010+)</li>
</ul>
```

The `<ul>` immediately follows the heading with no paragraph in between. Google extracts the list as the snippet.

## Table Snippet Formula

```html
<h2>Oil change intervals by vehicle type</h2>
<table>
  <thead>
    <tr>
      <th>Vehicle Type</th>
      <th>Interval (miles)</th>
      <th>Interval (time)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Modern gasoline (2010+)</td>
      <td>5,000–7,500</td>
      <td>Every 6 months</td>
    </tr>
    <tr>
      <td>Older vehicles (pre-2010)</td>
      <td>3,000–5,000</td>
      <td>Every 3 months</td>
    </tr>
    <tr>
      <td>Diesel engines</td>
      <td>5,000–8,000</td>
      <td>Every 6 months</td>
    </tr>
  </tbody>
</table>
```

## Target Questions for JRS Auto Repair

High-value snippet opportunities for Twin Falls / Magic Valley queries:

**High intent:**
- "how much does a brake job cost in twin falls"
- "how long does an oil change take"
- "can i drive with check engine light on"

**Informational (builds E-E-A-T):**
- "what does a transmission service include"
- "how long do brake pads last"
- "what causes engine to overheat"

## Page Structure for Multiple Snippets

Structure articles to target multiple questions in one page:

```html
<h1>Complete Guide to Brake Maintenance</h1>

<h2>How do I know if my brakes need replacing?</h2>
<!-- paragraph or list answer here -->

<h2>How often should brakes be inspected?</h2>
<!-- direct answer in first sentence -->

<h2>How much does a brake job cost in Twin Falls?</h2>
<!-- direct cost range answer -->

<h2>What is included in a brake service?</h2>
<!-- list of included items -->
```

Each H2 is a potential featured snippet, and the article can appear for multiple queries.

## AEO (Answer Engine Optimization) for AI Search

AI search engines (ChatGPT, Perplexity, Google AI Overviews) pull from the same signals but prefer:
- Schema.org FAQPage markup for Q&A content
- Clear question-answer format
- Specific numbers and facts (not vague generalizations)
- Source citations for factual claims

```typescript
// FAQ schema for AEO:
const faqSchema = {
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "How often should I change my oil in Twin Falls, Idaho?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Most vehicles in Twin Falls need an oil change every 5,000–7,500 miles or every 6 months. The cold Idaho winters and dusty summer roads mean more frequent checks are wise."
      }
    }
  ]
}
```

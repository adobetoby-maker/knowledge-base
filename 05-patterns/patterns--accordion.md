# Pattern: Accordion (Collapsible Sections)

## What This Solves

Collapsible sections appear in FAQs, settings panels, and content that needs progressive disclosure. Use shadcn/ui Accordion — it handles keyboard navigation, ARIA attributes, and animation. Only build a custom version for non-standard layouts.

## Standard Accordion (shadcn/ui)

```tsx
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion'

// Single: only one item open at a time
<Accordion type="single" collapsible>
  <AccordionItem value="item-1">
    <AccordionTrigger>What payment methods do you accept?</AccordionTrigger>
    <AccordionContent>
      We accept Visa, Mastercard, and bank transfers. Invoice payment terms are Net 30.
    </AccordionContent>
  </AccordionItem>
  <AccordionItem value="item-2">
    <AccordionTrigger>How long does a repair take?</AccordionTrigger>
    <AccordionContent>
      Most repairs take 1–3 business days. Complex engine work may take 5–7 days.
    </AccordionContent>
  </AccordionItem>
</Accordion>

// Multiple: any number of items can be open simultaneously
<Accordion type="multiple" defaultValue={['item-1']}>
  ...
</Accordion>
```

## From Data Array (FAQ Pattern)

```tsx
interface FaqItem {
  question: string
  answer: string
}

const FAQ_ITEMS: FaqItem[] = [
  { question: 'Do you offer warranties?', answer: 'Yes, 12 months on parts and labor.' },
  { question: 'Do you accept walk-ins?', answer: 'Walk-ins welcome Monday–Saturday 9AM–5PM.' },
]

export function FaqSection() {
  return (
    <section>
      <h2 className="text-2xl font-semibold mb-6">Frequently Asked Questions</h2>
      <Accordion type="single" collapsible className="w-full">
        {FAQ_ITEMS.map((item, i) => (
          <AccordionItem key={i} value={`faq-${i}`}>
            <AccordionTrigger className="text-left">{item.question}</AccordionTrigger>
            <AccordionContent>
              <p className="text-muted-foreground">{item.answer}</p>
            </AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </section>
  )
}
```

## FAQ Schema Markup

Always add schema markup to FAQ sections for Google's rich results. Note: the JSON-LD content below is a static string literal from compile-time data — never inject user-submitted content into JSON-LD without sanitization:

```tsx
export function FaqWithSchema({ items }: { items: FaqItem[] }) {
  // items comes from static lib/faqs.ts data — not user input
  const schema = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: items.map(item => ({
      '@type': 'Question',
      name: item.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: item.answer,
      },
    })),
  })

  return (
    <>
      {/* Safe: schema is built from trusted static data, not user input */}
      <script type="application/ld+json" suppressHydrationWarning>
        {schema}
      </script>
      <Accordion type="single" collapsible>
        {items.map((item, i) => (
          <AccordionItem key={i} value={`q-${i}`}>
            <AccordionTrigger>{item.question}</AccordionTrigger>
            <AccordionContent>{item.answer}</AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </>
  )
}
```

## Controlled Accordion (Programmatic Open/Close)

```tsx
const [openItems, setOpenItems] = useState<string[]>([])

const expandAll = () => setOpenItems(items.map((_, i) => `item-${i}`))
const collapseAll = () => setOpenItems([])

<Accordion type="multiple" value={openItems} onValueChange={setOpenItems}>
  ...
</Accordion>
```

## Settings Panel Accordion

For admin settings pages, each section is a collapsible panel. Persist the open state to localStorage:

```tsx
const [open, setOpen] = useLocalStorage<string[]>('settings-accordion', ['general'])

<Accordion type="multiple" value={open} onValueChange={setOpen}>
  <AccordionItem value="general">
    <AccordionTrigger>General Settings</AccordionTrigger>
    <AccordionContent>...</AccordionContent>
  </AccordionItem>
  <AccordionItem value="notifications">
    <AccordionTrigger>Notification Preferences</AccordionTrigger>
    <AccordionContent>...</AccordionContent>
  </AccordionItem>
</Accordion>
```

## Custom Animation Speed

```css
/* Customize the height animation duration */
[data-radix-accordion-content] {
  animation-duration: 200ms; /* default is 300ms */
}
```

Or override via className on AccordionContent with Tailwind duration utilities.

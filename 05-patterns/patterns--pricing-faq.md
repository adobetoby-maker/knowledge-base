# Pattern: Pricing Page FAQ Section

## Overview
The FAQ section on a pricing page exists to overcome the final objections that prevent conversion. Users who scroll past the pricing table and read the FAQ are actively evaluating — they have specific concerns (billing surprises, lock-in, refunds) that the table format doesn't address. Each question should have a CTA where relevant, and tracking which questions get expanded reveals which objections are most common.

## Implementation

### FAQ data structure

```ts
interface FaqItem {
  id: string
  question: string
  answer: React.ReactNode   // Can include links and CTAs
  category?: 'billing' | 'plans' | 'trial' | 'enterprise'
}

const PRICING_FAQ: FaqItem[] = [
  {
    id: 'how-billing-works',
    question: 'How does billing work?',
    category: 'billing',
    answer: (
      <>
        You&apos;re billed monthly or annually depending on your plan. Monthly billing
        charges on the same date each month. Annual billing charges once upfront and
        saves 20%. Usage-based charges (overages) are billed at the end of each billing period.
        <a href="/docs/billing" className="ml-1 text-blue-600 underline">View billing docs</a>
      </>
    ),
  },
  {
    id: 'refund-policy',
    question: 'What is your refund policy?',
    category: 'billing',
    answer: (
      <>
        We offer a full refund within 14 days of your initial purchase if
        you&apos;re not satisfied — no questions asked. After 14 days, refunds
        are considered on a case-by-case basis.{' '}
        <a href="mailto:billing@example.com" className="text-blue-600 underline">
          Contact billing support
        </a>
      </>
    ),
  },
  {
    id: 'upgrade-downgrade',
    question: 'Can I upgrade or downgrade at any time?',
    category: 'plans',
    answer: (
      <>
        Yes. Upgrades take effect immediately and are prorated. Downgrades take
        effect at the end of your current billing period — you keep your current
        plan until then.
      </>
    ),
  },
  {
    id: 'cancel-anytime',
    question: 'Can I cancel my subscription?',
    category: 'plans',
    answer: 'You can cancel at any time from your account settings. You retain access until the end of your paid period. We do not offer partial-month refunds on cancellation.',
  },
  {
    id: 'enterprise-pricing',
    question: 'Do you offer enterprise pricing?',
    category: 'enterprise',
    answer: (
      <>
        Yes — enterprise plans include custom limits, SLA guarantees, SSO, and
        a dedicated account manager.{' '}
        <a href="/contact/enterprise" className="text-blue-600 underline font-medium">
          Talk to our sales team →
        </a>
      </>
    ),
  },
  {
    id: 'free-trial',
    question: 'Is there a free trial?',
    category: 'trial',
    answer: (
      <>
        All paid plans include a 14-day free trial. No credit card required to start.{' '}
        <a href="/signup" className="text-blue-600 underline font-medium">
          Start your free trial →
        </a>
      </>
    ),
  },
]
```

### Accordion FAQ component

```tsx
function PricingFaq() {
  // First item open by default
  const [openId, setOpenId] = useState<string | null>(PRICING_FAQ[0]?.id ?? null)

  function toggle(id: string) {
    const next = openId === id ? null : id
    setOpenId(next)

    // Track which questions get expanded (conversion analytics)
    if (next === id) {
      analytics.track('pricing_faq_expanded', { question_id: id })
    }
  }

  return (
    <section className="max-w-2xl mx-auto py-16 px-4">
      <div className="text-center mb-10">
        <h2 className="text-3xl font-bold">Frequently asked questions</h2>
        <p className="text-gray-500 mt-2">
          Still have questions?{' '}
          <a href="/contact" className="text-blue-600 underline">Talk to us</a>
        </p>
      </div>

      <div className="divide-y border rounded-xl overflow-hidden">
        {PRICING_FAQ.map((item) => (
          <FaqAccordionItem
            key={item.id}
            item={item}
            isOpen={openId === item.id}
            onToggle={() => toggle(item.id)}
          />
        ))}
      </div>
    </section>
  )
}
```

### Accordion item

```tsx
function FaqAccordionItem({
  item,
  isOpen,
  onToggle,
}: {
  item: FaqItem
  isOpen: boolean
  onToggle: () => void
}) {
  const answerId = `faq-answer-${item.id}`

  return (
    <div>
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={isOpen}
        aria-controls={answerId}
        className="w-full flex items-center justify-between px-6 py-4 text-left 
                   hover:bg-gray-50 transition-colors"
      >
        <span className="font-medium text-gray-900">{item.question}</span>
        <ChevronDown
          size={18}
          className={`shrink-0 text-gray-400 transition-transform duration-200 
                      ${isOpen ? 'rotate-180' : ''}`}
        />
      </button>

      <div
        id={answerId}
        role="region"
        hidden={!isOpen}
        className={`px-6 pb-5 text-gray-600 text-sm leading-relaxed
                    ${isOpen ? 'block' : 'hidden'}`}
      >
        {item.answer}
      </div>
    </div>
  )
}
```

### Animated version with height transition

```tsx
function FaqAccordionItemAnimated({ item, isOpen, onToggle }: Props) {
  const contentRef = useRef<HTMLDivElement>(null)

  return (
    <div>
      <button
        onClick={onToggle}
        aria-expanded={isOpen}
        className="w-full flex items-center justify-between px-6 py-4 text-left hover:bg-gray-50"
      >
        <span className="font-medium">{item.question}</span>
        <ChevronDown size={18} className={`transition-transform ${isOpen ? 'rotate-180' : ''}`} />
      </button>

      <div
        ref={contentRef}
        style={{
          height: isOpen ? contentRef.current?.scrollHeight : 0,
          overflow: 'hidden',
          transition: 'height 200ms ease',
        }}
      >
        <div className="px-6 pb-5 text-sm text-gray-600 leading-relaxed">
          {item.answer}
        </div>
      </div>
    </div>
  )
}
```

## Key Rules
- Open the first item by default — reduces the cognitive effort of "nothing looks clickable"
- Track which questions are expanded — high expansion rates indicate content gaps in the pricing table
- Enterprise pricing question always needs a direct CTA ("Talk to sales") — don't just say "contact us"
- Refund policy answer must be complete and specific — vague answers ("on a case-by-case basis") reduce trust
- Upgrade/downgrade behavior is one of the top FAQ questions — answer proration policy explicitly
- `aria-expanded` + `aria-controls` required for accessibility
- CTA links within answers should be visually distinct (blue, underline) — they're action items, not decorative links
- Keep answers concise — if an answer needs more than 3 sentences, link to documentation instead

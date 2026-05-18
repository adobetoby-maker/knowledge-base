# Principle: Progressive Disclosure

## The Problem

Showing all features and options at once overwhelms users and makes simple tasks harder. A form with 20 fields is intimidating even if 15 of them are optional. A settings page with every configuration option visible creates decision paralysis. The cognitive load of ignoring irrelevant options is real.

## The Principle

Show only what's needed for the current task. Reveal additional complexity only when the user requests it or has established enough context to need it.

## Level 1: Show Less by Default

```tsx
// BAD: all fields visible immediately
<form>
  <input name="name" placeholder="Company name" />
  <input name="email" />
  <input name="phone" />
  <input name="address1" />
  <input name="address2" />
  <input name="city" />
  <input name="state" />
  <input name="zip" />
  <input name="country" />
  <input name="tax_id" />
  <input name="notes" />
</form>

// GOOD: show required fields, offer optional expansion
<form>
  <input name="name" placeholder="Company name" required />
  <input name="email" required />
  <button type="button" onClick={() => setShowMore(true)}>
    + Add address, phone, and notes
  </button>
  {showMore && (
    <>
      <input name="phone" />
      <AddressFields />
      <textarea name="notes" />
    </>
  )}
</form>
```

## Level 2: Progressive Configuration

Settings pages follow a hierarchy of visibility:
- **Always visible**: core settings the user will need on first use
- **Advanced section** (collapsed): power-user options, defaults are fine for most
- **Danger zone** (separate section, visually distinct): destructive operations

```tsx
<div className="space-y-8">
  {/* Core settings — always visible */}
  <section>
    <h2 className="text-lg font-semibold">General</h2>
    <GeneralSettings />
  </section>

  {/* Advanced — collapsed by default */}
  <Accordion type="single" collapsible>
    <AccordionItem value="advanced">
      <AccordionTrigger>Advanced Settings</AccordionTrigger>
      <AccordionContent>
        <AdvancedSettings />
      </AccordionContent>
    </AccordionItem>
  </Accordion>

  {/* Danger zone — visually separated */}
  <section className="border border-destructive/50 rounded-lg p-6">
    <h2 className="text-lg font-semibold text-destructive">Danger Zone</h2>
    <DangerSettings />
  </section>
</div>
```

## Level 3: Context-Dependent Revelation

Reveal options only when they become relevant:

```tsx
function PaymentForm() {
  const [method, setMethod] = useState<'card' | 'bank'>('card')

  return (
    <>
      <RadioGroup value={method} onValueChange={v => setMethod(v as 'card' | 'bank')}>
        <RadioGroupItem value="card" label="Credit/Debit Card" />
        <RadioGroupItem value="bank" label="Bank Transfer" />
      </RadioGroup>

      {/* Card-specific fields — only shown when method is 'card' */}
      {method === 'card' && <CardFields />}

      {/* Bank-specific fields — only shown when method is 'bank' */}
      {method === 'bank' && <BankFields />}
    </>
  )
}
```

## Level 4: Step-by-Step Wizards

Multi-step forms apply progressive disclosure across time:
- Each step shows only what's needed for that decision
- Previous steps are summarized, not re-shown
- The user never sees all fields simultaneously

Appropriate when:
- 5+ fields with dependencies between them
- Users need to take a decision at one step before the next step makes sense
- Different users will follow different paths

## Information Hierarchy in Content

Apply to text as well as UI:
- Lead with the answer, then provide supporting detail
- Put the most common case first, edge cases last
- Use expandable sections for technical details non-experts won't need

```tsx
function ApiDocsSection({ endpoint }: { endpoint: ApiEndpoint }) {
  const [showParams, setShowParams] = useState(false)

  return (
    <div>
      <p className="text-muted-foreground">{endpoint.description}</p>
      <CodeBlock code={endpoint.example} />

      {/* Show parameters only when user asks */}
      <button onClick={() => setShowParams(v => !v)} className="text-sm text-primary">
        {showParams ? 'Hide parameters' : `Show ${endpoint.params.length} parameters`}
      </button>
      {showParams && <ParamTable params={endpoint.params} />}
    </div>
  )
}
```

## When Not to Use Progressive Disclosure

Don't hide information when:
- The hidden information is needed to complete the task users came to do (hiding it just adds a step)
- Users are power users who need all options immediately (admin dashboards, developer tools)
- The disclosure step itself adds confusion (user doesn't know to look for the "show more" trigger)
- Sequential disclosure obscures the full scope of commitment (e.g., burying a cancellation-is-hard policy)

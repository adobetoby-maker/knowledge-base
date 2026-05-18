# Skill: User Session Recording (Privacy-First)

## Overview
Session recordings reveal exactly where users struggle — rage clicks, scroll depth, form abandonment — without asking them. The privacy risk is real: recordings can capture passwords, PII, and payment data. A privacy-first setup masks sensitive fields by default and collects recordings only with valid legal basis.

## Implementation / Key Points

### Masking Sensitive Fields
```html
<!-- Declarative masking — handled by the recording SDK -->
<input type="password" data-recording-ignore />
<input type="text" name="ssn" data-recording-ignore />
<div class="credit-card-frame" data-recording-mask />   <!-- blur, not ignore -->

<!-- Never record iframes with payment providers — iframe content is not under your control -->
<iframe src="https://js.stripe.com/v3/..." />  <!-- Stripe.js is fine, it records nothing -->
```

PostHog: set `mask_all_inputs: true` and whitelist safe fields.
Hotjar: enable "Suppress text" on fields with class `hj-suppress`.

### Framework-Level Masking
```ts
// PostHog initialization
posthog.init(POSTHOG_KEY, {
  session_recording: {
    maskAllInputs: true,                    // masks every <input> by default
    maskInputOptions: { password: true },   // extra safety for passwords
    maskTextSelector: '[data-private]',     // custom selector
    blockSelector: '[data-recording-block]',// removes element entirely from DOM snapshot
  }
});
```

### Consent Gate (GDPR)
```ts
// Only start recording after explicit consent (EU users)
function onConsentAccepted(categories: string[]) {
  if (categories.includes('analytics')) {
    posthog.opt_in_capturing();
    posthog.startSessionRecording();
  }
}

// Legitimate interest basis (non-EU, B2B SaaS): document in privacy policy.
// Still honor opt-out:
function onUserOptOut() {
  posthog.opt_out_capturing();
  posthog.stopSessionRecording();
}
```

### Data Retention Policy
Configure 30-day automatic deletion in the vendor dashboard. Shorter is better for GDPR compliance. Export or archive any recordings needed for longer analysis before deletion.

### Hotjar Setup
```html
<!-- In <head> — will not record if user has opted out via consent banner -->
<script>
  (function(h,o,t,j,a,r){
    h.hj=h.hj||function(){(h.hj.q=h.hj.q||[]).push(arguments)};
    h._hjSettings={hjid: YOUR_HJID, hjsv: 6};
    // ...
  })(window,...);
</script>
```
In Hotjar dashboard: Settings → Site & Tracking Info → Suppress content on all pages containing: `/checkout`, `/payment`, `/account/security`.

### PostHog Recordings Setup
```ts
posthog.init(POSTHOG_KEY, {
  api_host: 'https://app.posthog.com',
  capture_pageview: true,
  session_recording: {
    maskAllInputs: true,
    recordCanvas: false,         // canvas elements (charts) usually not needed
    networkCapture: { recordHeaders: false, recordBody: false },  // never capture request bodies
  }
});
```

## Key Rules
- Passwords and payment fields must NEVER appear in recordings — use `data-recording-ignore` or SDK-level masking.
- Opt-in consent required for EU/UK users; document legitimate interest basis for non-EU B2B.
- Retention max 30 days; shorter retention = less GDPR exposure.
- Never record inside cross-origin iframes (payment provider frames, auth provider iframes).
- Mask before record — it's not possible to un-record data that was captured.
- Provide a visible opt-out mechanism accessible from the privacy policy.
- Test masking in staging: watch recordings of your own checkout flow before enabling in production.

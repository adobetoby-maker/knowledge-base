# Supabase Edge Functions

**When:** Need server-side logic that runs close to users, processes webhooks, sends emails/SMS, or integrates with external services. Not a fit for full Next.js server-side work.
**Rule:** Edge Functions are Deno — not Node.js. Different imports, different runtime. Best for: event-triggered work, third-party integrations, background jobs.

## When to Use Edge Functions vs API Routes
```
Supabase Edge Function:
  ✓ Triggered by database events (webhooks)
  ✓ Processing Stripe/Twilio/SendGrid webhooks
  ✓ Sending email/SMS after DB insert
  ✓ Background jobs triggered from Supabase
  ✓ Need to run close to DB (same region)
  
Next.js API Route:
  ✓ Frontend-driven requests (user clicks something)
  ✓ Complex request/response with streaming
  ✓ Already have the project running in Next.js
  ✓ Need session/cookie context from the user
```

## Function Shape (Deno)
```typescript
// supabase/functions/send-welcome-email/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  
  const { userId } = await req.json()
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  
  const { data: user } = await supabase
    .from('profiles')
    .select('email, name')
    .eq('id', userId)
    .single()
  
  // Send email via Resend, SendGrid, etc.
  await sendWelcomeEmail(user.email, user.name)
  
  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
```

## Deno Import Differences
```typescript
// Node.js (DON'T use)
import Anthropic from '@anthropic-ai/sdk'
import fetch from 'node-fetch'

// Deno (DO use)
import Anthropic from 'https://esm.sh/@anthropic-ai/sdk'
// fetch is built-in in Deno — no import needed
```

## Database Webhook Trigger
In Supabase dashboard → Database → Webhooks:
1. Select table and event (INSERT / UPDATE / DELETE)
2. Set URL to your function: `https://[project].supabase.co/functions/v1/your-function`
3. Set Authorization: `Bearer [SERVICE_ROLE_KEY]`

The webhook payload includes the row data.

## Local Development
```bash
supabase functions serve your-function-name
# Runs on http://localhost:54321/functions/v1/your-function-name
```

## Deploy
```bash
supabase functions deploy your-function-name
```
Or use MCP: `mcp__plugin_supabase_supabase__deploy_edge_function`

## Env Vars in Edge Functions
```
SUPABASE_URL        — auto-injected, no need to set
SUPABASE_SERVICE_ROLE_KEY — auto-injected
SUPABASE_ANON_KEY   — auto-injected
Custom vars         — set in Supabase dashboard → Edge Functions → Manage secrets
```

## Calling a Function from Client
```typescript
const { data, error } = await supabase.functions.invoke('send-welcome-email', {
  body: { userId: user.id }
})
```

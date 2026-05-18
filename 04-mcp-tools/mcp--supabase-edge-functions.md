# MCP: Supabase Edge Functions

## Tool Reference

| Tool | Purpose |
|------|---------|
| `mcp__plugin_supabase_supabase__deploy_edge_function` | Deploy a Deno edge function |
| `mcp__plugin_supabase_supabase__get_edge_function` | Get function details and URL |
| `mcp__plugin_supabase_supabase__list_edge_functions` | List all deployed functions |
| `mcp__plugin_supabase_supabase__get_logs` | Read function invocation logs |

## Listing Edge Functions

```
mcp__plugin_supabase_supabase__list_edge_functions({
  projectId: "your-project-id"
})
→ Returns: function names, URLs, created_at, status
```

## Getting a Function's URL

```
mcp__plugin_supabase_supabase__get_edge_function({
  projectId: "your-project-id",
  functionName: "send-invoice"
})
→ Returns: url, verify_jwt, created_at
```

The function URL format:
```
https://<project-ref>.supabase.co/functions/v1/<function-name>
```

## Deploying a Function

```
mcp__plugin_supabase_supabase__deploy_edge_function({
  projectId: "your-project-id",
  name: "send-invoice",
  entrypointPath: "supabase/functions/send-invoice/index.ts"
})
```

The function code must be in your local filesystem at the specified path.

## Reading Logs

```
mcp__plugin_supabase_supabase__get_logs({
  projectId: "your-project-id",
  service: "edge-functions",
  limit: 50
})
→ Returns recent invocation logs with timestamps, status codes, and error messages
```

## When to Use Edge Functions vs Route Handlers

**Use Supabase Edge Functions when:**
- The function is triggered by a Supabase database event or webhook
- You need a Deno runtime (different from Node.js ecosystem)
- The function runs close to your database (same region)
- You need `supabaseClient` with auth context within the function

**Use Next.js Route Handlers when:**
- The API is consumed by your own frontend
- You need Node.js packages
- The logic belongs in the app layer, not the DB layer

## Edge Function Pattern (send-invoice)

```ts
// supabase/functions/send-invoice/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req: Request) => {
  const { invoice_id } = await req.json()

  // Auth: get user from JWT
  const authHeader = req.headers.get('Authorization')!
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error: authError } = await supabase.auth.getUser()
  if (authError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  // Fetch invoice (RLS ensures user can only access their own)
  const { data: invoice } = await supabase
    .from('invoices')
    .select('*')
    .eq('id', invoice_id)
    .single()

  if (!invoice) {
    return new Response(JSON.stringify({ error: 'Invoice not found' }), { status: 404 })
  }

  // Send email via Resend
  const emailRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('RESEND_API_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'invoices@yourdomain.com',
      to: invoice.client_email,
      subject: `Invoice #${invoice.number}`,
      html: buildInvoiceHtml(invoice),
    }),
  })

  if (!emailRes.ok) {
    return new Response(JSON.stringify({ error: 'Email failed' }), { status: 500 })
  }

  return new Response(JSON.stringify({ sent: true }), { status: 200 })
})
```

## Database Triggers → Edge Functions

Edge functions can be triggered by Postgres events via Supabase webhooks:

```sql
-- Trigger edge function on invoice status change
CREATE OR REPLACE FUNCTION notify_invoice_sent()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'sent' AND OLD.status != 'sent' THEN
    PERFORM net.http_post(
      url := current_setting('app.supabase_functions_url') || '/on-invoice-sent',
      body := json_build_object('invoice_id', NEW.id)::text,
      headers := json_build_object('Authorization', 'Bearer ' || current_setting('app.service_key'))
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER invoice_status_change
  AFTER UPDATE OF status ON invoices
  FOR EACH ROW EXECUTE FUNCTION notify_invoice_sent();
```

# QuickBooks Integration

## Where It's Used

`silver-creek-logistics` integrates with QuickBooks Online for accounting sync. Invoices created in the app can be synced to QuickBooks.

## OAuth Flow

QuickBooks uses OAuth 2.0. The integration requires:
1. User authorizes via QuickBooks OAuth URL
2. QuickBooks redirects back with `code` and `realmId`
3. Exchange code for access/refresh tokens
4. Store tokens in database
5. Refresh tokens automatically when they expire (1 hour TTL)

## Env Vars

```
QB_CLIENT_ID         # from QuickBooks Developer app
QB_CLIENT_SECRET     # from QuickBooks Developer app
QB_REDIRECT_URI      # must match exactly: https://yourdomain.com/api/qb/callback
QB_ENVIRONMENT       # 'sandbox' or 'production'
```

## OAuth URL Generation

```typescript
// app/api/qb/auth/route.ts
import OAuthClient from 'intuit-oauth'

const oauthClient = new OAuthClient({
  clientId: process.env.QB_CLIENT_ID!,
  clientSecret: process.env.QB_CLIENT_SECRET!,
  environment: process.env.QB_ENVIRONMENT as 'sandbox' | 'production',
  redirectUri: process.env.QB_REDIRECT_URI!,
})

export async function GET() {
  const authUri = oauthClient.authorizeUri({
    scope: [OAuthClient.scopes.Accounting],
    state: 'csrf-token-here',  // validate in callback
  })
  return NextResponse.redirect(authUri)
}
```

## OAuth Callback

```typescript
// app/api/qb/callback/route.ts
export async function GET(req: NextRequest) {
  const url = req.nextUrl.toString()
  
  try {
    const authResponse = await oauthClient.createToken(url)
    const tokenData = authResponse.getJson()
    
    // Store tokens in database
    const supabase = createAdminClient()
    await supabase.from('qb_tokens').upsert({
      realm_id: tokenData.realmId,
      access_token: tokenData.access_token,
      refresh_token: tokenData.refresh_token,
      expires_at: new Date(Date.now() + tokenData.expires_in * 1000).toISOString(),
    })
    
    return NextResponse.redirect('/admin/settings?qb=connected')
  } catch (error) {
    return NextResponse.redirect('/admin/settings?qb=error')
  }
}
```

## Creating an Invoice in QuickBooks

```typescript
// lib/quickbooks.ts
export async function syncInvoiceToQuickBooks(invoice: Invoice): Promise<void> {
  const tokens = await getQBTokens()
  if (!tokens) throw new Error('QuickBooks not connected')
  
  // Refresh token if expired
  if (new Date(tokens.expires_at) < new Date()) {
    await refreshQBToken(tokens.refresh_token)
  }
  
  const qbInvoice = {
    Line: invoice.line_items.map(item => ({
      Amount: item.amount,
      DetailType: 'SalesItemLineDetail',
      SalesItemLineDetail: {
        ItemRef: { value: '1', name: 'Services' },
        UnitPrice: item.unit_price,
        Qty: item.quantity,
      },
      Description: item.description,
    })),
    CustomerRef: { name: invoice.customer_name },
    DocNumber: invoice.number,
  }
  
  const response = await fetch(
    `https://quickbooks.api.intuit.com/v3/company/${tokens.realm_id}/invoice`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${tokens.access_token}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(qbInvoice),
    }
  )
  
  if (!response.ok) {
    const error = await response.json()
    throw new Error(`QuickBooks sync failed: ${JSON.stringify(error)}`)
  }
}
```

## Sandbox vs Production

QuickBooks requires switching environment explicitly:
- Sandbox: `https://sandbox-quickbooks.api.intuit.com/`
- Production: `https://quickbooks.api.intuit.com/`

Set `QB_ENVIRONMENT=sandbox` in development, `QB_ENVIRONMENT=production` in production.

The sandbox has test customers and accounts pre-loaded. Always test in sandbox first.

## Token Refresh Strategy

QuickBooks access tokens expire in 1 hour. Refresh tokens last 100 days. Auto-refresh before any API call:

```typescript
async function getValidAccessToken(): Promise<string> {
  const tokens = await getQBTokens()
  if (!tokens) throw new Error('QuickBooks not connected')
  
  const expiresAt = new Date(tokens.expires_at)
  const fiveMinutesFromNow = new Date(Date.now() + 5 * 60 * 1000)
  
  if (expiresAt <= fiveMinutesFromNow) {
    // Token is about to expire — refresh it
    return await refreshQBToken(tokens.refresh_token)
  }
  
  return tokens.access_token
}
```

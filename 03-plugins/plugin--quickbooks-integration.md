# QuickBooks Integration

## Stack Context

QuickBooks Online (QBO) integration is in `silver-creek-logistics`. It syncs invoices from the internal system to QuickBooks for accounting purposes.

## OAuth Flow

QuickBooks uses OAuth 2.0. Credentials stored in env vars:

```
QB_CLIENT_ID=...
QB_CLIENT_SECRET=...
QB_REDIRECT_URI=https://your-domain.com/api/auth/quickbooks/callback
QB_ENVIRONMENT=sandbox  # or 'production'
```

```bash
npm install intuit-oauth node-quickbooks
```

## OAuth Implementation

```typescript
// lib/quickbooks/oauth.ts
import OAuthClient from 'intuit-oauth'

let _oauthClient: OAuthClient | null = null

export function getOAuthClient(): OAuthClient {
  if (_oauthClient) return _oauthClient
  
  _oauthClient = new OAuthClient({
    clientId: process.env.QB_CLIENT_ID!,
    clientSecret: process.env.QB_CLIENT_SECRET!,
    environment: process.env.QB_ENVIRONMENT as 'sandbox' | 'production',
    redirectUri: process.env.QB_REDIRECT_URI!,
  })
  
  return _oauthClient
}
```

```typescript
// app/api/auth/quickbooks/route.ts
import { getOAuthClient } from '@/lib/quickbooks/oauth'

export async function GET() {
  const authUri = getOAuthClient().authorizeUri({
    scope: [OAuthClient.scopes.Accounting],
    state: crypto.randomUUID(),  // store this to verify callback
  })
  return Response.redirect(authUri)
}
```

```typescript
// app/api/auth/quickbooks/callback/route.ts
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const code = searchParams.get('code')
  const realmId = searchParams.get('realmId')  // QuickBooks company ID
  
  const tokenResponse = await getOAuthClient().createToken(request.url)
  const { access_token, refresh_token, expires_in } = tokenResponse.getJson()
  
  // Store tokens in DB:
  await saveQBTokens({ accessToken: access_token, refreshToken: refresh_token, realmId, expiresAt: new Date(Date.now() + expires_in * 1000).toISOString() })
  
  return Response.redirect('/admin/settings?qb=connected')
}
```

## Token Refresh

Access tokens expire in 1 hour. Refresh tokens last 101 days:

```typescript
// lib/quickbooks/tokens.ts
export async function getValidAccessToken(): Promise<{ accessToken: string; realmId: string }> {
  const tokens = await loadQBTokens()
  if (!tokens) throw new Error('QuickBooks not connected')
  
  const isExpired = new Date(tokens.expiresAt) < new Date(Date.now() + 5 * 60_000)  // 5 min buffer
  
  if (isExpired) {
    const client = getOAuthClient()
    client.setToken({ access_token: tokens.accessToken, refresh_token: tokens.refreshToken })
    
    const refreshed = await client.refresh()
    const { access_token, refresh_token, expires_in } = refreshed.getJson()
    
    await saveQBTokens({
      accessToken: access_token,
      refreshToken: refresh_token,
      realmId: tokens.realmId,
      expiresAt: new Date(Date.now() + expires_in * 1000).toISOString(),
    })
    
    return { accessToken: access_token, realmId: tokens.realmId }
  }
  
  return { accessToken: tokens.accessToken, realmId: tokens.realmId }
}
```

## Creating an Invoice in QBO

```typescript
import QuickBooks from 'node-quickbooks'

export async function createQBInvoice(invoice: Invoice): Promise<string> {
  const { accessToken, realmId } = await getValidAccessToken()
  
  const qbo = new QuickBooks(
    process.env.QB_CLIENT_ID,
    process.env.QB_CLIENT_SECRET,
    accessToken,
    false,  // no token secret (OAuth2)
    realmId,
    process.env.QB_ENVIRONMENT === 'sandbox',
    false,  // no debug
    null,   // minor version
    '2.0',  // OAuth version
    null
  )
  
  const qbInvoice = {
    Line: invoice.lineItems.map((item, i) => ({
      Id: String(i + 1),
      Amount: item.unitPriceCents / 100 * item.quantity,
      DetailType: 'SalesItemLineDetail',
      SalesItemLineDetail: {
        ItemRef: { value: '1', name: 'Services' },  // QBO item ID
        Qty: item.quantity,
        UnitPrice: item.unitPriceCents / 100,
      },
      Description: item.description,
    })),
    CustomerRef: { value: invoice.qbCustomerId },  // QBO customer ID
    DueDate: invoice.dueDate,
  }
  
  return new Promise((resolve, reject) => {
    qbo.createInvoice(qbInvoice, (err: Error, result: any) => {
      if (err) reject(err)
      else resolve(result.Id)  // QuickBooks invoice ID
    })
  })
}
```

## Sync Strategy

Sync QBO invoice IDs back to your DB for reconciliation:

```sql
ALTER TABLE invoices ADD COLUMN qb_invoice_id text;
```

After creating in QBO, store the QBO ID:
```typescript
await supabase.from('invoices').update({ qb_invoice_id: qbId }).eq('id', invoice.id)
```

This prevents duplicate creation if the sync runs again.

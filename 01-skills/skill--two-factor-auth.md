# Skill: Two-Factor Authentication (TOTP)

## What This Covers

Time-based One-Time Passwords (TOTP) using authenticator apps (Google Authenticator, Authy). Not SMS (insecure) — use TOTP for admin accounts and sensitive operations.

## Library

```bash
npm install otplib qrcode
npm install --save-dev @types/qrcode
```

## Setup Flow

### 1. Generate Secret and QR Code

```ts
// app/api/2fa/setup/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { authenticator } from 'otplib'
import QRCode from 'qrcode'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

export async function POST(request: NextRequest) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  // Generate TOTP secret
  const secret = authenticator.generateSecret()

  // Create the otpauth URI (what the QR code encodes)
  const otpauthUri = authenticator.keyuri(
    user.email!,
    'JR\'s Auto Repair',  // Your app name
    secret
  )

  // Generate QR code as data URL
  const qrCodeDataUrl = await QRCode.toDataURL(otpauthUri)

  // Store secret temporarily (not activated until user verifies)
  await supabase
    .from('user_2fa')
    .upsert({
      user_id: user.id,
      secret_pending: secret,  // Pending until verified
      secret: null,             // Active secret (null until verified)
      enabled: false,
    })

  return NextResponse.json({ qrCode: qrCodeDataUrl, secret })
}
```

### 2. Verify and Activate

```ts
// app/api/2fa/verify/route.ts
export async function POST(request: NextRequest) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { token } = await request.json()

  const { data: record } = await supabase
    .from('user_2fa')
    .select('secret_pending')
    .eq('user_id', user.id)
    .single()

  if (!record?.secret_pending) {
    return NextResponse.json({ error: 'No pending setup' }, { status: 400 })
  }

  const isValid = authenticator.verify({
    token,
    secret: record.secret_pending,
  })

  if (!isValid) {
    return NextResponse.json({ error: 'Invalid code' }, { status: 400 })
  }

  // Activate 2FA
  await supabase
    .from('user_2fa')
    .update({
      secret: record.secret_pending,
      secret_pending: null,
      enabled: true,
    })
    .eq('user_id', user.id)

  return NextResponse.json({ success: true })
}
```

### 3. Validate on Login

```ts
// Called after password verification
export async function validate2FA(userId: string, token: string): Promise<boolean> {
  const { data: record } = await supabase
    .from('user_2fa')
    .select('secret, enabled')
    .eq('user_id', userId)
    .single()

  if (!record?.enabled || !record.secret) return true  // 2FA not set up — allow

  return authenticator.verify({ token, secret: record.secret })
}
```

TOTP windows are ±30 seconds. `otplib` checks ±1 window by default (accepts codes from 30s ago). Configure `window` option for looser/stricter tolerance.

## Database Schema

```sql
CREATE TABLE user_2fa (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  secret     TEXT,           -- Active TOTP secret (NULL if not enabled)
  secret_pending TEXT,       -- Temp secret during setup (cleared after verify)
  enabled    BOOLEAN NOT NULL DEFAULT FALSE,
  backup_codes TEXT[],       -- Hashed backup codes
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Only the user can read their own 2FA status
ALTER TABLE user_2fa ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user reads own 2fa" ON user_2fa FOR SELECT USING (auth.uid() = user_id);
```

Never expose the `secret` column in client-side queries. Use RLS to restrict it.

## Backup Codes

```ts
import { randomBytes, createHash } from 'crypto'

function generateBackupCodes(count = 8): { codes: string[]; hashed: string[] } {
  const codes = Array.from({ length: count }, () =>
    randomBytes(5).toString('hex').toUpperCase().match(/.{4}/g)!.join('-')
  )
  // "A1B2-C3D4-E5F6"

  const hashed = codes.map((code) =>
    createHash('sha256').update(code).digest('hex')
  )

  return { codes, hashed }
}

// Store hashed codes; show plain codes to user ONCE
const { codes, hashed } = generateBackupCodes()
await supabase.from('user_2fa').update({ backup_codes: hashed }).eq('user_id', userId)
// Return codes to user (only time they see them)
```

## UI Setup Flow

```tsx
function TwoFactorSetup() {
  const [step, setStep] = useState<'qr' | 'verify' | 'done'>('qr')
  const [qrCode, setQrCode] = useState('')
  const [token, setToken] = useState('')
  const [error, setError] = useState('')

  const startSetup = async () => {
    const res = await fetch('/api/2fa/setup', { method: 'POST' })
    const { qrCode } = await res.json()
    setQrCode(qrCode)
    setStep('qr')
  }

  const verifySetup = async () => {
    const res = await fetch('/api/2fa/verify', {
      method: 'POST',
      body: JSON.stringify({ token }),
    })
    if (res.ok) setStep('done')
    else setError('Invalid code — check your authenticator app')
  }

  return (
    <>
      {step === 'qr' && (
        <div>
          <img src={qrCode} alt="Scan with authenticator app" />
          <input value={token} onChange={(e) => setToken(e.target.value)} placeholder="6-digit code" />
          <button onClick={verifySetup}>Verify</button>
          {error && <p className="text-red-600">{error}</p>}
        </div>
      )}
      {step === 'done' && <p>2FA enabled successfully!</p>}
    </>
  )
}
```

## Security Notes

- Store secrets encrypted in DB (not plaintext) in production — use `pgcrypto` extension
- Rate-limit 2FA attempts (max 5 per 10 minutes)
- Log all 2FA events to audit log
- TOTP window of ±1 is sufficient; don't increase to avoid brute-force window
- Never log TOTP tokens or secrets

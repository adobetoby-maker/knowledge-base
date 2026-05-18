# Pattern: Two-Factor Authentication Setup

## Overview

2FA setup flows require generating a TOTP secret, displaying a QR code for authenticator apps, verifying the code works before enabling, and storing backup codes. The verification step before enabling is critical — without it, a user can lock themselves out if the QR scan failed.

## TOTP Secret Generation

```ts
import { createTOTPKeyURI, generateTOTPToken } from '@oslojs/otp'
import { encodeBase32UpperCaseNoPadding } from '@oslojs/encoding'

export function generateTotpSecret(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(20))
  return encodeBase32UpperCaseNoPadding(bytes)
}

export function getTotpUri(secret: string, email: string, appName: string): string {
  return createTOTPKeyURI(appName, email, secret, 30, 6)
}

export function verifyTotpCode(secret: string, code: string): boolean {
  // Check current window (30s) and ±1 window for clock drift
  const now = Date.now()
  for (const offset of [-1, 0, 1]) {
    const expected = generateTOTPToken(secret, 30, 6, now + offset * 30000)
    if (expected === code) return true
  }
  return false
}
```

## Setup Flow (3 Steps)

```tsx
type SetupStep = 'qr' | 'verify' | 'backup-codes'

export function TwoFactorSetup({ onComplete }: { onComplete: () => void }) {
  const [step, setStep] = useState<SetupStep>('qr')
  const [secret] = useState(() => generateTotpSecret())
  const [backupCodes, setBackupCodes] = useState<string[]>([])

  const { user } = useAuth()
  const totpUri = getTotpUri(secret, user.email, 'MyApp')

  return (
    <>
      {step === 'qr' && (
        <QRStep uri={totpUri} secret={secret} onNext={() => setStep('verify')} />
      )}
      {step === 'verify' && (
        <VerifyStep
          secret={secret}
          onSuccess={(codes) => { setBackupCodes(codes); setStep('backup-codes') }}
        />
      )}
      {step === 'backup-codes' && (
        <BackupCodesStep codes={backupCodes} onComplete={onComplete} />
      )}
    </>
  )
}
```

## QR Code Display

```tsx
import QRCode from 'qrcode'

function QRStep({ uri, secret, onNext }: { uri: string; secret: string; onNext: () => void }) {
  const [dataUrl, setDataUrl] = useState('')

  useEffect(() => {
    QRCode.toDataURL(uri, { width: 200, margin: 2 }).then(setDataUrl)
  }, [uri])

  return (
    <div>
      <p>Scan this QR code with your authenticator app (Google Authenticator, Authy).</p>
      {dataUrl && <img src={dataUrl} alt="TOTP QR code" width={200} height={200} />}
      <details>
        <summary className="text-sm cursor-pointer">Can't scan? Enter manually</summary>
        <code className="text-sm font-mono">{secret}</code>
      </details>
      <button onClick={onNext}>I've scanned it — continue</button>
    </div>
  )
}
```

## Verification Step

```tsx
function VerifyStep({ secret, onSuccess }: { secret: string; onSuccess: (codes: string[]) => void }) {
  const [code, setCode] = useState('')
  const [error, setError] = useState('')

  async function handleVerify() {
    setError('')
    const result = await verifyAndEnable2FA({ secret, code })
    if (result.success) {
      onSuccess(result.backupCodes)
    } else {
      setError('Invalid code. Make sure your phone's clock is correct.')
    }
  }

  return (
    <div>
      <p>Enter the 6-digit code from your authenticator app to confirm setup.</p>
      <OtpInput length={6} value={code} onChange={setCode} />
      {error && <p role="alert" className="text-red-600 text-sm">{error}</p>}
      <button onClick={handleVerify} disabled={code.length < 6}>Verify</button>
    </div>
  )
}
```

## Server Action: Enable 2FA

```ts
async function verifyAndEnable2FA({ secret, code }: { secret: string; code: string }) {
  'use server'
  const user = await getServerUser()
  if (!user) throw new Error('Unauthorized')

  if (!verifyTotpCode(secret, code)) {
    return { success: false }
  }

  // Generate backup codes
  const backupCodes = Array.from({ length: 8 }, () =>
    encodeBase32UpperCaseNoPadding(crypto.getRandomValues(new Uint8Array(5)))
  )

  // Store: encrypted secret + hashed backup codes
  await db.update(users)
    .set({
      totpSecret: encrypt(secret),  // encrypt at rest
      backupCodes: backupCodes.map(c => hashCode(c)),  // hash for comparison
      twoFactorEnabled: true,
    })
    .where(eq(users.id, user.id))

  return { success: true, backupCodes }
}
```

## Key Rules

- Always verify the code works before enabling — the user could have scanned wrong.
- Store the TOTP secret encrypted (not plaintext) — it's equivalent to a password.
- Hash backup codes before storing (bcrypt or SHA-256) — they're single-use credentials.
- Show backup codes exactly once, force the user to copy/download them.
- Allow ±1 window (30s drift) for clock skew — strict validation locks out users with imprecise clocks.
- Rate-limit the verification endpoint — 10 attempts per 10 minutes prevents brute force.

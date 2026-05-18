# Plugin: bcrypt / bcryptjs

## What It Is

Password hashing library. Use for: admin passwords, backup codes, any secret that needs to be stored in a database but never retrieved in plain text. Two flavors: `bcrypt` (native, Node-only) and `bcryptjs` (pure JS, any runtime including Workers).

## Installation

```bash
# Node.js / Next.js (faster)
npm install bcrypt
npm install --save-dev @types/bcrypt

# Cloudflare Workers / Edge (pure JS, no native modules)
npm install bcryptjs
```

## Hashing a Password

```ts
import bcrypt from 'bcrypt'

const SALT_ROUNDS = 12  // 2^12 iterations — ~300ms on modern hardware

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS)
}
```

Salt rounds trade-off: higher = slower = harder to brute-force. 10 is minimum, 12 is recommended for passwords, 14+ for high-security contexts. Never use fewer than 10.

## Verifying a Password

```ts
export async function verifyPassword(
  plaintext: string,
  hash: string
): Promise<boolean> {
  return bcrypt.compare(plaintext, hash)
}
```

`compare` is timing-safe — it doesn't short-circuit on mismatch, preventing timing attacks.

## Admin Password Setup (jrs-auto-repair Pattern)

```ts
// scripts/create-admin.ts
// Run once to create the admin hash — store in data/admins.json
import bcrypt from 'bcrypt'
import fs from 'fs'

const password = process.env.ADMIN_PASSWORD!
const hash = await bcrypt.hash(password, 12)

const admins = [
  { username: 'pablo', passwordHash: hash }
]

fs.writeFileSync('data/admins.json', JSON.stringify(admins, null, 2))
console.log('Admin created')
```

```ts
// lib/adminAuth.ts
import bcrypt from 'bcrypt'
import admins from '@/data/admins.json'

export async function verifyAdminCredentials(
  username: string,
  password: string
): Promise<boolean> {
  const admin = admins.find((a) => a.username === username)
  if (!admin) {
    // Constant-time hash to prevent username enumeration via timing
    await bcrypt.hash(password, 12)
    return false
  }

  return bcrypt.compare(password, admin.passwordHash)
}
```

Running a fake hash when the user doesn't exist prevents timing-based username enumeration (response time would be different without the fake operation).

## Hashing Backup Codes

```ts
import crypto from 'crypto'

// For backup codes, use SHA-256 (bcrypt is too slow for bulk operations)
// Backup codes are random — not user-chosen — so bcrypt's dictionary attack protection isn't needed
function hashBackupCode(code: string): string {
  return crypto
    .createHash('sha256')
    .update(code + process.env.BACKUP_CODE_SALT!)
    .digest('hex')
}

function verifyBackupCode(code: string, storedHash: string): boolean {
  const hash = hashBackupCode(code)
  return crypto.timingSafeEqual(Buffer.from(hash), Buffer.from(storedHash))
}
```

`timingSafeEqual` is required for any secret comparison — prevents timing attacks.

## What NOT to Hash with bcrypt

- Tokens (API keys, session tokens, magic links) — use SHA-256 instead. bcrypt is for human-memorable passwords only.
- Large inputs (>72 bytes) — bcrypt silently truncates at 72 bytes. For longer inputs: `hash(sha256(longInput))`.

## Password Validation Before Hashing

Always validate before hashing:

```ts
import { z } from 'zod'

const passwordSchema = z
  .string()
  .min(8, 'At least 8 characters')
  .max(100, 'Too long')
  .regex(/[A-Z]/, 'Include at least one uppercase letter')
  .regex(/[0-9]/, 'Include at least one number')
```

Validation rejects impossible inputs before the expensive hash operation.

# Pattern: Password Strength Indicator

## Overview

Real-time password strength feedback during registration. Reduces weak password submissions and improves security without making the UX hostile.

## Strength Calculation

Don't use a simple regex score — use multiple independent criteria:

```ts
interface PasswordStrength {
  score: 0 | 1 | 2 | 3 | 4  // 0=very weak, 4=very strong
  label: 'Very weak' | 'Weak' | 'Fair' | 'Strong' | 'Very strong'
  feedback: string[]         // Specific improvement hints
}

function getPasswordStrength(password: string): PasswordStrength {
  const checks = {
    length8: password.length >= 8,
    length12: password.length >= 12,
    uppercase: /[A-Z]/.test(password),
    lowercase: /[a-z]/.test(password),
    number: /[0-9]/.test(password),
    special: /[^A-Za-z0-9]/.test(password),
  }

  const passed = Object.values(checks).filter(Boolean).length
  const score = Math.min(4, Math.floor(passed / 1.5)) as 0 | 1 | 2 | 3 | 4

  const feedback: string[] = []
  if (!checks.length8) feedback.push('Use at least 8 characters')
  if (!checks.uppercase) feedback.push('Add uppercase letters')
  if (!checks.number) feedback.push('Add numbers')
  if (!checks.special) feedback.push('Add special characters (!, @, #...)')
  if (!checks.length12 && score >= 2) feedback.push('Longer passwords are stronger')

  const labels = ['Very weak', 'Weak', 'Fair', 'Strong', 'Very strong'] as const

  return { score, label: labels[score], feedback }
}
```

For production, use `zxcvbn` (Dropbox's password strength library) — it checks against common passwords and patterns:

```bash
npm install zxcvbn @types/zxcvbn
```

```ts
import zxcvbn from 'zxcvbn'

const result = zxcvbn(password)
// result.score: 0-4
// result.feedback.warning: string
// result.feedback.suggestions: string[]
// result.crack_times_display: { offline_fast_hashing_1e10_per_second: '...' }
```

## Strength Bar Component

```tsx
const COLORS = {
  0: 'bg-red-500',
  1: 'bg-orange-500',
  2: 'bg-yellow-500',
  3: 'bg-blue-500',
  4: 'bg-green-500',
} as const

interface PasswordStrengthBarProps {
  password: string
}

export function PasswordStrengthBar({ password }: PasswordStrengthBarProps) {
  if (!password) return null

  const { score, label, feedback } = getPasswordStrength(password)

  return (
    <div className="mt-2 space-y-1.5">
      {/* Segmented bar */}
      <div className="flex gap-1">
        {[0, 1, 2, 3].map((i) => (
          <div
            key={i}
            className={`h-1.5 flex-1 rounded-full transition-colors duration-300 ${
              i <= score ? COLORS[score as keyof typeof COLORS] : 'bg-gray-200'
            }`}
          />
        ))}
      </div>

      {/* Label */}
      <div className="flex items-center justify-between">
        <span className="text-xs text-gray-500">
          {feedback[0] ?? label}
        </span>
        <span className={`text-xs font-medium ${
          score <= 1 ? 'text-red-600' :
          score === 2 ? 'text-yellow-600' :
          'text-green-600'
        }`}>
          {label}
        </span>
      </div>
    </div>
  )
}
```

## Password Field with Strength

```tsx
import { useState } from 'react'
import { Eye, EyeOff } from 'lucide-react'

export function PasswordField({
  value,
  onChange,
  showStrength = true,
}: {
  value: string
  onChange: (v: string) => void
  showStrength?: boolean
}) {
  const [visible, setVisible] = useState(false)

  return (
    <div>
      <div className="relative">
        <input
          type={visible ? 'text' : 'password'}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="w-full rounded-lg border px-3 py-2 pr-10 text-sm"
          autoComplete="new-password"
          placeholder="Create a password"
        />
        <button
          type="button"
          onClick={() => setVisible(!visible)}
          className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
          aria-label={visible ? 'Hide password' : 'Show password'}
        >
          {visible ? <EyeOff size={16} /> : <Eye size={16} />}
        </button>
      </div>

      {showStrength && <PasswordStrengthBar password={value} />}
    </div>
  )
}
```

## Validation Gating

Don't block form submission with the strength meter — use it as guidance, not enforcement. The actual minimum should be enforced server-side:

```ts
// Server-side validation (Zod)
const schema = z.object({
  password: z.string()
    .min(8, 'Password must be at least 8 characters')
    .max(128, 'Password too long'),
})
```

Server enforces minimum. Strength indicator encourages users to go further. These are separate concerns.

## Timing Attack Prevention

Always hash passwords server-side with bcrypt or argon2:

```ts
import bcrypt from 'bcrypt'

const hash = await bcrypt.hash(password, 12)  // cost factor 12

// Verify (constant-time comparison)
const valid = await bcrypt.compare(inputPassword, storedHash)
```

Never compare passwords with `===` — use bcrypt's constant-time compare to prevent timing attacks.

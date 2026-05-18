# Skill: Viral Waitlist with Referrals

## Overview
A referral-powered waitlist converts waiting time from passive frustration into active distribution. Users share their link to move up; every share is a free acquisition. The position mechanic works because it is transparent (users see their exact rank) and rewarding (jumps are immediate and visible). Without self-referral prevention and duplicate detection, the ranking is gamed.

## Implementation / Key Points

### Data Model
```ts
interface WaitlistEntry {
  id: string;
  email: string;
  referralCode: string;    // unique, URL-safe, 8 chars
  referredBy?: string;     // referralCode of referrer
  referralCount: number;   // how many valid referrals this entry has
  position: number;        // recomputed dynamically
  joinedAt: string;
}
```

### Unique Referral Code Generation
```ts
import { randomBytes } from 'crypto';

function generateReferralCode(): string {
  return randomBytes(6).toString('base64url').slice(0, 8);  // 'aB3x9kQr'
}
```

### Position Calculation (Dynamic)
Position is not stored as a static number — it is recomputed from the score. This way it always reflects current rankings without needing to update every row on every referral.

```ts
// Score = join timestamp + bonus per referral (earlier + more referrals = better rank)
// Position = rank when sorted by score ascending (lower = better)
async function getPosition(email: string): Promise<number> {
  const entry = await db.waitlist.findByEmail(email);
  const score = computeScore(entry);
  const betterEntries = await db.waitlist.count({
    where: { score: { lt: score } }
  });
  return betterEntries + 1;
}

function computeScore(entry: WaitlistEntry): number {
  const joinMs = new Date(entry.joinedAt).getTime();
  const referralBonus = entry.referralCount * 3_600_000 * 24 * 5;  // 5 days per referral
  return joinMs - referralBonus;  // lower = better position
}
```

### Referral Tracking (Cookie + URL Param)
```ts
// Landing page: extract ref param and store in cookie
const ref = new URLSearchParams(window.location.search).get('ref');
if (ref) document.cookie = `waitlist_ref=${ref}; max-age=2592000; path=/`;  // 30 days

// On signup: read cookie
function getReferralCode(): string | null {
  return document.cookie.match(/waitlist_ref=([^;]+)/)?.[1] ?? null;
}
```

### Self-Referral Prevention
```ts
async function join(email: string, referralCode?: string) {
  // Resolve referrer entry
  let referrer = referralCode ? await db.waitlist.findByCode(referralCode) : null;

  // Prevent self-referral (same email owns that code)
  if (referrer?.email === email) referrer = null;

  const newEntry = await db.waitlist.create({
    email,
    referralCode: generateReferralCode(),
    referredBy: referrer?.referralCode ?? null,
    referralCount: 0,
    joinedAt: new Date().toISOString(),
  });

  if (referrer) {
    await db.waitlist.incrementReferralCount(referrer.id);
    await sendPositionMilestoneEmail(referrer);
  }

  return newEntry;
}
```

### Email on Position Milestone
```ts
const MILESTONES = [100, 50, 25, 10, 5, 1];

async function sendPositionMilestoneEmail(entry: WaitlistEntry) {
  const position = await getPosition(entry.email);
  const lastNotifiedPosition = entry.lastNotifiedPosition ?? Infinity;
  const milestone = MILESTONES.find(m => position <= m && m < lastNotifiedPosition);
  if (!milestone) return;
  await sendEmail({ template: 'waitlist-milestone', to: entry.email, data: { position } });
  await db.waitlist.update(entry.id, { lastNotifiedPosition: milestone });
}
```

## Key Rules
- Referral code must be unguessable — use CSPRNG, not sequential IDs.
- Position is computed dynamically from score, not stored statically.
- Block self-referral by checking email match before crediting the referrer.
- Store referral source in a cookie for 30 days — covers users who close the tab before signing up.
- Notify users at position milestones (50, 25, 10, 5) to sustain sharing momentum.
- Leaderboard of top referrers creates social proof and competitive motivation.
- Rate-limit the `/join` endpoint to prevent bot-flooding the referral credit system.

# Plugin: Day.js

## Overview

Day.js is a 2KB alternative to Moment.js with an identical API. Use it for: date parsing, formatting, manipulation, and comparison. Import immutability and locale support separately via plugins.

## Install

```bash
npm install dayjs
```

No configuration required. Day.js is immutable by default — every operation returns a new instance.

## Basic Operations

```ts
import dayjs from 'dayjs'

// Parse
const d = dayjs('2026-05-18')           // ISO string
const d2 = dayjs(1716076800000)         // Unix ms timestamp
const d3 = dayjs()                      // Current time
const d4 = dayjs(new Date())            // From Date object

// Format
d.format('YYYY-MM-DD')                  // '2026-05-18'
d.format('MMM D, YYYY')                 // 'May 18, 2026'
d.format('h:mm A')                      // '3:30 PM'
d.toISOString()                         // '2026-05-18T00:00:00.000Z'
d.valueOf()                             // Unix ms: 1716076800000
d.unix()                                // Unix seconds: 1716076800

// Display to user — always format in local timezone
dayjs().format('MMM D, YYYY [at] h:mm A')
```

## Comparison

```ts
const a = dayjs('2026-05-18')
const b = dayjs('2026-06-01')

a.isBefore(b)         // true
a.isAfter(b)          // false
a.isSame(b)           // false
a.isSame(b, 'month')  // false (different month)
a.isSame(a, 'month')  // true (same month granularity)

// Difference
b.diff(a, 'day')      // 14
b.diff(a, 'month')    // 0 (truncated, not rounded)
b.diff(a, 'week')     // 2
```

## Manipulation

```ts
const d = dayjs('2026-05-18')

d.add(7, 'day')          // May 25
d.subtract(1, 'month')   // April 18
d.startOf('month')       // May 1
d.endOf('month')         // May 31
d.startOf('week')        // Sunday of that week (or Monday if locale set)
d.set('year', 2027)      // 2027-05-18
```

Chaining works because each method returns a new instance:
```ts
dayjs().add(30, 'day').startOf('month').format('YYYY-MM-DD')
```

## Plugins — Load Only What You Need

```ts
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'
import duration from 'dayjs/plugin/duration'
import isBetween from 'dayjs/plugin/isBetween'
import isSameOrBefore from 'dayjs/plugin/isSameOrBefore'

dayjs.extend(relativeTime)
dayjs.extend(utc)
dayjs.extend(timezone)
dayjs.extend(duration)
dayjs.extend(isBetween)
dayjs.extend(isSameOrBefore)
```

## Relative Time

```ts
dayjs.extend(relativeTime)

dayjs('2026-05-01').fromNow()           // '17 days ago'
dayjs('2026-06-01').fromNow()           // 'in 14 days'
dayjs('2026-05-18').from(dayjs('2026-05-20'))  // '2 days ago'
```

Use for: comment timestamps, notification times, activity feeds.

## Timezone Handling

```ts
dayjs.extend(utc)
dayjs.extend(timezone)

// Store in UTC, display in user's timezone
const stored = dayjs.utc('2026-05-18T15:00:00Z')
stored.tz('America/New_York').format('h:mm A')    // '11:00 AM'
stored.tz('Europe/London').format('h:mm A')        // '4:00 PM'

// Get user's local timezone
const userTz = Intl.DateTimeFormat().resolvedOptions().timeZone
stored.tz(userTz).format('MMM D, h:mm A')
```

## Duration

```ts
dayjs.extend(duration)

const d = dayjs.duration(90, 'minutes')
d.hours()          // 1
d.minutes()        // 30
d.humanize()       // 'an hour' (requires relativeTime plugin)
d.format('H:mm')   // '1:30'
```

## Locale

```ts
import 'dayjs/locale/pt-br'
import 'dayjs/locale/es'
import 'dayjs/locale/ja'

dayjs.locale('pt-br')
dayjs().format('MMMM')   // 'maio'

// Per-instance locale without changing global
dayjs().locale('es').format('MMMM')  // 'mayo'
```

## Date Ranges

```ts
dayjs.extend(isBetween)

const start = dayjs('2026-05-01')
const end = dayjs('2026-05-31')
const check = dayjs('2026-05-15')

check.isBetween(start, end)              // true (exclusive)
check.isBetween(start, end, 'day', '[]') // true (inclusive)
```

## Day.js vs date-fns

| | Day.js | date-fns |
|--|--------|---------|
| Bundle size | ~2KB | Tree-shakeable per function |
| API style | OOP (chain) | Functional (separate functions) |
| Mutability | Immutable | Immutable |
| Timezone | Plugin | Plugin (date-fns-tz) |
| Locale | Plugin | Separate locale imports |
| Moment compat | Yes (drop-in) | No |

Choose Day.js when migrating from Moment.js. Choose date-fns when you prefer functional style and want zero-overhead tree shaking.

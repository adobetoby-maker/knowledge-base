# Skill: Calendar Integration (Google Calendar + Outlook)

## Overview
Calendar sync is harder than it looks because time is genuinely complex: timezone handling is a source of recurring bugs, recurring events with exceptions require special treatment, and two-way sync introduces conflict resolution. The correct mental model: always store in UTC, convert to local only for display, and treat the calendar provider as an external source of truth that can change without warning. Webhooks notify you of changes; your job is to reconcile.

## Implementation

### OAuth Setup (Google Calendar)
```ts
import { google } from 'googleapis';

const oauth2Client = new google.auth.OAuth2(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  `${BASE_URL}/api/auth/google/callback`
);

// Generate authorization URL
export function getGoogleAuthUrl(userId: string) {
  return oauth2Client.generateAuthUrl({
    access_type: 'offline',  // 'offline' = get refresh token
    scope: ['https://www.googleapis.com/auth/calendar'],
    state: userId,           // pass userId through OAuth flow
    prompt: 'consent',       // force consent to get refresh token every time
  });
}

// Exchange code for tokens
export async function handleGoogleCallback(code: string, userId: string) {
  const { tokens } = await oauth2Client.getToken(code);
  // Store tokens (access_token expires in 1h; refresh_token is long-lived)
  await db.calendarConnections.upsert({
    userId,
    provider: 'google',
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token,  // may be null if user already authorized
    expiresAt: new Date(tokens.expiry_date!),
  });
}
```

### Timezone-Safe Event Creation
```ts
// RULE: always receive user's local time + IANA timezone; store UTC start/end
function toUTC(localDatetime: string, timezone: string): Date {
  const { zonedTimeToUtc } = require('date-fns-tz');
  return zonedTimeToUtc(new Date(localDatetime), timezone);
}

export async function createGoogleEvent(userId: string, event: {
  title: string;
  startLocal: string;     // ISO datetime string in user's local time
  endLocal: string;
  timezone: string;       // IANA timezone: 'America/New_York'
  description?: string;
  attendeeEmails?: string[];
}) {
  const tokens = await getCalendarTokens(userId);
  oauth2Client.setCredentials(tokens);
  const calendar = google.calendar({ version: 'v3', auth: oauth2Client });

  const response = await calendar.events.insert({
    calendarId: 'primary',
    requestBody: {
      summary: event.title,
      description: event.description,
      start: {
        dateTime: event.startLocal,
        timeZone: event.timezone,
        // Google stores start.dateTime in the provided timezone
        // It handles UTC conversion internally
      },
      end: {
        dateTime: event.endLocal,
        timeZone: event.timezone,
      },
      attendees: event.attendeeEmails?.map(email => ({ email })),
    },
  });

  // Store our local record with UTC times for DB queries
  await db.events.create({
    userId,
    googleEventId: response.data.id,
    title: event.title,
    startUtc: toUTC(event.startLocal, event.timezone),
    endUtc: toUTC(event.endLocal, event.timezone),
    timezone: event.timezone,
  });

  return response.data;
}
```

### Listing Events
```ts
export async function listUpcomingEvents(userId: string, days = 30) {
  const tokens = await getCalendarTokens(userId);
  oauth2Client.setCredentials(tokens);
  const calendar = google.calendar({ version: 'v3', auth: oauth2Client });

  const now = new Date();
  const end = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);

  const response = await calendar.events.list({
    calendarId: 'primary',
    timeMin: now.toISOString(),
    timeMax: end.toISOString(),
    singleEvents: true,        // expand recurring events into individual instances
    orderBy: 'startTime',
    maxResults: 250,
  });

  return response.data.items ?? [];
}
```

### Webhook for Change Notification
```ts
// Subscribe to push notifications
export async function subscribeToCalendarChanges(userId: string) {
  const tokens = await getCalendarTokens(userId);
  oauth2Client.setCredentials(tokens);
  const calendar = google.calendar({ version: 'v3', auth: oauth2Client });

  const channelId = crypto.randomUUID();
  const expiration = Date.now() + 7 * 24 * 60 * 60 * 1000; // 7 days max

  const response = await calendar.events.watch({
    calendarId: 'primary',
    requestBody: {
      id: channelId,
      type: 'web_hook',
      address: `${BASE_URL}/api/webhooks/google-calendar`,
      expiration: String(expiration),
    },
  });

  await db.calendarWatchChannels.upsert({
    userId,
    channelId,
    resourceId: response.data.resourceId,
    expiresAt: new Date(expiration),
  });
}

// Renew channel before it expires (run daily cron)
export async function renewExpiringSubs() {
  const expiringSoon = await db.calendarWatchChannels.findAll({
    where: { expiresAt: { $lt: new Date(Date.now() + 24 * 60 * 60 * 1000) } },
  });
  for (const channel of expiringSoon) {
    await subscribeToCalendarChanges(channel.userId);
  }
}
```

### iCal Export (Universal Fallback)
```ts
import ical from 'ical-generator';

export function generateICalFeed(events: Event[]): string {
  const cal = ical({ name: 'My Calendar', timezone: 'UTC' });

  events.forEach(event => {
    cal.createEvent({
      start: event.startUtc,
      end: event.endUtc,
      summary: event.title,
      description: event.description,
      uid: event.id,
      url: `${BASE_URL}/events/${event.id}`,
    });
  });

  return cal.toString();
}

// Serve at /api/calendar/feed.ics with Content-Type: text/calendar
```

## Key Rules
- Always store event times in UTC in your database — display in user's IANA timezone using `date-fns-tz`.
- Request `access_type: 'offline'` and `prompt: 'consent'` to always get a refresh token — without it, access expires in 1 hour.
- `singleEvents: true` in list calls expands recurring events — without it, you get only the recurrence rule, not individual instances.
- Handle token refresh transparently: catch 401 from Google API, refresh with `oauth2Client.refreshAccessToken()`, retry once.
- Google Calendar push channels expire after 7 days maximum — run a daily cron to renew channels before they lapse.
- iCal export is the universal fallback for calendar apps (Apple, Outlook, any CalDAV client) that don't support your OAuth flow.
- Conflict detection: check for overlapping `startUtc`/`endUtc` ranges in your DB before creating an event.

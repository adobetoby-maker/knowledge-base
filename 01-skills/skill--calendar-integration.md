# Skill: Calendar Integration

## Overview

Calendar integration covers: embedding a calendar event into email (`.ics` file), adding to Google Calendar via URL, integrating with Google Calendar API for read/write, and displaying a scheduling widget (Calendly-style). For most apps, the `.ics` file + Google/Apple Calendar URL approach covers 90% of use cases without OAuth complexity.

## ICS File Generation

```ts
import { createEvents, EventAttributes } from 'ics'

function generateICS(event: {
  title: string
  description: string
  startDate: Date
  endDate: Date
  location?: string
  organizerEmail?: string
}): string {
  const { error, value } = createEvents([{
    title: event.title,
    description: event.description,
    start: [
      event.startDate.getFullYear(),
      event.startDate.getMonth() + 1,
      event.startDate.getDate(),
      event.startDate.getHours(),
      event.startDate.getMinutes(),
    ],
    end: [
      event.endDate.getFullYear(),
      event.endDate.getMonth() + 1,
      event.endDate.getDate(),
      event.endDate.getHours(),
      event.endDate.getMinutes(),
    ],
    location: event.location,
    organizer: event.organizerEmail
      ? { email: event.organizerEmail }
      : undefined,
    status: 'CONFIRMED',
    busyStatus: 'BUSY',
  } satisfies EventAttributes])

  if (error) throw new Error(error.message)
  return value!
}
```

## Email Attachment

```ts
// Attach .ics to booking confirmation email
await resend.emails.send({
  to: user.email,
  subject: 'Appointment confirmed',
  react: <AppointmentEmailTemplate appointment={appointment} />,
  attachments: [
    {
      filename: 'appointment.ics',
      content: Buffer.from(generateICS({
        title: `Appointment with ${practitionerName}`,
        description: appointment.notes,
        startDate: appointment.startTime,
        endDate: appointment.endTime,
        location: appointment.location,
      })),
      contentType: 'text/calendar',
    },
  ],
})
```

## Add to Google Calendar URL

```ts
function googleCalendarUrl(event: {
  title: string
  startDate: Date
  endDate: Date
  description?: string
  location?: string
}): string {
  const fmt = (d: Date) => d.toISOString().replace(/[-:]/g, '').replace('.000', '')

  const params = new URLSearchParams({
    action: 'TEMPLATE',
    text: event.title,
    dates: `${fmt(event.startDate)}/${fmt(event.endDate)}`,
    ...(event.description && { details: event.description }),
    ...(event.location && { location: event.location }),
  })

  return `https://calendar.google.com/calendar/render?${params}`
}
```

```tsx
<a href={googleCalendarUrl(event)} target="_blank" rel="noopener noreferrer"
   className="btn-secondary text-sm">
  Add to Google Calendar
</a>
```

## Apple/Outlook Calendar URL

```ts
// Apple Calendar and Outlook both accept .ics downloads
function downloadICS(icsContent: string, filename = 'event.ics') {
  const blob = new Blob([icsContent], { type: 'text/calendar' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
```

## Google Calendar API (Read/Write)

```ts
import { google } from 'googleapis'

const oauth2Client = new google.auth.OAuth2(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  process.env.GOOGLE_REDIRECT_URI
)

// After OAuth flow, store and use tokens
oauth2Client.setCredentials({ refresh_token: user.googleRefreshToken })

const calendar = google.calendar({ version: 'v3', auth: oauth2Client })

// List upcoming events
async function getUpcomingEvents(calendarId = 'primary') {
  const response = await calendar.events.list({
    calendarId,
    timeMin: new Date().toISOString(),
    maxResults: 10,
    singleEvents: true,
    orderBy: 'startTime',
  })
  return response.data.items ?? []
}

// Create an event
async function createEvent(event: {
  title: string
  startTime: Date
  endTime: Date
  attendees?: string[]
}) {
  const response = await calendar.events.insert({
    calendarId: 'primary',
    requestBody: {
      summary: event.title,
      start: { dateTime: event.startTime.toISOString() },
      end: { dateTime: event.endTime.toISOString() },
      attendees: event.attendees?.map(email => ({ email })),
      conferenceData: {
        createRequest: { requestId: crypto.randomUUID(), conferenceSolutionKey: { type: 'hangoutsMeet' } },
      },
    },
    conferenceDataVersion: 1,
  })
  return response.data
}
```

## Key Rules

- `.ics` attachment + Google Calendar URL covers most use cases without requiring OAuth or API credentials.
- Google Calendar URL uses `Z` suffix (UTC) timestamps — always convert to UTC before formatting.
- For read/write Google Calendar access, you need OAuth consent — request only `https://www.googleapis.com/auth/calendar.events` scope, not full calendar access.
- The `.ics` `DTSTART`/`DTEND` format: `20260615T140000Z` for UTC, or `20260615T140000` + `TZID` component for local time.
- Refresh tokens for Google Calendar expire after 7 days if the OAuth app is unverified — submit for verification before launch.

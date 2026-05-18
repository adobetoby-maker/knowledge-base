# Skill: Appointment Booking

## Overview

Appointment booking requires: available time slots, booking/cancellation, reminders, and preventing double-booking. The critical constraint is preventing two customers from booking the same slot concurrently.

## Database Schema

```sql
CREATE TABLE availability_schedules (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     UUID NOT NULL REFERENCES organizations(id),
  day_of_week INT NOT NULL,  -- 0=Sunday, 1=Monday, ... 6=Saturday
  start_time TIME NOT NULL,
  end_time   TIME NOT NULL,
  slot_duration_mins INT NOT NULL DEFAULT 60
);

CREATE TABLE appointments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        UUID NOT NULL REFERENCES organizations(id),
  customer_name TEXT NOT NULL,
  customer_email TEXT NOT NULL,
  customer_phone TEXT,
  service       TEXT NOT NULL,
  start_time    TIMESTAMPTZ NOT NULL,
  end_time      TIMESTAMPTZ NOT NULL,
  status        TEXT NOT NULL DEFAULT 'confirmed',  -- confirmed, cancelled, completed, no_show
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  cancelled_at  TIMESTAMPTZ,
  
  CONSTRAINT no_overlap EXCLUDE USING gist (
    org_id WITH =,
    tstzrange(start_time, end_time) WITH &&
  )
);

CREATE INDEX appointments_start_time_idx ON appointments (org_id, start_time);
```

The `EXCLUDE` constraint with `gist` prevents overlapping appointments at the database level — no race condition possible.

## Generating Available Slots

```ts
interface TimeSlot {
  startTime: Date
  endTime: Date
  available: boolean
}

async function getAvailableSlots(
  orgId: string,
  date: Date,
  serviceDurationMins: number,
): Promise<TimeSlot[]> {
  const dayOfWeek = date.getDay()

  // Get schedule for this day
  const schedule = await db.query.availabilitySchedules.findFirst({
    where: and(
      eq(availabilitySchedules.orgId, orgId),
      eq(availabilitySchedules.dayOfWeek, dayOfWeek),
    ),
  })
  if (!schedule) return []

  // Get existing appointments that day
  const dayStart = startOfDay(date)
  const dayEnd = endOfDay(date)
  const existing = await db.query.appointments.findMany({
    where: and(
      eq(appointments.orgId, orgId),
      gte(appointments.startTime, dayStart),
      lte(appointments.startTime, dayEnd),
      ne(appointments.status, 'cancelled'),
    ),
  })

  // Generate slots from schedule
  const slots: TimeSlot[] = []
  const scheduleStart = parse(`${format(date, 'yyyy-MM-dd')} ${schedule.startTime}`, "yyyy-MM-dd HH:mm:ss", new Date())
  const scheduleEnd = parse(`${format(date, 'yyyy-MM-dd')} ${schedule.endTime}`, "yyyy-MM-dd HH:mm:ss", new Date())

  let current = scheduleStart
  while (addMinutes(current, serviceDurationMins) <= scheduleEnd) {
    const end = addMinutes(current, serviceDurationMins)

    // Check if this slot overlaps with an existing appointment
    const isBooked = existing.some(apt =>
      isBefore(apt.startTime, end) && isAfter(apt.endTime, current)
    )

    slots.push({ startTime: current, endTime: end, available: !isBooked })
    current = addMinutes(current, schedule.slotDurationMins)
  }

  return slots
}
```

## Booking with Conflict Prevention

```ts
async function createAppointment(data: {
  orgId: string
  customerName: string
  customerEmail: string
  customerPhone?: string
  service: string
  startTime: Date
  durationMins: number
}): Promise<Appointment> {
  const endTime = addMinutes(data.startTime, data.durationMins)

  try {
    const [appointment] = await db.insert(appointments).values({
      orgId: data.orgId,
      customerName: data.customerName,
      customerEmail: data.customerEmail,
      customerPhone: data.customerPhone,
      service: data.service,
      startTime: data.startTime,
      endTime,
    }).returning()

    return appointment
  } catch (err) {
    // EXCLUDE constraint violation = slot taken
    if (err instanceof Error && err.message.includes('appointments_org_id_tstzrange_excl')) {
      throw new Error('This time slot is no longer available. Please choose another time.')
    }
    throw err
  }
}
```

## Reminder System

```ts
// Overnight batch: send reminders for tomorrow's appointments
async function sendAppointmentReminders() {
  const tomorrow = startOfDay(addDays(new Date(), 1))
  const dayAfter = endOfDay(tomorrow)

  const upcoming = await db.query.appointments.findMany({
    where: and(
      eq(appointments.status, 'confirmed'),
      gte(appointments.startTime, tomorrow),
      lte(appointments.startTime, dayAfter),
    ),
  })

  for (const apt of upcoming) {
    await sendSMS(apt.customerPhone, 
      `Reminder: Your appointment is tomorrow at ${format(apt.startTime, 'h:mm a')}. ` +
      `Reply CANCEL to cancel. JR's Auto Repair: (208) 595-2101`
    )
    
    await sendEmail({
      to: apt.customerEmail,
      subject: 'Appointment Reminder',
      template: 'appointment-reminder',
      data: { appointment: apt },
    })
  }
}
```

## Cancellation

```ts
async function cancelAppointment(
  appointmentId: string,
  cancelledBy: 'customer' | 'business',
) {
  const cutoffHours = 2  // Must cancel at least 2 hours before

  const apt = await db.query.appointments.findFirst({
    where: eq(appointments.id, appointmentId),
  })
  if (!apt) throw new Error('Appointment not found')

  if (cancelledBy === 'customer') {
    const hoursUntil = differenceInHours(apt.startTime, new Date())
    if (hoursUntil < cutoffHours) {
      throw new Error(`Appointments must be cancelled at least ${cutoffHours} hours in advance`)
    }
  }

  await db.update(appointments).set({
    status: 'cancelled',
    cancelledAt: new Date(),
  }).where(eq(appointments.id, appointmentId))
}
```

## Calendar View Integration

For displaying appointments on a calendar, use FullCalendar or a custom weekly grid. Pass appointments as events:

```ts
const events = appointments.map(apt => ({
  id: apt.id,
  title: `${apt.service} — ${apt.customerName}`,
  start: apt.startTime,
  end: apt.endTime,
  backgroundColor: apt.status === 'confirmed' ? '#3b82f6' : '#6b7280',
}))
```

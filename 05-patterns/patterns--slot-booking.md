# Pattern: Time Slot Booking Interface

An appointment booking UI with time slot grid, timezone-aware display, confirmation step, and double-booking prevention.

## Slot States

Each slot has one of four states. The component must handle all four without ambiguity:

```tsx
type SlotStatus = 'available' | 'booked' | 'past' | 'selected';

type TimeSlot = {
  id: string;
  startUtc: string;   // ISO UTC timestamp — source of truth
  endUtc: string;
  status: SlotStatus;
  bookingId?: string; // if booked, the reservation ID
};
```

Store all times as UTC. Convert to the user's timezone only for display. Converting at the data layer leads to timezone bugs when users are in different zones.

## Timezone Display

Display slots in the user's local timezone. Never hardcode a timezone.

```tsx
function useUserTimezone() {
  return Intl.DateTimeFormat().resolvedOptions().timeZone; // e.g., "America/New_York"
}

function formatSlotTime(utcIso: string, timeZone: string): string {
  return new Intl.DateTimeFormat('en-US', {
    timeZone,
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  }).format(new Date(utcIso));
}

// In the component:
const userTz = useUserTimezone();
const displayTime = formatSlotTime(slot.startUtc, userTz);
```

Show the timezone abbreviation near the header:

```tsx
<p className="text-sm text-muted-foreground">
  Times shown in {new Intl.DateTimeFormat('en-US', { timeZone: userTz, timeZoneName: 'short' })
    .formatToParts(new Date()).find(p => p.type === 'timeZoneName')?.value}
</p>
```

Let users switch timezone via a dropdown if they're booking on behalf of someone in another zone.

## Slot Grid

```tsx
function SlotGrid({ slots, selectedId, onSelect }: {
  slots: TimeSlot[];
  selectedId: string | null;
  onSelect: (slot: TimeSlot) => void;
}) {
  const grouped = groupByDate(slots, slot => slot.startUtc);

  return (
    <div className="space-y-6">
      {Object.entries(grouped).map(([date, daySlots]) => (
        <div key={date}>
          <h3 className="font-medium text-sm mb-3">{formatDate(date)}</h3>
          <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
            {daySlots.map(slot => (
              <SlotButton
                key={slot.id}
                slot={slot}
                isSelected={slot.id === selectedId}
                onSelect={onSelect}
                userTz={userTz}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function SlotButton({ slot, isSelected, onSelect, userTz }: SlotButtonProps) {
  const isPast = slot.status === 'past';
  const isBooked = slot.status === 'booked';
  const isDisabled = isPast || isBooked;

  return (
    <button
      onClick={() => !isDisabled && onSelect(slot)}
      disabled={isDisabled}
      aria-pressed={isSelected}
      aria-label={`${formatSlotTime(slot.startUtc, userTz)} - ${isBooked ? 'unavailable' : isPast ? 'past' : 'available'}`}
      className={cn(
        'py-2 px-3 rounded-lg text-sm font-medium border transition-colors',
        isSelected && 'bg-primary text-primary-foreground border-primary',
        !isSelected && !isDisabled && 'hover:border-primary hover:text-primary',
        isBooked && 'bg-muted text-muted-foreground line-through cursor-not-allowed',
        isPast && 'bg-muted/50 text-muted-foreground/50 cursor-not-allowed',
      )}
    >
      {formatSlotTime(slot.startUtc, userTz)}
    </button>
  );
}
```

## Confirmation Step

Don't book directly on slot selection — require a confirmation step to prevent accidental bookings.

```tsx
function BookingFlow() {
  const [step, setStep] = useState<'select' | 'confirm' | 'success'>('select');
  const [selectedSlot, setSelectedSlot] = useState<TimeSlot | null>(null);

  if (step === 'confirm' && selectedSlot) {
    return (
      <ConfirmationStep
        slot={selectedSlot}
        userTz={userTz}
        onConfirm={async () => {
          try {
            await bookSlot(selectedSlot.id);
            setStep('success');
          } catch (err) {
            if (err.code === 'SLOT_TAKEN') {
              // Race condition — slot was booked by someone else
              toast.error('Sorry, this slot was just booked. Please choose another.');
              setStep('select');
              await refreshSlots(); // reload to show updated availability
            }
          }
        }}
        onBack={() => setStep('select')}
      />
    );
  }
  // ...
}
```

## Double-Booking Prevention

Client-side slot status is stale the moment it's loaded. Two users can select the same "available" slot simultaneously. Prevent double-booking with a database constraint:

```sql
-- Supabase / PostgreSQL
ALTER TABLE bookings ADD CONSTRAINT unique_slot UNIQUE (slot_id);
```

The `SLOT_TAKEN` error from the unique constraint violation must be caught and surfaced gracefully (not as a generic error). Refresh the slot list so the UI reflects current availability.

For high-contention slots (popular appointment times), consider optimistic locking: mark the slot as `held` for 5 minutes when selected, then confirm or release.

## Key Rules

- Store all times as UTC; convert to user timezone for display only — never store in local time
- Show timezone abbreviation prominently so users don't book at the wrong hour
- `aria-pressed` on slot buttons — they are toggles, not links
- Confirmation step prevents fat-finger bookings; don't book on first tap
- Catch `SLOT_TAKEN` specifically and refresh slots — a generic error leaves stale "available" slots visible
- Database `UNIQUE` constraint on `slot_id` is the authoritative double-booking guard — client checks are advisory

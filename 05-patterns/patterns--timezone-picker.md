# Pattern: Timezone Selector

## Overview
Storing a UTC offset like `+05:30` breaks when DST rules change because the offset alone cannot reconstruct the correct local time in future dates. Storing an IANA timezone string like `"America/New_York"` lets the runtime apply the correct DST rules at conversion time. The picker needs to feel fast on 500+ zones — grouping by region and surfacing the user's detected zone first makes the list manageable.

## Detect and Surface User's Timezone

```ts
// Detect with Intl.DateTimeFormat — available in all modern environments
// Returns an IANA string like "America/Los_Angeles"
function detectTimezone(): string {
  return Intl.DateTimeFormat().resolvedOptions().timeZone;
}

// Build the timezone list with the detected zone first, then grouped by region
function buildTimezoneList(all: IanaZone[]): TimezoneGroup[] {
  const detected = detectTimezone();
  const detectedZone = all.find(z => z.name === detected);

  const groups = groupByRegion(all.filter(z => z.name !== detected));

  // "Your timezone" group at the top — eliminates scrolling for most users
  return [
    detectedZone ? { label: 'Your timezone', zones: [detectedZone] } : null,
    ...groups,
  ].filter(Boolean) as TimezoneGroup[];
}

function groupByRegion(zones: IanaZone[]): TimezoneGroup[] {
  const map = new Map<string, IanaZone[]>();
  for (const zone of zones) {
    // IANA names are "Region/City" — extract region prefix
    const region = zone.name.split('/')[0];
    if (!map.has(region)) map.set(region, []);
    map.get(region)!.push(zone);
  }
  // Sort zones within each region by UTC offset for easier scanning
  return Array.from(map.entries()).map(([label, zones]) => ({
    label,
    zones: zones.sort((a, b) => a.offset - b.offset),
  }));
}
```

## Current Time Preview

```tsx
// Show "3:42 PM" in the candidate timezone — makes the choice concrete
// Use Intl.DateTimeFormat to avoid importing date libraries for this
function TimePreview({ timezone }: { timezone: string }) {
  const [time, setTime] = useState('');

  useEffect(() => {
    function update() {
      setTime(
        new Intl.DateTimeFormat('en-US', {
          timeZone: timezone,
          hour: 'numeric',
          minute: '2-digit',
          hour12: true,
          // Show timezone abbreviation (PST, EST) so users can cross-check
          timeZoneName: 'short',
        }).format(new Date())
      );
    }
    update();
    // Update every minute — no need for per-second precision
    const id = setInterval(update, 60_000);
    return () => clearInterval(id);
  }, [timezone]);

  return <span className="tz-preview">{time}</span>;
}
```

## Selector Component

```tsx
function TimezonePicker({ value, onChange }: { value: string; onChange: (tz: string) => void }) {
  const [query, setQuery] = useState('');
  const groups = useMemo(() => buildTimezoneList(ALL_TIMEZONES), []);

  const filtered = query
    ? ALL_TIMEZONES.filter(z =>
        z.name.toLowerCase().includes(query.toLowerCase()) ||
        z.label.toLowerCase().includes(query.toLowerCase())
      )
    : null; // null = show grouped list; truthy = show flat filtered results

  return (
    <div className="tz-picker">
      <input
        type="search"
        placeholder="Search timezone..."
        value={query}
        onChange={e => setQuery(e.target.value)}
      />
      <div className="tz-picker__list" role="listbox">
        {filtered
          ? filtered.map(zone => <TimezoneOption key={zone.name} zone={zone} selected={value === zone.name} onSelect={onChange} />)
          : groups.map(group => (
              <optgroup key={group.label} label={group.label}>
                {group.zones.map(zone => (
                  <TimezoneOption key={zone.name} zone={zone} selected={value === zone.name} onSelect={onChange} />
                ))}
              </optgroup>
            ))
        }
      </div>
      {value && <TimePreview timezone={value} />}
    </div>
  );
}
```

## Storing and Displaying

```ts
// STORE: IANA string, never offset
// Good:  "America/Chicago"
// Bad:   "-06:00"  (breaks at DST boundaries)

// DISPLAY: Format using the stored IANA string at render time
function formatInUserTimezone(isoString: string, userTimezone: string): string {
  return new Intl.DateTimeFormat('en-US', {
    timeZone: userTimezone,
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(isoString));
}
```

## Key Rules
- Store IANA timezone strings (`"America/New_York"`), never UTC offsets (`"+05:00"`)
- Detect the user's timezone with `Intl.DateTimeFormat().resolvedOptions().timeZone` — put it first
- Group zones by IANA region prefix for scannable structure
- Show a live time preview for the hovered/selected zone using `Intl.DateTimeFormat`
- Update the preview every minute — per-second updates are unnecessary
- Support text search across both IANA names and human-readable labels
- Use `Intl.DateTimeFormat` for all display — avoid importing full date libraries just for timezone formatting

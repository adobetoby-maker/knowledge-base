# Skill: Address Validation

## Overview

Validate and standardize postal addresses for deliverability and billing. Two levels: format validation (required fields, ZIP format) which is free, and authoritative validation (USPS, Google Places, SmartyStreets) which catches "123 Fake Street" and normalizes addresses. Always validate server-side before charging or shipping.

## Format Validation (Client-Side)

```ts
interface Address {
  line1: string
  line2?: string
  city: string
  state: string    // 2-letter for US
  zip: string
  country: string  // ISO 3166-1 alpha-2
}

function validateAddressFormat(addr: Address): string[] {
  const errors: string[] = []
  
  if (!addr.line1?.trim()) errors.push('Street address is required')
  if (!addr.city?.trim()) errors.push('City is required')
  if (!addr.state?.trim()) errors.push('State is required')
  if (!addr.zip?.trim()) errors.push('ZIP/postal code is required')
  if (!addr.country) errors.push('Country is required')

  // US ZIP code format
  if (addr.country === 'US' && !/^\d{5}(-\d{4})?$/.test(addr.zip)) {
    errors.push('Invalid US ZIP code (use 12345 or 12345-6789)')
  }

  // Canadian postal code
  if (addr.country === 'CA' && !/^[A-Z]\d[A-Z]\s?\d[A-Z]\d$/i.test(addr.zip)) {
    errors.push('Invalid Canadian postal code (use A1A 1A1)')
  }

  return errors
}
```

## Google Places Autocomplete

The best UX for address entry — reduces errors and speeds up forms:

```tsx
import usePlacesAutocomplete, { getGeocode, getDetails } from 'use-places-autocomplete'

function AddressAutocomplete({ onSelect }: { onSelect: (addr: Address) => void }) {
  const {
    ready,
    value,
    suggestions: { status, data },
    setValue,
    clearSuggestions,
  } = usePlacesAutocomplete({ requestOptions: { types: ['address'] } })

  async function handleSelect(placeId: string, description: string) {
    setValue(description, false)
    clearSuggestions()

    const results = await getGeocode({ placeId })
    const components = results[0].address_components

    const get = (type: string) =>
      components.find(c => c.types.includes(type))?.short_name ?? ''
    const getLong = (type: string) =>
      components.find(c => c.types.includes(type))?.long_name ?? ''

    onSelect({
      line1: `${get('street_number')} ${getLong('route')}`.trim(),
      city: getLong('locality') || getLong('sublocality'),
      state: get('administrative_area_level_1'),
      zip: get('postal_code'),
      country: get('country'),
    })
  }

  return (
    <div className="relative">
      <input
        value={value}
        onChange={e => setValue(e.target.value)}
        disabled={!ready}
        placeholder="Start typing an address..."
        className="w-full border rounded px-3 py-2"
      />
      {status === 'OK' && (
        <ul className="absolute z-10 w-full bg-white border rounded shadow mt-1">
          {data.map(({ place_id, description }) => (
            <li
              key={place_id}
              className="px-3 py-2 hover:bg-gray-50 cursor-pointer text-sm"
              onClick={() => handleSelect(place_id, description)}
            >
              {description}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
```

Requires Google Maps JavaScript API loaded: add `<Script src="https://maps.googleapis.com/maps/api/js?key=...&libraries=places" />`.

## SmartyStreets (US Authoritative Validation)

For shipping and billing where accuracy matters:

```ts
async function validateUSAddress(addr: Address): Promise<{
  valid: boolean
  standardized?: Address
  dpvMatchCode?: 'Y' | 'S' | 'D' | 'N'  // Y=confirmed, S=partial, D=unit missing, N=invalid
}> {
  const res = await fetch('https://us-street.api.smartystreets.com/street-address', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify([{
      street: addr.line1,
      street2: addr.line2 ?? '',
      city: addr.city,
      state: addr.state,
      zipcode: addr.zip,
      candidates: 1,
    }]),
    // Auth via query params for SmartyStreets
  })
  
  const results = await res.json()
  if (!results?.length) return { valid: false }
  
  const match = results[0]
  return {
    valid: true,
    dpvMatchCode: match.analysis?.dpv_match_code,
    standardized: {
      line1: match.delivery_line_1,
      city: match.components.city_name,
      state: match.components.state_abbreviation,
      zip: `${match.components.zipcode}-${match.components.plus4_code}`,
      country: 'US',
    },
  }
}
```

## Key Rules

- Google Places autocomplete is the best UX; SmartyStreets/USPS is best for authoritative verification before shipping.
- Always let users override validation — not every address is in the database (new developments, rural routes).
- Store standardized form when available: `1234 ELM ST` not `1234 Elm St.` — USPS uses all-caps.
- For international: don't enforce US-style validation globally. Country determines required fields and format.

# Pattern: Conditional Form Section Reveal

## Overview
Forms frequently need to show additional fields based on a previous answer — "Do you have a vehicle?" reveals license plate and model fields. The naive implementation (CSS `display: none` while keeping the field in the DOM) is wrong: hidden fields still submit their values and still participate in validation. The correct implementation either unmounts the fields (and handles re-registration) or uses a library mechanism that explicitly excludes hidden fields from the submit payload.

## Implementation

### The Problem with CSS-Only Hiding
```tsx
// WRONG — field is in DOM, submits "licenseplate", validates on submit
<div style={{ display: condition ? 'block' : 'none' }}>
  <input {...register('licensePlate', { required: true })} />
</div>
```

### Correct: Conditional Render with React Hook Form
```tsx
import { useForm, useWatch } from 'react-hook-form';

interface FormValues {
  hasVehicle: 'yes' | 'no';
  licensePlate?: string;
  vehicleModel?: string;
}

function VehicleForm() {
  const { register, handleSubmit, control, unregister, formState: { errors } } = useForm<FormValues>();
  const hasVehicle = useWatch({ control, name: 'hasVehicle' });
  const showVehicleSection = hasVehicle === 'yes';

  // Unregister when hidden so values don't persist in form state
  useEffect(() => {
    if (!showVehicleSection) {
      unregister(['licensePlate', 'vehicleModel']);
    }
  }, [showVehicleSection, unregister]);

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <fieldset>
        <legend>Do you own a vehicle?</legend>
        <label>
          <input type="radio" value="yes" {...register('hasVehicle')} />
          Yes
        </label>
        <label>
          <input type="radio" value="no" {...register('hasVehicle')} />
          No
        </label>
      </fieldset>

      {/* Conditionally render — not hide — so fields are fully unmounted */}
      {showVehicleSection && (
        <section aria-live="polite">
          <div>
            <label htmlFor="licensePlate">License Plate</label>
            <input
              id="licensePlate"
              {...register('licensePlate', { required: 'License plate is required' })}
            />
            {errors.licensePlate && <span role="alert">{errors.licensePlate.message}</span>}
          </div>
          <div>
            <label htmlFor="vehicleModel">Vehicle Model</label>
            <input
              id="vehicleModel"
              {...register('vehicleModel', { required: 'Vehicle model is required' })}
            />
            {errors.vehicleModel && <span role="alert">{errors.vehicleModel.message}</span>}
          </div>
        </section>
      )}

      <button type="submit">Submit</button>
    </form>
  );
}
```

### Preserving Values on Re-Show
If the user should see their previously entered values when re-revealing a section (e.g., toggled back and forth), persist outside the form state:

```tsx
const vehicleDataRef = useRef<{ licensePlate: string; vehicleModel: string } | null>(null);

useEffect(() => {
  if (!showVehicleSection) {
    // Save current values before unregistering
    vehicleDataRef.current = getValues(['licensePlate', 'vehicleModel']);
    unregister(['licensePlate', 'vehicleModel']);
  }
}, [showVehicleSection, unregister, getValues]);

// When section re-mounts, restore values
useEffect(() => {
  if (showVehicleSection && vehicleDataRef.current) {
    setValue('licensePlate', vehicleDataRef.current.licensePlate);
    setValue('vehicleModel', vehicleDataRef.current.vehicleModel);
  }
}, [showVehicleSection, setValue]);
```

### Animation (CSS Transition Safe Approach)
Since the section unmounts, a CSS `transition` won't animate out. Use a wrapper with animation that delays unmount:

```tsx
function AnimatedSection({ visible, children }: { visible: boolean; children: React.ReactNode }) {
  const [mounted, setMounted] = useState(visible);

  useEffect(() => {
    if (visible) setMounted(true);
    else {
      const id = setTimeout(() => setMounted(false), 200); // match CSS transition duration
      return () => clearTimeout(id);
    }
  }, [visible]);

  if (!mounted) return null;

  return (
    <div
      style={{
        opacity: visible ? 1 : 0,
        transform: visible ? 'translateY(0)' : 'translateY(-8px)',
        transition: 'opacity 200ms, transform 200ms',
      }}
    >
      {children}
    </div>
  );
}
```

### Alternative: `shouldUnregister` Global Option
React Hook Form has a global `shouldUnregister: true` option that automatically unregisters fields when they unmount. Enable once at form creation level if all conditional fields should be cleared on hide.

```tsx
const form = useForm({ shouldUnregister: true });
```

## Key Rules
- Never use `display: none` or `visibility: hidden` to hide form fields — they still submit and validate.
- Always call `unregister` for fields that are conditionally hidden, unless using `shouldUnregister: true`.
- Wrap the conditional section in `aria-live="polite"` so screen readers announce when new fields appear.
- Consider whether values should be preserved on re-show (wizard back/forward) or cleared (fresh context).
- `useWatch` triggers on every change — memoize the condition if the section contains expensive children.
- For multi-level conditions (show C when A=yes AND B=yes), keep the condition logic in a single derived boolean, not nested ternaries in JSX.

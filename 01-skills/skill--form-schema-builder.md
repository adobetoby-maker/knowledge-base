# Skill: Dynamic Form Schema Builder

## Overview
Storing form definitions as JSON schemas in a database lets non-engineers create and modify forms without deployments. The schema is the single source of truth for rendering, validation, and submission storage. Schema versioning is essential: when a form changes, historical submissions must still be renderable against the schema that was active when they were submitted.

## Implementation / Key Points

### Schema Definition
```ts
interface FormSchema {
  id: string;
  version: number;           // increment on every structural change
  name: string;
  fields: FieldDefinition[];
  createdAt: string;
  archivedAt?: string;
}

interface FieldDefinition {
  id: string;               // stable across schema versions
  type: 'text' | 'email' | 'phone' | 'number' | 'select' | 'multiselect' | 'textarea' | 'checkbox' | 'date' | 'file';
  label: string;
  placeholder?: string;
  required: boolean;
  validation?: ValidationRule[];
  options?: { label: string; value: string }[];   // for select/multiselect
  dependsOn?: { fieldId: string; value: string }; // conditional display
  order: number;
}

interface ValidationRule {
  type: 'min' | 'max' | 'minLength' | 'maxLength' | 'pattern' | 'email';
  value: string | number;
  message: string;
}
```

### Field Type Registry
```tsx
const FIELD_COMPONENTS: Record<FieldDefinition['type'], React.ComponentType<FieldProps>> = {
  text: TextInput,
  email: EmailInput,
  phone: PhoneInput,
  number: NumberInput,
  select: SelectInput,
  multiselect: MultiSelectInput,
  textarea: TextareaInput,
  checkbox: CheckboxInput,
  date: DateInput,
  file: FileUpload,
};

function DynamicForm({ schema }: { schema: FormSchema }) {
  const sortedFields = schema.fields.sort((a, b) => a.order - b.order);
  return (
    <form>
      {sortedFields.map(field => {
        const Component = FIELD_COMPONENTS[field.type];
        return <Component key={field.id} field={field} />;
      })}
    </form>
  );
}
```

### Validation Generated from Schema
```ts
import { z } from 'zod';

function buildZodSchema(fields: FieldDefinition[]): z.ZodObject<any> {
  const shape: Record<string, z.ZodTypeAny> = {};

  for (const field of fields) {
    let schema: z.ZodTypeAny = z.string();

    for (const rule of field.validation ?? []) {
      if (rule.type === 'minLength') schema = (schema as z.ZodString).min(Number(rule.value), rule.message);
      if (rule.type === 'maxLength') schema = (schema as z.ZodString).max(Number(rule.value), rule.message);
      if (rule.type === 'email') schema = z.string().email(rule.message);
      if (rule.type === 'pattern') schema = (schema as z.ZodString).regex(new RegExp(rule.value as string), rule.message);
    }

    shape[field.id] = field.required ? schema : schema.optional();
  }

  return z.object(shape);
}
```

### Storing Submissions Against Schema Version
```ts
interface FormSubmission {
  id: string;
  formId: string;
  schemaVersion: number;        // which schema version was active at submission time
  data: Record<string, unknown>; // raw field values keyed by field.id
  submittedAt: string;
}

// When rendering historical submission:
async function renderSubmission(submission: FormSubmission) {
  const schema = await db.formSchemas.findByVersion(submission.formId, submission.schemaVersion);
  return schema.fields.map(field => ({
    label: field.label,
    value: submission.data[field.id] ?? '(not answered)',
  }));
}
```

### Schema Versioning Strategy
- Increment `version` on every structural change (add/remove/rename field).
- Never mutate an existing schema in place — always create a new version record.
- Mark old versions `archivedAt` when no longer accepting new submissions.
- Keep all historical versions for as long as submissions are retained.

## Key Rules
- Every field needs a stable `id` (slug, not auto-increment) that persists across versions.
- `schemaVersion` must be stored with every submission — you cannot reconstruct it later.
- Validation rules live in the schema, not in application code — code only interprets them.
- Field type registry must be exhaustive: adding a type without a component is a runtime crash.
- Conditional fields (`dependsOn`) must be excluded from validation when their condition is not met.
- Schema is append-only — never delete fields from a schema that has submissions against it.

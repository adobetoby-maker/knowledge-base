# Pattern: Dynamic Form from JSON Schema

## Overview

Schema-driven forms render fields from a JSON configuration rather than hardcoded JSX. This is useful for admin-configurable forms, multi-tenant apps where each tenant has different fields, or survey builders. The key insight: the schema defines structure and validation rules; a field registry maps schema types to React components; `react-hook-form` handles state.

## Schema Shape

Keep the schema flat and explicit. Avoid trying to encode every validation nuance in JSON — complex cross-field rules are better handled in code.

```ts
type FieldType = 'text' | 'email' | 'number' | 'select' | 'checkbox' | 'textarea' | 'array'

interface FieldSchema {
  name: string
  type: FieldType
  label: string
  placeholder?: string
  required?: boolean
  min?: number
  max?: number
  minLength?: number
  maxLength?: number
  pattern?: string          // regex string, compiled at runtime
  options?: { label: string; value: string }[]   // for select
  fields?: FieldSchema[]    // for array/nested types
}

interface FormSchema {
  id: string
  fields: FieldSchema[]
}
```

## Field Type Registry

A registry maps each `FieldType` to a renderer. This is the extensibility point — add a new type by adding one entry, not by modifying a sprawling switch statement.

```tsx
// lib/fieldRegistry.tsx
type FieldRenderer = (props: FieldProps) => JSX.Element

interface FieldProps {
  schema: FieldSchema
  register: UseFormRegister<FieldValues>
  control: Control<FieldValues>
  errors: FieldErrors<FieldValues>
  namePrefix?: string
}

const registry: Record<FieldType, FieldRenderer> = {
  text: TextFieldRenderer,
  email: EmailFieldRenderer,
  number: NumberFieldRenderer,
  select: SelectFieldRenderer,
  checkbox: CheckboxFieldRenderer,
  textarea: TextareaFieldRenderer,
  array: ArrayFieldRenderer,
}

export function renderField(props: FieldProps) {
  const Renderer = registry[props.schema.type]
  if (!Renderer) {
    console.warn(`Unknown field type: ${props.schema.type}`)
    return null
  }
  return <Renderer key={props.schema.name} {...props} />
}
```

## Building Validation Rules from Schema

Convert the schema's validation properties into `react-hook-form` register options at render time:

```ts
function buildValidationRules(schema: FieldSchema): RegisterOptions {
  return {
    required: schema.required ? `${schema.label} is required` : false,
    min: schema.min !== undefined
      ? { value: schema.min, message: `Minimum value is ${schema.min}` }
      : undefined,
    max: schema.max !== undefined
      ? { value: schema.max, message: `Maximum value is ${schema.max}` }
      : undefined,
    minLength: schema.minLength !== undefined
      ? { value: schema.minLength, message: `Minimum ${schema.minLength} characters` }
      : undefined,
    maxLength: schema.maxLength !== undefined
      ? { value: schema.maxLength, message: `Maximum ${schema.maxLength} characters` }
      : undefined,
    pattern: schema.pattern
      ? { value: new RegExp(schema.pattern), message: `Invalid format` }
      : undefined,
  }
}
```

## Array Field Support with useFieldArray

Nested/repeating groups use `useFieldArray`. The `namePrefix` prop threads the parent path through:

```tsx
function ArrayFieldRenderer({ schema, control, register, errors }: FieldProps) {
  const { fields, append, remove } = useFieldArray({
    control,
    name: schema.name,
  })

  return (
    <fieldset>
      <legend>{schema.label}</legend>
      {fields.map((field, index) => (
        <div key={field.id}>
          {schema.fields?.map((subSchema) =>
            renderField({
              schema: subSchema,
              register,
              control,
              errors,
              namePrefix: `${schema.name}.${index}`,
            })
          )}
          <button type="button" onClick={() => remove(index)}>Remove</button>
        </div>
      ))}
      <button type="button" onClick={() => append({})}>Add {schema.label}</button>
    </fieldset>
  )
}
```

The `namePrefix` is prepended to `schema.name` in each renderer: `register(\`${namePrefix}.${schema.name}\`)`.

## Rendering the Form

```tsx
function DynamicForm({ schema, onSubmit }: { schema: FormSchema; onSubmit: (data: FieldValues) => void }) {
  const { register, control, handleSubmit, formState: { errors } } = useForm()

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      {schema.fields.map((fieldSchema) =>
        renderField({ schema: fieldSchema, register, control, errors })
      )}
      <button type="submit">Submit</button>
    </form>
  )
}
```

## Key Rules

- Compile regex patterns from schema strings at render time with `new RegExp()` — JSON can't store RegExp objects.
- Keep cross-field validation (e.g., "end date after start date") in code via `useForm`'s `resolver` option (Zod/Yup), not in the schema JSON — JSON can't express relationships.
- The registry pattern (type → component map) is the right extensibility point; avoid a single `switch` statement in a shared renderer.
- Thread `namePrefix` through all nested renderers to build correct dot-notation paths for `useFieldArray`.
- Validate the schema itself on load in development — unknown field types should warn loudly, not silently skip.

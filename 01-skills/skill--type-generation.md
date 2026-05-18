# Skill: Auto-Generate TypeScript Types

## Overview
Manually written types for database schemas, API responses, and external contracts diverge from reality over time. Generated types are always in sync because they derive directly from the source of truth. The key discipline: run generation in CI, commit the output, and treat type mismatches as build failures — not warnings.

## Supabase Types

```bash
# Generate into a single file
npx supabase gen types typescript \
  --project-id <project-id> \
  --schema public \
  > lib/database.types.ts
```

Use the generated types everywhere:

```ts
import type { Database } from '@/lib/database.types'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient<Database>(url, key)

// Fully typed — .select() returns typed rows
const { data } = await supabase.from('invoices').select('id, total, status')
// data is Array<{ id: string; total: number; status: string }> | null
```

Commit `lib/database.types.ts`. It is generated — not gitignored. The version history shows schema evolution.

## OpenAPI → TypeScript

For REST APIs with an OpenAPI spec:

```bash
npm install --save-dev openapi-typescript

# From a URL
npx openapi-typescript https://api.example.com/openapi.json -o lib/api.types.ts

# From a local file
npx openapi-typescript openapi.yaml -o lib/api.types.ts
```

Usage with `openapi-fetch`:

```ts
import createClient from 'openapi-fetch'
import type { paths } from '@/lib/api.types'

const client = createClient<paths>({ baseUrl: 'https://api.example.com' })

// Typed request and response
const { data, error } = await client.GET('/users/{id}', {
  params: { path: { id: '123' } },
})
```

## JSON Schema → TypeScript

For JSON configs, event payloads, or any schema-validated data:

```bash
npm install --save-dev json-schema-to-typescript

npx json2ts -i schema.json -o lib/schema.types.ts
```

Or programmatically:

```ts
import { compile } from 'json-schema-to-typescript'
import { readFile, writeFile } from 'fs/promises'

const schema = JSON.parse(await readFile('webhook-payload.json', 'utf8'))
const types = await compile(schema, 'WebhookPayload', { bannerComment: '' })
await writeFile('lib/webhook.types.ts', types)
```

## Prisma Types

Prisma generates `PrismaClient` with full TypeScript types from `schema.prisma`:

```bash
npx prisma generate
```

Types live in `node_modules/.prisma/client` and `@prisma/client`. Access via:

```ts
import type { Prisma, User } from '@prisma/client'

// Typed query result
type UserWithPosts = Prisma.UserGetPayload<{
  include: { posts: true }
}>
```

Run `prisma generate` after every schema change. Add to `postinstall` script:

```json
{
  "scripts": {
    "postinstall": "prisma generate"
  }
}
```

## CI Type Sync Enforcement

```yaml
# .github/workflows/types.yml
- name: Regenerate types
  run: |
    npx supabase gen types typescript --project-id $PROJECT_ID > lib/database.types.ts
    npx openapi-typescript openapi.yaml -o lib/api.types.ts

- name: Check for uncommitted type changes
  run: |
    if ! git diff --quiet lib/database.types.ts lib/api.types.ts; then
      echo "Generated types are out of sync. Run type generation locally and commit."
      git diff lib/
      exit 1
    fi
```

This fails the build if someone modified the database schema without regenerating types.

## Key Rules
- Commit generated type files — they are source artifacts, not build artifacts
- Never gitignore generated type files; version history is valuable
- Run generation in CI + diff check to catch schema drift before it reaches production
- Add type generation to `postinstall` so it runs automatically after `npm install`
- Do not hand-edit generated files — edits will be overwritten on next generation
- For Supabase: use the typed client everywhere, not the untyped default export

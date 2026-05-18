# Review: Agent Output Quality Checklist

## Purpose

Before using agent-generated content, code, or data in production, verify these items. Agents make systematic errors that are hard to spot in individual outputs but obvious in bulk.

## Code Generation

- [ ] **Types match usage**: Generated TypeScript compiles without `// @ts-ignore` or `as any` casts
- [ ] **Imports exist**: Every imported module is actually installed in `package.json`
- [ ] **No placeholder values**: No `// TODO`, `// FIXME`, `"your_api_key_here"`, or `undefined as never`
- [ ] **Auth check present**: Route handlers that touch user data have `validateAdminSession` or `getUser()` at entry
- [ ] **Error handling**: Async operations have `.catch()` or try/catch — no unhandled rejections
- [ ] **No hardcoded secrets**: No strings that look like API keys, passwords, or tokens
- [ ] **Correct client**: Supabase operations use the right client (not `admin.ts` in browser-facing code)

## Content Generation

- [ ] **Factual accuracy**: Claims about specific businesses, people, dates, addresses are verified
- [ ] **No hallucinated citations**: Any cited statistics, studies, or sources actually exist
- [ ] **Keyword density**: Primary keyword appears in: title, first 100 words, at least one H2, meta description
- [ ] **Word count**: Meets the target length; not padded with repetitive filler
- [ ] **No AI tells**: Phrases like "In today's digital landscape", "It's worth noting", "At the end of the day"
- [ ] **Appropriate tone**: Matches the site's established voice (professional, friendly, technical)
- [ ] **Internal links**: Links to other content on the same site, not external competitors

## Data Transformation

- [ ] **Completeness**: Output count matches input count (no items silently dropped)
- [ ] **Schema match**: Output shape matches the expected TypeScript type or Zod schema
- [ ] **No truncation**: Long strings aren't cut mid-sentence; arrays aren't length-limited
- [ ] **Encoding handled**: Special characters, Unicode, quotes in strings are escaped correctly
- [ ] **Money safety**: Numeric values for prices are integers (cents), not floats

## Database Operations

- [ ] **Additive only**: No `DROP TABLE`, `TRUNCATE`, `DELETE` without WHERE clause
- [ ] **Migration reversible**: Has both `up` and `down` migration, or is clearly not reversible
- [ ] **RLS considered**: New tables have RLS enabled; new operations don't bypass existing policies
- [ ] **No N+1**: Queries inside loops are replaced with bulk selects + join
- [ ] **Indexes on FK**: Every foreign key column has an index

## API Design

- [ ] **Consistent error format**: All errors return `{ error: string }` not mixed shapes
- [ ] **HTTP methods correct**: GET for reads, POST for creates, PUT for replaces, PATCH for partial updates
- [ ] **No sensitive data in responses**: Error messages don't expose stack traces, DB structure, or secrets
- [ ] **Pagination on lists**: Endpoints returning collections have limit/offset or cursor parameters
- [ ] **Input validation**: Route Handlers validate with Zod before touching DB

## Structural

- [ ] **File naming**: Matches project conventions (kebab-case files, PascalCase components)
- [ ] **No circular imports**: New files don't import from files that import from them
- [ ] **No dead exports**: Functions exported but never imported anywhere
- [ ] **Consistent with neighbors**: Code in the same file follows the same patterns as existing code
- [ ] **Tests pass**: `npm run test` (if tests exist) passes with the changes

## Reviewing Agent Batches

When reviewing 50+ agent-generated items (articles, components, data records):

1. **Sample review**: Check 10% of items in detail, plus any that look unusual
2. **Statistical check**: Count: completions, lengths, error rates, patterns
3. **Schema validation**: Run all outputs through the Zod schema — failures reveal systematic problems
4. **Spot check extremes**: Review the shortest and longest outputs — truncation and padding problems show up there
5. **Duplicate detection**: Hash content to find near-duplicates the agent produced for different inputs

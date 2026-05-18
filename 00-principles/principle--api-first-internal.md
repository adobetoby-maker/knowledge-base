# Principle: API-First for Internal Services

## Overview
Building the internal API before (or alongside) the first consumer forces the team to make explicit decisions about data contracts, error conditions, and boundaries that would otherwise be left implicit in shared code or direct database calls. The act of designing the API — separate from implementing it — surfaces product logic gaps before they are baked into implementation details that are expensive to change.

## Key Points

### Design the Interface Before the Implementation
The API-first sequence:
1. Write the OpenAPI spec (or tRPC router definitions, or GraphQL schema)
2. Review the spec with consuming teams — is the shape right?
3. Generate a mock server from the spec
4. Frontend/mobile develops against the mock in parallel with backend implementation
5. Replace mock with real implementation when ready; consuming teams switch over

If you skip to step 5 directly:
- Frontend blocks on backend, serializing the work
- The API shape is whatever was convenient to implement, not what consumers actually need
- Changes required by consuming teams mean rework after code is written

### API Design Review Reveals Product Gaps
Reviewing an API design with stakeholders often uncovers:
```
Proposed: GET /api/orders → returns list of orders

Question from frontend team: "Does this include cancelled orders? Draft orders? 
                               Archived orders from 3 years ago?"

Product: "...hm, we haven't decided that yet"
```
These are product decisions that must be made before the endpoint is built. Surfacing them at API design time is cheap. Surfacing them after launch requires migrations, versioning, and backward-compatibility work.

### Mock APIs Enable Parallel Development
```yaml
# openapi.yaml
/api/v1/orders:
  get:
    parameters:
      - name: status
        in: query
        schema:
          type: string
          enum: [pending, confirmed, shipped, delivered, cancelled]
    responses:
      '200':
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/OrderList'
```

From this spec, tools like Prism or Mockoon generate a mock server that returns realistic data. Frontend team uses it from day one — no backend dependency.

### SDK Generation
From an OpenAPI spec, generate typed clients automatically:
```bash
npx openapi-typescript openapi.yaml -o types/api.d.ts
npx openapi-generator-cli generate -i openapi.yaml -g typescript-fetch -o lib/api/
```

Benefits:
- Client code never drifts from server implementation
- Regenerate on spec change → TypeScript catches mismatched call sites
- Documentation is always current (generated from spec, not written separately)

### "We'll Add the API Later" Is a Pattern That Fails
The failure mode:
1. Internal service built without explicit API design
2. Consumer team uses internal database queries or imports internal modules directly
3. Service wants to refactor its internals → impossible without breaking consumers
4. Service grows into a monolith by necessity: no clear boundary, any change is global

An explicit API boundary enforces the separation of concerns between teams. It is a commitment: "everything inside this boundary is ours to change; everything outside this boundary is the contract we maintain."

### API Documentation Lives With the Code
```
/services/orders/
  openapi.yaml       ← spec lives here, versioned in git
  src/               ← implementation
  README.md          ← links to spec, not duplicate of spec
```

Documentation written separately from code goes stale. The spec is the documentation. Generate readable docs from the spec:
```bash
npx @redocly/cli build-docs openapi.yaml -o docs/api.html
```

## Key Rules
- Write the API spec before writing the implementation; implementation details follow the contract, not vice versa
- API design review with consumers happens before implementation starts
- Generate a mock server from the spec; consuming teams develop against the mock in parallel
- Never allow direct database access or module imports across service boundaries — force everything through the API
- Generate typed clients from the spec; do not hand-write client code that can drift
- "We'll figure out the shape later" = "we'll rewrite this later" — make the contract explicit at the start
- API documentation is generated from the spec, not maintained separately

# Skill: API Documentation

## Overview
API documentation that is written separately from code goes stale immediately. The only sustainable approach is generating the OpenAPI spec from code — types and validation schemas that already exist. Consumers need: working example requests, authentication instructions, and a changelog for breaking changes. Without these, every API integration starts with a support request.

## Implementation

### OpenAPI Spec from Zod Schemas (zod-to-openapi)
```typescript
// lib/openapi.ts
import { OpenAPIRegistry, OpenApiGeneratorV3 } from "@asteasolutions/zod-to-openapi";
import { z } from "zod";

export const registry = new OpenAPIRegistry();

// Define schemas once — used for both validation and docs
const InvoiceSchema = registry.register(
  "Invoice",
  z.object({
    id: z.string().uuid(),
    status: z.enum(["draft", "pending", "paid"]).describe("Current invoice status"),
    total: z.number().int().describe("Total in cents"),
    customerId: z.string().uuid(),
    createdAt: z.string().datetime(),
  })
);

// Register an endpoint
registry.registerPath({
  method: "post",
  path: "/api/invoices",
  summary: "Create a new invoice",
  request: {
    body: {
      content: {
        "application/json": {
          schema: z.object({
            customerId: z.string().uuid(),
            lineItems: z.array(z.object({
              description: z.string(),
              amount: z.number().int(),
            })).min(1),
          }),
        },
      },
    },
  },
  responses: {
    201: {
      description: "Invoice created",
      content: { "application/json": { schema: InvoiceSchema } },
    },
    422: { description: "Validation error" },
    401: { description: "Unauthorized" },
  },
});

// Generate spec
export function generateSpec() {
  const generator = new OpenApiGeneratorV3(registry.definitions);
  return generator.generateDocument({
    openapi: "3.0.0",
    info: { title: "My API", version: "1.0.0" },
    servers: [{ url: "https://api.example.com" }],
  });
}
```

### Serve Swagger UI / Redoc
```typescript
// app/api/docs/route.ts
import { generateSpec } from "@/lib/openapi";

export async function GET() {
  const spec = generateSpec();
  const html = `<!DOCTYPE html>
<html>
<head><title>API Docs</title>
<script src="https://cdn.jsdelivr.net/npm/redoc/bundles/redoc.standalone.js"></script>
</head>
<body>
<div id="redoc-container"></div>
<script>Redoc.init('/api/docs/spec', {}, document.getElementById('redoc-container'))</script>
</body></html>`;
  return new Response(html, { headers: { "Content-Type": "text/html" } });
}

// app/api/docs/spec/route.ts
export async function GET() {
  return Response.json(generateSpec());
}
```

### Authentication Section
Every API must document how to authenticate. In the OpenAPI spec:
```typescript
registry.registerComponent("securitySchemes", "BearerAuth", {
  type: "http",
  scheme: "bearer",
  bearerFormat: "JWT",
});
// Then reference in each protected endpoint:
// security: [{ BearerAuth: [] }]
```

### Changelog for Breaking Changes
```markdown
// CHANGELOG.md (API section)
## API v2.1.0 — 2026-03-01
### Breaking Changes
- `GET /api/invoices` — removed `total_string` field (use `total` integer in cents)

### New
- `POST /api/invoices/bulk` — create up to 50 invoices in one request

## API v2.0.0 — 2026-01-15 (6-month deprecation of v1)
### Breaking Changes
- All amounts now in cents (integers), not dollars (strings)
- Rate limit reduced from 1000/min to 200/min
```

## Key Rules
- Generate the OpenAPI spec from code (zod-to-openapi, TypeSpec, or similar) — manually written specs are always out of date within one sprint
- Every endpoint needs at least one example request and one example response — prose descriptions alone are insufficient for integration
- Document all error responses, not just 200 — 401, 422, 429, 500 each need descriptions so integrators handle them correctly
- Authentication documentation must include a working token example (use a fake but structurally valid token)
- Maintain a breaking-changes changelog separate from the feature changelog — breaking changes require advance notice and migration guides
- Serve Swagger UI or Redoc at a stable URL (e.g. `/api/docs`) — don't make integrators download and render the spec manually
- Version the spec in the URL or header when you introduce breaking changes (`/api/v2/` or `API-Version: 2`)

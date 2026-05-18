# Principle: Zero Trust Networks

## Overview
The traditional security model assumed that anything inside the corporate network perimeter could be trusted. "Zero trust" rejects this assumption entirely: no request is trusted based on network location alone. Every request — whether from an external user or an internal microservice on the same cluster — must be authenticated and authorized. The network perimeter is not a security boundary; it is just a network.

## Why the Perimeter Model Fails

- Cloud infrastructure has no perimeter — services span VPCs, regions, cloud providers
- Lateral movement: one compromised internal service can reach all other "trusted" services
- Supply chain attacks: a malicious npm package running inside your cluster has "internal" network access
- Remote work: employees access systems from coffee shops, not corporate offices
- Breaches happen: when they do, a zero-trust model limits blast radius

## Service-to-Service Authentication

Every internal API call must carry a credential:

```typescript
// Service A calling Service B — passes a token
const response = await fetch("http://order-service/api/orders", {
  headers: {
    "Authorization": `Bearer ${serviceToken}`,
    "X-Service-ID": "payment-service",
  },
});

// Service B verifies the token
app.use(async (req, res, next) => {
  const token = req.headers.authorization?.replace("Bearer ", "");
  if (!token || !await verifyServiceToken(token)) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  next();
});
```

Service tokens should have:
- Short TTL (1 hour or less)
- Audience claim limiting which services can use them
- Automatic rotation via a secrets manager (Vault, AWS Secrets Manager)

## Mutual TLS (mTLS) for Service Mesh

For mature service meshes (Istio, Linkerd), mTLS provides automatic authentication:
- Each service has its own TLS certificate issued by an internal CA
- Both client and server present certificates and verify each other
- The service mesh sidecar handles this transparently
- A compromised certificate can be revoked centrally

Without a service mesh, implement mTLS at the application layer using certificate pinning.

## Input Validation at Every Layer

Zero trust applies to data as well. An "internal" service calling your API with a service token does not automatically get to skip input validation. Validate all inputs regardless of source:

```typescript
// Even though this comes from our own payment service, still validate
const parsed = z.object({
  orderId: z.string().uuid(),
  amount: z.number().positive().max(1_000_000),
  currency: z.enum(["usd", "eur", "gbp"]),
}).parse(req.body);
```

A bug in an internal service sending malformed data should not corrupt your database.

## Authorization Is Not Authentication

Authentication: "Who are you?" (verified identity)  
Authorization: "What are you allowed to do?" (permissions check)

Even after service authentication, enforce authorization per operation:
```typescript
// Service is authenticated as "analytics-service"
// But analytics-service should not be able to write orders
if (req.service.id === "analytics-service" && req.method !== "GET") {
  return res.status(403).json({ error: "Analytics service has read-only access" });
}
```

## Practical Checklist

- [ ] Service-to-service calls use short-lived tokens or mTLS
- [ ] Tokens carry audience claims (service A's token only works for service B)
- [ ] Network segmentation still exists (defense in depth) but is not trusted alone
- [ ] Secrets are in a secrets manager, not environment variables in container definitions
- [ ] Internal admin endpoints require the same (or stronger) authentication as external APIs
- [ ] Audit logs capture service identity for every internal API call

## Key Rules
- "Internal network" is not a trust boundary
- Every service call requires a credential — no anonymous internal traffic
- Service tokens have short TTL and explicit audience scopes
- Input validation runs regardless of caller's trust level
- Authorization is separate from authentication — check both
- Rotate service credentials automatically; manual rotation is never done regularly
- Assume breach: design as if an attacker is already inside the network

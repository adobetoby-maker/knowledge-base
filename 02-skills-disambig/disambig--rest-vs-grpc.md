# Disambig: REST vs gRPC

## Overview
REST and gRPC solve the same problem—service-to-service communication—with fundamentally different tradeoffs. REST is the default because it's human-readable, cacheable, and browser-native. gRPC earns its added complexity when you need: binary efficiency at scale, streaming, or a machine-enforced contract between many services. The choice affects your toolchain, debugging approach, and client compatibility permanently.

## Comparison

| Property | REST | gRPC |
|---|---|---|
| Wire format | JSON (text) | Protocol Buffers (binary) |
| Readability | Human-readable | Not human-readable without tooling |
| Browser native | Yes (`fetch`, `XMLHttpRequest`) | No (needs grpc-web proxy) |
| Caching | HTTP caching headers work natively | Not cacheable (POST by convention) |
| Contract | OpenAPI spec (optional) | `.proto` file (required, enforced) |
| Code generation | Optional | Required (proto compiler) |
| Streaming | SSE (one-way) / WebSocket | Native bi-directional streaming |
| Performance | Slower (JSON parse, verbose) | Faster (binary, smaller payloads) |
| Debugging | `curl`, browser DevTools | `grpcurl`, specialized tooling |
| Error model | HTTP status codes | gRPC status codes (different set) |

## When to Use REST

```
Public API consumed by third parties
→ REST: developers expect HTTP + JSON; no proto toolchain required

Browser clients calling your backend
→ REST: browsers can't use gRPC without a grpc-web proxy layer

Simple CRUD operations
→ REST: maps naturally to GET/POST/PUT/DELETE semantics

Team unfamiliar with Protocol Buffers
→ REST: lower onboarding cost

Low request volume, payload size not a concern
→ REST: JSON overhead is negligible at small scale
```

## When to Use gRPC

```
Internal microservice-to-microservice calls
→ gRPC: no browser involved; binary performance matters

Streaming data (logs, events, sensor data)
→ gRPC: native bidirectional streaming; SSE can't send client→server

Mobile clients where bandwidth is expensive
→ gRPC: protobuf payloads 3-10x smaller than JSON

Large number of services needing a shared contract
→ gRPC: .proto file enforces schema at compile time; JSON drifts silently

High-throughput internal APIs (>10k RPS per service)
→ gRPC: binary serialization + HTTP/2 multiplexing reduces CPU and latency
```

## gRPC in Node.js/TypeScript
```ts
// Define contract in .proto
service UserService {
  rpc GetUser (GetUserRequest) returns (User);
  rpc StreamUsers (StreamRequest) returns (stream User);
}

// Generate types
// protoc --ts_out=. --ts_opt=server_generic user.proto

// Server
const server = new grpc.Server();
server.addService(UserServiceService, {
  getUser: async (call, callback) => {
    const user = await db.users.findById(call.request.id);
    callback(null, user);
  },
  streamUsers: (call) => {
    users.forEach(user => call.write(user));
    call.end();
  },
});

// Client
const client = new UserServiceClient('localhost:50051', grpc.credentials.createInsecure());
const user = await promisify(client.getUser.bind(client))({ id: '123' });
```

## gRPC-Web for Browser Clients
```
If you need gRPC from browsers, add an Envoy proxy or use @grpc/grpc-js with grpc-web:
Browser → grpc-web → Envoy proxy → gRPC backend

This adds significant infrastructure complexity — evaluate whether REST is sufficient first.
```

## Key Rules
- **Default to REST** — simpler toolchain, universal browser support, familiar to more developers.
- **gRPC earns its complexity** — only introduce it when streaming, binary efficiency, or contract enforcement provide measurable value.
- **`.proto` is the contract** — treat it like a database schema; version it, review changes carefully, never break backward compatibility.
- **gRPC and REST can coexist** — public API can be REST while internal services use gRPC.
- **`grpcurl` for debugging** — equivalent of `curl` for gRPC; install it before writing your first gRPC service.
- **gRPC status codes ≠ HTTP codes** — `NOT_FOUND` is code 5 in gRPC, not 404; map them explicitly if bridging.

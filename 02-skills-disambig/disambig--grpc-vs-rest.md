# gRPC vs REST for Service Communication

## What gRPC Is and Why It Exists

gRPC is a remote procedure call framework built on HTTP/2 and Protocol Buffers (protobuf). Where REST sends human-readable JSON over HTTP/1.1, gRPC sends binary-encoded messages over a multiplexed HTTP/2 connection. The combination produces significantly lower latency and smaller payload sizes — typically 5–10x smaller than equivalent JSON, with serialization/deserialization that is 3–6x faster.

gRPC also generates type-safe client and server code from `.proto` schema files, eliminating an entire category of integration bugs that REST APIs encounter at runtime.

## Why REST Has Stayed Dominant for Public APIs

REST's advantages are almost entirely about tooling and accessibility:

- Any HTTP client can call a REST API — curl, browser fetch, Postman, language-native HTTP libraries
- Responses are human-readable JSON — you can inspect traffic in browser DevTools without additional tooling
- HTTP semantics map naturally to CRUD operations — consumers understand the model without reading documentation
- Caching works at every layer (browser, CDN, reverse proxy) with no configuration

gRPC requires the client to have generated stubs from your `.proto` file. Calling a gRPC service from a browser requires grpc-web and a proxy layer. Debugging binary traffic requires protobuf-aware tooling. External developers integrating with your API face a steep setup cost compared to a REST API.

## The Protobuf Schema: Asset and Liability

The `.proto` schema is gRPC's strongest feature and its most significant maintenance burden. On the asset side: the schema is a precise, versioned contract. Code generation eliminates hand-rolled HTTP clients. Breaking changes are caught at compile time, not in production.

On the liability side: every field change requires regenerating and distributing client stubs. Evolving a schema across multiple services and language targets (Go backend, Python data service, TypeScript web frontend) requires discipline and tooling. Reserved field numbers for deleted fields must be tracked to prevent future reuse. This overhead is manageable for a team that invests in it, but it's real.

## Streaming: gRPC's Unique Capability

gRPC supports four communication patterns: unary (one request, one response), server streaming, client streaming, and bidirectional streaming. These map directly to real use cases: server streaming for real-time progress updates, bidirectional streaming for chat or sensor data.

REST can approximate server streaming with Server-Sent Events and simulate bidirectional with WebSockets, but these are separate protocols layered on top of HTTP rather than first-class features of the same framework.

## Where gRPC Wins

**High-throughput internal microservices**: When Service A calls Service B thousands of times per second — payment processing, recommendation engines, search indexes — the binary encoding and HTTP/2 multiplexing produce measurable latency and bandwidth reduction.

**Polyglot service meshes**: When services are written in Go, Python, Java, and Rust, gRPC's code generation provides consistent, type-safe clients in every language from a single source of truth.

**Streaming data pipelines**: Bidirectional streaming is natural for scenarios where both sides are continuously producing data.

## Where REST Wins

**Public APIs**: External developers should not need to manage `.proto` files and code generation to call your API. REST is the universal language of web APIs.

**Browser clients**: grpc-web requires a proxy (Envoy or a custom layer). REST works from `fetch()` with no infrastructure.

**Simple services with low call volume**: The setup cost of protobuf tooling and code generation is not justified for a service that handles a few hundred requests per minute.

**Teams without existing gRPC experience**: The learning curve for protobuf schema design, versioning rules, and code generation pipelines is non-trivial.

## Key Rules

- Default to REST for any API that external clients, browsers, or third parties will consume
- Use gRPC for internal service-to-service communication where throughput is high and both sides are under your control
- Never start a new project with gRPC without first establishing `.proto` schema governance — field number management and breaking change detection must be solved before the first production service
- If adding gRPC to an existing REST-dominant system, introduce it incrementally on the highest-volume internal path first
- Bidirectional streaming requirements are a strong signal to use gRPC — REST alternatives are significantly more complex
- REST + JSON is almost always fast enough; choose gRPC only when profiling shows serialization or connection overhead is an actual bottleneck

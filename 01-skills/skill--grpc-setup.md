# Skill: gRPC Between Internal Services

## Overview
gRPC is HTTP/2-based RPC with strongly typed contracts defined in `.proto` files. It outperforms REST for internal service communication: binary serialization, multiplexed streams, and generated client/server stubs eliminate serialization bugs. The `.proto` file IS the API contract — both sides are generated from it, so schema drift is impossible.

## Implementation

### 1. Proto file (the contract)
```proto
// proto/order.proto
syntax = "proto3";
package order;

service OrderService {
  rpc GetOrder (GetOrderRequest) returns (Order);
  rpc ListOrders (ListOrdersRequest) returns (stream Order);  // server streaming
  rpc CreateOrder (CreateOrderRequest) returns (Order);
}

message GetOrderRequest {
  string order_id = 1;
}

message ListOrdersRequest {
  string user_id = 1;
  string status = 2;  // optional filter
}

message CreateOrderRequest {
  string user_id = 1;
  repeated OrderItem items = 2;
}

message Order {
  string id = 1;
  string user_id = 2;
  string status = 3;
  int64 created_at = 4;  // unix timestamp
  repeated OrderItem items = 5;
}

message OrderItem {
  string product_id = 1;
  int32 quantity = 2;
  int64 price_cents = 3;
}
```

### 2. Generate TypeScript from proto
```bash
# Install code generation tools
npm install -D grpc-tools @grpc/grpc-js @grpc/proto-loader ts-protoc-gen

# package.json script
"proto:gen": "grpc_tools_node_protoc \
  --plugin=protoc-gen-ts=./node_modules/.bin/protoc-gen-ts \
  --ts_out=grpc_js:./src/generated \
  --js_out=import_style=commonjs,binary:./src/generated \
  --grpc_out=grpc_js:./src/generated \
  --proto_path=./proto \
  ./proto/*.proto"
```

### 3. Server implementation
```ts
import * as grpc from '@grpc/grpc-js';
import { OrderServiceService } from './generated/order_grpc_pb';
import { Order, GetOrderRequest } from './generated/order_pb';

const server = new grpc.Server();

server.addService(OrderServiceService, {
  getOrder: async (call: grpc.ServerUnaryCall<GetOrderRequest, Order>, callback) => {
    // Set deadline awareness — check if client cancelled
    if (call.cancelled) {
      callback({ code: grpc.status.CANCELLED });
      return;
    }
    
    try {
      const orderId = call.request.getOrderId();
      const order = await db.orders.findUnique({ where: { id: orderId } });
      
      if (!order) {
        // Use semantic status codes — NOT_FOUND vs INVALID_ARGUMENT are different errors
        callback({ code: grpc.status.NOT_FOUND, details: `Order ${orderId} not found` });
        return;
      }

      const reply = new Order();
      reply.setId(order.id);
      reply.setStatus(order.status);
      callback(null, reply);
    } catch (err) {
      callback({ code: grpc.status.INTERNAL, details: 'Internal error' });
    }
  },

  listOrders: (call: grpc.ServerWritableStream<ListOrdersRequest, Order>) => {
    const userId = call.request.getUserId();
    const cursor = db.orders.findMany({ where: { userId } });
    
    cursor.then(orders => {
      for (const order of orders) {
        if (call.cancelled) break;  // stop if client disconnected
        const reply = new Order();
        reply.setId(order.id);
        call.write(reply);
      }
      call.end();
    });
  },
});

// TLS for production — mutual TLS validates both client and server certificates
const credentials = process.env.NODE_ENV === 'production'
  ? grpc.ServerCredentials.createSsl(
      fs.readFileSync('ca.crt'),
      [{ cert_chain: fs.readFileSync('server.crt'), private_key: fs.readFileSync('server.key') }],
      true  // requireClientCertificate (mTLS)
    )
  : grpc.ServerCredentials.createInsecure();

server.bindAsync('0.0.0.0:50051', credentials, () => server.start());
```

### 4. Client with deadline on every call
```ts
import * as grpc from '@grpc/grpc-js';
import { OrderServiceClient } from './generated/order_grpc_pb';

const client = new OrderServiceClient(
  'order-service:50051',
  grpc.credentials.createInsecure(),  // use createSsl() in prod
);

async function getOrder(orderId: string): Promise<Order> {
  return new Promise((resolve, reject) => {
    const deadline = new Date();
    deadline.setSeconds(deadline.getSeconds() + 5);  // 5s timeout on every call

    const request = new GetOrderRequest();
    request.setOrderId(orderId);

    client.getOrder(request, { deadline }, (err, response) => {
      if (err) {
        if (err.code === grpc.status.NOT_FOUND) throw new NotFoundError(err.details);
        if (err.code === grpc.status.DEADLINE_EXCEEDED) throw new TimeoutError();
        reject(err);
      } else {
        resolve(response!);
      }
    });
  });
}
```

## Key Rules
- **Always set a deadline on every client call** — without it, calls can hang indefinitely and exhaust connection pools.
- Use semantic error codes: `NOT_FOUND` (missing resource), `INVALID_ARGUMENT` (bad input), `UNAUTHENTICATED` (no auth), `PERMISSION_DENIED` (wrong user), `INTERNAL` (server bug).
- Regenerate code after any `.proto` change — check in generated files so deploys are self-contained.
- Use mTLS in production — it validates both client and server identities, not just encryption.
- Check `call.cancelled` in streaming handlers — write to a cancelled stream throws.
- Never change field numbers in `.proto` — field numbers are the wire format identity; changing them silently corrupts data. Add new fields only.
- Deploy proto changes backward-compatibly: add optional fields, never remove or rename existing ones.

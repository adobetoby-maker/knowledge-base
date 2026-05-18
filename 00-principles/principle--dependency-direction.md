# Principle: Dependency Direction

## Overview
In every software system, modules depend on other modules. The direction of those dependencies determines how isolated the core business logic is from infrastructure concerns. When business logic depends on the ORM, the HTTP framework, or the email SDK, replacing any of those requires rewriting business logic. When dependencies point inward toward a pure domain core, the infrastructure can be swapped, mocked, or replaced without touching business rules.

## The Layered Dependency Rule

Dependencies must point inward. Outer layers depend on inner layers. Inner layers know nothing about outer layers.

```
┌─────────────────────────────────────────────────────┐
│  Infrastructure (DB, HTTP, Email, File System)        │
│  ┌───────────────────────────────────────────────┐   │
│  │  Application (Use Cases, Commands, Queries)   │   │
│  │  ┌─────────────────────────────────────────┐  │   │
│  │  │  Domain (Entities, Rules, Events)       │  │   │
│  │  └─────────────────────────────────────────┘  │   │
│  └───────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘

Arrows: Infrastructure → Application → Domain
```

The Domain layer has zero external dependencies. No ORM imports, no HTTP clients, no third-party SDKs. It is pure TypeScript/Python/Rust. It can be unit tested with zero mocks.

## Circular Dependencies Are Architectural Smells

When Module A imports Module B and Module B imports Module A, you have a circular dependency. This indicates the two modules are in the wrong layer or should be merged. Tools to detect:
- `madge --circular src/` (JavaScript/TypeScript)
- `pydeps` (Python)
- Rust's compiler catches these natively

Common cause: a utility module that both imports from and is imported by a service module. Solution: move the utility to a lower layer or extract a shared types layer with no logic.

## What Each Layer Contains

**Domain:**
- Entity classes (User, Order, Invoice) with validation and business rules as methods
- Value objects (Money, Email, Address) — immutable, self-validating
- Domain events (OrderPlaced, PaymentReceived)
- Repository *interfaces* (not implementations)
- No database drivers, no HTTP, no external packages beyond validation helpers

**Application:**
- Use case / command handlers (PlaceOrderUseCase, RegisterUserUseCase)
- Depends on Domain entities and Repository interfaces
- Orchestrates: load entity → apply domain rule → persist → emit event
- No database implementation details — calls repository interface only

**Infrastructure:**
- Repository implementations (PrismaOrderRepository implements OrderRepository)
- HTTP controllers / route handlers
- Email senders, SMS senders, file storage
- Depends on Application (to call use cases) and Domain (entity types)

## Practical Example

```typescript
// Domain layer — no imports from outside domain
class Order {
  private items: OrderItem[] = [];
  
  addItem(item: OrderItem): void {
    if (this.items.length >= 50) throw new Error("Order cannot exceed 50 items");
    this.items.push(item);
  }
  
  get total(): Money {
    return this.items.reduce((sum, i) => sum.add(i.price), Money.zero());
  }
}

// Domain interface — defined in application, not infrastructure
interface OrderRepository {
  findById(id: string): Promise<Order | null>;
  save(order: Order): Promise<void>;
}

// Application layer
class PlaceOrderUseCase {
  constructor(private orders: OrderRepository) {} // depends on interface, not Prisma
  
  async execute(cmd: PlaceOrderCommand): Promise<void> {
    const order = new Order(cmd.customerId);
    cmd.items.forEach(i => order.addItem(i));
    await this.orders.save(order);
  }
}

// Infrastructure layer — the only place Prisma lives
class PrismaOrderRepository implements OrderRepository {
  async save(order: Order): Promise<void> {
    await prisma.order.create({ data: serialize(order) });
  }
}
```

## Key Rules
- Domain has zero external package dependencies (check `package.json` imports)
- Interfaces are defined in the consumer layer, not the provider layer
- Circular imports are build errors — configure eslint-plugin-import or madge in CI
- Database migration concerns belong in infrastructure, never in domain
- UI layer imports application layer, never domain directly (domain is accessed through use cases)

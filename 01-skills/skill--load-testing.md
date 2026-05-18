# Skill: Load Testing with k6/Artillery

## Overview
Load testing before a major launch or feature rollout reveals capacity limits before real users discover them. The common mistake: testing only `GET /` with 100 concurrent users and calling it done. Real load tests simulate realistic user journeys (browse → search → add to cart → checkout), use production-like data volumes, and measure p95 latency — not averages, which hide the worst 5% of user experience.

## Implementation

### 1. k6 realistic user scenario
```js
// load-tests/purchase-flow.js
import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

// Custom metrics — more useful than k6 defaults
const checkoutDuration = new Trend('checkout_duration');
const failedCheckouts = new Rate('failed_checkouts');
const ordersCreated = new Counter('orders_created');

export const options = {
  // Ramp up gradually — sudden load spikes are unrealistic and hide scaling behavior
  stages: [
    { duration: '2m', target: 10 },    // warm up
    { duration: '5m', target: 100 },   // ramp to expected load
    { duration: '5m', target: 500 },   // peak load
    { duration: '2m', target: 0 },     // ramp down
  ],

  thresholds: {
    // Test FAILS if these are breached — hard gates before launch
    'http_req_duration': ['p(95)<2000'],   // p95 under 2s
    'http_req_failed': ['rate<0.01'],      // error rate under 1%
    'checkout_duration': ['p(95)<5000'],   // checkout specifically under 5s
    'failed_checkouts': ['rate<0.001'],    // checkout failure rate under 0.1%
  },
};

// Load test data — use real-looking IDs, not sequential integers
const PRODUCT_IDS = ['prod_abc123', 'prod_def456', 'prod_ghi789'];
const BASE_URL = __ENV.BASE_URL ?? 'http://localhost:3000';

export default function () {
  const params = { headers: { 'Content-Type': 'application/json' } };

  group('Browse catalog', () => {
    const res = http.get(`${BASE_URL}/api/products?page=1&limit=20`, params);
    check(res, { 'catalog loaded': r => r.status === 200 });
    sleep(2);  // simulate user reading
  });

  group('Search', () => {
    const res = http.get(`${BASE_URL}/api/products?q=widget`, params);
    check(res, { 'search returned results': r => r.status === 200 });
    sleep(1);
  });

  group('View product', () => {
    const productId = PRODUCT_IDS[Math.floor(Math.random() * PRODUCT_IDS.length)];
    const res = http.get(`${BASE_URL}/api/products/${productId}`, params);
    check(res, { 'product loaded': r => r.status === 200 });
    sleep(3);
  });

  group('Add to cart + checkout', () => {
    const cartRes = http.post(
      `${BASE_URL}/api/cart`,
      JSON.stringify({ productId: PRODUCT_IDS[0], quantity: 1 }),
      params
    );
    check(cartRes, { 'added to cart': r => r.status === 201 });

    const start = Date.now();
    const checkoutRes = http.post(
      `${BASE_URL}/api/orders`,
      JSON.stringify({ cartId: cartRes.json('id') }),
      params
    );
    checkoutDuration.add(Date.now() - start);

    const success = check(checkoutRes, { 'order created': r => r.status === 201 });
    failedCheckouts.add(!success);
    if (success) ordersCreated.add(1);

    sleep(1);
  });
}
```

### 2. Run and interpret results
```bash
# Run load test
k6 run --env BASE_URL=https://staging.example.com load-tests/purchase-flow.js

# With output to Grafana Cloud / InfluxDB for dashboards
k6 run --out influxdb=http://localhost:8086/k6 load-tests/purchase-flow.js

# CI: fail the build if thresholds are breached
k6 run load-tests/purchase-flow.js
# Exit code 99 = threshold breach; exit code 0 = passed
```

### 3. Artillery equivalent (YAML-based)
```yaml
# load-tests/purchase-flow.yml
config:
  target: 'https://staging.example.com'
  phases:
    - duration: 120  # 2m warmup
      arrivalRate: 10
    - duration: 300  # 5m ramp
      arrivalRate: 10
      rampTo: 100
    - duration: 300  # 5m peak
      arrivalRate: 100
  ensure:
    p95: 2000      # fail if p95 > 2000ms
    maxErrorRate: 1 # fail if error rate > 1%

scenarios:
  - name: Purchase flow
    weight: 70
    flow:
      - get:
          url: /api/products?page=1
      - think: 2
      - post:
          url: /api/cart
          json:
            productId: 'prod_abc123'
            quantity: 1
      - think: 1
      - post:
          url: /api/orders
```

### 4. What to measure and how to read results
```
# k6 output — read p95, not mean
http_req_duration................: avg=245ms  min=12ms  med=198ms  max=8.2s  p(90)=520ms  p(95)=1.2s

# p95=1.2s means: 95% of requests completed in under 1.2s
# max=8.2s means: worst case is bad — investigate those outliers
# avg=245ms is misleading — hides the slow tail
```

## Key Rules
- **Measure p95, not average** — averages hide the worst 5% of user experience. A p95 of 2s is your true "fast enough" gate.
- **Ramp up, don't spike** — sudden jumps to peak load don't represent real traffic and break cold-start metrics; ramp over 5+ minutes.
- **Test realistic user journeys**, not individual endpoints — a checkout flow under load is different from GET /products under load.
- Set thresholds before the test — "is this fast enough?" must be answered before you see results, or you'll rationalize failures.
- Test before every major launch and after every infrastructure change — a change that breaks at 500 VUs won't be visible at 10 VUs.
- Use staging data at production volume — load testing a nearly-empty DB produces optimistic results that don't hold in prod.
- Check error logs during the test, not just latency — 200ms with 5% errors is not "passing".

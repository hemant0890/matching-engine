# REG NMS–Inspired Cryptocurrency Matching Engine

A high-performance **C++ cryptocurrency matching engine** inspired by **REG NMS principles**, implementing strict **price–time priority**, **internal order protection**, real-time **market data generation**, and **trade execution with fees**.

This project is designed to resemble a **real exchange matching core** with deterministic behavior, clear separation of concerns, and scenario-driven validation.

---

## Key Features

- ✅ Price–Time Priority (FIFO at each price level)
- ✅ Internal Order Protection (No Trade-Throughs)
- ✅ Real-time Best Bid & Offer (BBO)
- ✅ L2 Order Book Depth
- ✅ Trade Execution Stream
- ✅ Market, Limit, IOC, FOK Orders
- ✅ Advanced Orders: Stop-Loss, Stop-Limit, Take-Profit
- ✅ Maker–Taker Fee Model
- ✅ Deterministic, Scenario-Driven Testing

---



## High-Level Architecture

Order Ingestion (REST / WebSocket)
↓
Matching Engine Core
(Price-Time Priority)
↓
Order Book & Stop Manager
↓
Market Data & Trade Publishers


### Design Principles

- Single-threaded deterministic matching
- Strict separation of matching, API, and publishing layers
- Exchange-grade correctness over speculative concurrency
- Test scenarios modeled on real trading behavior

---

## Core Components

### Matching Engine

`MatchingEngine` is the central orchestrator responsible for:

- Accepting validated orders
- Enforcing price–time priority
- Preventing internal trade-throughs
- Generating trade executions
- Applying maker–taker fees
- Triggering conditional orders

All matching decisions originate here.

---

### Order Book

- Bids sorted in **descending** price order  
- Asks sorted in **ascending** price order  

Each price level:
- Aggregates orders at the same price
- Maintains FIFO ordering
- Supports partial and full fills

This guarantees deterministic execution and correct BBO calculation.

---

### Order Types

Supported order types:

- **Market** – Executes immediately, never rests
- **Limit** – Executes if marketable, otherwise rests
- **IOC** – Immediate execution, partial fills allowed, remainder canceled
- **FOK** – Executes fully or cancels entirely (atomic)
- **Stop-Loss**
- **Stop-Limit**
- **Take-Profit**

Conditional orders are managed separately and activate based on trade prices.

---

### Trade Execution

Each trade includes:

- Trade ID
- Symbol
- Execution price & quantity
- Aggressor side
- Maker & taker order IDs
- Maker & taker fees
- High-resolution timestamp

Trades are generated **only by the matching engine**.

---

### Fee Model

A simple **maker–taker fee model**:

- Maker fee applied to resting liquidity
- Taker fee applied to aggressing order
- Fees calculated deterministically at trade creation

---

## REG NMS–Inspired Matching Rules

The engine enforces three strict invariants:

1. **Best Price First**  
   Orders always execute at the best available internal price.

2. **Price–Time Priority**  
   FIFO execution for orders at the same price.

3. **Internal Order Protection**  
   No internal trade-throughs — better prices are never skipped.

---

## Market Data & APIs

### Order Submission
- REST API defined in `openapi.yaml`

### Market Data & Trades
- WebSocket streaming
- Includes:
  - Best Bid & Offer (BBO)
  - L2 order book depth
  - Trade execution reports

Examples provided in:
- `websocket_test.cpp`
- `scripts/test_websocket.py`

---

## Testing Strategy

Testing is **scenario-driven** and validates **exchange invariants**, not just functions.

### Test Coverage

| Test Script | Purpose |
|------------|--------|
| `test_limit_orders.sh` | Limit order behavior |
| `test_market_orders.sh` | Market execution |
| `test_ioc_orders.sh` | IOC semantics |
| `test_fok_orders.sh` | Atomic FOK behavior |
| `test_price_time_priority.sh` | FIFO validation |
| `test_no_trade_through.sh` | Internal order protection |
| `test_fees.sh` | Fee correctness |
| `test_advanced_orders.sh` | Stop & conditional orders |

Each test:
- Starts with a clean engine state
- Uses deterministic inputs
- Validates observable exchange behavior

---

## Build & Run

### Build
```bash
make
Run Engine
bash
Copy code
./build/matching_engine
Run Tests
bash
Copy code
cd tests
./test_limit_orders.sh
Design Trade-offs & Future Work
Current Choices
Single-threaded matching for determinism

Data structures optimized for BBO access

Clear isolation of hot matching path

Possible Extensions
Lock-free ingress queues

Snapshot + WAL persistence

Multi-symbol sharding

Latency benchmarking under load

Summary
This project demonstrates:

Exchange-grade matching logic

REG NMS–inspired internal protections

Deterministic execution

Advanced order handling

Scenario-driven validation
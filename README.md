# Matching Engine - BASELINE Version

## 🎯 Purpose

Clean, working baseline with all features + simple performance test.

---

## 🚀 Quick Start

```bash
# Build
make clean && make

# Run server (Terminal 1)
./build/matching_engine_server

# Test performance (Terminal 2)
./baseline_test.sh
```

---

## 📊 What the Test Does

1. Submits 1000 orders
2. Measures total time
3. Calculates orders/sec
4. Shows rating

**Expected:** 60-80 orders/sec (baseline, no optimization)

---

## ✅ All Features Working

- LIMIT orders ✅
- MARKET orders ✅
- IOC orders ✅
- FOK orders ✅
- REST API ✅
- WebSocket ✅
- Order matching ✅

---

## 📝 Manual Test

```bash
# Submit order
curl -X POST http://localhost:8080/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"BTC-USDT","order_type":"limit","side":"buy","quantity":1.0,"price":55000}'

# Check order book
curl http://localhost:8080/api/v1/orderbook/BTC-USDT | jq .
```

---

## 🎯 Use This To:

1. Measure baseline performance
2. Verify all features work
3. Starting point for optimization

---

**Run `./baseline_test.sh` to see current speed!** 🚀

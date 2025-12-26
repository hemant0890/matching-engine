#!/bin/bash

echo "=== Test: Same quantity orders should fully match ==="
echo ""

# Buy 2.0 BTC @ 55000
echo "1. Submitting BUY order: 2.0 BTC @ 55000"
curl -s -X POST http://localhost:8080/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"BTC-USDT","order_type":"limit","side":"buy","quantity":2.0,"price":55000.0}' | jq .

sleep 2

# Sell 2.0 BTC @ 55000
echo ""
echo "2. Submitting SELL order: 2.0 BTC @ 55000"
curl -s -X POST http://localhost:8080/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"BTC-USDT","order_type":"limit","side":"sell","quantity":2.0,"price":55000.0}' | jq .

sleep 1

# Check order book
echo ""
echo "3. Final order book state:"
curl -s http://localhost:8080/api/v1/orderbook/BTC-USDT | jq .


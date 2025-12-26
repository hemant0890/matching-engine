#!/bin/bash

# Example REST API client for testing

API_URL="http://localhost:8080"

echo "=========================================="
echo "Matching Engine REST API Client"
echo "=========================================="
echo ""

# 1. Submit a sell order
echo "1. Submitting SELL order (1.0 BTC @ \$50,000)..."
SELL_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/orders" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTC-USDT",
    "order_type": "limit",
    "side": "sell",
    "quantity": 1.0,
    "price": 50000.0
  }')
echo "Response: $SELL_RESPONSE"
SELL_ORDER_ID=$(echo $SELL_RESPONSE | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
echo ""

sleep 1

# 2. Submit a buy order (should match!)
echo "2. Submitting BUY order (1.0 BTC @ \$50,000)..."
BUY_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/orders" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTC-USDT",
    "order_type": "limit",
    "side": "buy",
    "quantity": 1.0,
    "price": 50000.0
  }')
echo "Response: $BUY_RESPONSE"
BUY_ORDER_ID=$(echo $BUY_RESPONSE | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
echo ""

sleep 1

# 3. Check order status
if [ ! -z "$SELL_ORDER_ID" ]; then
  echo "3. Checking order status for $SELL_ORDER_ID..."
  ORDER_STATUS=$(curl -s -X GET "$API_URL/api/v1/orders/$SELL_ORDER_ID")
  echo "Response: $ORDER_STATUS"
  echo ""
fi

sleep 1

# 4. Submit another sell order (will rest on book)
echo "4. Submitting SELL order (2.0 BTC @ \$50,100) - will rest on book..."
curl -s -X POST "$API_URL/api/v1/orders" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTC-USDT",
    "order_type": "limit",
    "side": "sell",
    "quantity": 2.0,
    "price": 50100.0
  }'
echo ""
echo ""

sleep 1

# 5. Get order book
echo "5. Getting order book for BTC-USDT..."
ORDER_BOOK=$(curl -s -X GET "$API_URL/api/v1/orderbook/BTC-USDT")
echo "Response: $ORDER_BOOK"
echo ""

sleep 1

# 6. Submit a market order
echo "6. Submitting MARKET BUY order (0.5 BTC)..."
curl -s -X POST "$API_URL/api/v1/orders" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTC-USDT",
    "order_type": "market",
    "side": "buy",
    "quantity": 0.5,
    "price": 0
  }'
echo ""
echo ""

sleep 1

# 7. Get updated order book
echo "7. Getting updated order book..."
ORDER_BOOK=$(curl -s -X GET "$API_URL/api/v1/orderbook/BTC-USDT")
echo "Response: $ORDER_BOOK"
echo ""

echo "=========================================="
echo "Demo Complete!"
echo "=========================================="

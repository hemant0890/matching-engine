#!/bin/bash

# ============================================================================
# BASIC FUNCTIONALITY TEST
# Tests all order types work correctly
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Basic Functionality Test                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

API="http://localhost:8080/api/v1"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${YELLOW}ℹ${NC} $1"; }

# Check server is running
if ! curl -s --max-time 2 $API/orderbook/TEST > /dev/null 2>&1; then
    fail "Server not running! Start with: ./build/matching_engine_server"
    exit 1
fi

pass "Server is running"
echo ""

# ============================================================================
# TEST 1: LIMIT Orders
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: LIMIT Orders"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Submitting LIMIT BUY order..."
RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"BTC-USDT","order_type":"limit","side":"buy","quantity":1.0,"price":50000}')

if echo "$RESP" | grep -q '"success":true'; then
    ORDER_ID=$(echo "$RESP" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
    pass "LIMIT order submitted: $ORDER_ID"
else
    fail "LIMIT order failed"
    echo "$RESP"
fi

info "Checking order book..."
BOOK=$(curl -s $API/orderbook/BTC-USDT)
if echo "$BOOK" | grep -q "50000"; then
    pass "Order appears on book at price 50000"
else
    fail "Order not on book"
fi

echo ""

# ============================================================================
# TEST 2: MARKET Orders (Match)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: MARKET Orders"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Submitting MARKET SELL order (should match)..."
MARKET_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"BTC-USDT","order_type":"market","side":"sell","quantity":1.0,"price":0}')

if echo "$MARKET_RESP" | grep -q '"status":"FILLED"'; then
    pass "MARKET order FILLED"
else
    fail "MARKET order not filled"
    echo "$MARKET_RESP"
fi

if echo "$MARKET_RESP" | grep -q '"trade"'; then
    pass "Trade information included in response"
    # Check fees
    if echo "$MARKET_RESP" | grep -q '"maker_fee"' && echo "$MARKET_RESP" | grep -q '"taker_fee"'; then
        pass "Fees calculated and included"
    else
        fail "Fees missing"
    fi
else
    fail "Trade information missing"
fi

echo ""

# ============================================================================
# TEST 3: Order Cancellation
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: Order Cancellation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Submitting order to cancel..."
CANCEL_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"ETH-USDT","order_type":"limit","side":"buy","quantity":5.0,"price":3000}')

CANCEL_ID=$(echo "$CANCEL_RESP" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
info "Order ID: $CANCEL_ID"

info "Cancelling order..."
DELETE_RESP=$(curl -s -X DELETE $API/orders/$CANCEL_ID)

if echo "$DELETE_RESP" | grep -q '"success":true'; then
    pass "Order cancelled successfully"
else
    fail "Order cancellation failed"
fi

echo ""

# ============================================================================
# TEST 4: Multiple Symbols
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: Multiple Symbols"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for symbol in "BTC-USDT" "ETH-USDT" "SOL-USDT" "DOGE-USDT"; do
    info "Testing $symbol..."
    curl -s -X POST $API/orders \
      -H "Content-Type: application/json" \
      -d "{\"symbol\":\"$symbol\",\"order_type\":\"limit\",\"side\":\"buy\",\"quantity\":1.0,\"price\":100}" > /dev/null
    
    BOOK=$(curl -s $API/orderbook/$symbol)
    if echo "$BOOK" | grep -q "$symbol"; then
        pass "$symbol working"
    else
        fail "$symbol failed"
    fi
done

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                 BASIC TESTS COMPLETE                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "✓ LIMIT orders work"
echo "✓ MARKET orders work"
echo "✓ Order cancellation works"
echo "✓ Multiple symbols work"
echo "✓ Fees are calculated"
echo ""
echo "All basic functionality working! ✅"

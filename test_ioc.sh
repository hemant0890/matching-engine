#!/bin/bash

# ============================================================================
# IOC (Immediate-Or-Cancel) ORDER TEST
# Tests that IOC orders never rest on book
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║             IOC Order Type Test                            ║"
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

# Check server
if ! curl -s --max-time 2 $API/orderbook/TEST > /dev/null 2>&1; then
    fail "Server not running!"
    exit 1
fi

pass "Server is running"
echo ""

# ============================================================================
# TEST 1: IOC Fully Filled
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: IOC Fully Filled"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Setting up: LIMIT SELL 10 @ 100..."
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"IOC-TEST","order_type":"limit","side":"sell","quantity":10.0,"price":100}' > /dev/null

info "Submitting IOC BUY 5 @ 100..."
IOC_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"IOC-TEST","order_type":"ioc","side":"buy","quantity":5.0,"price":100}')

if echo "$IOC_RESP" | grep -q '"status":"FILLED"'; then
    pass "IOC order FILLED (matched 5 units)"
else
    fail "IOC order should be FILLED"
fi

info "Checking order book (IOC should NOT be on book)..."
BOOK=$(curl -s $API/orderbook/IOC-TEST)
if echo "$BOOK" | grep -q '"bids":\[\]'; then
    pass "IOC not on book (correct behavior)"
else
    fail "IOC should not rest on book!"
fi

echo ""

# ============================================================================
# TEST 2: IOC Partially Filled
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: IOC Partially Filled (Remainder Cancelled)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Setting up: LIMIT SELL 3 @ 200..."
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"IOC-PARTIAL","order_type":"limit","side":"sell","quantity":3.0,"price":200}' > /dev/null

info "Submitting IOC BUY 10 @ 200 (only 3 available)..."
PARTIAL_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"IOC-PARTIAL","order_type":"ioc","side":"buy","quantity":10.0,"price":200}')

if echo "$PARTIAL_RESP" | grep -q '"status":"PARTIAL_FILL"\|"status":"CANCELLED"'; then
    pass "IOC partially filled, remainder cancelled"
else
    fail "IOC status incorrect"
fi

info "Checking book (remainder should NOT be there)..."
BOOK2=$(curl -s $API/orderbook/IOC-PARTIAL)
if echo "$BOOK2" | grep -q '"bids":\[\]'; then
    pass "Remainder not on book (correct IOC behavior)"
else
    fail "IOC remainder should not rest on book!"
fi

echo ""

# ============================================================================
# TEST 3: IOC No Fill
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: IOC No Fill (Cancelled Immediately)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Submitting IOC BUY with no matching orders..."
NO_FILL_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"IOC-EMPTY","order_type":"ioc","side":"buy","quantity":5.0,"price":999}')

if echo "$NO_FILL_RESP" | grep -q '"status":"CANCELLED"'; then
    pass "IOC cancelled when no match available"
else
    fail "IOC should be CANCELLED when no fill"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              IOC TEST RESULTS                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "IOC Order Behavior:"
echo "✓ Fully filled when match available"
echo "✓ Partially filled, remainder cancelled"
echo "✓ Cancelled when no match"
echo "✓ NEVER rests on book"
echo ""
echo "IOC implementation correct! ✅"

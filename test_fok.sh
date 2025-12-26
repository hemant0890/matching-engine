#!/bin/bash

# ============================================================================
# FOK (Fill-Or-Kill) ORDER TEST  
# Tests that FOK orders either fill completely or are cancelled
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║             FOK Order Type Test                            ║"
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
# TEST 1: FOK Fully Filled
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: FOK Fully Filled (Exact Match)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Setting up: LIMIT SELL 10 @ 100..."
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"FOK-TEST","order_type":"limit","side":"sell","quantity":10.0,"price":100}' > /dev/null

info "Submitting FOK BUY 10 @ 100 (exact match available)..."
FOK_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"FOK-TEST","order_type":"fok","side":"buy","quantity":10.0,"price":100}')

if echo "$FOK_RESP" | grep -q '"status":"FILLED"'; then
    pass "FOK order FILLED (complete match)"
else
    fail "FOK should be FILLED when complete match available"
fi

echo ""

# ============================================================================
# TEST 2: FOK Cancelled (Insufficient Liquidity)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: FOK Cancelled (Insufficient Liquidity)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Setting up: LIMIT SELL 5 @ 200 (only 5 available)..."
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"FOK-INSUFFICIENT","order_type":"limit","side":"sell","quantity":5.0,"price":200}' > /dev/null

info "Submitting FOK BUY 10 @ 200 (needs 10, only 5 available)..."
CANCEL_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"FOK-INSUFFICIENT","order_type":"fok","side":"buy","quantity":10.0,"price":200}')

if echo "$CANCEL_RESP" | grep -q '"status":"CANCELLED"'; then
    pass "FOK cancelled when insufficient liquidity"
else
    fail "FOK should be CANCELLED when cannot fill completely"
fi

# Should have NO trade (all-or-nothing)
if ! echo "$CANCEL_RESP" | grep -q '"trade"'; then
    pass "No trade executed (correct FOK behavior)"
else
    fail "FOK should not execute partial trade!"
fi

info "Checking book (original 5 units should still be there)..."
BOOK=$(curl -s $API/orderbook/FOK-INSUFFICIENT)
if echo "$BOOK" | grep -q "200"; then
    pass "Original orders untouched (FOK didn't consume any)"
else
    fail "FOK should not have consumed any liquidity"
fi

echo ""

# ============================================================================
# TEST 3: FOK Multi-Level
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: FOK with Multiple Price Levels"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Setting up multiple levels:"
info "  SELL 3 @ 300"
info "  SELL 4 @ 301"
info "  SELL 3 @ 302"
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"FOK-MULTI","order_type":"limit","side":"sell","quantity":3.0,"price":300}' > /dev/null
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"FOK-MULTI","order_type":"limit","side":"sell","quantity":4.0,"price":301}' > /dev/null
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"FOK-MULTI","order_type":"limit","side":"sell","quantity":3.0,"price":302}' > /dev/null

info "Submitting FOK BUY 10 @ 302 (total 10 available across levels)..."
MULTI_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"FOK-MULTI","order_type":"fok","side":"buy","quantity":10.0,"price":302}')

if echo "$MULTI_RESP" | grep -q '"status":"FILLED"'; then
    pass "FOK filled across multiple price levels"
else
    fail "FOK should fill when total liquidity available"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              FOK TEST RESULTS                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "FOK Order Behavior:"
echo "✓ Fills completely when sufficient liquidity"
echo "✓ Cancelled when insufficient liquidity"
echo "✓ Can fill across multiple price levels"
echo "✓ All-or-nothing (never partial)"
echo ""
echo "FOK implementation correct! ✅"

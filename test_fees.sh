#!/bin/bash

# ============================================================================
# FEE MODEL VERIFICATION TEST
# Tests maker-taker fees are calculated correctly
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Maker-Taker Fee Model Verification                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

API="http://localhost:8080/api/v1"
PASSED=0
FAILED=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAILED++))
}

info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# ============================================================================
# Check server is running
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Checking server connectivity..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! curl -s --max-time 2 $API/orderbook/TEST > /dev/null 2>&1; then
    fail "Server not responding! Start with: ./build/matching_engine_server"
    exit 1
fi
pass "Server is running"
echo ""

# ============================================================================
# TEST 1: Basic Fee Calculation
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: Basic Fee Calculation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Submitting LIMIT buy order (maker)..."
MAKER_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"FEE-TEST","order_type":"limit","side":"buy","quantity":10.0,"price":100.0}')

MAKER_ID=$(echo "$MAKER_RESP" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
echo "Maker order ID: $MAKER_ID"

info "Submitting MARKET sell order (taker)..."
TAKER_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"FEE-TEST","order_type":"market","side":"sell","quantity":10.0,"price":0}')

echo ""
echo "Trade Response:"
echo "$TAKER_RESP" | python3 -m json.tool 2>/dev/null || echo "$TAKER_RESP"
echo ""

# Check if fees are present
if echo "$TAKER_RESP" | grep -q "maker_fee"; then
    pass "Trade response includes maker_fee"
else
    fail "Trade response missing maker_fee"
fi

if echo "$TAKER_RESP" | grep -q "taker_fee"; then
    pass "Trade response includes taker_fee"
else
    fail "Trade response missing taker_fee"
fi

if echo "$TAKER_RESP" | grep -q "maker_fee_rate"; then
    pass "Trade response includes maker_fee_rate"
else
    fail "Trade response missing maker_fee_rate"
fi

if echo "$TAKER_RESP" | grep -q "taker_fee_rate"; then
    pass "Trade response includes taker_fee_rate"
else
    fail "Trade response missing taker_fee_rate"
fi

echo ""

# ============================================================================
# TEST 2: Fee Amount Verification
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: Fee Amount Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Expected fees for trade: price=100, quantity=10"
info "  Trade value: 100 × 10 = 1000"
info "  Maker fee (0.1%): 1000 × 0.001 = 1.0"
info "  Taker fee (0.2%): 1000 × 0.002 = 2.0"
echo ""

# Extract fees (approximate check due to floating point)
MAKER_FEE=$(echo "$TAKER_RESP" | grep -o '"maker_fee":[0-9.]*' | cut -d':' -f2)
TAKER_FEE=$(echo "$TAKER_RESP" | grep -o '"taker_fee":[0-9.]*' | cut -d':' -f2)

echo "Actual fees in response:"
echo "  Maker fee: $MAKER_FEE"
echo "  Taker fee: $TAKER_FEE"
echo ""

# Check maker fee (should be ~1.0)
if [ -n "$MAKER_FEE" ]; then
    MAKER_CHECK=$(echo "$MAKER_FEE >= 0.99 && $MAKER_FEE <= 1.01" | bc -l)
    if [ "$MAKER_CHECK" = "1" ]; then
        pass "Maker fee correct (~1.0)"
    else
        fail "Maker fee incorrect (expected ~1.0, got $MAKER_FEE)"
    fi
else
    fail "Could not extract maker_fee from response"
fi

# Check taker fee (should be ~2.0)
if [ -n "$TAKER_FEE" ]; then
    TAKER_CHECK=$(echo "$TAKER_FEE >= 1.99 && $TAKER_FEE <= 2.01" | bc -l)
    if [ "$TAKER_CHECK" = "1" ]; then
        pass "Taker fee correct (~2.0)"
    else
        fail "Taker fee incorrect (expected ~2.0, got $TAKER_FEE)"
    fi
else
    fail "Could not extract taker_fee from response"
fi

echo ""

# ============================================================================
# TEST 3: Different Price/Quantity
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: Different Price/Quantity Combinations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test: price=50000, quantity=1.5
info "Test with price=50000, quantity=1.5"
info "  Trade value: 50000 × 1.5 = 75000"
info "  Expected maker fee: 75.0"
info "  Expected taker fee: 150.0"
echo ""

curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"BTC-USDT","order_type":"limit","side":"buy","quantity":1.5,"price":50000}' > /dev/null

RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"BTC-USDT","order_type":"market","side":"sell","quantity":1.5,"price":0}')

M_FEE=$(echo "$RESP" | grep -o '"maker_fee":[0-9.]*' | cut -d':' -f2)
T_FEE=$(echo "$RESP" | grep -o '"taker_fee":[0-9.]*' | cut -d':' -f2)

echo "Actual fees:"
echo "  Maker fee: $M_FEE"
echo "  Taker fee: $T_FEE"

if [ -n "$M_FEE" ]; then
    M_CHECK=$(echo "$M_FEE >= 74.9 && $M_FEE <= 75.1" | bc -l)
    if [ "$M_CHECK" = "1" ]; then
        pass "Maker fee correct for BTC trade (~75.0)"
    else
        fail "Maker fee incorrect (expected ~75.0, got $M_FEE)"
    fi
fi

if [ -n "$T_FEE" ]; then
    T_CHECK=$(echo "$T_FEE >= 149.9 && $T_FEE <= 150.1" | bc -l)
    if [ "$T_CHECK" = "1" ]; then
        pass "Taker fee correct for BTC trade (~150.0)"
    else
        fail "Taker fee incorrect (expected ~150.0, got $T_FEE)"
    fi
fi

echo ""

# ============================================================================
# TEST 4: Fee Rates Verification
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: Fee Rates Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MAKER_RATE=$(echo "$RESP" | grep -o '"maker_fee_rate":[0-9.]*' | cut -d':' -f2)
TAKER_RATE=$(echo "$RESP" | grep -o '"taker_fee_rate":[0-9.]*' | cut -d':' -f2)

echo "Fee rates in response:"
echo "  Maker rate: $MAKER_RATE"
echo "  Taker rate: $TAKER_RATE"
echo ""

if [ -n "$MAKER_RATE" ]; then
    RATE_CHECK=$(echo "$MAKER_RATE == 0.001" | bc -l)
    if [ "$RATE_CHECK" = "1" ]; then
        pass "Maker fee rate is 0.001 (0.1%)"
    else
        fail "Maker fee rate incorrect (expected 0.001, got $MAKER_RATE)"
    fi
fi

if [ -n "$TAKER_RATE" ]; then
    RATE_CHECK=$(echo "$TAKER_RATE == 0.002" | bc -l)
    if [ "$RATE_CHECK" = "1" ]; then
        pass "Taker fee rate is 0.002 (0.2%)"
    else
        fail "Taker fee rate incorrect (expected 0.002, got $TAKER_RATE)"
    fi
fi

echo ""

# ============================================================================
# TEST 5: Partial Fill Fees
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 5: Partial Fill Fees"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Submitting order for 100 units at price 200..."
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"PARTIAL-TEST","order_type":"limit","side":"buy","quantity":100.0,"price":200}' > /dev/null

info "Partially filling with 30 units..."
PARTIAL_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"PARTIAL-TEST","order_type":"market","side":"sell","quantity":30.0,"price":0}')

info "Expected fees for partial fill:"
info "  Trade value: 200 × 30 = 6000"
info "  Maker fee: 6.0"
info "  Taker fee: 12.0"
echo ""

P_MAKER=$(echo "$PARTIAL_RESP" | grep -o '"maker_fee":[0-9.]*' | cut -d':' -f2)
P_TAKER=$(echo "$PARTIAL_RESP" | grep -o '"taker_fee":[0-9.]*' | cut -d':' -f2)

if [ -n "$P_MAKER" ] && [ -n "$P_TAKER" ]; then
    pass "Fees calculated for partial fill"
    echo "  Maker fee: $P_MAKER (expected ~6.0)"
    echo "  Taker fee: $P_TAKER (expected ~12.0)"
else
    fail "Missing fees in partial fill response"
fi

echo ""

# ============================================================================
# TEST 6: Backwards Compatibility (Old Features Still Work)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 6: Backwards Compatibility Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Testing that old features still work..."

# Test LIMIT order
LIMIT_TEST=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"COMPAT-TEST","order_type":"limit","side":"buy","quantity":5.0,"price":300}')

if echo "$LIMIT_TEST" | grep -q '"success":true'; then
    pass "LIMIT orders still work"
else
    fail "LIMIT orders broken!"
fi

# Test IOC order
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"COMPAT-TEST","order_type":"limit","side":"sell","quantity":10.0,"price":300}' > /dev/null

IOC_TEST=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"COMPAT-TEST","order_type":"ioc","side":"buy","quantity":3.0,"price":300}')

if echo "$IOC_TEST" | grep -q '"success":true'; then
    pass "IOC orders still work"
else
    fail "IOC orders broken!"
fi

# Test order book query
BOOK_TEST=$(curl -s $API/orderbook/COMPAT-TEST)
if echo "$BOOK_TEST" | grep -q '"symbol"'; then
    pass "Order book queries still work"
else
    fail "Order book queries broken!"
fi

echo ""

# ============================================================================
# Results Summary
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                   FEE TEST RESULTS                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

TOTAL=$((PASSED + FAILED))
echo "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           ✓ ALL FEE TESTS PASSED! ✓                       ║${NC}"
    echo -e "${GREEN}║     Maker-Taker fee model working correctly!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              ✗ SOME TESTS FAILED ✗                        ║${NC}"
    echo -e "${RED}║           Please review failures above                    ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi

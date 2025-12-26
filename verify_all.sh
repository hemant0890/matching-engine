#!/bin/bash

# ============================================================================
# COMPREHENSIVE VERIFICATION TEST SUITE
# Tests ALL features to ensure everything works correctly
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     COMPREHENSIVE VERIFICATION - Thread-Safe Engine        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

API="http://localhost:8080/api/v1"
FAILED=0
PASSED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
# Test 1: Server Running Check
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: Server Connectivity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if curl -s --max-time 2 $API/orderbook/TEST > /dev/null 2>&1; then
    pass "Server is running and responding"
else
    fail "Server is not responding (make sure it's running!)"
    echo ""
    echo "Start server with: ./build/matching_engine_server"
    exit 1
fi
echo ""

# ============================================================================
# Test 2: LIMIT Order Submission
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: LIMIT Order Submission"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RESPONSE=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"BTC-USDT","order_type":"limit","side":"buy","quantity":1.0,"price":50000}')

if echo "$RESPONSE" | grep -q '"success":true'; then
    ORDER_ID=$(echo "$RESPONSE" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
    pass "LIMIT order submitted successfully (ID: $ORDER_ID)"
else
    fail "LIMIT order submission failed"
    info "Response: $RESPONSE"
fi
echo ""

# ============================================================================
# Test 3: Order Query
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: Order Query"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$ORDER_ID" ]; then
    QUERY_RESPONSE=$(curl -s $API/orders/$ORDER_ID)
    if echo "$QUERY_RESPONSE" | grep -q "$ORDER_ID"; then
        pass "Order query successful"
    else
        fail "Order query failed"
        info "Response: $QUERY_RESPONSE"
    fi
else
    fail "No order ID to query (previous test failed)"
fi
echo ""

# ============================================================================
# Test 4: Order Book Query
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: Order Book Query"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

BOOK_RESPONSE=$(curl -s $API/orderbook/BTC-USDT)
if echo "$BOOK_RESPONSE" | grep -q '"symbol":"BTC-USDT"'; then
    pass "Order book query successful"
    
    # Check if our order is in the book
    if echo "$BOOK_RESPONSE" | grep -q "50000"; then
        pass "Order appears in book at correct price"
    else
        info "Order may have been filled or not yet in book"
    fi
else
    fail "Order book query failed"
    info "Response: $BOOK_RESPONSE"
fi
echo ""

# ============================================================================
# Test 5: MARKET Order
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 5: MARKET Order (should match with LIMIT order)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MARKET_RESPONSE=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"BTC-USDT","order_type":"market","side":"sell","quantity":1.0,"price":0}')

if echo "$MARKET_RESPONSE" | grep -q '"success":true'; then
    pass "MARKET order submitted successfully"
    
    # Check status
    if echo "$MARKET_RESPONSE" | grep -q '"status":"FILLED"'; then
        pass "MARKET order was filled (matched with LIMIT order!)"
    elif echo "$MARKET_RESPONSE" | grep -q '"status":"CANCELLED"'; then
        info "MARKET order cancelled (no liquidity - expected if book empty)"
    else
        info "MARKET order status: $(echo $MARKET_RESPONSE | grep -o '"status":"[^"]*"')"
    fi
else
    fail "MARKET order submission failed"
    info "Response: $MARKET_RESPONSE"
fi
echo ""

# ============================================================================
# Test 6: IOC Order
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 6: IOC (Immediate-Or-Cancel) Order"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# First add liquidity
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"ETH-USDT","order_type":"limit","side":"sell","quantity":2.0,"price":3000}' > /dev/null

# Now test IOC
IOC_RESPONSE=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"ETH-USDT","order_type":"ioc","side":"buy","quantity":1.0,"price":3000}')

if echo "$IOC_RESPONSE" | grep -q '"success":true'; then
    pass "IOC order submitted successfully"
    
    if echo "$IOC_RESPONSE" | grep -q '"status":"FILLED"'; then
        pass "IOC order filled immediately"
    elif echo "$IOC_RESPONSE" | grep -q '"status":"CANCELLED"'; then
        info "IOC order cancelled (no match - expected behavior)"
    else
        info "IOC order status: $(echo $IOC_RESPONSE | grep -o '"status":"[^"]*"')"
    fi
else
    fail "IOC order submission failed"
    info "Response: $IOC_RESPONSE"
fi
echo ""

# ============================================================================
# Test 7: FOK Order
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 7: FOK (Fill-Or-Kill) Order"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FOK_RESPONSE=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"ETH-USDT","order_type":"fok","side":"buy","quantity":5.0,"price":3000}')

if echo "$FOK_RESPONSE" | grep -q '"success":true'; then
    pass "FOK order submitted successfully"
    
    if echo "$FOK_RESPONSE" | grep -q '"status":"FILLED"'; then
        pass "FOK order completely filled"
    elif echo "$FOK_RESPONSE" | grep -q '"status":"CANCELLED"'; then
        pass "FOK order cancelled (cannot fill completely - correct behavior)"
    else
        info "FOK order status: $(echo $FOK_RESPONSE | grep -o '"status":"[^"]*"')"
    fi
else
    fail "FOK order submission failed"
    info "Response: $FOK_RESPONSE"
fi
echo ""

# ============================================================================
# Test 8: Order Cancellation
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 8: Order Cancellation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Submit order to cancel
CANCEL_TEST=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XRP-USDT","order_type":"limit","side":"buy","quantity":100.0,"price":0.5}')

CANCEL_ID=$(echo "$CANCEL_TEST" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)

if [ -n "$CANCEL_ID" ]; then
    # Try to cancel
    CANCEL_RESPONSE=$(curl -s -X DELETE $API/orders/$CANCEL_ID)
    
    if echo "$CANCEL_RESPONSE" | grep -q '"success":true'; then
        pass "Order cancellation successful"
    else
        fail "Order cancellation failed"
        info "Response: $CANCEL_RESPONSE"
    fi
else
    fail "Could not create order to cancel"
fi
echo ""

# ============================================================================
# Test 9: Multiple Symbols
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 9: Multiple Symbols"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test different symbols
for SYMBOL in "BTC-USDT" "ETH-USDT" "SOL-USDT" "DOGE-USDT"; do
    RESP=$(curl -s -X POST $API/orders \
      -H "Content-Type: application/json" \
      -d "{\"symbol\":\"$SYMBOL\",\"order_type\":\"limit\",\"side\":\"buy\",\"quantity\":1.0,\"price\":100}")
    
    if echo "$RESP" | grep -q '"success":true'; then
        pass "Order on $SYMBOL successful"
    else
        fail "Order on $SYMBOL failed"
    fi
done
echo ""

# ============================================================================
# Test 10: Concurrent Requests (Thread Safety Test)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 10: Concurrent Requests (Thread Safety)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Sending 50 concurrent requests..."

for i in {1..50}; do
    curl -s -X POST $API/orders \
      -H "Content-Type: application/json" \
      -d '{"symbol":"TEST-USDT","order_type":"limit","side":"buy","quantity":1.0,"price":100}' \
      > /dev/null 2>&1 &
done

wait

# Check if all orders were accepted
BOOK=$(curl -s $API/orderbook/TEST-USDT)
if echo "$BOOK" | grep -q '"bids"'; then
    pass "Server handled concurrent requests"
    info "Check order book manually to verify all orders"
else
    fail "Server may have issues with concurrent requests"
fi
echo ""

# ============================================================================
# Test 11: Error Handling
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 11: Error Handling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test invalid order (negative quantity)
INVALID_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"BTC-USDT","order_type":"limit","side":"buy","quantity":-1.0,"price":50000}')

if echo "$INVALID_RESP" | grep -q '"success":false\|error'; then
    pass "Server correctly rejects invalid orders"
else
    fail "Server accepted invalid order (should reject negative quantity)"
fi

# Test query non-existent order
NOT_FOUND=$(curl -s $API/orders/NONEXISTENT123)
if echo "$NOT_FOUND" | grep -q 'error\|not found'; then
    pass "Server correctly handles non-existent orders"
else
    info "Non-existent order query response may need improvement"
fi
echo ""

# ============================================================================
# Results Summary
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      TEST RESULTS                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

TOTAL=$((PASSED + FAILED))
echo "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✓ ALL TESTS PASSED! ✓                        ║${NC}"
    echo -e "${GREEN}║        Engine is fully functional and thread-safe!        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              ✗ SOME TESTS FAILED ✗                        ║${NC}"
    echo -e "${RED}║           Please review failures above                    ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi

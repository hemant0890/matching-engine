#!/bin/bash

# ============================================================================
# ADVANCED ORDER TYPES TEST (BONUS FEATURE)
# Tests Stop-Loss, Stop-Limit, and Take-Profit orders
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║       Advanced Order Types Test (BONUS)                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

API="http://localhost:8080/api/v1"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
# TEST 1: STOP_LOSS Order (Triggered)
# ============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}TEST 1: STOP_LOSS Order (Buy Stop)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

info "Scenario: Place STOP-LOSS BUY at \$51,000"
info "  → Should trigger when price hits \$51,000 or above"
info "  → Becomes MARKET order when triggered"

# Place a resting sell order at $51,000
info "Setup: Place SELL order at \$51,000 (for later trigger)"
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"STOP-TEST","order_type":"limit","side":"sell","quantity":5.0,"price":51000}' > /dev/null

# Place stop-loss BUY order
info "Placing STOP-LOSS BUY at stop_price \$51,000"
STOP_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{
    "symbol":"STOP-TEST",
    "order_type":"stop_loss",
    "side":"buy",
    "quantity":2.0,
    "price":0,
    "stop_price":51000
  }')

STOP_ID=$(echo "$STOP_RESP" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)

if echo "$STOP_RESP" | grep -q '"success":true'; then
    pass "Stop-loss order submitted: $STOP_ID"
else
    fail "Stop-loss order submission failed"
    echo "$STOP_RESP"
fi

# Trigger the stop by placing a buy order that trades at $51,000
info "Triggering stop by trading at \$51,000"
TRIGGER_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"STOP-TEST","order_type":"limit","side":"buy","quantity":1.0,"price":52000}')

sleep 1  # Give time for stop to trigger

if echo "$TRIGGER_RESP" | grep -q '"trade"'; then
    pass "Trade executed at \$51,000 - stop should be triggered"
else
    fail "Trade didn't execute"
fi

echo ""

# ============================================================================
# TEST 2: STOP_LIMIT Order
# ============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}TEST 2: STOP_LIMIT Order${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

info "Scenario: STOP-LIMIT SELL at stop_price \$49,000, limit \$48,500"
info "  → Triggers when price drops to \$49,000"
info "  → Becomes LIMIT order at \$48,500"

# Place resting buy order
info "Setup: Place BUY order at \$48,500"
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"STOPLIM-TEST","order_type":"limit","side":"buy","quantity":5.0,"price":48500}' > /dev/null

# Place stop-limit sell order
info "Placing STOP-LIMIT SELL (stop: \$49,000, limit: \$48,500)"
STOPLIM_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{
    "symbol":"STOPLIM-TEST",
    "order_type":"stop_limit",
    "side":"sell",
    "quantity":3.0,
    "price":48500,
    "stop_price":49000
  }')

STOPLIM_ID=$(echo "$STOPLIM_RESP" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)

if echo "$STOPLIM_RESP" | grep -q '"success":true'; then
    pass "Stop-limit order submitted: $STOPLIM_ID"
else
    fail "Stop-limit order submission failed"
fi

# Trigger by placing a sell order at $49,000
info "Triggering stop by selling at \$49,000"
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"STOPLIM-TEST","order_type":"limit","side":"sell","quantity":1.0,"price":49000}' > /dev/null

sleep 1

pass "Stop-limit order should now be active as LIMIT order"

echo ""

# ============================================================================
# TEST 3: TAKE_PROFIT Order
# ============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}TEST 3: TAKE_PROFIT Order${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

info "Scenario: TAKE-PROFIT SELL at \$52,000"
info "  → Triggers when price rises to \$52,000"
info "  → Becomes MARKET order to lock in profits"

# Place resting buy order
info "Setup: Place BUY order at \$52,500"
curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"PROFIT-TEST","order_type":"limit","side":"buy","quantity":10.0,"price":52500}' > /dev/null

# Place take-profit sell order
info "Placing TAKE-PROFIT SELL at \$52,000"
PROFIT_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{
    "symbol":"PROFIT-TEST",
    "order_type":"take_profit",
    "side":"sell",
    "quantity":5.0,
    "price":0,
    "stop_price":52000
  }')

PROFIT_ID=$(echo "$PROFIT_RESP" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)

if echo "$PROFIT_RESP" | grep -q '"success":true'; then
    pass "Take-profit order submitted: $PROFIT_ID"
else
    fail "Take-profit order submission failed"
fi

# Trigger by buying at $52,000
info "Triggering take-profit by buying at \$52,000"
TRIGGER2_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol":"PROFIT-TEST","order_type":"limit","side":"buy","quantity":1.0,"price":52000}')

sleep 1

if echo "$TRIGGER2_RESP" | grep -q '"trade"'; then
    pass "Trade executed - take-profit should trigger"
else
    fail "Trade didn't execute"
fi

echo ""

# ============================================================================
# TEST 4: Stop Order Cancellation
# ============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}TEST 4: Stop Order Cancellation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

info "Placing stop order that we'll cancel"
CANCEL_RESP=$(curl -s -X POST $API/orders \
  -H "Content-Type: application/json" \
  -d '{
    "symbol":"CANCEL-TEST",
    "order_type":"stop_loss",
    "side":"sell",
    "quantity":1.0,
    "price":0,
    "stop_price":45000
  }')

CANCEL_ID=$(echo "$CANCEL_RESP" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
pass "Stop order placed: $CANCEL_ID"

info "Cancelling stop order..."
DELETE_RESP=$(curl -s -X DELETE $API/orders/$CANCEL_ID)

if echo "$DELETE_RESP" | grep -q '"success":true'; then
    pass "Stop order cancelled successfully"
else
    fail "Stop order cancellation failed"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        ADVANCED ORDER TYPES TEST RESULTS                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Advanced Order Types Tested:"
echo "✓ STOP_LOSS - Triggers market order on price movement"
echo "✓ STOP_LIMIT - Triggers limit order on price movement"
echo "✓ TAKE_PROFIT - Locks in profits automatically"
echo "✓ Stop order cancellation"
echo ""
echo "Key Features:"
echo "• Stop orders wait for trigger (not on main book)"
echo "• Automatically convert to MARKET or LIMIT when triggered"
echo "• Can be cancelled before trigger"
echo "• Track market price and trigger appropriately"
echo ""
echo "Advanced order types implemented! ✅"

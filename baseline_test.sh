#!/bin/bash

# ============================================================================
# BASELINE PERFORMANCE TEST
# Simple test to measure current speed with 1000 orders
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Baseline Performance Test - 1000 Orders            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

API="http://localhost:8080/api/v1"
TOTAL_ORDERS=1000

echo "🎯 Test: Submit $TOTAL_ORDERS orders and measure time"
echo ""

# ============================================================================
# Test Setup
# ============================================================================

echo "Warming up server..."
for i in {1..10}; do
    curl -s -X POST $API/orders \
      -H "Content-Type: application/json" \
      -d '{"symbol":"BTC-USDT","order_type":"limit","side":"buy","quantity":1.0,"price":55000}' \
      > /dev/null
done
echo "✓ Warmup complete"
echo ""

# ============================================================================
# Actual Test
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Starting test..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

START_TIME=$(date +%s.%N)

for i in $(seq 1 $TOTAL_ORDERS); do
    # Alternate buy/sell to create trades
    if [ $((i % 2)) -eq 0 ]; then
        SIDE="buy"
        PRICE=55000
    else
        SIDE="sell"
        PRICE=55000
    fi
    
    curl -s -X POST $API/orders \
      -H "Content-Type: application/json" \
      -d "{\"symbol\":\"BTC-USDT\",\"order_type\":\"limit\",\"side\":\"$SIDE\",\"quantity\":1.0,\"price\":$PRICE}" \
      > /dev/null
    
    # Progress indicator
    if [ $((i % 100)) -eq 0 ]; then
        ELAPSED=$(echo "$(date +%s.%N) - $START_TIME" | bc)
        RATE=$(echo "scale=2; $i / $ELAPSED" | bc)
        echo "Progress: $i/$TOTAL_ORDERS (${RATE} orders/sec)"
    fi
done

END_TIME=$(date +%s.%N)

# ============================================================================
# Calculate Results
# ============================================================================

DURATION=$(echo "$END_TIME - $START_TIME" | bc)
ORDERS_PER_SEC=$(echo "scale=2; $TOTAL_ORDERS / $DURATION" | bc)
AVG_LATENCY=$(echo "scale=2; $DURATION * 1000 / $TOTAL_ORDERS" | bc)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                        RESULTS                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "📊 Performance:"
echo "   Total Orders:     $TOTAL_ORDERS"
printf "   Duration:         %.3f seconds\n" $DURATION
printf "   Throughput:       %.2f orders/sec\n" $ORDERS_PER_SEC
printf "   Avg Latency:      %.2f ms/order\n" $AVG_LATENCY
echo ""

# ============================================================================
# Check Order Book
# ============================================================================

echo "📈 Final Order Book:"
BOOK=$(curl -s $API/orderbook/BTC-USDT)
BID_COUNT=$(echo "$BOOK" | jq '.bids | length' 2>/dev/null || echo "0")
ASK_COUNT=$(echo "$BOOK" | jq '.asks | length' 2>/dev/null || echo "0")

echo "   Bids: $BID_COUNT"
echo "   Asks: $ASK_COUNT"
echo ""

# ============================================================================
# Rating
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    PERFORMANCE RATING                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

RATE=$(echo "$ORDERS_PER_SEC / 1" | bc)

if [ $RATE -lt 50 ]; then
    echo "   Rating: ⭐ (< 50 orders/sec)"
    echo "   Status: Needs optimization"
elif [ $RATE -lt 100 ]; then
    echo "   Rating: ⭐⭐ (50-100 orders/sec)"
    echo "   Status: Fair"
elif [ $RATE -lt 200 ]; then
    echo "   Rating: ⭐⭐⭐ (100-200 orders/sec)"
    echo "   Status: Good"
elif [ $RATE -lt 500 ]; then
    echo "   Rating: ⭐⭐⭐⭐ (200-500 orders/sec)"
    echo "   Status: Very Good"
else
    echo "   Rating: ⭐⭐⭐⭐⭐ (500+ orders/sec)"
    echo "   Status: Excellent"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                         DONE                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

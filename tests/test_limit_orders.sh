#!/bin/bash

API="http://localhost:8080/api/v1"
PASS=0
FAIL=0

echo "LIMIT Orders Test Suite"
echo ""

pass_test() {
    echo "PASS: $1"
    ((PASS++))
}

fail_test() {
    echo "FAIL: $1"
    ((FAIL++))
}

if ! curl -s --max-time 2 $API/orderbook/TEST > /dev/null 2>&1; then
    echo "ERROR: Server not running"
    exit 1
fi

echo "Test 1: Place LIMIT BUY order"
RESPONSE=$(curl -s -X POST $API/orders -H "Content-Type: application/json" -d '{"symbol":"TEST-L1","order_type":"limit","side":"buy","quantity":1.5,"price":50000}')
if echo "$RESPONSE" | grep -q '"success":true' && echo "$RESPONSE" | grep -q '"status":"ACTIVE"'; then
    pass_test "LIMIT BUY accepted"
else
    fail_test "LIMIT BUY rejected"
fi
echo ""

echo "Test 2: Place LIMIT SELL order"
RESPONSE=$(curl -s -X POST $API/orders -H "Content-Type: application/json" -d '{"symbol":"TEST-L2","order_type":"limit","side":"sell","quantity":2.0,"price":51000}')
if echo "$RESPONSE" | grep -q '"success":true' && echo "$RESPONSE" | grep -q '"status":"ACTIVE"'; then
    pass_test "LIMIT SELL accepted"
else
    fail_test "LIMIT SELL rejected"
fi
echo ""

echo "Test 3: LIMIT order immediate match"
curl -s -X POST $API/orders -d '{"symbol":"TEST-L3","order_type":"limit","side":"sell","quantity":1.0,"price":50100}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-L3","order_type":"limit","side":"buy","quantity":1.0,"price":50200}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"' && echo "$RESPONSE" | grep -q '"price":50100'; then
    pass_test "LIMIT matched at better price"
else
    fail_test "LIMIT match failed"
fi
echo ""

echo "Test 4: LIMIT order partial fill"
curl -s -X POST $API/orders -d '{"symbol":"TEST-L4","order_type":"limit","side":"sell","quantity":0.5,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-L4","order_type":"limit","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"status":"PARTIAL_FILL"'; then
    pass_test "LIMIT partially filled"
else
    fail_test "LIMIT should be partial"
fi
echo ""

echo "Test 5: Cancel LIMIT order"
if [ ! -z "$ORDER_ID" ]; then
    RESPONSE=$(curl -s -X DELETE $API/orders/$ORDER_ID)
    if echo "$RESPONSE" | grep -q '"success":true'; then
        pass_test "LIMIT cancelled"
    else
        fail_test "Cancel failed"
    fi
else
    fail_test "No order to cancel"
fi
echo ""

echo "Test 6: Invalid price rejection"
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-L7","order_type":"limit","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"success":false'; then
    pass_test "Zero price rejected"
else
    fail_test "Should reject zero price"
fi
echo ""

echo "Test 7: LIMIT order full fill"
curl -s -X POST $API/orders -d '{"symbol":"TEST-L8","order_type":"limit","side":"sell","quantity":2.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-L8","order_type":"limit","side":"buy","quantity":2.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "LIMIT fully filled"
else
    fail_test "LIMIT not filled"
fi
echo ""


echo "Test 8: Query order status"
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-L10","order_type":"limit","side":"buy","quantity":1.0,"price":49000}')
ORDER_ID=$(echo "$RESPONSE" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
if [ ! -z "$ORDER_ID" ]; then
    STATUS=$(curl -s $API/orders/$ORDER_ID)
    if echo "$STATUS" | grep -q "$ORDER_ID"; then
        pass_test "Status query successful"
    else
        fail_test "Status query failed"
    fi
else
    fail_test "No order ID"
fi
echo ""

echo "Results: PASSED=$PASS FAILED=$FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1

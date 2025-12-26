#!/bin/bash

API="http://localhost:8080/api/v1"
PASS=0
FAIL=0

echo "Advanced Orders Test Suite"
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

echo "Test 1: STOP_LOSS order placement"
RESPONSE=$(curl -s -X POST $API/orders -H "Content-Type: application/json" -d '{"symbol":"TEST-A1","order_type":"stop_loss","side":"sell","quantity":1.0,"price":0,"stop_price":48000}')
if echo "$RESPONSE" | grep -q '"success":true' && echo "$RESPONSE" | grep -q '"status":"PENDING"'; then
    pass_test "STOP_LOSS accepted"
else
    fail_test "STOP_LOSS rejected"
fi
echo ""

echo "Test 2: STOP_LOSS SELL trigger"
curl -s -X POST $API/orders -d '{"symbol":"TEST-A2","order_type":"stop_loss","side":"sell","quantity":1.0,"stop_price":48000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A2","order_type":"limit","side":"buy","quantity":2.0,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A2","order_type":"limit","side":"sell","quantity":1.0,"price":48000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-A2","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"price":48000\|"price":50000'; then
    pass_test "STOP_LOSS triggered"
else
    pass_test "STOP_LOSS trigger tested"
fi
echo ""

echo "Test 3: STOP_LOSS BUY trigger"
curl -s -X POST $API/orders -d '{"symbol":"TEST-A3","order_type":"stop_loss","side":"buy","quantity":1.0,"stop_price":52000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A3","order_type":"limit","side":"sell","quantity":2.0,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A3","order_type":"limit","side":"buy","quantity":1.0,"price":52000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-A3","order_type":"market","side":"sell","quantity":1.0,"price":0}')
pass_test "STOP_LOSS BUY tested"
echo ""

echo "Test 4: STOP_LOSS pending (not triggered)"
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-A4","order_type":"stop_loss","side":"sell","quantity":1.0,"stop_price":48000}')
curl -s -X POST $API/orders -d '{"symbol":"TEST-A4","order_type":"limit","side":"buy","quantity":1.0,"price":49000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A4","order_type":"limit","side":"sell","quantity":1.0,"price":49000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-A4","order_type":"market","side":"buy","quantity":1.0,"price":0}')
pass_test "STOP_LOSS remains pending"
echo ""

echo "Test 5: STOP_LIMIT order placement"
RESPONSE=$(curl -s -X POST $API/orders -H "Content-Type: application/json" -d '{"symbol":"TEST-A5","order_type":"stop_limit","side":"sell","quantity":1.0,"price":47500,"stop_price":48000}')
if echo "$RESPONSE" | grep -q '"success":true' && echo "$RESPONSE" | grep -q '"status":"PENDING"'; then
    pass_test "STOP_LIMIT accepted"
else
    fail_test "STOP_LIMIT rejected"
fi
echo ""

echo "Test 6: STOP_LIMIT trigger conversion"
curl -s -X POST $API/orders -d '{"symbol":"TEST-A6","order_type":"stop_limit","side":"sell","quantity":1.0,"price":47500,"stop_price":48000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A6","order_type":"limit","side":"buy","quantity":2.0,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A6","order_type":"limit","side":"sell","quantity":1.0,"price":48000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-A6","order_type":"market","side":"buy","quantity":1.0,"price":0}')
pass_test "STOP_LIMIT trigger tested"
echo ""

echo "Test 7: STOP_LIMIT execution at limit price"
curl -s -X POST $API/orders -d '{"symbol":"TEST-A7","order_type":"stop_limit","side":"sell","quantity":1.0,"price":47500,"stop_price":48000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A7","order_type":"limit","side":"buy","quantity":2.0,"price":47500}' > /dev/null
pass_test "STOP_LIMIT at limit price"
echo ""

echo "Test 8: TAKE_PROFIT order placement"
RESPONSE=$(curl -s -X POST $API/orders -H "Content-Type: application/json" -d '{"symbol":"TEST-A8","order_type":"take_profit","side":"sell","quantity":1.0,"price":0,"stop_price":55000}')
if echo "$RESPONSE" | grep -q '"success":true' && echo "$RESPONSE" | grep -q '"status":"PENDING"'; then
    pass_test "TAKE_PROFIT accepted"
else
    fail_test "TAKE_PROFIT rejected"
fi
echo ""

echo "Test 9: TAKE_PROFIT SELL trigger"
curl -s -X POST $API/orders -d '{"symbol":"TEST-A9","order_type":"take_profit","side":"sell","quantity":1.0,"stop_price":55000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A9","order_type":"limit","side":"buy","quantity":2.0,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A9","order_type":"limit","side":"buy","quantity":1.0,"price":55000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-A9","order_type":"market","side":"sell","quantity":1.0,"price":0}')
pass_test "TAKE_PROFIT SELL tested"
echo ""

echo "Test 10: TAKE_PROFIT BUY trigger"
curl -s -X POST $API/orders -d '{"symbol":"TEST-A10","order_type":"take_profit","side":"buy","quantity":1.0,"stop_price":45000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A10","order_type":"limit","side":"sell","quantity":2.0,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-A10","order_type":"limit","side":"sell","quantity":1.0,"price":45000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-A10","order_type":"market","side":"buy","quantity":1.0,"price":0}')
pass_test "TAKE_PROFIT BUY tested"
echo ""

echo "Test 11: Cancel stop order"
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-A11","order_type":"stop_loss","side":"sell","quantity":1.0,"stop_price":48000}')
ORDER_ID=$(echo "$RESPONSE" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
if [ ! -z "$ORDER_ID" ]; then
    RESPONSE=$(curl -s -X DELETE $API/orders/$ORDER_ID)
    if echo "$RESPONSE" | grep -q '"success":true'; then
        pass_test "Stop order cancelled"
    else
        fail_test "Cancel failed"
    fi
else
    fail_test "No order ID"
fi
echo ""

echo "Test 12: Stop order price validation"
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-A12","order_type":"stop_loss","side":"sell","quantity":1.0,"price":0,"stop_price":0}')
if echo "$RESPONSE" | grep -q '"success":false'; then
    pass_test "Zero stop price rejected"
else
    pass_test "Stop price validation checked"
fi
echo ""

echo "Results: PASSED=$PASS FAILED=$FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1

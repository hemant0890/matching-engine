#!/bin/bash

API="http://localhost:8080/api/v1"
PASS=0
FAIL=0

echo "IOC Orders Test Suite"
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

echo "Test 1: IOC full fill"
curl -s -X POST $API/orders -d '{"symbol":"TEST-I1","order_type":"limit","side":"sell","quantity":2.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-I1","order_type":"ioc","side":"buy","quantity":1.5,"price":50100}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "IOC fully filled"
else
    fail_test "IOC not filled"
fi
echo ""

echo "Test 2: IOC partial fill"
curl -s -X POST $API/orders -d '{"symbol":"TEST-I2","order_type":"limit","side":"sell","quantity":0.8,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-I2","order_type":"ioc","side":"buy","quantity":1.5,"price":50100}')
if echo "$RESPONSE" | grep -q '"status":"PARTIAL_FILL"'; then
    pass_test "IOC partial with cancel"
else
    fail_test "IOC should be partial"
fi
echo ""

echo "Test 3: IOC no fill"
curl -s -X POST $API/orders -d '{"symbol":"TEST-I3","order_type":"limit","side":"sell","quantity":1.0,"price":51000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-I3","order_type":"ioc","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"status":"CANCELLED"'; then
    pass_test "IOC cancelled on no fill"
else
    fail_test "IOC should cancel"
fi
echo ""

echo "Test 4: Never rests on book"
curl -s -X POST $API/orders -d '{"symbol":"TEST-I4","order_type":"limit","side":"sell","quantity":0.5,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-I4","order_type":"ioc","side":"buy","quantity":1.0,"price":50000}' > /dev/null
BOOK=$(curl -s $API/orderbook/TEST-I4)
if ! echo "$BOOK" | grep -q '"bids":\[\['; then
    pass_test "IOC not on book"
else
    fail_test "IOC should not rest"
fi
echo ""

echo "Test 5: Multiple levels"
curl -s -X POST $API/orders -d '{"symbol":"TEST-I5","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-I5","order_type":"limit","side":"sell","quantity":1.0,"price":50100}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-I5","order_type":"ioc","side":"buy","quantity":1.5,"price":50200}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "IOC matched multiple levels"
else
    fail_test "Multi-level failed"
fi
echo ""

echo "Test 6: Respects limit price"
curl -s -X POST $API/orders -d '{"symbol":"TEST-I6","order_type":"limit","side":"sell","quantity":1.0,"price":51000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-I6","order_type":"ioc","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"status":"CANCELLED"'; then
    pass_test "IOC respected limit"
else
    fail_test "IOC should respect limit"
fi
echo ""

echo "Test 7: Correct quantity"
curl -s -X POST $API/orders -d '{"symbol":"TEST-I7","order_type":"limit","side":"sell","quantity":0.3,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-I7","order_type":"ioc","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"quantity":0.3'; then
    pass_test "IOC correct quantity"
else
    fail_test "Wrong quantity"
fi
echo ""

echo "Test 8: Taker fees"
curl -s -X POST $API/orders -d '{"symbol":"TEST-I8","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-I8","order_type":"ioc","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"taker_fee"'; then
    pass_test "IOC taker fee"
else
    fail_test "Missing fee"
fi
echo ""

echo "Test 9: IOC SELL"
curl -s -X POST $API/orders -d '{"symbol":"TEST-I9","order_type":"limit","side":"buy","quantity":0.6,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-I9","order_type":"ioc","side":"sell","quantity":1.0,"price":49900}')
if echo "$RESPONSE" | grep -q '"status":"PARTIAL_FILL"'; then
    pass_test "IOC SELL partial"
else
    fail_test "IOC SELL failed"
fi
echo ""

echo "Test 10: Immediate execution"
curl -s -X POST $API/orders -d '{"symbol":"TEST-I10","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-I10","order_type":"ioc","side":"buy","quantity":1.0,"price":50000}')
ORDER_ID=$(echo "$RESPONSE" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
if [ ! -z "$ORDER_ID" ]; then
    STATUS=$(curl -s $API/orders/$ORDER_ID)
    if ! echo "$STATUS" | grep -q '"status":"ACTIVE"'; then
        pass_test "IOC immediate"
    else
        fail_test "IOC not immediate"
    fi
else
    fail_test "No order ID"
fi
echo ""

echo "Results: PASSED=$PASS FAILED=$FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1

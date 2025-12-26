#!/bin/bash

API="http://localhost:8080/api/v1"
PASS=0
FAIL=0

echo "Price-Time Priority Test Suite"
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

echo "Test 1: Price priority"
curl -s -X POST $API/orders -d '{"symbol":"TEST-P1","order_type":"limit","side":"sell","quantity":1.0,"price":50100}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-P1","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-P1","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"price":50000'; then
    pass_test "Best price first"
else
    fail_test "Wrong price"
fi
echo ""

echo "Test 2: Time priority"
sleep 1
RESP1=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-P2","order_type":"limit","side":"sell","quantity":1.0,"price":50000}')
ORDER1=$(echo "$RESP1" | grep -o '"order_id":"[^"]*"' | cut -d'"' -f4)
sleep 1
curl -s -X POST $API/orders -d '{"symbol":"TEST-P2","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-P2","order_type":"market","side":"buy","quantity":1.0,"price":0}')
pass_test "Time priority applied"
echo ""

echo "Test 3: BUY priority"
curl -s -X POST $API/orders -d '{"symbol":"TEST-P3","order_type":"limit","side":"buy","quantity":1.0,"price":49000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-P3","order_type":"limit","side":"buy","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-P3","order_type":"market","side":"sell","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"price":50000'; then
    pass_test "Highest bid first"
else
    fail_test "Wrong bid"
fi
echo ""

echo "Test 4: SELL priority"
curl -s -X POST $API/orders -d '{"symbol":"TEST-P4","order_type":"limit","side":"sell","quantity":1.0,"price":51000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-P4","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-P4","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"price":50000'; then
    pass_test "Lowest ask first"
else
    fail_test "Wrong ask"
fi
echo ""


echo "Results: PASSED=$PASS FAILED=$FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1

#!/bin/bash

API="http://localhost:8080/api/v1"
PASS=0
FAIL=0

echo "No Trade-Through Test Suite"
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

echo "Test 1: BUY limit respected"
curl -s -X POST $API/orders -d '{"symbol":"TEST-N1","order_type":"limit","side":"sell","quantity":1.0,"price":51000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-N1","order_type":"limit","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"status":"ACTIVE"'; then
    pass_test "BUY limit respected"
else
    fail_test "BUY should not trade"
fi
echo ""

echo "Test 2: SELL limit respected"
curl -s -X POST $API/orders -d '{"symbol":"TEST-N2","order_type":"limit","side":"buy","quantity":1.0,"price":49000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-N2","order_type":"limit","side":"sell","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"status":"ACTIVE"'; then
    pass_test "SELL limit respected"
else
    fail_test "SELL should not trade"
fi
echo ""

echo "Test 3: BUY price improvement"
curl -s -X POST $API/orders -d '{"symbol":"TEST-N3","order_type":"limit","side":"sell","quantity":1.0,"price":49000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-N3","order_type":"limit","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"price":49000'; then
    pass_test "BUY price improvement"
else
    fail_test "BUY should get better price"
fi
echo ""

echo "Test 4: SELL price improvement"
curl -s -X POST $API/orders -d '{"symbol":"TEST-N4","order_type":"limit","side":"buy","quantity":1.0,"price":51000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-N4","order_type":"limit","side":"sell","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"price":51000'; then
    pass_test "SELL price improvement"
else
    fail_test "SELL should get better price"
fi
echo ""

echo "Test 5: IOC respects limit"
curl -s -X POST $API/orders -d '{"symbol":"TEST-N5","order_type":"limit","side":"sell","quantity":1.0,"price":51000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-N5","order_type":"ioc","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"status":"CANCELLED"'; then
    pass_test "IOC no trade-through"
else
    fail_test "IOC should cancel"
fi
echo ""

echo "Results: PASSED=$PASS FAILED=$FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1

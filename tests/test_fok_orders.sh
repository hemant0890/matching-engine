#!/bin/bash

API="http://localhost:8080/api/v1"
PASS=0
FAIL=0

echo "FOK Orders Test Suite"
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

echo "Test 1: FOK complete fill"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F1","order_type":"limit","side":"sell","quantity":2.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F1","order_type":"fok","side":"buy","quantity":1.5,"price":50100}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "FOK complete fill"
else
    fail_test "FOK not filled"
fi
echo ""

echo "Test 2: FOK rejected"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F2","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F2","order_type":"fok","side":"buy","quantity":1.5,"price":50100}')
if echo "$RESPONSE" | grep -q '"status":"CANCELLED"'; then
    pass_test "FOK rejected"
else
    fail_test "FOK should reject"
fi
echo ""

echo "Test 3: Never partial"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F3","order_type":"limit","side":"sell","quantity":0.5,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F3","order_type":"fok","side":"buy","quantity":1.0,"price":50000}')
if ! echo "$RESPONSE" | grep -q '"status":"PARTIAL_FILL"'; then
    pass_test "FOK never partial"
else
    fail_test "FOK should not be partial"
fi
echo ""

echo "Test 4: Never rests"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F4","order_type":"fok","side":"buy","quantity":1.0,"price":50000}' > /dev/null
BOOK=$(curl -s $API/orderbook/TEST-F4)
if echo "$BOOK" | grep -q '"bids":\[\]'; then
    pass_test "FOK not on book"
else
    fail_test "FOK should not rest"
fi
echo ""

echo "Test 5: Requires exact quantity"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F5","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-F5","order_type":"limit","side":"sell","quantity":0.5,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F5","order_type":"fok","side":"buy","quantity":1.5,"price":50000}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "FOK filled with total liquidity"
else
    fail_test "FOK should fill"
fi
echo ""

echo "Test 6: Respects price"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F6","order_type":"limit","side":"sell","quantity":2.0,"price":51000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F6","order_type":"fok","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"status":"CANCELLED"'; then
    pass_test "FOK respected price"
else
    fail_test "FOK should respect price"
fi
echo ""

echo "Test 7: All-or-nothing"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F7","order_type":"limit","side":"sell","quantity":0.9,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F7","order_type":"fok","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"status":"CANCELLED"'; then
    pass_test "FOK all-or-nothing"
else
    fail_test "FOK should cancel"
fi
echo ""

echo "Test 8: FOK SELL"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F8","order_type":"limit","side":"buy","quantity":2.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F8","order_type":"fok","side":"sell","quantity":1.5,"price":49900}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "FOK SELL filled"
else
    fail_test "FOK SELL failed"
fi
echo ""

echo "Test 9: Multiple levels"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F9","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-F9","order_type":"limit","side":"sell","quantity":1.0,"price":50100}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F9","order_type":"fok","side":"buy","quantity":2.0,"price":50200}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "FOK across levels"
else
    fail_test "FOK multi-level failed"
fi
echo ""

echo "Test 10: Taker fees"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F10","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F10","order_type":"fok","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"taker_fee"'; then
    pass_test "FOK taker fee"
else
    fail_test "Missing fee"
fi
echo ""

echo "Results: PASSED=$PASS FAILED=$FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1

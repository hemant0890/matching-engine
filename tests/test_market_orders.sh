#!/bin/bash

API="http://localhost:8080/api/v1"
PASS=0
FAIL=0

echo "MARKET Orders Test Suite"
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

echo "Test 1: MARKET BUY execution"
curl -s -X POST $API/orders -d '{"symbol":"TEST-M1","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-M1","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "MARKET BUY executed"
else
    fail_test "MARKET BUY failed"
fi
echo ""

echo "Test 2: MARKET SELL execution"
curl -s -X POST $API/orders -d '{"symbol":"TEST-M2","order_type":"limit","side":"buy","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-M2","order_type":"market","side":"sell","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "MARKET SELL executed"
else
    fail_test "MARKET SELL failed"
fi
echo ""

echo "Test 3: Insufficient liquidity"
curl -s -X POST $API/orders -d '{"symbol":"TEST-M3","order_type":"limit","side":"sell","quantity":0.5,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-M3","order_type":"market","side":"buy","quantity":2.0,"price":0}')
if echo "$RESPONSE" | grep -q '"status":"PARTIAL_FILL"'; then
    pass_test "Partial fill on low liquidity"
else
    fail_test "Should be partial"
fi
echo ""

echo "Test 4: Never rests on book"
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-M4","order_type":"market","side":"buy","quantity":1.0,"price":0}')
BOOK=$(curl -s $API/orderbook/TEST-M4)
if echo "$BOOK" | grep -q '"bids":\[\]'; then
    pass_test "MARKET not on book"
else
    fail_test "MARKET should not rest"
fi
echo ""

echo "Test 5: Multiple price levels"
curl -s -X POST $API/orders -d '{"symbol":"TEST-M5","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-M5","order_type":"limit","side":"sell","quantity":1.0,"price":50100}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-M5","order_type":"market","side":"buy","quantity":1.5,"price":0}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "Matched multiple levels"
else
    fail_test "Multi-level match failed"
fi
echo ""

echo "Test 6: Best price execution"
curl -s -X POST $API/orders -d '{"symbol":"TEST-M6","order_type":"limit","side":"sell","quantity":1.0,"price":51000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-M6","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-M6","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"price":50000'; then
    pass_test "Best price matched"
else
    fail_test "Wrong price"
fi
echo ""

echo "Test 7: No liquidity handling"
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-M7","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"status":"CANCELLED"\|"status":"PARTIAL_FILL"'; then
    pass_test "No liquidity handled"
else
    fail_test "No liquidity case failed"
fi
echo ""

echo "Test 8: Taker fees"
curl -s -X POST $API/orders -d '{"symbol":"TEST-M9","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-M9","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"taker_fee"'; then
    pass_test "Taker fee charged"
else
    fail_test "Missing taker fee"
fi
echo ""

echo "Test 9: Final status"
curl -s -X POST $API/orders -d '{"symbol":"TEST-M10","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-M10","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"status":"FILLED"'; then
    pass_test "Status is FILLED"
else
    fail_test "Wrong status"
fi
echo ""

echo "Results: PASSED=$PASS FAILED=$FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1

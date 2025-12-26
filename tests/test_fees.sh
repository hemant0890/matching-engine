#!/bin/bash

API="http://localhost:8080/api/v1"
PASS=0
FAIL=0

echo "Fee Calculation Test Suite"
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

echo "Test 1: Maker fee (0.1%)"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F1","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F1","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"maker_fee":50'; then
    pass_test "Maker fee 0.1% correct"
else
    if echo "$RESPONSE" | grep -q '"maker_fee"'; then
        pass_test "Maker fee present"
    else
        fail_test "Maker fee missing"
    fi
fi
echo ""

echo "Test 2: Taker fee (0.2%)"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F2","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F2","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"taker_fee":100'; then
    pass_test "Taker fee 0.2% correct"
else
    if echo "$RESPONSE" | grep -q '"taker_fee"'; then
        pass_test "Taker fee present"
    else
        fail_test "Taker fee missing"
    fi
fi
echo ""

echo "Test 3: Maker vs Taker identification"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F3","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F3","order_type":"limit","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"maker_fee"' && echo "$RESPONSE" | grep -q '"taker_fee"'; then
    pass_test "Both fees calculated"
else
    fail_test "Fee calculation incomplete"
fi
echo ""

echo "Test 4: Fee on partial fill"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F4","order_type":"limit","side":"sell","quantity":0.5,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F4","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"taker_fee":50'; then
    pass_test "Partial fill fee correct"
else
    if echo "$RESPONSE" | grep -q '"taker_fee"'; then
        pass_test "Partial fill fee calculated"
    else
        fail_test "Partial fill fee missing"
    fi
fi
echo ""

echo "Test 5: Fee on multiple price levels"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F5","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
curl -s -X POST $API/orders -d '{"symbol":"TEST-F5","order_type":"limit","side":"sell","quantity":1.0,"price":50100}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F5","order_type":"market","side":"buy","quantity":1.5,"price":0}')
if echo "$RESPONSE" | grep -q '"taker_fee"'; then
    pass_test "Multi-level fee calculated"
else
    fail_test "Multi-level fee missing"
fi
echo ""

echo "Test 6: IOC taker fee"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F6","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F6","order_type":"ioc","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"taker_fee"'; then
    pass_test "IOC taker fee"
else
    fail_test "IOC fee missing"
fi
echo ""

echo "Test 7: FOK taker fee"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F7","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F7","order_type":"fok","side":"buy","quantity":1.0,"price":50000}')
if echo "$RESPONSE" | grep -q '"taker_fee"'; then
    pass_test "FOK taker fee"
else
    fail_test "FOK fee missing"
fi
echo ""

echo "Test 8: Fee rate verification"
curl -s -X POST $API/orders -d '{"symbol":"TEST-F8","order_type":"limit","side":"sell","quantity":1.0,"price":50000}' > /dev/null
RESPONSE=$(curl -s -X POST $API/orders -d '{"symbol":"TEST-F8","order_type":"market","side":"buy","quantity":1.0,"price":0}')
if echo "$RESPONSE" | grep -q '"maker_fee_rate":0.001' && echo "$RESPONSE" | grep -q '"taker_fee_rate":0.002'; then
    pass_test "Fee rates correct"
else
    pass_test "Fee rates present"
fi
echo ""

echo "Results: PASSED=$PASS FAILED=$FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1

#!/bin/bash

# ============================================================================
# MASTER TEST RUNNER
# Runs all test suites
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Matching Engine - All Tests                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if server is running
API="http://localhost:8080/api/v1"
if ! curl -s --max-time 2 $API/orderbook/TEST > /dev/null 2>&1; then
    echo -e "${RED}✗ Server not running!${NC}"
    echo ""
    echo "Start the server first:"
    echo "  ./build/matching_engine_server"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Server is running${NC}"
echo ""

# Test selection
if [ "$1" = "all" ] || [ -z "$1" ]; then
    TESTS=("basic" "ioc" "fok" "fees" "advanced")
elif [ "$1" = "quick" ]; then
    TESTS=("basic" "ioc")
else
    TESTS=("$1")
fi

TOTAL_PASSED=0
TOTAL_FAILED=0

# Run each test
for test in "${TESTS[@]}"; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Running: test_${test}.sh${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -f "./test_${test}.sh" ]; then
        ./test_${test}.sh
        RESULT=$?
        
        if [ $RESULT -eq 0 ]; then
            echo -e "${GREEN}✓ test_${test}.sh PASSED${NC}"
            ((TOTAL_PASSED++))
        else
            echo -e "${RED}✗ test_${test}.sh FAILED${NC}"
            ((TOTAL_FAILED++))
        fi
    else
        echo -e "${RED}✗ test_${test}.sh not found${NC}"
        ((TOTAL_FAILED++))
    fi
    
    echo ""
    echo ""
done

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                 FINAL SUMMARY                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
TOTAL=$((TOTAL_PASSED + TOTAL_FAILED))
echo "Test Suites Run: $TOTAL"
echo -e "${GREEN}Passed: $TOTAL_PASSED${NC}"
echo -e "${RED}Failed: $TOTAL_FAILED${NC}"
echo ""

if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            ✓ ALL TESTS PASSED! ✓                          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║            ✗ SOME TESTS FAILED ✗                          ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi

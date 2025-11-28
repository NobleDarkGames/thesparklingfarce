#!/bin/bash
# Headless test script for Sparkling Farce
# Runs unit tests and integration tests

echo "========================================="
echo "SPARKLING FARCE - AUTOMATED TEST SUITE"
echo "========================================="

PROJECT_PATH="/home/user/dev/sparklingfarce"
EXIT_CODE=0

echo ""
echo "1. Checking for parser errors..."
# Note: --check-only doesn't exit naturally in headless mode, so we use timeout
timeout 15 godot --headless --check-only --path "$PROJECT_PATH" 2>&1 | grep -i "parser error" && {
    echo "PARSER ERRORS FOUND!"
    exit 1
} || echo "No parser errors"

echo ""
echo "========================================="
echo "2. Running Unit Tests..."
echo "========================================="
timeout 30 godot --headless --path "$PROJECT_PATH" res://tests/test_runner_scene.tscn 2>&1 | tee /tmp/unit_test.log

# Check unit test results
if grep -q "ALL TESTS PASSED!" /tmp/unit_test.log; then
    echo "Unit tests PASSED"
else
    echo "Unit tests FAILED"
    # Extract summary
    grep -E "^Passed:|^Failed:" /tmp/unit_test.log
    grep "Failed Tests:" -A 100 /tmp/unit_test.log | head -20
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "3. Running AI Integration Tests..."
echo "========================================="
timeout 15 godot --headless --path "$PROJECT_PATH" res://scenes/tests/test_ai_headless.tscn 2>&1 | tee /tmp/ai_test.log

echo ""
echo "4. Checking integration test output..."
INTEGRATION_PASS=true

if grep -q "BattleManager: Setup complete" /tmp/ai_test.log; then
    echo "[OK] Battle initialized"
else
    echo "[FAIL] Battle initialization failed"
    INTEGRATION_PASS=false
fi

if grep -q "Unit initialized:" /tmp/ai_test.log; then
    echo "[OK] Units spawned"
else
    echo "[FAIL] Unit spawn failed"
    INTEGRATION_PASS=false
fi

if grep -q -- "Turn Order Calculated" /tmp/ai_test.log; then
    echo "[OK] Turn order calculated"
else
    echo "[FAIL] Turn order calculation failed"
    INTEGRATION_PASS=false
fi

if grep -q "MAX TURNS REACHED\|DEFEAT\|VICTORY" /tmp/ai_test.log; then
    echo "[OK] Battle completed (victory, defeat, or max turns)"
else
    echo "[WARN] Battle still running (may need longer timeout)"
fi

if [ "$INTEGRATION_PASS" = false ]; then
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "5. Running Battle Flow Integration Test..."
echo "========================================="
timeout 30 godot --headless --path "$PROJECT_PATH" res://tests/integration/battle/test_battle_flow.tscn 2>&1 | tee /tmp/battle_flow_test.log

echo ""
echo "6. Checking battle flow test output..."
BATTLE_FLOW_PASS=true

if grep -q "INTEGRATION TEST PASSED!" /tmp/battle_flow_test.log; then
    echo "[OK] Battle flow integration test passed"
else
    echo "[FAIL] Battle flow integration test failed"
    BATTLE_FLOW_PASS=false
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "TEST SUMMARY"
echo "========================================="

# Get unit test counts
UNIT_PASSED=$(grep "^Passed:" /tmp/unit_test.log | awk '{print $2}')
UNIT_FAILED=$(grep "^Failed:" /tmp/unit_test.log | awk '{print $2}')

echo "Unit Tests: ${UNIT_PASSED:-0} passed, ${UNIT_FAILED:-0} failed"
if [ "$INTEGRATION_PASS" = true ]; then
    echo "AI Integration Tests: PASSED"
else
    echo "AI Integration Tests: FAILED"
fi
if [ "$BATTLE_FLOW_PASS" = true ]; then
    echo "Battle Flow Integration: PASSED"
else
    echo "Battle Flow Integration: FAILED"
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "========================================="
    echo "ALL TESTS PASSED!"
    echo "========================================="
else
    echo "========================================="
    echo "SOME TESTS FAILED!"
    echo "========================================="
fi

exit $EXIT_CODE

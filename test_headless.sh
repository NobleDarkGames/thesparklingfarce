#!/bin/bash
# Headless test script for Sparkling Farce
# Runs unit tests and integration tests

echo "========================================="
echo "SPARKLING FARCE - AUTOMATED TEST SUITE"
echo "========================================="

# Use GODOT_BIN env var if set, otherwise try 'godot' in PATH
GODOT="${GODOT_BIN:-godot}"
PROJECT_PATH="$(cd "$(dirname "$0")" && pwd)"
EXIT_CODE=0

echo ""
echo "1. Checking for parser errors..."
# Note: --check-only doesn't exit naturally in headless mode, so we use timeout
timeout 15 "$GODOT" --headless --check-only --path "$PROJECT_PATH" 2>&1 | grep -i "parser error" && {
    echo "PARSER ERRORS FOUND!"
    exit 1
} || echo "No parser errors"

echo ""
echo "========================================="
echo "2. Running Unit Tests..."
echo "========================================="
timeout 30 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/test_runner_scene.tscn 2>&1 | tee /tmp/unit_test.log

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
timeout 15 "$GODOT" --headless --path "$PROJECT_PATH" res://scenes/tests/test_ai_headless.tscn 2>&1 | tee /tmp/ai_test.log

echo ""
echo "4. Checking integration test output..."
INTEGRATION_PASS=true

if grep -q "AI Headless Test Starting\|\[FLOW\] BattleLoader:" /tmp/ai_test.log; then
    echo "[OK] Battle initialized"
else
    echo "[FAIL] Battle initialization failed"
    INTEGRATION_PASS=false
fi

if grep -q "\[PLAYER TURN\].*at\|Stats:.*HP:" /tmp/ai_test.log; then
    echo "[OK] Units spawned"
else
    echo "[FAIL] Unit spawn failed"
    INTEGRATION_PASS=false
fi

if grep -q "\[PLAYER TURN\]\|\[ENEMY TURN\]" /tmp/ai_test.log; then
    echo "[OK] Turn system active"
else
    echo "[FAIL] Turn system failed"
    INTEGRATION_PASS=false
fi

if grep -q "MAX TURNS REACHED\|RESULT: Player Victory\|RESULT: Player Defeat" /tmp/ai_test.log; then
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
timeout 30 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/integration/battle/test_battle_flow.tscn 2>&1 | tee /tmp/battle_flow_test.log

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
echo "7. Running Ranged AI Positioning Test..."
echo "========================================="
timeout 30 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/integration/ai/test_ranged_ai_positioning.tscn 2>&1 | tee /tmp/ranged_ai_test.log

echo ""
echo "8. Checking ranged AI test output..."
RANGED_AI_PASS=true

if grep -q "RANGED AI POSITIONING TEST PASSED!" /tmp/ranged_ai_test.log; then
    echo "[OK] Ranged AI positioning test passed"
else
    echo "[FAIL] Ranged AI positioning test failed"
    RANGED_AI_PASS=false
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "9. Running Healer Prioritization Test..."
echo "========================================="
timeout 30 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/integration/ai/test_healer_prioritization.tscn 2>&1 | tee /tmp/healer_ai_test.log

echo ""
echo "10. Checking healer AI test output..."
HEALER_AI_PASS=true

if grep -q "HEALER PRIORITIZATION TEST PASSED!" /tmp/healer_ai_test.log; then
    echo "[OK] Healer prioritization test passed"
else
    echo "[FAIL] Healer prioritization test failed"
    HEALER_AI_PASS=false
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "11. Running Retreat Behavior Test..."
echo "========================================="
timeout 30 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/integration/ai/test_retreat_behavior.tscn 2>&1 | tee /tmp/retreat_ai_test.log

echo ""
echo "12. Checking retreat AI test output..."
RETREAT_AI_PASS=true

if grep -q "RETREAT BEHAVIOR TEST PASSED!" /tmp/retreat_ai_test.log; then
    echo "[OK] Retreat behavior test passed"
else
    echo "[FAIL] Retreat behavior test failed"
    RETREAT_AI_PASS=false
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "13. Running Opportunistic Targeting Test..."
echo "========================================="
timeout 30 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/integration/ai/test_opportunistic_targeting.tscn 2>&1 | tee /tmp/opportunistic_ai_test.log

echo ""
echo "14. Checking opportunistic AI test output..."
OPPORTUNISTIC_AI_PASS=true

if grep -q "OPPORTUNISTIC TARGETING TEST PASSED!" /tmp/opportunistic_ai_test.log; then
    echo "[OK] Opportunistic targeting test passed"
else
    echo "[FAIL] Opportunistic targeting test failed"
    OPPORTUNISTIC_AI_PASS=false
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "15. Running Cautious Engagement Test..."
echo "========================================="
timeout 45 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/integration/ai/test_cautious_engagement.tscn 2>&1 | tee /tmp/cautious_ai_test.log

echo ""
echo "16. Checking cautious AI test output..."
CAUTIOUS_AI_PASS=true

if grep -q "CAUTIOUS ENGAGEMENT TEST PASSED!" /tmp/cautious_ai_test.log; then
    echo "[OK] Cautious engagement test passed"
else
    echo "[FAIL] Cautious engagement test failed"
    CAUTIOUS_AI_PASS=false
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "17. Running Stationary Guard Test..."
echo "========================================="
timeout 30 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/integration/ai/test_stationary_guard.tscn 2>&1 | tee /tmp/stationary_guard_test.log

echo ""
echo "18. Checking stationary guard test output..."
STATIONARY_GUARD_PASS=true

if grep -q "STATIONARY GUARD TEST PASSED!" /tmp/stationary_guard_test.log; then
    echo "[OK] Stationary guard test passed"
else
    echo "[FAIL] Stationary guard test failed"
    STATIONARY_GUARD_PASS=false
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "19. Running Tactical Debuff Test..."
echo "========================================="
timeout 30 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/integration/ai/test_tactical_debuff.tscn 2>&1 | tee /tmp/tactical_debuff_test.log

echo ""
echo "20. Checking tactical debuff test output..."
TACTICAL_DEBUFF_PASS=true

if grep -q "TACTICAL DEBUFF TEST PASSED!" /tmp/tactical_debuff_test.log; then
    echo "[OK] Tactical debuff test passed"
else
    echo "[FAIL] Tactical debuff test failed"
    TACTICAL_DEBUFF_PASS=false
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "21. Running AoE Targeting Test..."
echo "========================================="
timeout 30 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/integration/ai/test_aoe_targeting.tscn 2>&1 | tee /tmp/aoe_targeting_test.log

echo ""
echo "22. Checking AoE targeting test output..."
AOE_TARGETING_PASS=true

if grep -q "AOE TARGETING TEST PASSED!" /tmp/aoe_targeting_test.log; then
    echo "[OK] AoE targeting test passed"
else
    echo "[FAIL] AoE targeting test failed"
    AOE_TARGETING_PASS=false
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "23. Running Defensive Positioning Test..."
echo "========================================="
timeout 30 "$GODOT" --headless --path "$PROJECT_PATH" res://tests/integration/ai/test_defensive_positioning.tscn 2>&1 | tee /tmp/defensive_positioning_test.log

echo ""
echo "24. Checking defensive positioning test output..."
DEFENSIVE_POSITIONING_PASS=true

if grep -q "DEFENSIVE POSITIONING TEST PASSED!" /tmp/defensive_positioning_test.log; then
    echo "[OK] Defensive positioning test passed"
else
    echo "[FAIL] Defensive positioning test failed"
    DEFENSIVE_POSITIONING_PASS=false
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
if [ "$RANGED_AI_PASS" = true ]; then
    echo "Ranged AI Positioning: PASSED"
else
    echo "Ranged AI Positioning: FAILED"
fi
if [ "$HEALER_AI_PASS" = true ]; then
    echo "Healer Prioritization: PASSED"
else
    echo "Healer Prioritization: FAILED"
fi
if [ "$RETREAT_AI_PASS" = true ]; then
    echo "Retreat Behavior: PASSED"
else
    echo "Retreat Behavior: FAILED"
fi
if [ "$OPPORTUNISTIC_AI_PASS" = true ]; then
    echo "Opportunistic Targeting: PASSED"
else
    echo "Opportunistic Targeting: FAILED"
fi
if [ "$CAUTIOUS_AI_PASS" = true ]; then
    echo "Cautious Engagement: PASSED"
else
    echo "Cautious Engagement: FAILED"
fi
if [ "$STATIONARY_GUARD_PASS" = true ]; then
    echo "Stationary Guard: PASSED"
else
    echo "Stationary Guard: FAILED"
fi
if [ "$TACTICAL_DEBUFF_PASS" = true ]; then
    echo "Tactical Debuff: PASSED"
else
    echo "Tactical Debuff: FAILED"
fi
if [ "$AOE_TARGETING_PASS" = true ]; then
    echo "AoE Targeting: PASSED"
else
    echo "AoE Targeting: FAILED"
fi
if [ "$DEFENSIVE_POSITIONING_PASS" = true ]; then
    echo "Defensive Positioning: PASSED"
else
    echo "Defensive Positioning: FAILED"
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

#!/bin/bash
# Headless test script for Phase 3 systems

echo "========================================="
echo "Running Headless Tests for Phase 3"
echo "========================================="

PROJECT_PATH="/home/user/dev/sparklingfarce"

echo ""
echo "1. Checking for parser errors..."
godot --headless --check-only --path "$PROJECT_PATH" 2>&1 | grep -i "parser error" && {
    echo "❌ Parser errors found!"
    exit 1
} || echo "✅ No parser errors"

echo ""
echo "2. Running test scene (10 seconds)..."
timeout 10 godot --headless --path "$PROJECT_PATH" res://mods/_sandbox/scenes/test_full_battle.tscn 2>&1 | tee /tmp/godot_test.log

echo ""
echo "3. Checking test output..."
if grep -q "BattleManager: Battle initialized successfully" /tmp/godot_test.log; then
    echo "✅ Battle initialized"
else
    echo "❌ Battle initialization failed"
    exit 1
fi

if grep -q "TEST: Player units added to battle" /tmp/godot_test.log; then
    echo "✅ Player units spawned"
else
    echo "❌ Player unit spawn failed"
    exit 1
fi

if grep -q "--- Turn Order Calculated ---" /tmp/godot_test.log; then
    echo "✅ Turn order calculated"
else
    echo "❌ Turn order calculation failed"
    exit 1
fi

if grep -q "DEFEAT\|VICTORY" /tmp/godot_test.log; then
    echo "⚠️  Battle ended (expected for headless test)"
else
    echo "✅ Battle running"
fi

echo ""
echo "========================================="
echo "✅ All headless tests passed!"
echo "========================================="

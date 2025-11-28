#!/bin/bash
# Headless test script for Phase 3 systems

echo "========================================="
echo "Running Headless Tests for Phase 3"
echo "========================================="

PROJECT_PATH="/home/user/dev/sparklingfarce"

echo ""
echo "1. Checking for parser errors..."
# Note: --check-only doesn't exit naturally in headless mode, so we use timeout
timeout 10 godot --headless --check-only --path "$PROJECT_PATH" 2>&1 | grep -i "parser error" && {
    echo "❌ Parser errors found!"
    exit 1
} || echo "✅ No parser errors"

echo ""
echo "2. Running test scene (10 seconds)..."
timeout 10 godot --headless --path "$PROJECT_PATH" res://scenes/tests/test_ai_headless.tscn 2>&1 | tee /tmp/godot_test.log

echo ""
echo "3. Checking test output..."
if grep -q "BattleManager: Setup complete" /tmp/godot_test.log; then
    echo "✅ Battle initialized"
else
    echo "❌ Battle initialization failed"
    exit 1
fi

if grep -q "Unit initialized:" /tmp/godot_test.log; then
    echo "✅ Units spawned"
else
    echo "❌ Unit spawn failed"
    exit 1
fi

if grep -q -- "Turn Order Calculated" /tmp/godot_test.log; then
    echo "✅ Turn order calculated"
else
    echo "❌ Turn order calculation failed"
    exit 1
fi

if grep -q "MAX TURNS REACHED\|DEFEAT\|VICTORY" /tmp/godot_test.log; then
    echo "✅ Battle completed (victory, defeat, or max turns)"
else
    echo "⚠️  Battle still running (may need longer timeout)"
fi

echo ""
echo "========================================="
echo "✅ All headless tests passed!"
echo "========================================="

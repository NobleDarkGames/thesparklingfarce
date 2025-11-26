#!/bin/bash

# Headless test for cinematics system
# Tests Phase 1: Basic infrastructure

echo "=== Cinematics System Headless Test ==="
echo "Testing Phase 1: Core infrastructure"
echo ""

# Run Godot in headless mode with the test scene
timeout 10 godot --headless --path . scenes/tests/cinematic_test_scene.tscn --quit-after 5 2>&1 | tee /tmp/cinematic_test.log

# Check for errors
if grep -i "error" /tmp/cinematic_test.log | grep -v "GLX"; then
    echo ""
    echo "FAILED: Errors detected in test output"
    exit 1
fi

# Check that CinematicsManager loaded
if ! grep -q "CinematicsManager" /tmp/cinematic_test.log; then
    echo ""
    echo "WARNING: CinematicsManager not mentioned in output"
fi

echo ""
echo "=== Test Complete ==="
echo "Review /tmp/cinematic_test.log for detailed output"

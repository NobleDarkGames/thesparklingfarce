#!/bin/bash
# Headless test script for Sparkling Farce
# Runs GdUnit4 test suite

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
echo "2. Running GdUnit4 Tests..."
echo "========================================="
timeout 180 "$GODOT" --headless --path "$PROJECT_PATH" -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add "res://tests" 2>&1 | tee /tmp/gdunit_test.log

# Check GdUnit4 results - look for the overall summary line
if grep -q "0 errors | 0 failures" /tmp/gdunit_test.log; then
    echo "GdUnit4 tests PASSED"
    # Extract statistics
    GDUNIT_STATS=$(grep "Overall Summary:" /tmp/gdunit_test.log | sed 's/\x1b\[[0-9;]*m//g')
    echo "$GDUNIT_STATS"
else
    echo "GdUnit4 tests FAILED"
    # Show failures - strip ANSI codes for readability
    grep -E "FAILED|ERROR" /tmp/gdunit_test.log | sed 's/\x1b\[[0-9;]*m//g' | head -30
    EXIT_CODE=1
fi

echo ""
echo "========================================="
echo "TEST SUMMARY"
echo "========================================="

# Get GdUnit4 test counts - strip ANSI codes
GDUNIT_SUMMARY=$(grep "Overall Summary:" /tmp/gdunit_test.log | sed 's/\x1b\[[0-9;]*m//g')
if [ -n "$GDUNIT_SUMMARY" ]; then
    echo "GdUnit4: $GDUNIT_SUMMARY"
else
    echo "GdUnit4: No results (check logs)"
    EXIT_CODE=1
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

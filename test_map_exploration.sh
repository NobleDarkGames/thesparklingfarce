#!/bin/bash
# Quick launcher for map exploration test

echo "========================================="
echo "Launching Map Exploration Test"
echo "========================================="
echo ""
echo "Controls:"
echo "  Arrow Keys - Move hero"
echo "  Enter/Z    - Interact"
echo "  F1         - Show debug info"
echo "  F2         - Teleport test"
echo "  ESC        - Quit"
echo ""
echo "========================================="
echo ""

godot --path /home/user/dev/sparklingfarce res://scenes/map_exploration/map_test_playable.tscn

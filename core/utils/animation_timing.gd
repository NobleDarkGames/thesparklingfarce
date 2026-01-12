## AnimationTiming - SF2-authentic animation speed constants
##
## SF2 uses dramatically different animation speeds for idle vs movement:
## - Idle: slow, gentle "breathing" animation (~500-600ms per frame)
## - Movement: snappy, urgent animation (~100-150ms per frame)
##
## The ratio matters: movement should be ~4-5x faster than idle.
## This creates the authentic SF2 feel where idle is contemplative
## and movement feels decisive.
class_name AnimationTiming
extends RefCounted

## Slow down base animation for idle state (~2 FPS effective)
const IDLE_SPEED_SCALE: float = 0.5

## Speed up base animation for movement state (~8 FPS effective)
const MOVEMENT_SPEED_SCALE: float = 2.0

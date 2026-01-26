class_name UIUtils
extends RefCounted

## UI utility functions for common patterns

## Kill and clear a tween if valid
static func kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()


## Safe signal connect (only if not already connected)
static func safe_connect(sig: Signal, callback: Callable) -> void:
	if not sig.is_connected(callback):
		sig.connect(callback)


## Safe signal disconnect (only if connected)
static func safe_disconnect(sig: Signal, callback: Callable) -> void:
	if sig.is_connected(callback):
		sig.disconnect(callback)

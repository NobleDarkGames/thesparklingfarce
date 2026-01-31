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


## Start a looping blink animation on a label (for "Press any key..." prompts)
## @param label: The label to animate
## @param existing_tween: The existing tween reference to kill first (can be null)
## @return: The new tween (caller should store this reference)
static func start_blink_tween(label: Control, existing_tween: Tween) -> Tween:
	kill_tween(existing_tween)
	var tween: Tween = label.create_tween()
	tween.set_loops()
	tween.tween_property(label, "modulate:a", 0.3, 0.5)
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	return tween


## Apply monogram font styling to a control
## @param control: The control to style (Label, Button, etc.)
## @param font_size: Font size (default 16, use 24 for headers)
static func apply_monogram_style(control: Control, font_size: int = 16) -> void:
	control.add_theme_font_override("font", preload("res://assets/fonts/monogram.ttf"))
	control.add_theme_font_size_override("font_size", font_size)


## Create a StyleBoxFlat with uniform border width
## @param bg_color: Background color for the panel
## @param border_color: Border color
## @param border_width: Border width on all sides (default 1)
## @param corner_radius: Corner radius for all corners (default 0)
## @return: Configured StyleBoxFlat
static func create_panel_style(
	bg_color: Color,
	border_color: Color,
	border_width: int = 1,
	corner_radius: int = 0
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(border_width)
	style.border_color = border_color
	if corner_radius > 0:
		style.set_corner_radius_all(corner_radius)
	return style

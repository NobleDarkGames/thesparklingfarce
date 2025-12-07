# Shop Character Button Click Diagnostic

## The Problem
Character buttons in the shop UI receive `gui_input` events but do NOT fire `pressed` signals.

## Key Evidence
```
[SHOP] GUI_INPUT click on: Mr Big Hero Face
```
But NO corresponding:
```
[SHOP] PRESSED signal for: Mr Big Hero Face
```

## What This Means
- Clicks ARE reaching the button (gui_input fires)
- But the Button's internal `pressed` signal does NOT fire
- This suggests something about the Button's state or configuration is wrong

## Possible Causes
1. **Button is disabled** - disabled buttons receive gui_input but don't fire pressed
2. **Button action_mode** - Button.action_mode might be set to RELEASE but we're only checking press
3. **Button toggle_mode** - If toggle_mode is true, behavior changes
4. **Mouse filter on button itself** - Though unlikely since gui_input works
5. **Some parent is calling accept_event()** - Consuming the event after gui_input

## Files Involved
- `scenes/ui/shops/shop_interface.tscn` - Scene structure
- `scenes/ui/shops/shop_interface.gd` - Script logic

## Button Creation Code (shop_interface.gd ~line 613)
```gdscript
func _create_character_button(character: CharacterData) -> Button:
    var button: Button = Button.new()
    button.custom_minimum_size = Vector2(80, 24)
    button.add_theme_font_size_override("font_size", 16)
    button.text = character.character_name
    button.focus_mode = Control.FOCUS_ALL
    return button
```

## Signal Connection Code (~line 580)
```gdscript
button.pressed.connect(func() -> void:
    print("[SHOP] PRESSED signal for: %s" % char_name)
    _on_character_button_pressed(uid, button)
)
button.gui_input.connect(func(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        print("[SHOP] GUI_INPUT click on: %s" % char_name)
)
```

## What We've Already Tried
1. Added `mouse_filter = 1` (PASS) to all containers
2. Added `mouse_filter = 2` (IGNORE) to decorative ColorRects
3. Added `focus_mode = 2` (ALL) to buttons
4. Tried lambda connections instead of .bind()
5. Item buttons work fine with same pattern - only character buttons fail

## Key Difference
- Item buttons are added to `ItemListContainer` (VBoxContainer inside ScrollContainer)
- Character buttons are added to `CharacterGrid` (GridContainer inside PanelContainer)

## Debugging Questions for Barclay
1. Is the button disabled when clicked? (check `button.disabled` at click time)
2. Is there something special about GridContainer that affects child button behavior?
3. Is the PanelContainer's StyleBox somehow involved?
4. Should we try adding buttons to a VBoxContainer instead of GridContainer?
5. What's different about how item buttons work vs character buttons?

## Quick Test to Try
In `_create_character_button`, add:
```gdscript
button.disabled = false  # Explicitly ensure not disabled
button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS  # Fire on press, not release
```

## Broader Issue
The user also expressed dissatisfaction with the overall shop UX design. After fixing this click issue, may need to revisit the entire shop flow design per specs in:
- `docs/specs/shop-interface-ux-specification.md`
- `docs/specs/shop-interface-wireframes.md`

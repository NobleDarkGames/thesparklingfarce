## Play sound command executor
## Plays a sound effect via AudioManager
class_name PlaySoundExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, _manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var sound_id: String = params.get("sound_id", "")

	if sound_id.is_empty():
		push_warning("PlaySoundExecutor: No sound_id specified")
		return true

	# Play sound effect via AudioManager
	AudioManager.play_sfx(sound_id, AudioManager.SFXCategory.SYSTEM)

	return true  # Sound effects play asynchronously, complete immediately

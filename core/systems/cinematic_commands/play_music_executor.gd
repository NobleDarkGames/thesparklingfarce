## Play music command executor
## Plays background music via AudioManager
class_name PlayMusicExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, _manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var music_id: String = params.get("music_id", "")
	var fade_duration: float = params.get("fade_duration", 0.5)

	if music_id.is_empty():
		push_warning("PlayMusicExecutor: No music_id specified")
		return true

	# Play music via AudioManager (handles fade-in automatically)
	AudioManager.play_music(music_id, fade_duration)

	return true  # Music starts playing, complete immediately

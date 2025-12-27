## AudioManager
## Central audio playback system that loads sounds from the active mod
##
## Provides a simple API for playing sound effects and music throughout the game.
## All audio files are stored in mods, not in the core engine.
##
## Usage:
##   AudioManager.play_sfx("cursor_move")
##   AudioManager.play_sfx("attack_hit")
##   AudioManager.play_music("battle_theme")

extends Node

## Sound effect categories (for organization and volume control)
enum SFXCategory {
	UI,        ## Menu navigation, cursor movement
	COMBAT,    ## Attacks, damage, critical hits
	SYSTEM,    ## Turn changes, victory/defeat
	MOVEMENT,  ## Unit movement
	CEREMONY,  ## Promotion ceremonies, special events
}

## Current mod's audio path (set by ModLoader or BattleManager)
var current_mod_path: String = ""

## Audio buses (configured in project settings)
const SFX_BUS: String = "SFX"
const MUSIC_BUS: String = "Music"

## Audio player pools
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer = null

## Cache for loaded audio streams (prevents repeated disk reads)
var _audio_cache: Dictionary = {}

## Volume settings (0.0 to 1.0)
var sfx_volume: float = 0.7
var music_volume: float = 0.5


func _ready() -> void:
	# Create audio player pool for sound effects (8 simultaneous sounds)
	for i: int in range(8):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)

	# Create music player (single looping track)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)

	# Apply volume settings
	_update_volumes()

	# Connect to ModLoader's active_mod_changed signal for runtime mod switches
	ModLoader.active_mod_changed.connect(_on_active_mod_changed)

	# Initialize mod path from ModLoader's current active mod
	# ModLoader runs before AudioManager in autoload order, so it's already loaded
	var active_mod: ModManifest = ModLoader.get_active_mod()
	if active_mod:
		set_active_mod(active_mod.mod_directory)
	else:
		# Fallback: construct path from active_mod_id when manifest unavailable
		# This can happen if mods directory wasn't accessible during startup
		var fallback_path: String = "res://mods/".path_join(ModLoader.active_mod_id)
		set_active_mod(fallback_path)


## Called when ModLoader's active mod changes
func _on_active_mod_changed(mod_path: String) -> void:
	set_active_mod(mod_path)


## Set the current mod for audio loading
func set_active_mod(mod_path: String) -> void:
	current_mod_path = mod_path
	_audio_cache.clear()  # Clear cache when switching mods


## Play a sound effect from the current mod
## @param sfx_name: Name of the sound file (without extension)
## @param _category: Category for organization (optional, defaults to SYSTEM) - reserved for future use
func play_sfx(sfx_name: String, _category: SFXCategory = SFXCategory.SYSTEM) -> void:
	var stream: AudioStream = _load_audio(sfx_name, "sfx")
	if not stream:
		return  # Audio file not found, fail silently

	# Find available player
	var player: AudioStreamPlayer = _get_available_sfx_player()
	if not player:
		push_warning("AudioManager: All SFX players busy, cannot play '%s'" % sfx_name)
		return

	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume)
	player.play()


## Play background music from the current mod (loops automatically)
## @param music_name: Name of the music file (without extension)
## @param fade_in_duration: Duration of fade-in effect in seconds (default: 0.5)
func play_music(music_name: String, fade_in_duration: float = 0.5) -> void:
	var stream: AudioStream = _load_audio(music_name, "music")
	if not stream:
		return  # Music file not found, fail silently

	# Stop current music if playing
	if _music_player.playing:
		stop_music(fade_in_duration * 0.5)  # Fade out faster than fade in
		await get_tree().create_timer(fade_in_duration * 0.5).timeout

	# Set up new music
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(0.0)  # Start silent for fade-in
	_music_player.play()
	_music_has_played = true
	_is_paused = false

	# Fade in
	if fade_in_duration > 0.0:
		var tween: Tween = create_tween()
		tween.tween_method(
			func(vol: float) -> void: _music_player.volume_db = linear_to_db(vol),
			0.0,
			music_volume,
			fade_in_duration
		)
	else:
		_music_player.volume_db = linear_to_db(music_volume)


## Stop the currently playing music
## @param fade_out_duration: Duration of fade-out effect in seconds (default: 1.0)
func stop_music(fade_out_duration: float = 1.0) -> void:
	if not _music_player.playing:
		return

	if fade_out_duration > 0.0:
		var tween: Tween = create_tween()
		tween.tween_method(
			func(vol: float) -> void: _music_player.volume_db = linear_to_db(vol),
			music_volume,
			0.0,
			fade_out_duration
		)
		tween.tween_callback(_music_player.stop)
	else:
		_music_player.stop()


## Load an audio stream from the current mod's audio directory
## @param audio_name: Name of the audio file (without extension)
## @param subfolder: Subfolder within audio/ (e.g., "sfx", "music")
## @return AudioStream or null if not found
func _load_audio(audio_name: String, subfolder: String) -> AudioStream:
	# Check cache first
	var cache_key: String = "%s/%s" % [subfolder, audio_name]
	if cache_key in _audio_cache:
		return _audio_cache[cache_key]

	# Try common audio formats
	var extensions: Array[String] = ["ogg", "wav", "mp3"]

	for ext: String in extensions:
		var audio_path: String = "%s/audio/%s/%s.%s" % [current_mod_path, subfolder, audio_name, ext]

		if ResourceLoader.exists(audio_path):
			var stream: AudioStream = load(audio_path) as AudioStream
			if stream:
				_audio_cache[cache_key] = stream
				return stream

	# Audio not found - this is expected for optional sounds
	return null


## Find an available (not playing) SFX player
func _get_available_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player
	return null


## Check if a specific sound effect is currently playing
## @param sfx_name: Name of the sound file (without extension)
## @return true if the sound is currently playing on any player
func is_sfx_playing(sfx_name: String) -> bool:
	var stream: AudioStream = _load_audio(sfx_name, "sfx")
	if not stream:
		return false

	for player: AudioStreamPlayer in _sfx_players:
		if player.playing and player.stream == stream:
			return true
	return false


## Play a sound effect only if it's not already playing (prevents overlap)
## Useful for continuous sounds like footsteps that shouldn't stack
## @param sfx_name: Name of the sound file (without extension)
## @param category: Category for organization (optional, defaults to SYSTEM)
func play_sfx_no_overlap(sfx_name: String, category: SFXCategory = SFXCategory.SYSTEM) -> void:
	if is_sfx_playing(sfx_name):
		return
	play_sfx(sfx_name, category)


## Update volume for all audio buses
func _update_volumes() -> void:
	# Note: AudioServer.set_bus_volume_db would be used here
	# if we want global volume control beyond per-player settings
	pass


## Set SFX volume (0.0 to 1.0)
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)


## Set music volume (0.0 to 1.0)
func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	if _music_player and _music_player.playing:
		_music_player.volume_db = linear_to_db(music_volume)


# ============================================================================
# PAUSE/RESUME SYSTEM (with race condition guards)
# ============================================================================

## Track if music has been played at least once (prevents resume before play)
var _music_has_played: bool = false

## Track if we're currently paused (prevents double-pause issues)
var _is_paused: bool = false

## Stored position for resume (used during pause)
var _paused_position: float = 0.0


## Pause currently playing music (safe - ignores if not playing or never played)
func pause_music() -> void:
	# Guard: Don't pause if we've never played or already paused
	if not _music_has_played:
		return

	if _is_paused:
		push_warning("AudioManager: Music already paused, ignoring duplicate pause")
		return

	if not _music_player.playing:
		return

	_paused_position = _music_player.get_playback_position()
	_music_player.stop()
	_is_paused = true


## Resume previously paused music (safe - ignores if not paused)
func resume_music() -> void:
	# Guard: Don't resume if we've never played
	if not _music_has_played:
		push_warning("AudioManager: Cannot resume music that was never played")
		return

	# Guard: Don't resume if not paused
	if not _is_paused:
		push_warning("AudioManager: Music is not paused, ignoring resume")
		return

	# Guard: Ensure we have a stream to resume
	if not _music_player.stream:
		push_warning("AudioManager: No music stream to resume")
		_is_paused = false
		return

	_music_player.play(_paused_position)
	_music_player.volume_db = linear_to_db(music_volume)
	_is_paused = false


## Check if music is currently paused
func is_music_paused() -> bool:
	return _is_paused


## Check if music is currently playing (not paused, not stopped)
func is_music_playing() -> bool:
	return _music_player.playing and not _is_paused

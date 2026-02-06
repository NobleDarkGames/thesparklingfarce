## AudioManager
## Central audio playback system with mod-aware resource resolution
##
## Provides a simple API for playing sound effects and music throughout the game.
## Audio files are resolved through the mod system with proper priority/fallback:
## - Higher priority mods can override sounds from lower priority mods
## - Falls back to _starter_kit for default sounds
##
## ADAPTIVE MUSIC SYSTEM:
## Supports layered music tracks for dynamic audio:
## - Layer 0 (base): Always plays during music playback
## - Layer 1 (attack): Fades in during combat animations
## - Layer 2 (boss): Plays throughout boss battles
##
## Layer files are discovered automatically using naming conventions:
##   battle_theme.ogg        # Base layer
##   battle_theme_layer1.ogg # Attack layer (or _l1.ogg)
##   battle_theme_layer2.ogg # Boss layer (or _l2.ogg)
##
## IMPORTANT: All layer files must be identical length for proper synchronization.
##
## Usage:
##   AudioManager.play_sfx("cursor_move")
##   AudioManager.play_sfx("attack_hit")
##   AudioManager.play_music("battle_theme")
##   AudioManager.enable_layer(1)   # Fade in attack layer
##   AudioManager.disable_layer(1)  # Fade out attack layer

extends Node

## Sound effect categories (for organization and volume control)
enum SFXCategory {
	UI,        ## Menu navigation, cursor movement
	COMBAT,    ## Attacks, damage, critical hits
	SYSTEM,    ## Turn changes, victory/defeat
	MOVEMENT,  ## Unit movement
	CEREMONY,  ## Promotion ceremonies, special events
}

## Fallback path for audio assets (starter kit provides default sounds)
const AUDIO_FALLBACK_PATH: String = "res://mods/_starter_kit/assets/"

## Audio buses (configured in project settings)
const SFX_BUS: String = "SFX"
const MUSIC_BUS: String = "Music"

## Maximum number of music layers (base + 2 additional)
const MAX_LAYERS: int = 3

## Default fade duration for layer transitions
const DEFAULT_LAYER_FADE: float = 0.4

## Audio player pools
var _sfx_players: Array[AudioStreamPlayer] = []

## Layered music system - array of AudioStreamPlayers (index = layer number)
var _music_layers: Array[AudioStreamPlayer] = []

## Track which layers are currently enabled (target volume > 0)
var _layer_enabled: Array[bool] = [true, false, false]

## Current layer volumes (0.0 to 1.0, relative to music_volume)
var _layer_volumes: Array[float] = [1.0, 0.0, 0.0]

## Active tweens for layer fades (to cancel if new fade requested)
var _layer_tweens: Array[Tween] = [null, null, null]

## Current music track name (without extension)
var _current_music_name: String = ""

## Number of layers available for current track
var _current_layer_count: int = 0

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

	# Create layered music players
	for i: int in range(MAX_LAYERS):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = MUSIC_BUS
		player.name = "MusicLayer%d" % i
		add_child(player)
		_music_layers.append(player)

	# Apply volume settings
	_update_volumes()

	# Clear audio cache when mods are reloaded
	ModLoader.mods_loaded.connect(_on_mods_loaded)


## Called when mods are reloaded - clear cache to pick up new/changed audio
func _on_mods_loaded() -> void:
	_audio_cache.clear()


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
	player.volume_db = linear_to_db(maxf(sfx_volume, 0.0001))
	player.play()


# =============================================================================
# LAYERED MUSIC SYSTEM
# =============================================================================

## Play background music with automatic layer discovery
## If the same track is already playing, returns without restarting (track continuation)
## @param music_name: Name of the music file (without extension)
## @param fade_in_duration: Duration of fade-in effect in seconds (default: 0.5)
func play_music(music_name: String, fade_in_duration: float = 0.5) -> void:
	# Track continuation: don't restart if same track already playing
	if music_name == _current_music_name and _music_layers[0].playing:
		return

	# Load base layer
	var base_stream: AudioStream = _load_audio(music_name, "music")
	if not base_stream:
		return  # Music file not found, fail silently

	# Stop current music if playing (immediate stop - new track will fade in)
	if _music_layers[0].playing:
		stop_music(0.0)  # Immediate stop to avoid race condition with tween callback

	# Store current track name
	_current_music_name = music_name

	# Discover and load additional layers
	var layer_streams: Array[AudioStream] = [base_stream]
	layer_streams.append(_discover_layer(music_name, 1))
	layer_streams.append(_discover_layer(music_name, 2))

	# Count available layers
	_current_layer_count = 1
	for i: int in range(1, MAX_LAYERS):
		if layer_streams[i] != null:
			_current_layer_count = i + 1

	# Reset layer states
	_layer_enabled = [true, false, false]
	_layer_volumes = [1.0, 0.0, 0.0]

	# Set up all layer players
	for i: int in range(MAX_LAYERS):
		var player: AudioStreamPlayer = _music_layers[i]
		player.stream = layer_streams[i]

		if layer_streams[i]:
			# Start silent for fade-in (base layer) or disabled (other layers)
			if i == 0:
				player.volume_db = linear_to_db(0.0001)
			else:
				player.volume_db = linear_to_db(0.0001)  # Additional layers start silent

	# Start all layers simultaneously for sync
	for i: int in range(MAX_LAYERS):
		if _music_layers[i].stream:
			_music_layers[i].play()

	_music_has_played = true
	_is_paused = false

	# Fade in base layer
	if fade_in_duration > 0.0:
		_cancel_layer_tween(0)
		var tween: Tween = create_tween()
		_layer_tweens[0] = tween
		tween.tween_method(
			func(vol: float) -> void:
				_layer_volumes[0] = vol
				_update_layer_volume(0),
			0.0,
			1.0,
			fade_in_duration
		)
	else:
		_layer_volumes[0] = 1.0
		_update_layer_volume(0)


## Discover a layer file for a music track
## Checks both _layerN and _lN naming conventions
## @param music_name: Base music track name
## @param layer_num: Layer number (1 or 2)
## @return: AudioStream if found, null otherwise
func _discover_layer(music_name: String, layer_num: int) -> AudioStream:
	# Try full naming convention first: track_layer1.ogg
	var full_name: String = "%s_layer%d" % [music_name, layer_num]
	var stream: AudioStream = _load_audio(full_name, "music")
	if stream:
		return stream

	# Try short naming convention: track_l1.ogg
	var short_name: String = "%s_l%d" % [music_name, layer_num]
	stream = _load_audio(short_name, "music")
	if stream:
		return stream

	return null


## Stop the currently playing music (all layers)
## @param fade_out_duration: Duration of fade-out effect in seconds (default: 1.0)
func stop_music(fade_out_duration: float = 1.0) -> void:
	if not _music_layers[0].playing:
		return

	# Cancel any active layer tweens
	for i: int in range(MAX_LAYERS):
		if _layer_tweens[i] and _layer_tweens[i].is_valid():
			_layer_tweens[i].kill()
			_layer_tweens[i] = null

	if fade_out_duration > 0.0:
		var tween: Tween = create_tween()
		tween.tween_method(
			func(vol: float) -> void:
				for i: int in range(MAX_LAYERS):
					if _music_layers[i].stream:
						_music_layers[i].volume_db = linear_to_db(maxf(vol * _layer_volumes[i] * music_volume, 0.0001)),
			1.0,
			0.0,
			fade_out_duration
		)
		tween.tween_callback(_stop_all_layers)
	else:
		_stop_all_layers()


## Stop all music layer players and clear track name
func _stop_all_layers() -> void:
	for player: AudioStreamPlayer in _music_layers:
		player.stop()
	_current_music_name = ""
	_current_layer_count = 0


## Get the name of the currently playing music track
## @return: Track name (without extension) or empty string if not playing
func get_current_music_name() -> String:
	return _current_music_name


## Get the number of layers available for the current track
## @return: Number of layers (1-3), or 0 if no music playing
func get_layer_count() -> int:
	return _current_layer_count


## Check if a specific layer is currently enabled
## @param layer: Layer number (0 = base, 1 = attack, 2 = boss)
## @return: True if layer is enabled (fading in or at full volume)
func is_layer_enabled(layer: int) -> bool:
	if layer < 0 or layer >= MAX_LAYERS:
		return false
	return _layer_enabled[layer]


## Enable a music layer (fade in)
## @param layer: Layer number (1 = attack, 2 = boss). Layer 0 is always enabled.
## @param fade_duration: Duration of fade-in effect (default: 0.4)
func enable_layer(layer: int, fade_duration: float = DEFAULT_LAYER_FADE) -> void:
	if layer <= 0 or layer >= MAX_LAYERS:
		if layer != 0:
			push_warning("AudioManager: Invalid layer %d (valid: 1-%d)" % [layer, MAX_LAYERS - 1])
		return

	if not _music_layers[layer].stream:
		return  # No layer file available

	if _layer_enabled[layer]:
		return  # Already enabled

	_layer_enabled[layer] = true
	_fade_layer(layer, 1.0, fade_duration)


## Disable a music layer (fade out)
## @param layer: Layer number (1 = attack, 2 = boss). Layer 0 cannot be disabled.
## @param fade_duration: Duration of fade-out effect (default: 0.4)
func disable_layer(layer: int, fade_duration: float = DEFAULT_LAYER_FADE) -> void:
	if layer <= 0 or layer >= MAX_LAYERS:
		if layer == 0:
			push_warning("AudioManager: Cannot disable base layer (0)")
		else:
			push_warning("AudioManager: Invalid layer %d (valid: 1-%d)" % [layer, MAX_LAYERS - 1])
		return

	if not _layer_enabled[layer]:
		return  # Already disabled

	_layer_enabled[layer] = false
	_fade_layer(layer, 0.0, fade_duration)


## Fade a layer to target volume
func _fade_layer(layer: int, target_volume: float, fade_duration: float) -> void:
	_cancel_layer_tween(layer)
	var tween: Tween = create_tween()
	_layer_tweens[layer] = tween
	tween.tween_method(
		func(vol: float) -> void:
			_layer_volumes[layer] = vol
			_update_layer_volume(layer),
		_layer_volumes[layer],
		target_volume,
		fade_duration
	)


## Cancel any active tween for a layer
func _cancel_layer_tween(layer: int) -> void:
	if _layer_tweens[layer] and _layer_tweens[layer].is_valid():
		_layer_tweens[layer].kill()
		_layer_tweens[layer] = null


## Set the volume of a specific layer
## @param layer: Layer number (0-2)
## @param volume: Target volume (0.0 to 1.0)
## @param fade_duration: Duration of fade effect (0.0 for instant)
func set_layer_volume(layer: int, volume: float, fade_duration: float = 0.0) -> void:
	if layer < 0 or layer >= MAX_LAYERS:
		push_warning("AudioManager: Invalid layer %d" % layer)
		return

	volume = clampf(volume, 0.0, 1.0)

	if fade_duration > 0.0:
		_fade_layer(layer, volume, fade_duration)
	else:
		_cancel_layer_tween(layer)
		_layer_volumes[layer] = volume
		_update_layer_volume(layer)

	_layer_enabled[layer] = volume > 0.0


## Update the actual volume_db of a layer player
## Combines layer volume with master music_volume
func _update_layer_volume(layer: int) -> void:
	if layer < 0 or layer >= MAX_LAYERS:
		return
	if not _music_layers[layer].stream:
		return

	var final_volume: float = _layer_volumes[layer] * music_volume
	_music_layers[layer].volume_db = linear_to_db(maxf(final_volume, 0.0001))


## Load an audio stream using mod-aware asset resolution
## Checks mods in priority order, falls back to _starter_kit for defaults
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
		var relative_path: String = "audio/%s/%s.%s" % [subfolder, audio_name, ext]
		var resolved_path: String = ModLoader.resolve_asset_path(relative_path, AUDIO_FALLBACK_PATH)

		if not resolved_path.is_empty():
			var stream: AudioStream = load(resolved_path) as AudioStream
			if stream:
				# Enable looping for music tracks
				if subfolder == "music":
					_enable_stream_looping(stream)
				_audio_cache[cache_key] = stream
				return stream

	# Audio not found - this is expected for optional sounds
	return null


## Enable looping on an audio stream (for music)
## Handles different stream types appropriately
func _enable_stream_looping(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


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
## Updates all active music layers to reflect new volume
func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	# Update all layer volumes
	for i: int in range(MAX_LAYERS):
		_update_layer_volume(i)


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
## Pauses all layers simultaneously to maintain sync
func pause_music() -> void:
	# Guard: Don't pause if we've never played or already paused
	if not _music_has_played:
		return

	if _is_paused:
		push_warning("AudioManager: Music already paused, ignoring duplicate pause")
		return

	if not _music_layers[0].playing:
		return

	_paused_position = _music_layers[0].get_playback_position()

	# Stop all layers
	for player: AudioStreamPlayer in _music_layers:
		player.stop()

	_is_paused = true


## Resume previously paused music (safe - ignores if not paused)
## Resumes all layers at the same position to maintain sync
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
	if not _music_layers[0].stream:
		push_warning("AudioManager: No music stream to resume")
		_is_paused = false
		return

	# Resume all layers at the same position
	for i: int in range(MAX_LAYERS):
		if _music_layers[i].stream:
			_music_layers[i].play(_paused_position)
			_update_layer_volume(i)

	_is_paused = false


## Check if music is currently paused
func is_music_paused() -> bool:
	return _is_paused


## Check if music is currently playing (not paused, not stopped)
func is_music_playing() -> bool:
	return _music_layers[0].playing and not _is_paused

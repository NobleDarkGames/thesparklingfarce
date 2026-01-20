@tool
class_name MusicDiscovery
extends RefCounted

## Utility for discovering available music tracks across all mods.
## Scans mods/*/assets/audio/music/ directories and returns base track names
## (without layer suffixes like _layer1, _layer2, _l1, _l2).

## Layer suffix patterns to strip from track names
const LAYER_SUFFIXES: Array[String] = ["_layer1", "_layer2", "_l1", "_l2"]


## Get all available music track IDs from all mods
## Returns base track names only (layers are automatic)
static func get_available_music() -> Array[String]:
	var music_tracks: Array[String] = []
	var seen_tracks: Dictionary = {}  # Track deduplication

	# Scan all mod directories
	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		push_warning("MusicDiscovery: Could not open mods directory")
		return music_tracks

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var music_path: String = "res://mods/%s/assets/audio/music/" % mod_name
			_scan_music_directory(music_path, mod_name, seen_tracks)
		mod_name = mods_dir.get_next()
	mods_dir.list_dir_end()

	# Convert to sorted array
	for track_id: String in seen_tracks.keys():
		music_tracks.append(track_id)
	music_tracks.sort()

	return music_tracks


## Get available music tracks with mod labels for UI display
## Returns array of dictionaries: {id: String, display_name: String, mod: String}
static func get_available_music_with_labels() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen_tracks: Dictionary = {}  # id -> {mod: String, display_name: String}

	# Scan all mod directories
	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		push_warning("MusicDiscovery: Could not open mods directory")
		return results

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var music_path: String = "res://mods/%s/assets/audio/music/" % mod_name
			_scan_music_directory_with_labels(music_path, mod_name, seen_tracks)
		mod_name = mods_dir.get_next()
	mods_dir.list_dir_end()

	# Convert to sorted array of dictionaries
	var track_ids: Array = seen_tracks.keys()
	track_ids.sort()

	for track_id: String in track_ids:
		var info: Dictionary = seen_tracks[track_id]
		results.append({
			"id": track_id,
			"display_name": _format_display_name(track_id),
			"mod": info.mod
		})

	return results


## Get available SFX track IDs from all mods (for victory/defeat fanfares)
## Scans mods/*/assets/audio/sfx/ directories
static func get_available_sfx() -> Array[String]:
	var sfx_tracks: Array[String] = []
	var seen_tracks: Dictionary = {}

	# Scan all mod directories
	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		push_warning("MusicDiscovery: Could not open mods directory")
		return sfx_tracks

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var sfx_path: String = "res://mods/%s/assets/audio/sfx/" % mod_name
			_scan_sfx_directory(sfx_path, mod_name, seen_tracks)
		mod_name = mods_dir.get_next()
	mods_dir.list_dir_end()

	# Convert to sorted array
	for track_id: String in seen_tracks.keys():
		sfx_tracks.append(track_id)
	sfx_tracks.sort()

	return sfx_tracks


## Get available SFX tracks with mod labels for UI display
static func get_available_sfx_with_labels() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen_tracks: Dictionary = {}

	# Scan all mod directories
	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		push_warning("MusicDiscovery: Could not open mods directory")
		return results

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var sfx_path: String = "res://mods/%s/assets/audio/sfx/" % mod_name
			_scan_sfx_directory(sfx_path, mod_name, seen_tracks)
		mod_name = mods_dir.get_next()
	mods_dir.list_dir_end()

	# Convert to sorted array of dictionaries
	var track_ids: Array = seen_tracks.keys()
	track_ids.sort()

	for track_id: String in track_ids:
		var info: Dictionary = seen_tracks[track_id]
		results.append({
			"id": track_id,
			"display_name": _format_display_name(track_id),
			"mod": info.mod
		})

	return results


## Scan a music directory and add base track names to seen_tracks
static func _scan_music_directory(music_path: String, mod_name: String, seen_tracks: Dictionary) -> void:
	var music_dir: DirAccess = DirAccess.open(music_path)
	if not music_dir:
		return

	music_dir.list_dir_begin()
	var file_name: String = music_dir.get_next()

	while file_name != "":
		if not music_dir.current_is_dir() and _is_audio_file(file_name):
			var base_name: String = _get_base_track_name(file_name)
			if base_name not in seen_tracks:
				seen_tracks[base_name] = true
		file_name = music_dir.get_next()
	music_dir.list_dir_end()


## Scan a music directory and add base track names with mod info
static func _scan_music_directory_with_labels(music_path: String, mod_name: String, seen_tracks: Dictionary) -> void:
	var music_dir: DirAccess = DirAccess.open(music_path)
	if not music_dir:
		return

	music_dir.list_dir_begin()
	var file_name: String = music_dir.get_next()

	while file_name != "":
		if not music_dir.current_is_dir() and _is_audio_file(file_name):
			var base_name: String = _get_base_track_name(file_name)
			if base_name not in seen_tracks:
				seen_tracks[base_name] = {mod = mod_name}
		file_name = music_dir.get_next()
	music_dir.list_dir_end()


## Scan an SFX directory and add track names
static func _scan_sfx_directory(sfx_path: String, mod_name: String, seen_tracks: Dictionary) -> void:
	var sfx_dir: DirAccess = DirAccess.open(sfx_path)
	if not sfx_dir:
		return

	sfx_dir.list_dir_begin()
	var file_name: String = sfx_dir.get_next()

	while file_name != "":
		if not sfx_dir.current_is_dir() and _is_audio_file(file_name):
			# SFX don't have layers, just use base name without extension
			var base_name: String = file_name.get_basename()
			if base_name not in seen_tracks:
				seen_tracks[base_name] = {mod = mod_name}
		file_name = sfx_dir.get_next()
	sfx_dir.list_dir_end()


## Check if a file is an audio file (ogg, wav, mp3)
static func _is_audio_file(file_name: String) -> bool:
	var extension: String = file_name.get_extension().to_lower()
	return extension in ["ogg", "wav", "mp3"]


## Get the base track name by stripping layer suffixes and extension
static func _get_base_track_name(file_name: String) -> String:
	var base_name: String = file_name.get_basename()

	# Strip layer suffixes
	for suffix: String in LAYER_SUFFIXES:
		if base_name.ends_with(suffix):
			base_name = base_name.substr(0, base_name.length() - suffix.length())
			break

	return base_name


## Format track ID for display (replace underscores with spaces, capitalize)
static func _format_display_name(track_id: String) -> String:
	return track_id.replace("_", " ").capitalize()

class_name TextInterpolator
extends RefCounted

## Text Interpolator - Replaces variables in dialog text with runtime values
##
## Supported variable syntax:
##   {player_name}    - Hero character's name
##   {party_count}    - Total party size
##   {active_count}   - Active party members count
##   {gold}           - Current gold amount
##   {chapter}        - Current chapter number
##   {char:id}        - Character name by resource ID or UID (e.g., {char:max}, {char:hk7wm4np})
##   {flag:name}      - Story flag value ("true" or "false")
##   {var:key}        - Campaign data value by key
##
## Usage:
##   var text: String = TextInterpolator.interpolate("Hello, {player_name}!")
##   # Result: "Hello, Max!"


## Interpolate all variables in the given text
## Returns the text with all recognized variables replaced
## Unrecognized variables are left as-is (allows graceful fallback)
static func interpolate(text: String) -> String:
	if text.is_empty() or "{" not in text:
		return text

	var result: String = text

	# Process complex patterns first (ones with colons) to avoid partial matches
	# {char:id} - Character name lookup
	result = _interpolate_character_refs(result)

	# {flag:name} - Story flag lookup
	result = _interpolate_flags(result)

	# {var:key} - Campaign data lookup
	result = _interpolate_vars(result)

	# Process simple built-in variables last
	result = _interpolate_builtins(result)

	return result


## Replace built-in simple variables
static func _interpolate_builtins(text: String) -> String:
	var result: String = text

	# {player_name} - Hero's character name
	if "{player_name}" in result:
		result = result.replace("{player_name}", _get_player_name())

	# {party_count} - Total party size
	if "{party_count}" in result:
		result = result.replace("{party_count}", str(_get_party_count()))

	# {active_count} - Active party members
	if "{active_count}" in result:
		result = result.replace("{active_count}", str(_get_active_count()))

	# {gold} - Current gold
	if "{gold}" in result:
		result = result.replace("{gold}", str(_get_gold()))

	# {chapter} - Current chapter
	if "{chapter}" in result:
		result = result.replace("{chapter}", str(_get_chapter()))

	return result


## Replace {char:id} patterns with character names
static func _interpolate_character_refs(text: String) -> String:
	var result: String = text

	# Find all {char:...} patterns
	var regex: RegEx = RegEx.new()
	regex.compile("\\{char:([^}]+)\\}")

	var matches: Array[RegExMatch] = regex.search_all(result)
	# Process in reverse order to maintain string positions
	matches.reverse()

	for match_result: RegExMatch in matches:
		var full_match: String = match_result.get_string(0)
		var char_id: String = match_result.get_string(1)
		var char_name: String = _lookup_character_name(char_id)
		result = result.replace(full_match, char_name)

	return result


## Replace {flag:name} patterns with "true" or "false"
static func _interpolate_flags(text: String) -> String:
	var result: String = text

	var regex: RegEx = RegEx.new()
	regex.compile("\\{flag:([^}]+)\\}")

	var matches: Array[RegExMatch] = regex.search_all(result)
	matches.reverse()

	for match_result: RegExMatch in matches:
		var full_match: String = match_result.get_string(0)
		var flag_name: String = match_result.get_string(1)
		var flag_value: String = "true" if GameState.has_flag(flag_name) else "false"
		result = result.replace(full_match, flag_value)

	return result


## Replace {var:key} patterns with campaign data values
static func _interpolate_vars(text: String) -> String:
	var result: String = text

	var regex: RegEx = RegEx.new()
	regex.compile("\\{var:([^}]+)\\}")

	var matches: Array[RegExMatch] = regex.search_all(result)
	matches.reverse()

	for match_result: RegExMatch in matches:
		var full_match: String = match_result.get_string(0)
		var var_key: String = match_result.get_string(1)
		var var_value: Variant = GameState.get_campaign_data(var_key, "")
		result = result.replace(full_match, str(var_value))

	return result


## Look up a character name by resource ID or character_uid
static func _lookup_character_name(char_id: String) -> String:
	if char_id.is_empty():
		return "[unknown]"

	# Try ModLoader registry lookup
	if ModLoader and ModLoader.registry:
		# First try by character_uid
		var char_data: CharacterData = ModLoader.registry.get_character_by_uid(char_id)
		if char_data:
			return char_data.character_name

		# Fall back to resource ID lookup
		char_data = ModLoader.registry.get_character(char_id)
		if char_data:
			return char_data.character_name

	# Character not found - return placeholder
	return "[%s]" % char_id


## Get the hero/player character's name
static func _get_player_name() -> String:
	if PartyManager:
		var hero: CharacterData = PartyManager.get_hero()
		if hero:
			return hero.character_name
	return "Hero"


## Get total party size
static func _get_party_count() -> int:
	if PartyManager:
		return PartyManager.get_party_size()
	return 0


## Get active party member count
static func _get_active_count() -> int:
	if PartyManager:
		return PartyManager.get_active_count()
	return 0


## Get current gold amount
static func _get_gold() -> int:
	if SaveManager:
		return SaveManager.get_current_gold()
	return 0


## Get current chapter number
static func _get_chapter() -> int:
	if GameState:
		return GameState.get_campaign_data("current_chapter", 0)
	return 0

class_name TestMonogramFontCompliance
extends GdUnitTestSuite

## Monogram Font Size Compliance Test
##
## Monogram is a pixel font that only renders cleanly at specific sizes.
## All GAME UI fonts must use one of these sizes: 16, 24, 32, 48, 64
## (All are multiples of 8, which is Monogram's base unit)
##
## This test scans the codebase and fails if any game code uses non-compliant sizes.
## Editor code (addons/) is excluded as it can use system fonts.

const ALLOWED_SIZES: Array[int] = [16, 24, 32, 48, 64]

# Directories to scan (game code only, not editor)
const SCAN_DIRECTORIES: Array[String] = [
	"res://scenes/",
	"res://core/",
	"res://mods/",
]

# Directories to exclude (editor UI can use any font sizes)
const EXCLUDE_PATTERNS: Array[String] = [
	"addons/",
	"sparkling_editor",
]


func test_all_font_sizes_are_monogram_compliant() -> void:
	var violations: Array[Dictionary] = []

	for scan_dir in SCAN_DIRECTORIES:
		_scan_directory_for_violations(scan_dir, violations)

	# Build violation report for assertion message
	var report: String = ""
	if not violations.is_empty():
		report = "Found %d Monogram font size violations:\n" % violations.size()
		for v in violations:
			report += "  %s:%d - size %d\n" % [v.file, v.line, v.size]
		report += "Allowed sizes: %s" % str(ALLOWED_SIZES)

	# Assert no violations - the report will show in failure message
	assert_array(violations).override_failure_message(report).is_empty()


func _scan_directory_for_violations(dir_path: String, violations: Array[Dictionary]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		var full_path: String = dir_path.path_join(file_name)

		if dir.current_is_dir():
			if not file_name.begins_with("."):
				# Check exclusions
				var should_exclude: bool = false
				for pattern in EXCLUDE_PATTERNS:
					if full_path.contains(pattern):
						should_exclude = true
						break

				if not should_exclude:
					_scan_directory_for_violations(full_path, violations)
		else:
			if file_name.ends_with(".gd"):
				_scan_file_for_violations(full_path, violations)

		file_name = dir.get_next()

	dir.list_dir_end()


func _scan_file_for_violations(file_path: String, violations: Array[Dictionary]) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	var line_number: int = 0
	while not file.eof_reached():
		line_number += 1
		var line: String = file.get_line()

		# Look for font_size patterns
		# Patterns: add_theme_font_size_override("...", N) or font_size = N
		var size: int = _extract_font_size(line)
		if size > 0 and size not in ALLOWED_SIZES:
			violations.append({
				"file": file_path.replace("res://", ""),
				"line": line_number,
				"size": size,
				"code": line.strip_edges()
			})

	file.close()


func _extract_font_size(line: String) -> int:
	# Skip comments
	var comment_pos: int = line.find("#")
	if comment_pos == 0:
		return 0
	if comment_pos > 0:
		line = line.substr(0, comment_pos)

	# Pattern 1: add_theme_font_size_override("...", NUMBER)
	var regex1: RegEx = RegEx.new()
	regex1.compile("add_theme_font_size_override\\s*\\([^,]+,\\s*(\\d+)\\s*\\)")
	var match1: RegExMatch = regex1.search(line)
	if match1:
		return int(match1.get_string(1))

	# Pattern 2: "font_size": NUMBER (in theme overrides)
	var regex2: RegEx = RegEx.new()
	regex2.compile("\"font_size\"\\s*:\\s*(\\d+)")
	var match2: RegExMatch = regex2.search(line)
	if match2:
		return int(match2.get_string(1))

	# Pattern 3: font_size = NUMBER
	var regex3: RegEx = RegEx.new()
	regex3.compile("font_size\\s*=\\s*(\\d+)")
	var match3: RegExMatch = regex3.search(line)
	if match3:
		return int(match3.get_string(1))

	return 0



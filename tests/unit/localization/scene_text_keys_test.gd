## Guards static text in scene files: every single-line `text = "..."`,
## `title = "..."` and `dialog_text = "..."` property in a .tscn under res://src
## must be a translation key present in strings.csv, or be explicitly
## allowlisted below with a reason. Adding a new literal English static label to a
## scene fails this test. (Multi-line/escaped-newline values are not scanned; no
## scene currently uses them.)
extends GdUnitTestSuite

const CSV_PATH: String = "res://assets/localization/strings.csv"
const SCAN_ROOT: String = "res://src"

## Scenes excluded wholesale.
const SKIPPED_SCENES: Array[String] = [
	# QA scaffolding scene, never shown to players.
	"res://src/gameplay/missions/the_gap/the_gap.tscn",
]

## Literal values that may stay as static scene text. Each has a reason.
const ALLOWED_LITERALS: Dictionary = {
	# Empty placeholders that a script fills at runtime (or intentionally blank).
	"": "empty text",
	# Volume/scale readouts the owning script overwrites with "%d%%" at _ready().
	"80%": "runtime-overwritten volume readout (main_menu.gd / pause_menu.gd)",
	"100%": "runtime-overwritten UI scale readout (main_menu.gd)",
	# Save-slot buttons and overwrite prompt are rebuilt with tr() by main_menu.gd.
	"Slot 1": "runtime-overwritten slot button (main_menu.gd)",
	"Slot 2": "runtime-overwritten slot button (main_menu.gd)",
	"Slot 3": "runtime-overwritten slot button (main_menu.gd)",
	"This will overwrite Slot 1. Continue?": "runtime-overwritten prompt (main_menu.gd, MAIN_MENU_OVERWRITE_CONFIRM)",
	# MissionScene HUD placeholders overwritten every frame by mission_hud.gd via tr() keys.
	"Phase: --": "runtime-overwritten HUD placeholder",
	"Wave: --": "runtime-overwritten HUD placeholder",
	"Timer: --": "runtime-overwritten HUD placeholder",
	"Hero HP: --": "runtime-overwritten HUD placeholder",
	"Breaches: 0": "runtime-overwritten HUD placeholder",
	"0": "runtime-overwritten numeric readout (gold counter)",
	# Ready button text is reassigned from planning_cluster.gd's READY_LABEL/SKIP_LABEL constants.
	"Ready": "runtime-overwritten by planning_cluster.gd (READY_LABEL / SKIP_LABEL literals)",
	# hero_skill_tree_screen.gd assigns this label's text on every refresh (literal, not yet tr()).
	"1 purchase available this visit": "runtime-overwritten by hero_skill_tree_screen.gd",
}


func _load_rows() -> Dictionary:
	var rows: Dictionary = {}
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	if file == null:
		return rows
	var first: bool = true
	while not file.eof_reached():
		var cols: PackedStringArray = file.get_csv_line(",")
		if first:
			first = false
			continue
		if cols.size() >= 1 and not cols[0].is_empty():
			if not rows.has(cols[0]):
				rows[cols[0]] = []
			(rows[cols[0]] as Array).append(cols[1] if cols.size() >= 2 else "")
	return rows


func _collect_scenes(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_scenes(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


## Returns [[scene, line_no, prop, value], ...].
func _scan_static_texts() -> Array:
	var scenes: Array[String] = []
	_collect_scenes(SCAN_ROOT, scenes)
	var regex: RegEx = RegEx.new()
	regex.compile("^(text|title|dialog_text) = \"(.*)\"$")
	var found: Array = []
	for scene in scenes:
		if SKIPPED_SCENES.has(scene):
			continue
		var file: FileAccess = FileAccess.open(scene, FileAccess.READ)
		if file == null:
			continue
		var line_no: int = 0
		while not file.eof_reached():
			var line: String = file.get_line().strip_edges(false, true)
			line_no += 1
			var m: RegExMatch = regex.search(line)
			if m != null:
				found.append([scene, line_no, m.get_string(1), m.get_string(2)])
	return found


func test_csv_has_no_duplicate_keys() -> void:
	var rows: Dictionary = _load_rows()
	for key in rows:
		assert_int((rows[key] as Array).size()).override_failure_message("duplicate CSV key: %s" % key).is_equal(1)


func test_scene_static_text_is_key_or_allowlisted() -> void:
	var rows: Dictionary = _load_rows()
	var found: Array = _scan_static_texts()
	assert_int(found.size()).is_greater(0)
	for item in found:
		var value: String = item[3]
		var ok: bool = rows.has(value) or ALLOWED_LITERALS.has(value)
		assert_bool(ok).override_failure_message(
			"%s:%d %s = \"%s\" is neither a strings.csv key nor allowlisted (localize it)" % [item[0], item[1], item[2], value]
		).is_true()


func test_keys_used_by_scenes_have_english_values() -> void:
	var rows: Dictionary = _load_rows()
	for item in _scan_static_texts():
		var value: String = item[3]
		if rows.has(value):
			var english: String = (rows[value] as Array)[0]
			assert_str(english).override_failure_message("key %s has an empty English value" % value).is_not_empty()


func test_allowlist_has_no_dead_entries() -> void:
	var used: Dictionary = {}
	for item in _scan_static_texts():
		used[item[3]] = true
	for literal in ALLOWED_LITERALS:
		assert_bool(used.has(literal)).override_failure_message(
			"allowlist entry \"%s\" is not used by any scene; remove it" % literal
		).is_true()

class_name ResourceHeader
extends Control

## Sanctuary UI persistent resource header (Story 004, ADR-0001, epic-10-sanctuary-ui).
##
## GDD source: design/gdd/sanctuary-ui.md -- Core Rule 3, AC Group 3.
## Story: production/epics/epic-10-sanctuary-ui/story-004-resource-header.md
##
## Read-only pure subscriber to materials deltas -- owns no authoritative
## data, validates nothing, has no interactive affordance (never focusable,
## per Core Rule 3's explicit "not a 6th navigable region"). Renders at the
## top edge of the screen in every state, including OVERVIEW (Story 001's
## chrome layer already guarantees this header is always present/rendering).
##
## Gold deliberately NOT shown here (2026-08-06, design/quick-specs/
## sanctuary-header-drop-gold-2026-08-06.md), closing a real cross-GDD
## inconsistency found while investigating this class's own previously-
## flagged "no balance owner" gap: gold is mission-scoped ephemeral budget
## (resource-economy.md Rule 1, ADR-0018) -- reset to 0 on every
## mission_launched, no save/restore obligation, no carry-over mechanic to
## the Sanctuary anywhere in the codebase. A persistent Sanctuary gold
## display was never correct, regardless of who "owned" the balance; the
## fix is removing the display, not inventing a new balance-owning system to
## serve a display that shouldn't exist. Materials remain here since
## Inventory is their real ledger of record and they genuinely do persist
## into the Sanctuary.

var _materials: Dictionary = {}

@onready var _background: Panel = Panel.new()
@onready var _row: HBoxContainer = HBoxContainer.new()
@onready var _materials_label: Label = Label.new()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_theme_stylebox_override("panel", ShellChromeStyle.resource_header_stylebox())
	add_child(_background)

	_row.name = &"ResourceRow"
	add_child(_row)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 8)

	_materials_label.name = &"MaterialsLabel"
	_row.add_child(_materials_label)
	_materials_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_materials_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Pre-existing overflow, only exposed visually now that the Chrome
	# full-rect fix (sanctuary_ui.gd, 2026-08-04) lets this header actually
	# render at nonzero size: the untranslated placeholder key + material
	# list is long enough to autowrap to 2 lines and spill outside
	# HEADER_HEIGHT vertically. Single-line + ellipsis-trim + vertical
	# centering is a display-only fix (Story 004's own "read-only, no
	# authoritative data" scope) -- it doesn't touch the underlying text
	# content, which is a separate localization-catalogue gap every other
	# SANCTUARY_TAB_* key in this shell already has.
	_materials_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_materials_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_materials_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_materials_label.clip_contents = true
	_materials_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_refresh_label()
	GEventBus.materials_earned.connect(_on_materials_earned)
	GEventBus.materials_spent.connect(_on_materials_spent)


func _exit_tree() -> void:
	GEventBus.materials_earned.disconnect(_on_materials_earned)
	GEventBus.materials_spent.disconnect(_on_materials_spent)


## Test/inspection accessor -- current locally-accumulated quantity for one
## material type (0 if never seen).
func get_material_quantity(material_type: String) -> int:
	return int(_materials.get(material_type, 0))


func _on_materials_earned(material_type: String, quantity: int, _source: String) -> void:
	_materials[material_type] = int(_materials.get(material_type, 0)) + quantity
	_refresh_label()
	_play_scale_pop()


func _on_materials_spent(material_type: String, quantity: int, _destination: String) -> void:
	_materials[material_type] = int(_materials.get(material_type, 0)) - quantity
	_refresh_label()
	_play_scale_pop()


## GDD Visual/Audio Requirements: numeric changes reuse Inventory's existing
## scale-pop treatment (~1.0->1.15->1.0 over ~0.2s).
func _play_scale_pop() -> void:
	_row.pivot_offset = _row.size / 2.0
	_row.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(_row, "scale", Vector2(1.15, 1.15), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_row, "scale", Vector2.ONE, 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _refresh_label() -> void:
	var parts: PackedStringArray = []
	for material_type: String in _materials:
		parts.append("%s %d" % [material_type, _materials[material_type]])
	_materials_label.text = " · ".join(parts)

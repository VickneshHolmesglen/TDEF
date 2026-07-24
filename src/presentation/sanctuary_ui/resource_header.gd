class_name ResourceHeader
extends Control

## Sanctuary UI persistent resource header (Story 004, ADR-0001, epic-10-sanctuary-ui).
##
## GDD source: design/gdd/sanctuary-ui.md -- Core Rule 3, AC Group 3.
## Story: production/epics/epic-10-sanctuary-ui/story-004-resource-header.md
##
## Read-only pure subscriber to gold/materials deltas -- owns no authoritative
## data, validates nothing, has no interactive affordance (never focusable,
## per Core Rule 3's explicit "not a 6th navigable region"). Renders at the
## top edge of the screen in every state, including OVERVIEW (Story 001's
## chrome layer already guarantees this header is always present/rendering).
##
## REAL ARCHITECTURAL GAP, FLAGGED NOT SILENTLY WORKED AROUND: the GDD's own
## Edge Cases section requires a "mount-time poll fallback" against Resource
## Economy's current balance if resources_changed hasn't fired yet. No system
## in this project actually owns or exposes a queryable Sanctuary-context
## gold/materials balance -- checked directly: `resource_economy.gd` (ADR-0017)
## only owns a `_menagerie_quality_bonus` scalar and has no balance getter;
## `mission_economy.gd` (ADR-0018) owns gold but is explicitly Mission-only,
## reset to 0 on `mission_launched`, and "holds a stale balance during
## SanctuaryScene" per ADR-0002's own diagram note -- not the right owner for
## a Sanctuary display. This is a real, unresolved cross-system ownership gap,
## not a naming mismatch like Story 003's -- inventing a new balance-owning
## Autoload mid-story would be significant scope creep past this Presentation-
## layer header. Implemented instead as a pure local running tally accumulated
## from already-emitted deltas (resources_changed/materials_earned/
## materials_spent) -- this is a display cache, not state ownership, since it
## never writes anything back (Core Rule 3's "owns no data" is about
## authoritative ownership, not about caching already-public deltas for
## display). The mount-time-poll AC specifically (never show empty/zero before
## the first event) is NOT implementable as literally specified until a real
## balance-owning system exists -- tracked as a new gap for whoever resolves
## it, same honesty standard this epic's own Story 003 substitution used.

var _gold: int = 0
var _materials: Dictionary = {}

@onready var _background: Panel = Panel.new()
@onready var _label: Label = Label.new()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_theme_stylebox_override("panel", ShellChromeStyle.chrome_panel_stylebox())
	add_child(_background)
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_refresh_label()
	GEventBus.resources_changed.connect(_on_resources_changed)
	GEventBus.materials_earned.connect(_on_materials_earned)
	GEventBus.materials_spent.connect(_on_materials_spent)


func _exit_tree() -> void:
	GEventBus.resources_changed.disconnect(_on_resources_changed)
	GEventBus.materials_earned.disconnect(_on_materials_earned)
	GEventBus.materials_spent.disconnect(_on_materials_spent)


## Test/inspection accessor -- current locally-accumulated gold tally.
func get_gold() -> int:
	return _gold


## Test/inspection accessor -- current locally-accumulated quantity for one
## material type (0 if never seen).
func get_material_quantity(material_type: String) -> int:
	return int(_materials.get(material_type, 0))


func _on_resources_changed(gold: int, _source: StringName) -> void:
	# gold is a signed delta, matching MissionEconomy's own accumulation
	# convention (control-manifest.md, ADR-0018) -- not an absolute balance.
	_gold += gold
	_refresh_label()
	_play_scale_pop()


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
	_label.pivot_offset = _label.size / 2.0
	_label.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(_label, "scale", Vector2(1.15, 1.15), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "scale", Vector2.ONE, 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _refresh_label() -> void:
	var parts: PackedStringArray = []
	for material_type: String in _materials:
		parts.append("%s %d" % [material_type, _materials[material_type]])
	_label.text = "%s: %d    %s" % [
		tr("SANCTUARY_HEADER_GOLD_LABEL"), _gold, " · ".join(parts)
	]

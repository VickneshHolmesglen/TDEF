extends Control

## Diorama -- Sanctuary UI's OVERVIEW-state content (Story 001 Core Rule 1,
## epic-10 Story 013 Visual/Audio Pass).
##
## GDD source: design/gdd/sanctuary-ui.md -- Core Rule 1 ("full-canvas
## diorama... showing all built structures and habitat occupancy at their
## fixed, hand-authored positions"), Visual/Audio Requirements (diorama
## stacked-sprite/cast-shadow treatment, DEPARTING camera pull-back).
##
## Real gap closed 2026-07-25: this node was Story 001's placeholder, empty
## `Control` with 0 children for this entire epic (confirmed by Story 012's
## own finding) until now. Real diorama art was attempted first via this
## project's own ComfyUI asset-generation pipeline (`tools/generate_asset.py`)
## but hard-failed on a CUDA/ZLUDA driver error at the very first
## embedding-tensor allocation (`torch.nn.modules.sparse.Embedding.__init__`,
## "CUDA error: operation not supported") -- a local GPU/driver environment
## issue on this machine's AMD setup, not something fixable from this
## codebase. Falls back to the same "plain shape/text, no art exists"
## honest-scope convention already used project-wide this session (Tarot,
## Hero Skill Build, Equipment Forge screens) -- `ColorRect` placeholders per
## structure type instead of generated sprites. The GDD's own "full
## stacked-sprite/cast-shadow treatment" requirement remains a real, flagged
## gap pending actual art -- not fabricated here.
##
## "Camera" pull-back (DEPARTING beat): this node's own root is a `Control`,
## not a `Node2D`/`Viewport`, so a literal `Camera2D` has no meaningful
## effect here. Implemented instead as a scale+position tween on the `World`
## container -- visually equivalent to a camera pull-back for a single flat
## layer with no parallax, and avoids introducing a `SubViewport` (ADR-0013
## forbids SubViewport-*per-entity*-compositing specifically; a single
## diorama-wide viewport would be defensible but adds real complexity this
## fallback-scope pass doesn't need for one flat layer).
##
## Shell-owned: instantiated once by `SanctuaryUI`, persists for the shell's
## whole lifetime regardless of active state (Core Rule 1 -- "keeps running...
## even while occluded by a room") -- subscriptions stay live throughout,
## never torn down on a room switch.

## One shared placeholder color per structure_type -- not per structure_id,
## since later tiers of the same type (e.g. habitat_expansion_tier_2/3)
## upgrade the same physical footprint in place, matching Defense Building's
## own upgrade-in-place model. Real content today: only "watchtower" and
## "habitat_expansion" exist as authored StructureResource types.
## "watchtower" now has real art (see WATCHTOWER_TEXTURE below) -- this
## color entry is unused for it but left as the Color.GRAY fallback path's
## documented default for any future structure_type with no art yet.
const STRUCTURE_COLORS: Dictionary[String, Color] = {
	"watchtower": Color(0.55, 0.55, 0.6),
	"habitat_expansion": Color(0.35, 0.65, 0.35),
}

## Fixed, hand-authored positions (GDD Core Rule 1's own requirement) --
## chosen to roughly match design/ux/sanctuary-ui.md's own ASCII wireframe
## layout (Watchtower left, Habitat right, both mid-frame).
const STRUCTURE_POSITIONS: Dictionary[String, Vector2] = {
	"watchtower": Vector2(120, 90),
	"habitat_expansion": Vector2(320, 160),
}

const STRUCTURE_SIZE: Vector2 = Vector2(64, 64)

## Real watchtower_tier_1 art (2026-07-31) -- only "watchtower" has real
## content; "habitat_expansion" still uses the ColorRect placeholder below
## until its own art exists. Source: user-provided reference image, color-
## keyed from a flat opaque background to real transparency (the source PNG
## had alpha=1.0 everywhere, including a uniform light-grey backdrop -- not
## actually transparent despite being RGBA). Only watchtower_tier_1 exists
## as real StructureResource data today (no tier_2/3/4 authored yet), and
## _render_structure() below still renders once per structure_type
## regardless of tier, matching its own existing "upgrades in place, no new
## visual yet" scope discipline -- this is a real, single, non-tiered asset,
## not a placeholder for a tier system that doesn't exist yet.
const WATCHTOWER_TEXTURE: Texture2D = preload("res://assets/art/sanctuary/watchtower.png")
const WATCHTOWER_DISPLAY_HEIGHT: float = 64.0  ## matches STRUCTURE_SIZE.y for scale consistency with the habitat placeholder rect

@onready var _world: Node2D = $World

## Injectable for tests; defaults to the real GMenagerie Autoload (unlike
## Tarot/EquipmentForge, Menagerie is a real Autoload, not scene-instanced --
## matches menagerie_screen.gd's own identical default).
@export var menagerie: Menagerie

## Control, not ColorRect -- "watchtower" is now a TextureRect (real art),
## "habitat_expansion" remains a ColorRect (no art yet). Both are Control
## subclasses so the shared lookup/removal logic doesn't need to care which.
var _rendered_structure_types: Dictionary[String, Control] = {}
var _habitat_label: Label = null


func _ready() -> void:
	if menagerie == null:
		menagerie = GMenagerie
	GEventBus.sanctuary_structure_built.connect(_on_sanctuary_structure_built)
	GEventBus.creature_acquired.connect(_on_habitat_composition_changed)
	GEventBus.creature_happiness_changed.connect(_on_creature_happiness_changed)
	GEventBus.creature_sacrificed.connect(_on_habitat_composition_changed)


func _exit_tree() -> void:
	GEventBus.sanctuary_structure_built.disconnect(_on_sanctuary_structure_built)
	GEventBus.creature_acquired.disconnect(_on_habitat_composition_changed)
	GEventBus.creature_happiness_changed.disconnect(_on_creature_happiness_changed)
	GEventBus.creature_sacrificed.disconnect(_on_habitat_composition_changed)


func _on_sanctuary_structure_built(_structure_id: String, structure_type: String) -> void:
	_render_structure(structure_type)


## Edge case (GDD): a structure_type with no diorama position mapping (none
## exist today -- both real types are mapped) renders nothing rather than
## erroring, matching the GDD's own "inert tooltip, no crash" precedent for
## unmapped structures elsewhere in this shell.
func _render_structure(structure_type: String) -> void:
	if _rendered_structure_types.has(structure_type):
		return  # already rendered -- a later tier of the same type upgrades in place (same visual, no new asset yet, honest scope)
	if not STRUCTURE_POSITIONS.has(structure_type):
		return

	var visual: Control = _build_watchtower_sprite() if structure_type == "watchtower" else _build_placeholder_rect(structure_type)
	_world.add_child(visual)
	_rendered_structure_types[structure_type] = visual

	if structure_type == "habitat_expansion":
		_ensure_habitat_label(visual)


## Real art path (2026-07-31) -- see WATCHTOWER_TEXTURE's own doc comment.
func _build_watchtower_sprite() -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.name = "Structure_watchtower"
	tex_rect.texture = WATCHTOWER_TEXTURE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	var aspect: float = float(WATCHTOWER_TEXTURE.get_width()) / float(WATCHTOWER_TEXTURE.get_height())
	var display_size := Vector2(WATCHTOWER_DISPLAY_HEIGHT * aspect, WATCHTOWER_DISPLAY_HEIGHT)
	tex_rect.size = display_size
	tex_rect.position = STRUCTURE_POSITIONS["watchtower"] - display_size / 2.0
	# See _build_placeholder_rect()'s identical note -- same reasoning.
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex_rect


## No-art-yet path -- currently only "habitat_expansion" uses this.
func _build_placeholder_rect(structure_type: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Structure_%s" % structure_type
	rect.color = STRUCTURE_COLORS.get(structure_type, Color.GRAY)
	rect.size = STRUCTURE_SIZE
	rect.position = STRUCTURE_POSITIONS[structure_type] - STRUCTURE_SIZE / 2.0
	# No click/room-entry handler exists yet for these placeholders (GDD's
	# "click a structure to enter its room" secondary entry path is a future
	# story's scope) -- Control's default MOUSE_FILTER_STOP would otherwise
	# silently swallow clicks aimed at anything else with no handler of its
	# own to show for it. Explicit MOUSE_FILTER_IGNORE until that story wires
	# real click handling here.
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## GDD Core Rule 1: diorama shows "habitat occupancy" alongside structures --
## a plain-text count overlay on the habitat structure's own placeholder,
## matching this shell's own no-art text-tag convention.
func _ensure_habitat_label(rect: Control) -> void:
	if _habitat_label != null:
		return
	_habitat_label = Label.new()
	_habitat_label.position = Vector2(0.0, STRUCTURE_SIZE.y + 2.0)
	rect.add_child(_habitat_label)
	_refresh_habitat_label()


func _on_habitat_composition_changed(_a: Variant = null, _b: Variant = null) -> void:
	_refresh_habitat_label()


func _on_creature_happiness_changed(_creature_id: int, _new_happiness: float, _quality_bonus: float) -> void:
	_refresh_habitat_label()


func _refresh_habitat_label() -> void:
	if _habitat_label == null or menagerie == null:
		return
	var count: int = 0
	for creature: CreatureInstance in menagerie.get_all_creatures():
		if creature.state == CreatureInstance.CreatureState.HABITAT:
			count += 1
	_habitat_label.text = "Habitat: %d" % count


## DEPARTING beat (GDD Visual/Audio Requirements, Tuning Knobs' 60/40 split):
## chrome fades separately (sanctuary_ui.gd's own _play_departing_chrome_fade())
## -- this plays the diorama's own pull-back-and-settle 60% half within the
## same total budget.
func play_departing_pull_back(total_duration: float = 0.5) -> void:
	var pull_back_duration: float = total_duration * 0.6
	var tween: Tween = create_tween()
	tween.tween_property(_world, "scale", Vector2(0.85, 0.85), pull_back_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_world, "position", _world.position - Vector2(20.0, 10.0), pull_back_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Test/inspection accessors
# ---------------------------------------------------------------------------

func get_rendered_structure_types() -> Array[String]:
	return _rendered_structure_types.keys()


func get_habitat_label_text() -> String:
	return _habitat_label.text if _habitat_label != null else ""


func get_world() -> Node2D:
	return _world

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
## codebase. Fell back to the same "plain shape/text, no art exists"
## honest-scope convention already used project-wide this session (Tarot,
## Hero Skill Build, Equipment Forge screens) -- `ColorRect` placeholders per
## structure type instead of generated sprites. Both real structure types
## (`watchtower`, `habitat_expansion`) since gained real, user-provided art
## (2026-07-31/2026-08-01, see WATCHTOWER_TEXTURE/HABITAT_TEXTURES below) --
## the GDD's own "full stacked-sprite/cast-shadow treatment" requirement is
## narrower now but still not fully closed (no cast-shadow layer exists).
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

## Fixed, hand-authored positions (GDD Core Rule 1's own requirement) --
## medieval-town composition (2026-08-21, player-requested): Castle sits
## back-center as the town's landmark anchor, with Watchtower and Habitat
## flanking it lower/left-right, forming a simple triangle. "Lower on screen
## = closer to the viewer" matches this diorama's own existing Y-ordering
## convention (structures further "back" render smaller/higher).
const STRUCTURE_POSITIONS: Dictionary[String, Vector2] = {
	"castle": Vector2(220, 80),
	"watchtower": Vector2(120, 150),
	"habitat_expansion": Vector2(320, 150),
}

const STRUCTURE_SIZE: Vector2 = Vector2(64, 64)

## Castle (2026-08-21, player-requested): the town's decorative centerpiece
## landmark -- explicitly NOT a real gameplay structure (no StructureResource,
## no tech-tree entry, no tier/upgrade path, never fires sanctuary_structure_
## built). No art has been generated for it, so it renders as a plain bordered
## placeholder shape, same "no art exists yet, be honest about it" convention
## this file used for watchtower/habitat_expansion before their real art
## arrived (see this file's own header comment). Sized larger than the other
## two structures -- a town's castle should read as the biggest, most central
## building, not a same-size peer.
const CASTLE_SIZE: Vector2 = Vector2(80, 96)
const CASTLE_LABEL: String = "Castle"

## Real watchtower_tier_1 art (2026-07-31). Source: user-provided reference
## image, color-keyed from a flat opaque background to real transparency
## (the source PNG had alpha=1.0 everywhere, including a uniform light-grey
## backdrop -- not actually transparent despite being RGBA). Only
## watchtower_tier_1 exists as real StructureResource data today (no
## tier_2/3/4 authored yet), and _render_structure() below still renders
## once regardless of tier, matching its own existing "upgrades in place, no
## new visual yet" scope discipline -- this is a real, single, non-tiered
## asset, not a placeholder for a tier system that doesn't exist yet. (Contrast
## habitat_expansion below, which does have 4 real tiers and its own
## tier-swap path, _render_habitat().)
const WATCHTOWER_TEXTURE: Texture2D = preload("res://assets/art/sanctuary/watchtower.png")
const WATCHTOWER_DISPLAY_HEIGHT: float = 64.0  ## matches STRUCTURE_SIZE.y for scale consistency with the habitat placeholder rect

## Art & Animation Pipeline Upgrade, vertical slice (design/art/animation-
## pipeline.md §2 "Environment: procedural only"). The directive names
## "goal/sanctuary light flickering" explicitly as an example of the subtle
## environmental motion this pass should add; the watchtower is the one
## single, reusable (non-per-mission) Sanctuary structure asset today, making
## it the lowest-risk demonstrative pick. A small beacon-glow blob pulses at
## the tower's top, matching the tower idle-ambient precedent
## (TowerInstance.set_idle_ambient()) of "quietly present, never competing"
## rather than a loud effect. Deliberately NOT reusing Sanctum Amber
## (already the project's established "special status" badge color, e.g.
## TowerInstance.PERK_BADGE_COLOR) -- a warm lantern-white avoids implying a
## gameplay-state meaning that isn't there (Art Bible P3: color communicates
## before it decorates).
const BEACON_GLOW_COLOR: Color = Color(1.0, 0.92, 0.75)
const BEACON_GLOW_RADIUS: float = 5.0
const BEACON_GLOW_MIN_ALPHA: float = 0.25
const BEACON_GLOW_MAX_ALPHA: float = 0.65
const BEACON_GLOW_PULSE_DURATION: float = 1.8  ## seconds per half-cycle -- slow, "noticeable only when looking for it"

## Real habitat_expansion tier art (2026-08-01, see
## design/quick-specs/habitat-expansion-tiered-art-2026-08-01.md) -- unlike
## watchtower (single-tier), habitat_expansion has 4 real authored tiers
## (habitat_expansion_tier_1/2/3/4), so this structure_type's diorama visual
## swaps texture in place as the player upgrades, instead of rendering once
## and staying static forever. Source: the same user-provided reference
## image set as watchtower's, cropped into per-tier sprites and flood-fill
## background-keyed to transparency from the canvas edges (a fixed-color-
## distance key, as used for watchtower.png, left visible noise/gradient
## artifacts in the background here -- flood fill from the border follows
## the actual local background instead of assuming one uniform color).
## Tier 4 (the set's 4th, grandest building) added 2026-08-03 alongside a
## real habitat_expansion_tier_4 StructureResource + tech_structural_3 gate
## (see design/quick-specs/habitat-expansion-tier-4-2026-08-03.md) -- closes
## the "4th building unused, no design slot" gap flagged since 2026-08-01.
const HABITAT_TEXTURES: Dictionary[int, Texture2D] = {
	1: preload("res://assets/art/sanctuary/habitat_tier_1.png"),
	2: preload("res://assets/art/sanctuary/habitat_tier_2.png"),
	3: preload("res://assets/art/sanctuary/habitat_tier_3.png"),
	4: preload("res://assets/art/sanctuary/habitat_tier_4.png"),
}
const HABITAT_DISPLAY_HEIGHT: float = 64.0  ## matches STRUCTURE_SIZE.y, same reasoning as WATCHTOWER_DISPLAY_HEIGHT

@onready var _world: Node2D = $World

## Injectable for tests; defaults to the real GMenagerie Autoload (unlike
## Tarot/EquipmentForge, Menagerie is a real Autoload, not scene-instanced --
## matches menagerie_screen.gd's own identical default).
@export var menagerie: Menagerie

## Both "watchtower" and "habitat_expansion" now render as TextureRect (real
## art for both, see WATCHTOWER_TEXTURE/HABITAT_TEXTURES) -- typed as the
## shared Control base so the lookup/removal logic doesn't need to care
## about the concrete subclass, in case a future structure_type ever needs
## a different Control-derived visual again.
var _rendered_structure_types: Dictionary[String, Control] = {}
var _habitat_label: Label = null

## Tracks the highest habitat_expansion tier rendered so far (0 = not built
## yet) -- see design/quick-specs/habitat-expansion-tiered-art-2026-08-01.md.
## watchtower needs no equivalent since only one tier of it exists.
var _habitat_tier: int = 0


func _ready() -> void:
	if menagerie == null:
		menagerie = GMenagerie
	_render_castle()
	GEventBus.sanctuary_structure_built.connect(_on_sanctuary_structure_built)
	GEventBus.creature_acquired.connect(_on_habitat_composition_changed)
	GEventBus.creature_happiness_changed.connect(_on_creature_happiness_changed)
	GEventBus.creature_sacrificed.connect(_on_habitat_composition_changed)


func _exit_tree() -> void:
	GEventBus.sanctuary_structure_built.disconnect(_on_sanctuary_structure_built)
	GEventBus.creature_acquired.disconnect(_on_habitat_composition_changed)
	GEventBus.creature_happiness_changed.disconnect(_on_creature_happiness_changed)
	GEventBus.creature_sacrificed.disconnect(_on_habitat_composition_changed)


func _on_sanctuary_structure_built(structure_id: String, structure_type: String) -> void:
	if structure_type == "habitat_expansion":
		_render_habitat(structure_id)
	else:
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

	var visual: Control = _build_watchtower_sprite()
	_world.add_child(_build_shadow_for(STRUCTURE_POSITIONS["watchtower"], visual.size, "watchtower"))  # added BEFORE the sprite -- draws underneath (2D tree-order compositing)
	_world.add_child(visual)
	_world.add_child(_build_beacon_glow(visual))  # added AFTER the sprite -- draws on top, at the tower's beacon point
	_rendered_structure_types[structure_type] = visual


## habitat_expansion has its own path (not the generic _render_structure()
## above) because it's the one structure_type with real multi-tier art --
## see design/quick-specs/habitat-expansion-tiered-art-2026-08-01.md. First
## build creates the node; a later, higher tier swaps its texture in place
## instead of the generic path's "already rendered, no-op" rule.
func _render_habitat(structure_id: String) -> void:
	var structure: StructureResource = GGameDataRegistry.get_structure(StringName(structure_id))
	var tier: int = structure.tier if structure != null else 1
	if not HABITAT_TEXTURES.has(tier):
		tier = 1  # no art for this tier yet -- fall back rather than erroring

	if not _rendered_structure_types.has("habitat_expansion"):
		var visual: TextureRect = _build_habitat_sprite(tier)
		_world.add_child(_build_shadow_for(STRUCTURE_POSITIONS["habitat_expansion"], visual.size, "habitat_expansion"))  # draws underneath, same convention as watchtower
		_world.add_child(visual)
		_rendered_structure_types["habitat_expansion"] = visual
		_habitat_tier = tier
		_ensure_habitat_label(visual)
		return

	if tier <= _habitat_tier:
		return  # tiers only build forward in real play -- never downgrade the visual

	var tex_rect := _rendered_structure_types["habitat_expansion"] as TextureRect
	tex_rect.texture = HABITAT_TEXTURES[tier]
	_habitat_tier = tier


## Art bible Principle 1 ("Everything Has Weight and Depth"): a ground-
## contact cast-shadow layer beneath a structure sprite, closing the
## GDD's own "full stacked-sprite/cast-shadow treatment" requirement.
## Positioned at the sprite's base (bottom-center of its bounding box,
## not its full center) and sized proportional to sprite width so it
## reads as ground contact, not a second copy of the sprite silhouette.
## structure_type only names the node uniquely (Godot's own sibling-name
## collision resolution otherwise renames a second same-named Control to
## an anonymous "@Control@N", found live via Godot MCP while verifying
## this — cosmetic, not a rendering defect, but worth a real name).
func _build_shadow_for(structure_center: Vector2, sprite_display_size: Vector2, structure_type: String) -> StructureCastShadow:
	var shadow := StructureCastShadow.new()
	shadow.name = "Shadow_%s" % structure_type
	shadow.ellipse_size = Vector2(sprite_display_size.x * 0.7, sprite_display_size.y * 0.18)
	shadow.size = shadow.ellipse_size
	shadow.position = Vector2(
		structure_center.x - shadow.size.x / 2.0,
		structure_center.y + sprite_display_size.y / 2.0 - shadow.size.y / 2.0
	)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shadow


## Renders the Castle placeholder once, unconditionally, at _ready() -- unlike
## every other structure here, it never waits for sanctuary_structure_built
## (it isn't a real structure, see CASTLE_SIZE's own doc comment) and is
## always present as soon as the diorama mounts, matching a town's landmark
## always being "just there" rather than something the player unlocks.
func _render_castle() -> void:
	var visual: Panel = _build_castle_placeholder()
	_world.add_child(_build_shadow_for(STRUCTURE_POSITIONS["castle"], CASTLE_SIZE, "castle"))  # underneath, same convention as the other structures
	_world.add_child(visual)


## Plain bordered placeholder + centered label -- see CASTLE_SIZE's own doc
## comment for why there is no real art to render here yet.
func _build_castle_placeholder() -> Panel:
	var panel := Panel.new()
	panel.name = "Structure_castle"
	panel.size = CASTLE_SIZE
	panel.position = STRUCTURE_POSITIONS["castle"] - CASTLE_SIZE / 2.0
	panel.add_theme_stylebox_override("panel", ShellChromeStyle.chrome_button_stylebox(false))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # see _build_watchtower_sprite()'s identical note -- no click handler exists for diorama structures yet

	var label := Label.new()
	label.text = CASTLE_LABEL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	return panel


## Real art path (2026-07-31) -- see WATCHTOWER_TEXTURE's own doc comment.
func _build_watchtower_sprite() -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.name = "Structure_watchtower"
	tex_rect.texture = WATCHTOWER_TEXTURE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	# See _build_habitat_sprite()'s identical note -- same bug, same fix,
	# found live via Godot MCP while verifying the Tier 4 habitat addition.
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var aspect: float = float(WATCHTOWER_TEXTURE.get_width()) / float(WATCHTOWER_TEXTURE.get_height())
	var display_size := Vector2(WATCHTOWER_DISPLAY_HEIGHT * aspect, WATCHTOWER_DISPLAY_HEIGHT)
	tex_rect.size = display_size
	tex_rect.position = STRUCTURE_POSITIONS["watchtower"] - display_size / 2.0
	# No click/room-entry handler exists yet for diorama structures (GDD's
	# "click a structure to enter its room" secondary entry path is a future
	# story's scope) -- Control's default MOUSE_FILTER_STOP would otherwise
	# silently swallow clicks aimed at anything else with no handler of its
	# own to show for it. Explicit MOUSE_FILTER_IGNORE until that story wires
	# real click handling here.
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex_rect


## See BEACON_GLOW_COLOR's own doc comment. sprite: the already-positioned
## watchtower TextureRect, used only to derive the glow's position (top-
## center of the sprite's bounding box) -- never reparented under it, so it
## draws in the same _world sibling order as the sprite/shadow above.
func _build_beacon_glow(sprite: Control) -> Panel:
	var glow := Panel.new()
	glow.name = "WatchtowerBeaconGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var diameter: float = BEACON_GLOW_RADIUS * 2.0
	glow.size = Vector2(diameter, diameter)
	glow.position = Vector2(sprite.position.x + sprite.size.x * 0.5 - BEACON_GLOW_RADIUS, sprite.position.y - BEACON_GLOW_RADIUS * 0.5)
	var style := StyleBoxFlat.new()
	style.bg_color = BEACON_GLOW_COLOR
	style.corner_radius_top_left = int(BEACON_GLOW_RADIUS)
	style.corner_radius_top_right = int(BEACON_GLOW_RADIUS)
	style.corner_radius_bottom_left = int(BEACON_GLOW_RADIUS)
	style.corner_radius_bottom_right = int(BEACON_GLOW_RADIUS)
	glow.add_theme_stylebox_override("panel", style)
	glow.modulate.a = BEACON_GLOW_MIN_ALPHA
	var tween: Tween = glow.create_tween()
	tween.set_loops()  ## infinite -- "ambient motion should generally be noticeable only when looking for it," never a one-shot
	tween.tween_property(glow, "modulate:a", BEACON_GLOW_MAX_ALPHA, BEACON_GLOW_PULSE_DURATION)
	tween.tween_property(glow, "modulate:a", BEACON_GLOW_MIN_ALPHA, BEACON_GLOW_PULSE_DURATION)
	return glow


## Real art path (2026-08-01) -- see HABITAT_TEXTURES' own doc comment. tier
## selects which of the 4 authored sprites to use; sizing/positioning use
## HABITAT_DISPLAY_HEIGHT/STRUCTURE_POSITIONS the same way watchtower does.
func _build_habitat_sprite(tier: int) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.name = "Structure_habitat_expansion"
	var texture: Texture2D = HABITAT_TEXTURES[tier]
	tex_rect.texture = texture
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	# Found live via Godot MCP while verifying Tier 4 (2026-08-03): TextureRect's
	# default expand_mode (EXPAND_KEEP_SIZE) reports the texture's own native
	# pixel size as its minimum size, which silently clamps the `.size =
	# display_size` assignment below right back to native dimensions on the
	# same frame -- every tier (and watchtower, same bug, same fix applied
	# there) had been rendering at full native art-generation resolution
	# instead of the intended HABITAT_DISPLAY_HEIGHT-scaled size the whole
	# time. EXPAND_IGNORE_SIZE makes the manually-set size authoritative.
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var aspect: float = float(texture.get_width()) / float(texture.get_height())
	var display_size := Vector2(HABITAT_DISPLAY_HEIGHT * aspect, HABITAT_DISPLAY_HEIGHT)
	tex_rect.size = display_size
	tex_rect.position = STRUCTURE_POSITIONS["habitat_expansion"] - display_size / 2.0
	# See _build_watchtower_sprite()'s identical note -- same reasoning.
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex_rect


## GDD Core Rule 1: diorama shows "habitat occupancy" alongside structures --
## a plain-text count overlay parented to the habitat structure's own
## visual (real art since 2026-08-01; the label itself has no art of its
## own, matching this shell's no-art text-tag convention for readouts).
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
	_habitat_label.text = tr("DIORAMA_HABITAT_COUNT") % count


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

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
	"watchtower": Vector2(120, 150),
	"habitat_expansion": Vector2(320, 150),
}

const STRUCTURE_SIZE: Vector2 = Vector2(64, 64)

## The Castle centerpiece is now a town building (TOWN_BUILDING_PATHS,
## castle.tres) that grows with overall progress; its old text card is gone.

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

## Town buildings (sanctuary town buildings spec, 2026-10-07): one building per
## side-panel tab plus the Castle, each growing through 5 tiers with that
## tab's progress (SanctuaryProgress). Data in assets/data/sanctuary_buildings/.
## Drawn beneath the built-structure sprites; replaces the old Castle card.
const TOWN_BUILDING_PATHS: Array[String] = [
	"res://assets/data/sanctuary_buildings/castle.tres",
	"res://assets/data/sanctuary_buildings/seers_tower.tres",
	"res://assets/data/sanctuary_buildings/armoury.tres",
	"res://assets/data/sanctuary_buildings/blacksmith.tres",
	"res://assets/data/sanctuary_buildings/training_hall.tres",
	"res://assets/data/sanctuary_buildings/menagerie.tres",
	"res://assets/data/sanctuary_buildings/keep.tres",
]
## Emitted when a clickable building is pressed; SanctuaryUI routes it through
## the tab strip so the room switch matches a side-panel click exactly.
signal building_selected(target_state: StringName)

var _town_views: Dictionary[StringName, TownBuildingView] = {}
var _town_info_label: Label = null
## Progress events that can raise a building's tier (spec §4).
var _town_refresh_signals: Array[Signal] = []

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
	_build_town()
	_setup_hd2d_backdrop()
	resized.connect(_setup_hd2d_backdrop)
	GEventBus.sanctuary_structure_built.connect(_on_sanctuary_structure_built)
	GEventBus.creature_acquired.connect(_on_habitat_composition_changed)
	GEventBus.creature_happiness_changed.connect(_on_creature_happiness_changed)
	GEventBus.creature_sacrificed.connect(_on_habitat_composition_changed)


func _exit_tree() -> void:
	for sig: Signal in _town_refresh_signals:
		if sig.is_connected(_on_town_progress_event):
			sig.disconnect(_on_town_progress_event)
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


# ---------------------------------------------------------------------------
# Town buildings (sanctuary town buildings spec, 2026-10-07)
# ---------------------------------------------------------------------------

func _build_town() -> void:
	var town := Node2D.new()
	town.name = "Town"
	_world.add_child(town)
	_world.move_child(town, 0)  # beneath every built-structure sprite/shadow
	for path: String in TOWN_BUILDING_PATHS:
		var res: SanctuaryBuildingResource = load(path) as SanctuaryBuildingResource
		if res == null:
			continue
		var view := TownBuildingView.new()
		view.setup(res)
		view.pressed.connect(_on_town_building_pressed.bind(res.building_id))
		view.mouse_entered.connect(_show_town_info.bind(res.building_id))
		view.focus_entered.connect(_show_town_info.bind(res.building_id))
		view.mouse_exited.connect(_show_town_prompt)
		view.focus_exited.connect(_show_town_prompt)
		town.add_child(view)
		_town_views[res.building_id] = view
	add_child(_build_town_info_strip())
	_show_town_prompt()
	_town_refresh_signals = [
		GEventBus.slot_expansion_completed, GEventBus.recipe_discovered, GEventBus.creature_acquired,
		GEventBus.creature_bred, GEventBus.creature_sacrificed, GEventBus.tech_unlocked,
		GEventBus.item_rune_imbued, GEventBus.hero_equipment_crafted, GEventBus.skill_tree_node_unlocked,
		GEventBus.tarot_deck_changed, GEventBus.sanctuary_structure_built,
	]
	for sig: Signal in _town_refresh_signals:
		sig.connect(_on_town_progress_event)
	visibility_changed.connect(_on_town_visibility_changed)
	refresh_town(false)


## ADR-0042 dioramas pass (2026-10-12): the HD-2D town scenery, rendered in
## its own SubViewport, replaces the painted Background image. The building
## buttons stay on top unchanged; the scenery camera frames this Control's own
## rect so each building stands on the dirt pad laid out under it. Rebuilt
## only when the diorama's size changes; with no profile the painted image
## stays.
var _town_backdrop: Hd2dTownBackdrop


func _setup_hd2d_backdrop() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var background: TextureRect = get_node_or_null(^"Background") as TextureRect
	if background == null:
		return
	if _town_backdrop == null:
		_town_backdrop = Hd2dTownBackdrop.new()
		_town_backdrop.name = "Hd2dTownBackdrop"
		add_child(_town_backdrop)
	var buildings: Array[SanctuaryBuildingResource] = []
	for id: StringName in _town_views:
		buildings.append(_town_views[id].building)
	if _town_backdrop.setup(size, buildings):
		background.texture = _town_backdrop.get_texture()
		background.stretch_mode = TextureRect.STRETCH_SCALE


## Re-scores every building. With `animate`, a building whose tier rose plays
## its pop (first build and loads never pop -- spec §6).
func refresh_town(animate: bool = true) -> void:
	var scores: Dictionary[StringName, float] = SanctuaryProgress.scores(get_tree())
	for id: StringName in _town_views:
		var rose: bool = _town_views[id].set_progress(scores.get(id, 0.0))
		if rose and animate:
			_town_views[id].play_tier_up()


## Events carry varied payloads; any of them just means "re-score".
func _on_town_progress_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	refresh_town()


func _on_town_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh_town()


func _on_town_building_pressed(building_id: StringName) -> void:
	var view: TownBuildingView = _town_views.get(building_id)
	if view != null and view.building.target_state != &"":
		building_selected.emit(view.building.target_state)


## Bottom hint line on a translucent chrome strip: the Overview background's
## rocky bottom edge made bare parchment text hard to read. Stops short of the
## Launch Mission button (SanctuaryUI.LAUNCH_BUTTON_SIZE, 24 px from the right).
func _build_town_info_strip() -> PanelContainer:
	var strip := PanelContainer.new()
	strip.name = "TownInfoStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.anchor_right = 1.0
	strip.offset_left = 12.0
	strip.offset_top = -40.0
	strip.offset_right = -(SanctuaryUI.LAUNCH_BUTTON_SIZE.x + 24.0 + 16.0)
	strip.offset_bottom = -8.0
	var box := ShellChromeStyle.chrome_panel_stylebox()
	box.bg_color.a = 0.82
	box.border_width_top = 1
	box.border_color = Color(ShellChromeStyle.UI_PARCHMENT, 0.35)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	strip.add_theme_stylebox_override("panel", box)
	_town_info_label = Label.new()
	_town_info_label.name = "TownInfo"
	_town_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_town_info_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_town_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_town_info_label.add_theme_font_size_override("font_size", 14)
	_town_info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strip.add_child(_town_info_label)
	return strip


func _show_town_info(building_id: StringName) -> void:
	var view: TownBuildingView = _town_views.get(building_id)
	if view == null or _town_info_label == null:
		return
	_town_info_label.text = tr("SANCTUARY_BUILDING_INFO") % [tr(view.building.name_key), view.tier,
		roundi(view.score * 100.0), tr(view.building.hint_key)]


func _show_town_prompt() -> void:
	if _town_info_label != null:
		_town_info_label.text = tr("SANCTUARY_BUILDING_PROMPT")


## The town building views by id (for tests and the shell).
func get_town_building(building_id: StringName) -> TownBuildingView:
	return _town_views.get(building_id)


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

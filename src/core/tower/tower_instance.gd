class_name TowerInstance
extends Node2D

## Visual presentation for a placed tower. Current placement payloads provide
## Foundation/Weapon component IDs, which assemble processed Base/Shaft/Top
## art; the two-argument configure() path retains the former archetype texture
## behavior for older callers and isolated tests.

## Archetype -> art lookup. All 4 archetypes now have placeholder art.
## "elemental" here is the fallback used when no per-element texture exists
## below (see ELEMENT_TEXTURES) — kept so an unrecognized/future element
## never renders with no texture at all.
const ARCHETYPE_TEXTURES: Dictionary[String, Texture2D] = {
	"ranged": preload("res://assets/art/towers/tower_ranged_base.png"),
	"physical": preload("res://assets/art/towers/tower_physical_base.png"),
	"elemental": preload("res://assets/art/towers/tower_elem_ice.png"),
	"support": preload("res://assets/art/towers/tower_support_base.png"),
}

## Real bug found and fixed 2026-08-17 (Art & Animation Pipeline Upgrade
## audit): configure() previously only ever received `archetype`, never
## `element`, so every "elemental" archetype tower rendered as ice art
## regardless of its real WeaponComponent.element — including the shipped
## Firebolt Turret (element="fire"), which has silently displayed as an ice
## tower since it was added. 8 elemental sprites already exist in
## assets/art/towers/ (fire/ice/lightning/poison/earth/water/wind/shadow/
## holy); ELEMENT_TEXTURES wires them all up. _resolve_tower_color() in
## mission_scene.gd already resolved per-element COLOR correctly (and
## IDLE_AMBIENT_CONFIGS already resolved fire/frost particles correctly) —
## only the sprite texture itself was never element-aware.
const ELEMENT_TEXTURES: Dictionary[String, Texture2D] = {
	"fire": preload("res://assets/art/towers/tower_elem_fire.png"),
	"frost": preload("res://assets/art/towers/tower_elem_ice.png"),
	"lightning": preload("res://assets/art/towers/tower_elem_lightning.png"),
	"poison": preload("res://assets/art/towers/tower_elem_poison.png"),
	"earth": preload("res://assets/art/towers/tower_elem_earth.png"),
	"water": preload("res://assets/art/towers/tower_elem_water.png"),
	"wind": preload("res://assets/art/towers/tower_elem_wind.png"),
	"shadow": preload("res://assets/art/towers/tower_elem_shadow.png"),
	"holy": preload("res://assets/art/towers/tower_elem_holy.png"),
}

## Processed Base/Shaft/Top art keyed by the silhouette families defined in
## design/art/asset-generation-prompts.md. All three pieces in a family share
## a camera and attachment language, so they are always resolved as a set.
const SHAPE_BASE_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"round": preload("res://assets/art/towers/tower_base_matched_round.png"),
	&"square": preload("res://assets/art/towers/tower_base_matched_square.png"),
	&"stump": preload("res://assets/art/towers/tower_base_matched_stump.png"),
	&"stonemound": preload("res://assets/art/towers/tower_base_matched_stonemound.png"),
	&"octagon": preload("res://assets/art/towers/tower_base_matched_octagon.png"),
	&"tiered": preload("res://assets/art/towers/tower_base_matched_tiered.png"),
	&"scalloped": preload("res://assets/art/towers/tower_base_matched_scalloped.png"),
	&"triangle": preload("res://assets/art/towers/tower_base_matched_triangle.png"),
	&"hexplank": preload("res://assets/art/towers/tower_base_matched_hexplank.png"),
}
const SHAPE_SHAFT_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"round": preload("res://assets/art/towers/tower_shaft_round.png"),
	&"square": preload("res://assets/art/towers/tower_shaft_square.png"),
	&"stump": preload("res://assets/art/towers/tower_shaft_stump.png"),
	&"stonemound": preload("res://assets/art/towers/tower_shaft_stonemound.png"),
	&"octagon": preload("res://assets/art/towers/tower_shaft_octagon.png"),
	&"tiered": preload("res://assets/art/towers/tower_shaft_tiered.png"),
	&"scalloped": preload("res://assets/art/towers/tower_shaft_scalloped.png"),
	&"triangle": preload("res://assets/art/towers/tower_shaft_triangle.png"),
	&"hexplank": preload("res://assets/art/towers/tower_shaft_hexplank.png"),
}
const SHAPE_TOP_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"round": preload("res://assets/art/towers/tower_top_round.png"),
	&"square": preload("res://assets/art/towers/tower_top_square.png"),
	&"stump": preload("res://assets/art/towers/tower_top_stump.png"),
	&"stonemound": preload("res://assets/art/towers/tower_top_stonemound.png"),
	&"octagon": preload("res://assets/art/towers/tower_top_octagon.png"),
	&"tiered": preload("res://assets/art/towers/tower_top_tiered.png"),
	&"scalloped": preload("res://assets/art/towers/tower_top_scalloped.png"),
	&"triangle": preload("res://assets/art/towers/tower_top_triangle.png"),
	&"hexplank": preload("res://assets/art/towers/tower_top_hexplank.png"),
}

## Weapon-component identity overrides only the crown. This preserves the
## foundation-selected body while making firing hardware readable at a glance.
const WEAPON_TOP_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"siege": preload("res://assets/art/towers/tower_top_weapon_siege_cannon.png"),
	&"railgun": preload("res://assets/art/towers/tower_top_weapon_railgun_laser.png"),
	&"arcane": preload("res://assets/art/towers/tower_top_weapon_arcane_lance_emitter.png"),
	&"storm": preload("res://assets/art/towers/tower_top_weapon_storm_emitter.png"),
	&"firestorm": preload("res://assets/art/towers/tower_top_weapon_firestorm_emitter.png"),
	&"frost": preload("res://assets/art/towers/tower_top_weapon_frost_emitter.png"),
}

## The shared modular batch is the safe fallback for unknown/future component
## IDs. It avoids guessing a named silhouette while still rendering all three
## authored layers and retaining archetype/element identity in the crown.
const MODULAR_BASE_TEXTURE: Texture2D = preload("res://assets/art/towers/tower_modular_base_shared.png")
const MODULAR_SHAFT_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"solid": preload("res://assets/art/towers/tower_modular_shaft_solid.png"),
	&"support": preload("res://assets/art/towers/tower_modular_shaft_open_support.png"),
}
const MODULAR_TOP_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"physical": preload("res://assets/art/towers/tower_modular_top_physical.png"),
	&"ranged": preload("res://assets/art/towers/tower_modular_top_ranged.png"),
	&"support": preload("res://assets/art/towers/tower_modular_top_support.png"),
	&"fire": preload("res://assets/art/towers/tower_modular_top_fire.png"),
	&"frost": preload("res://assets/art/towers/tower_modular_top_frost.png"),
	&"poison": preload("res://assets/art/towers/tower_modular_top_poison.png"),
}

## Any Top fits any Shaft and any Shaft fits any Base (UX overhaul
## 2026-10-09, player-requested "all the tops should attach seamlessly to all
## the shafts, and all the shafts to all the bases"). stack_layers() lays the
## three pieces out from their painted (non-transparent) rects, so neither
## the PNGs' transparent margins nor the 256 px import cap can open a seam:
##  1. Width: every piece is scaled so its painted width is a fixed fraction
##     of the base's (LAYER_WIDTH_FRACTIONS), so mixed families match in size.
##  2. Seat: each Base/Shaft carries a seat line, the front rim of its
##     painted top face, as a fraction of its painted width measured down from
##     its painted top (LAYER_SEAT_FRACTIONS). The piece above stands with its
##     painted bottom on that line, covering the face.
## Seat values were read off every base/shaft with the line drawn on it, then
## checked on composites of every shaft on two bases and every top on two
## shafts. Re-measure when layer art is replaced; unknown art falls back to
## DEFAULT_SEAT_FRACTION.
const LAYER_WIDTH_FRACTIONS: PackedFloat32Array = [1.0, 0.85, 0.95]  # base, shaft, top
const DEFAULT_SEAT_FRACTION: float = 0.27
const LAYER_SEAT_FRACTIONS: Dictionary[String, float] = {
	"tower_base_matched_hexplank": 0.21,
	"tower_base_matched_octagon": 0.26,
	"tower_base_matched_round": 0.27,
	"tower_base_matched_scalloped": 0.27,
	"tower_base_matched_square": 0.25,
	"tower_base_matched_stonemound": 0.17,
	"tower_base_matched_stump": 0.25,
	"tower_base_matched_tiered": 0.27,
	"tower_base_matched_triangle": 0.09,
	"tower_modular_base_shared": 0.26,
	"tower_modular_shaft_open_support": 0.30,
	"tower_modular_shaft_solid": 0.30,
	"tower_shaft_hexplank": 0.21,
	"tower_shaft_octagon": 0.28,
	"tower_shaft_round": 0.28,
	"tower_shaft_scalloped": 0.28,
	"tower_shaft_square": 0.25,
	"tower_shaft_stonemound": 0.19,
	"tower_shaft_stump": 0.28,
	"tower_shaft_tiered": 0.27,
	"tower_shaft_triangle": 0.14,
}
## Adaptor caps (2026-10-09, player decision: one cap per shape family, shown
## only where two different families meet). A cap sits on the lower piece's
## seat line, matches that piece's top-face outline and width, and ends in a
## standard round socket every upper piece fits on. Art is a Codex batch
## (design/art/tower-adaptor-caps-prompts.md); a family with no cap PNG yet
## simply joins directly, so caps switch on per shape as the art lands. Seat
## lines for caps go in LAYER_SEAT_FRACTIONS like any other lower piece.
const CAP_TEXTURE_PATH_FORMAT: String = "res://assets/art/towers/tower_cap_%s.png"
## Basename prefixes that carry a shape family name after them.
const FAMILY_PREFIXES: PackedStringArray = ["tower_base_matched_", "tower_base_", "tower_shaft_", "tower_top_", "tower_cap_"]

## texture resource_path -> painted rect in texture pixels; see painted_rect().
static var _painted_rect_cache: Dictionary[String, Rect2] = {}

## Persistent color-identity ring for an "elemental" archetype tower whose
## WeaponComponent.element has no bespoke art in ELEMENT_TEXTURES yet (see
## that dict's own fallback comment above configure()) -- lets a brand-new
## element ship with a real color identity immediately, reusing the shared
## generic "elemental" body texture instead of requiring new painted art
## before the element can visually read as distinct from every other
## not-yet-authored element. Reuses ProjectileVisual.ELEMENT_COLORS (the
## same source of truth mission_scene.gd's _resolve_tower_color(),
## tower_destroy_vfx.gd, and aoe_ring_visual.gd already read from) rather
## than a second color table -- this project's established single-source-
## of-truth convention for element colors. Falls back to
## ProjectileVisual.ARCHETYPE_COLORS["elemental"] (ice blue) for an element
## with no entry in either dict, the same fallback _resolve_tower_color()
## already uses. Pure Node2D._draw() output, no new art asset -- matches
## design/art/animation-pipeline.md §2's "Towers: procedural only" rule,
## already the basis for this file's existing weapon-glow dot and perk
## badge below.
const ELEMENT_TINT_RING_RADIUS: float = TARGET_DISPLAY_HEIGHT * 0.55  ## sits outside WEAPON_GLOW_ORBIT_RADIUS, around the tower's base
const ELEMENT_TINT_RING_ALPHA: float = 0.55  ## quiet identity signal, not a spotlight -- matches IDLE_AMBIENT_CONFIGS's "low-intensity" framing
const ELEMENT_TINT_RING_WIDTH: float = 2.5  ## world units

## Target on-screen height (world units, matches MonsterManager.CELL_SIZE=64
## so a tower reads as roughly one grid cell). Source art is unscaled,
## native ChatGPT-generation resolution and varies wildly by archetype
## (267x471 to 1185x1173, per a project-wide art-asset sweep 2026-08-03) --
## found and fixed proactively here, mirroring the identical unscaled-sprite
## bug already found live (via Godot MCP) and fixed in MonsterInstance and
## diorama.gd's structure sprites. TowerInstance has no live placement
## call-site yet to have caught this by screenshot the same way -- fixed
## ahead of that wiring so it isn't rediscovered the hard way later.
const TARGET_DISPLAY_HEIGHT: float = 64.0

## ADR-0043: seconds a 3D crown keeps tracking after a shot's glow ends
## before it goes back to its sentry sweep.
const AIM_HOLD_EXTRA: float = 0.5

## design/gdd/tower.md IDLE Visual/Audio Requirements: "Elemental towers may
## have a low-intensity particle ambient (embers for fire, frost haze for
## frost) provided it is visually distinct from TARGETING/ATTACKING
## particles." Only these 2 elements are named by the GDD — poison/lightning/
## arcane have no idle-ambient signature specified, so they get none (not an
## oversight; nothing to add without inventing an unspecified signature).
## Deliberately much lower amount/velocity than ProjectileVisual's own
## per-shot trail configs — this must read as "quietly present," not compete
## with TARGETING/ATTACKING visuals per the GDD's own distinctness mandate.
const IDLE_AMBIENT_CONFIGS: Dictionary[String, Dictionary] = {
	"fire": {
		"color": Color(0.85, 0.35, 0.1), "amount": 3, "lifetime": 1.2,
		"velocity_min": 3.0, "velocity_max": 8.0,
		"gravity": Vector2(0.0, -15.0), "scale_min": 1.5, "scale_max": 2.5,
	},
	"frost": {
		"color": Color(0.65, 0.85, 1.0), "amount": 3, "lifetime": 1.4,
		"velocity_min": 2.0, "velocity_max": 5.0,
		"gravity": Vector2.ZERO, "scale_min": 1.5, "scale_max": 2.5,
	},
}

## design/gdd/tower.md "Tower Voluntarily Removed" Visual/Audio Requirements:
## "Smooth dissolve or retract animation (~0.3–0.5s)."
const REMOVE_DURATION: float = 0.4  ## seconds

## design/gdd/tower.md "Tower TARGETING State": "Orientation snap toward
## acquired target... A low-intensity glow on the weapon slot signals
## 'locked and counting down.'" Scope note: this project's actual TowerSystem
## logic (Rule 17) only resolves a target at attack-timer expiry, immediately
## transitioning to ATTACKING in the same instant — there is no separate,
## sustained "target acquired, timer still counting down" backend state to
## visualize continuously. This is approximated the only way the real game
## logic allows: both the orientation snap and the glow start fire from the
## same tower_attacked event ATTACKING itself fires from (see
## play_attack_punch()), with the glow's fade duration set to the tower's own
## next attack-cycle length (1.0 / attack_speed) so it reads as "counting
## down to the next shot" even though it technically starts at the previous
## shot's moment rather than proactively at true acquisition time.
##
## The "orientation snap" itself is the weapon-slot glow dot's POSITION
## snapping toward the target (see _weapon_glow_offset below) — never the
## tower's own rotation/_sprite. design/gdd/tower.md's Data Model table is
## explicit: tower_facing_dir is "Never updated during TARGETING or ATTACKING
## states." Rotating the whole sprite here (a real, shipped bug — the tower
## visibly spun to face its target like a turret) violated that rule; the
## body must stay static and only this small weapon-slot indicator moves.
const ORIENTATION_SNAP_DURATION: float = 0.1  ## seconds — fast enough to read as a "snap," not a smooth pan
const WEAPON_GLOW_PEAK_ALPHA: float = 0.5
const WEAPON_GLOW_RADIUS: float = 6.0  ## world units
const WEAPON_GLOW_ORBIT_RADIUS: float = TARGET_DISPLAY_HEIGHT * 0.3  ## distance of the glow dot from tower center

## design/gdd/tower.md "Tower ATTACKING State": "Attack animation on fire
## (recoil, beam flash, energy discharge, or AoE effect by weapon type)...
## Must be visually distinct from TARGETING." Kept on separate visual
## channels from the TARGETING glow above (sprite modulate/scale here vs. a
## dedicated glow dot there) specifically so the two can never visually
## merge into one indistinguishable effect. A single unified "punch" (flash +
## scale kick) stands in for recoil/beam-flash/energy-discharge alike across
## Physical/Ranged/Elemental — Support never calls this (Rule 5a: Support
## emits tower_aura_pulse, not tower_attacked; its aura-pulse ring already
## fully covers Support's own ATTACKING-equivalent visual).
const PUNCH_FLASH_IN_DURATION: float = 0.06
const PUNCH_FLASH_OUT_DURATION: float = 0.12
const PUNCH_SCALE_PEAK: float = 1.12

## Art & Animation Pipeline Upgrade, vertical slice (design/art/animation-
## pipeline.md §2 "Towers: procedural only"). The directive's Tower Animation
## section explicitly asks for "anticipation" ahead of "firing motion" — this
## codebase's real constraint (see this file's own TARGETING doc comment
## above) is that TARGETING and ATTACKING both fire from the same
## tower_attacked event, so a true pre-attack anticipation beat can't be
## triggered any earlier than the punch itself. Folded into play_attack_punch()
## as its first tween stage instead of a separately-timed call — a quick
## pull-back before the existing flash+scale-out reads as "wind up, then
## release" within the same visual beat.
const CHARGE_UP_DURATION: float = 0.05
const CHARGE_UP_SCALE_TROUGH: float = 0.94

## design/gdd/tower.md "Pre-Placement Perk Indicator": "Persistent icon badge
## on the tower sprite (top-right corner of cell, 12–16px on-screen)...
## Binary — present or absent; not a progress meter... the specific perk is
## communicated via HUD tooltip, not the badge." A plain colored badge is
## therefore sufficient — it never needs to encode WHICH perk, only that one
## exists. Set via set_perk_badge(), driven by mission_scene.gd's
## pre_placement_perk_activated subscription. Never cleared mid-lifetime —
## the GDD's "removed if voluntarily removed and re-placed" requirement is
## satisfied structurally: a removed tower's TowerInstance is freed entirely
## (play_remove_animation()), and a fresh instance always starts with no badge.
const RANK_CHEVRON_COLOR: Color = Color(1.0, 0.82, 0.35)
const RANK_CHEVRON_OUTLINE: Color = Color(0.15, 0.1, 0.05, 0.9)
const RANK_CHEVRON_HALF_WIDTH: float = 7.0
const RANK_CHEVRON_WIDTH: float = 2.5
const RANK_CHEVRON_SPACING: float = 5.0
const RANK_CHEVRON_BASE_Y: float = TARGET_DISPLAY_HEIGHT * 0.5
const PERK_BADGE_COLOR: Color = Color(0.784, 0.502, 0.102)  ## Sanctum Amber — this project's established "special status" color
const PERK_BADGE_RADIUS: float = 7.0  ## world units — ~14px on-screen, within the GDD's 12-16px spec

## Art & Animation Pipeline Upgrade, vertical slice: closes a real gap found
## during the audit — mission_scene.gd never subscribed to tower_damaged at
## all (only mission_hud.gd's HP-bar text reacts to it), so a tower being hit
## by a monster had zero sprite-level feedback. play_hit_flash() (below)
## fills that loop using src/shaders/hit_flash.gdshader — a shader parameter
## flash rather than a second modulate-tween, so it can run independently of
## (and simultaneously with) play_attack_punch()'s own modulate-driven flash
## without the two fighting over the same property.
const HIT_FLASH_SHADER: Shader = preload("res://src/shaders/hit_flash.gdshader")

const HIT_FLASH_DURATION: float = 0.18  ## seconds, matches this file's other flash timings' rough scale

## WeaponComponent.element — cached here at placement time (see
## mission_scene.gd's _on_tower_placed) so tower_destroyed's VFX can read it
## even though TowerSystem.placed_towers[tower_id] is already erased by the
## time tower_destroyed fires (TowerSystem erases before emitting). Presentation
## metadata living on the presentation node, not re-derived from a system
## lookup that may no longer be valid.
var element: String = ""


var _base_sprite_scale: Vector2 = Vector2.ONE
var _weapon_glow_alpha: float = 0.0
var _weapon_glow_color: Color = Color.WHITE
## Position of the weapon-slot glow dot, relative to tower center — this is
## what "snaps" toward the target, never _sprite.rotation. Starts facing "up"
## to match this file's previous fixed-position default.
var _weapon_glow_offset: Vector2 = Vector2(0.0, -WEAPON_GLOW_ORBIT_RADIUS)
var _glow_offset_tween: Tween = null
var _glow_tween: Tween = null
var _punch_tween: Tween = null
var _has_perk_badge: bool = false
## Tower veterancy rank (0-3), drawn as gold chevrons under the tower.
var _rank: int = 0
## Child canvas item the chevrons draw on: a Node2D's own _draw() renders
## under its children, so drawing them in _draw() hid them behind the sprite.
var _rank_badge: Node2D = null
## Set by configure() -- true only when the tower's archetype is
## "elemental" and its element has no entry in ELEMENT_TEXTURES (the
## generic-fallback-texture case). See ELEMENT_TINT_RING_RADIUS's own doc
## comment for why this exists instead of new art.
var _element_tint_active: bool = false
var _element_tint_color: Color = Color.WHITE
## Per-instance ShaderMaterial wrapping the shared HIT_FLASH_SHADER resource
## (compiled once, cached by the rendering server via preload() — only the
## lightweight parameter-holding ShaderMaterial itself is per-instance, which
## is required since each tower's flash_amount varies independently).
var _hit_flash_material: ShaderMaterial = null
var _hit_flash_tween: Tween = null
## ADR-0043 3D tower path. _scenery is injected by the mission scene; when
## it is set and every piece of this tower has a model, _model renders the
## tower in the scenery world and the 2D layer sprites stay hidden.
var _scenery: Hd2dScenery = null
var _model: TowerModel3D = null
## The tower's gameplay spot on the flat 2D map (its square centre). On a
## hill the node itself sits higher on screen by the scenery's screen lift,
## so every 2D child (badges, rings, flashes) and projectile origin rises with
## it (spec 2026-11-07-3d-terrain §6.4). Vector2.INF = not set: the node's
## own position is the ground spot.
var ground_position: Vector2 = Vector2.INF
var _ground_shadow: GroundShadow = null
## Monster the crown is tracking between shots, and how long it may keep
## tracking without a new shot (see play_targeting_orientation()).
var _aim_target: Node2D = null
var _aim_hold: float = 0.0
## True while following _aim_target. A flag, not `_aim_target != null`: a
## freed monster reference compares equal to null, which would skip the
## clear_aim() that sends the crown back to its sweep.
var _aim_active: bool = false

@onready var _visual_root: Node2D = $VisualRoot
@onready var _layer_root: Node2D = $VisualRoot/LayerRoot
@onready var _base_sprite: Sprite2D = $VisualRoot/LayerRoot/BaseSprite
@onready var _shaft_sprite: Sprite2D = $VisualRoot/LayerRoot/ShaftSprite
@onready var _top_sprite: Sprite2D = $VisualRoot/LayerRoot/TopSprite
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _idle_particles: CPUParticles2D = $IdleParticles2D


func _ready() -> void:
	# ADR-0042 unit pass: every tower is normalised to TARGET_DISPLAY_HEIGHT,
	# so one fixed contact shadow at the base fits all of them.
	_ground_shadow = GroundShadow.attach(self, TARGET_DISPLAY_HEIGHT * 0.8, TARGET_DISPLAY_HEIGHT * 0.42)
	set_process(false)
	_assign_hit_flash_material(_sprite)
	_assign_hit_flash_material(_base_sprite)
	_assign_hit_flash_material(_shaft_sprite)
	_assign_hit_flash_material(_top_sprite)
	_hit_flash_material = _sprite.material as ShaderMaterial


## Configures a tower visual. Component IDs select a three-layer body and any
## dedicated weapon crown; omitted IDs retain the legacy archetype/element
## texture path. Every result is normalized to TARGET_DISPLAY_HEIGHT, with a
## safe authored fallback for unknown future component IDs.
## tier: the Foundation tier (1-4); the 3D model shows more detail per tier.
func configure(archetype: String, element: String = "", foundation_component_id: String = "",
		weapon_component_id: String = "", tier: int = 1) -> void:
	if foundation_component_id != "" or weapon_component_id != "":
		_configure_layered(archetype, element, foundation_component_id, weapon_component_id)
		_try_build_model(archetype, foundation_component_id, weapon_component_id, tier)
	else:
		_configure_legacy(archetype, element)


## ADR-0043: lets configure() render this tower as a 3D model in `scenery`.
## Call before configure(). Without it (or for a tower with an unmodelled
## piece) the tower renders as 2D layered sprites exactly as before.
func set_scenery(scenery: Hd2dScenery) -> void:
	_scenery = scenery
	_apply_lift()


## Places the tower at its flat-map gameplay spot `p` and lifts the node onto
## the terrain drawn there (no lift without a terrain scenery).
## Example: vis.set_ground_position(payload.world_position)
func set_ground_position(p: Vector2) -> void:
	ground_position = p
	_apply_lift()


func _apply_lift() -> void:
	if ground_position == Vector2.INF:
		return
	var lift: float = _scenery.screen_lift(ground_position) if _scenery != null else 0.0
	position = ground_position - Vector2(0.0, lift)


## Flat-map spot the 3D model stands on.
func _ground_spot() -> Vector2:
	return ground_position if ground_position != Vector2.INF else global_position


func _model_world_position() -> Vector3:
	var g: Vector2 = _ground_spot()
	return _scenery.to_world(g, _scenery.ground_height(g))


## The 3D model, or null when this tower renders in 2D.
func get_model_3d() -> TowerModel3D:
	return _model


## The 3D pieces a tower with these components is built from: [shape,
## crown_key] for TowerModel3D.build(), or [] when a piece has no model (the
## tower then renders in 2D). UI that pictures a blueprint uses this too, so
## its picture is the model a mission places.
## Example: var keys := TowerInstance.model_keys("physical", "found_archer_t1", "wpn_bow_t1")
static func model_keys(archetype: String, foundation_component_id: String,
		weapon_component_id: String) -> Array[StringName]:
	var shape: StringName = resolve_shape_for_component(foundation_component_id, archetype)
	if shape == &"":
		return []
	var crown_key: StringName = _resolve_weapon_top_key(weapon_component_id)
	if crown_key == &"":
		crown_key = StringName("top_" + String(shape))
	if not TowerModel3D.has_models(shape, crown_key):
		return []
	return [shape, crown_key]


func _try_build_model(archetype: String, foundation_component_id: String, weapon_component_id: String, tier: int) -> void:
	_free_model()
	if _scenery == null:
		return
	var keys: Array[StringName] = model_keys(archetype, foundation_component_id, weapon_component_id)
	if keys.is_empty():
		return
	var shape: StringName = keys[0]
	var crown_key: StringName = keys[1]
	_model = TowerModel3D.new()
	_model.name = "TowerModel3D_%d" % get_instance_id()
	_scenery.get_dynamic_root().add_child(_model)
	_model.build(shape, crown_key, tier, _scenery.get_z_stretch(), get_instance_id())
	_model.position = _model_world_position()
	_model.set_painted_style(_scenery.profile != null and _scenery.profile.art_style == "painted")
	_model.set_rank(_rank, false)
	_visual_root.visible = false
	if _ground_shadow != null:
		_ground_shadow.visible = false  # the 3D model casts a real shadow
	set_process(true)


func _free_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = null
	_visual_root.visible = true
	if _ground_shadow != null:
		_ground_shadow.visible = true
	set_process(false)


func _process(delta: float) -> void:
	if _model == null or not is_instance_valid(_model):
		return
	_model.position = _model_world_position()
	if not _aim_active:
		return
	if not is_instance_valid(_aim_target) or _aim_hold <= 0.0:
		_aim_active = false
		_aim_target = null
		_model.clear_aim()
		return
	_model.aim_at(_aim_target.global_position - global_position, _aim_hold)
	_aim_hold -= delta


func _exit_tree() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = null


## Resolves a processed silhouette family from stable component identity.
## Substring matching deliberately ignores tier suffixes, so upgraded copies
## keep their construction language. Unknown IDs return an empty StringName
## and are rendered through the shared modular fallback by configure().
static func resolve_shape_for_component(component_id: String, archetype: String) -> StringName:
	var normalized_id: String = component_id.to_lower()
	if "siege" in normalized_id:
		return &"hexplank"
	if "longshot" in normalized_id or "railgun" in normalized_id:
		return &"triangle"
	if "frost" in normalized_id:
		return &"scalloped"
	if "arcane" in normalized_id or "storm" in normalized_id:
		return &"octagon"
	if "venom" in normalized_id or "earth" in normalized_id or "crystal" in normalized_id:
		return &"stonemound"
	if "grandrally" in normalized_id or "standard" in normalized_id or "barrier" in normalized_id:
		return &"tiered"
	if "rally" in normalized_id:
		return &"stump"
	if "bulwark" in normalized_id or "warbreaker" in normalized_id:
		return &"square"
	# "iron"/"reinforced" are this project's real, currently-shipped starter
	# foundations (found_iron_t1, found_reinforced_t2 — both "physical"
	# archetype, a tier1->tier2 HP-tank lineage). They share "square" with
	# bulwark/warbreaker rather than getting a dedicated shape: same
	# defensive/blocky identity, and the tiered upgrade keeps one consistent
	# silhouette across its tier progression (mirroring how
	# grandrally/standard/barrier already share "tiered" above). Found live
	# 2026-08-30 via Godot MCP verification: both IDs fell through to the
	# modular fallback and rendered identically to each other.
	if "iron" in normalized_id or "reinforced" in normalized_id:
		return &"square"
	if "archer" in normalized_id or "ballista" in normalized_id or "firebolt" in normalized_id or "volley" in normalized_id:
		return &"round"
	# Archetype is intentionally not used to invent a named shape. It is
	# retained in this API because callers already possess it and fallback
	# selection uses it immediately after this resolver returns empty.
	var _unused_archetype: String = archetype
	return &""


## Returns the unscaled union of the painted (non-transparent) parts of the
## layered sprites. Exposed for deterministic layout verification; gameplay
## code does not need it.
func get_layered_visual_bounds() -> Rect2:
	if _model != null and is_instance_valid(_model):
		var pitch: float = _scenery.profile.camera_pitch_deg if _scenery.profile != null else 50.0
		var h: float = _model.screen_height_px(pitch)
		var w: float = TARGET_DISPLAY_HEIGHT * 0.75
		return Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))
	var bounds := Rect2()
	for sprite: Sprite2D in [_base_sprite, _shaft_sprite, _top_sprite]:
		var painted: Rect2 = painted_rect(sprite.texture)
		var top_left: Vector2 = sprite.position - sprite.texture.get_size() * sprite.scale * 0.5
		var part := Rect2(top_left + painted.position * sprite.scale, painted.size * sprite.scale)
		bounds = part if sprite == _base_sprite else bounds.merge(part)
	return bounds


func _configure_legacy(archetype: String, element: String) -> void:
	var texture: Texture2D = null
	_element_tint_active = false
	if archetype == "elemental":
		texture = ELEMENT_TEXTURES.get(element)
		if texture == null and element != "":
			_element_tint_active = true
			_element_tint_color = ProjectileVisual.ELEMENT_COLORS.get(element, ProjectileVisual.ARCHETYPE_COLORS["elemental"])
	if texture == null:
		texture = ARCHETYPE_TEXTURES.get(archetype, null)
	if texture == null:
		push_warning("[TowerInstance] no art authored for archetype '%s'" % archetype)
		_sprite.texture = null
		_sprite.visible = true
		_layer_root.visible = false
		queue_redraw()
		return
	_visual_root.modulate = Color.WHITE
	_layer_root.visible = false
	_sprite.visible = true
	_sprite.texture = texture
	var uniform_scale: float = TARGET_DISPLAY_HEIGHT / float(texture.get_height())
	_sprite.scale = Vector2(uniform_scale, uniform_scale)
	_base_sprite_scale = _sprite.scale
	queue_redraw()


func _configure_layered(archetype: String, element: String, foundation_component_id: String,
		weapon_component_id: String) -> void:
	_element_tint_active = false
	# Keep the former single-sprite contract populated (but hidden) for tools
	# and tests that inspect the legacy Sprite2D directly. Runtime rendering is
	# exclusively the layer root whenever component identity is available.
	_sprite.texture = ELEMENT_TEXTURES.get(element) if archetype == "elemental" else null
	if _sprite.texture == null:
		_sprite.texture = ARCHETYPE_TEXTURES.get(archetype)
	var shape: StringName = resolve_shape_for_component(foundation_component_id, archetype)
	if shape != &"":
		_base_sprite.texture = SHAPE_BASE_TEXTURES[shape]
		_shaft_sprite.texture = SHAPE_SHAFT_TEXTURES[shape]
		_top_sprite.texture = _resolve_weapon_top(weapon_component_id, SHAPE_TOP_TEXTURES[shape])
	else:
		_base_sprite.texture = MODULAR_BASE_TEXTURE
		_shaft_sprite.texture = MODULAR_SHAFT_TEXTURES[&"support" if archetype == "support" else &"solid"]
		var fallback_top: Texture2D = _resolve_modular_top(archetype, element)
		_top_sprite.texture = _resolve_weapon_top(weapon_component_id, fallback_top)
		if archetype == "elemental" and not MODULAR_TOP_TEXTURES.has(StringName(element)):
			_element_tint_active = true
			_element_tint_color = ProjectileVisual.ELEMENT_COLORS.get(element, ProjectileVisual.ARCHETYPE_COLORS["elemental"])
	_sprite.visible = false
	_layer_root.visible = true
	_visual_root.modulate = Color.WHITE
	_layout_layers()
	queue_redraw()


func _resolve_weapon_top(weapon_component_id: String, fallback: Texture2D) -> Texture2D:
	var weapon_top_key: StringName = _resolve_weapon_top_key(weapon_component_id)
	return WEAPON_TOP_TEXTURES.get(weapon_top_key, fallback)


static func _resolve_weapon_top_key(weapon_component_id: String) -> StringName:
	var normalized_id: String = weapon_component_id.to_lower()
	# Longer/specific names must precede their shared element roots.
	if "firestorm" in normalized_id:
		return &"firestorm"
	if "railgun" in normalized_id:
		return &"railgun"
	if "siege" in normalized_id:
		return &"siege"
	if "arcane" in normalized_id:
		return &"arcane"
	if "storm" in normalized_id:
		return &"storm"
	if "frost" in normalized_id:
		return &"frost"
	return &""


func _resolve_modular_top(archetype: String, element: String) -> Texture2D:
	var element_key: StringName = StringName(element)
	if MODULAR_TOP_TEXTURES.has(element_key):
		return MODULAR_TOP_TEXTURES[element_key]
	return MODULAR_TOP_TEXTURES.get(StringName(archetype), MODULAR_TOP_TEXTURES[&"physical"])


func _layout_layers() -> void:
	var sprites: Array[Sprite2D] = [_base_sprite, _shaft_sprite, _top_sprite]
	var textures: Array[Texture2D] = [_base_sprite.texture, _shaft_sprite.texture, _top_sprite.texture]
	var rects: Array[Rect2] = stack_layers(textures)
	var painted: Rect2 = stacked_painted_bounds(textures, rects)
	# Painted stack centred on the origin (spans -H/2..H/2), then scaled to
	# TARGET_DISPLAY_HEIGHT -- the same footprint the single-sprite path uses.
	var shift := Vector2(0.0, -painted.get_center().y)
	for i: int in sprites.size():
		var sprite: Sprite2D = sprites[i]
		var tex_scale: float = rects[i].size.x / float(sprite.texture.get_width())
		sprite.scale = Vector2(tex_scale, tex_scale)
		sprite.position = rects[i].get_center() + shift
	var uniform_scale: float = TARGET_DISPLAY_HEIGHT / painted.size.y
	_layer_root.scale = Vector2(uniform_scale, uniform_scale)
	_base_sprite_scale = _layer_root.scale


## Lays out a Base/Shaft/Top texture triple (bottom to top) as one tower.
## Returns each texture's full draw rect in layout units: the base's painted
## width is 1.0, its painted bottom sits on y = 0, and every piece is
## centred on x = 0, so y grows downward and the stack occupies negative y.
## Shared by TowerInstance and the Inventory tower preview so both always
## show the same silhouette. See LAYER_SEAT_FRACTIONS for the rules.
## Adaptor caps (see with_adaptor_caps()) take the width of the piece below
## them and do not count toward the base/shaft/top width roles.
static func stack_layers(textures: Array[Texture2D]) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var bottom_y: float = 0.0
	var role: int = 0
	var width: float = 0.0
	for i: int in textures.size():
		var texture: Texture2D = textures[i]
		var painted: Rect2 = painted_rect(texture)
		if not is_adaptor_cap(texture) or i == 0:
			width = LAYER_WIDTH_FRACTIONS[mini(role, LAYER_WIDTH_FRACTIONS.size() - 1)]
			role += 1
		var tex_scale: float = width / painted.size.x
		var origin := Vector2(-painted.get_center().x * tex_scale, bottom_y - painted.end.y * tex_scale)
		rects.append(Rect2(origin, texture.get_size() * tex_scale))
		var painted_top: float = bottom_y - painted.size.y * tex_scale
		bottom_y = painted_top + seat_fraction(texture) * width
	return rects


## Returns `textures` (bottom to top) with an adaptor cap inserted between
## every adjacent pair whose shape families differ, when the lower piece's
## family has cap art. Pieces with no recognised family (modular fallbacks,
## dedicated weapon tops) never get a cap.
static func with_adaptor_caps(textures: Array[Texture2D]) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for i: int in textures.size():
		result.append(textures[i])
		if i == textures.size() - 1:
			break
		var lower: StringName = shape_family(textures[i])
		var upper: StringName = shape_family(textures[i + 1])
		if lower == &"" or upper == &"" or lower == upper:
			continue
		var cap_path: String = CAP_TEXTURE_PATH_FORMAT % lower
		if ResourceLoader.exists(cap_path):
			result.append(load(cap_path) as Texture2D)
	return result


## Shape family a tower layer texture belongs to ("round", "triangle", ...),
## read from its file name; &"" for modular fallbacks and weapon tops.
static func shape_family(texture: Texture2D) -> StringName:
	var basename: String = texture.resource_path.get_file().get_basename()
	for prefix: String in FAMILY_PREFIXES:
		if basename.begins_with(prefix):
			var family: StringName = StringName(basename.trim_prefix(prefix))
			return family if SHAPE_BASE_TEXTURES.has(family) else &""
	return &""


static func is_adaptor_cap(texture: Texture2D) -> bool:
	return texture.resource_path.get_file().begins_with("tower_cap_")


## Union of the painted (visible) parts of rects returned by stack_layers().
static func stacked_painted_bounds(textures: Array[Texture2D], rects: Array[Rect2]) -> Rect2:
	var bounds := Rect2()
	for i: int in textures.size():
		var tex_scale: float = rects[i].size.x / float(textures[i].get_width())
		var painted: Rect2 = painted_rect(textures[i])
		var part := Rect2(rects[i].position + painted.position * tex_scale, painted.size * tex_scale)
		bounds = part if i == 0 else bounds.merge(part)
	return bounds


## Seat line of a Base/Shaft texture: LAYER_SEAT_FRACTIONS by file basename.
static func seat_fraction(texture: Texture2D) -> float:
	return LAYER_SEAT_FRACTIONS.get(texture.resource_path.get_file().get_basename(), DEFAULT_SEAT_FRACTION)


## Non-transparent rect of `texture`, in its own (imported) pixels. Cached
## per resource path; tower art imports lossless, so get_image() is cheap
## and exact. Falls back to the full texture rect if no image is readable.
static func painted_rect(texture: Texture2D) -> Rect2:
	var key: String = texture.resource_path
	if key != "" and _painted_rect_cache.has(key):
		return _painted_rect_cache[key]
	var rect := Rect2(Vector2.ZERO, texture.get_size())
	var image: Image = texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		var used: Rect2i = image.get_used_rect()
		if used.has_area():
			rect = Rect2(used)
	if key != "":
		_painted_rect_cache[key] = rect
	return rect


func _assign_hit_flash_material(sprite: Sprite2D) -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = HIT_FLASH_SHADER
	sprite.material = material


## element: WeaponComponent.element. Starts a continuous low-intensity idle
## ambient if a signature is defined for it (fire/frost only — see
## IDLE_AMBIENT_CONFIGS). Call once, after configure(); a no-op for every
## other element (silently leaves _idle_particles at its default emitting=false).
func set_idle_ambient(element: String) -> void:
	if not IDLE_AMBIENT_CONFIGS.has(element):
		return
	var config: Dictionary = IDLE_AMBIENT_CONFIGS[element]
	var color: Color = config["color"] as Color
	_idle_particles.amount = config["amount"] as int
	_idle_particles.lifetime = config["lifetime"] as float
	_idle_particles.one_shot = false
	_idle_particles.local_coords = false
	_idle_particles.direction = Vector2.RIGHT
	_idle_particles.spread = 180.0
	_idle_particles.initial_velocity_min = config["velocity_min"] as float
	_idle_particles.initial_velocity_max = config["velocity_max"] as float
	_idle_particles.gravity = config["gravity"] as Vector2
	_idle_particles.scale_amount_min = config["scale_min"] as float
	_idle_particles.scale_amount_max = config["scale_max"] as float
	_idle_particles.color = color

	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.6))  ## capped below full alpha — "low-intensity," never competes with attack VFX
	ramp.set_color(1, Color(color, 0.0))
	_idle_particles.color_ramp = ramp
	PixelVfx.style_particles(_idle_particles)

	_idle_particles.emitting = true


## design/gdd/tower.md "Tower Voluntarily Removed": "Smooth dissolve or
## retract animation (~0.3–0.5s). No debris, no red flash — reads as
## 'packed up, not killed.'" Deliberately the calm counterpart to
## TowerDestroyVFX's sudden/violent flash-and-burst — this node animates and
## frees ITSELF; the caller does not queue_free() separately. The idle
## ambient particles (if any) are children of this node and are freed
## along with it automatically, no separate cleanup needed.
func play_remove_animation() -> void:
	if _model != null and is_instance_valid(_model):
		set_process(false)
		modulate.a = 0.0  # 2D overlays (badges, particles) vanish with the model
		_model.play_remove(queue_free)
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, REMOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, REMOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## design/gdd/tower.md "Tower TARGETING State" — see this file's own
## TARGETING consts above for the scope note on why this fires from the same
## moment as play_attack_punch() rather than a separate acquisition instant.
## target_world_position: the fired-upon monster's position at attack time.
## glow_color: archetype/element color (caller resolves — matches
## ProjectileVisual's own ARCHETYPE_COLORS/ELEMENT_COLORS for consistency
## with every other tower VFX this session added).
## glow_duration: seconds, caller passes 1.0 / attack_speed (Rule 17's own
## timer formula) so the glow fades out exactly as the next shot is due.
## target (optional): the monster node, so a 3D crown keeps following it
## between shots until glow_duration + AIM_HOLD_EXTRA passes or it is freed.
func play_targeting_orientation(target_world_position: Vector2, glow_color: Color, glow_duration: float,
		target: Node2D = null) -> void:
	var to_target: Vector2 = target_world_position - global_position
	if _model != null and is_instance_valid(_model):
		_aim_target = target
		_aim_active = target != null
		_aim_hold = glow_duration + AIM_HOLD_EXTRA
		_model.aim_at(to_target, _aim_hold)
	if to_target.length_squared() > 0.0:
		if _glow_offset_tween != null and _glow_offset_tween.is_valid():
			_glow_offset_tween.kill()
		var target_offset: Vector2 = to_target.normalized() * WEAPON_GLOW_ORBIT_RADIUS
		_glow_offset_tween = create_tween()
		_glow_offset_tween.tween_method(_set_weapon_glow_offset, _weapon_glow_offset, target_offset, ORIENTATION_SNAP_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_weapon_glow_color = glow_color
	_set_weapon_glow_alpha(WEAPON_GLOW_PEAK_ALPHA)
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_weapon_glow_alpha, WEAPON_GLOW_PEAK_ALPHA, 0.0, glow_duration)


func _set_weapon_glow_alpha(alpha: float) -> void:
	_weapon_glow_alpha = alpha
	queue_redraw()


func _set_weapon_glow_offset(offset: Vector2) -> void:
	_weapon_glow_offset = offset
	queue_redraw()


## design/gdd/tower.md "Tower ATTACKING State" — see this file's own
## ATTACKING consts above for why this and play_targeting_orientation() are
## kept on separate visual channels (sprite modulate/scale here, a dedicated
## glow dot there). color: archetype/element color, same resolution as
## play_targeting_orientation()'s glow_color — caller passes the same value
## to both since GDD Rule 17 means TARGETING and ATTACKING happen in the same
## instant in this codebase's actual implementation.
func play_attack_punch(color: Color) -> void:
	if _model != null and is_instance_valid(_model):
		_model.play_punch()
		return
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	var active_visual: Node2D = _layer_root if _layer_root.visible else _sprite
	active_visual.modulate = Color.WHITE
	active_visual.scale = _base_sprite_scale
	_punch_tween = create_tween()
	# Charge-up (anticipation): a quick pull-back before the flash+scale-out
	# below — see CHARGE_UP_DURATION's own doc comment for why this is folded
	# into the same tween chain rather than a separately-timed call.
	_punch_tween.tween_property(active_visual, "scale", _base_sprite_scale * CHARGE_UP_SCALE_TROUGH, CHARGE_UP_DURATION)
	_punch_tween.chain().set_parallel(true)
	_punch_tween.tween_property(active_visual, "modulate", color, PUNCH_FLASH_IN_DURATION)
	_punch_tween.tween_property(active_visual, "scale", _base_sprite_scale * PUNCH_SCALE_PEAK, PUNCH_FLASH_IN_DURATION)
	_punch_tween.chain().set_parallel(true)
	_punch_tween.tween_property(active_visual, "modulate", Color.WHITE, PUNCH_FLASH_OUT_DURATION)
	_punch_tween.tween_property(active_visual, "scale", _base_sprite_scale, PUNCH_FLASH_OUT_DURATION)


## Art & Animation Pipeline Upgrade, vertical slice — see HIT_FLASH_SHADER's
## own doc comment for the real feedback gap this closes (towers took damage
## with zero sprite reaction). Driven independently of play_attack_punch()'s
## modulate/scale channel via a shader uniform instead, so a tower being hit
## mid-punch (e.g. by a different monster while it's also firing) shows both
## effects at once rather than one overwriting the other.
func play_hit_flash() -> void:
	if _model != null and is_instance_valid(_model):
		_model.play_hit_flash()
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_set_hit_flash_amount(1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_method(_set_hit_flash_amount, 1.0, 0.0, HIT_FLASH_DURATION)


func _set_hit_flash_amount(amount: float) -> void:
	var sprites: Array[Sprite2D] = [_sprite, _base_sprite, _shaft_sprite, _top_sprite]
	for sprite: Sprite2D in sprites:
		var material: ShaderMaterial = sprite.material as ShaderMaterial
		material.set_shader_parameter("flash_amount", amount)


## design/gdd/tower.md "Pre-Placement Perk Indicator" — see PERK_BADGE_COLOR's
## own doc comment. active: true on pre_placement_perk_activated; this method
## is never called with false in the current implementation (see that
## comment for why forfeiture doesn't need an explicit "turn off" path) but
## accepts the parameter for correctness/testability rather than a bare
## "activate" method that could only ever do one thing.
func set_perk_badge(active: bool) -> void:
	_has_perk_badge = active
	_ensure_badge_overlay().queue_redraw()


## Tower veterancy (design/quick-specs/tower-veterancy-2026-11-04.md): shows
## `rank` chevrons (0 hides them). A rank-up also plays the attack punch in
## the chevron colour so the moment reads on a busy field.
func set_rank(rank: int) -> void:
	var ranked_up: bool = rank > _rank
	_rank = clampi(rank, 0, 3)
	_ensure_badge_overlay().queue_redraw()
	if _model != null and is_instance_valid(_model):
		_model.set_rank(_rank, ranked_up)
	if ranked_up:
		play_attack_punch(RANK_CHEVRON_COLOR)


func get_rank() -> int:
	return _rank


## Lazily creates the child canvas item that badges draw on (drawn above the
## tower sprite; see _rank_badge's doc comment).
func _ensure_badge_overlay() -> Node2D:
	if _rank_badge == null:
		_rank_badge = Node2D.new()
		_rank_badge.name = "BadgeOverlay"
		_rank_badge.z_index = 1
		_rank_badge.draw.connect(_draw_badge_overlay)
		add_child(_rank_badge)
	return _rank_badge


## Perk badge (upper right) and veterancy chevrons (stacked over the base).
## Both used to draw in _draw(), under the sprite; the perk badge moved here
## 2026-11-04 when the chevrons showed that layer was hidden.
func _draw_badge_overlay() -> void:
	if _has_perk_badge:
		var badge_pos := Vector2(TARGET_DISPLAY_HEIGHT * 0.35, -TARGET_DISPLAY_HEIGHT * 0.45)
		_rank_badge.draw_circle(badge_pos, PERK_BADGE_RADIUS, PERK_BADGE_COLOR)
		_rank_badge.draw_arc(badge_pos, PERK_BADGE_RADIUS, 0.0, TAU, 24, Color(0.95, 0.95, 0.9), 1.5, true)
	for i: int in _rank:
		var y: float = RANK_CHEVRON_BASE_Y - float(i) * RANK_CHEVRON_SPACING
		var w: float = RANK_CHEVRON_HALF_WIDTH
		var points := PackedVector2Array([Vector2(-w, y - w * 0.6), Vector2(0.0, y), Vector2(w, y - w * 0.6)])
		_rank_badge.draw_polyline(points, RANK_CHEVRON_OUTLINE, RANK_CHEVRON_WIDTH + 2.0, true)
		_rank_badge.draw_polyline(points, RANK_CHEVRON_COLOR, RANK_CHEVRON_WIDTH, true)


## Draws the element-tint identity ring and the TARGETING weapon-slot glow, in
## that order -- the ring paints first, so it is the bottom-most layer. (The
## perk badge and rank chevrons draw on the BadgeOverlay child instead.) It only
## draws when _element_tint_active is set (by configure(), for an
## "elemental" archetype tower whose element has no bespoke texture yet; see
## ELEMENT_TINT_RING_RADIUS's own doc comment). The ATTACKING punch lives
## entirely on the active visual root's modulate/scale (no custom draw needed),
## keeping that channel structurally separate from all three of these.
func _draw() -> void:
	if _element_tint_active:
		var ring_color: Color = _element_tint_color
		ring_color.a = ELEMENT_TINT_RING_ALPHA
		draw_arc(Vector2.ZERO, ELEMENT_TINT_RING_RADIUS, 0.0, TAU, 32, ring_color, ELEMENT_TINT_RING_WIDTH, true)
	if _weapon_glow_alpha > 0.0:
		var glow_color: Color = _weapon_glow_color
		glow_color.a = _weapon_glow_alpha
		draw_circle(_weapon_glow_offset, WEAPON_GLOW_RADIUS, glow_color)



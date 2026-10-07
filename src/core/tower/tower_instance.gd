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

## Transparent padding differs between the generated silhouette families, so
## a universal overlap leaves some attachment planes floating. Values are a
## fraction of the smaller adjacent texture height. Every authored family has
## an explicit profile; unknown component IDs use the modular fallback.
const SHAPE_OVERLAP_PROFILES: Dictionary[StringName, Vector2] = {
	# x = Base -> Shaft, y = Shaft -> matched Top.
	&"round": Vector2(0.20, 0.22),
	&"square": Vector2(0.26, 0.20),
	&"stump": Vector2(0.18, 0.18),
	&"stonemound": Vector2(0.18, 0.18),
	&"octagon": Vector2(0.18, 0.18),
	&"tiered": Vector2(0.18, 0.18),
	&"scalloped": Vector2(0.22, 0.24),
	&"triangle": Vector2(0.22, 0.30),
	&"hexplank": Vector2(0.28, 0.26),
}
const MODULAR_OVERLAP_PROFILE: Vector2 = Vector2(0.18, 0.18)

## Dedicated weapon crowns have their own transparent mount padding. These
## values override only the profile's y component, preserving the foundation
## family's tuned Base -> Shaft join.
const WEAPON_TOP_OVERLAP_PROFILES: Dictionary[StringName, float] = {
	&"siege": 0.26,
	&"railgun": 0.34,
	&"arcane": 0.20,
	&"storm": 0.20,
	&"firestorm": 0.20,
	&"frost": 0.24,
}

## Largest pixel dimension of each layer PNG on disk. The tower import preset
## caps textures at 256 px (process/size_limit, 9d592d3), which shrinks every
## layer by a DIFFERENT factor (a 1433 px shaft by 0.18, a 954 px top by 0.27),
## so laying out raw imported sizes pulled the pieces apart in missions.
## _layout_layers() rescales each sprite back to this shared source pixel space.
## Regenerate when layer art is replaced; missing entries fall back to 1:1.
const LAYER_SOURCE_MAX_DIMENSIONS: Dictionary[String, int] = {
	"tower_base_matched_hexplank": 1222,
	"tower_base_matched_octagon": 1048,
	"tower_base_matched_round": 1055,
	"tower_base_matched_scalloped": 1107,
	"tower_base_matched_square": 1094,
	"tower_base_matched_stonemound": 1176,
	"tower_base_matched_stump": 1180,
	"tower_base_matched_tiered": 1175,
	"tower_base_matched_triangle": 1227,
	"tower_modular_base_shared": 1010,
	"tower_modular_shaft_open_support": 1132,
	"tower_modular_shaft_solid": 936,
	"tower_modular_top_fire": 985,
	"tower_modular_top_frost": 1094,
	"tower_modular_top_physical": 998,
	"tower_modular_top_poison": 970,
	"tower_modular_top_ranged": 1155,
	"tower_modular_top_support": 1090,
	"tower_shaft_hexplank": 1433,
	"tower_shaft_octagon": 1029,
	"tower_shaft_round": 1040,
	"tower_shaft_scalloped": 1157,
	"tower_shaft_square": 1116,
	"tower_shaft_stonemound": 1140,
	"tower_shaft_stump": 1083,
	"tower_shaft_tiered": 1043,
	"tower_shaft_triangle": 959,
	"tower_top_hexplank": 1063,
	"tower_top_octagon": 1119,
	"tower_top_round": 1090,
	"tower_top_scalloped": 1131,
	"tower_top_square": 1133,
	"tower_top_stonemound": 953,
	"tower_top_stump": 1167,
	"tower_top_tiered": 997,
	"tower_top_triangle": 954,
	"tower_top_weapon_arcane_lance_emitter": 1133,
	"tower_top_weapon_firestorm_emitter": 1170,
	"tower_top_weapon_frost_emitter": 1042,
	"tower_top_weapon_railgun_laser": 949,
	"tower_top_weapon_siege_cannon": 1170,
	"tower_top_weapon_storm_emitter": 988,
}

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

## Epic 15 Phase 3 (VFX/shaders -> spatial): spatial port of HIT_FLASH_SHADER
## for the 3D visual companion mesh, mirroring creature_swarm_body.gdshader's
## identical hit-flash channel (ADR-0038) for the monster swarm. See
## _build_hit_flash_material_3d()'s own doc comment for why this is wired
## defensively (unverified mesh structure — no live testing this session).
const HIT_FLASH_SHADER_SPATIAL: Shader = preload("res://src/shaders/hit_flash_spatial.gdshader")
const HIT_FLASH_DURATION: float = 0.18  ## seconds, matches this file's other flash timings' rough scale

## WeaponComponent.element — cached here at placement time (see
## mission_scene.gd's _on_tower_placed) so tower_destroyed's VFX can read it
## even though TowerSystem.placed_towers[tower_id] is already erased by the
## time tower_destroyed fires (TowerSystem erases before emitting). Presentation
## metadata living on the presentation node, not re-derived from a system
## lookup that may no longer be valid.
var element: String = ""

## Epic 15 Story 003 (ADR-0037, Visual Presentation 3D Companion Layer): the
## entity_or_component_id every TowerInstance resolves its 3D visual through,
## via GGameDataRegistry.get_visual_mesh_mapping(). A single shared id for
## every archetype/element combination — this story proves the companion
## pipeline for "at least one tower type" (ADR-0037's Migration Plan scope),
## reusing Story 001's existing assets/data/visual_meshes/tower_round.tres
## mapping rather than authoring a per-archetype mesh set (a future
## content-authoring pass, not this story's architecture change — mirrors
## grid_visual.gd's identical TILE_MESH_ENTITY_ID judgment call).
const TOWER_MESH_ENTITY_ID: StringName = &"tower_round"

## Y-height for tower visuals per ADR-0037's layer_height table ("tower visual
## anchors = 0" — confirmed by the spike's live-queried AABB data that these
## Kenney meshes already have their origin at their own base).
const TOWER_LAYER_HEIGHT: float = 0.0

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
## Set by configure() -- true only when the tower's archetype is
## "elemental" and its element has no entry in ELEMENT_TEXTURES (the
## generic-fallback-texture case). See ELEMENT_TINT_RING_RADIUS's own doc
## comment for why this exists instead of new art.
var _element_tint_active: bool = false
var _element_tint_color: Color = Color.WHITE
## Node3D visual-companion subtree (ADR-0037's Visual Companion pattern),
## holding the tower's MeshInstance3D-bearing mesh instance. Built and synced
## once from configure() — see _build_visual_companion()'s own doc comment
## for why this project's real usage (position set once at placement,
## verified in mission_scene.gd/the_gap.gd's _on_tower_placed, and never
## touched again) makes configure() the correct "existing update method" for
## this story's one-line sync call, not a new _process()/_physics_process()
## override.
var _visual_companion: Node3D = null
## Per-instance ShaderMaterial wrapping the shared HIT_FLASH_SHADER resource
## (compiled once, cached by the rendering server via preload() — only the
## lightweight parameter-holding ShaderMaterial itself is per-instance, which
## is required since each tower's flash_amount varies independently).
var _hit_flash_material: ShaderMaterial = null
var _hit_flash_tween: Tween = null
## Null whenever the 3D companion's mesh has no readable albedo texture to
## seed HIT_FLASH_SHADER_SPATIAL with (see _build_hit_flash_material_3d()) —
## play_hit_flash() checks for null before touching this, so the 2D flash
## degrades gracefully to 2D-only rather than erroring.
var _hit_flash_material_3d: ShaderMaterial = null

@onready var _visual_root: Node2D = $VisualRoot
@onready var _layer_root: Node2D = $VisualRoot/LayerRoot
@onready var _base_sprite: Sprite2D = $VisualRoot/LayerRoot/BaseSprite
@onready var _shaft_sprite: Sprite2D = $VisualRoot/LayerRoot/ShaftSprite
@onready var _top_sprite: Sprite2D = $VisualRoot/LayerRoot/TopSprite
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _idle_particles: CPUParticles2D = $IdleParticles2D


func _ready() -> void:
	_assign_hit_flash_material(_sprite)
	_assign_hit_flash_material(_base_sprite)
	_assign_hit_flash_material(_shaft_sprite)
	_assign_hit_flash_material(_top_sprite)
	_hit_flash_material = _sprite.material as ShaderMaterial


## Configures a tower visual. Component IDs select a three-layer body and any
## dedicated weapon crown; omitted IDs retain the legacy archetype/element
## texture path. Every result is normalized to TARGET_DISPLAY_HEIGHT, with a
## safe authored fallback for unknown future component IDs.
func configure(archetype: String, element: String = "", foundation_component_id: String = "",
		weapon_component_id: String = "") -> void:
	if foundation_component_id != "" or weapon_component_id != "":
		_configure_layered(archetype, element, foundation_component_id, weapon_component_id)
	else:
		_configure_legacy(archetype, element)
	_build_visual_companion()


## Resolves a processed silhouette family from stable component identity.
## Substring matching deliberately ignores tier suffixes, so upgraded copies
## keep their construction language. Unknown IDs return an empty StringName
## and are rendered through the shared modular fallback by configure().
func resolve_shape_for_component(component_id: String, archetype: String) -> StringName:
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


## Returns the unscaled union of all active layered sprites. Exposed for
## deterministic layout verification; gameplay code does not need it.
func get_layered_visual_bounds() -> Rect2:
	var bounds: Rect2 = _sprite_rect(_base_sprite)
	bounds = bounds.merge(_sprite_rect(_shaft_sprite))
	bounds = bounds.merge(_sprite_rect(_top_sprite))
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
	# Epic 15 Story 003 (ADR-0037): the one line this story adds to
	# TowerInstance's existing update method — no new _process()/
	# _physics_process() callback. See _build_visual_companion()'s doc
	# comment for why configure() (not a new per-frame override) is correct
	# here.


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
	var overlap_profile: Vector2 = SHAPE_OVERLAP_PROFILES.get(shape, MODULAR_OVERLAP_PROFILE)
	var weapon_top_key: StringName = _resolve_weapon_top_key(weapon_component_id)
	if weapon_top_key != &"":
		overlap_profile.y = WEAPON_TOP_OVERLAP_PROFILES[weapon_top_key]
	_layout_layers(overlap_profile)
	queue_redraw()


func _resolve_weapon_top(weapon_component_id: String, fallback: Texture2D) -> Texture2D:
	var weapon_top_key: StringName = _resolve_weapon_top_key(weapon_component_id)
	return WEAPON_TOP_TEXTURES.get(weapon_top_key, fallback)


func _resolve_weapon_top_key(weapon_component_id: String) -> StringName:
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


func _layout_layers(overlap_profile: Vector2) -> void:
	for sprite: Sprite2D in [_base_sprite, _shaft_sprite, _top_sprite]:
		var factor: float = _source_scale_for(sprite.texture)
		sprite.scale = Vector2(factor, factor)
	var base_height: float = float(_base_sprite.texture.get_height()) * _base_sprite.scale.y
	var shaft_height: float = float(_shaft_sprite.texture.get_height()) * _shaft_sprite.scale.y
	var top_height: float = float(_top_sprite.texture.get_height()) * _top_sprite.scale.y
	var base_shaft_overlap: float = minf(base_height, shaft_height) * overlap_profile.x
	var shaft_top_overlap: float = minf(shaft_height, top_height) * overlap_profile.y
	var assembled_height: float = base_height + shaft_height + top_height - base_shaft_overlap - shaft_top_overlap
	var bottom_y: float = assembled_height * 0.5
	_base_sprite.position = Vector2(0.0, bottom_y - base_height * 0.5)
	_shaft_sprite.position = Vector2(0.0, bottom_y - base_height + base_shaft_overlap - shaft_height * 0.5)
	_top_sprite.position = Vector2(0.0, bottom_y - base_height + base_shaft_overlap - shaft_height + shaft_top_overlap - top_height * 0.5)
	var uniform_scale: float = TARGET_DISPLAY_HEIGHT / assembled_height
	_layer_root.scale = Vector2(uniform_scale, uniform_scale)
	_base_sprite_scale = _layer_root.scale


## Scale that maps an imported (possibly size-capped) layer texture back to
## its on-disk pixel size; see LAYER_SOURCE_MAX_DIMENSIONS.
func _source_scale_for(texture: Texture2D) -> float:
	var source_max: int = LAYER_SOURCE_MAX_DIMENSIONS.get(texture.resource_path.get_file().get_basename(), 0)
	var imported_max: float = maxf(float(texture.get_width()), float(texture.get_height()))
	if source_max <= 0 or imported_max <= 0.0:
		return 1.0
	return float(source_max) / imported_max


func _sprite_rect(sprite: Sprite2D) -> Rect2:
	if sprite.texture == null:
		return Rect2(sprite.position, Vector2.ZERO)
	var size: Vector2 = sprite.texture.get_size() * sprite.scale
	return Rect2(sprite.position - size * 0.5, size)


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

	_idle_particles.emitting = true


## design/gdd/tower.md "Tower Voluntarily Removed": "Smooth dissolve or
## retract animation (~0.3–0.5s). No debris, no red flash — reads as
## 'packed up, not killed.'" Deliberately the calm counterpart to
## TowerDestroyVFX's sudden/violent flash-and-burst — this node animates and
## frees ITSELF; the caller does not queue_free() separately. The idle
## ambient particles (if any) are children of this node and are freed
## along with it automatically, no separate cleanup needed.
func play_remove_animation() -> void:
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
func play_targeting_orientation(target_world_position: Vector2, glow_color: Color, glow_duration: float) -> void:
	var to_target: Vector2 = target_world_position - global_position
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
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_set_hit_flash_amount(1.0)
	if _hit_flash_material_3d != null:
		_hit_flash_material_3d.set_shader_parameter("flash_amount", 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_method(
		func(v: float) -> void:
			_set_hit_flash_amount(v)
			if _hit_flash_material_3d != null:
				_hit_flash_material_3d.set_shader_parameter("flash_amount", v),
		1.0, 0.0, HIT_FLASH_DURATION
	)


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
	queue_redraw()


## Draws the element-tint identity ring, the TARGETING weapon-slot glow, and
## the perk badge, in that order -- the ring paints first, so it is the
## bottom-most layer, underneath both the glow dot and the badge. It only
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
	if _has_perk_badge:
		var badge_pos := Vector2(TARGET_DISPLAY_HEIGHT * 0.35, -TARGET_DISPLAY_HEIGHT * 0.45)
		draw_circle(badge_pos, PERK_BADGE_RADIUS, PERK_BADGE_COLOR)
		draw_arc(badge_pos, PERK_BADGE_RADIUS, 0.0, TAU, 24, Color(0.95, 0.95, 0.9), 1.5, true)


# ---------------------------------------------------------------------------
# Epic 15 Story 003 (ADR-0037): 3D visual-companion subtree.
# Purely additive — everything above this point (this file's existing 2D
# sprite/particle/tween presentation) is unchanged, per ADR-0037's core
# constraint of zero simulation-code changes.
# ---------------------------------------------------------------------------

## Builds (or rebuilds) the Node3D visual-companion subtree holding this
## tower's MeshInstance3D-bearing mesh instance, resolved via
## GGameDataRegistry.get_visual_mesh_mapping() (data-driven per ADR-0037's
## Constraints — never a hardcoded scene reference), and syncs its position
## via VisualMath.map_to_3d() against this tower's own 2D `position`.
##
## Deviation from ADR-0037's literal "TowerInstance already has one [update
## callback], this adds one line" framing: TowerInstance has ZERO existing
## _process()/_physics_process() overrides (verified — grep found none prior
## to this story). A real TowerInstance's `position` is set exactly once, by
## its owning mission scene (mission_scene.gd/the_gap.gd's _on_tower_placed),
## BEFORE configure() is called and never touched again afterward — towers do
## not reposition after placement in this codebase. configure() is therefore
## the correct "existing update method" per the story's actual intent (sync
## on every relevant position-affecting event, add no new callback): it is
## the one method that already runs once per tower and already runs strictly
## after `position` is final, matching the QA Test Cases' own "if applicable"
## hedge on the repositioning case. This mirrors grid_visual.gd's identical
## precedent (build once from configure(), since the underlying entity's 2D
## position is static after that call) rather than grid_visual.gd's *other*
## precedent for genuinely-moving entities (Stories 004-006's centralized
## per-frame managers), which does not apply here.
##
## A missing/invalid mapping fails loudly (push_error) rather than silently
## rendering no visual, per ADR-0037's Risks section policy ("rather than
## silently falling back to invisible") — same policy grid_visual.gd already
## established.
##
## Called once per configure() call. If configure() is ever called again on
## an already-configured TowerInstance (not this project's current call
## sites, but this method makes no single-call assumption, matching
## grid_visual.gd's own defensive rebuild), the previous companion subtree is
## freed and rebuilt from scratch rather than leaking or duplicating mesh
## instances.
func _build_visual_companion() -> void:
	# Synchronous remove_child() BEFORE queue_free(), not queue_free() alone —
	# same gotcha grid_visual.gd's _build_visual_companion() already fixed
	# (docs/registry/architecture.yaml's mission_hud_planning_cluster_lifecycle
	# entry): queue_free() defers removal to end-of-frame, so an
	# immediately-following add_child() of a new node with the SAME name
	# ("VisualCompanion3D") while the old one is still technically in the tree
	# causes Godot to auto-uniquify the new node's name — after the deferred
	# free runs, zero nodes are left with the expected name.
	if _visual_companion != null and is_instance_valid(_visual_companion):
		remove_child(_visual_companion)
		_visual_companion.queue_free()
	_visual_companion = Node3D.new()
	_visual_companion.name = "VisualCompanion3D"
	add_child(_visual_companion)

	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(TOWER_MESH_ENTITY_ID)
	if mapping == null or mapping.mesh_scene == null:
		push_error("[TowerInstance] No valid VisualMeshMappingResource for '%s' — tower will have no 3D visual companion." % TOWER_MESH_ENTITY_ID)
		return

	var mesh_node: Node = mapping.mesh_scene.instantiate()
	if not (mesh_node is Node3D):
		push_error("[TowerInstance] mesh_scene for '%s' did not instantiate as a Node3D — no 3D visual companion." % TOWER_MESH_ENTITY_ID)
		mesh_node.free()
		return
	_visual_companion.add_child(mesh_node)
	# ABSOLUTE assignment only, never additive/relative to this Node2D's own
	# transform — a Node3D child of a Node2D parent does not inherit the
	# parent's 2D transform (ADR-0037's "Important engine clarification").
	(mesh_node as Node3D).position = VisualMath.map_to_3d(position, TOWER_LAYER_HEIGHT)

	_build_picking_area()
	_build_hit_flash_material_3d(mesh_node)


## Epic 15 Phase 3 (VFX/shaders -> spatial). Finds the first MeshInstance3D
## in the instantiated mesh_scene subtree, reads its surface-0 material's
## albedo texture (StandardMaterial3D.albedo_texture), and — if one exists —
## builds a per-instance HIT_FLASH_SHADER_SPATIAL ShaderMaterial seeded with
## it, applied as that MeshInstance3D's material_override.
##
## UNVERIFIED THIS SESSION: this project's Kenney-pack placeholder meshes
## (design/art/codex-art-overhaul.md — 3D art is still placeholder, real
## pipeline not yet built, see ADR-0039's Phase 5 note) were never live-
## inspected for their actual material/texture structure while writing this
## (explicit "no testing" constraint for this work session). If a mesh has no
## StandardMaterial3D with an albedo_texture (e.g. a vertex-colored or
## texture-less placeholder mesh), this logs a warning and leaves
## _hit_flash_material_3d null — play_hit_flash() then flashes the 2D sprite
## only, exactly matching current shipping behavior. This is a deliberate
## graceful-degradation choice (src/CLAUDE.md's engine-code.md "all engine
## systems must support graceful degradation"), not a silent bug: the 2D
## flash (the only one a player watching Camera2D actually sees today) is
## unaffected either way.
func _build_hit_flash_material_3d(mesh_scene_root: Node) -> void:
	var mesh_instance: MeshInstance3D = _find_first_mesh_instance_3d(mesh_scene_root)
	if mesh_instance == null:
		push_warning("[TowerInstance] No MeshInstance3D found in mesh_scene for '%s' — 3D hit-flash unavailable, 2D flash still works." % TOWER_MESH_ENTITY_ID)
		return
	var source_material: Material = mesh_instance.get_active_material(0)
	if not (source_material is StandardMaterial3D):
		push_warning("[TowerInstance] mesh_scene for '%s' has no StandardMaterial3D on surface 0 — 3D hit-flash unavailable, 2D flash still works." % TOWER_MESH_ENTITY_ID)
		return
	var albedo_tex: Texture2D = (source_material as StandardMaterial3D).albedo_texture
	if albedo_tex == null:
		push_warning("[TowerInstance] mesh_scene for '%s' has no albedo_texture — 3D hit-flash unavailable, 2D flash still works." % TOWER_MESH_ENTITY_ID)
		return
	_hit_flash_material_3d = ShaderMaterial.new()
	_hit_flash_material_3d.shader = HIT_FLASH_SHADER_SPATIAL
	_hit_flash_material_3d.set_shader_parameter("albedo_tex", albedo_tex)
	mesh_instance.material_override = _hit_flash_material_3d


## Depth-first search for the first MeshInstance3D under `root` (inclusive).
## mesh_scene's internal structure is whatever the source art pipeline
## produced (a bare MeshInstance3D, or a rig with intermediate Node3D/
## Skeleton3D wrapper nodes) — not assumed flat.
func _find_first_mesh_instance_3d(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child: Node in root.get_children():
		var found: MeshInstance3D = _find_first_mesh_instance_3d(child)
		if found != null:
			return found
	return null


## Adds an Area3D + CollisionShape3D sibling of the mesh under
## VisualCompanion3D, on Picking3D.PICKING_LAYER_TOWER, for ADR-0039 (3D
## Interaction and Picking Layer, Epic 15 Phase 2). Dormant infrastructure —
## nothing raycasts against this layer until a scene's ENABLE_3D_PRESENTATION_MODE
## constant is flipped true (see ADR-0039's Decision, "Dormancy" subsection).
## Box size approximates the mesh's footprint using this tower's existing
## TARGET_DISPLAY_HEIGHT (the 2D-to-3D coordinate mapping is 1:1 per
## VisualMath.map_to_3d(), so world-unit sizing here matches the 2D grid's
## own scale) — not measured against the actual mesh AABB, since that would
## require the mesh to be loaded and ready-processed, which live-verification
## (explicitly out of scope this session) would be needed to confirm is safe.
func _build_picking_area() -> void:
	var area := Area3D.new()
	area.collision_layer = Picking3D.PICKING_LAYER_TOWER
	area.collision_mask = 0
	area.set_meta("owner_tower", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * TARGET_DISPLAY_HEIGHT
	shape.shape = box
	area.add_child(shape)
	_visual_companion.add_child(area)
	area.position = VisualMath.map_to_3d(position, TOWER_LAYER_HEIGHT)

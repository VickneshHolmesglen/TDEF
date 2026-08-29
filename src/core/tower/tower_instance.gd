class_name TowerInstance
extends Node2D

## Minimal visual presentation for a placed tower. Displays a static texture
## keyed by the tower's Foundation archetype (`physical` | `ranged` |
## `elemental` | `support`, per design/gdd/tower.md Group 2).
##
## Scope note: this is presentation only — it has no link yet to
## TowerSystem/TowerMissionState (which remain RefCounted, headless
## simulation with no scene-tree presence). Placement-triggered
## instantiation, tier-based art swaps, and damaged-state visuals are not
## yet designed; call configure() manually until that wiring exists.

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

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _idle_particles: CPUParticles2D = $IdleParticles2D


func _ready() -> void:
	_hit_flash_material = ShaderMaterial.new()
	_hit_flash_material.shader = HIT_FLASH_SHADER
	_sprite.material = _hit_flash_material


## Sets the displayed texture for the given Foundation archetype (and, for
## "elemental" archetype towers, the real WeaponComponent.element — see
## ELEMENT_TEXTURES's own doc comment for the bug this closes) and scales it
## to TARGET_DISPLAY_HEIGHT. Logs a warning and leaves the sprite empty if no
## art exists for that archetype/element combination yet. element defaults to
## "" for non-elemental archetypes, which always fall through to
## ARCHETYPE_TEXTURES regardless.
func configure(archetype: String, element: String = "") -> void:
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
		queue_redraw()
		return
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
	_build_visual_companion()


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
	_sprite.modulate = Color.WHITE
	_sprite.scale = _base_sprite_scale
	_punch_tween = create_tween()
	# Charge-up (anticipation): a quick pull-back before the flash+scale-out
	# below — see CHARGE_UP_DURATION's own doc comment for why this is folded
	# into the same tween chain rather than a separately-timed call.
	_punch_tween.tween_property(_sprite, "scale", _base_sprite_scale * CHARGE_UP_SCALE_TROUGH, CHARGE_UP_DURATION)
	_punch_tween.chain().set_parallel(true)
	_punch_tween.tween_property(_sprite, "modulate", color, PUNCH_FLASH_IN_DURATION)
	_punch_tween.tween_property(_sprite, "scale", _base_sprite_scale * PUNCH_SCALE_PEAK, PUNCH_FLASH_IN_DURATION)
	_punch_tween.chain().set_parallel(true)
	_punch_tween.tween_property(_sprite, "modulate", Color.WHITE, PUNCH_FLASH_OUT_DURATION)
	_punch_tween.tween_property(_sprite, "scale", _base_sprite_scale, PUNCH_FLASH_OUT_DURATION)


## Art & Animation Pipeline Upgrade, vertical slice — see HIT_FLASH_SHADER's
## own doc comment for the real feedback gap this closes (towers took damage
## with zero sprite reaction). Driven independently of play_attack_punch()'s
## modulate/scale channel via a shader uniform instead, so a tower being hit
## mid-punch (e.g. by a different monster while it's also firing) shows both
## effects at once rather than one overwriting the other.
func play_hit_flash() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_hit_flash_material.set_shader_parameter("flash_amount", 1.0)
	if _hit_flash_material_3d != null:
		_hit_flash_material_3d.set_shader_parameter("flash_amount", 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_method(
		func(v: float) -> void:
			_hit_flash_material.set_shader_parameter("flash_amount", v)
			if _hit_flash_material_3d != null:
				_hit_flash_material_3d.set_shader_parameter("flash_amount", v),
		1.0, 0.0, HIT_FLASH_DURATION
	)


## design/gdd/tower.md "Pre-Placement Perk Indicator" — see PERK_BADGE_COLOR's
## own doc comment. active: true on pre_placement_perk_activated; this method
## is never called with false in the current implementation (see that
## comment for why forfeiture doesn't need an explicit "turn off" path) but
## accepts the parameter for correctness/testability rather than a bare
## "activate" method that could only ever do one thing.
func set_perk_badge(active: bool) -> void:
	_has_perk_badge = active
	queue_redraw()


## Draws the TARGETING weapon-slot glow and the perk badge. The ATTACKING
## punch lives entirely on _sprite's own modulate/scale (no custom draw
## needed for it), keeping that channel structurally separate from both of
## these.
func _draw() -> void:
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

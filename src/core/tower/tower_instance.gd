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
const ARCHETYPE_TEXTURES: Dictionary[String, Texture2D] = {
	"ranged": preload("res://assets/art/towers/tower_ranged_base.png"),
	"physical": preload("res://assets/art/towers/tower_physical_base.png"),
	"elemental": preload("res://assets/art/towers/tower_elem_ice.png"),
	"support": preload("res://assets/art/towers/tower_support_base.png"),
}

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
const ORIENTATION_SNAP_DURATION: float = 0.1  ## seconds — fast enough to read as a "snap," not a smooth pan
const WEAPON_GLOW_PEAK_ALPHA: float = 0.5
const WEAPON_GLOW_RADIUS: float = 6.0  ## world units

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
var _rotation_tween: Tween = null
var _glow_tween: Tween = null
var _punch_tween: Tween = null
var _has_perk_badge: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _idle_particles: CPUParticles2D = $IdleParticles2D


## Sets the displayed texture for the given Foundation archetype and scales
## it to TARGET_DISPLAY_HEIGHT. Logs a warning and leaves the sprite empty
## if no art exists for that archetype yet.
func configure(archetype: String) -> void:
	var texture: Texture2D = ARCHETYPE_TEXTURES.get(archetype, null)
	if texture == null:
		push_warning("[TowerInstance] no art authored for archetype '%s'" % archetype)
		_sprite.texture = null
		return
	_sprite.texture = texture
	var uniform_scale: float = TARGET_DISPLAY_HEIGHT / float(texture.get_height())
	_sprite.scale = Vector2(uniform_scale, uniform_scale)
	_base_sprite_scale = _sprite.scale


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
		if _rotation_tween != null and _rotation_tween.is_valid():
			_rotation_tween.kill()
		# Placeholder art is authored facing "up" (a common top-down default);
		# the + PI/2 offset makes rotation=0 correspond to that assumed facing.
		# Approximation, not a verified art-authoring guarantee — flagged
		# rather than silently assumed correct.
		var target_angle: float = to_target.angle() + PI / 2.0
		_rotation_tween = create_tween()
		_rotation_tween.tween_property(_sprite, "rotation", target_angle, ORIENTATION_SNAP_DURATION) \
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
	_punch_tween.set_parallel(true)
	_punch_tween.tween_property(_sprite, "modulate", color, PUNCH_FLASH_IN_DURATION)
	_punch_tween.tween_property(_sprite, "scale", _base_sprite_scale * PUNCH_SCALE_PEAK, PUNCH_FLASH_IN_DURATION)
	_punch_tween.chain().set_parallel(true)
	_punch_tween.tween_property(_sprite, "modulate", Color.WHITE, PUNCH_FLASH_OUT_DURATION)
	_punch_tween.tween_property(_sprite, "scale", _base_sprite_scale, PUNCH_FLASH_OUT_DURATION)


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
		draw_circle(Vector2(0.0, -TARGET_DISPLAY_HEIGHT * 0.3), WEAPON_GLOW_RADIUS, glow_color)
	if _has_perk_badge:
		var badge_pos := Vector2(TARGET_DISPLAY_HEIGHT * 0.35, -TARGET_DISPLAY_HEIGHT * 0.45)
		draw_circle(badge_pos, PERK_BADGE_RADIUS, PERK_BADGE_COLOR)
		draw_arc(badge_pos, PERK_BADGE_RADIUS, 0.0, TAU, 24, Color(0.95, 0.95, 0.9), 1.5, true)

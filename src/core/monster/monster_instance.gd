class_name MonsterInstance
extends Node2D

## Minimal visual presentation for a spawned monster. Displays a static
## texture keyed by the monster's `monster_id` (per design/gdd/monster.md
## Group 1 — one authored art asset per monster_id, not per-archetype/tier
## like TowerInstance's Foundation-archetype keying).
##
## Mirrors TowerInstance's pattern (src/core/tower/tower_instance.gd):
## presentation only, no simulation logic. Unlike TowerInstance, this IS
## wired into its owning system's spawn path — MonsterManager._spawn_entity()
## already parents every MonsterEntity into the real scene tree (TD-monster-003),
## so no separate placement-triggered-instantiation gap exists here.

## monster_id -> single-pose art (HUD/Mission Select previews, death ghost, and
## the in-mission sprite for a monster without an animation sheet). Every
## monster in assets/data/monsters has an entry. iron_colossus_elite's only
## painted art is its walk strip, so its still is that strip's idle frame
## (pixelate_sprites.py DERIVED_STILLS, 2026-10-25).
const MONSTER_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"goblin_runner": preload("res://assets/art/monsters/goblin_runner.png"),
	&"spore_skitterling": preload("res://assets/art/monsters/spore_skitterling.png"),
	&"armored_brute": preload("res://assets/art/monsters/armored_brute.png"),
	&"forest_troll_elite": preload("res://assets/art/monsters/forest_troll_elite.png"),
	&"bog_lurker_elite": preload("res://assets/art/monsters/bog_lurker_elite.png"),
	&"goblin_warlord_boss": preload("res://assets/art/monsters/goblin_warlord_boss.png"),
	&"rift_sentinel_boss": preload("res://assets/art/monsters/rift_sentinel_boss.png"),
	&"iron_colossus_elite": preload("res://assets/art/monsters/iron_colossus_elite_idle.png"),
}

## Target on-screen size (world units, matches MonsterManager.CELL_SIZE=64) for
## a sprite's longest edge, by MonsterResource.tier (0=STANDARD/1=ELITE fit one
## cell; 2=BOSS reads deliberately larger). Source art is authored at native
## ChatGPT-generation resolution (~900-1200px) with no downscale baked in —
## found live via Godot MCP screenshot (an undersized boss filled the whole
## viewport) rather than assumed; TowerInstance shares this same unscaled
## pattern but was never live-verified against a real placement to catch it.
const TARGET_LONG_EDGE_BY_TIER: Dictionary[int, float] = {
	0: 64.0,
	1: 64.0,
	2: 112.0,
}

## design/gdd/monster.md "Tier Badge / Icon": "STANDARD: None. ELITE: 12x12px
## world-space icon, top-right of sprite bounding box, single downward
## chevron or elite-mark glyph — follows same spec pattern as tower
## pre-placement perk badge. BOSS: 16x16px world-space icon, top-right,
## skull or crown glyph (art bible to define)." No art bible glyph asset
## exists yet, so both are drawn procedurally via _draw() — the same
## _draw()-based approach TowerInstance's own perk badge already uses.
## Crown chosen over skull for BOSS (simpler to read as a clean silhouette
## at this size without dedicated art); GDD explicitly leaves this open.
const ELITE_BADGE_SIZE: float = 12.0
const BOSS_BADGE_SIZE: float = 16.0
const ELITE_BADGE_COLOR: Color = Color(0.784, 0.847, 0.909)  ## Silver / cold-white — GDD's own #C8D8E8 provisional value
const BOSS_BADGE_COLOR: Color = Color(0.9, 0.75, 0.2)  ## gold crown

## Wind-up telegraph (wind-up presentation spec §4.1). Mirrors MonsterManager.CELL_SIZE (a direct
## reference would make the two scripts depend on each other at parse time).
## Assumes GridConfig.cell_size == 64 (same assumption as MonsterManager.CELL_SIZE).
const CELL_SIZE: float = 64.0
const TELEGRAPH_COLOR: Color = Color(0.878, 0.267, 0.18)
const TELEGRAPH_PULSE_HZ: float = 2.0  ## at most 2 flashes per second (flash-safety limit is 3)
const TELEGRAPH_TINT_STRENGTH: float = 0.55
const TELEGRAPH_OUTLINE_WIDTH: float = 3.0
const TELEGRAPH_DASH: float = 10.0
const TELEGRAPH_BAR_SIZE: Vector2 = Vector2(40.0, 6.0)
const TELEGRAPH_BAR_GAP: float = 6.0
const RESOLVE_HIT_DURATION: float = 0.15
const RESOLVE_WHIFF_DURATION: float = 0.3
const RESOLVE_WHIFF_COLOR: Color = Color(0.72, 0.72, 0.72)

## design/gdd/monster.md: "Plus: floating display_name nameplate above
## sprite, Y-offset above bounding box top, using HUD font." No dedicated
## HUD font/theme resource exists yet anywhere in this project (checked —
## Mission HUD's own screens use Godot's default theme throughout), so the
## nameplate Label uses the default font rather than a fabricated one.
const NAMEPLATE_Y_OFFSET: float = 10.0  ## world units above the sprite's own top edge

## Y-height for monster visuals per ADR-0037's layer_height table ("monster
## visual anchors = 0" — same reasoning as TowerInstance.TOWER_LAYER_HEIGHT
## and GridVisual.TILE_LAYER_HEIGHT: the spike's live-queried AABB data shows
## these Kenney meshes already have their origin at their own base).
const MONSTER_LAYER_HEIGHT: float = 0.0

var _tier: int = 0
## Half-extent of the actual rendered sprite (texture size x uniform_scale),
## computed fresh in configure() — badges/nameplate position relative to
## this, not TARGET_LONG_EDGE_BY_TIER, since source art aspect ratios vary
## per monster (see this file's own unscaled-sprite doc comment above).
var _sprite_half_size: Vector2 = Vector2(32.0, 32.0)

## Art & Animation Pipeline Upgrade, vertical slice (design/art/animation-
## pipeline.md §2 "Monsters: procedural first"). This file had zero Tween
## usage anywhere before this — the highest on-screen-frequency entity in
## the game had no self-driven feedback of any kind. Mirrors TowerInstance's
## identical hit-flash pattern (src/core/tower/tower_instance.gd) so both
## entity types share one visual vocabulary for "just took damage."
const HIT_FLASH_SHADER: Shader = preload("res://src/shaders/hit_flash.gdshader")
const HIT_FLASH_DURATION: float = 0.18
var _hit_flash_material: ShaderMaterial = null
var _hit_flash_tween: Tween = null
var _telegraph_active: bool = false
var _telegraph_progress: float = 0.0
var _telegraph_range_cells: int = 0
var _telegraph_center_offset: Vector2 = Vector2.ZERO
var _telegraph_time: float = 0.0
var _resolve_alpha: float = 0.0
var _resolve_hit: bool = false
var _resolve_tween: Tween = null

## Walk animation (2026-10-07, player-reported "no movement animation";
## animation-pipeline.md §2 allows per-monster frame animation where the walk
## tell is worth the asset cost -- these sheets already exist). The visible 2D
## sprite plays the monster's CreatureAtlasMapping clips from its sprite sheet:
## "walk" while it is actually moving, "idle" when it stands still (stunned,
## attacking, waiting), "attack_prepare" during a boss wind-up when the sheet
## has one. Sheets face right, so the sprite flips while walking left. A
## monster without a usable sheet keeps its static image (MONSTER_TEXTURES).
## Driven by MonsterManager (advance_animation), never a per-monster _process.
var _clips: Dictionary[StringName, CreatureAnimationClip] = {}
var _anim_clip: StringName = &""
var _anim_time: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _has_last_position: bool = false
## Below this many world units of travel per frame the monster counts as standing still.
const WALK_MOVE_EPSILON: float = 0.05

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _nameplate: Label = $Nameplate


## ADR-0042 unit pass: contact shadow at the sprite's feet, sized from the
## fitted sprite so it tracks every tier/size.
func _update_ground_shadow() -> void:
	GroundShadow.attach(self, _sprite_half_size.x * 1.3, _sprite_half_size.y * 0.85)


func _ready() -> void:
	_hit_flash_material = ShaderMaterial.new()
	_hit_flash_material.shader = HIT_FLASH_SHADER
	_sprite.material = _hit_flash_material


## See HIT_FLASH_SHADER's own doc comment. Independent of any other visual
## channel on this sprite (there are none yet) — a shader parameter flash
## rather than a modulate tween so a future addition (e.g. a status-effect
## tint) can't fight this over the same property, matching the reasoning
## TowerInstance.play_hit_flash() already established.
func play_hit_flash() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_hit_flash_material.set_shader_parameter("flash_amount", 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_method(
		func(v: float) -> void: _hit_flash_material.set_shader_parameter("flash_amount", v),
		1.0, 0.0, HIT_FLASH_DURATION
	)


## display_name: MonsterResource.display_name — only consulted for BOSS
## (tier == 2); ignored for STANDARD/ELITE, which get no nameplate at MVP.
## Sets the displayed texture for the given monster_id and scales it to fit
## the grid (see TARGET_LONG_EDGE_BY_TIER). Logs a warning and leaves the
## sprite empty if no art exists for that id yet.
func configure(monster_id: StringName, tier: int = 0, display_name: String = "") -> void:
	_tier = tier
	if _configure_sheet(monster_id, tier):
		_configure_nameplate(display_name)
		return
	var texture: Texture2D = MONSTER_TEXTURES.get(monster_id, null)
	if texture == null:
		push_warning("[MonsterInstance] no art authored for monster_id '%s'" % monster_id)
		_sprite.texture = null
		_nameplate.visible = false
		queue_redraw()
		return
	_sprite.texture = texture
	var target_long_edge: float = TARGET_LONG_EDGE_BY_TIER.get(tier, 64.0)
	var longest_edge: float = maxf(texture.get_width(), texture.get_height())
	var uniform_scale: float = target_long_edge / longest_edge
	_sprite.scale = Vector2(uniform_scale, uniform_scale)
	_sprite_half_size = Vector2(texture.get_width(), texture.get_height()) * uniform_scale * 0.5
	_update_ground_shadow()

	_configure_nameplate(display_name)
	queue_redraw()


## BOSS nameplate above the sprite (STANDARD/ELITE get none at MVP).
func _configure_nameplate(display_name: String) -> void:
	if _tier == 2:
		_nameplate.text = display_name
		_nameplate.visible = true
		# get_minimum_size() (not .size) — recomputes synchronously from font
		# metrics the instant .text is set; .size can still reflect the
		# pre-update layout until Godot's next Control layout pass runs,
		# which would misposition/clip the nameplate on its very first frame.
		var label_size: Vector2 = _nameplate.get_minimum_size()
		# Centered horizontally, sitting just above the sprite's top edge.
		_nameplate.position = Vector2(-label_size.x * 0.5,
				-_sprite_half_size.y - NAMEPLATE_Y_OFFSET - label_size.y)
	else:
		_nameplate.visible = false

	queue_redraw()


## Uses the monster's sprite sheet (CreatureAtlasMapping) when it has a walk
## clip. Returns false (caller falls back to the static image) when there is no
## mapping, no sheet texture, or the sheet would slice into implausible frames.
func _configure_sheet(monster_id: StringName, tier: int) -> bool:
	var mapping: CreatureAtlasMappingResource = GGameDataRegistry.get_creature_atlas_mapping(monster_id)
	if mapping == null or mapping.atlas_texture == null or mapping.get_animation_clip(&"walk") == null:
		return false
	var columns: int = maxi(mapping.atlas_columns, 1)
	var rows: int = maxi(mapping.atlas_rows, 1)
	var frame_size := Vector2(mapping.atlas_texture.get_width() / float(columns), mapping.atlas_texture.get_height() / float(rows))
	# A single painting mislabelled as a strip would slice into slivers.
	if frame_size.x < 16.0 or frame_size.y < 16.0 or frame_size.x / frame_size.y > 3.0 or frame_size.y / frame_size.x > 3.0:
		return false
	_clips.clear()
	for clip: CreatureAnimationClip in mapping.animation_clips:
		_clips[clip.clip_name] = clip
	_sprite.texture = mapping.atlas_texture
	_sprite.hframes = columns
	_sprite.vframes = rows
	var uniform_scale: float = TARGET_LONG_EDGE_BY_TIER.get(tier, 64.0) / maxf(frame_size.x, frame_size.y)
	_sprite.scale = Vector2(uniform_scale, uniform_scale)
	_sprite_half_size = frame_size * uniform_scale * 0.5
	_update_ground_shadow()
	_anim_time = 0.0
	_has_last_position = false
	_show_clip(&"idle" if _clips.has(&"idle") else &"walk", 0.0)
	return true


## True when this monster animates from a sprite sheet.
func is_sheet_animated() -> bool:
	return not _clips.is_empty()


## Called once per frame by MonsterManager._pass3c_visual_sync() -- monsters
## never run their own _process (ADR-0006 per_monster_physics_process rule).
## Walking vs standing and facing come from how far this instance actually
## moved since the last call; `preparing` (an attack wind-up) shows the
## sheet's attack_prepare clip when it has one.
func advance_animation(delta: float, preparing: bool = false) -> void:
	if _clips.is_empty():
		return
	var moved: Vector2 = global_position - _last_position if _has_last_position else Vector2.ZERO
	_last_position = global_position
	_has_last_position = true
	if absf(moved.x) > WALK_MOVE_EPSILON:
		_sprite.flip_h = moved.x < 0.0  # sheets face right
	var clip_name: StringName = &"idle"
	if preparing and _clips.has(&"attack_prepare"):
		clip_name = &"attack_prepare"
	elif moved.length() > WALK_MOVE_EPSILON:
		clip_name = &"walk"
	_show_clip(clip_name if _clips.has(clip_name) else &"walk", delta)


## Advances (or switches to) `clip_name` and sets the sprite's frame.
func _show_clip(clip_name: StringName, delta: float) -> void:
	if clip_name != _anim_clip:
		_anim_clip = clip_name
		_anim_time = 0.0
	else:
		_anim_time += delta
	var clip: CreatureAnimationClip = _clips.get(clip_name)
	if clip == null:
		return
	var step: int = int(_anim_time * clip.fps)
	var offset: int = step % maxi(clip.frame_count, 1) if clip.loop else mini(step, clip.frame_count - 1)
	_sprite.frame = clampi(clip.start_frame + offset, 0, _sprite.hframes * _sprite.vframes - 1)


## Name of the clip currently shown (for tests).
func get_current_clip() -> StringName:
	return _anim_clip


func _exit_tree() -> void:
	_kill_resolve_tween()


## 0 at the start of the wind-up, 1 when it fires. A zero-length wind-up reads as complete.
static func windup_progress(remaining: float, total: float) -> float:
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / total, 0.0, 1.0)


## Half the side of the reach square: reach is Chebyshev distance, so it is a (2r+1)-cell square.
static func reach_half_extent(range_cells: int) -> float:
	return (float(range_cells) + 0.5) * CELL_SIZE


## 0..1 pulse at TELEGRAPH_PULSE_HZ; a steady 0.5 under reduced motion.
static func pulse_amount(elapsed: float) -> float:
	if ReduceMotion.enabled():
		return 0.5
	return 0.5 + 0.5 * sin(TAU * TELEGRAPH_PULSE_HZ * elapsed)


## Driven every frame by MonsterManager._pass3c_visual_sync while a Hero wind-up is in flight.
## `center_offset` is the vector from this node to the CENTER of the monster's grid cell (the
## Hero-hit range check is made from that cell), so the outline matches what the simulation judges.
func set_windup_telegraph(progress: float, range_cells: int, center_offset: Vector2, delta: float) -> void:
	if not _telegraph_active:
		_telegraph_time = 0.0
	_kill_resolve_tween()
	_resolve_alpha = 0.0
	_telegraph_active = true
	_telegraph_progress = progress
	_telegraph_range_cells = range_cells
	_telegraph_center_offset = center_offset
	_telegraph_time += delta
	_sprite.modulate = Color.WHITE.lerp(TELEGRAPH_COLOR, pulse_amount(_telegraph_time) * TELEGRAPH_TINT_STRENGTH)
	queue_redraw()


## Ends the live telegraph. Deliberately leaves a running resolve fade alone: the wind-up state
## clears in the same frame it resolves, and the hit/whiff confirmation must outlive it.
func clear_windup_telegraph() -> void:
	if not _telegraph_active:
		return
	_telegraph_active = false
	_sprite.modulate = Color.WHITE
	queue_redraw()


## Hit: the outline flashes solid red then clears. Whiff: it fades to neutral grey (the player's
## "I dodged it" confirmation). Reuses the geometry of the last telegraph.
func play_windup_resolved(hit: bool) -> void:
	if not is_inside_tree():
		return
	_kill_resolve_tween()
	_resolve_hit = hit
	_resolve_alpha = 1.0
	var duration: float = RESOLVE_HIT_DURATION if hit else RESOLVE_WHIFF_DURATION
	_resolve_tween = create_tween()
	_resolve_tween.tween_method(_set_resolve_alpha, 1.0, 0.0, duration)
	queue_redraw()


func is_windup_telegraph_active() -> bool:
	return _telegraph_active


func get_windup_progress() -> float:
	return _telegraph_progress


func get_resolve_alpha() -> float:
	return _resolve_alpha


func _set_resolve_alpha(value: float) -> void:
	_resolve_alpha = value
	queue_redraw()


func _kill_resolve_tween() -> void:
	if _resolve_tween != null and _resolve_tween.is_valid():
		_resolve_tween.kill()
	_resolve_tween = null


func _draw() -> void:
	match _tier:
		1:
			_draw_elite_badge()
		2:
			_draw_boss_badge()
	if _telegraph_active:
		_draw_reach_outline(TELEGRAPH_COLOR, 1.0, true)
		_draw_progress_bar()
	elif _resolve_alpha > 0.0:
		if _resolve_hit:
			_draw_reach_outline(TELEGRAPH_COLOR, _resolve_alpha, false)
		else:
			_draw_reach_outline(RESOLVE_WHIFF_COLOR, _resolve_alpha, true)


## Outline of the reach square. Dashed while a wind-up is live (the shape is the non-color cue);
## solid for the hit flash.
func _draw_reach_outline(color: Color, alpha: float, dashed: bool) -> void:
	var half: float = reach_half_extent(_telegraph_range_cells)
	var c: Vector2 = _telegraph_center_offset
	var corners := PackedVector2Array([
		c + Vector2(-half, -half), c + Vector2(half, -half),
		c + Vector2(half, half), c + Vector2(-half, half),
	])
	var draw_color := Color(color.r, color.g, color.b, alpha)
	for i in range(4):
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		if dashed:
			draw_dashed_line(from, to, draw_color, TELEGRAPH_OUTLINE_WIDTH, TELEGRAPH_DASH)
		else:
			draw_line(from, to, draw_color, TELEGRAPH_OUTLINE_WIDTH)


## Countdown bar under the sprite (the second non-color cue): dark track, red fill, red border.
func _draw_progress_bar() -> void:
	var top_left := Vector2(-TELEGRAPH_BAR_SIZE.x * 0.5, _sprite_half_size.y + TELEGRAPH_BAR_GAP)
	draw_rect(Rect2(top_left, TELEGRAPH_BAR_SIZE), Color(0.14, 0.12, 0.09), true)
	draw_rect(Rect2(top_left, Vector2(TELEGRAPH_BAR_SIZE.x * _telegraph_progress, TELEGRAPH_BAR_SIZE.y)), TELEGRAPH_COLOR, true)
	draw_rect(Rect2(top_left, TELEGRAPH_BAR_SIZE), TELEGRAPH_COLOR, false, 1.0)


## A single downward chevron — GDD's own first-listed option.
func _draw_elite_badge() -> void:
	var half: float = ELITE_BADGE_SIZE * 0.5
	var center := Vector2(_sprite_half_size.x - half, -_sprite_half_size.y + half)
	var points := PackedVector2Array([
		center + Vector2(-half, -half * 0.4),
		center + Vector2(0.0, half * 0.5),
		center + Vector2(half, -half * 0.4),
	])
	draw_polyline(points, ELITE_BADGE_COLOR, 2.5, true)


## A simple 3-point crown silhouette (base band + left/center/right spikes,
## center spike tallest) — a procedural placeholder until a real glyph
## asset exists.
func _draw_boss_badge() -> void:
	var half: float = BOSS_BADGE_SIZE * 0.5
	var center := Vector2(_sprite_half_size.x - half, -_sprite_half_size.y + half)
	var base_rect := Rect2(center + Vector2(-half, half * 0.2), Vector2(BOSS_BADGE_SIZE, half * 0.6))
	draw_rect(base_rect, BOSS_BADGE_COLOR, true)
	var point_width: float = half * 0.6
	for i in range(3):
		var spike_x: float = center.x - half + point_width * (0.5 + float(i) * 1.1)
		var spike_height: float = half * (0.9 if i == 1 else 0.5)
		var points := PackedVector2Array([
			Vector2(spike_x - point_width * 0.5, center.y + half * 0.2),
			Vector2(spike_x, center.y - spike_height),
			Vector2(spike_x + point_width * 0.5, center.y + half * 0.2),
		])
		draw_colored_polygon(points, BOSS_BADGE_COLOR)

# ---------------------------------------------------------------------------
# ADR-0038, Epic 16 Story 10: the legacy ADR-0037 3D mesh companion
# (_build_visual_companion()/sync_visual_companion_position(), formerly
# here) was removed in this cleanup pass — Story 9 retired its last live
# caller (BOSS; STANDARD/ELITE were already retired in Story 7). Every
# monster tier now presents via MonsterSwarmRenderer3D (STANDARD/ELITE) or
# BossCreaturePresenter3D (BOSS) instead. See git history for the removed
# implementation if ever needed for reference.
# ---------------------------------------------------------------------------

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

## monster_id -> art lookup. All 7 monsters generated this session have art.
const MONSTER_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"goblin_runner": preload("res://assets/art/monsters/goblin_runner.png"),
	&"spore_skitterling": preload("res://assets/art/monsters/spore_skitterling.png"),
	&"armored_brute": preload("res://assets/art/monsters/armored_brute.png"),
	&"forest_troll_elite": preload("res://assets/art/monsters/forest_troll_elite.png"),
	&"bog_lurker_elite": preload("res://assets/art/monsters/bog_lurker_elite.png"),
	&"goblin_warlord_boss": preload("res://assets/art/monsters/goblin_warlord_boss.png"),
	&"rift_sentinel_boss": preload("res://assets/art/monsters/rift_sentinel_boss.png"),
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

## design/gdd/monster.md: "Plus: floating display_name nameplate above
## sprite, Y-offset above bounding box top, using HUD font." No dedicated
## HUD font/theme resource exists yet anywhere in this project (checked —
## Mission HUD's own screens use Godot's default theme throughout), so the
## nameplate Label uses the default font rather than a fabricated one.
const NAMEPLATE_Y_OFFSET: float = 10.0  ## world units above the sprite's own top edge

## Epic 15 Story 004 (ADR-0037, Visual Presentation 3D Companion Layer): the
## entity_or_component_id every MonsterInstance resolves its 3D visual
## through, via GGameDataRegistry.get_visual_mesh_mapping(). A single shared
## id for every monster_id/tier — this story proves the companion pipeline
## for "at least one monster type" (ADR-0037's Migration Plan scope) by
## reusing one placeholder Kenney "Tower Defense Models" mesh
## (enemy-ufo-a.glb, thematically a placeholder — this epic proves the
## pipeline, not final art) rather than authoring a per-monster-type mesh set
## (a future content-authoring pass, not this story's architecture change).
## Mirrors tower_instance.gd's TOWER_MESH_ENTITY_ID / grid_visual.gd's
## TILE_MESH_ENTITY_ID — the same "one shared id proves the pattern" judgment
## call already established for those two entity types.
const MONSTER_MESH_ENTITY_ID: StringName = &"enemy_ufo_a"

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

## Node3D visual-companion subtree (ADR-0037's Visual Companion pattern),
## holding this monster's MeshInstance3D-bearing mesh instance. Built once
## from configure() (mirrors TowerInstance's/GridVisual's build-once
## pattern). Unlike TowerInstance's static-after-placement case, a monster's
## position changes every frame — but that per-frame sync is driven from
## OUTSIDE this script, by MonsterManager's existing centralized
## _physics_process pass calling sync_visual_companion_position() (below),
## never by a new _process()/_physics_process() override declared here.
## ADR-0006's registered forbidden pattern, per_monster_physics_process, is
## the single most important constraint this file must not violate — see
## monster_manager.gd's class doc comment and its _pass3c_visual_sync().
var _visual_companion: Node3D = null

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _nameplate: Label = $Nameplate


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

	if tier == 2:
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
	# Epic 15 Story 004 (ADR-0037): the one build-time call this story adds to
	# MonsterInstance's existing configure() — no new _process()/
	# _physics_process() callback. See _build_visual_companion()'s doc
	# comment for why configure() (not a new per-frame override) is the
	# correct place to BUILD the companion; per-frame POSITION sync is a
	# separate, externally-driven step (sync_visual_companion_position()).
	_build_visual_companion()


func _draw() -> void:
	match _tier:
		1:
			_draw_elite_badge()
		2:
			_draw_boss_badge()


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
# Epic 15 Story 004 (ADR-0037): 3D visual-companion subtree.
# Purely additive -- everything above this point (this file's existing 2D
# sprite/badge/nameplate/hit-flash presentation) is unchanged, per ADR-0037's
# core constraint of zero simulation-code changes. No _process()/
# _physics_process() is declared anywhere in this file -- position sync is
# driven externally, once per frame, by MonsterManager._physics_process's
# existing centralized pass (ADR-0006's per_monster_physics_process
# forbidden pattern is the single most important constraint of this story).
# ---------------------------------------------------------------------------

## Builds (or rebuilds) the Node3D visual-companion subtree holding this
## monster's MeshInstance3D-bearing mesh instance, resolved via
## GGameDataRegistry.get_visual_mesh_mapping() (data-driven per ADR-0037's
## Constraints -- never a hardcoded scene reference). Seeds the companion's
## initial position from this node's own global_position (equal to the
## owning MonsterEntity's global_position -- MonsterInstance is a plain
## Node2D child at local (0,0) that rides its parent's global_position for
## free, per this file's own class doc comment) so a monster spawned this
## frame has a correctly-placed companion on its very first visible frame,
## with no one-frame lag before MonsterManager's first per-frame sync call.
##
## A missing/invalid mapping fails loudly (push_error) rather than silently
## rendering no visual, per ADR-0037's Risks section policy -- same policy
## TowerInstance/GridVisual already established.
##
## Called once per configure() call (mirrors TowerInstance's identical
## precedent -- see tower_instance.gd's _build_visual_companion() doc
## comment). If configure() is ever called again on an already-configured
## MonsterInstance (not this project's current call sites), the previous
## companion subtree is freed and rebuilt from scratch rather than leaking
## or duplicating mesh instances.
func _build_visual_companion() -> void:
	# Synchronous remove_child() BEFORE queue_free(), not queue_free() alone
	# -- same gotcha TowerInstance's/GridVisual's _build_visual_companion()
	# already fixed (docs/registry/architecture.yaml's
	# mission_hud_planning_cluster_lifecycle entry): queue_free() defers
	# removal to end-of-frame, so an immediately-following add_child() of a
	# new node with the SAME name ("VisualCompanion3D") while the old one is
	# still technically in the tree causes Godot to auto-uniquify the new
	# node's name -- after the deferred free runs, zero nodes are left with
	# the expected name.
	if _visual_companion != null and is_instance_valid(_visual_companion):
		remove_child(_visual_companion)
		_visual_companion.queue_free()
	_visual_companion = Node3D.new()
	_visual_companion.name = "VisualCompanion3D"
	add_child(_visual_companion)

	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(MONSTER_MESH_ENTITY_ID)
	if mapping == null or mapping.mesh_scene == null:
		push_error("[MonsterInstance] No valid VisualMeshMappingResource for '%s' -- monster will have no 3D visual companion." % MONSTER_MESH_ENTITY_ID)
		return

	var mesh_node: Node = mapping.mesh_scene.instantiate()
	if not (mesh_node is Node3D):
		push_error("[MonsterInstance] mesh_scene for '%s' did not instantiate as a Node3D -- no 3D visual companion." % MONSTER_MESH_ENTITY_ID)
		mesh_node.free()
		return
	_visual_companion.add_child(mesh_node)
	# ABSOLUTE assignment only, never additive/relative to this Node2D's own
	# transform -- a Node3D child of a Node2D parent does not inherit the
	# parent's 2D transform (ADR-0037's "Important engine clarification").
	(mesh_node as Node3D).position = VisualMath.map_to_3d(global_position, MONSTER_LAYER_HEIGHT)


## Public per-frame sync entry point -- called every frame by
## MonsterManager's existing centralized _physics_process pass (never by a
## new per-node override on this script or on MonsterEntity, per ADR-0006's
## per_monster_physics_process forbidden pattern). world_position is an
## ABSOLUTE Node3D position, already computed via VisualMath.map_to_3d() by
## the caller -- never offset against this Node2D's own transform (a Node3D
## child does not inherit its Node2D parent's 2D transform, ADR-0037's
## "Important engine clarification"). No-op if this instance has no
## companion mesh (e.g. the mapping was missing/invalid at build time -- see
## _build_visual_companion()'s own doc comment).
##
## Usage (from MonsterManager._pass3c_visual_sync()):
##   entity.monster_instance.sync_visual_companion_position(
##       VisualMath.map_to_3d(entity.global_position, MonsterInstance.MONSTER_LAYER_HEIGHT))
func sync_visual_companion_position(world_position: Vector3) -> void:
	if _visual_companion == null or not is_instance_valid(_visual_companion):
		return
	if _visual_companion.get_child_count() == 0:
		return
	(_visual_companion.get_child(0) as Node3D).position = world_position

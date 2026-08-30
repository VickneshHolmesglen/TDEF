class_name BossCreaturePresenter3D
extends Node3D

## Capped individual-presenter pool for BOSS-tier (and any future
## approved-exceptional) creatures (ADR-0038 §"Bosses, elites, and
## Menagerie"; blueprint "boss_creature_presenter_3d.gd"). Reproduces
## design/gdd/monster.md's "BOSS Scene Structure — Two-Layer AnimatedSprite2D"
## spec in 3D: two stacked Sprite3D layers per slot — a base layer (always
## visible while registered) and an overlay layer (visible only during the
## attack-telegraph window, `boss_attack_prepare_remaining > 0`), mirroring
## the GDD's "walk continues uninterrupted on the base layer, attack_prepare
## plays on the overlay layer" design without `AnimationTree`.
##
## Real content gap, flagged not hidden: walk/attack_prepare/attack ANIMATION
## content now exists for `goblin_warlord_boss` and `rift_sentinel_boss`
## (mapped via `CreatureAtlasMappingResource` and `CreatureAnimationClip`).
## Any other tier-2 boss without a full `CreatureAtlasMappingResource` falls
## back to the static single-texture mode — both layers show the same
## static per-monster_id texture; the overlay's role in this fallback is
## proven entirely through its VISIBILITY toggle (on during the
## attack-telegraph window, off otherwise), not through distinct animated
## frames. Real animated boss art for additional bosses is a future
## content-authoring pass, not fabricated here.
##
## No independent process callback (ADR-0038: "Exceptional presenters have
## no independent process callback. MonsterManager publishes the same
## snapshots to their pool.") — `MonsterManager` calls `update_boss()` from
## its own existing centralized `_pass3c_visual_sync()`, exactly like the
## swarm path.
##
## Fixed capacity, content-capped per ADR-0038's "anticipated concurrency is
## content-capped and verified" — CAPACITY below is a reasonable assumed
## default (BOSS, tier 2, is the rarest spawn category by this project's
## own design), not empirically verified against real wave data; flagged
## here for a future playtest to confirm or raise.
##
## Uses a free-list slot allocator, not the swarm batch's dense
## swap-remove — a Node-based presenter has no `visible_instance_count`
## constraint to satisfy (each slot is a real Node3D that can simply hide
## itself), so there is no correctness reason to port the dense-packing
## complexity here.

const CAPACITY: int = 2

## Distinguishes this pool's handles from any real MonsterSwarmBatch's
## BatchKey string — a handle from one must never validate against the
## other.
const POOL_BATCH_KEY: String = "__boss_presenter_pool__"

const OVERLAY_STATE_HIDDEN: int = 0
const OVERLAY_STATE_PREPARE: int = 1
const OVERLAY_STATE_ATTACK: int = 2

var _free_slots: Array[int] = []
var _entity_to_slot: Dictionary = {}       # entity_id(int) -> slot_index(int)
var _entity_to_generation: Dictionary = {} # entity_id(int) -> generation(int)

var _slots: Array[Node3D] = []
var _base_layers: Array[Sprite3D] = []
var _overlay_layers: Array[Sprite3D] = []

var _base_clips: Array[CreatureAnimationClip] = []
var _base_elapsed: Array[float] = []
var _overlay_prepare_clips: Array[CreatureAnimationClip] = []
var _overlay_attack_clips: Array[CreatureAnimationClip] = []
var _overlay_states: Array[int] = []
var _overlay_elapsed: Array[float] = []


func _ready() -> void:
	for i in range(CAPACITY):
		_free_slots.append(i)

		var slot := Node3D.new()
		slot.name = "Slot_%d" % i
		slot.visible = false
		add_child(slot)
		_slots.append(slot)

		var base := Sprite3D.new()
		base.name = "BaseLayer"
		base.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		base.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		slot.add_child(base)
		_base_layers.append(base)

		var overlay := Sprite3D.new()
		overlay.name = "OverlayLayer"
		overlay.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		overlay.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		overlay.visible = false
		slot.add_child(overlay)
		_overlay_layers.append(overlay)

		_base_clips.append(null)
		_base_elapsed.append(0.0)
		_overlay_prepare_clips.append(null)
		_overlay_attack_clips.append(null)
		_overlay_states.append(OVERLAY_STATE_HIDDEN)
		_overlay_elapsed.append(0.0)


## Registers a new boss entity into a free slot. Returns a
## MonsterPresentationHandle on success, or null if the pool is at capacity
## (content-capped, never grown at runtime — ADR-0038's "no runtime
## instance_count resizing" spirit applies here too, even though this pool
## isn't a MultiMesh), a duplicate entity_id, or no art exists for
## monster_id.
func register_boss(entity_id: int, monster_id: StringName, world_transform: Transform3D) -> MonsterPresentationHandle:
	if _entity_to_slot.has(entity_id):
		push_warning("[BossCreaturePresenter3D] register_boss: entity_id %d already registered -- duplicate rejected" % entity_id)
		return null
	if _free_slots.is_empty():
		push_warning("[BossCreaturePresenter3D] register_boss: pool at capacity (%d) -- registration dropped, not resized" % CAPACITY)
		return null

	var mapping: CreatureAtlasMappingResource = GGameDataRegistry.get_creature_atlas_mapping(monster_id)
	var idle_clip: CreatureAnimationClip = mapping.get_animation_clip(&"idle") if mapping != null else null
	var walk_clip: CreatureAnimationClip = mapping.get_animation_clip(&"walk") if mapping != null else null
	var has_full_animset: bool = mapping != null and idle_clip != null and walk_clip != null

	var texture: Texture2D = mapping.atlas_texture if has_full_animset else MonsterInstance.MONSTER_TEXTURES.get(monster_id, null) as Texture2D
	if texture == null:
		push_error("[BossCreaturePresenter3D] register_boss: no art authored for monster_id '%s' -- no boss presenter." % monster_id)
		return null

	var slot: int = _free_slots.pop_back()
	var generation: int = (_entity_to_generation.get(entity_id, 0) as int) + 1
	_entity_to_slot[entity_id] = slot
	_entity_to_generation[entity_id] = generation

	_base_layers[slot].texture = texture
	_overlay_layers[slot].texture = texture
	if has_full_animset:
		_base_layers[slot].hframes = mapping.atlas_columns
		_base_layers[slot].vframes = mapping.atlas_rows
		_base_layers[slot].frame = idle_clip.start_frame
		_overlay_layers[slot].hframes = mapping.atlas_columns
		_overlay_layers[slot].vframes = mapping.atlas_rows
		_base_clips[slot] = walk_clip
		_overlay_prepare_clips[slot] = mapping.get_animation_clip(&"attack_prepare")
		_overlay_attack_clips[slot] = mapping.get_animation_clip(&"attack")
	else:
		_base_layers[slot].hframes = 1
		_base_layers[slot].vframes = 1
		# Sprite3D only re-derives `frame` from a hframes/vframes change when
		# vframes > 1 -- a slot reused from a previous full-animset boss could
		# otherwise keep a stale frame index (e.g. 13) that reads out of
		# bounds against this 1x1 fallback texture.
		_base_layers[slot].frame = 0
		_overlay_layers[slot].frame = 0
		_base_clips[slot] = null
		_overlay_prepare_clips[slot] = null
		_overlay_attack_clips[slot] = null
	_base_elapsed[slot] = 0.0
	_overlay_states[slot] = OVERLAY_STATE_HIDDEN
	_overlay_elapsed[slot] = 0.0
	_overlay_layers[slot].visible = false
	_slots[slot].visible = true
	_slots[slot].global_transform = world_transform

	return MonsterPresentationHandle.new(entity_id, POOL_BATCH_KEY, slot, generation)


## Updates a registered boss's position, base-layer walk animation frame,
## and attack-telegraph overlay visibility. `delta` advances the base-layer
## walk clip (no-op if the boss has no full animset or `delta <= 0.0`).
## Returns false (no mutation) for a stale/foreign handle — never mutates
## whatever entity now occupies that slot.
func update_boss(handle: MonsterPresentationHandle, world_transform: Transform3D, attack_telegraphed: bool, delta: float = 0.0) -> bool:
	var slot: int = _resolve_valid_slot(handle)
	if slot == -1:
		return false
	_slots[slot].global_transform = world_transform

	var walk_clip: CreatureAnimationClip = _base_clips[slot]
	if walk_clip != null and delta > 0.0:
		_base_elapsed[slot] += delta
		var frames_elapsed: int = int(_base_elapsed[slot] * walk_clip.fps)
		var offset_in_clip: int = frames_elapsed % walk_clip.frame_count
		_base_layers[slot].frame = walk_clip.start_frame + offset_in_clip

	var prepare_clip: CreatureAnimationClip = _overlay_prepare_clips[slot]
	var attack_clip: CreatureAnimationClip = _overlay_attack_clips[slot]
	if prepare_clip == null or attack_clip == null:
		# Fallback contract (Task 1): no attack-animation art authored for
		# this monster_id -- keep the original plain visibility toggle.
		_overlay_layers[slot].visible = attack_telegraphed
		return true

	match _overlay_states[slot]:
		OVERLAY_STATE_HIDDEN:
			if attack_telegraphed:
				_overlay_states[slot] = OVERLAY_STATE_PREPARE
				_overlay_elapsed[slot] = 0.0
				_overlay_layers[slot].visible = true
				_overlay_layers[slot].frame = prepare_clip.start_frame
		OVERLAY_STATE_PREPARE:
			if not attack_telegraphed:
				# Telegraph ended -- this is the strike moment. The ATTACK
				# state always plays to completion, uninterrupted, even if
				# attack_telegraphed flips true again before it finishes
				# (ruling: no gameplay signal distinguishes "attack landed"
				# from "prepare ended" today, so the strike's own visual
				# duration is authoritative).
				_overlay_states[slot] = OVERLAY_STATE_ATTACK
				_overlay_elapsed[slot] = 0.0
				_overlay_layers[slot].frame = attack_clip.start_frame
			else:
				_overlay_elapsed[slot] += delta
				var frames_elapsed: int = int(_overlay_elapsed[slot] * prepare_clip.fps)
				_overlay_layers[slot].frame = prepare_clip.start_frame + (frames_elapsed % prepare_clip.frame_count)
		OVERLAY_STATE_ATTACK:
			_overlay_elapsed[slot] += delta
			var duration: float = attack_clip.frame_count / attack_clip.fps
			# Epsilon guards against float accumulation error (e.g. 30 additions
			# of 1.0/60.0 lands at 0.49999999999999994, not exactly 0.5) --
			# without it, a caller ticking exactly N frames at the clip's own
			# frame rate can miss the boundary by one frame's worth of time.
			if _overlay_elapsed[slot] >= duration - 0.0001:
				_overlay_states[slot] = OVERLAY_STATE_HIDDEN
				_overlay_layers[slot].visible = false
			else:
				var frames_elapsed: int = int(_overlay_elapsed[slot] * attack_clip.fps)
				var clamped_offset: int = mini(frames_elapsed, attack_clip.frame_count - 1)
				_overlay_layers[slot].frame = attack_clip.start_frame + clamped_offset

	return true


## Frees a registered boss's slot, hiding both layers. Returns false for a
## stale/foreign handle.
func unregister_boss(handle: MonsterPresentationHandle) -> bool:
	var slot: int = _resolve_valid_slot(handle)
	if slot == -1:
		return false
	_slots[slot].visible = false
	_overlay_layers[slot].visible = false
	_overlay_states[slot] = OVERLAY_STATE_HIDDEN
	_overlay_elapsed[slot] = 0.0
	_entity_to_slot.erase(handle.entity_id)
	_free_slots.append(slot)
	return true


## Number of currently-registered bosses (0..CAPACITY).
func get_live_count() -> int:
	return CAPACITY - _free_slots.size()


func _resolve_valid_slot(handle: MonsterPresentationHandle) -> int:
	if handle == null or handle.batch_key != POOL_BATCH_KEY:
		return -1
	if not _entity_to_slot.has(handle.entity_id):
		return -1
	if (_entity_to_generation.get(handle.entity_id, -1) as int) != handle.generation:
		return -1
	return _entity_to_slot[handle.entity_id]

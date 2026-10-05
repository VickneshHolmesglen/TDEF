class_name AudioCueDispatcher
extends Node

## Data-driven one-shot cue dispatch — Story 003 (epic-12-audio-system).
##
## GDD source: design/gdd/audio-system.md — Core Rules 3-4, AC Group 3.
##
## Core Rule 4's own requirement: dispatch is generic — one lookup path keyed
## by event name, never a per-event `match` statement deciding what to play.
## The individual `.connect()` calls below are unavoidable signal *wiring*
## (GDScript signals aren't reflectively enumerable the way a real event-name
## string dispatch would be) — each one forwards into the single
## `dispatch_cue()` entry point, which is where all the actual per-event
## *behavior* difference is data (the `AudioCueMap` entry), not code.
##
## Real audio content is still nearly nonexistent (OQ-2, largely out of this
## epic's scope) — most cues have no `AudioCueEntry.stream` assigned, so most
## dispatches remain a routing/attenuation exercise only, matching this
## project's "mechanism real, content placeholder" convention (Diorama,
## Music/Ambient's own Story 002). **2026-08-28 (S9-03, audio content pilot)**:
## for the small number of entries that DO carry a real `stream` (currently
## Tower Mastery's 3 stingers — `assets/data/audio/audio_cue_map.tres`),
## playback is now genuinely real — see `_play_stream()` below. A cue with no
## `stream` still dispatches (routing/ducking/voice-limiting all still run
## against it, per this class's own tests) but produces no sound, which is
## the correct behavior for an unauthored cue, not a bug.
##
## World-space distance attenuation (Formula F2) needs a real distance value. The project has no
## scrolling/following camera (fixed top-down viewport showing the whole grid), so "camera focus
## point" is read as the Hero's position — the player's actual point of reference. `dispatch_cue()`
## accepts `distance` directly so Formula F2's own math is fully real and testable. The
## signal-driven wiring below computes a real cell-distance for the two cues whose source is away
## from the Hero (`tower_placed`, `tower_attacked`), tracked purely through existing EventBus
## signals — no new signal, no cross-scene node reference. `hero_damage_taken` and
## `hero_skill_activated` originate AT the Hero (the listener), so `distance = 0.0` for those two
## is not a placeholder — it's correct: a cue that happens at the listener's own position is
## always full volume under Formula F2's clamp.

const MAX_AUDIBLE_RADIUS: float = 15.0  ## Tuning Knobs default (Formula F2, R)

## Default content-authored cue map (S9-03) — loaded in `_ready()` if no
## `cue_map` was already injected (tests always inject their own fixtures via
## `set_cue_map()` immediately after `add_child()`, before emitting any real
## event, so this default is only ever observed in real gameplay).
const DEFAULT_CUE_MAP_PATH: String = "res://assets/data/audio/audio_cue_map.tres"

## Fixed-size pool of `AudioStreamPlayer`s, pre-allocated once — per this
## project's own zero-alloc-in-hot-paths convention (`.claude/rules/engine-code.md`),
## a one-shot cue must never spawn-then-free a node per dispatch. Sized to
## `combat_impact`'s own voice cap (`VoiceLimiter.DEFAULT_FAMILY_CAPS`, the
## largest family), the loosest realistic simultaneous-cue ceiling — beyond
## that, the oldest-still-playing player in the pool is stolen and restarted,
## mirroring `VoiceLimiter`'s own oldest-voice-steal policy (Core Rule 5) so
## a saturated pool degrades the same way a saturated family already does,
## rather than silently dropping the newest sound.
const PLAYER_POOL_SIZE: int = 12

## A pack of elites can wind up in the same frame; one warning per window keeps it from becoming a
## wall of sound (wind-up presentation spec §7).
const WINDUP_WARNING_MIN_GAP_MSEC: int = 250
var _last_windup_warning_msec: int = -WINDUP_WARNING_MIN_GAP_MSEC

## `tower_placement_blocked` can fire every frame while the cursor hovers a blocked cell; event-driven
## `ui_denied` is limited to one per window (UI audio cues spec §3). Button-press denials are not limited.
const DENIED_EVENT_MIN_GAP_MSEC: int = 300
var _last_denied_event_msec: int = -DENIED_EVENT_MIN_GAP_MSEC

## A tower volley can kill a whole cluster in one frame; one death cue per window keeps deaths from
## stealing every combat_impact voice from tower hits (2026-10-05 placeholder cue pass).
const MONSTER_DIED_MIN_GAP_MSEC: int = 70
var _last_monster_died_msec: int = -MONSTER_DIED_MIN_GAP_MSEC

## Sentinel for "no hero_position_changed observed yet this mission" — distinct from any real cell.
const UNKNOWN_CELL: Vector2i = Vector2i(-1, -1)
## Formula F2's "camera focus point": the Hero's last known grid cell, tracked via the existing
## hero_position_changed signal (no new signal, no cross-scene reference).
var _hero_cell: Vector2i = UNKNOWN_CELL
## tower_id -> grid_position, populated from tower_placed and erased on tower_removed — the same
## "cache from one event, read from another" pattern MonsterManager's own _entity_lookup uses.
var _tower_cells: Dictionary[int, Vector2i] = {}

var cue_map: AudioCueMap
var _lookup: Dictionary[StringName, AudioCueEntry] = {}

## Pre-allocated playback pool (see `PLAYER_POOL_SIZE`) — built once in
## `_ready()`, never resized at runtime.
var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0

## Story 004 (Ducking and Voice Limiting): registers a voice against its
## family's cap on every dispatch. Wiring this into the live dispatch path
## was deliberately deferred by Story 004's own Definition of Done (Story
## 003 owns triggering a cue; Story 004 only owns what happens once a
## family is at/beyond capacity) — this closes that documented follow-up.
var voice_limiter: VoiceLimiter = VoiceLimiter.new()

var _last_played_event: StringName = &""
var _last_played_bus: StringName = &""
var _last_effective_volume_linear: float = 0.0
var _dispatch_count: int = 0
var _last_dispatch_voice_id: int = -1

## Stored so `_exit_tree()` can actually disconnect the anonymous lambdas
## `_connect_all_events()` wires below — a bare `.connect(func...)` call has
## no reference to disconnect later, which would silently violate this
## project's own EventBus Rule 6 ("every subscriber MUST disconnect in
## `_exit_tree()`") the moment this node is ever created/freed outside the
## permanent Autoload tree (e.g. in a future test or refactor).
var _connected_signals: Array[Signal] = []
var _connected_callables: Array[Callable] = []


func _ready() -> void:
	if cue_map == null:
		cue_map = ResourceLoader.load(DEFAULT_CUE_MAP_PATH) as AudioCueMap
		if cue_map == null:
			push_error("AudioCueDispatcher: failed to load %s — falling back to an empty cue map." % DEFAULT_CUE_MAP_PATH)
			cue_map = AudioCueMap.new()
	_rebuild_lookup()
	_connect_all_events()
	_build_player_pool()
	_create_ui_binder()


## Auto-hooks every button in the tree for click/confirm/cancel/denial cues. `PROCESS_MODE_ALWAYS` so
## the binder keeps working for always-processing Pause Menu buttons while the tree is paused.
func _create_ui_binder() -> void:
	var existing: UiAudioBinder = get_node_or_null("UiAudioBinder") as UiAudioBinder
	if existing != null:
		# Re-entered dispatcher: make sure the surviving binder is live (setup is idempotent).
		existing.setup(dispatch_cue, get_tree())
		return
	var binder := UiAudioBinder.new()
	binder.name = "UiAudioBinder"
	binder.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(binder)
	binder.setup(dispatch_cue, get_tree())


func _build_player_pool() -> void:
	if not _players.is_empty():
		return
	for i in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "CuePlayer%d" % i
		add_child(player)
		_players.append(player)


## Ticks Formula F3's sidechain duck envelopes once per frame. Uses this
## project's default `PROCESS_MODE_INHERIT` — while `get_tree().paused` is
## true (`PauseMenu`'s own mechanism), this simply stops being called, which
## is exactly Core Rule 7's "freeze exactly where it is" requirement with no
## bespoke pause-handling needed here.
func _process(delta: float) -> void:
	voice_limiter.tick_sidechain(delta)


func _exit_tree() -> void:
	for i in range(_connected_signals.size()):
		if _connected_signals[i].is_connected(_connected_callables[i]):
			_connected_signals[i].disconnect(_connected_callables[i])
	_connected_signals.clear()
	_connected_callables.clear()


## Replaces the active cue map and rebuilds the runtime lookup — used by
## tests to inject fixtures without touching real content authoring.
func set_cue_map(map: AudioCueMap) -> void:
	cue_map = map
	_rebuild_lookup()


func _rebuild_lookup() -> void:
	_lookup.clear()
	for entry: AudioCueEntry in cue_map.entries:
		_lookup[entry.event_name] = entry


func _dispatch_windup_warning() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_windup_warning_msec < WINDUP_WARNING_MIN_GAP_MSEC:
		return
	_last_windup_warning_msec = now
	dispatch_cue(&"monster_windup_warning")


## Collapses a burst of monster deaths (individual or batched) into one death cue per window.
func _dispatch_monster_died() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_monster_died_msec < MONSTER_DIED_MIN_GAP_MSEC:
		return
	_last_monster_died_msec = now
	dispatch_cue(&"monster_died")


## Every attempt (first launch or a Retry) starts the spatial cache clean — a tower cell or Hero
## position cached from a previous attempt must never leak into the next one.
func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	_hero_cell = UNKNOWN_CELL
	_tower_cells.clear()


func _dispatch_denied_event() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_denied_event_msec < DENIED_EVENT_MIN_GAP_MSEC:
		return
	_last_denied_event_msec = now
	dispatch_cue(UiAudioBinder.CUE_DENIED)


## Dispatches a spatial cue whose source sits at `source_cell`, with the real distance to the
## Hero (Formula F2's "camera focus point" — see this file's header doc). `_hero_cell` is unknown
## (sentinel) before the first hero_position_changed of a mission; dispatching at distance 0 in
## that narrow window is the same "full volume" fallback this dispatcher already used everywhere
## before this change, not a new failure mode.
func _dispatch_spatial(event_name: StringName, source_cell: Vector2i) -> void:
	dispatch_cue(event_name, _hero_distance_to(source_cell))


## Formula F2 distance from `cell` to the Hero, or 0.0 before the first hero_position_changed of
## a mission — the same full-volume fallback this dispatcher always used before this gap closed.
func _hero_distance_to(cell: Vector2i) -> float:
	if _hero_cell == UNKNOWN_CELL:
		return 0.0
	return Vector2(cell - _hero_cell).length()


## Audio follow-up (per-element/per-skill variants): dispatches `variant_name` when an
## AudioCueEntry exists for it, otherwise the generic `fallback_name` every such event already
## has. Lets content give one specific skill or status effect a distinct sound with no code
## change — author the variant's cue entry under that exact name and it is picked up
## automatically on the next load. Placeholder variants exist for every shipped skill and Power
## effect_type (2026-10-05); anything unauthored still falls back to the shared generic cue.
func _dispatch_with_variant(variant_name: StringName, fallback_name: StringName, distance: float = 0.0) -> void:
	dispatch_cue(variant_name if variant_name != &"" and _lookup.has(variant_name) else fallback_name, distance)


func _connect_all_events() -> void:
	if not _connected_signals.is_empty():
		return
	# The generic mission_phase_changed stays deliberately unmapped (music owns phase changes);
	# only the per-phase variants that carry a sting (MISSION_COMPLETE, DEFEAT) make a sound.
	_wire(GEventBus.mission_phase_changed, func(_a: String, new_phase: String, _c: float) -> void:
			_dispatch_with_variant(StringName("mission_phase_changed_%s" % new_phase), &"mission_phase_changed"))
	_wire(GEventBus.wave_countdown_warning, func(_a: int) -> void: dispatch_cue(&"wave_countdown_warning"))
	_wire(GEventBus.hero_skill_activated, func(skill_id: String, _b: Vector2) -> void:
			_dispatch_with_variant(StringName("hero_skill_activated_%s" % skill_id), &"hero_skill_activated"))
	_wire(GEventBus.hero_class_unlocked, func(_a: StringName, _b: bool) -> void: dispatch_cue(&"hero_class_unlocked"))
	_wire(GEventBus.mission_launched, _on_mission_launched)
	_wire(GEventBus.hero_position_changed, func(cell: Vector2i) -> void: _hero_cell = cell)
	_wire(GEventBus.tower_placed, func(payload: TowerPlacedEvent) -> void:
			_tower_cells[payload.tower_id] = payload.grid_position
			_dispatch_spatial(&"tower_placed", payload.grid_position))
	_wire(GEventBus.tower_removed, func(tower_id: int, _b: Vector2i, _c: String, _d: String) -> void: _tower_cells.erase(tower_id))
	_wire(GEventBus.tower_destroyed, func(tower_id: int, grid_position: Vector2i, _c: String, _d: Array, _e: String) -> void:
			_tower_cells.erase(tower_id)
			_dispatch_spatial(&"tower_destroyed", grid_position))
	_wire(GEventBus.tower_attacked, func(tower_id: int, _b: int, _c: float, _d: bool, _e: bool, effect_type: String, _g: float, _h: float, _i: float, _j: bool) -> void:
			var distance: float = _hero_distance_to(_tower_cells.get(tower_id, _hero_cell))
			var variant: StringName = StringName("tower_attacked_%s" % effect_type) if not effect_type.is_empty() else &""
			_dispatch_with_variant(variant, &"tower_attacked", distance))
	_wire(GEventBus.pre_placement_perk_activated, func(_a: int, _b: String) -> void: dispatch_cue(&"pre_placement_perk_activated"))
	_wire(GEventBus.boss_died, func(_a: int, _b: StringName, _c: int, _d: String) -> void: dispatch_cue(&"boss_died"))
	_wire(GEventBus.hero_damage_taken, func(_a: int, _b: int) -> void: dispatch_cue(&"hero_damage_taken"))
	_wire(GEventBus.monster_hero_attack_winding_up, func(_a: int, _b: float) -> void: _dispatch_windup_warning())
	_wire(GEventBus.monster_hero_attack_resolved, func(_a: int, hit: bool) -> void:
			if not hit:
				dispatch_cue(&"monster_attack_whiff"))
	_wire(GEventBus.tower_placement_blocked, func(_cells: Array, _cell: Vector2i) -> void: _dispatch_denied_event())
	_wire(GEventBus.item_pickup_rejected, func(_a: String, _b: String, _c: int, _d: String) -> void: _dispatch_denied_event())
	_wire(GEventBus.hero_died, func() -> void: dispatch_cue(&"hero_died"))
	_wire(GEventBus.constellation_activated, func(_a: String, _b: Vector2i, _c: String, _d: float) -> void: dispatch_cue(&"constellation_activated"))
	_wire(GEventBus.component_crafted, func(_a: String, _b: String, _c: int) -> void: dispatch_cue(&"component_crafted"))
	_wire(GEventBus.component_repaired, func(_a: String, _b: String) -> void: dispatch_cue(&"component_repaired"))
	_wire(GEventBus.sanctuary_structure_built, func(_a: String, _b: String) -> void: dispatch_cue(&"sanctuary_structure_built"))
	_wire(GEventBus.hero_equipment_crafted, func(_a: String, _b: String, _c: int) -> void: dispatch_cue(&"hero_equipment_crafted"))
	# Story 004 (TR-buildupgrade-004, Rule 6a, AC-9): reuses this exact
	# generic-dispatch mechanism rather than adding chime logic inside
	# BuildingUpgrade.resolve_upgrade() -- Rule 6's "emits and does nothing
	# further" contract means the purchase-confirmation cue belongs entirely
	# to whoever already owns generic EventBus->audio dispatch, matching how
	# sanctuary_structure_built (the closest sibling, Defense Building's own
	# tech-node-unlock feedback) is wired the exact same way one line above.
	# AC-10a's own no-op-if-unmapped guarantee means this is safe to wire
	# even before a real "structure_upgraded" AudioCueMap entry is authored.
	_wire(GEventBus.structure_upgraded, func(_a: String, _b: String) -> void: dispatch_cue(&"structure_upgraded"))
	_wire(GEventBus.game_paused, func() -> void: dispatch_cue(&"game_paused"))
	_wire(GEventBus.game_unpaused, func() -> void: dispatch_cue(&"game_unpaused"))
	# Epic 06 Story 013 (tower-mastery.md Audio Requirement d): the
	# skill_unlocked chime half of this story's blocked "Audio stingers" item
	# -- reuses this exact mechanism (AC-10a's no-op-if-unmapped guarantee),
	# same precedent as structure_upgraded above.
	_wire(GEventBus.skill_unlocked, func(_a: String, _b: int) -> void: dispatch_cue(&"skill_unlocked"))
	# 2026-10-05 placeholder cue pass: events that had no cue at all. Each is a plain forward into
	# dispatch_cue(); the sound itself is data (assets/data/audio/cues/<event>.tres).
	_wire(GEventBus.wave_started, func(_a: int, _b: int, _c: float) -> void: dispatch_cue(&"wave_started"))
	_wire(GEventBus.wave_completed, func(_a: int, _b: int, _c: bool) -> void: dispatch_cue(&"wave_completed"))
	_wire(GEventBus.monster_died, func(_a: MonsterDiedEvent) -> void: _dispatch_monster_died())
	_wire(GEventBus.monsters_died_batch, func(_a: Array) -> void: _dispatch_monster_died())
	_wire(GEventBus.monster_breached, func(_a: int, _b: StringName, _c: int) -> void: dispatch_cue(&"monster_breached"))
	_wire(GEventBus.hero_ultimate_activated, func() -> void: dispatch_cue(&"hero_ultimate_activated"))
	_wire(GEventBus.hero_leveled_up, func(_a: int) -> void: dispatch_cue(&"hero_leveled_up"))
	_wire(GEventBus.tower_sell_requested, func(_a: int) -> void: dispatch_cue(&"tower_sell_requested"))
	_wire(GEventBus.recipe_discovered, func(_a: String, _b: String) -> void: dispatch_cue(&"recipe_discovered"))
	_wire(GEventBus.tarot_rune_discovered, func(_a: String, _b: String) -> void: dispatch_cue(&"tarot_rune_discovered"))
	_wire(GEventBus.constellation_rune_discovered, func(_a: String, _b: String) -> void: dispatch_cue(&"constellation_rune_discovered"))
	_wire(GEventBus.constellation_deactivated, func(_a: String, _b: String) -> void: dispatch_cue(&"constellation_deactivated"))
	_wire(GEventBus.creature_acquired, func(_a: int, _b: String) -> void: dispatch_cue(&"creature_acquired"))
	_wire(GEventBus.creature_bred, func(_a: int, _b: String) -> void: dispatch_cue(&"creature_bred"))
	_wire(GEventBus.creature_sacrificed, func(_a: int, _b: int) -> void: dispatch_cue(&"creature_sacrificed"))
	_wire(GEventBus.tech_unlocked, func(_a: String, _b: String) -> void: dispatch_cue(&"tech_unlocked"))
	_wire(GEventBus.item_rune_imbued, func(_a: String, _b: String, _c: String) -> void: dispatch_cue(&"item_rune_imbued"))
	_wire(GEventBus.tower_assembled, func(_a: String, _b: String) -> void: dispatch_cue(&"tower_assembled"))
	_wire(GEventBus.equipment_slot_changed, func(_a: String, _b: String, _c: String) -> void: dispatch_cue(&"equipment_slot_changed"))
	# The enter-range-tick/pause-descending-tone pair (2026-08-13): now
	# wireable since tower_mastery_proximity_changed's discrete edge-detection
	# signal exists (see event_bus.gd's own doc comment for why
	# mastery_progress_updated couldn't serve this role). Two distinct cue
	# names, matching the GDD's two distinct stingers -- entering plays a
	# short tick, exiting plays a descending tone, never the same sound.
	_wire(GEventBus.tower_mastery_proximity_changed, func(_a: String, in_range: bool) -> void:
			dispatch_cue(&"tower_mastery_proximity_entered" if in_range else &"tower_mastery_proximity_exited"))


func _wire(event_signal: Signal, callable: Callable) -> void:
	event_signal.connect(callable)
	_connected_signals.append(event_signal)
	_connected_callables.append(callable)


## The single generic dispatch entry point (Core Rule 4). `distance` only
## matters for cues marked `spatial == true` (Formula F2); ignored otherwise.
## AC-10a: an event with no matching map entry is a silent no-op — never an
## error. Cues with a `polyphony_group` also get Formula F1's concurrent-cue
## ducking applied, evaluated against the bus-wide voice count *after* this
## dispatch's own voice is registered (Formula F1's `N` is defined as
## "including this one"). Every dispatch also registers a Formula F3
## sidechain trigger against whichever cross-bus relationship its `bus`
## qualifies for (`&"SFX"` -> SFX_TO_AMBIENT, `&"UI"` -> UI_TO_MUSIC_AND_SFX)
## — the actual duck envelope is ticked separately, once per frame, by
## `_process()`.
func dispatch_cue(event_name: StringName, distance: float = 0.0) -> void:
	if not _lookup.has(event_name):
		return

	var entry: AudioCueEntry = _lookup[event_name]
	var base_volume: float = db_to_linear(entry.volume_db_offset)
	var effective_volume: float = base_volume
	if entry.spatial:
		effective_volume = base_volume * _world_space_attenuation(distance)

	_last_dispatch_voice_id = -1
	if entry.polyphony_group != &"":
		_last_dispatch_voice_id = voice_limiter.trigger_voice(entry.polyphony_group)
		var total_active_voices: int = voice_limiter.get_total_active_voice_count()
		effective_volume = VoiceLimiter.compute_ducked_volume(effective_volume, total_active_voices)

	if entry.bus == &"SFX":
		voice_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	elif entry.bus == &"UI" and not get_tree().paused:
		# While paused the duck envelope cannot advance (_process is frozen) and Music/SFX are already
		# ducked by the pause controller, so arming it would only dip the mix after resume.
		voice_limiter.trigger_sidechain(VoiceLimiter.UI_TO_MUSIC_AND_SFX)

	_last_played_event = event_name
	_last_played_bus = entry.bus
	_last_effective_volume_linear = effective_volume
	_dispatch_count += 1

	if entry.stream != null:
		_play_stream(entry, effective_volume)


## Plays `entry.stream` on a pooled `AudioStreamPlayer` — prefers the first
## currently-idle player (checked in round-robin cursor order, so repeated
## calls spread load evenly rather than always favoring `_players[0]`); if
## every player in the pool is already playing, takes the cursor's current
## player anyway rather than dropping the cue. Because the cursor always
## advances on every dispatch regardless of which branch ran, this
## approximates `VoiceLimiter`'s own oldest-voice-steal policy (Core Rule 5)
## without tracking exact per-voice start times — good enough for a pool this
## small, and consistent with "the newest trigger is never silently dropped."
## `effective_volume` is linear (already includes Formula F2 spatial
## attenuation and Formula F1 polyphony ducking, computed by the caller) —
## converted to dB here, the one place this class talks to `AudioStreamPlayer`
## directly.
func _play_stream(entry: AudioCueEntry, effective_volume: float) -> void:
	if _players.is_empty():
		return  # _build_player_pool() hasn't run yet (e.g. a test that never add_child()s this node) — dispatch_cue() still ran its real routing/ducking math above, only playback is skipped.

	var player: AudioStreamPlayer = _players[_next_player_index]
	var found_idle: bool = false
	for offset in range(_players.size()):
		var candidate_index: int = (_next_player_index + offset) % _players.size()
		if not _is_player_busy(_players[candidate_index]):
			player = _players[candidate_index]
			found_idle = true
			break
	if not found_idle and get_tree().paused:
		# While paused, INHERIT players are frozen mid-cue: stealing one would cut a gameplay cue that
		# resumes on unpause. Prefer an always-processing (UI) player; fall back to the cursor player
		# only if none exists.
		for offset in range(_players.size()):
			var candidate_index: int = (_next_player_index + offset) % _players.size()
			if _players[candidate_index].process_mode == Node.PROCESS_MODE_ALWAYS:
				player = _players[candidate_index]
				break
	_next_player_index = (_next_player_index + 1) % _players.size()

	# A pooled AudioStreamPlayer pauses with its node while the tree is paused, so UI-bus cues (Pause Menu
	# clicks, denials) need an always-processing player; gameplay cues still freeze with the tree (Core
	# Rule 7). Set per play because the pool is shared.
	player.process_mode = Node.PROCESS_MODE_ALWAYS if entry.bus == &"UI" else Node.PROCESS_MODE_INHERIT
	player.stream = entry.stream
	player.bus = entry.bus
	player.volume_db = linear_to_db(effective_volume)
	player.play()


## A player is busy while it plays or holds a live playback. `playing` alone reads false for an
## INHERIT player frozen mid-cue by a paused tree, so the live playback object is also checked.
func _is_player_busy(player: AudioStreamPlayer) -> bool:
	# has_stream_playback() (not get_stream_playback()) — the latter logs an engine error for a player
	# that has never called play().
	return player.playing or player.has_stream_playback()


## Formula F2 — World-Space Distance Attenuation (spatial cues only).
## `world_volume = base_volume * clamp(1 - distance / max_audible_radius, 0, 1)`
func _world_space_attenuation(distance: float) -> float:
	var clamped_distance: float = maxf(distance, 0.0)
	return clampf(1.0 - clamped_distance / MAX_AUDIBLE_RADIUS, 0.0, 1.0)


## Test/inspection accessor.
func get_last_played_event() -> StringName:
	return _last_played_event


## Test/inspection accessor.
func get_last_played_bus() -> StringName:
	return _last_played_bus


## Test/inspection accessor.
func get_last_effective_volume_linear() -> float:
	return _last_effective_volume_linear


## Test/inspection accessor (AC-10a) — total number of cues actually
## dispatched (map hits only; misses never increment this).
func get_dispatch_count() -> int:
	return _dispatch_count


## Test/inspection accessor (Story 004 wiring) — the voice ID
## `voice_limiter` assigned to the most recent dispatch, or -1 if that
## dispatch's entry had no `polyphony_group` (or was a lookup miss).
func get_last_dispatch_voice_id() -> int:
	return _last_dispatch_voice_id


## Test/inspection accessor (S9-03 playback pool) — number of pooled
## `AudioStreamPlayer`s the pool was actually built with (0 before `_ready()`
## has run, e.g. a dispatcher never `add_child()`-ed into a live tree).
func get_pool_size() -> int:
	return _players.size()


## Test/inspection accessor (S9-03 playback pool) — how many pooled players
## are currently mid-playback right now.
func get_active_player_count() -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _players:
		if player.playing:
			count += 1
	return count

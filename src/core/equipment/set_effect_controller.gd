class_name SetEffectController
extends Node

## Runs equipment-set capstone effects (equipment-set-effects spec §3.4).
## Lives as a child of Hero. Subscribes to existing EventBus signals only;
## emits none (ADR-0001 Rule 4). All buff durations and kill stacks are owned
## here; Hero only holds the resulting modifiers (Hero.set_effect_modifier).
## Every subscription is disconnected in _exit_tree() (ADR-0001 Rule 6).

var _hero: Hero = null

## Active effects by key (&"<set_id>:<threshold>").
var _active: Dictionary[StringName, Dictionary] = {}

## Remaining seconds for timed effects (wave/skill buffs, kill stacks).
var _timers: Dictionary[StringName, float] = {}

## Current stack count for on_kill_stack_buff effects.
var _stacks: Dictionary[StringName, int] = {}

## Last phase name seen on mission_phase_changed ("" until the first one).
var _current_phase: String = ""


func _ready() -> void:
	_hero = get_parent() as Hero
	if _hero == null:
		push_error("[SetEffectController] must be a direct child of Hero")
		return
	for pair: Array in _subscriptions():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if not sig.is_connected(handler):
			sig.connect(handler)
	set_process(false)
	_rebuild()


func _exit_tree() -> void:
	for pair: Array in _subscriptions():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)
	if _hero != null and is_instance_valid(_hero):
		_hero.clear_all_effect_modifiers()


## Every EventBus subscription this node holds, as [signal, handler] pairs.
## Connected in _ready(), disconnected in _exit_tree(); later tasks add rows.
func _subscriptions() -> Array:
	return [
		[GEventBus.equipment_slot_changed, _on_equipment_slot_changed],
		[GEventBus.item_rune_imbued, _on_item_rune_imbued],
		[GEventBus.wave_started, _on_wave_started],
		[GEventBus.hero_skill_activated, _on_hero_skill_activated],
		[GEventBus.hero_died, _on_hero_died],
		[GEventBus.mission_phase_changed, _on_mission_phase_changed],
		[GEventBus.monster_died, _on_monster_died],
		[GEventBus.monsters_died_batch, _on_monsters_died_batch],
	]


func _process(delta: float) -> void:
	for key: StringName in _timers.keys():
		var remaining: float = _timers[key] - delta
		if remaining <= 0.0:
			_expire(key)
		else:
			_timers[key] = remaining
	_update_processing()


# ---------------------------------------------------------------------------
# Rebuild
# ---------------------------------------------------------------------------

func _on_equipment_slot_changed(_slot: String, _new_item_id: String, _previous_item_id: String) -> void:
	_rebuild()


func _on_item_rune_imbued(_item_id: String, _rune_id: String, _rune_source: String) -> void:
	_rebuild()


func _rebuild() -> void:
	apply_effects(SetEffectResolver.active_effects(EquipmentBonuses.equipped_contents()))


## Replaces the active effect set. Effects no longer present are dropped
## (modifier, timer and stacks cleared at once); effects present before and
## after keep their timers and stacks. Also the test seam.
func apply_effects(effects: Array[Dictionary]) -> void:
	var next: Dictionary[StringName, Dictionary] = {}
	for effect: Dictionary in effects:
		next[effect[&"key"]] = effect
	for key: StringName in _active.keys():
		if not next.has(key):
			_drop_effect(key)
	for key: StringName in next:
		if not _active.has(key):
			_active[key] = next[key]
			if next[key][&"type"] == &"phase_state":
				_refresh_phase_state(key)
	_update_processing()


func _drop_effect(key: StringName) -> void:
	_active.erase(key)
	_timers.erase(key)
	_stacks.erase(key)
	_hero.clear_effect_modifier(key)


# ---------------------------------------------------------------------------
# Timed buffs: on_wave_start_buff / on_skill_cast_buff
# ---------------------------------------------------------------------------

func _on_wave_started(_wave_number: int, _total_waves: int, _difficulty: float) -> void:
	_grant_timed(&"on_wave_start_buff")


func _on_hero_skill_activated(_skill_id: String, _target_position: Vector2) -> void:
	_grant_timed(&"on_skill_cast_buff")


## Grants (or refreshes -- never stacks) every active effect of `type`.
func _grant_timed(type: StringName) -> void:
	for key: StringName in _active:
		var effect: Dictionary = _active[key]
		if effect[&"type"] != type:
			continue
		var params: Dictionary = effect[&"params"]
		_hero.set_effect_modifier(key, params[&"stats"])
		_timers[key] = float(params[&"duration"])
	_update_processing()


func _expire(key: StringName) -> void:
	_timers.erase(key)
	_stacks.erase(key)
	_hero.clear_effect_modifier(key)


func _on_hero_died() -> void:
	_clear_runtime()


# ---------------------------------------------------------------------------
# phase_state
# ---------------------------------------------------------------------------

func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	_current_phase = new_phase
	if new_phase == "MISSION_COMPLETE" or new_phase == "DEFEAT":
		_clear_runtime()
		return
	for key: StringName in _active:
		if _active[key][&"type"] == &"phase_state":
			_refresh_phase_state(key)


func _refresh_phase_state(key: StringName) -> void:
	var params: Dictionary = _active[key][&"params"]
	if (params[&"phases"] as Array).has(_current_phase):
		_hero.set_effect_modifier(key, params[&"stats"])
	else:
		_hero.clear_effect_modifier(key)


# ---------------------------------------------------------------------------
# on_kill_stack_buff
# ---------------------------------------------------------------------------

func _on_monster_died(payload: MonsterDiedEvent) -> void:
	if not _has_active(&"on_kill_stack_buff"):
		return
	_register_kills(1 if _hero.is_direct_kill(payload) else 0)


## ADR-0001 Rule 5: large waves arrive batched, so this must count each entry.
func _on_monsters_died_batch(payloads: Array[MonsterDiedEvent]) -> void:
	if not _has_active(&"on_kill_stack_buff"):
		return
	var qualifying: int = 0
	for payload: MonsterDiedEvent in payloads:
		if _hero.is_direct_kill(payload):
			qualifying += 1
	_register_kills(qualifying)


func _register_kills(count: int) -> void:
	if count <= 0:
		return
	for key: StringName in _active:
		var effect: Dictionary = _active[key]
		if effect[&"type"] != &"on_kill_stack_buff":
			continue
		var params: Dictionary = effect[&"params"]
		var stacks: int = mini(int(params[&"max_stacks"]), int(_stacks.get(key, 0)) + count)
		_stacks[key] = stacks
		_timers[key] = float(params[&"duration"])
		_hero.set_effect_modifier(key, _scaled(params[&"stats"], stacks))
	_update_processing()


func _has_active(type: StringName) -> bool:
	for key: StringName in _active:
		if _active[key][&"type"] == type:
			return true
	return false


static func _scaled(stats: Dictionary, factor: int) -> Dictionary:
	var out: Dictionary = {}
	for stat: Variant in stats:
		out[stat] = float(stats[stat]) * float(factor)
	return out


## Drops all timers, stacks and modifiers but keeps the active effect list.
func _clear_runtime() -> void:
	_timers.clear()
	_stacks.clear()
	_hero.clear_all_effect_modifiers()
	_update_processing()


func _update_processing() -> void:
	set_process(not _timers.is_empty())

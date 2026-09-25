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


## Drops all timers, stacks and modifiers but keeps the active effect list.
func _clear_runtime() -> void:
	_timers.clear()
	_stacks.clear()
	_hero.clear_all_effect_modifiers()
	_update_processing()


func _update_processing() -> void:
	set_process(not _timers.is_empty())

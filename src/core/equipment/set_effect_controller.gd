class_name SetEffectController
extends Node

## Runs equipment-set capstone effects (equipment-set-effects spec §3.4).
## Lives as a child of Hero. Subscribes to existing EventBus signals only;
## emits none (ADR-0001 Rule 4). All buff durations and kill stacks are owned
## here; Hero only holds the resulting modifiers (Hero.set_effect_modifier).
## Every subscription is disconnected in _exit_tree() (ADR-0001 Rule 6).

## The HUD finds this node through this group to read get_hud_entries().
const GROUP_NAME: StringName = &"set_effect_controller"

var _hero: Hero = null

## Active effects by key (&"<set_id>:<threshold>").
var _active: Dictionary[StringName, Dictionary] = {}

## Remaining seconds for timed effects (wave/skill buffs, kill stacks).
var _timers: Dictionary[StringName, float] = {}

## Current stack count for on_kill_stack_buff effects.
var _stacks: Dictionary[StringName, int] = {}

## Remaining seconds before an on_hurt_shield effect may grant again. Kept apart
## from _timers because a shield's duration and its cooldown run independently.
var _cooldowns: Dictionary[StringName, float] = {}

## Last phase name seen on mission_phase_changed ("" until the first one).
var _current_phase: String = ""

## Test seam. In production leave null: the controller finds MonsterManager
## through its group (MonsterManager.GROUP_NAME) because it is a scene child,
## not an autoload. Typed as Node so tests can inject a recording stub.
var monster_manager: Node = null


func _ready() -> void:
	_hero = get_parent() as Hero
	if _hero == null:
		push_error("[SetEffectController] must be a direct child of Hero")
		return
	add_to_group(GROUP_NAME)
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
		_hero.clear_all_shields()


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
		[GEventBus.hero_auto_attacked, _on_hero_auto_attacked],
		[GEventBus.hero_skill_attacked, _on_hero_skill_attacked],
		[GEventBus.hero_damage_taken, _on_hero_damage_taken],
		[GEventBus.hero_health_changed, _on_hero_health_changed],
	]


func _process(delta: float) -> void:
	for key: StringName in _timers.keys():
		var remaining: float = _timers[key] - delta
		if remaining <= 0.0:
			_expire(key)
		else:
			_timers[key] = remaining
	for key: StringName in _cooldowns.keys():
		var left: float = _cooldowns[key] - delta
		if left <= 0.0:
			_cooldowns.erase(key)
		else:
			_cooldowns[key] = left
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
			elif next[key][&"type"] == &"low_hp_state":
				_refresh_low_hp_state(key, _hero.get_current_hp(), _hero.get_max_hp())
	_update_processing()


func _drop_effect(key: StringName) -> void:
	_active.erase(key)
	_timers.erase(key)
	_stacks.erase(key)
	_cooldowns.erase(key)
	_hero.clear_effect_modifier(key)
	_hero.clear_shield(key)


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
	_hero.clear_shield(key)


## Death drops timed buffs and kill stacks, but a phase_state effect whose phase
## is still current must stay applied, so re-evaluate those against `_current_phase`.
func _on_hero_died() -> void:
	_clear_runtime()
	for key: StringName in _active:
		if _active[key][&"type"] == &"phase_state":
			_refresh_phase_state(key)


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
	if not _has_active(&"on_kill_stack_buff") and not _has_active(&"on_kill_heal"):
		return
	_register_kills(1 if _hero.is_direct_kill(payload) else 0)


## ADR-0001 Rule 5: large waves arrive batched, so this must count each entry.
func _on_monsters_died_batch(payloads: Array[MonsterDiedEvent]) -> void:
	if not _has_active(&"on_kill_stack_buff") and not _has_active(&"on_kill_heal"):
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
		if effect[&"type"] == &"on_kill_heal":
			var heal: int = roundi(float(effect[&"params"][&"heal_fraction"]) * _hero.get_effective_stat(&"max_hp"))
			for i: int in count:
				_hero.apply_heal(heal)
			continue
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


## Drops all timers, stacks, cooldowns, shields and modifiers but keeps the active effect list.
func _clear_runtime() -> void:
	_timers.clear()
	_stacks.clear()
	_cooldowns.clear()
	_hero.clear_all_effect_modifiers()
	_hero.clear_all_shields()
	_update_processing()


func _update_processing() -> void:
	set_process(not _timers.is_empty() or not _cooldowns.is_empty())


# ---------------------------------------------------------------------------
# on_crit_status
# ---------------------------------------------------------------------------

## Keys off the crit flag on the emitted event, i.e. before Damage & Status
## rolls evasion (spec §11: an evaded crit can still proc).
func _on_hero_auto_attacked(payload: HeroAutoAttackEvent) -> void:
	if payload.is_crit:
		_apply_crit_status(payload.target_id)


func _on_hero_skill_attacked(payload: HeroSkillAttackEvent) -> void:
	if payload.is_crit:
		_apply_crit_status(payload.target_id)


func _apply_crit_status(target_id: int) -> void:
	if not _has_active(&"on_crit_status"):
		return
	var manager: Node = _resolve_monster_manager()
	if manager == null or not manager.has_method(&"apply_dot"):
		return
	for key: StringName in _active:
		var effect: Dictionary = _active[key]
		if effect[&"type"] != &"on_crit_status":
			continue
		var params: Dictionary = effect[&"params"]
		manager.apply_dot(target_id, String(params[&"effect_type"]),
				float(params[&"effect_value"]), float(params[&"effect_duration"]))


func _resolve_monster_manager() -> Node:
	if monster_manager != null and is_instance_valid(monster_manager):
		return monster_manager
	return get_tree().get_first_node_in_group(MonsterManager.GROUP_NAME)


# ---------------------------------------------------------------------------
# on_hurt_shield (set defensive effects spec §3.4)
# ---------------------------------------------------------------------------

## This node is a child of Hero, so its _ready() connects before Hero's own and
## this handler runs before Hero applies the hit. Granting synchronously would let
## the new shield soak the very hit that triggered it, so the grant is deferred.
func _on_hero_damage_taken(amount: int, _source_type: int) -> void:
	if amount <= 0 or not _has_active(&"on_hurt_shield"):
		return
	for key: StringName in _active:
		if _active[key][&"type"] == &"on_hurt_shield" and not _cooldowns.has(key):
			# Claim the cooldown now so a second hit in the same frame cannot double-grant.
			_cooldowns[key] = float(_active[key][&"params"][&"cooldown"])
			_grant_shield.call_deferred(key)
	_update_processing()


func _grant_shield(key: StringName) -> void:
	if not _active.has(key) or _hero == null or not is_instance_valid(_hero):
		return
	var params: Dictionary = _active[key][&"params"]
	_hero.set_shield(key, roundi(float(params[&"shield_fraction"]) * _hero.get_effective_stat(&"max_hp")))
	_timers[key] = float(params[&"duration"])
	_update_processing()


# ---------------------------------------------------------------------------
# low_hp_state (set defensive effects spec §3.4)
# ---------------------------------------------------------------------------

func _on_hero_health_changed(current_health: float, max_health: float) -> void:
	for key: StringName in _active:
		if _active[key][&"type"] == &"low_hp_state":
			_refresh_low_hp_state(key, current_health, max_health)


## Active while 0 < hp / max_hp <= hp_fraction (a dead Hero never shows it).
func _refresh_low_hp_state(key: StringName, current_health: float, max_health: float) -> void:
	var params: Dictionary = _active[key][&"params"]
	if max_health > 0.0 and current_health > 0.0 and current_health / max_health <= float(params[&"hp_fraction"]):
		_hero.set_effect_modifier(key, params[&"stats"])
	else:
		_hero.clear_effect_modifier(key)


# ---------------------------------------------------------------------------
# HUD read model (set-effect HUD indicator, 2026-10-06)
# ---------------------------------------------------------------------------

## What is visibly "on" right now, for the Mission HUD's effect list. Read-only;
## the HUD polls it, so the controller still emits no EventBus signals. One entry
## per live effect: {name, kind, remaining, stacks, amount}. kind is "shield",
## "stacks", "timed" or "state"; remaining is seconds (-1 for untimed states).
## Passive procs (on_crit_status, on_kill_heal) have nothing to show between
## procs and are omitted.
func get_hud_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _hero == null or not is_instance_valid(_hero):
		return out
	for key: StringName in _active:
		var effect: Dictionary = _active[key]
		var entry: Dictionary = {&"name": String(effect[&"name"]), &"remaining": float(_timers.get(key, -1.0)),
			&"stacks": 0, &"amount": 0}
		match StringName(effect[&"type"]):
			&"on_hurt_shield":
				entry[&"amount"] = _hero.get_shield(key)
				if int(entry[&"amount"]) <= 0:
					continue
				entry[&"kind"] = "shield"
			&"on_kill_stack_buff":
				entry[&"stacks"] = int(_stacks.get(key, 0))
				if int(entry[&"stacks"]) <= 0:
					continue
				entry[&"kind"] = "stacks"
			&"on_wave_start_buff", &"on_skill_cast_buff":
				if not _timers.has(key):
					continue
				entry[&"kind"] = "timed"
			&"phase_state", &"low_hp_state":
				if not _hero.has_effect_modifier(key):
					continue
				entry[&"kind"] = "state"
			_:
				continue
		out.append(entry)
	return out

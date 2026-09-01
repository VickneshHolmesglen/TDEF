class_name TowerSystem
extends Node

## Scene-instanced Tower System. NOT an Autoload.
##
## Control manifest rule: Autoloads must not own per-mission state.
## TowerSystem owns _current_phase, _placed_towers, _monster_cache —
## all per-mission state — so it is scene-instanced (same pattern as MonsterManager).
##
## Gold balance is NOT owned here — GMissionEconomy (Autoload, ADR-0018) is the
## sole owner. Gate 2 reads it live via GMissionEconomy.can_afford(); place_tower()/
## sell_tower() emit signed resources_changed deltas (never absolute balances) —
## TowerSystem does not subscribe to resources_changed.
##
## ADR-0008: 4-gate placement, duplicate_deep() component isolation at commit,
##   get_placement_preview() runs Gates 1–3 only (never Gate 4).
## Amendment 2026-07-19 (implementation catch-up): _tower_table now holds
##   TowerBlueprintData (4-component-composed) instead of the flat TowerData;
##   duplicate_deep() is genuinely called at placement commit now, not deferred.

enum Phase { UNKNOWN, SCOUT, INTERMISSION, WAVE_ACTIVE, MISSION_COMPLETE, DEFEAT }

## 2026-08-17 (Tower Components mission-end surplus grant): ResourceEconomy
## (an Autoload, with no existing reference to the scene-instanced
## TowerSystem) discovers the one real per-mission instance via this group at
## MISSION_COMPLETE, matching the discovery pattern crafting.gd/
## tower_assembly.gd already use for the reverse direction (a scene-instanced
## system finding another shell-owned instance).
const GROUP_NAME: StringName = &"tower_system"

## Formula 1c (design/gdd/tower.md) — splash damage fraction at the outer edge
## of a BALLISTIC weapon's aoe_radius_cells. 1.0 at distance 0 (the primary
## target, handled separately) linearly interpolates down to this value at
## distance == aoe_radius_cells.
const MIN_SPLASH_FALLOFF: float = 0.40

## TD-tower-008 fix — Support/AURA buff duration. A Support tower's pulse
## refreshes every allied TowerMissionState.damage_buff_remaining in its
## radius to this many seconds; _tick_combat() decays it toward 0 every
## frame. Deliberately NOT "reapply forever until a pulse stops reaching
## you" (that would need no timer, but would also mean a buffed tower that
## walks out of every Support tower's radius mid-wave keeps its bonus
## forever with nothing to ever clear it -- there's no monster_died-style
## terminal event for "this tower stopped being in range"). A flat buffer
## comfortably longer than any authored Support weapon's own attack
## interval (Rally Banner: attack_speed=1.0 -> 1.0s between pulses) means a
## tower still in range never visibly flickers the buff off between pulses,
## while one that leaves range fades out within one duration window instead
## of holding the bonus indefinitely.
const AURA_BUFF_DURATION: float = 2.0

## TD-tower-008 fix — safety clamp on aura_effect_value applied at
## consumption time, not authoring time (WeaponComponent.validate() leaves
## this field's upper bound unbounded on purpose -- tower.md's own schema
## table says "Upper bound is effect-type-dependent; D&S System owns the
## valid range per effect_id" -- this constant is that owned range for the
## one effect_id actually implemented so far, "damage_buff").
const MAX_DAMAGE_BUFF_FRACTION: float = 1.0

# ---------------------------------------------------------------------------
# Public state — readable by tests and other mission-scene systems
# ---------------------------------------------------------------------------

## Placed towers keyed by integer instance id (auto-increments from 1).
var placed_towers: Dictionary = {}  # int tower_id → TowerMissionState

## Blueprint lookup table. Populated from GGameDataRegistry in production
## (_ready(), S5-01) if empty at that point; tests inject directly into this
## table before add_child() triggers _ready(), which leaves it non-empty and
## therefore skips the production population step below.
var _tower_table: Dictionary = {}   # StringName blueprint_id → TowerBlueprintData

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _tower_id_counter: int = 0
var _current_phase: Phase = Phase.UNKNOWN

## Entity position/HP cache (TR-tower-003: no direct MonsterEntity refs).
## Keyed by entity_id: int → {cell: Vector2i, hp: float, is_armored: bool,
## archetype_tag: StringName, elemental_resistances: Dictionary}. The last 2
## keys added by Tower Stats System Phase 1 (player-requested 2026-08-16) —
## see _on_monster_spawned()'s own doc comment for the is_armored bugfix
## that came with them.
var _monster_cache: Dictionary = {}

## DI seams — untyped so RefCounted stubs work in unit tests.
var _grid = null
var _pathfinding = null

## ADR-0019 fix — child node, TowerSystem's own owned domain (not a
## cross-system reference). Test harnesses may inject a stub here before
## add_child() triggers _ready(), same DI pattern as _grid/_pathfinding.
var _projectile_manager: ProjectileManager = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group(GROUP_NAME)
	_grid = GGrid
	_pathfinding = GPathfindingSystem
	if _tower_table.is_empty():
		_tower_table = GGameDataRegistry.get_all_tower_blueprints()
	if _projectile_manager == null:
		_projectile_manager = ProjectileManager.new()
		_projectile_manager.name = "ProjectileManager"
	_projectile_manager._tower_system = self
	if not _projectile_manager.is_inside_tree():
		add_child(_projectile_manager)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.monster_cell_entered.connect(_on_monster_cell_entered)
	GEventBus.monster_died.connect(_on_monster_died)
	GEventBus.monster_breached.connect(_on_monster_breached)
	GEventBus.wave_started.connect(_on_wave_started)
	GEventBus.boss_tower_attack_attempted.connect(_on_boss_tower_attack_attempted)
	GEventBus.tower_sell_requested.connect(_on_tower_sell_requested)


func _exit_tree() -> void:
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.monster_cell_entered.disconnect(_on_monster_cell_entered)
	GEventBus.monster_died.disconnect(_on_monster_died)
	GEventBus.monster_breached.disconnect(_on_monster_breached)
	GEventBus.wave_started.disconnect(_on_wave_started)
	GEventBus.boss_tower_attack_attempted.disconnect(_on_boss_tower_attack_attempted)
	GEventBus.tower_sell_requested.disconnect(_on_tower_sell_requested)


## Combat tick. Called by engine each physics frame. Public for test injection.
func _tick_combat(delta: float) -> void:
	if _current_phase != Phase.WAVE_ACTIVE:
		return
	for id: int in placed_towers:
		var state: TowerMissionState = placed_towers[id] as TowerMissionState
		state.attack_timer_remaining -= delta
		if state.attack_timer_remaining <= 0.0:
			_try_attack(state)
			state.attack_timer_remaining += 1.0 / state.weapon.attack_speed
		if state.damage_buff_remaining > 0.0:
			state.damage_buff_remaining -= delta
			if state.damage_buff_remaining <= 0.0:
				state.damage_buff_remaining = 0.0
				state.damage_buff_fraction = 0.0


func _physics_process(delta: float) -> void:
	_tick_combat(delta)

# ---------------------------------------------------------------------------
# Placement gate (ADR-0008)
# ---------------------------------------------------------------------------

## Place a tower blueprint at top_left. Returns true on success.
##
## 4-gate sequence: Phase → Resource → Footprint → Path.
## Emits tower_placed (and pre_placement_perk_activated if SCOUT).
func place_tower(blueprint_id: StringName, top_left: Vector2i) -> bool:
	# Gate 1 — Phase
	if _current_phase == Phase.WAVE_ACTIVE:
		return false
	if not _tower_table.has(blueprint_id):
		push_error("[TowerSystem] Unknown blueprint_id '%s'" % blueprint_id)
		return false
	var data: TowerBlueprintData = _tower_table[blueprint_id] as TowerBlueprintData
	# Gate 2 — Resource
	if not GMissionEconomy.can_afford(data.placement_cost):
		return false
	# Gate 3 — Grid footprint
	if not _grid.is_footprint_placeable(top_left, data.foundation.footprint):
		return false
	# Gate 4 — Path integrity (NEVER skipped on commit)
	var cells: Array[Vector2i] = _get_footprint_cells(top_left, data.foundation.footprint)
	if _pathfinding.would_block_all_paths(cells):
		return false
	# Commit
	_tower_id_counter += 1
	var tower_id: int = _tower_id_counter
	var err: int = _grid.place_tower(tower_id, top_left, data.foundation.footprint)
	if err != OK:
		_tower_id_counter -= 1
		return false
	var state := TowerMissionState.new()
	state.tower_id = tower_id
	state.placement_cost = data.placement_cost
	# ADR-0008 Component Deep-Copy Policy: independent mission-instance copies,
	# isolated from the inventory-owned blueprint — mutations (e.g. `damaged`)
	# never write back to `data`.
	state.foundation = data.foundation.duplicate_deep()
	state.weapon = data.weapon.duplicate_deep()
	state.focus = data.focus.duplicate_deep()
	state.power = data.power.duplicate_deep()
	# Shaft/Top (new 2026-09-01): data.shaft/data.top are nullable on
	# TowerBlueprintData (pre-existing static blueprints predate this
	# feature) -- substitute a fresh, inert ShaftComponent.new()/
	# TopComponent.new() rather than crashing on .duplicate_deep() of a null
	# reference. TowerMissionState.shaft/top are documented as never-null
	# for exactly this reason.
	state.shaft = data.shaft.duplicate_deep() if data.shaft != null else ShaftComponent.new()
	state.top = data.top.duplicate_deep() if data.top != null else TopComponent.new()
	state.grid_position = top_left
	state.max_hp = state.foundation.hp_base * state.foundation.tier_multiplier
	state.current_hp = state.max_hp
	state.attack_timer_remaining = 0.0  # Fire on first combat frame
	placed_towers[tower_id] = state
	GEventBus.resources_changed.emit(-data.placement_cost, &"tower_placed")
	var placed_in_scout: bool = _current_phase == Phase.SCOUT
	var payload := TowerPlacedEvent.new()
	payload.tower_id = tower_id
	payload.grid_position = top_left
	payload.archetype = String(state.foundation.archetype)
	payload.footprint = state.foundation.footprint
	payload.placed_in_scout = placed_in_scout
	payload.constellation_eligibility_tag = state.power.constellation_eligibility_tag
	payload.foundation_component_id = state.foundation.component_id
	payload.weapon_component_id = state.weapon.component_id
	payload.focus_component_id = state.focus.component_id
	payload.power_component_id = state.power.component_id
	GEventBus.tower_placed.emit(payload)
	# Real bug fixed here (2026-08-13, found while implementing the
	# perk-badge VFX): this previously fired unconditionally for every
	# Scout-Phase placement, using the tower's ARCHETYPE as perk_type. Per
	# this file's own schema table ("pre_placement_perk: any perk type id,
	# or '' -- empty string = no perk") and Rule 12's own text ("A Foundation
	# component with pre_placement_perk = '' has no perk"), a tower with no
	# perk configured must not fire this event at all. No shipped blueprint
	# currently sets a non-empty pre_placement_perk, so this bug produced no
	# visibly wrong behavior yet -- it would have the moment content authors
	# added a real perk.
	if placed_in_scout and state.foundation.pre_placement_perk != "":
		_apply_pre_placement_perk(state)
		GEventBus.pre_placement_perk_activated.emit(tower_id, state.foundation.pre_placement_perk)
	return true


## TD-tower-004 fix — tower.md Rule 12/12a: applies the Foundation's
## pre_placement_perk to this tower's own already-duplicated (ADR-0008
## isolated, mission-instance-only) component copies, exactly once, at the
## moment of Scout-Phase placement. Mutating state.weapon/state.focus
## directly (rather than a separate multiplier field, unlike TD-tower-008's
## decaying aura buff) matches the GDD's own framing: "The perk enters an
## active/buffed state at placement and remains active for the tower's
## lifetime on that mission" -- a permanent, one-time, non-decaying change,
## so there's nothing to track or decay, only to apply once and forget.
## Silently no-ops if the tower's archetype isn't in the perk's
## archetype_restrictions -- a content-authoring contract, not a runtime
## error path (equip-time cross-component validation for SPEED_BOOST/
## AURA_EXTEND's "wasted benefit" warnings is intentionally NOT implemented
## here -- it needs Tower Assembly's cross-component view, not TowerSystem's
## single-instance one; flagged as still-open in TD-tower-004's own entry).
func _apply_pre_placement_perk(state: TowerMissionState) -> void:
	var registry: TowerPerkRegistry = GGameDataRegistry.get_perk_registry()
	if registry == null or not registry.entries.has(state.foundation.pre_placement_perk):
		return
	var entry: Dictionary = registry.entries[state.foundation.pre_placement_perk] as Dictionary
	var restrictions: Array = entry.get("archetype_restrictions", []) as Array
	if not restrictions.has(state.foundation.archetype.capitalize()):
		return
	var power: float = state.foundation.perk_power
	match state.foundation.pre_placement_perk:
		"DAMAGE_BOOST":
			state.weapon.weapon_damage *= (1.0 + power)
		"SPEED_BOOST":
			state.weapon.attack_speed = minf(4.0, state.weapon.attack_speed * (1.0 + power))
		"RANGE_BOOST":
			state.focus.attack_range_cells = mini(8, state.focus.attack_range_cells + roundi(power * 8.0))
		"AURA_EXTEND":
			state.weapon.aura_radius_cells = mini(6, state.weapon.aura_radius_cells + roundi(power * 6.0))


## Returns a preview result for hover display.
##
## Runs Gates 1–3 only. Gate 4 (path integrity) is NEVER called here — AC-8.
func get_placement_preview(blueprint_id: StringName, top_left: Vector2i) -> PlacementPreview:
	var preview := PlacementPreview.new()
	if not _tower_table.has(blueprint_id):
		preview.valid = false
		preview.reason = PlacementPreview.PlacementBlockReason.FOOTPRINT_BLOCKED
		return preview
	var data: TowerBlueprintData = _tower_table[blueprint_id] as TowerBlueprintData
	# Gate 1
	if _current_phase == Phase.WAVE_ACTIVE:
		preview.valid = false
		preview.reason = PlacementPreview.PlacementBlockReason.WAVE_ACTIVE
		return preview
	# Gate 2
	if not GMissionEconomy.can_afford(data.placement_cost):
		preview.valid = false
		preview.reason = PlacementPreview.PlacementBlockReason.INSUFFICIENT_RESOURCES
		return preview
	# Gate 3
	if not _grid.is_footprint_placeable(top_left, data.foundation.footprint):
		preview.valid = false
		preview.reason = PlacementPreview.PlacementBlockReason.FOOTPRINT_BLOCKED
		return preview
	# Gate 4 intentionally omitted
	preview.valid = true
	preview.reason = PlacementPreview.PlacementBlockReason.NONE
	return preview


## Sell a placed tower. Returns true on success.
##
## Refund = round(placement_cost × 0.4). Blocked during WAVE_ACTIVE (AC-21).
## Emits tower_removed (not tower_destroyed).
func sell_tower(tower_id: int) -> bool:
	if _current_phase == Phase.WAVE_ACTIVE:
		return false
	if not placed_towers.has(tower_id):
		push_error("[TowerSystem] sell_tower: unknown tower_id %d" % tower_id)
		return false
	var state: TowerMissionState = placed_towers[tower_id] as TowerMissionState
	var refund: int = roundi(state.placement_cost * 0.4)
	_grid.remove_tower(tower_id)
	placed_towers.erase(tower_id)
	GEventBus.resources_changed.emit(refund, &"tower_sold")
	GEventBus.tower_removed.emit(tower_id, state.grid_position,
			String(state.foundation.archetype), state.power.constellation_eligibility_tag)
	return true


## Mission-End Building Material Surplus Grant (2026-08-17, Tower Components,
## resource-economy.md Formula 6): pure read of the towers still standing
## right now, for ResourceEconomy to tally at MISSION_COMPLETE. Deliberately
## excludes anything already sold/destroyed (erased from placed_towers by
## sell_tower()/the tower_destroyed path) — a tower that didn't survive to
## the end of the mission has already cost its placement gold and its 4
## source components; granting surplus for it too would double-reward, per
## this same convention as every other Resource Economy grant (rewards
## outcomes survived, not actions taken).
func get_placed_tower_slot_tally() -> Array[TowerMissionState]:
	var snapshot: Array[TowerMissionState] = []
	for id: int in placed_towers:
		snapshot.append(placed_towers[id] as TowerMissionState)
	return snapshot

# ---------------------------------------------------------------------------
# Combat formulas (AC-9 to AC-17)
# ---------------------------------------------------------------------------

## DPS formula: (weapon_damage + Top's "damage"-type bonus, if any) ×
## attack_speed × tier_dps_multiplier.
## Amendment 2026-07-19: tier_dps_multiplier lives on FoundationComponent per
## tower.md's schema (not WeaponComponent), split accordingly.
## Amendment 2026-09-01: `top` defaults to null (treated as +0.0 bonus) so
## every pre-existing call site (tower_combat_test.gd) is unaffected.
func compute_dps(weapon: WeaponComponent, foundation: FoundationComponent, top: TopComponent = null) -> float:
	var top_damage_bonus: float = top.bonus_value if (top != null and top.bonus_type == "damage") else 0.0
	return (weapon.weapon_damage + top_damage_bonus) * weapon.attack_speed * foundation.tier_dps_multiplier


## True when enemy_cell is within the tower's effective range.
##
## Effective range = attack_range_cells + shaft's range_bonus_cells (new
## 2026-09-01), + 2 more if cone_half_angle ≤ 30°.
## Distance metric: Chebyshev (diagonals equal to cardinals).
## `shaft` defaults to null (treated as +0 bonus) so this stays callable
## exactly as before wherever a caller has no Shaft to pass (e.g. this
## project's existing test suite, tower_combat_test.gd).
func is_in_range(tower_cell: Vector2i, enemy_cell: Vector2i, focus: FocusComponent, shaft: ShaftComponent = null) -> bool:
	var chebyshev: int = max(
		abs(tower_cell.x - enemy_cell.x), abs(tower_cell.y - enemy_cell.y)
	)
	return chebyshev <= _get_effective_range(focus, shaft)


## Effective range after Shaft's range_bonus_cells and the cone bonus.
func _get_effective_range(focus: FocusComponent, shaft: ShaftComponent = null) -> int:
	var range_bonus: int = shaft.range_bonus_cells if shaft != null else 0
	if focus.cone_half_angle <= 30.0:
		return focus.attack_range_cells + range_bonus + 2
	return focus.attack_range_cells + range_bonus

# ---------------------------------------------------------------------------
# Attack resolution
# ---------------------------------------------------------------------------

## Tower Stats System Phase 1 (player-requested 2026-08-16): damage
## composition expanded from the old `weapon_damage × tier_dps_multiplier`
## to `base_damage × crit_mult × vs_tag_mult × boss_mult`, then reduced by
## the target's elemental resistance for weapon.element (see design/gdd/
## tower.md's new Damage Resolution Formula section). Crit and the status-
## effect proc chance are each an independent per-attack roll — a failed
## proc roll forwards effect_type as "" (Power effect not applied this hit),
## same convention as "no Power equipped at all."
func _try_attack(state: TowerMissionState) -> void:
	# tower.md Rule 5a / Support archetype state exceptions table: on
	# attack-timer expiry a Support/AURA tower transitions straight to
	# ATTACKING and emits tower_aura_pulse unconditionally -- no monster
	# target is found or required, and no tower_attacked/projectile path
	# runs at all. Previously this branch didn't exist, so AURA weapons fell
	# through to the standard targeting path below and (since Support towers
	# ship with no meaningful weapon_damage) silently dealt 0 DPS forever
	# (TD-tower-007).
	if state.weapon.projectile_type == "AURA":
		var pulse := TowerAuraPulseEvent.new()
		pulse.tower_id = state.tower_id
		pulse.aura_effect_type = state.weapon.aura_effect_type
		pulse.aura_effect_value = state.weapon.aura_effect_value
		pulse.aura_radius_cells = state.weapon.aura_radius_cells
		GEventBus.tower_aura_pulse.emit(pulse)
		_apply_aura_pulse(state)
		return
	var target_id: int = _find_target(state)
	if target_id == -1:
		return
	if not _monster_cache.has(target_id):
		return
	var entry: Dictionary = _monster_cache[target_id] as Dictionary
	var is_armored: bool = entry["is_armored"] as bool
	var is_siege: bool = state.foundation.tier == 4

	# Top's bonus_type (new 2026-09-01) additively amplifies exactly one of
	# Weapon's own base stats -- never more than one, per bonus_type's own
	# validate() (only one type is ever active on a given Top instance).
	# state.top is never null (place_tower() substitutes an inert
	# TopComponent.new() for legacy content -- see that call site's comment),
	# and bonus_type "" contributes 0.0 to every branch below by construction.
	var top_damage_bonus: float = state.top.bonus_value if state.top.bonus_type == "damage" else 0.0
	var top_crit_chance_bonus: float = state.top.bonus_value if state.top.bonus_type == "crit_chance" else 0.0
	var top_crit_damage_bonus: float = state.top.bonus_value if state.top.bonus_type == "crit_damage" else 0.0

	var base_damage: float = (state.weapon.weapon_damage + top_damage_bonus) * state.foundation.tier_dps_multiplier
	var is_crit: bool = randf() < (state.weapon.crit_chance + top_crit_chance_bonus)
	var crit_mult: float = (state.weapon.crit_multiplier + top_crit_damage_bonus) if is_crit else 1.0
	var vs_tag_mult: float = _resolve_vs_tag_multiplier(state.foundation, entry)
	var boss_mult: float = state.foundation.tier_boss_dps_multiplier if entry.get("is_boss", false) else 1.0
	var aura_mult: float = 1.0 + state.damage_buff_fraction  # TD-tower-008 fix
	var damage: float = base_damage * crit_mult * vs_tag_mult * boss_mult * aura_mult
	var resistance: float = _resolve_element_resistance(state.weapon.element, entry)
	damage *= 1.0 - resistance

	var effect_type: String = state.power.effect_type
	var effect_value: float = state.power.effect_value
	var effect_duration: float = state.power.effect_duration
	if effect_type != "" and randf() >= state.weapon.status_proc_chance:
		effect_type = ""  # proc roll failed — no status effect on this hit

	# ADR-0019 fix (2026-08-24): tower_projectile_fired always fires now, at
	# this instant (fire time) -- drives the tower's own recoil/punch
	# animation and spawns the cosmetic ProjectileVisual, decoupled from
	# when tower_attacked fires (see event_bus.gd's doc comments on both
	# signals for why this split exists).
	GEventBus.tower_projectile_fired.emit.call_deferred(state.tower_id, target_id, is_armored)

	if state.weapon.projectile_type == "HOMING" or state.weapon.projectile_type == "BALLISTIC":
		# Pooled, flight-time-delayed path: tower_attacked fires later, on
		# arrival (on_projectile_arrived()), not here. Splash also moves to
		# arrival -- see on_projectile_arrived()'s own doc comment.
		var payload: Dictionary = {
			"damage": damage,
			"is_siege": is_siege,
			"effect_type": effect_type,
			"effect_value": effect_value,
			"effect_duration": effect_duration,
			"armor_penetration": state.weapon.armor_penetration,
			"is_crit": is_crit,
			"aoe_radius_cells": state.weapon.aoe_radius_cells,
		}
		var origin_world: Vector2 = _grid.cell_to_world(state.grid_position)
		var target_world: Vector2 = _grid.cell_to_world(entry["cell"] as Vector2i)
		var fired: bool = _projectile_manager.fire(state.tower_id, StringName(state.weapon.projectile_type),
				origin_world, target_id, target_world, payload)
		if not fired:
			return  # pool exhausted -- shot silently dropped, per ADR-0019's graceful-degradation contract
		return

	# BEAM (the only remaining projectile_type here) — unchanged: immediate,
	# no pool involvement, no flight delay.
	GEventBus.tower_attacked.emit.call_deferred(state.tower_id, target_id, damage, is_siege, is_armored,
			effect_type, effect_value, effect_duration, state.weapon.armor_penetration, is_crit)


## Formula 1c (design/gdd/tower.md) — every other monster within
## weapon.aoe_radius_cells (Chebyshev) of the primary target's cell takes a
## falloff-scaled fraction of the primary's already-resolved damage. Crit/
## vs-tag/boss/resistance are NOT re-rolled per splash target — every hit
## monster shares the same resolved `damage` number, just scaled down by
## distance. Status effects deliberately do not splash (effect_type always
## forwarded as "" here) — see Formula 1c's own doc comment for why.
func _apply_splash_damage(state: TowerMissionState, primary_id: int, primary_cell: Vector2i,
		damage: float, is_siege: bool, is_crit: bool) -> void:
	var radius: int = state.weapon.aoe_radius_cells
	for entity_id: int in _monster_cache:
		if entity_id == primary_id:
			continue
		var entry: Dictionary = _monster_cache[entity_id] as Dictionary
		var cell: Vector2i = entry["cell"] as Vector2i
		var distance: int = maxi(absi(cell.x - primary_cell.x), absi(cell.y - primary_cell.y))
		if distance < 1 or distance > radius:
			continue
		var falloff_fraction: float = float(distance) / float(radius)
		var splash_multiplier: float = lerpf(1.0, MIN_SPLASH_FALLOFF, falloff_fraction)
		var splash_damage: float = damage * splash_multiplier
		var is_armored: bool = entry["is_armored"] as bool
		GEventBus.tower_attacked.emit.call_deferred(state.tower_id, entity_id, splash_damage, is_siege,
				is_armored, "", 0.0, 0.0, state.weapon.armor_penetration, is_crit)


## TD-tower-008 fix — the buff-application half of TD-tower-007's original
## gap: a Support tower's pulse refreshes damage_buff_fraction/
## damage_buff_remaining on every allied tower (including itself; no
## self-exclusion is specified anywhere and a Support tower buffing its own
## HP-only combat presence is harmless -- it never reaches _try_attack's
## damage path itself) within aura_radius_cells (Chebyshev, same distance
## metric as every other range check in this file). Only "damage_buff" is
## implemented -- any other aura_effect_type is a no-op here (tower.md's own
## schema says "D&S System owns the valid range per effect_id"; this is
## this system's owned range for the one effect_id any shipped content
## actually authors today, matching the project's established "unrecognized
## value = inert, not an error" convention for content-driven string enums).
func _apply_aura_pulse(source_state: TowerMissionState) -> void:
	if source_state.weapon.aura_effect_type != "damage_buff":
		return
	var fraction: float = clampf(source_state.weapon.aura_effect_value, 0.0, MAX_DAMAGE_BUFF_FRACTION)
	var radius: int = source_state.weapon.aura_radius_cells
	for id: int in placed_towers:
		var ally: TowerMissionState = placed_towers[id] as TowerMissionState
		var distance: int = maxi(
			absi(ally.grid_position.x - source_state.grid_position.x),
			absi(ally.grid_position.y - source_state.grid_position.y)
		)
		if distance > radius:
			continue
		ally.damage_buff_fraction = maxf(ally.damage_buff_fraction, fraction)
		ally.damage_buff_remaining = AURA_BUFF_DURATION


## Looks up foundation.bonus_damage_vs_tags against the target's cached
## archetype_tag. Returns 1.0 (no bonus) if the tag is absent or the
## dictionary has no entry for it — missing-key-means-no-bonus is the same
## backward-compatible convention MonsterResource.elemental_resistances uses.
func _resolve_vs_tag_multiplier(foundation: FoundationComponent, monster_cache_entry: Dictionary) -> float:
	var tag: StringName = monster_cache_entry.get("archetype_tag", &"") as StringName
	if tag == &"":
		return 1.0
	return foundation.bonus_damage_vs_tags.get(tag, 1.0) as float


## Looks up the target's cached elemental_resistances against the weapon's
## element. "" (physical) never resolves to anything but 0.0 resistance —
## no monster content authors a "" key in elemental_resistances (see that
## field's own doc comment).
func _resolve_element_resistance(element: String, monster_cache_entry: Dictionary) -> float:
	if element == "":
		return 0.0
	var resistances: Dictionary = monster_cache_entry.get("elemental_resistances", {}) as Dictionary
	return resistances.get(element, 0.0) as float


## Returns the entity_id of the lowest-HP monster in range, or -1 if none.
## Tiebreak (tower.md Rule 15): HP-primary modes skip straight to lowest
## entity_id on a tie (tiebreaker 2, "lowest current_hp," is redundant when
## HP is already the primary sort).
func _find_lowest_hp_target(state: TowerMissionState) -> int:
	var best_id: int = -1
	var best_hp: float = INF
	for entity_id: int in _candidates_in_range(state):
		var hp: float = (_monster_cache[entity_id] as Dictionary)["hp"] as float
		if hp < best_hp or (hp == best_hp and entity_id < best_id):
			best_hp = hp
			best_id = entity_id
	return best_id


## tower.md Rule 15 — HIGHEST_HP: same shape as _find_lowest_hp_target, HP
## comparison inverted. Same tiebreak rule (HP-primary modes skip straight
## to lowest entity_id).
func _find_highest_hp_target(state: TowerMissionState) -> int:
	var best_id: int = -1
	var best_hp: float = -INF
	for entity_id: int in _candidates_in_range(state):
		var hp: float = (_monster_cache[entity_id] as Dictionary)["hp"] as float
		if hp > best_hp or (hp == best_hp and entity_id < best_id):
			best_hp = hp
			best_id = entity_id
	return best_id


## tower.md Rule 15 — CLOSEST_TO_GOAL: highest path_step_index (furthest
## along path) wins. Also this system's default/fallback for any
## unrecognized targeting_mode ("default if no Focus"). Universal tiebreaker
## on a path_step_index tie: lowest current_hp, then lowest entity_id.
func _find_closest_to_goal_target(state: TowerMissionState) -> int:
	var best_id: int = -1
	var best_step: int = -1
	var best_hp: float = INF
	for entity_id: int in _candidates_in_range(state):
		var entry: Dictionary = _monster_cache[entity_id] as Dictionary
		var step: int = entry.get("path_step_index", 0) as int
		var hp: float = entry["hp"] as float
		var better: bool = step > best_step \
				or (step == best_step and hp < best_hp) \
				or (step == best_step and hp == best_hp and entity_id < best_id)
		if better:
			best_step = step
			best_hp = hp
			best_id = entity_id
	return best_id


## tower.md Rule 15 — SPAWN_ORDER: lowest entity_id among valid candidates.
## Fully deterministic on its own; entity_id is a total order, so no
## separate tiebreaker chain is needed (Rule 15's own wording).
func _find_spawn_order_target(state: TowerMissionState) -> int:
	var best_id: int = -1
	for entity_id: int in _candidates_in_range(state):
		if best_id == -1 or entity_id < best_id:
			best_id = entity_id
	return best_id


## tower.md Rule 15 — SCATTER: deterministic round-robin cycle through the
## candidate pool (sorted ascending by entity_id, same ordering as
## SPAWN_ORDER), advancing state.scatter_index by exactly 1 per firing
## cycle. Repeat-guard: if the naive pick would re-select
## last_scatter_target_id and 2+ candidates remain, picks the next
## candidate in the sorted list instead. A single remaining candidate is
## always re-targeted (no guard — no different target exists to skip to).
## Skips all tiebreakers (index-driven, not ranking-driven) per Rule 15.
func _find_scatter_target(state: TowerMissionState) -> int:
	var candidates: Array[int] = _candidates_in_range(state)
	if candidates.is_empty():
		return -1
	candidates.sort()
	var index: int = state.scatter_index % candidates.size()
	var picked: int = candidates[index]
	if picked == state.last_scatter_target_id and candidates.size() >= 2:
		index = (index + 1) % candidates.size()
		picked = candidates[index]
	state.scatter_index += 1
	state.last_scatter_target_id = picked
	return picked


## Candidate monsters within this tower's effective range/cone (Formula 2),
## shared by every targeting mode below.
func _candidates_in_range(state: TowerMissionState) -> Array[int]:
	var result: Array[int] = []
	for entity_id: int in _monster_cache:
		var cell: Vector2i = (_monster_cache[entity_id] as Dictionary)["cell"] as Vector2i
		if is_in_range(state.grid_position, cell, state.focus, state.shaft):
			result.append(entity_id)
	return result


## tower.md Rule 15 — dispatches to the tower's own Focus.targeting_mode.
## Also exposed as _get_best_target() below for HOMING re-acquisition
## (currently unused — see that method's own doc comment).
func _find_target(state: TowerMissionState) -> int:
	match state.focus.targeting_mode:
		"LOWEST_HP":
			return _find_lowest_hp_target(state)
		"HIGHEST_HP":
			return _find_highest_hp_target(state)
		"SPAWN_ORDER":
			return _find_spawn_order_target(state)
		"SCATTER":
			return _find_scatter_target(state)
		_:  # CLOSEST_TO_GOAL, and the documented default for any other/empty value
			return _find_closest_to_goal_target(state)


## tower.md Rule 19 (Re-acquisition architecture note): the system-level
## method a HOMING projectile is meant to call when its original target
## dies before impact, since _monster_cache is TowerSystem-owned state a
## per-projectile object can't hold. NOT YET WIRED to any real caller —
## HOMING re-acquisition-on-death itself does not exist anywhere in this
## project yet (ProjectileVisual's own doc comment explicitly defers it,
## tracked separately as TD-tower-005/TD-tower-006's own remediation notes
## do not claim to close it). This method exists so the dispatch surface
## Rule 19 requires is real and ready for whenever re-acquisition itself is
## built — it does not, on its own, make re-acquisition happen.
func _get_best_target(tower_id: int, targeting_mode: String) -> int:
	if not placed_towers.has(tower_id):
		return -1
	var state: TowerMissionState = placed_towers[tower_id] as TowerMissionState
	# Evaluate the requested mode directly rather than trusting state.focus.
	# targeting_mode to already equal it -- callers pass targeting_mode
	# explicitly per Rule 19's own signature, so honor what they asked for.
	var original_mode: String = state.focus.targeting_mode
	state.focus.targeting_mode = targeting_mode
	var result: int = _find_target(state)
	state.focus.targeting_mode = original_mode
	return result

# ---------------------------------------------------------------------------
# ProjectileManager-facing accessors (ADR-0019 fix, 2026-08-24)
# ---------------------------------------------------------------------------
#
# ProjectileManager is TowerSystem's own owned child (not a cross-system
# reference, per ADR-0019's Ownership section) -- these are the read-only
# accessors it needs into TowerSystem's private state (_monster_cache,
# _grid, placed_towers) rather than reaching into those fields directly,
# keeping the actual private state genuinely private to this file.

## Returns the monster's live world position if still cached, or null if it
## has died/breached since the projectile tracking it last checked. HOMING
## in-flight tracking reads this every frame for its currently-tracked target.
func get_cached_monster_world_position(entity_id: int) -> Variant:
	if not _monster_cache.has(entity_id):
		return null
	return _grid.cell_to_world((_monster_cache[entity_id] as Dictionary)["cell"] as Vector2i)


## HOMING re-acquisition (tower.md Rule 19): delegates to _get_best_target(),
## bounded by the firing tower's own range/cone via its own placed position
## and Focus component -- never a global search, matching Rule 19's own
## "the projectile does not extend its search area" edge case. Uses the
## tower's own configured targeting_mode (Rule 19 doesn't specify a
## different mode for re-acquisition than normal targeting).
func reacquire_target(tower_id: int) -> int:
	if not placed_towers.has(tower_id):
		return -1
	var state: TowerMissionState = placed_towers[tower_id] as TowerMissionState
	return _get_best_target(tower_id, state.focus.targeting_mode)


## Thin delegation to _grid.world_to_cell() -- ProjectileManager needs this
## once, at arrival, to resolve the cell splash damage should originate from.
func world_to_cell(world_position: Vector2) -> Vector2i:
	return _grid.world_to_cell(world_position)


## ADR-0019 fix — called by ProjectileManager exactly once per pooled
## projectile, at real flight arrival (never at fire time). Re-resolves
## is_armored fresh from _monster_cache rather than trusting fire-time data,
## which could be up to base_flight_time_sec stale by now. damage/effect_
## type/effect_value/effect_duration/armor_penetration/is_crit were already
## resolved at fire time (tower.md: the logical arrival event only changes
## WHEN tower_attacked fires, never how the damage number itself was
## computed) and travel through unchanged in damage_payload.
##
## If target_entity_id is no longer cached (died/breached during flight and,
## for HOMING, ProjectileManager's own re-acquisition already exhausted its
## options before reaching here), this is the "target position empty on
## arrival" case tower.md's Requirements describe: no primary tower_attacked
## fires, but an AoE-tagged BALLISTIC weapon still detonates against the
## empty arrival cell (passing primary_id=-1, an id no real entity can ever
## match, to _apply_splash_damage() so nothing gets excluded from the blast).
func on_projectile_arrived(tower_id: int, target_entity_id: int, arrival_cell: Vector2i,
		damage_payload: Dictionary) -> void:
	if not placed_towers.has(tower_id):
		return  # tower sold/destroyed mid-flight
	var state: TowerMissionState = placed_towers[tower_id] as TowerMissionState
	var damage: float = damage_payload["damage"] as float
	var is_siege: bool = damage_payload["is_siege"] as bool
	var effect_type: String = damage_payload["effect_type"] as String
	var effect_value: float = damage_payload["effect_value"] as float
	var effect_duration: float = damage_payload["effect_duration"] as float
	var armor_penetration: float = damage_payload["armor_penetration"] as float
	var is_crit: bool = damage_payload["is_crit"] as bool
	var aoe_radius_cells: int = damage_payload["aoe_radius_cells"] as int
	# design/gdd/tower.md line 80 / Formula 1c: "aoe_radius_cells: BALLISTIC
	# only." Live-caught 2026-08-26 (gdUnit4 full regression sweep,
	# test_splash_disabled_for_non_ballistic_weapon): this method previously
	# gated splash on aoe_radius_cells > 0 alone, with no projectile_type
	# check at all — a real regression introduced when ADR-0019 moved splash
	# resolution from fire-time (where a type gate presumably existed) to
	# this arrival-time method (where it did not). WeaponComponent.validate()
	# also does not enforce this pairing (only range-checks aoe_radius_cells
	# itself), so nothing anywhere defended against a HOMING weapon with
	# aoe_radius_cells > 0 actually splashing.
	var splash_eligible: bool = aoe_radius_cells > 0 and state.weapon.projectile_type == "BALLISTIC"

	if _monster_cache.has(target_entity_id):
		var entry: Dictionary = _monster_cache[target_entity_id] as Dictionary
		var is_armored: bool = entry["is_armored"] as bool
		GEventBus.tower_attacked.emit.call_deferred(tower_id, target_entity_id, damage, is_siege, is_armored,
				effect_type, effect_value, effect_duration, armor_penetration, is_crit)
		if splash_eligible:
			_apply_splash_damage(state, target_entity_id, entry["cell"] as Vector2i, damage, is_siege, is_crit)
	elif splash_eligible:
		_apply_splash_damage(state, -1, arrival_cell, damage, is_siege, is_crit)

# ---------------------------------------------------------------------------
# Boss damage receiver
# ---------------------------------------------------------------------------

func _on_boss_tower_attack_attempted(_boss_entity_id: int, target_tower_id: int,
		base_damage: float, _wave_id: int) -> void:
	if not placed_towers.has(target_tower_id):
		return
	var state: TowerMissionState = placed_towers[target_tower_id] as TowerMissionState
	state.current_hp -= base_damage
	state.damaged = true
	if state.current_hp <= 0.0:
		state.current_hp = 0.0
		_grid.remove_tower(target_tower_id)
		placed_towers.erase(target_tower_id)
		var cells: Array[Vector2i] = _get_footprint_cells(state.grid_position, state.foundation.footprint)
		GEventBus.tower_destroyed.emit(target_tower_id, state.grid_position,
				String(state.foundation.archetype), cells, state.power.constellation_eligibility_tag)
	else:
		GEventBus.tower_damaged.emit(target_tower_id, base_damage,
				state.current_hp, state.max_hp)

# ---------------------------------------------------------------------------
# Monster cache (TR-tower-003: no direct MonsterEntity refs)
# ---------------------------------------------------------------------------

## Synchronous subscription (Tower GDD Rule 14a: must receive before tower_attacked).
##
## Real pre-existing bugs found and fixed here (Tower Stats System Phase 1,
## player-requested 2026-08-16): this used to hardcode "is_armored": false
## unconditionally — MonsterSpawnedEvent's payload never carried archetype/
## tag info (ADR-0001 Rule 3 caps event payloads at 5 fields; this one only
## has entity_id/monster_id/wave_index/grid_position/hp_max), so the
## armored-monster 50% damage mitigation in damage_status.gd has never
## actually fired in real gameplay — every monster was silently treated as
## unarmored regardless of its real archetype_tag. Separately,
## FoundationComponent.tier_boss_dps_multiplier (validated to 2.0 at tower
## tier 4, documented in tower.md's own DPS-ceiling formula as "the boss
## variant") was never actually multiplied into any damage computation
## anywhere in this file — dead data, same bug class as is_armored. Both
## fixed by looking up the real MonsterResource via the payload's
## monster_id (the same GameDataRegistry-lookup-by-id pattern used
## everywhere else in this codebase for resolving static content), which
## also gives elemental_resistances a real source now.
func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	var resource: MonsterResource = GGameDataRegistry.get_monster_resource(payload.monster_id)
	var is_armored: bool = resource != null and resource.archetype_tag == &"armored"
	var elemental_resistances: Dictionary = resource.elemental_resistances if resource != null else {}
	_monster_cache[payload.entity_id] = {
		"cell": payload.grid_position,
		"hp": payload.hp_max,
		"is_armored": is_armored,
		"archetype_tag": resource.archetype_tag if resource != null else &"",
		"elemental_resistances": elemental_resistances,
		"is_boss": resource != null and resource.tier == 2,
		"path_step_index": 0,
	}


## tower.md Rule 14a: also used by CLOSEST_TO_GOAL/SPAWN_ORDER targeting and
## the universal tiebreaker chain (Rule 15) — path_step_index is the
## authoritative "how far along the path" signal for those.
func _on_monster_cell_entered(entity_id: int, grid_cell: Vector2i, path_step_index: int) -> void:
	if _monster_cache.has(entity_id):
		var entry: Dictionary = _monster_cache[entity_id] as Dictionary
		entry["cell"] = grid_cell
		entry["path_step_index"] = path_step_index


func _on_monster_died(payload: MonsterDiedEvent) -> void:
	_monster_cache.erase(payload.entity_id)


## tower.md Edge Cases (Targeting): monster_died is not fired for monsters
## that breach the GOAL (exited the grid) — without this subscription,
## SPAWN_ORDER and other targeting modes could reference an entity no
## longer on the grid until wave_completed eventually clears the cache.
func _on_monster_breached(entity_id: int, _monster_id: StringName, _tier: int) -> void:
	_monster_cache.erase(entity_id)


## tower.md Rule 15 (SCATTER): scatter_index/last_scatter_target_id reset to
## defaults at the start of every wave, for every currently-placed tower.
func _on_wave_started(_wave_number: int, _total_waves: int, _wave_difficulty: float) -> void:
	for id: int in placed_towers:
		var state: TowerMissionState = placed_towers[id] as TowerMissionState
		state.scatter_index = 0
		state.last_scatter_target_id = -1

# ---------------------------------------------------------------------------
# Phase and resource tracking
# ---------------------------------------------------------------------------

func _on_mission_phase_changed(_previous_phase: String, new_phase: String,
		_timestamp: float) -> void:
	match new_phase:
		"SCOUT":            _current_phase = Phase.SCOUT
		"INTERMISSION":     _current_phase = Phase.INTERMISSION
		"WAVE_ACTIVE":      _current_phase = Phase.WAVE_ACTIVE
		"MISSION_COMPLETE": _current_phase = Phase.MISSION_COMPLETE
		"DEFEAT":           _current_phase = Phase.DEFEAT
		_:                  _current_phase = Phase.UNKNOWN


func _on_tower_sell_requested(tower_id: int) -> void:
	sell_tower(tower_id)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_footprint_cells(top_left: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for col: int in range(size.x):
		for row: int in range(size.y):
			cells.append(top_left + Vector2i(col, row))
	return cells

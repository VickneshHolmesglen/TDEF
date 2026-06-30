class_name EventBus
extends Node

## Central pub/sub dispatcher for all cross-system communication.
##
## ADR-0001 (Accepted 2026-05-15): Framework-First Event-Driven Communication.
## ADR-0002: Boot position 1 — must be the FIRST Autoload in Project Settings.
## GDD source: design/gdd/event-bus.md — 70-event catalogue.
##
## Rules (from ADR-0001):
##   Rule 1 — Synchronous dispatch is the default.
##   Rule 2 — Physics callers and Level-1 cascade emitters use deferred dispatch.
##             Use call_deferred for end-of-frame; await get_tree().process_frame
##             for guaranteed next-frame delivery.
##   Rule 3 — 1–4 field events: typed parameters. 5+ field events: Resource subclass.
##   Rule 4 — Cascade depth cap: maximum 2 levels.
##   Rule 5 — Batch at >= 20 firings/frame (Wave Manager owns monster_died accumulator).
##   Rule 6 — Every subscriber MUST disconnect in _exit_tree() — not optional.
##   Rule 7 — EventBus is first Autoload; connect in _ready(), never in _init().
##   Rule 8 — EventBus owns no game state. Pure dispatcher only.
##   Rule 9 — Only cross-system events belong here. Internal events must not be added.
##
## Dispatch patterns:
##   Synchronous (non-physics):
##     EventBus.wave_started.emit(wave_number, total_waves, difficulty)
##
##   Deferred end-of-frame (physics callers, Level-1 cascade emitters):
##     EventBus.monster_damage_taken.emit.call_deferred(payload)
##
##   Deferred next-frame (when pass-1 drain must complete first — see ADR-0007):
##     await get_tree().process_frame
##     EventBus.monster_damage_taken.emit(payload)
##
##   Subscribe (in _ready()):
##     EventBus.monster_died.connect(_on_monster_died)
##
##   Disconnect (in _exit_tree() — MANDATORY):
##     EventBus.monster_died.disconnect(_on_monster_died)
##
## Performance budget (Formula 1, event-bus.md):
##   Total EventBus processing per frame: <= 1.667 ms (10% of 16.67 ms @ 60 FPS)
##   Per-event type budget (8 concurrent): ~0.208 ms
##   Batch threshold: > 20 firings/frame
##   Max cascade depth: 2 levels

# =============================================================================
# Wave Manager
# =============================================================================

## Any SCOUT / WAVE_ACTIVE / INTERMISSION / MISSION_COMPLETE / DEFEAT transition.
## Key subscribers: all mission-active systems, Save & Persistence, Audio.
signal mission_phase_changed(previous_phase: String, new_phase: String, timestamp: float)

## Wave timer expires and first monster spawns.
## Key subscribers: Monster, Hero, Tower, Mission HUD.
signal wave_started(wave_number: int, total_waves: int, wave_difficulty: float)

## All wave enemies are dead or boss is killed.
## Key subscribers: Monster, Resource Economy, Mission HUD.
signal wave_completed(wave_number: int, enemies_remaining: int)

## 10 seconds before wave launch.
## Key subscribers: Mission HUD, Audio.
signal wave_countdown_warning(seconds_remaining: int)

## Every second during Scout Phase and Intermission.
## Key subscribers: Mission HUD.
signal phase_timer_tick(phase: String, seconds_remaining: float)

## Per spawn entry during WAVE_ACTIVE, after each pre_delay elapses. Resource payload (5 fields).
## wave_reward_scalar is consumed by Resource Economy only — Monster System must not apply to stats.
## Key subscribers: Monster System.
signal monster_spawn_requested(payload: MonsterSpawnRequest)

## Immediately on INTERMISSION entry (non-final wave). Delivers upcoming wave composition.
## Key subscribers: Mission HUD.
signal wave_preview_available(next_wave_number: int, composition: Array)

## 30s after _all_spawns_fired if _enemies_alive > 0. Precedes 60s force-clear watchdog.
## Key subscribers: Mission HUD.
signal wave_stalled(wave_number: int, enemies_remaining: int)

## Emitted by Mission HUD when player presses Ready button. Wave Manager gates SCOUT/INTERMISSION.
## Wave Manager ignores this event outside SCOUT and INTERMISSION (Rules 9 and 12).
signal player_ready()

# =============================================================================
# Hero System
# =============================================================================

## Hero's auto-attack animation resolves. Resource payload (6 fields).
## Hero System pre-computes crit and reads target tier before emitting.
## Key subscribers: Damage & Status (pipeline trigger).
signal hero_auto_attacked(payload: HeroAutoAttackEvent)

## Any HP change (damage or healing).
## Key subscribers: Mission HUD.
signal hero_health_changed(current_health: float, max_health: float)

## Hero HP reaches 0.
## Key subscribers: Wave Manager (trigger DEFEAT).
signal hero_died()

## Hero moves to a new grid cell.
## Key subscribers: Tower Mastery (proximity tracking).
signal hero_position_changed(grid_position: Vector2i)

## Equipment slot updated at Sanctuary.
## Key subscribers: Damage & Status, Mission HUD.
signal hero_equipment_changed(slot: String, item_id: String)

## Player activates an active skill.
## Key subscribers: Damage & Status, Audio, Mission HUD.
signal hero_skill_activated(skill_id: String, target_position: Vector2)

## Emitted by Hero System each second while a skill slot is on cooldown.
## Key subscribers: Mission HUD (skill button fill-drain display).
signal hero_skill_cooldown_updated(skill_slot: int, cooldown_remaining: float, cooldown_max: float)

## Emitted by Mission HUD when player presses the Ultimate button.
## Key subscribers: Hero System (effect resolution + cooldown start).
signal hero_ultimate_activated()

## Hero accumulates enough proximity time to unlock a new class identity.
## Key subscribers: Tower Mastery, Mission HUD, Audio.
signal hero_class_unlocked(class_id: String)

# =============================================================================
# Tower System
# =============================================================================

## Tower placed during SCOUT or INTERMISSION only. WAVE_ACTIVE placement is blocked.
## Key subscribers: Constellation, Hero, Pathfinding (dirty-check + deferred rebuild),
##   Mission HUD, Audio.
## placed_in_scout: true only for SCOUT placements.
signal tower_placed(
	tower_id: int,
	grid_position: Vector2i,
	archetype: String,
	footprint: Vector2i,
	placed_in_scout: bool
)

## Tower voluntarily removed during SCOUT or INTERMISSION.
## Key subscribers: Constellation, Hero (Tower Affinity recalc),
##   Pathfinding (dirty-check + deferred rebuild), Mission HUD.
signal tower_removed(tower_id: int, grid_position: Vector2i, archetype: String)

## Tower HP reaches 0 mid-wave.
## Key subscribers: Constellation, Grid, Inventory (component recovery), Mission HUD,
##   Pathfinding (sets _tower_destroyed_during_wave = true for auto-rebuild at INTERMISSION).
signal tower_destroyed(
	tower_id: int,
	grid_position: Vector2i,
	archetype: String,
	footprint: Array
)

## Boss attack reduces tower HP and tower survives. Primary HP observable.
## Key subscribers: Mission HUD (tower HP bar update).
signal tower_damaged(tower_id: int, damage_dealt: float, current_hp: float, max_hp: float)

## Emitted by Mission HUD when player presses Sell in SCOUT or INTERMISSION.
## Tower System must guard against this arriving outside valid phases.
signal tower_sell_requested(tower_id: int)

## Component swapped in a tower slot.
## Key subscribers: Constellation, Mission HUD.
signal tower_component_equipped(tower_id: int, slot: String, component_id: String)

## Tower fires at a monster.
## is_siege: derived from originating tower's Foundation.siege flag (true for T4 only).
## is_armored: pre-resolved by Tower System from target's MonsterResource.archetype_tag
##   (true when archetype_tag == &"armored"); D&S applies 50% tower damage mitigation.
## Key subscribers: Damage & Status, Monster System, Audio.
signal tower_attacked(
	tower_id: int,
	target_monster_id: int,
	damage_amount: float,
	is_siege: bool,
	is_armored: bool
)

## Support archetype tower's attack timer expires. Emitted unconditionally (no target needed).
## Resource payload (4 fields — promoted to Resource for future extensibility).
## D&S derives tower position from tower_id via Grid read; anchor_cell is not included.
## Key subscribers: Damage & Status (apply effect in radius), Mission HUD.
signal tower_aura_pulse(payload: TowerAuraPulseEvent)

## Immediately on Scout Phase tower placement confirmation (before any wave begins).
## Key subscribers: Mission HUD, Audio.
signal pre_placement_perk_activated(tower_id: int, perk_type: String)

## Once per active tower on wave_completed (after HP reset). Resource payload (7 fields).
## Key subscribers: Mission HUD ("Endless Theorist" feedback display).
signal tower_wave_summary(payload: TowerWaveSummary)

# =============================================================================
# Monster System
# =============================================================================

## Monster enters the field. Resource payload (5 fields).
## hp_max seeds Tower System's HP-tracking cache. Tower System must subscribe Synchronous.
## Key subscribers: Pathfinding, Wave Manager, Mission HUD, Tower System.
signal monster_spawned(payload: MonsterSpawnedEvent)

## Monster HP reaches 0 or wave_completed force-removal. Resource payload (8 fields).
## At > 20 firings/frame: Wave Manager batch accumulator emits monsters_died_batch instead.
## Key subscribers: Resource Economy, Wave Manager, Constellation, Mission HUD.
signal monster_died(payload: MonsterDiedEvent)

## Batch variant of monster_died — fires when >= 20 monsters die in one frame.
## Wave Manager owns the accumulator. EventBus remains a pure dispatcher.
## Key subscribers: Resource Economy, Wave Manager, Constellation, Mission HUD.
signal monsters_died_batch(payloads: Array[MonsterDiedEvent])

## Monster exits the GOAL cell boundary without being killed.
## tier == 2 triggers wave-clear in Wave Manager.
## Key subscribers: Wave Manager, Mission HUD.
signal monster_breached(entity_id: int, monster_id: StringName, tier: int)

## BOSS HP reaches 0, or BOSS breaches, or BOSS force-removed at wave_completed.
## cause values: "killed" / "breached" / "force_removed".
## Key subscribers: Wave Manager (wave-clear), Mission HUD, Audio.
signal boss_died(entity_id: int, monster_id: StringName, wave_index: int, cause: String)

## Each time a BOSS receives monster_damage_taken and survives.
## Key subscribers: Mission HUD (BOSS HP bar).
signal boss_hp_changed(entity_id: int, current_hp: float, max_hp: float)

## BOSS attack cooldown reached 0 and a tower is within boss_attack_range_cells.
## wave_id used for staleness rejection by Tower System (Tower GDD Edge Cases).
## Key subscribers: Tower System (apply damage directly to tower HP, no mitigation, MVP).
signal boss_tower_attack_attempted(
	boss_entity_id: int,
	target_tower_id: int,
	base_damage: float,
	wave_id: int
)

## Monster moves from one grid cell to an adjacent cell along its path.
## Key subscribers: Tower System (update monster position cache for targeting).
signal monster_cell_entered(entity_id: int, grid_cell: Vector2i, path_step_index: int)

# =============================================================================
# Pathfinding System
# =============================================================================

## Tower placed/removed triggers deferred rebuild; also fires at INTERMISSION entry
## if BOSS destroyed a tower during preceding WAVE_ACTIVE.
## Key subscribers: Monster System (trigger path recalc), Wave Manager (secondary gate).
signal path_invalidated(affected_cells: Array)  ## Array[Vector2i], deduplicated union

## After all N route templates finish building at SCOUT start. Fires exactly once per SCOUT.
## Key subscribers: Wave Manager (gate — must not emit monster_spawn_requested until this fires).
signal templates_ready(spawn_count: int, build_duration_ms: float)

## Pathfinding emits when would_block_all_paths(footprint) returns true.
## primary_blocking_cell == Vector2i(-1, -1) means multi-cell interaction block.
## Key subscribers: Mission HUD (show blocked-placement indicator).
signal tower_placement_blocked(blocked_cells: Array, primary_blocking_cell: Vector2i)

# =============================================================================
# Damage & Status System
# =============================================================================

## Deferred one frame after tower_attacked or hero_auto_attacked. NEVER synchronous.
## Resource payload (5 fields). See ADR-0007 for canonical deferred dispatch pattern.
## Key subscribers: Monster System (apply HP reduction), Mission HUD.
signal monster_damage_taken(payload: MonsterDamageTaken)

## Frame N+2 from triggering hero_auto_attacked. Fires only when heal_amount > 0.
## Cascade exemption: synchronous emission at depth 1 from monster_hp_absorbed (depth 0).
## Hero System must NOT re-emit from its hero_healed handler.
## Key subscribers: Hero System (apply HP gain and overheal clamp).
signal hero_healed(amount: int)

## Emitted by Monster System (deferred one frame from monster_damage_taken) after applying
## damage to target HP. absorbed = min(amount_received, pre_hit_hp). NOT emitted when
## Monster System discards monster_damage_taken for a dead entity.
## Key subscribers: Damage & Status (lifesteal resolution).
signal monster_hp_absorbed(entity_id: int, absorbed: int)

## Deferred one frame from hero_incoming_damage after D4 armor reduction applied.
## MVP: no active attack sources exist — pipeline is scaffolding only.
## Key subscribers: Hero System, Mission HUD, Audio.
signal hero_damage_taken(amount: int, source_type: int)

## Emitted by any future source that inflicts damage on the hero.
## MVP: no sources exist. Payload TBD — defined by the future system's GDD.
## Key subscribers: Damage & Status.
signal hero_incoming_damage()

# =============================================================================
# Constellation System
# =============================================================================

## Valid geometric pattern fully placed.
## Key subscribers: Tower System, Mission HUD, Audio.
signal constellation_activated(
	pattern_id: String,
	grid_origin: Vector2i,
	bonus_type: String,
	bonus_value: float
)

## Pattern broken (tower destroyed or moved).
## Key subscribers: Tower System, Mission HUD.
signal constellation_deactivated(pattern_id: String, reason: String)

## First time a constellation pattern is completed in this playthrough.
## Key subscribers: Encyclopedia, Equipment Forge.
signal constellation_rune_discovered(rune_id: String, pattern_id: String)

# =============================================================================
# Tarot System
# =============================================================================

## At mission start (SCOUT phase). Modifiers resolve before Tarot rune effects.
## Key subscribers: Wave Manager, Monster System.
signal mission_modifier_applied(
	modifier_type: String,
	modifier_value: float,
	source_card_id: String
)

## First time a Tarot rune is unlocked in this playthrough.
## Key subscribers: Encyclopedia, Equipment Forge.
signal tarot_rune_discovered(rune_id: String, card_id: String)

## Player modifies deck at Sanctuary.
## Key subscribers: Save & Persistence, Tarot Deck UI.
signal tarot_deck_changed(active_card_count: int)

# =============================================================================
# Crafting System
# =============================================================================

## Crafting operation completes successfully.
## Key subscribers: Inventory, Mission HUD, Audio.
signal component_crafted(component_id: String, component_type: String, quality_tier: int)

## New recipe becomes available (tech unlock or first time materials available).
## Key subscribers: Encyclopedia, Crafting UI.
signal recipe_discovered(recipe_id: String, recipe_category: String)

# =============================================================================
# Menagerie System
# =============================================================================

## Creature happiness value updates.
## Key subscribers: Resource Economy, Mission HUD.
signal creature_happiness_changed(creature_id: String, new_happiness: float, quality_bonus: float)

## Breeding pen produces offspring.
## Key subscribers: Encyclopedia, Mission HUD.
signal creature_bred(offspring_id: String, species: String)

## Creature consumed in Equipment Forge operation.
## Key subscribers: Equipment Forge, Mission HUD.
signal creature_sacrificed(creature_id: String, target_item_id: String)

## Player moves creature out of habitat.
## Key subscribers: Resource Economy (reduce quality bonus).
signal creature_moved_to_breeding_pen(creature_id: String)

## Player returns creature to habitat.
## Key subscribers: Resource Economy (restore quality bonus).
signal creature_returned_from_breeding_pen(creature_id: String)

# =============================================================================
# Defense Building System
# =============================================================================

## Player unlocks a tech tree node.
## Key subscribers: Crafting (new recipes), Encyclopedia, Mission HUD.
signal tech_unlocked(tech_id: String, tech_category: String)

## New Sanctuary structure placed.
## Key subscribers: Mission HUD, Audio.
signal sanctuary_structure_built(structure_id: String, structure_type: String)

# =============================================================================
# Inventory System
# =============================================================================

## Item added to inventory.
## Key subscribers: Mission HUD, Crafting (recipe availability).
signal item_added(item_id: String, item_type: String, quantity: int)

## Item consumed or discarded.
## Key subscribers: Mission HUD, Crafting.
signal item_removed(item_id: String, item_type: String, quantity: int)

## Equipment change at Sanctuary.
## Key subscribers: Hero System (stat recalc), Damage & Status, Mission HUD.
signal equipment_slot_changed(slot: String, new_item_id: String, previous_item_id: String)

# =============================================================================
# Resource Economy System
# =============================================================================

## Drop resolved after monster_died or wave_completed.
## Key subscribers: Inventory, Mission HUD.
signal materials_earned(material_type: String, quantity: int, source: String)

## Crafting or Equipment Forge consumes materials.
## Key subscribers: Inventory, Mission HUD.
signal materials_spent(material_type: String, quantity: int, destination: String)

# =============================================================================
# Tower Mastery System
# =============================================================================

## Hero proximity timer increments for a tower.
## Key subscribers: Mission HUD.
signal mastery_progress_updated(tower_id: int, skill_id: String, progress_percent: float)

## Proximity threshold reached — skill added to learned library.
## Key subscribers: Hero Skill Build, Encyclopedia, Mission HUD.
signal skill_unlocked(skill_id: String, source_tower_id: int)

# =============================================================================
# Equipment Forge System
# =============================================================================

## Forge operation produces hero gear.
## Key subscribers: Inventory, Mission HUD, Audio.
signal hero_equipment_crafted(item_id: String, item_type: String, quality_tier: int)

## Rune imbued into hero equipment.
## Key subscribers: Hero System (stat update), Mission HUD.
signal item_rune_imbued(item_id: String, rune_id: String, rune_source: String)

# =============================================================================
# Hero Skill Build System
# =============================================================================

## Player assigns a skill to an active slot at Sanctuary.
## Key subscribers: Hero System, Mission HUD.
signal active_skill_equipped(slot_index: int, skill_id: String)

## Active skill combination resolves to a new Ultimate.
## Key subscribers: Hero System, Mission HUD.
signal ultimate_skill_changed(ultimate_id: String)

# =============================================================================
# Save & Persistence System
# =============================================================================

## Sanctuary state serialised to disk.
## Key subscribers: Mission HUD (show save indicator).
signal game_saved(save_slot: int, timestamp: float)

## Save file loaded (game start or post-defeat return).
## IMPORTANT: Save & Persistence must NOT emit this from its own _ready().
##   Must call_deferred so all subscribers have connected first (EC-10).
##   Sanctuary systems must also pull initial state directly on _ready() —
##   this event handles subsequent changes, not initial load.
## Key subscribers: All Sanctuary systems.
signal sanctuary_state_restored(save_slot: int)

# =============================================================================
# Mission Select System
# =============================================================================

## Player confirms a mission from the select screen.
## Key subscribers: Wave Manager (prepare parameters), Mission HUD.
signal mission_selected(mission_id: String)

## Player toggles a run modifier on/off.
## Key subscribers: Wave Manager, Tarot System.
signal run_modifier_selected(modifier_id: String, modifier_value: float)

## Player confirms launch with current modifiers.
## Key subscribers: Wave Manager, Save & Persistence (pre-mission checkpoint).
signal mission_launched(mission_id: String, modifiers: PackedStringArray)

# =============================================================================
# Encyclopedia System
# =============================================================================

## Any discovery event triggers an entry addition.
## Key subscribers: Mission HUD (discovery notification).
signal encyclopedia_entry_added(category: String, entry_id: String)

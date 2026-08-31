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
## was_boss_breached: true only when the wave-clear cause was a BOSS breach
## (Story 003 territory, epic-04-wave-manager) — every clear path this
## codebase currently implements (standard clear, watchdog force-clear)
## emits false (Story 002).
## Key subscribers: Monster, Resource Economy, Mission HUD.
signal wave_completed(wave_number: int, enemies_remaining: int, was_boss_breached: bool)

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

## Immediately on INTERMISSION entry (non-final wave), and once at SCOUT
## entry for wave 1. Delivers upcoming wave composition.
## boss_spawn_cell (Mission HUD ADR-0031, Story 006): Vector2i(-1,-1) if the
## previewed wave has no BOSS-tier entry, otherwise the cell that entry will
## resolve to when it actually spawns — closes tower.md's OQ-11 (boss-lane
## telegraph). Added when this signal's real shipped payload was found to be
## missing the field the GDD/tower.md had already assumed existed.
## Key subscribers: Mission HUD.
signal wave_preview_available(next_wave_number: int, composition: Array, boss_spawn_cell: Vector2i)

## 30s after _all_spawns_fired if _enemies_alive > 0. Precedes 60s force-clear watchdog.
## Key subscribers: Mission HUD.
signal wave_stalled(wave_number: int, enemies_remaining: int)

## Emitted by Mission HUD when player presses Ready button. Wave Manager gates SCOUT/INTERMISSION.
## Wave Manager ignores this event outside SCOUT and INTERMISSION (Rules 9 and 12).
signal player_ready()

# =============================================================================
# Pause System
# =============================================================================

## Player toggles pause on (ADR-0014). SceneTree.paused is the source of truth —
## this signal is informational only, for systems that react to a pause boundary
## without gating their own _process/_physics_process/Timer logic on it (that is
## handled natively by SceneTree.paused propagation). Fired by the Pause Menu.
## Key subscribers: none yet (future Audio ducking, analytics).
signal game_paused()

## Player toggles pause off (ADR-0014). See game_paused for the informational-only note.
## Key subscribers: none yet (future Audio ducking, analytics).
signal game_unpaused()

# =============================================================================
# Scene Manager
# =============================================================================

## Fires before SceneManager unloads the current scene during a SANCTUARY<->MISSION
## transition. target_context is "SANCTUARY" or "MISSION"; mission_id is "" for
## sanctuary transitions (ADR-0002).
## Key subscribers: Presentation-layer loading screens (future).
signal scene_transition_started(target_context: String, mission_id: String)

## Fires after the new scene's _ready() has run, following scene_transition_started.
## Key subscribers: Presentation-layer loading screens (future).
signal scene_transition_completed(target_context: String, mission_id: String)

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

## Player activates an active skill (a cast happened — not necessarily a hit).
## Key subscribers: Audio, Mission HUD. **Corrected 2026-08-25/26 (TD-hero-001)**:
## Damage & Status removed from subscribers — it was never a real consumer of
## this event. See hero_skill_attacked below for the actual damage-resolution
## event; design/gdd/damage-status.md Rule I.2 documents the distinction.
signal hero_skill_activated(skill_id: String, target_position: Vector2)

## A skill cast actually struck a specific target — distinct from
## hero_skill_activated ("a skill was cast"). One emission per target hit
## (Resource payload, 7 fields). Hero System pre-computes crit, target tier,
## and skill_power (already including tower_affinity_bonus) before emitting.
## Added 2026-08-25/26, closes TD-hero-001's Skill Power consumer gap.
## Key subscribers: Damage & Status (Rule IX / Formula D7 pipeline trigger).
signal hero_skill_attacked(payload: HeroSkillAttackEvent)

## Emitted by Hero System each second while a skill slot is on cooldown.
## Key subscribers: Mission HUD (skill button fill-drain display).
signal hero_skill_cooldown_updated(skill_slot: int, cooldown_remaining: float, cooldown_max: float)

## Emitted by Mission HUD when player presses the Ultimate button.
## Key subscribers: Hero System (effect resolution + cooldown start).
signal hero_ultimate_activated()

## Hero accumulates enough proximity time to unlock a new class identity.
## is_deep: false for the 30s primary-class unlock, true for the 90s deep-class unlock.
## Key subscribers: Tower Mastery, Mission HUD, Audio.
signal hero_class_unlocked(archetype: StringName, is_deep: bool)

# =============================================================================
# Tower System
# =============================================================================

## Tower placed during SCOUT or INTERMISSION only. WAVE_ACTIVE placement is blocked.
## Key subscribers: Constellation, Hero, Pathfinding (dirty-check + deferred rebuild),
##   Mission HUD, Audio, Planning Cluster (Build Panel placement-confirmation
##   pulse — added 2026-08-17, Art & Animation Pipeline Upgrade vertical slice).
## placed_in_scout: true only for SCOUT placements.
## constellation_eligibility_tag added 2026-07-18 (Sprint 6, S6-08): closes
## constellation.md OQ-4 — this field was already documented as "added
## 2026-07-17" in event-bus.md's own table and assumed live by ADR-0022, but
## the actual signal declaration here was never updated to match. Found while
## implementing Constellation Story 001 (Core Rule 2's eligibility check reads
## this field directly off the payload). Empty string means not
## constellation-eligible, mirrors TowerData's own field of the same name.
## Promoted to a TowerPlacedEvent Resource subclass 2026-07-19 (Sprint 7,
## Epic 06 Story 008): adds foundation/weapon/focus/power_component_id
## fields for Tower Mastery's build_signature derivation (Formula 4) — see
## event_payloads/tower_placed_event.gd.
signal tower_placed(payload: TowerPlacedEvent)

## Tower voluntarily removed during SCOUT or INTERMISSION.
## Key subscribers: Constellation, Hero (Tower Affinity recalc),
##   Pathfinding (dirty-check + deferred rebuild), Mission HUD.
## constellation_eligibility_tag added 2026-07-18 (Sprint 6, S6-08) — see tower_placed's note.
signal tower_removed(tower_id: int, grid_position: Vector2i, archetype: String, constellation_eligibility_tag: String)

## Tower HP reaches 0 mid-wave.
## Key subscribers: Constellation, Grid, Inventory (component recovery), Mission HUD,
##   Pathfinding (sets _tower_destroyed_during_wave = true for auto-rebuild at INTERMISSION).
## constellation_eligibility_tag added 2026-07-18 (Sprint 6, S6-08) — see tower_placed's note.
signal tower_destroyed(
	tower_id: int,
	grid_position: Vector2i,
	archetype: String,
	footprint: Array,
	constellation_eligibility_tag: String
)

## Boss attack reduces tower HP and tower survives. Primary HP observable.
## Key subscribers: Mission HUD (tower HP bar update), Mission Scene
## (TowerInstance.play_hit_flash() — added 2026-08-17, Art & Animation
## Pipeline Upgrade vertical slice; previously unsubscribed here entirely,
## so a damaged tower had zero sprite-level reaction).
signal tower_damaged(tower_id: int, damage_dealt: float, current_hp: float, max_hp: float)

## Emitted by Mission HUD when player presses Sell in SCOUT or INTERMISSION.
## Tower System must guard against this arriving outside valid phases.
signal tower_sell_requested(tower_id: int)

## Emitted by Mission HUD's Tower Build Panel when the player selects a
## buyable tower entry — the mission scene (owner of the real TowerSystem
## reference) tracks this as the pending placement selection and uses it
## instead of a hardcoded blueprint_id on the next grid click.
## Key subscribers: mission_scene.gd / the_gap.gd.
signal tower_blueprint_selected(blueprint_id: StringName)

## Emitted by the mission scene on every grid-hover mouse motion while a
## blueprint is selected (SCOUT/INTERMISSION only) — carries TowerSystem's
## own get_placement_preview() result so Mission HUD's Planning Cluster can
## render a footprint ghost without holding a direct TowerSystem reference
## (mirrors tower_placement_blocked's identical decoupling).
## Key subscribers: Mission HUD (Planning Cluster placement cursor).
signal tower_placement_preview_updated(cell: Vector2i, footprint: Vector2i, valid: bool)

## Component swapped in a tower slot.
## Key subscribers: Constellation, Mission HUD, Tower Mastery.
## Promoted to a TowerComponentEquippedEvent Resource subclass 2026-07-19
## (Sprint 7, Epic 06 Story 008) — carries the tower's complete resulting
## loadout (all 4 slots), not just the changed slot. No real emitter exists
## yet (Equipment Forge, Epic 08, not implemented) — see
## event_payloads/tower_component_equipped_event.gd.
signal tower_component_equipped(payload: TowerComponentEquippedEvent)

## Tower fires at a monster.
## is_siege: derived from originating tower's Foundation.siege flag (true for T4 only).
## is_armored: pre-resolved by Tower System from target's MonsterResource.archetype_tag
##   (true when archetype_tag == &"armored"); D&S applies 50% tower damage mitigation,
##   reduced further by armor_penetration below (Tower Stats System Phase 1).
## damage_amount: as of Phase 1, already includes crit/vs-tag/boss multipliers AND the
##   target's elemental-resistance reduction for the firing weapon's element -- element
##   itself never crosses this signal, since TowerSystem resolves resistance upstream via
##   its own monster cache (keeps Damage & Status a pure math node with no registry
##   dependency). armor_penetration is the only new damage-modifier field carried here,
##   because armored-mitigation is D&S's own job, not TowerSystem's.
## effect_type/effect_value/effect_duration: the firing tower's own PowerComponent
##   fields. effect_type can now be "" for TWO distinct reasons (Phase 1) -- no Power
##   equipped at all, OR a status_proc_chance roll failed this hit -- subscribers that
##   care about the distinction cannot infer it from this signal alone. Added
##   2026-08-13 so Monster System's status-tick pass (see damage-status.md Rule I.3's
##   exception note) can apply burn/poison without a direct query into TowerSystem's
##   placed_towers state.
## armor_penetration: (Tower Stats System Phase 1, 2026-08-16) the firing weapon's
##   WeaponComponent.armor_penetration, [0.0, 1.0] -- D&S uses this to reduce the
##   armored-mitigation multiplier above.
## is_crit: (Phase 1) whether this hit rolled a critical hit -- damage_amount already
##   has crit_multiplier applied; this is carried separately for VFX/audio/HUD hooks.
## ADR-0019 (Projectile Pooling Strategy) fix, 2026-08-24: fires at the
## moment a weapon actually discharges -- BEFORE any HOMING/BALLISTIC flight
## delay -- carrying only what fire-time-appropriate cosmetic reactions need
## (the tower's own recoil/punch animation, the flying projectile sprite).
## Decoupled from tower_attacked (below) specifically so a pooled projectile's
## real flight time no longer also delays the tower's firing animation, which
## must play the instant the shot leaves the tower, not when it lands.
## Fires for every non-AURA weapon type (BEAM included, even though BEAM's
## tower_attacked still fires at the same instant -- keeps one consistent
## "shot fired" signal regardless of projectile_type, rather than only
## emitting it for the two delayed types).
## Key subscribers: Mission Scene (tower punch/targeting animation, spawns
## the cosmetic ProjectileVisual).
signal tower_projectile_fired(tower_id: int, target_monster_id: int, is_armored: bool)

## Key subscribers: Damage & Status, Monster System (direct-hit AND status-tick
## subscriptions), Audio, Mission Scene
## (2026-08-13 — spawns a purely cosmetic projectile visual, does not gate damage).
## ADR-0019 fix, 2026-08-24: for HOMING/BALLISTIC weapons this now fires at
## real projectile ARRIVAL (after ProjectileManager's flight-time delay), not
## at fire time -- damage/status/audio/armored-spark timing all shift to
## match logical impact. BEAM/AURA-adjacent instant weapons are unchanged
## (still fire immediately). See tower_projectile_fired above for the
## fire-time-only cosmetic signal this split introduces.
signal tower_attacked(
	tower_id: int,
	target_monster_id: int,
	damage_amount: float,
	is_siege: bool,
	is_armored: bool,
	effect_type: String,
	effect_value: float,
	effect_duration: float,
	armor_penetration: float,
	is_crit: bool
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
# Grid
# =============================================================================

## Grid.initialize() finished populating cell types for a new mission. Fires
## synchronously, before mission_launched (every mission_launched call site —
## MissionSelect.confirm_launch()/retry_current_mission(), the_gap.gd's debug
## auto-launch — calls GGrid.initialize() first). Added 2026-08-09: real bug
## fix. mission_scene.gd's own camera positioning previously ran inside its
## mission_launched handler, but mission_launched's subscriber order is fixed
## by connection order — WaveManager (an autoload, connected during boot)
## is always connected before any scene-instanced MissionScene, so its
## synchronous mission_launched -> mission_phase_changed -> templates_ready
## -> Mission HUD route-render cascade always completed BEFORE MissionScene's
## own camera-positioning handler ran. Every route-preview Line2D and
## blocked-cell/boss-telegraph marker (Planning Cluster's 3 screen-space
## overlays, all converting world position via the active Camera2D's
## get_viewport().get_canvas_transform()) was computed against a camera still
## sitting at its Node default (position (0,0), zoom (1,1)) — landing every
## marker hundreds of pixels off, confirmed live as a route line running
## diagonally off-screen instead of tracing the visible grid path. Subscribing
## camera setup to this signal instead (fired before the racy cascade even
## starts, not merely "early" within it) closes the ordering gap structurally
## rather than by connection-order luck.
## Key subscribers: MissionScene (camera position/zoom, GridVisual.configure()),
## MissionEconomy (gold-balance reset — added 2026-08-11, same "structural
## fix, not connection-order luck" rationale as the camera fix above; see
## mission_economy.gd's own class doc for the real ordering bug this closed).
signal grid_initialized(cols: int, rows: int, cell_size: float)


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

## Emitted synchronously by Monster System's _pass1_damage(), the one place in
## the codebase that resolves monster_damage_taken's entity_id against a live
## MonsterEntity AND still has that entity (global_position included) in hand
## — DamageStatus (monster_damage_taken's own emitter) never has a position to
## give, only entity_id. Closes the KNOWN GAP flagged in Mission HUD's
## _on_monster_damage_taken() (2026-08-06): floating damage numbers previously
## had no real world position and were rendered as a stacked feed near the
## boss bar instead. Skipped entirely for a dead/already-removed entity_id
## (same guard _pass1_damage() already applies before this point).
## Key subscribers: Mission HUD (floating damage number, positioned at the hit monster).
signal monster_damage_number_requested(entity_id: int, world_position: Vector2, amount: int, is_crit: bool)

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

## Crafting's repair action confirms a Common-material-only cost payment and
## mutates an existing damaged component in place (Rule 6). Documented in
## event-bus.md's catalogue (78 events, 2026-07-17) but missing from this
## file until Story 005 (Component Repair) added it — the mutation itself is
## a direct Inventory.clear_damaged_flag() call (ADR-0021 Criterion A), not
## an EventBus-subscribed side effect; this signal is purely the confirming
## notification, mirroring component_crafted's own emit-after-mutation order.
## Key subscribers: Mission HUD, Audio.
signal component_repaired(item_id: String, component_type: String)

## New recipe becomes available (tech unlock or first time materials available).
## Key subscribers: Encyclopedia, Crafting UI.
signal recipe_discovered(recipe_id: String, recipe_category: String)

# =============================================================================
# Menagerie System
# =============================================================================

## New creature created via Lure (Story 007, ADR-0026). Documented in
## ADR-0021's "Enables" note as already merged into event-bus.md's catalogue,
## but missing from this file until Story 007 added it.
## Key subscribers: Mission HUD, Encyclopedia.
signal creature_acquired(creature_id: int, species: String)

## Creature happiness value updates.
## Key subscribers: Resource Economy, Mission HUD.
## creature_id corrected from String to int (ADR-0026 Risks: matches
## ADR-0016/ADR-0021's int-typed instance-identity convention; the GDD's own
## prose said String, but the ADR is authoritative per the established
## "ADR corrects GDD" precedent from ADR-0024).
signal creature_happiness_changed(creature_id: int, new_happiness: float, quality_bonus: float)

## Breeding pen produces offspring.
## Key subscribers: Encyclopedia, Mission HUD.
signal creature_bred(offspring_id: int, species: String)

## Creature consumed in Equipment Forge operation. target_item_id corrected
## to int (ADR-0026 Risks) — minted via Inventory.reserve_instance_id() -> int.
## Key subscribers: Equipment Forge, Mission HUD.
signal creature_sacrificed(creature_id: int, target_item_id: int)

## Player moves creature out of habitat.
## Key subscribers: Resource Economy (reduce quality bonus).
signal creature_moved_to_breeding_pen(creature_id: int)

## Player returns creature to habitat.
## Key subscribers: Resource Economy (restore quality bonus).
signal creature_returned_from_breeding_pen(creature_id: int)

# =============================================================================
# Defense Building System
# =============================================================================

## Player unlocks a tech tree node.
## Key subscribers: Crafting (new recipes), Encyclopedia, Mission HUD.
signal tech_unlocked(tech_id: String, tech_category: String)

## New Sanctuary structure placed.
## Key subscribers: Mission HUD, Audio.
signal sanctuary_structure_built(structure_id: String, structure_type: String)

## An already-built Sanctuary structure gains a permanent upgrade (player-
## requested Building Upgrade System, design/gdd/building-upgrade.md Rule 6 —
## added 2026-08-11). Building Upgrade only emits this; it owns no
## mechanical effect itself. Which system reacts (Menagerie for Habitat
## Expansion, a future consumer for Watchtower) and what the effect is are
## deliberately undefined scaffolding, mirroring sanctuary_structure_built's
## own decoupled precedent.
## Key subscribers: none yet — proposed, not yet adopted by a consumer.
signal structure_upgraded(structure_id: String, upgrade_id: String)

## An upgrade's last unmet requirements/cost entry becomes satisfied —
## VISIBLE_LOCKED -> PURCHASABLE (player-requested Building Upgrade System,
## design/gdd/building-upgrade.md Rule 6a — added 2026-08-12 design review,
## Story 004/TR-buildupgrade-004). Fires only on that edge, never on every
## re-evaluation while already PURCHASABLE, and never again for the same
## upgrade_id once it reaches PURCHASED; re-armable if the upgrade later
## reverts to VISIBLE_LOCKED (Rule 4) and becomes PURCHASABLE again.
## Key subscribers: Sanctuary UI — drives its Connection Badge on the
## Equipment Forge tab (sanctuary-ui.md Core Rule 2 Tuning Knobs).
signal building_upgrade_became_purchasable(upgrade_id: String)

## Player combines 4 owned crafted tower components into a new, placeable
## TowerBlueprintData (player-requested Tower Assembly, design/quick-specs/
## tower-assembly-2026-08-11.md). Not part of Building Upgrade (Story 004) —
## restored here because src/core/tower_assembly/tower_assembly.gd and its
## own 12-test suite already depend on this exact signal existing (pre-
## existing, uncommitted 2026-08-11 work found while implementing this
## story; removing it would break that unrelated system, not just revert
## scope creep). Fires only after the new blueprint is already registered
## via GameDataRegistry — a subscriber can immediately query it.
## Key subscribers: Mission HUD (Tower Build Panel refresh), Encyclopedia, Audio.
signal tower_assembled(tower_id: String, display_name: String)

# =============================================================================
# Inventory System
# =============================================================================

## Item added to inventory.
## Key subscribers: Mission HUD, Crafting (recipe availability).
signal item_added(item_id: String, item_type: String, quantity: int)

## Item consumed or discarded.
## Key subscribers: Mission HUD, Crafting.
signal item_removed(item_id: String, item_type: String, quantity: int)

## Mid-mission pickup could not be stored (inventory full, no room in any
## stack). Fires instead of item_added; not queued or retried — the pickup
## is lost (Epic 03 Story 005, AC-15).
## Key subscribers: Mission HUD (toast/notification).
signal item_pickup_rejected(item_id: String, item_type: String, quantity: int, reason: String)

## Equipment change at Sanctuary.
## Key subscribers: Hero System (stat recalc), Damage & Status, Mission HUD.
signal equipment_slot_changed(slot: String, new_item_id: String, previous_item_id: String)

## Slot expansion tier completed (Story 003, TD-inv-003 item 2). Fires after
## Inventory.attempt_expand_slots() succeeds — materials already consumed,
## _slots already grown. new_tier is the tier just reached (1-5);
## new_slot_count matches SlotExpansionCostTable's slots_after for that tier.
## Key subscribers: Mission HUD / Inventory Screen (GDD's "Herald Gold flash"
## milestone moment — not yet wired to a visual, this signal existing is the
## prerequisite for that future work).
signal slot_expansion_completed(new_tier: int, new_slot_count: int)

# =============================================================================
# Resource Economy System
# =============================================================================

## Drop resolved after monster_died or wave_completed.
## Key subscribers: Inventory, Mission HUD.
signal materials_earned(material_type: String, quantity: int, source: String)

## Crafting or Equipment Forge consumes materials.
## Key subscribers: Inventory, Mission HUD.
signal materials_spent(material_type: String, quantity: int, destination: String)

## Player's gold balance changes (earned from drops, spent on placements/sells).
## source examples: "monster_drop", "tower_placed", "tower_sold".
## Key subscribers: Tower System (Gate 2 gold cache), Mission HUD.
signal resources_changed(gold: int, source: StringName)

# =============================================================================
# Tower Mastery System
# =============================================================================

## Hero proximity timer increments for a tower.
## Key subscribers: Mission HUD.
signal mastery_progress_updated(tower_id: int, skill_id: String, progress_percent: float)

## Proximity threshold reached — skill added to learned library. Emitted by
## Hero Skill Tree's node-purchase path only (hero-skill-tree.md Rule 9) —
## Tower Mastery itself no longer emits this directly as of the 2026-08-31
## Rule 13 revision; see skill_tree_point_earned below for its own trigger.
## Key subscribers: Hero Skill Build, Encyclopedia, Mission HUD.
signal skill_unlocked(skill_id: String, source_tower_id: int)

# =============================================================================
# Hero Skill Tree System (design/gdd/hero-skill-tree.md)
# =============================================================================

## Tower Mastery crossing a mastery_threshold_seconds multiple grants one
## spendable point in `archetype`'s pool — unconditional, emitted forever,
## never itself checking or mutating Hero Skill Tree's node state (Formula 3).
## Key subscribers: Hero Skill Tree, Mission HUD.
signal skill_tree_point_earned(archetype: String, source_tower_id: int)

## Fires instead of skill_tree_point_earned when the crediting archetype's
## own 4-node chain is already fully unlocked but at least one other
## archetype still has a locked node (Rule 3b) — the point converts to the
## shared, archetype-agnostic overflow pool instead of being lost.
## Key subscribers: Hero Skill Tree, Mission HUD.
signal skill_tree_overflow_point_earned(source_tower_id: int)

## A Minor node was purchased at Sanctuary (Formula 2's Minor branch) — never
## fired for a Choice node purchase, which fires skill_unlocked instead.
## Key subscribers: Mission HUD, Encyclopedia.
signal skill_tree_node_unlocked(archetype: String, node_index: int)

## Fires the instant a build_signature's hero-proximity state flips (entered
## or exited range) — added 2026-08-13 (Epic 06 Story 013's Audio
## Requirement d) to give the enter-range-tick/pause-descending-tone stinger
## pair a real discrete trigger. `mastery_progress_updated` deliberately
## cannot serve this role: it only fires while actively accruing, so
## "stopped firing" is an absence, not an event — exactly the "timeout
## heuristic, not an explicit signal" gap tower-mastery_feedback.gd's own
## visual pause-detection already documented as a known limitation. Emitted
## from TowerMastery._recompute_signatures_in_range() by diffing the
## previous and new in-range sets, not from tick() (which only runs for
## already-in-range signatures) — this is a state-transition signal, not a
## per-frame status broadcast.
## Key subscribers: Audio.
signal tower_mastery_proximity_changed(build_signature: String, in_range: bool)

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
## `difficulty_tier` added by Story 006 (epic-04-wave-manager, 2026-07-05) —
## Wave Manager reads it directly off this signal (GDD wave-manager.md Rule 8
## says Wave Manager "Reads difficulty_tier: int from the mission launch
## data"); the field did not exist on this signal until this story added it.
## Key subscribers: Wave Manager, Save & Persistence (pre-mission checkpoint).
signal mission_launched(mission_id: String, modifiers: PackedStringArray, difficulty_tier: int)

# =============================================================================
# Encyclopedia System
# =============================================================================

## Any discovery event triggers an entry addition.
## Key subscribers: Mission HUD (discovery notification).
signal encyclopedia_entry_added(category: String, entry_id: String)

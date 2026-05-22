# EventBus System

> **Status**: Approved (pass 1 — 2026-05-14; 2 blockers resolved in-session: hero_bonus_tier field renames in HeroAutoAttackEvent and MonsterDamageTaken)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-05-15
> **Implements Pillar**: All pillars (cross-cutting infrastructure)

## Overview

The EventBus System is the central pub/sub backbone of Sanctuary Defenders. It provides a single, global event channel through which all other systems publish and receive game-world notifications. No system holds a direct reference to any other system; instead, a system that needs to communicate an outcome fires an event to the EventBus, and any system interested in that outcome has previously registered a listener. The EventBus owns the full catalogue of named events — their identifiers, their payload definitions, and the rules governing how they are dispatched. Because every cross-system communication passes through this channel, the event catalogue functions as the public API of the entire game: adding a new event is a design act, not just a code act, and changing an event's payload is a breaking change that affects every subscriber.

## Player Fantasy

*Not applicable — the EventBus is pure infrastructure. Players never interact with it directly. Its value is expressed entirely through the cross-system synergies it enables: hero equipment affecting tower stats, creature happiness affecting material quality, Tarot cards altering wave composition. The player feels the outcomes; the EventBus is the invisible channel that makes them possible.*

## Detailed Design

### Core Rules

1. All cross-system communication passes through the EventBus. No system may hold a direct reference to any other system at runtime.
2. Event names use `snake_case`. Completed actions use past tense (e.g., `hero_damage_taken`, `wave_completed`). State transitions use present tense (e.g., `mission_phase_changed`).
3. **Synchronous dispatch is the default.** Event subscribers execute immediately when the emitter calls `emit_signal()`. Emitters originating inside Godot physics callbacks (`_physics_process`, `area_body_entered`) or that trigger scene-tree modifications (adding/removing nodes) must use deferred dispatch to avoid physics-context errors.
4. **Typed signal parameters are the payload standard.** Events with 1–4 fields use typed parameters declared directly on the signal. Events with 5 or more fields use a custom `Resource` subclass as a single typed parameter. Dictionary payloads are prohibited in the event catalogue.
5. Event chains may not exceed 2 levels without explicit design approval: a subscriber that receives an event may emit one further event; subscribers of that second event may not emit further events. Violations break the frame budget and make root-cause debugging impractical.
6. Every system that subscribes to EventBus events must disconnect all connections in its `_exit_tree()` method. This is mandatory — not a recommendation. Dangling connections into freed nodes cause runtime errors during wave cleanup.
7. The EventBus Autoload must be the **first entry** in Project Settings → Autoloads. All other systems that connect in `_ready()` depend on EventBus existing first.
8. The EventBus has no internal game state. It does not own, cache, validate, or transform event data. It is a pure dispatcher.
9. Only events that cross system boundaries belong in this catalogue. Events used internally within a single system are not registered here and should not be exposed on the EventBus.

---

### States and Transitions

The EventBus is stateless — it has no internal state machine. Its dispatch lifecycle per event is:

| State | Condition | Description |
|-------|-----------|-------------|
| **IDLE** | No event in flight | Default state between emissions |
| **DISPATCHING** | `emit_signal()` called | All connected subscribers execute synchronously; emitter is blocked until all subscribers return |
| **IDLE** | All subscribers returned | Dispatch complete; emitter resumes |

There is no QUEUED state in the default synchronous model. Events fire immediately and do not accumulate. Deferred events bypass this lifecycle — they are scheduled by Godot's message loop and dispatch on the next frame.

---

### Interactions with Other Systems — Event Catalogue

All 25 systems interact with the EventBus using the same pattern:
- **Subscribe** at initialisation to events they need to respond to
- **Emit** when their internal state changes in a way that other systems care about
- **Disconnect** all subscriptions at cleanup

The complete event catalogue follows, organised by the system that publishes each event. "Key Subscribers" lists the most important systems that must listen for each event.

---

#### Wave Manager

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `mission_phase_changed` | `previous_phase: String`, `new_phase: String`, `timestamp: float` | All mission-active systems, Save & Persistence, Audio | Any SCOUT/WAVE_ACTIVE/INTERMISSION/MISSION_COMPLETE/DEFEAT transition |
| `wave_started` | `wave_number: int`, `total_waves: int`, `wave_difficulty: float` | Monster, Hero, Tower, Mission HUD | Wave timer expires and first monster spawns |
| `wave_completed` | `wave_number: int`, `enemies_remaining: int` | Monster, Resource Economy, Mission HUD | All wave enemies are dead or boss is killed |
| `wave_countdown_warning` | `seconds_remaining: int` | Mission HUD, Audio | 10 seconds before wave launch |
| `phase_timer_tick` | `phase: String`, `seconds_remaining: float` | Mission HUD | Every second during Scout Phase and Intermission |
| `monster_spawn_requested` | `MonsterSpawnRequest` Resource: `monster_id: StringName`, `spawn_cell: Vector2i`, `wave_index: int`, `difficulty_tier: int`, `wave_reward_scalar: float` | Monster System (instantiate entity) | Per spawn entry during WAVE_ACTIVE, after each `pre_delay` elapses; 5 fields → Resource subclass per Core Rule 4. **`wave_reward_scalar` is consumed by Resource Economy only — Monster System must not apply it to combat stats.** |
| `wave_preview_available` | `next_wave_number: int`, `composition: Array[Dictionary]` (each dict: `{monster_id: StringName, count: int}`) | Mission HUD | Emitted immediately on INTERMISSION entry (non-final wave); delivers upcoming wave composition for "forewarning" display |
| `wave_stalled` | `wave_number: int`, `enemies_remaining: int` | Mission HUD | Emitted 30s after `_all_spawns_fired` if `_enemies_alive > 0`; precedes the 60s force-clear watchdog; enables "X enemies remaining" HUD display |
| `player_ready` | *(no payload)* | Wave Manager (phase gate — advances SCOUT→PRE_WAVE or INTERMISSION→PRE_WAVE) | Emitted by Mission HUD when player presses the Ready button. Wave Manager ignores this event outside SCOUT and INTERMISSION (Wave Manager Rules 9 and 12). |

---

#### Hero System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `hero_auto_attacked` | `HeroAutoAttackEvent` Resource: `base_damage: float`, `is_crit: bool`, `target_id: int`, `crit_multiplier_effective: float`, `hero_lifesteal_fraction: float`, `hero_bonus_tier: int` | Damage & Status (pipeline trigger) | Hero's auto-attack animation resolves; Hero System rolls crit, reads target tier, and pre-computes `crit_multiplier_effective` before emitting. Resource payload required (6 fields — Core Rule 4). |
| `hero_health_changed` | `current_health: float`, `max_health: float` | Mission HUD | Any HP change (damage or healing) |
| `hero_died` | *(no payload)* | Wave Manager (trigger DEFEAT) | Hero HP reaches 0 |
| `hero_position_changed` | `grid_position: Vector2i` | Tower Mastery (proximity tracking) | Hero moves to a new grid cell |
| `hero_equipment_changed` | `slot: String`, `item_id: String` | Damage & Status, Mission HUD | Equipment slot updated at Sanctuary |
| `hero_skill_activated` | `skill_id: String`, `target_position: Vector2` | Damage & Status, Audio, Mission HUD | Player activates an active skill |
| `hero_skill_cooldown_updated` | `skill_slot: int`, `cooldown_remaining: float`, `cooldown_max: float` | Mission HUD (skill button fill-drain display) | Emitted by Hero System each second while a skill slot is on cooldown; stops when cooldown reaches 0 |
| `hero_ultimate_activated` | *(no payload)* | Hero System (effect resolution + cooldown start) | Emitted by Mission HUD when player presses the Ultimate button; Hero System subscribes |
| `hero_class_unlocked` | `class_id: String` | Tower Mastery, Mission HUD, Audio | Hero accumulates enough proximity time to unlock a new class identity |

---

#### Tower System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `tower_placed` | `tower_id: int`, `grid_position: Vector2i`, `archetype: String`, `footprint: Vector2i`, `placed_in_scout: bool` | Constellation, Hero, **Pathfinding** (dirty-check + deferred rebuild), Mission HUD, Audio | Tower placed during SCOUT or INTERMISSION only; WAVE_ACTIVE placement is blocked (Tower System Rule 8). `placed_in_scout` is `true` only for SCOUT placements. |
| `tower_removed` | `tower_id: int`, `grid_position: Vector2i`, `archetype: String` | Constellation, Hero (Tower Affinity recalc), **Pathfinding** (dirty-check + deferred rebuild), Mission HUD | Tower voluntarily removed during SCOUT or INTERMISSION; distinct from `tower_destroyed` |
| `tower_destroyed` | `tower_id: int`, `grid_position: Vector2i`, `archetype: String`, `footprint: Array[Vector2i]` | Constellation, Grid, Inventory (component recovery), Mission HUD, **Pathfinding** (sets `_tower_destroyed_during_wave = true` for auto-rebuild at INTERMISSION entry) | Tower HP reaches 0 mid-wave |
| `tower_damaged` | `tower_id: int`, `damage_dealt: float`, `current_hp: float`, `max_hp: float` | Mission HUD (tower HP bar update) | Boss attack reduces tower HP and tower survives; primary HP observable (Tower System does not expose HP polling API) |
| `tower_sell_requested` | `tower_id: int` | Tower System (removal + build point refund) | Emitted by Mission HUD when player presses Sell in SCOUT or INTERMISSION; Tower System must guard against this arriving outside valid phases |
| `tower_component_equipped` | `tower_id: int`, `slot: String`, `component_id: String` | Constellation, Mission HUD | Component swapped in a tower slot |
| `tower_attacked` | `tower_id: int`, `target_monster_id: int`, `damage_amount: float`, `is_siege: bool`, `is_armored: bool` | Damage & Status, Monster System (shield penetration routing for `[BOSS]`-tagged targets — checks `is_siege`), Audio | Tower fires at a monster. `is_siege` is derived from the originating tower's `Foundation.siege` flag (`true` for T4 only). `is_armored` is pre-resolved by Tower System from the target's `MonsterResource.archetype_tag` at fire time (`true` when `archetype_tag == &"armored"`); D&S applies 50% tower damage mitigation when `true`. Hero damage is not affected by this flag. |
| `tower_aura_pulse` | `TowerAuraPulseEvent` Resource: `tower_id: int`, `aura_effect_type: String`, `aura_effect_value: float`, `aura_radius_cells: int` | Damage & Status (apply effect to entities in radius), Mission HUD | Support archetype tower's attack timer expires; aura pulse emitted unconditionally (no target required). 4 fields — promoted to Resource subclass per Core Rule 4 for consistency with `tower_wave_summary` and to allow future field additions without a breaking change. `anchor_cell` removed — D&S derives position from tower_id via Grid read. |
| `pre_placement_perk_activated` | `tower_id: int`, `perk_type: String` | Mission HUD, Audio | Immediately on Scout Phase tower placement confirmation (before any wave begins); NOT at wave start |
| `tower_wave_summary` | `TowerWaveSummary` Resource: `tower_id: int`, `max_hp: float`, `shots_fired: int`, `damage_dealt: float`, `idle_ticks: int`, `aura_applications_this_wave: int`, `scatter_target_cycle: Dictionary[int, int]` | Mission HUD ("Endless Theorist" feedback display) | Emitted once per active tower on `wave_completed` (after HP reset). 7 fields → Resource subclass per Core Rule 4. `max_hp` allows HUD to reconstruct full HP for towers that took no damage; `idle_ticks` = attack-timer expirations with no valid target; `aura_applications_this_wave` = Support pulse count (0 for non-Support); `scatter_target_cycle` = SCATTER hit map `{entity_id → hit_count}` (empty Dict for non-SCATTER). `hp_remaining` removed — HP always resets to `max_hp` at wave end, so `hp_remaining` is always `max_hp` and was redundant. `wave_id` removed — not required by Tower GDD Rule 23. |

---

#### Monster System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `monster_spawned` | `MonsterSpawnedEvent` Resource: `entity_id: int`, `monster_id: StringName`, `wave_index: int`, `grid_position: Vector2i`, `hp_max: float` | Pathfinding, Wave Manager, Mission HUD, Tower System (cache init — `hp_max` initialises `current_hp` in `_monster_cache`; subscribed Synchronous per Tower GDD Rule 14a) | Monster enters the field. 5 fields → promoted to `MonsterSpawnedEvent` Resource subclass per Core Rule 4. `hp_max` required by Tower System to seed HP-tracking cache entry at spawn time. |
| `monster_died` | `MonsterDied` Resource: `entity_id: int`, `monster_id: StringName`, `tier: int`, `drop_table_id: StringName`, `menagerie_attraction_drop_chance: float`, `world_position: Vector2`, `kill_source: String`, `wave_reward_scalar: float` | Resource Economy (drop calc + Menagerie chance scaled by `wave_reward_scalar`; must filter `kill_source == "wave_end"` and suppress all drop resolution), Wave Manager (count), Constellation (tower kill credit), Mission HUD | Monster HP reaches 0 or wave_completed force-removal; 8 fields → `MonsterDied` Resource subclass per Core Rule 4. `wave_reward_scalar` is forwarded from the original `monster_spawn_requested` payload — Monster System does not apply it to stats. Resource Economy owns drop scaling. |
| `monster_breached` | `entity_id: int`, `monster_id: StringName`, `tier: int` | Wave Manager (`tier==2` triggers wave-clear), Mission HUD | Monster exits the GOAL cell boundary without being killed; emitted once per entity |
| `boss_died` | `entity_id: int`, `monster_id: StringName`, `wave_index: int`, `cause: String` | Wave Manager (wave-clear: `cause="killed"` or `"breached"`), Mission HUD, Audio | BOSS HP reaches 0, or BOSS breaches, or BOSS force-removed at `wave_completed`; `cause` values: `"killed"` / `"breached"` / `"force_removed"` |
| `boss_hp_changed` | `entity_id: int`, `current_hp: float`, `max_hp: float` | Mission HUD (BOSS HP bar) | Each time a BOSS receives `monster_damage_taken` and survives; MVP-required |
| `boss_tower_attack_attempted` | `boss_entity_id: int`, `target_tower_id: int`, `base_damage: float`, `wave_id: int` | Tower System (apply damage directly to tower HP, no mitigation, MVP; `wave_id` used for staleness rejection — see Tower GDD Edge Cases) | BOSS attack cooldown reached 0 and a tower is within `boss_attack_range_cells` range |
| `monster_cell_entered` | `entity_id: int`, `grid_cell: Vector2i`, `path_step_index: int` | Tower System (update monster position cache for targeting; fired per monster per grid-cell transition during WAVE_ACTIVE) | Monster moves from one grid cell to an adjacent grid cell along its path |

---

#### Pathfinding System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `path_invalidated` | `affected_cells: Array[Vector2i]` (deduplicated union) | Monster System (trigger path recalc for entities using affected cells), Wave Manager (secondary gate for waves 2+) | Tower placed/removed during SCOUT or INTERMISSION triggers deferred rebuild; also fires at INTERMISSION entry if BOSS destroyed a tower during the preceding WAVE_ACTIVE |
| `templates_ready` | `spawn_count: int`, `build_duration_ms: float` | **Wave Manager** (gate first monster spawn — must not emit `monster_spawn_requested` until this fires) | After all N route templates finish building at SCOUT start; emitted exactly once per SCOUT entry |
| `tower_placement_blocked` | `blocked_cells: Array[Vector2i]`, `primary_blocking_cell: Vector2i` | Mission HUD (show blocked-placement indicator) | Pathfinding emits when `would_block_all_paths(footprint)` returns true — same frame as Tower System placement rejection. `primary_blocking_cell == Vector2i(-1, -1)` = multi-cell interaction block; Mission HUD highlights entire footprint uniformly. Otherwise, `primary_blocking_cell` is the single load-bearing cell — highlight distinctively. |

---

#### Damage & Status System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `monster_damage_taken` | `MonsterDamageTaken` Resource: `entity_id: int`, `amount: int`, `source_type: int`, `is_crit: bool`, `hero_bonus_tier: int` | Monster System (apply HP reduction), Mission HUD | Deferred one frame after `tower_attacked` or `hero_auto_attacked` fires; **never synchronous** — EventBus cascade budget rule |
| `hero_healed` | `amount: int` | Hero System (apply HP gain and overheal clamp) | Frame N+2 from the triggering `hero_auto_attacked` — fires synchronously within D&S's `monster_hp_absorbed` handler after Monster System confirms actual HP absorbed. Fires only when `heal_amount > 0` (zero heals suppressed). **Cascade exemption:** `hero_healed` is a permitted synchronous emission at depth 1 from `monster_hp_absorbed` (depth 0, fresh dispatch); Hero System does not re-emit from its `hero_healed` handler. |
| `monster_hp_absorbed` | `entity_id: int`, `absorbed: int` | Damage & Status (lifesteal resolution) | Emitted by Monster System (deferred one frame from `monster_damage_taken`) after applying the damage to the target's HP. `absorbed = min(amount_received, pre_hit_hp)` — actual HP removed, capped at what the monster had. NOT emitted when Monster System discards `monster_damage_taken` for a dead entity. |
| `hero_damage_taken` | `amount: int`, `source_type: int` | Hero System (apply HP reduction), Mission HUD, Audio | After D4 armor reduction applied, deferred one frame from `hero_incoming_damage`. MVP: no active attack sources exist — pipeline is scaffolding only |
| `hero_incoming_damage` | payload TBD — defined by the future system that attacks the hero | Damage & Status (subscribes as pipeline input) | Emitted by any future source that inflicts damage on the hero. MVP: no sources exist; event payload deferred to that system's GDD |

> **`source_type` values for `monster_damage_taken` and `hero_damage_taken`:** `0` = tower, `1` = hero, `2` = reserved for future sources. Defined here as the owning system's contract; consuming systems must not assume additional values without updating this catalogue.

> **`hero_bonus_tier` values for `monster_damage_taken` and `hero_auto_attacked`:** `0` = STANDARD, `1` = ELITE, `2` = BOSS. Set by Hero System at fire time from the target's archetype tag; read by D&S to apply the hero damage bonus multiplier.

---

#### Constellation System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `constellation_activated` | `pattern_id: String`, `grid_origin: Vector2i`, `bonus_type: String`, `bonus_value: float` | Tower System, Mission HUD, Audio | Valid geometric pattern fully placed |
| `constellation_deactivated` | `pattern_id: String`, `reason: String` | Tower System, Mission HUD | Pattern broken (tower destroyed or moved) |
| `constellation_rune_discovered` | `rune_id: String`, `pattern_id: String` | Encyclopedia, Equipment Forge | First time a constellation pattern is completed in this playthrough |

---

#### Tarot System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `mission_modifier_applied` | `modifier_type: String`, `modifier_value: float`, `source_card_id: String` | Wave Manager, Monster System | At mission start (SCOUT phase) — modifiers resolve before Tarot rune effects |
| `tarot_rune_discovered` | `rune_id: String`, `card_id: String` | Encyclopedia, Equipment Forge | First time a Tarot rune is unlocked in this playthrough |
| `tarot_deck_changed` | `active_card_count: int` | Save & Persistence, Tarot Deck UI | Player modifies deck at Sanctuary |

---

#### Crafting System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `component_crafted` | `component_id: String`, `component_type: String`, `quality_tier: int` | Inventory, Mission HUD, Audio | Crafting operation completes successfully |
| `recipe_discovered` | `recipe_id: String`, `recipe_category: String` | Encyclopedia, Crafting UI | New recipe becomes available (tech unlock or first time materials available) |

---

#### Menagerie System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `creature_happiness_changed` | `creature_id: String`, `new_happiness: float`, `quality_bonus: float` | Resource Economy, Mission HUD | Creature happiness value updates |
| `creature_bred` | `offspring_id: String`, `species: String` | Encyclopedia, Mission HUD | Breeding pen produces offspring |
| `creature_sacrificed` | `creature_id: String`, `target_item_id: String` | Equipment Forge, Mission HUD | Creature consumed in Equipment Forge operation |
| `creature_moved_to_breeding_pen` | `creature_id: String` | Resource Economy (reduce quality bonus) | Player moves creature out of habitat |
| `creature_returned_from_breeding_pen` | `creature_id: String` | Resource Economy (restore quality bonus) | Player returns creature to habitat |

---

#### Defense Building System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `tech_unlocked` | `tech_id: String`, `tech_category: String` | Crafting (new recipes), Encyclopedia, Mission HUD | Player unlocks a tech tree node |
| `sanctuary_structure_built` | `structure_id: String`, `structure_type: String` | Mission HUD, Audio | New Sanctuary structure placed |

---

#### Inventory System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `item_added` | `item_id: String`, `item_type: String`, `quantity: int` | Mission HUD, Crafting (recipe availability) | Item added to inventory |
| `item_removed` | `item_id: String`, `item_type: String`, `quantity: int` | Mission HUD, Crafting | Item consumed or discarded |
| `equipment_slot_changed` | `slot: String`, `new_item_id: String`, `previous_item_id: String` | Hero System (stat recalc), Damage & Status, Mission HUD | Equipment change at Sanctuary |

---

#### Resource Economy System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `materials_earned` | `material_type: String`, `quantity: int`, `source: String` | Inventory, Mission HUD | Drop resolved after monster_died or wave_completed |
| `materials_spent` | `material_type: String`, `quantity: int`, `destination: String` | Inventory, Mission HUD | Crafting or Equipment Forge consumes materials |

---

#### Tower Mastery System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `mastery_progress_updated` | `tower_id: int`, `skill_id: String`, `progress_percent: float` | Mission HUD | Hero proximity timer increments for a tower |
| `skill_unlocked` | `skill_id: String`, `source_tower_id: int` | Hero Skill Build, Encyclopedia, Mission HUD | Proximity threshold reached — skill added to learned library |

---

#### Equipment Forge System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `hero_equipment_crafted` | `item_id: String`, `item_type: String`, `quality_tier: int` | Inventory, Mission HUD, Audio | Forge operation produces hero gear |
| `item_rune_imbued` | `item_id: String`, `rune_id: String`, `rune_source: String` | Hero System (stat update), Mission HUD | Rune imbued into hero equipment |

---

#### Hero Skill Build System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `active_skill_equipped` | `slot_index: int`, `skill_id: String` | Hero System, Mission HUD | Player assigns a skill to an active slot at Sanctuary |
| `ultimate_skill_changed` | `ultimate_id: String` | Hero System, Mission HUD | Active skill combination resolves to a new Ultimate |

---

#### Save & Persistence System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `game_saved` | `save_slot: int`, `timestamp: float` | Mission HUD (show save indicator) | Sanctuary state serialised to disk |
| `sanctuary_state_restored` | `save_slot: int` | All Sanctuary systems | Save file loaded (game start or post-defeat return) |

---

#### Mission Select System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `mission_selected` | `mission_id: String` | Wave Manager (prepare parameters), Mission HUD | Player confirms a mission from the select screen |
| `run_modifier_selected` | `modifier_id: String`, `modifier_value: float` | Wave Manager, Tarot System | Player toggles a run modifier on/off |
| `mission_launched` | `mission_id: String`, `modifiers: PackedStringArray` | Wave Manager, Save & Persistence (pre-mission checkpoint) | Player confirms launch with current modifiers |

---

#### Encyclopedia System

| Event | Payload | Key Subscribers | When Fired |
|-------|---------|-----------------|------------|
| `encyclopedia_entry_added` | `category: String`, `entry_id: String` | Mission HUD (discovery notification) | Any discovery event triggers an entry addition |

---

**Total events in catalogue: 70** across 19 publishing systems. *(2026-04-26: +2 Monster System events — `boss_hp_changed` and `boss_tower_attack_attempted`; `monster_died`, `monster_spawned`, and `boss_died` payloads corrected to match Monster GDD naming convention. 2026-05-01: +3 Tower System GDD revision 2 — `tower_damaged` for HP observability, `tower_aura_pulse` for Support archetype aura model, `monster_cell_entered` for Tower targeting cache; payloads corrected for `tower_placed`, `tower_destroyed`, `boss_tower_attack_attempted`, and `pre_placement_perk_activated`. 2026-05-07 Tower Revision 7: +1 `tower_wave_summary` with `TowerWaveSummary` Resource subclass; `tower_aura_pulse` promoted to `TowerAuraPulseEvent` Resource subclass (5→4 fields, `anchor_cell` removed); `tower_placed` when-fired corrected — WAVE_ACTIVE is blocked.)*

> **ADR**: These three decisions are formally recorded in ADR-0001 (`docs/architecture/adr-0001-eventbus-architecture.md`, Accepted 2026-05-15): (1) synchronous-vs-deferred dispatch policy and batching rules (Rules 2 and 5), (2) typed-parameters-vs-Resource-subclass payload contract (Rule 3), (3) EventBus Autoload initialisation order as a verified build invariant (ADR Dependencies section and ADR-0002).

## Formulas

The EventBus performs no gameplay calculations. Its Formulas section defines the **performance contract** — the maximum acceptable cost of event dispatch so system authors know the budget their subscribers must respect.

---

### Formula 1 — Per-Event Subscriber Chain Budget

```
T_chain = T_frame × B_event / E_concurrent
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Frame budget | `T_frame` | float | 16.67 ms (fixed) | Total frame budget at 60 FPS |
| EventBus budget fraction | `B_event` | float | 0.05–0.20 | Fraction of frame allocated to all EventBus dispatch combined |
| Concurrent event types | `E_concurrent` | int | 1–20 | Distinct event types that may dispatch in the same frame (not firings — types) |
| Per-event chain budget | `T_chain` | float | practical ceiling ~1.0 ms | Maximum total subscriber execution time for one event type per frame |

**Output Range:** Unclamped. `T_chain` above 1.0 ms signals a frame-budget risk requiring deferred dispatch or subscriber pruning.

**Example:** Peak wave frame: rendering + physics (100+ monsters) + pathfinding consume ~85% of the budget. EventBus receives 10%:
```
T_chain = 16.67 × 0.10 / 8 = 0.208 ms per event type
```
Each subscriber across all listeners of one event must complete in ~0.208 ms total — meaning nothing heavier than a counter increment, property read, or label update.

---

### Formula 2 — High-Frequency Event Per-Firing Budget

```
T_firing = T_chain / F_per_frame
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Per-event chain budget | `T_chain` | float | from Formula 1, ~0.208 ms | Maximum budget for all subscribers of this event type in one frame |
| Firings per frame | `F_per_frame` | int | 1–50 | Times this event fires in a single frame |
| Per-firing budget | `T_firing` | float | practical ceiling ~0.05 ms | Maximum acceptable time per individual event firing |

**Output Range:** Unclamped. When `F_per_frame` exceeds 20, `T_firing` drops below 0.010 ms — requiring deferred batch dispatch.

**Example:** 40 monsters die in one physics frame. `monster_died` has 4 subscribers:
```
T_firing = 0.208 / 40 = 0.0052 ms = 5.2 µs per firing
```
Each of 4 subscribers gets ~1.3 µs per monster death — physically achievable only as a counter increment. **`monster_died` must use batched deferred dispatch at this scale.** The Wave Manager should accumulate individual deaths in `_physics_process` and fire one `monsters_died_batch` event at frame end.

---

### Formula 3 — Cascade Depth Cost Multiplier

```
T_cascade = T_firing × (1 + D_max × S_avg)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Per-firing budget | `T_firing` | float | from Formula 2 | Subscriber cost of the root event per firing |
| Cascade depth | `D_max` | int | {1} | Maximum downstream event levels; Core Rule 5 caps at 2 |
| Average downstream subscribers | `S_avg` | int | 1–5 | Subscribers on each downstream event in the chain |
| Total cascade cost | `T_cascade` | float | must remain ≤ T_chain | Total subscriber cost including all cascade levels per root firing |

**Output Range:** Must not exceed `T_chain` (Formula 1). Violations require deferred Level-1 dispatch.

**Example:** `tower_attacked` → (Damage & Status subscriber) → `monster_damage_taken` → (Monster, HUD, Audio):
```
T_cascade = 0.208 × (1 + 1 × 3) = 0.832 ms
```
During peak waves with 10+ towers firing per frame, this cascade consumes 50% of the EventBus budget from one event chain. **Rule: Level-1 cascade events must use deferred dispatch by default.** The downstream emission becomes a next-frame scheduled call, reducing the originating frame's cascade cost to zero.

---

### Performance Design Constraints Summary

| Rule | Source | Hard Limit |
|------|--------|-----------|
| All EventBus work per frame | Formula 1 (`B_event = 0.10`) | 1.667 ms total |
| Per-event type budget (8 concurrent) | Formula 1 | ~0.208 ms per event type |
| High-frequency per-firing budget (40×) | Formula 2 | ~5 µs — requires batching |
| Batching required threshold | Formula 2 | `F_per_frame` > 20 |
| Cascade multiplier (D=1, S_avg=3) | Formula 3 | 4× root cost — Level-1 must be deferred |

> **Cross-GDD impact:** The `monster_died` batching requirement (Formula 2) is a binding constraint on the Monster System and Wave Manager GDDs. Flag it when those are authored.

## Edge Cases

- **EC-1 — If a subscriber creates a re-entrant cycle** (subscriber to A emits B; subscriber to B emits A): The synchronous call stack grows infinitely and crashes. This is categorically prevented by Core Rule 5 (2-level chain cap). Subscribers at Level 2 must not emit further events — use `call_deferred` outside the EventBus chain if downstream state change is required. Detection must happen during design review; there is no runtime cycle guard.

- **EC-2 — If a subscribing node is freed via `queue_free()` before `_exit_tree()` fires, and an event emits in the same frame**: Godot calls a method on a partially freed object → runtime error. Resolution: nodes that may be freed mid-wave (tower nodes after `tower_destroyed`, monster nodes after death) must disconnect all EventBus connections as the *first* line of `_exit_tree()` — before any other cleanup. Direct node references in payloads are separately prohibited by Core Rule 4.

- **EC-3 — If no subscribers are registered for an event (ghost event)**: Godot's signal dispatch completes silently with no error and no effect. This is correct and intentional. Ghost events occur legitimately when subscribing systems have not yet loaded (e.g., Mission HUD not yet active when the first `phase_timer_tick` fires). Emitting systems must not assume any subscriber acted; acknowledgement patterns belong within individual systems, not on the EventBus.

- **EC-4 — If a system tries to subscribe before the EventBus Autoload exists**: Null reference error. Resolution: Core Rule 7 (EventBus is first Autoload) is a build invariant — there is no runtime workaround. All systems must connect in `_ready()`, never in `_init()`. The ordering must be verified in ADR-0002 acceptance criteria.

- **EC-5 — If two systems emit the same event type simultaneously in the same frame** (e.g., tower kill and hero AoE kill both resolve `monster_died` in the same `_physics_process` tick): Each `emit_signal()` dispatches independently and sequentially. This is expected behaviour. It becomes a performance violation only when `F_per_frame` exceeds 20 (Formula 2 threshold), at which point Wave Manager's batch accumulator collapses all firings into one `monsters_died_batch` emission per frame.

- **EC-6 — If a deferred event payload references a node that is freed before the deferred dispatch executes**: Subscriber accesses a freed object → crash. Resolution: payloads must never include direct Node references (Core Rule 4 enforces this — typed primitives and Resource subclasses only). Subscribers must look up live nodes from their own registry by ID after receiving the event, guarding with `is_instance_valid()` before acting.

- **EC-7 — If `mission_phase_changed` fires for DEFEAT, and a cleanup subscriber incorrectly triggers another phase change**: `mission_phase_changed` dispatches a second time synchronously before the first dispatch returns; all subscribers execute twice with contradictory phase values. Resolution: Wave Manager sets an internal `_phase_locked: bool = true` flag before emitting any terminal-phase event (DEFEAT, MISSION_COMPLETE), rejecting further phase-change calls until cleanup completes. This guard lives in Wave Manager — the EventBus remains stateless (Core Rule 8).

- **EC-8 — If a Level-1 cascade subscriber emits synchronously instead of deferred** (e.g., Damage & Status emits `monster_damage_taken` synchronously after receiving `tower_attacked`): Total cascade cost reaches ~0.832 ms for that chain — 50% of the entire EventBus frame budget from one event type at peak wave volume (Formula 3). Resolution: Level-1 cascade events must use `call_deferred("emit_signal", ...)`. The Damage & Status GDD must document this pattern explicitly. Design review of any Level-1 emitter must verify deferred usage.

- **EC-9 — If `monster_died` fires more than 20 times in one physics frame without batch accumulation**: Per-firing subscriber budget drops below 0.010 ms — even a counter increment is statistically risky across 4 subscribers at 40 firings. Resolution: Wave Manager maintains a `monster_died` batch accumulator during `_physics_process`. When per-frame count exceeds 20, it switches to deferred `monsters_died_batch` dispatch (custom Resource subclass payload). The 20-firing threshold is the Formula 2 boundary; Wave Manager owns the toggle — the EventBus remains a pure dispatcher.

- **EC-10 — If `sanctuary_state_restored` fires during game load before Sanctuary system subscribers have called `_ready()`**: Affected systems (Crafting, Menagerie, Equipment Forge, Tarot, Hero Skill Build) miss the event and initialise with default state, silently ignoring save data. Resolution: Save & Persistence must not emit `sanctuary_state_restored` from its own `_ready()`. It must defer emission by one frame (`call_deferred`), ensuring all scene-tree nodes have connected their subscribers. Additionally, Sanctuary systems must pull initial state directly from Save & Persistence on `_ready()` — the event handles subsequent changes, but initial load is a pull-not-push operation.

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Godot 4.6.2 | EventBus depends on engine | Signal system, Autoload lifecycle, `call_deferred()` for deferred dispatch |
| GDScript | EventBus depends on language | All signal declarations and subscriber callables authored in GDScript |
| **All 24 other systems** | All systems depend on EventBus | One-directional dependency: systems subscribe to and emit on the EventBus; the EventBus has no knowledge of any system |

**Dependency notes:**
- The EventBus has zero hard dependencies on other game systems — it is a pure infrastructure layer.
- The dependency direction is exclusively inward: every system depends on the EventBus; the EventBus depends on no system.
- The EventBus is a **bottleneck in the dependency graph** — it must be designed and implemented before any cross-system feature can be tested. This is why it is Design Order #1.
- Any change to an event's name or typed payload signature is a breaking change for all current subscribers of that event. Event contracts should be treated as a public API: deprecate, don't remove.

## Tuning Knobs

| Parameter | Default Value | Safe Range | Too High | Too Low |
|-----------|---------------|-----------|----------|---------|
| EventBus frame budget fraction (`B_event`) | 0.10 (10%) | 0.05–0.20 | EventBus crowds out rendering, physics, pathfinding | Event subscribers can't execute any meaningful work per firing |
| High-frequency event batch threshold (`F_per_frame`) | 20 firings/frame | 10–40 | Too many synchronous dispatches; frame hitches during mass monster deaths | Batching activates unnecessarily for normal wave sizes; adds frame-latency overhead |
| Maximum cascade depth (`D_max`) | 1 | 1–2 | Cascade multiplier (Formula 3) breaks frame budget; increases debugging complexity exponentially | N/A — 0 means no cross-system event chains at all, defeating the purpose |
| Maximum subscribers per event (design guideline) | 6 | 3–8 | Individual event dispatch exceeds per-event chain budget; signals need splitting | Insufficient system coverage; important systems excluded from event |

**Note:** These are design-time planning parameters, not runtime configuration values. They are set once per project architecture decision and revisited only if profiling reveals a sustained frame-budget violation. The `B_event` fraction is particularly likely to need revision when the full 25-system game is first profiled — treat the 10% default as a starting hypothesis.

## Visual/Audio Requirements

*Not applicable — the EventBus is a pure infrastructure layer with no visual or audio output. Visual and audio feedback for game events is the responsibility of the subscribing systems (Mission HUD, Audio System). The EventBus emits the signal; other systems provide the feedback.*

## UI Requirements

*Not applicable — the EventBus has no player-facing UI. Debug tooling (a signal monitor for development builds) may be added as an editor plugin, but that is an implementation concern, not a design requirement.*

## Acceptance Criteria

- [ ] **AC-01** — **GIVEN** all MVP systems are integrated, **WHEN** a static analysis scan searches all `.gd` files for direct system-to-system Autoload references, **THEN** zero instances are found; all cross-system calls route through `EventBus.emit_signal()`.

- [ ] **AC-02** — **GIVEN** Monster System fires `monster_died` from inside `area_body_entered`, **WHEN** 10 monsters are killed in a single physics frame, **THEN** no "Physics body modified outside physics callback" errors appear in the output log.

- [ ] **AC-03** — **GIVEN** the complete `EventBus.gd` signal declaration file, **WHEN** every signal definition is reviewed, **THEN** zero signals use `Dictionary` as a parameter type; all 1–4 field signals use typed primitives, and all 5+ field signals use a `Resource` subclass.

- [ ] **AC-04** — **GIVEN** all MVP systems active, **WHEN** `tower_attacked` fires and triggers the Damage & Status → `monster_damage_taken` cascade, **THEN** Monster System does not emit further events synchronously in that same dispatch cycle; any follow-on emissions are deferred to the next frame.

- [ ] **AC-05** — **GIVEN** a tower node has subscribed to at least one EventBus signal, **WHEN** the tower is destroyed mid-wave, **THEN** no "attempt to call function on a previously freed instance" errors appear when the next subscribed event fires.

- [ ] **AC-06** — **GIVEN** the Godot project is open, **WHEN** Project Settings → Autoloads is inspected, **THEN** `EventBus` is the first entry — no Autoload appears before it.

- [ ] **AC-07** — **GIVEN** a running session where 3 waves have completed, **WHEN** the `EventBus` node is inspected in the remote debugger, **THEN** the node exposes no exported variables, cached data, subscriber counts, or event history — only signal declarations and connection methods.

- [ ] **AC-08** — **GIVEN** the complete `EventBus.gd` signal file, **WHEN** each declared signal is cross-referenced against the 70-event catalogue, **THEN** every signal matches exactly one catalogue entry; no internal-only system signals are present.

- [ ] **AC-09 [Performance]** — **GIVEN** a peak-wave frame with 8 concurrent event types firing, **WHEN** Godot's profiler records 60 consecutive frames, **THEN** total EventBus dispatch time averages ≤ 1.667 ms/frame (10% of 16.67 ms budget), with no single frame exceeding 2.5 ms from EventBus work alone.

- [ ] **AC-10** — **GIVEN** 25 monsters with 1 HP each receive simultaneous AoE damage in one physics frame, **WHEN** the frame resolves, **THEN** the profiler shows `monster_died` firing 0 times and `monsters_died_batch` firing exactly 1 time; Wave Manager's batch accumulator has activated.

- [ ] **AC-11 [Performance]** — **GIVEN** 10 towers fire simultaneously in one frame, **WHEN** `tower_attacked` fires 10 times and Damage & Status processes each, **THEN** `monster_damage_taken` executes in the *following* frame (confirmed by profiler showing both events on separate frame rows), and no frame exceeds the 2.5 ms EventBus ceiling.

- [ ] **AC-12 [Performance]** — **GIVEN** a stress-test wave of 100 simultaneous pathfinding monsters, **WHEN** the wave runs for 60 continuous seconds, **THEN** the game maintains a minimum of 55 FPS on the minimum-spec machine (no frame below 30 FPS), confirmed by profiler FPS graph.

- [ ] **AC-13** — **GIVEN** a tower shot and hero AoE both kill the same monster in the same physics frame, **WHEN** that frame resolves, **THEN** exactly 2 `monster_died` signals fire; no subscriber receives duplicate data; no runtime errors appear.

- [ ] **AC-14** — **GIVEN** the hero's HP reaches 0 during WAVE_ACTIVE, **WHEN** Wave Manager emits `mission_phase_changed` with `new_phase = "DEFEAT"`, **THEN** a test subscriber counting received `mission_phase_changed` events asserts a count of exactly 1; no second emission occurs despite cleanup subscribers running.

- [ ] **AC-15** — **GIVEN** a save file exists and the game loads from it, **WHEN** all Sanctuary system subscribers have called `_ready()`, **THEN** `sanctuary_state_restored` fires no earlier than one frame after all connections are established; all Sanctuary systems reflect saved state — no system initialises with blank defaults that contradict the save file.

> **Test file targets:** `tests/unit/event-bus/` for AC-01–04, AC-07, AC-10. `tests/integration/event-bus/` for AC-13–15. AC-09, AC-11–12 are profiler-run manual tests.

## Open Questions

1. **Minimum-spec machine definition** — AC-09 and AC-12 reference "minimum-spec target machine." The target hardware spec (CPU, GPU, RAM) has not been defined. Required before performance acceptance criteria can be tested. *Owner: Producer/Technical Director. Resolve before Alpha milestone.*

2. **ADR-0002 scope and timing** — Three decisions are flagged as ADR material: deferred/synchronous dispatch policy, payload type contract, Autoload ordering as build invariant. ADR-0002 should be authored before the remaining 24 system GDDs are written, since each will reference these rules. *Owner: Technical Director. Resolve: after EventBus GDD is approved.*

3. **`monsters_died_batch` Resource subclass definition** — The batch dispatch for `monster_died` (EC-9, AC-10) requires a `MonstersDiedBatch` Resource subclass with defined fields. Wave Manager GDD has been authored (2026-04-25); this remains unresolved there as Wave Manager OQ-1. *Owner: Wave Manager GDD. Resolve: before implementation — define payload (`count: int`, `positions: Array[Vector2i]`, `kill_sources: Array[String]`) and confirm Wave Manager subscribes to it in addition to individual `monster_died`.*

4. **Passive skills and secondary events** — Passive slot modifications in Hero Skill Build may need their own EventBus events. Determine whether passive-slot changes are EventBus events or internal to Hero Skill Build. *Owner: Hero Skill Build GDD. Resolve: during Hero Skill Build GDD design.*

5. ~~**`hero_position_changed` granularity**~~ — **RESOLVED (Hero System GDD, 2026-04-21).** Per-cell-boundary emission with `prev_cell != current_cell` O(1) guard in `_physics_process`. No frame throttling needed. Tower Mastery GDD must confirm it can handle cell-resolution granularity.

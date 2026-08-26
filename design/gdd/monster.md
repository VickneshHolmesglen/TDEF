# Monster System

> **Status**: Needs Revision (Approved pass 5 — 2026-05-14; pass 6 — 2026-05-14, re-confirmed with 3 clarifications applied. **Pass 7 (2026-07-15) — `/design-review` full pass [3 specialists + creative-director], triggered by `/review-all-gdds` finding a stale "Wave 4" Overview sentence and a suspected Formula 3 boundary gap. Found something larger: Formula 4's own worked example contained a genuine, previously-undetected monotonicity bug — hidden across 6 prior approval passes by a closing sentence that silently compared against an unrelated 8-wave mission's figure instead of this same 5-wave example's actual final wave.** Fixed same-session: Overview's stale "Wave 4" text corrected to penultimate-wave language; Formula 4's escalation invariant reframed per user design decision (penultimate ELITE must stay below the mission's final-wave BOSS HP, not the following wave's generic STANDARD HP — the old invariant was mathematically unenforceable across the entire `elite_penultimate_wave_hp_amplifier` safe range at low `hp_wave_growth_rate`); the Tuning Knobs co-dependency warning's impossible "1.354" figure corrected; Formula 3's final-wave `base_damage` floor narrowed 40→55 per user design decision (closes an 18-hits-vs-15-target boundary failure at wave 5); Rule 18's Tier 1 "3-5 hits" target rescoped to early-wave bosses only (never achievable against a final-wave boss); AC-44 and AC-45 added. **`/review-all-gdds` re-run (2026-07-15) found a second, larger bug via cross-system scenario walkthrough**: Rule 21f explicitly suppressed `monster_hp_absorbed` on lethal hits, which made lifesteal categorically impossible on any killing blow — directly contradicting `damage-status.md`'s own Rule VII, whose stated purpose is preserving lifesteal on kills. Fixed: Rule 21f no longer erases the lethal hit's `_pending_absorbed` entry; it flushes normally like any other hit. AC-36 corrected to match. **`/review-all-gdds` 4th pass (2026-07-15d)** found Rule 6's spawn payload still listed only 5 fields, omitting `is_penultimate_wave: bool` — self-contradicted this doc's own Formula 4 and disagreed with wave-manager.md/event-bus.md's already-fixed 6-field payload. Fixed same-day: Rule 6 now lists all 6 fields.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-15
> **Implements Pillar**: The Fight Must Be Worth It · Placement is the Puzzle

## Engine Risk Notes (Godot 4.6.2)

| API | Used for | Risk | Status |
|-----|---------|------|--------|
| `Area2D` scene root (`CharacterBody2D` explicitly prohibited) | Monster entity movement | LOW — **pre-emptively mitigated** | This GDD already avoids `CharacterBody2D` because it "pushes co-occupying entities apart" (EC-1.3). That choice, made independent of engine-version concerns, also happens to sidestep any Jolt-as-default (Godot 4.6) collision-response differences `CharacterBody2D` might introduce. No action needed. |
| Edge-detect shader (ELITE tier differentiation) | Visual tier differentiation | LOW | Simple edge/outline effect, not implicated by the glow/bloom rework — no verification needed |

## Overview

The Monster System governs every enemy entity active during a mission: it owns each monster's runtime state (type, tier, current HP, movement speed, active path, attack behavior, and drop table), manages entity lifecycle from spawn through death or breach, and publishes five Monster-owned events — `monster_spawned`, `monster_died`, `boss_died`, `boss_hp_changed`, `monster_breached` — plus emits `boss_tower_attack_attempted` that downstream systems (Wave Manager, Resource Economy, Pathfinding, Mission HUD, Tower System) consume. Monsters exist in three tiers: **STANDARD** enemies that pathfind toward GOAL cells and deal breach damage on arrival; **ELITE** enemies that function as STANDARD enemies with amplified stats and a guaranteed rare material drop, appearing as sub-boss packs on the **penultimate wave** of a mission (the wave immediately before the final BOSS wave — relative to mission length, not a fixed wave index; see Formula 4. **Corrected 2026-07-15** — this sentence previously said "Wave 4," a stale leftover from before the wave-4→penultimate-wave generalization; it was only coincidentally true for 5-wave missions and wrong for 6–8 wave missions); and **BOSS** enemies that are unique, named entities with high HP and active tower-attack behavior. The Monster System does not own pathfinding — it consumes a pre-built path from the Pathfinding System and steps monsters along it each physics frame. It does not own damage resolution — it publishes `monster_died` and emits the `boss_tower_attack_attempted` event, and the Damage & Status System resolves incoming hits. Material drops are not resolved by the Monster System — `monster_died` triggers the Resource Economy System to calculate and issue drops. The Monster System is active exclusively during `WAVE_ACTIVE` phase; it initialises from `wave_started` events published by the Wave Manager and processes all active entities until `wave_completed` is received. Without the Monster System, the game has no pressure source, no material economy, and no win condition check — towers would have nothing to shoot at, and the hero would have nothing to fight.

## Player Fantasy

*Monsters are not the fantasy — they are the resistance and the reward that resistance provides.*

Monsters carry the stakes and the spoils. Their approach is what makes a tower placement feel decisive rather than decorative, and their death is what makes the fight worth it — the materials, the cleared lane, the moment the player's plan visibly worked. The player never fantasizes about being a monster or fighting monsters abstractly; they fantasize about their strategy meeting resistance and prevailing. The Monster System is the resistance and the reward that resistance provides.

## Detailed Design

### Core Rules

#### Group 1: Monster Entity Data Schema

1. Every monster instance on the field is defined by a **MonsterResource** — a Godot `Resource` subclass stored in `assets/data/monsters/`. The resource is the authoring-time definition; the runtime entity is a scene instance that reads from it at spawn. The resource is immutable during play; the runtime entity holds mutable state.

2. The **MonsterResource schema** (all fields required at MVP):

   | Field | Type | Description |
   |-------|------|-------------|
   | `monster_id` | `StringName` | Unique identifier (e.g., `&"goblin_runner"`) |
   | `display_name` | `String` | Human-readable name for HUD / codex |
   | `tier` | `int` enum | 0=STANDARD · 1=ELITE · 2=BOSS |
   | `archetype_tag` | `StringName` | Optional gameplay tag. Empty `StringName` if untagged. **Supported MVP values:** `&"armored"` — D&S applies 50% tower damage mitigation (tower hits deal half damage; hero damage is unaffected). `&""` (default) — no modification. Additional tags reserved for post-MVP. **Also the lookup key for `FoundationComponent.bonus_damage_vs_tags` (`tower.md`, Tower Stats System Phase 1, 2026-08-16) — a tower can author bonus damage against any `archetype_tag` value, not just "armored".** **Implementation note:** `TowerSystem`'s own monster cache did not actually read this field until 2026-08-16 — every monster was silently treated as unarmored in real gameplay before that fix (see `tower.md`'s Dependencies table, Tower Attacked row). |
   | `elemental_resistances` | `Dictionary` | **Added Tower Stats System Phase 1 (2026-08-16).** `StringName` element (`"fire"`/`"frost"`/`"poison"`/`"lightning"`/`"arcane"`, matching `WeaponComponent.element`) → `float` resist fraction `[0.0, 0.9]`. Missing key = `0.0` (no resistance) — fully backward-compatible, no data migration for existing monster content. Read by `TowerSystem`'s monster cache and applied in its damage-resolution formula (`tower.md` Formula 1b); physical hits (`element == ""`) never consult this. |
   | `base_hp` | `float` | HP at wave 1, difficulty Normal. Scaled at runtime. |
   | `base_speed` | `float` | Path traversal speed in grid-cells/second at wave 1. |
   | `base_damage` | `float` | BOSS only: base damage per tower attack. Set to 0 for STANDARD/ELITE. |
   | `base_attack_interval` | `float` | BOSS only: seconds between attack attempts. Set to 0 for STANDARD/ELITE. |
   | `boss_attack_range_cells` | `float` | BOSS only: Chebyshev cell radius for tower targeting. Set to 0 for STANDARD/ELITE. |
   | `drop_table_id` | `StringName` | References a Resource Economy drop table. Passed as-is in `monster_died`; Monster System does not read it. |
   | `menagerie_attraction_drop_chance` | `float` | 0.0–1.0. Chance this monster type drops a rare Menagerie-attraction material on death. Shared by all tiers; rarity scaling deferred to Resource Economy GDD. |
   | ~~`hero_damage_bonus_eligible`~~ | ~~`bool`~~ | **Deprecated — do not use.** D&S now derives the hero damage tier from the entity's `tier` field (0=STANDARD, 1=ELITE, 2=BOSS) at attack-roll time via `hero_bonus_tier: int` in `HeroAutoAttackEvent`. This field is dead weight and must not be read by any system. Retain in the schema for a migration window; remove after Hero GDD and EventBus GDD are updated. |
   | `sprite_frames` | `SpriteFrames` | Required animations: `"walk"`, `"death"`. BOSS additionally requires `"attack"` and **`"attack_prepare"`** (the telegraph animation, see Rule 17d). |
   | `death_vfx_scene` | `PackedScene` | One-shot VFX scene instantiated at death position. |

3. MonsterResource data lives in `assets/data/monsters/`. Each monster type has exactly one `.tres` file. Tuning (HP, speed, damage, drop chance) is done by editing resource files — never hardcoded in scripts.

4. The MVP supports **5–8 distinct monster types**, each with one MonsterResource. All types must be authored before the first playable build. The Wave Manager references types by `monster_id`.

5. A **runtime monster entity** holds this mutable state alongside its MonsterResource reference. **Scene root node: `Area2D`** — movement is position-based (`global_position` set directly); `CharacterBody2D` is prohibited as it pushes co-occupying entities apart (violates EC-1.3).

   | Field | Type | Description |
   |-------|------|-------------|
   | `entity_id` | `int` | Unique instance ID, monotonically incrementing per mission. Never recycled within a mission. |
   | `current_hp` | `float` | Starts at `scaled_hp`. |
   | `scaled_hp` | `float` | Immutable after spawn. `base_hp × wave_hp_multiplier × difficulty_hp_multiplier`. |
   | `scaled_speed` | `float` | Immutable after spawn. `base_speed × wave_speed_multiplier`. |
   | `current_path` | `Array[Vector2i]` | Ordered cells from current position to nearest GOAL. Populated at spawn; refreshed on path invalidation. |
   | `path_step_index` | `int` | Index into `current_path` of the cell the monster is currently moving toward. |
   | `lifecycle_state` | `int` enum | SPAWNING / ACTIVE / DEAD / BREACHED |
   | `boss_attack_cooldown_remaining` | `float` | BOSS only: seconds until next attack attempt. Starts at 0 (BOSS can attack immediately on ACTIVE). |
   | `boss_attack_prepare_remaining` | `int` | BOSS only: frames remaining in the `"attack_prepare"` animation before `boss_tower_attack_attempted` emits. 0 = ready to fire. Set to `boss_attack_prepare_frames` when attack conditions are first met. |
   | `boss_scan_frames_remaining` | `int` | BOSS only: frames remaining until the next targeting scan executes. Initialized to `0` on ACTIVE entry — scan fires on the very first BOSS Logic Pass. Decremented once per BOSS Logic Pass when `> 0`. Reset to `boss_scan_interval_frames` after each scan fires. |
   | `_locked_target_id` | `int` | BOSS only: `tower_id` of the tower selected when the prepare phase was entered. Carries the target across the prepare countdown so the fire step (Rule 17d.1) attacks the correct tower. Initialized to `-1` (no target). Set when `boss_attack_prepare_remaining` is first written. Cleared back to `-1` after `boss_tower_attack_attempted` fires. |
   | `last_hit_source` | `String` | `"hero"` or `"tower"`. Derived from `source_type` in `monster_damage_taken` (0→`"tower"`, 1→`"hero"`); used to populate `kill_source` in `monster_died`. |
   | `spawn_wave_reward_scalar` | `float` | Cached from the spawning `monster_spawn_requested.wave_reward_scalar` at spawn. Forwarded as-is in `monster_died` payload for Resource Economy. Never applied to combat stats. |

---

#### Group 2: Spawn Behavior

6. Monster spawning is initiated exclusively by the **Wave Manager** via the EventBus event `monster_spawn_requested`. Payload (typed Resource subclass — 6 fields): `monster_id: StringName`, `spawn_cell: Vector2i`, `wave_index: int`, `difficulty_tier: int`, `wave_reward_scalar: float`, `is_penultimate_wave: bool`. Monster System subscribes to this event. It does not self-initiate spawning. **Monster System must not apply `wave_reward_scalar` to combat stats.** Monster System caches it in `spawn_wave_reward_scalar` at spawn and forwards it in `monster_died` so Resource Economy can scale drop resolution by wave difficulty.

7. On receiving `monster_spawn_requested`, the Monster System:
   - a. Looks up the MonsterResource for `monster_id`. If not found: logs an error, aborts — no entity created, no event emitted.
   - b. Confirms `spawn_cell` is a `SPAWN`-typed cell via `Grid.get_cell_type(spawn_cell)`. If not: logs an error, aborts.
   - b.1. Checks `active_monsters.size() < MAX_ACTIVE_MONSTERS`. If at cap: logs `"[MonsterSystem] WARN: active_monsters at cap ({MAX_ACTIVE_MONSTERS}). Spawn of '{monster_id}' discarded."`, aborts — no entity created.
   - c. Calculates `scaled_hp` and `scaled_speed` using wave and difficulty multipliers (see Formulas).
   - d. Instantiates the monster scene, assigns a new `entity_id`, sets `lifecycle_state = SPAWNING`.
   - e. Requests the initial path from the Pathfinding System (see Rule 10).
   - f. Sets `lifecycle_state = ACTIVE`, adds to `active_monsters`, emits `monster_spawned`.
   - g. Applies any active Tarot `"monster_speed_scalar"` modifier to `scaled_speed`.
   - h. Caches `spawn_wave_reward_scalar = wave_reward_scalar` on the entity instance.

8. The Monster System maintains two flat lists, one input buffer, and two frame-scoped accumulators:
   - `active_monsters: Array[MonsterEntity]` — entities in ACTIVE state. Cleared when `wave_started` fires.
   - `spawning_entities: Array[MonsterEntity]` — entities whose initial path request has not yet returned (still in SPAWNING). Maintained separately so `wave_completed` force-removal can clean them up without touching `active_monsters`.
   - `_pending_damage: Array[MonsterDamageTaken]` — input buffer for incoming damage events. The EventBus handler for `monster_damage_taken` appends to this buffer immediately (does NOT apply damage on receipt). The damage pass in `_physics_process` drains this buffer sequentially, applying each event in order. Cleared at the end of the damage pass each frame. This ensures all damage resolution happens within the damage pass, not interleaved with movement or absorbed flush.
   - `_pending_absorbed: Dictionary[int, float]` — Monster System-level accumulator (not per-entity). Accumulates total `absorbed` HP per `entity_id` during a physics frame. Flushed at end of `_physics_process` as one `monster_hp_absorbed` event per entry. **Frame-scoped: cleared after flush every `_physics_process` frame** (not only on `wave_completed`). On `wave_completed`, any residual entries are cleared before idle transition (handles the edge case where `wave_completed` fires mid-frame before the flush pass runs). An entity is never in this map when `lifecycle_state == DEAD`.

9. Multiple monsters may share the same `spawn_cell` simultaneously. PATH cells are not occupation-exclusive for monsters.

---

#### Group 3: Movement and Pathfinding Contract

10. Monster System does **not** own pathfinding or the navmesh. It consumes path data from the Pathfinding System via direct API call: `PathfindingSystem.get_path(from_cell: Vector2i, tier: int) -> Array[Vector2i]`. Called once at spawn, and again when path invalidation is signaled. An empty returned array means no valid path — see Edge Cases.

11. Monster movement executes in `_physics_process(delta)`. Each active monster advances along `current_path` based on `scaled_speed` (cells per second):
    - a. Compute target world position: `Grid.cell_to_world(current_path[path_step_index])`.
    - b. Move entity toward target at *effective speed* units/second — `scaled_speed × Π(active slow speed_multiplier instances)` (damage-status.md Formula D6, amended 2026-08-13). `scaled_speed` itself is read here, never mutated — it remains the same immutable-after-spawn value described above regardless of how many slow instances are active or expire. With no active slow instances, effective speed equals `scaled_speed` exactly, so this is a pure extension of the existing rule, not a behavior change for any non-slowed monster.
    - c. When within `PATH_ARRIVAL_THRESHOLD` world units of the target position, increment `path_step_index` by 1.
    - d. If `path_step_index >= current_path.size()`: GOAL cell reached — trigger breach resolution (Rule 24).

12. If `scaled_speed` causes the monster to overshoot the next cell in a single frame, the arrival check fires for every overshot step within that frame (loop until no further overshoot or GOAL reached).

13. On receiving `path_invalidated` event from the Pathfinding System (payload: `affected_cells: Array[Vector2i]`), any monster whose `current_path` contains an affected cell must request a fresh path from `Grid.world_to_cell(entity.global_position)`. Monsters with unaffected paths continue unchanged.

---

#### Group 4: Attack Behavior

14. **STANDARD monsters do not attack towers.** Movement toward GOAL cells is their only behavior. `base_damage`, `base_attack_interval`, and `boss_attack_range_cells` are set to 0 in the resource and never read at runtime.

15. **ELITE monsters do not attack towers.** Behavior is identical to STANDARD regarding tower interaction. ELITE monsters differ from STANDARD in: higher HP/speed multipliers, `tier = 1` (ELITE) which causes D&S to apply the 150% hero damage multiplier via `hero_bonus_tier = 1` in the attack payload, and guaranteed rare material drop via `drop_table_id`.

16. **BOSS monsters attack towers while walking.** A BOSS never stops moving to attack. Movement and attack logic run simultaneously in `_physics_process`. There is no exclusive "attacking" state that halts movement.

17. BOSS attack logic per physics frame:
    - a. Tower scan throttle: scan executes only when `boss_scan_frames_remaining <= 0`. Each BOSS Logic Pass: **first decrement** (if `> 0`), **then scan-check** (if `≤ 0`) — these are two independent sequential checks, not an if-else. When decrement brings the value to 0, the scan fires in the same pass. Reset to `boss_scan_interval_frames` after each scan. This prevents a per-BOSS `Grid.get_towers_in_range()` call every single frame. See EC-3.1 and AC-37 for the definitive ordering spec.
    - b. When scan executes: `Grid.get_towers_in_range(boss_cell, boss_attack_range_cells) -> Array[tower_id]`.
    - c. If no towers in range: do nothing. Cooldown is NOT reset — it remains at its current value (including 0 if the BOSS was primed). *(Design decision: the BOSS stays primed and fires immediately when a tower next enters range. This rewards players who understand BOSS behavior but does not offer a "pull out of range to reset aggression" window. See EC-5.1.)*
    - d. If towers in range AND `boss_attack_cooldown_remaining <= 0` AND `boss_attack_prepare_remaining <= 0`:
      - Select the **closest tower by Chebyshev distance** from the BOSS's current grid cell. Tiebreaker: first in returned array. *(Closest-tower targeting is intentional: the BOSS always attacks the most immediate spatial threat. Players who understand this rule can place cheap towers adjacent to the BOSS's path to absorb hits — this is an accepted consequence of closest-distance targeting. If a future BOSS archetype requires different targeting behavior, it should be a distinct MonsterResource, not a change to this rule.)*
      - Set `boss_attack_prepare_remaining = boss_attack_prepare_frames`. Set `_locked_target_id = selected_tower_id`. Play `"attack_prepare"` animation on the overlay `AnimatedSprite2D`. Do NOT emit `boss_tower_attack_attempted` yet — the prepare phase is the player-readable attack telegraph.
    - d.1. If `boss_attack_prepare_remaining > 0`: decrement by 1. When it reaches 0: emit `boss_tower_attack_attempted` (payload: `boss_entity_id: int`, `target_tower_id: int = _locked_target_id`, `base_damage: float`). Reset `boss_attack_cooldown_remaining = base_attack_interval`. Clear `_locked_target_id = -1`. Play `"attack"` animation on overlay `AnimatedSprite2D`; movement continues uninterrupted.
    - e. Decrement `boss_attack_cooldown_remaining` by `delta` each frame, clamped to 0.

18. Monster System emits `boss_tower_attack_attempted` and does nothing further regarding tower damage. The Tower System subscribes to this event and applies `base_damage` directly to the target tower's HP (no mitigation, MVP decision). Boss attack damage must be designed within `tower_hp_boss_damage_provisional_range` [40–200 HP/hit]. **Scoping corrected 2026-07-15**: the "Tier 1 towers fall in 3–5 hits" target applies to **early-wave bosses only** (base_damage 15–25) — a final-wave boss (base_damage 55–80) always kills a Tier 1 tower in 1–2 hits at any legal authored value, since final-wave `base_damage` starts well above the range needed for a 3–5 hit kill against Tier 1's 80 HP; this was never actually achievable and the prose previously stated it without that scope. The "Tier 4 towers survive 8–15 hits" target applies to **final-wave bosses** (see Formula 3's calibration table).

19. A BOSS will attempt to attack a tower even on the frame it breaches. Attack check executes before breach check in the same frame.

---

#### Group 5: Death Resolution

20. Monster HP reaches 0 as a result of incoming damage resolved by the Damage & Status System. D&S emits `monster_damage_taken` (`MonsterDamageTaken` Resource — 5 fields: `entity_id: int`, `amount: int`, `source_type: int`, `is_crit: bool`, `hero_bonus_tier: int`). `hero_bonus_tier` values: 0 = no tier bonus (tower hit or STANDARD target), 1 = ELITE tier, 2 = BOSS tier. Updated from `hero_bonus_applied: bool` in the D&S GDD revision 2026-05-12. Monster System subscribes to this event. Monster System does not perform any damage arithmetic. `source_type` mapping: `0 = "tower"`, `1 = "hero"`.

21. On `monster_damage_taken` received:
    - a. Update `last_hit_source`: if `source_type == 1` set `"hero"`, else set `"tower"`.
    - b. Record `pre_hit_hp: float = current_hp` before modifying HP.
    - c. Subtract `amount` from `current_hp`.
    - d. If `current_hp > 0` AND entity is a BOSS: emit `boss_hp_changed` (payload: `entity_id: int`, `current_hp: float`, `max_hp: float`).
    - e. Accumulate `_pending_absorbed[entity_id] += min(amount, pre_hit_hp)`, **regardless of whether this hit is lethal**. This entry is flushed at the end of the current `_physics_process` frame as a single `monster_hp_absorbed` event, in the same end-of-frame absorbed-flush pass as any non-lethal hit. Multiple hits on the same entity in one frame sum into one event — no coroutine is allocated.
    - f. If `current_hp <= 0`: trigger death sequence. The entity's `_pending_absorbed` entry (accumulated in step e, including the killing blow's own absorbed amount) is **not** erased — it still flushes normally in the absorbed flush pass below, so a lethal hit's `monster_hp_absorbed` fires exactly like a non-lethal one. *(Corrected 2026-07-15 — `/review-all-gdds`: this rule previously erased the entry and explicitly suppressed `monster_hp_absorbed` on lethal hits. That made lifesteal categorically impossible on any killing blow, directly contradicting `damage-status.md`'s own Rule VII, whose stated purpose is "preserve lifesteal heals on the killing blow of a wave" — Rule VII's 1-frame defer logic was defending against a race for an event that could never fire in the first place. Since a lethal hit's `absorbed` is well-defined — `min(amount, pre_hit_hp) == pre_hit_hp` when the hit is lethal — there was no technical reason to suppress it; only this rule's own erase-before-flush behavior blocked it.)*

**`_pending_absorbed` flush (pass 4 of `_physics_process`):** For each `(entity_id, total_absorbed)` in `_pending_absorbed`: emit `monster_hp_absorbed` (payload: `entity_id: int`, `absorbed: int = floor(total_absorbed)`). Then clear `_pending_absorbed` entirely. This dictionary is **frame-scoped** — it is always cleared after the flush, not persisted between frames. The `wave_completed` handler also clears `_pending_absorbed` as a safety measure for the edge case where `wave_completed` fires before the flush pass of the current frame completes. This guarantees at most one `monster_hp_absorbed` per entity per frame regardless of how many hits arrived.

22. Death sequence:
    - a. Set `lifecycle_state = DEAD`. Remove from `active_monsters`. Stop all movement and attack logic.
    - b. Play `"death"` animation via base-layer `AnimatedSprite2D`. Stop overlay-layer `AnimatedSprite2D`. Instantiate `death_vfx_scene` at world position (deferred — queue as a deferred call to avoid instantiating during physics callback).
    - c. If tier is BOSS: emit `boss_died` (payload: `entity_id: int`, `monster_id: StringName`, `wave_index: int`, `cause: String = "killed"`) first, then emit `monster_died`.
    - d. All tiers: emit `monster_died` (payload: `entity_id: int`, `monster_id: StringName`, `tier: int`, `drop_table_id: StringName`, `menagerie_attraction_drop_chance: float`, `world_position: Vector2`, `kill_source: String`, `wave_reward_scalar: float`). This is an 8-field event and requires a typed Resource subclass per EventBus Core Rule 4. `wave_reward_scalar` is forwarded from `spawn_wave_reward_scalar` — Resource Economy uses it to scale drop resolution; Monster System does not interpret it.
    - e. Queue free the entity node after death animation completes.

**Note — `monster_died` batching (corrected 2026-07-31, ADR-0033):** Monster System owns batch accumulation and is the sole emitter of both signals — this note previously assigned that ownership to Wave Manager, which was found to be structurally impossible (Wave Manager cannot retroactively suppress individual `monster_died` events it has already received without breaking the mutual-exclusivity guarantee `resource-economy.md`/ADR-0017 depends on). Monster System buffers each frame's death payloads internally and, at frame end, emits `monster_died` synchronously per entity **unless** the frame's death count exceeds `eventbus_batch_threshold` (20, per `event-bus.md` Formula 2), in which case it emits exactly one `monsters_died_batch` instead — the two signals are mutually exclusive per frame, never both fire for the same kill. Wave Manager remains a subscriber to both signals only. See EventBus GDD AC-10, Formula 2, EC-9, and ADR-0033.

*(Rule 23 was deleted during the 2026-04-26 review — `monster_died` batch accumulation responsibility was moved to Wave Manager, then corrected back to Monster System 2026-07-31 per ADR-0033. Rule 24 follows.)*

---

#### Group 6: Breach Resolution

24. When `path_step_index >= current_path.size()` (monster reached GOAL cell):
    - a. Set `lifecycle_state = BREACHED`. Remove from `active_monsters`. Stop all movement and attack logic.
    - b. Emit `monster_breached` (payload: `entity_id: int`, `monster_id: StringName`, `tier: int`).
    - c. Queue free the entity node immediately. No death animation plays on breach.

25. Breach is not a damage event. Hero HP does not change on breach. The breach counter is maintained by the Mission HUD System from `monster_breached` events — Monster System does not own or track this counter.

---

#### Group 7: Wave State Contract

26. Monster System is **idle outside `WAVE_ACTIVE` phase**. No entity processing, no spawn handling, no `_physics_process` logic during `SCOUT`, `INTERMISSION`, `OUTCOME`, or `DEFEAT`.

27. On `wave_started` received (payload: `wave_index: int`):
    - a. Clear `active_monsters` (defensive safety).
    - b. Reset `entity_id` counter if `wave_index == 1`. Continue incrementing for subsequent waves.
    - c. Begin processing `monster_spawn_requested` events and running entity `_physics_process`.

28. On `wave_completed` received:
    - a. Any monsters remaining in `active_monsters` are force-removed: set `lifecycle_state = DEAD`, queue free. Entities in `spawning_entities` are also queue-freed silently.
    - b. If the force-removed entity is a BOSS: emit `boss_died` (payload: `entity_id: int`, `monster_id: StringName`, `wave_index: int`, `cause: String = "force_removed"`) before `monster_died`.
    - c. Emit `monster_died` for each force-removed entity with `kill_source = "wave_end"`. **No drops resolve for force-removed monsters — neither standard materials (`drop_table_id`) nor the Menagerie-attraction rare drop.** Force-removal is symmetric with breach: kills that were not earned by the player forfeit all economy rewards.
    - d. Monster System transitions to idle.

29. Monster System does **not** track wave completion. It does not count active monsters against a wave total. Wave completion is always signaled by `wave_completed` from Wave Manager.

---

#### Group 8: Tarot Modifier Handling

30. Monster System subscribes to `mission_modifier_applied` (fires during SCOUT phase before `wave_started`). Recognized modifier types:
    - `"monster_speed_scalar"`: Multiplies all entities' `scaled_speed` by `modifier_value` at instantiation.
    - `"elite_frequency_scalar"`: Applied by Wave Manager when composing spawn lists — Monster System does not read this modifier.
    - Any unrecognized `modifier_type`: silently ignored.

---

### States and Transitions

| State | Entry Condition | Active Behaviors | Terminal? |
|-------|----------------|-----------------|-----------|
| `SPAWNING` | `monster_spawn_requested` received; entity instantiated | Path request pending. No movement, attack, or targeting. | No |
| `ACTIVE` | Path received; `monster_spawned` emitted | Movement (all tiers) + tower attack (BOSS only). Susceptible to `monster_damage_taken`. | No |
| `DEAD` | `current_hp <= 0` after `monster_damage_taken`, or `wave_completed` force-removal | Death anim plays (if killed, not forced); `monster_died` emitted; queued for free. | Yes |
| `BREACHED` | `path_step_index >= current_path.size()` | `monster_breached` emitted; node freed immediately. No death anim. | Yes |

| From | To | Trigger | System Action |
|------|----|---------|--------------|
| — | `SPAWNING` | `monster_spawn_requested` | Instantiate entity; assign `entity_id`; calculate scaled stats; request path |
| `SPAWNING` | `ACTIVE` | Path returned from Pathfinding | Add to `active_monsters`; emit `monster_spawned` |
| `ACTIVE` | `DEAD` | `current_hp <= 0` from `monster_damage_taken` | Remove from list; play death anim; emit `boss_died` (BOSS tier) then `monster_died` |
| `ACTIVE` | `BREACHED` | GOAL cell reached | Remove from list; emit `monster_breached`; immediately free node |
| `ACTIVE` | `DEAD` (force) | `wave_completed` | Remove from list; free node; emit `monster_died` with `kill_source="wave_end"` |
| `DEAD` | freed | Death animation complete | Queue free node |
| `BREACHED` | freed | Immediate on breach | Node freed immediately |

---

### Interactions with Other Systems

| System | Direction | Data / Interface | Mechanism | When |
|--------|-----------|-----------------|-----------|------|
| **EventBus** | Monster → emits | `monster_spawned`, `monster_died`, `boss_died`, `boss_hp_changed`, `boss_tower_attack_attempted`, `monster_breached`, `monster_hp_absorbed` | EventBus signal | At spawn, death, boss death, boss HP change, boss attack, breach, and end-of-frame absorbed flush |
| **EventBus** | Monster ← subscribes | `wave_started`, `wave_completed`, `mission_phase_changed`, `mission_modifier_applied`, `monster_damage_taken`, `monster_spawn_requested`, `path_invalidated` | EventBus signal | Subscribed at Monster System initialisation |
| **Grid** | Grid → Monster (read) | `get_cell_type()`, `get_spawn_cells()`, `cell_to_world()`, `world_to_cell()`, `get_towers_in_range()` | Direct read API (Grid Autoload) | Per-frame (movement, GOAL detection, BOSS targeting) and at spawn |
| **Pathfinding** | Pathfinding → Monster (read) | `PathfindingSystem.get_path(from_cell, tier) -> Array[Vector2i]` | Direct API call | Once per entity at spawn; again on `path_invalidated` |
| **Wave Manager** | Monster → Wave Manager | Subscribes to `monster_died`, `boss_died` to track wave-clear condition | EventBus events consumed by Wave Manager | Per monster death during WAVE_ACTIVE |
| **Damage & Status** | Bidirectional | D&S resolves damage from `tower_attacked` and hero attacks → emits `monster_damage_taken` → Monster applies to `current_hp`, accumulates into `_pending_absorbed`, flushes `monster_hp_absorbed` at end of frame | `monster_damage_taken` (D&S → Monster) and `monster_hp_absorbed` (Monster → D&S) EventBus events | Per hit during WAVE_ACTIVE |
| **Tower System** (status effects) | Tower → Monster (direct, not via D&S) | Monster subscribes to `tower_attacked` a second time, independent of D&S, reading only `effect_type`/`effect_value`/`effect_duration` (a tower's `PowerComponent` fields) to apply burn/poison DoT (Formula D5) and slow speed reduction (Formula D6, added same day follow-up) — see damage-status.md Rule I.1's second named exception. Slow never mutates `scaled_speed` (stays immutable after spawn) — Pass 3 reads effective speed via a new `_effective_speed()` helper instead. | `tower_attacked` EventBus event | Per tower hit carrying a recognized `effect_type` during WAVE_ACTIVE; added 2026-08-13 as Pass 1b in the ADR-0006-amended 5-pass `_physics_process` |
| **Tower System** | Monster → Tower | Emits `boss_tower_attack_attempted` (`boss_entity_id`, `target_tower_id`, `base_damage`); Tower System applies `base_damage` directly to tower HP (no mitigation, MVP) | EventBus event | Per boss attack action during WAVE_ACTIVE |
| **Resource Economy** | Monster → Economy | `monster_died` payload includes `drop_table_id` and `menagerie_attraction_drop_chance`; Economy resolves material drops and Menagerie-attraction material chance | `monster_died` EventBus event | Per monster death (normal and wave-end force-removal) |
| **Mission HUD** | Monster → HUD | `monster_spawned` (increment counter), `monster_died` (decrement), `boss_died` (victory display), `monster_breached` (increment breach counter display) | EventBus events | Continuously during WAVE_ACTIVE |
| **Hero System** | Hero → Monster (indirect) | Hero attacks routed through D&S; Hero System reads target `tier` at attack-roll time and passes `hero_bonus_tier: int` (0=STANDARD, 1=ELITE, 2=BOSS) in `HeroAutoAttackEvent`; D&S applies the tier multiplier, resolves, emits `monster_damage_taken` | Via D&S / EventBus | Per hero attack during WAVE_ACTIVE |
| **Tarot System** | Tarot → Monster | `mission_modifier_applied` with `"monster_speed_scalar"` type; Monster reads and stores scalar | EventBus event | SCOUT phase, before `wave_started` |
| **Constellation** | Monster → Constellation | `monster_died` with `kill_source: "tower"` — Constellation credits tower kills for pattern bonuses | `monster_died` EventBus event | Per tower-sourced kill |
| **Menagerie** | Monster → Menagerie (indirect) | `menagerie_attraction_drop_chance` in `monster_died` → Resource Economy resolves drop → Inventory receives material → Player uses at Menagerie | Via Resource Economy and Inventory | Per monster death where drop resolves |

## Formulas

### Formula 1 — Monster HP Scaling

```
scaled_hp = base_hp × wave_hp_multiplier × difficulty_hp_multiplier

wave_hp_multiplier       = 1 + (hp_wave_growth_rate × (wave_index - 1))
difficulty_hp_multiplier = 1 + (hp_difficulty_growth_rate × (difficulty_tier - 1))
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `base_hp` | float | 40–800 | HP at wave 1, Normal difficulty. Authored per MonsterResource. |
| `wave_index` | int | 1–8 | Current wave number within the mission. |
| `difficulty_tier` | int | 1–3 | Player-selected difficulty: 1=Normal, 2=Hard, 3=Brutal. |
| `hp_wave_growth_rate` | float | 0.12–0.20 | Per-wave fractional HP increase. Tuning knob. Default: 0.15 |
| `hp_difficulty_growth_rate` | float | 0.25–0.50 | Per-difficulty-tier fractional HP increase. Tuning knob. Default: 0.35 |
| `wave_hp_multiplier` | float | 1.00–2.40 | HP scale factor from wave progression. |
| `difficulty_hp_multiplier` | float | 1.00–2.00 | HP scale factor from difficulty selection. |
| `scaled_hp` | float | 40–3840 | Immutable HP assigned at spawn. Floored at 1.0. |

**Output range (at reference rates):** 1.0×–3.49× base_hp  
**Design note:** Linear HP scaling per wave (not exponential) keeps time-to-kill ratios stable across the mission. Exponential HP inflation produces damage-sponge late waves — a known negative feedback pattern in tower defense.

**Worked examples:**

| Scenario | base_hp | Multipliers | scaled_hp |
|----------|---------|-------------|-----------|
| Wave 1, Normal, STANDARD | 60 | 1.00 × 1.00 | 60 |
| Wave 4, Normal, ELITE (before Wave 4 amp) | 300 | 1.45 × 1.00 | 435 |
| Wave 8, Brutal, heavy ELITE | 300 | 2.05 × 1.70 | 1,045 |

---

### Formula 2 — Monster Speed Scaling

```
scaled_speed = base_speed × wave_speed_multiplier × tarot_speed_scalar

wave_speed_multiplier = 1 + (speed_wave_growth_rate × (wave_index - 1))
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `base_speed` | float | 0.5–3.0 | Path traversal speed in grid-cells/second at wave 1. Authored per MonsterResource. |
| `wave_index` | int | 1–8 | Current wave number within the mission. |
| `speed_wave_growth_rate` | float | 0.04–0.10 | Per-wave fractional speed increase. Tuning knob. Default: 0.06 |
| `wave_speed_multiplier` | float | 1.00–1.70 | Speed scale from wave progression. |
| `tarot_speed_scalar` | float | 0.50–2.00 | Tarot modifier from `mission_modifier_applied`. Defaults to 1.0 if no modifier active. |
| `scaled_speed` | float | 0.25–10.2 | Immutable speed assigned at spawn. Floored at 0.1 cells/sec. |

**Output range:** 0.25–10.2 cells/sec (Tarot extreme case: base_speed=3.0, max wave, tarot=2.0)  
**Design note:** Speed grows slower than HP (0.06 vs. 0.15 per wave) by design. Speed spikes are reserved for Tarot modifiers as an opt-in risk; natural scaling escalates endurance, not movement threat.

> **Tarot application:** `tarot_speed_scalar` is applied as a post-calculation step in Rule 7g (after the base formula computes using `tarot_speed_scalar = 1.0`). Formula 2 shows the full combined expression. Whether implemented as one pass or two sequential steps, the result is identical — AC-39 defines the observable contract.

**Worked examples:**

| Scenario | base_speed | Multipliers | scaled_speed |
|----------|------------|-------------|--------------|
| Wave 1, no Tarot, slow STANDARD | 0.8 | 1.00 × 1.00 | 0.80 cells/sec |
| Wave 8, +50% Tarot modifier, fast ELITE | 2.0 | 1.42 × 1.50 | 4.26 cells/sec |
| Wave 4, no Tarot, medium ELITE (before amp) | 1.5 | 1.18 × 1.00 | 1.77 cells/sec |

---

### Formula 3 — BOSS Attack Damage

**Two BOSS calibration tiers** — early-wave and final-wave BOSSes use different `base_damage` values. The registered `tower_hp_boss_damage_provisional_range` [40–200 HP/hit] applies to **final-wave BOSSes** only.

```
boss_effective_damage = base_damage × boss_damage_phase_multiplier

boss_damage_phase_multiplier = 1 + (boss_dmg_wave_growth_rate × (wave_index - 1))
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `base_damage` | float | 15–80 | Flat damage per tower attack at wave 1. Authored per BOSS MonsterResource. Early-wave BOSSes: 15–25. Final-wave BOSSes: **55–80** (narrowed from 40–80, corrected 2026-07-15 — see calibration note below). |
| `wave_index` | int | 1–8 | Wave on which this BOSS appears. Final-wave BOSSes appear on waves 5–8. |
| `boss_dmg_wave_growth_rate` | float | 0.08–0.15 | Per-wave fractional damage increase. Tuning knob. Default: 0.10 |
| `boss_damage_phase_multiplier` | float | 1.00–2.05 | Damage scale factor from wave timing. |
| `boss_effective_damage` | float | 15–136 | Flat HP subtracted from target tower per attack. No mitigation at MVP. (136 = 80 × 1.70 at default rates. The registry-era value of 164 reflected tuning-ceiling rates, not defaults — corrected 2026-05-11.) |

**Calibration verification (corrected 2026-07-15 — the prior table only checked one boundary and missed a failing combination; `base_damage`'s final-wave floor was narrowed from 40 to 55 as a result — see below):**

| BOSS tier | wave | base_damage | boss_effective_damage | Tier 1 (80 HP) | Tier 4 (1000 HP) |
|-----------|------|-------------|----------------------|----------------|------------------|
| Early-wave | 2 | 20 | 22 HP/hit | 4 hits ✓ (early-wave target) | 46 hits (expected — Tier 4 not yet placed) |
| Final-wave, floor | 5 | 55 | 77 HP/hit | 2 hits (Tier 1 not scoped to this target — see Rule 18) | 13 hits ✓ |
| Final-wave | 8 | 50 | 85 HP/hit | 1 hit (Tier 1 not scoped to this target) | 12 hits ✓ |
| Final-wave, ceiling | 8 | 80 | 136 HP/hit | 1 hit (Tier 1 not scoped to this target) | 8 hits ✓ (design ceiling) |

**Boundary-value correction (2026-07-15, `/design-review`):** the prior table checked only wave=8/base_damage=50, which obscured a real boundary failure — at the earliest legal final-wave point (wave=5, `base_damage`=the prior floor of 40), `boss_effective_damage = 40 × 1.40 = 56`, giving `ceil(1000/56) = 18` hits against a Tier 4 tower, above the documented 8–15 hit target. Rather than loosen the target (which would let a final-wave boss feel passive/inert on its earliest legal wave — a Player Fantasy concern, not just a math one), the final-wave `base_damage` floor was raised 40→55, which brings the worst case to 13 hits, inside target. **The Tier 1 "3–5 hits" target in Rule 18 was never actually achievable against a final-wave boss at any authored value** (a final-wave boss's minimum damage, even at the old 40 floor, always kills a Tier 1 tower in 1–2 hits) — that target only ever applied to early-wave bosses; Rule 18's prose is corrected below to state this scoping explicitly rather than leaving it as an unstated assumption.

Tower System must apply `boss_effective_damage` directly to tower HP with no mitigation (MVP decision). This event is registered as `boss_tower_attack_attempted` on the EventBus.

---

### Formula 4 — Penultimate Wave Elite Amplification

Applied as a **post-processing step** after Formulas 1 and 2. Applies to ELITE-tier monsters on the **penultimate wave (N-1)** only — the wave immediately before the final BOSS wave. HP amplified; speed is **not** amplified (HP-only decision — threat is readable, not requiring layout restructuring).

The `is_penultimate_wave: bool` field in the `monster_spawn_requested` payload (Wave Manager Rule 15c) identifies penultimate wave spawns — Monster System reads this field instead of comparing `wave_index` to a hardcoded value. This makes the amplification relative to mission length rather than absolute, consistent with Wave Manager GDD Rule 6.

```
IF is_penultimate_wave == true AND monster.tier == ELITE:
    scaled_hp = scaled_hp × elite_penultimate_wave_hp_amplifier  // applied after Formula 1
    // scaled_speed unchanged
```

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `elite_penultimate_wave_hp_amplifier` | float | 1.35 | HP multiplier for ELITE monsters on the penultimate wave. |
| Application condition | — | `is_penultimate_wave == true` AND `tier == ELITE` | No other wave or tier receives this amplifier. |

**Output range:** `scaled_hp` from Formula 1 multiplied by 1.35. No additional clamp.  
**Combined multiplier at penultimate wave, Normal (example: 5-wave mission, wave 4):** `wave_hp_multiplier (1.45) × elite_penultimate_wave_hp_amplifier (1.35) = 1.9575×`.

**Escalation invariant, corrected 2026-07-15 (`/design-review`):** this document previously claimed "escalation is monotonic: the final wave remains the hardest," meaning the penultimate ELITE was asserted to always stay below the following wave's generic STANDARD HP. **This claim was false as written** — at this same worked example's own default values, the penultimate ELITE (587.25 HP, see below) already exceeds this 5-wave mission's actual final wave (wave 5) STANDARD HP (300 × (1+0.15×4) = 480). The document's prior closing sentence papered over this by comparing against "the Wave 8 peak (2.05×, 615 HP)" — a figure from an unrelated 8-wave mission, not this 5-wave mission's real final wave. Verified independently during this review: at `hp_wave_growth_rate = 0.12` (the low end of that knob's documented safe range), monotonicity against the next STANDARD wave breaks across the **entire** safe range of `elite_penultimate_wave_hp_amplifier` (1.20–1.40), not just at extreme values.

**The invariant is reframed rather than mechanically patched (design decision, 2026-07-15):** the penultimate-wave ELITE is explicitly a deliberate sub-boss difficulty spike — forcing it to stay below the following wave's generic STANDARD baseline fights the feature's own intent, and no combination of `hp_wave_growth_rate` and `elite_penultimate_wave_hp_amplifier` within their documented safe ranges can guarantee that weaker invariant without gutting the spike at low growth rates. **The actual guarantee this system makes is: the penultimate-wave ELITE never exceeds the mission's final-wave BOSS HP.** This holds by construction — a BOSS's `base_hp` and tier are authored independently and are always the mission's HP ceiling by design intent (BOSS `base_hp` is not currently formula-scaled the same way as STANDARD/ELITE `base_hp` — see MonsterResource schema, Rule 2 — so no numeric co-dependency check against the amplifier is needed the way the old, now-removed comparison required). The penultimate wave is allowed to spike above the immediately-following wave's generic difficulty; it is not allowed to spike above the mission's actual boss encounter, which remains the true peak.

**Worked example — penultimate wave ELITE (5-wave mission → wave 4), Normal difficulty, `base_hp = 300`, `base_speed = 1.5`:**

```
Step 1 — HP (Formula 1):
  wave_hp_multiplier    = 1 + (0.15 × 3) = 1.45
  difficulty_hp_multiplier = 1.00
  scaled_hp = 300 × 1.45 = 435 HP

Step 2 — Speed (Formula 2):
  wave_speed_multiplier = 1 + (0.06 × 3) = 1.18
  scaled_speed = 1.5 × 1.18 = 1.77 cells/sec

Step 3 — Penultimate wave amplification (HP only):
  scaled_hp    = 435 × 1.35 = 587.25 HP
  scaled_speed = 1.77 (unchanged)
```

**Corrected 2026-07-15**: Penultimate wave ELITE at 587.25 HP vs. this same 5-wave mission's actual final wave (wave 5) STANDARD HP at 480 (same `base_hp=300`) — the elite sub-boss wave is genuinely tankier than the mission's final generic wave, by design (see the reframed invariant above). This is intentional, not an error: the penultimate wave is a deliberate spike above the immediately-following wave's baseline. What remains true is that the mission's actual BOSS encounter (authored independently, not derived from this formula) remains the true difficulty peak — the previous version of this example compared against an unrelated 8-wave mission's wave-8 STANDARD figure (615 HP) to claim monotonicity against the *next wave*, which was both mathematically inapplicable to this 5-wave example and describing an invariant this system does not actually need to guarantee.

## Edge Cases

### Category 1: Pathfinding Edge Cases

**EC-1.1 — No valid path returned at spawn**
Situation: `PathfindingSystem.get_path()` returns an empty array during spawn (Rule 7e).
What happens: Entity stays in `SPAWNING` state indefinitely — not added to `active_monsters`, `monster_spawned` not emitted, entity cannot be targeted or damaged. A warning is logged. On `wave_completed`, the entity is in a separate `spawning_entities` list and is queue-freed silently — no `monster_died`, no drop, no breach.

**EC-1.2 — Path destroyed mid-wave (`path_invalidated` received)**
**Dead code at MVP.** Grid locks all tower-write operations during `WAVE_ACTIVE` phase (Pathfinding GDD Rule 20). No tower can be placed or removed mid-wave; therefore `path_invalidated` cannot fire during WAVE_ACTIVE. This edge case is unreachable in the MVP feature set. The handler should remain in code (the EventBus subscription, the path-refresh logic) for post-MVP where mid-wave tower removal may be introduced — but it will never execute in MVP. QA must not write a test for this AC against MVP builds.

**EC-1.3 — Two monsters occupy the same cell simultaneously**
Situation: Multiple entities step onto the same PATH cell.
What happens: Explicitly permitted (Rule 9). No collision detected, no resolution applied, no error logged. Visual overlap is a rendering concern.

**EC-1.4 — BOSS walks over a destroyed PATH cell**
**Dead code at MVP.** Trigger condition is path invalidation during WAVE_ACTIVE, which EC-1.2 establishes is impossible at MVP (Grid locks all tower-write operations during WAVE_ACTIVE). The handler should remain in code for post-MVP, but this case cannot occur and must not be QA-tested against MVP builds.
Situation: Path invalidation blocks the BOSS's current route.
What happens (post-MVP): BOSS requests a fresh path identically to EC-1.2. If no route exists, BOSS halts movement but tower attack logic continues — BOSS attacks the closest tower in range until killed or `wave_completed`.

---

### Category 2: Death Edge Cases

**EC-2.1 — AoE kill of 20+ monsters in one physics frame**
Situation: Lethal `monster_damage_taken` events arrive for 20+ entities in the same frame.
What happens: Each entity individually executes death sequence (set DEAD, remove from list, play death anim, instantiate VFX via deferred call). `monster_died` emits synchronously per entity during the damage pass — Monster System does NOT accumulate or batch. Wave Manager's batch accumulator collects these events and may emit `monsters_died_batch` at frame end. `boss_died` emits synchronously during the same damage pass at the moment the BOSS's HP reaches 0.

**EC-2.2 — BOSS killed mid-attack animation**
Situation: Lethal hit lands while BOSS `"attack"` animation is playing.
What happens: `lifecycle_state = DEAD` is set immediately. BOSS is removed from `active_monsters`. `"attack"` animation is interrupted; `"death"` animation begins. `boss_died` emits synchronously, then `monster_died`. Any `boss_tower_attack_attempted` already emitted this frame (before the lethal hit) is processed by Tower System normally — it has already been dispatched and the Tower System does not check whether the emitting BOSS is still alive. No further attack fires after death.

**EC-2.3 — Two simultaneous lethal hits on the same monster**
Situation: Two `monster_damage_taken` events (both lethal) arrive for the same entity in the same frame.
What happens: First event processed: sets `lifecycle_state = DEAD`, removes from `active_monsters`. Second event arrives: entity `lifecycle_state == DEAD`. Event is discarded — no second death sequence, no duplicate `monster_died`. `monster_died` fires exactly once with `kill_source` derived from the first event's `source_type` mapping. Second hit's source is not recorded.

---

### Category 3: Breach Edge Cases

**EC-3.1 — Monster reaches GOAL cell on the same frame it receives a lethal hit**
Situation: Movement detects GOAL arrival AND a lethal `monster_damage_taken` arrive in the same `_physics_process` frame.
What happens: **DEAD takes priority over BREACHED.** Implementation guarantee: Monster System must own a single centralized `_physics_process` that processes `active_monsters` in four sequential passes:

(1) **Damage pass**: drain `_pending_damage` buffer (all `monster_damage_taken` events buffered since last frame). For each event in order: apply `amount` to `current_hp`; flag any entity with `current_hp <= 0` as DEAD (set `lifecycle_state = DEAD`). Do NOT remove from `active_monsters` during this pass — modifying an Array while iterating is undefined behavior in GDScript.

(2) **BOSS Logic Pass**: for each non-DEAD BOSS in `active_monsters`: (a) if `boss_scan_frames_remaining > 0`, decrement it; (b) if `boss_scan_frames_remaining <= 0`, execute scan via `Grid.get_towers_in_range(boss_cell, boss_attack_range_cells)`; reset `boss_scan_frames_remaining = boss_scan_interval_frames`; `boss_cell` is derived from `Grid.world_to_cell(boss.global_position)` at the start of this pass. (c) Decrement `boss_attack_prepare_remaining` if `> 0`; if it reaches 0, emit `boss_tower_attack_attempted` using `_locked_target_id` and clear `_locked_target_id = -1`. (d) Decrement `boss_attack_cooldown_remaining` by `delta`, clamped to 0. Attack-prime entry (Rule 17d) is also evaluated here when scan results are available and conditions are met.

(3) **Movement pass**: skip DEAD entities; advance all ACTIVE entities along their paths. After all movement, rebuild `active_monsters` as a single filter pass removing all DEAD entries (`active_monsters = active_monsters.filter(func(e): return e.lifecycle_state != DEAD)`) — this replaces any `Array.erase()` in a loop.

(4) **Absorbed flush pass**: for each entry in `_pending_absorbed`, emit `monster_hp_absorbed`; then clear `_pending_absorbed`.

No individual monster entity node should define its own `_physics_process`. This centralized order makes the DEAD-priority guarantee implementable and keeps all BOSS logic within a predictable, profiler-visible pass. Note: since `monster_damage_taken` is buffered (not applied immediately on receipt), same-frame lethal-hit + GOAL-arrival should be deterministically ordered: lethal hits are always applied in the damage pass (pass 1), and GOAL-arrival is detected in the movement pass (pass 3) — DEAD always wins.

**EC-3.2 — BOSS reaches GOAL cell**
Situation: A BOSS entity completes its path.
What happens: Attack check fires before breach check on the arrival frame (Rule 19). If cooldown was ready and a tower was in range, `boss_tower_attack_attempted` fires first. Then: `lifecycle_state = BREACHED`, BOSS removed from `active_monsters`. **`boss_died` IS emitted** (payload: `entity_id`, `monster_id`, `wave_index`, `cause = "breached"`) — Wave Manager needs this to determine mission outcome. Then `monster_breached` emits (`tier=2` in payload). `monster_died` does NOT emit. Node is freed immediately; no death animation. The Wave Manager GDD must handle `boss_died` with `cause="breached"` distinctly from `cause="killed"` — both are valid wave-clear signals but produce different outcome states.

**EC-3.3 — ELITE reaches GOAL cell — what drops resolve?**
Situation: An ELITE monster breaches.
What happens: `monster_breached` emits. `monster_died` does NOT emit. No drop resolves — neither standard materials nor the Menagerie-attraction rare drop. Breach is a cost: letting a monster through forfeits its materials entirely. This is an intentional design decision.

---

### Category 4: Wave State Edge Cases

**EC-4.1 — `wave_completed` arrives with monsters in SPAWNING state**
Situation: `wave_completed` fires while entities exist in `SPAWNING` (path not yet returned, never entered ACTIVE).
What happens: Force-removal pass iterates `active_monsters` (SPAWNING entities are not in this list). A separate `spawning_entities` list is maintained; on `wave_completed` all entries are queue-freed immediately. `monster_died` is NOT emitted (they were never ACTIVE). No drop, no breach.

**EC-4.2 — `wave_completed` arrives while BOSS is mid-attack animation**
Situation: `wave_completed` fires while a BOSS entity is playing `"attack"` and has not been killed.
What happens: Force-removal pass runs. BOSS `lifecycle_state = DEAD`. Removed from `active_monsters`. `"attack"` animation interrupted. `boss_died` IS emitted with `cause = "force_removed"` (Rule 28b). `monster_died` emits with `kill_source = "wave_end"`. No drops resolve — neither standard materials nor Menagerie-attraction (Rule 28c). Any `boss_tower_attack_attempted` already emitted this frame is processed by Tower System normally.

---

### Category 5: BOSS Attack Edge Cases

**EC-5.1 — No towers in range when BOSS cooldown reaches 0**
Situation: `boss_attack_cooldown_remaining` reaches 0 but `Grid.get_towers_in_range()` returns empty.
What happens: Per Rule 17c (B6 design decision), cooldown is NOT reset — it remains at 0 (BOSS stays primed). When a tower next enters range and the scan executes, the BOSS immediately enters the `attack_prepare` phase on that scan frame (no additional cooldown delay). The `"attack_prepare"` animation is the player's only warning — there is no guaranteed idle window after a gap in tower presence.

**EC-5.2 — All towers destroyed — BOSS on an empty field**
Situation: Every tower has been destroyed. BOSS is ACTIVE and walking toward GOAL.
What happens: `Grid.get_towers_in_range()` returns empty every frame. No attack fires; cooldown remains at its current value (B6 decision: held at 0 if already primed — see Rule 17a). BOSS walks to GOAL at full `scaled_speed`. On reaching GOAL: EC-3.2 applies — `boss_died` IS emitted with `cause = "breached"`, then `monster_breached` emits. Wave Manager and HUD handle outcome.

**EC-5.3 — Target tower destroyed before `boss_tower_attack_attempted` resolves**
Situation: BOSS emits `boss_tower_attack_attempted` for a tower that is destroyed by another source in the same frame.
What happens: Monster System's responsibility ends at emission. The Tower System receives the event and must check whether `target_tower_id` still exists. If tower is already destroyed, Tower System discards the event — no damage applied, no error. `boss_attack_cooldown_remaining` has already been reset normally. This is a Tower System edge case documented here for cross-system clarity; the Tower System GDD must specify handling.

---

### Category 6: Spawn Edge Cases

**EC-6.1 — `monster_spawn_requested` references unknown `monster_id`**
Situation: Incoming spawn request names a type with no MonsterResource in `assets/data/monsters/`.
What happens: Per Rule 7a: logs `"[MonsterSystem] ERROR: Unknown monster_id '{id}'. Aborting spawn."` No entity created, no event emitted. Wave Manager's spawn plan continues (fire-and-forget). This is a content authoring error — QA must catch before ship.

**EC-6.2 — Duplicate `entity_id` issued in same mission**
Situation: The counter issues the same integer twice (implementation bug).
What happens: Must not occur by design (Rule 5: monotonically incrementing, never recycled within a mission). If it occurs, downstream event routing (D&S, Tower System, Wave Manager) is undefined. Not validated at runtime. This invariant is enforced by the entity_id counter unit test (required Acceptance Criterion).

**EC-6.3 — `spawn_cell` is not a SPAWN-typed cell**
Situation: `spawn_cell` resolves to PATH, PLACEABLE, GOAL, or BLOCKED via `Grid.get_cell_type()`.
What happens: Per Rule 7b: logs `"[MonsterSystem] ERROR: spawn_cell {cell} is not a SPAWN cell (type: {actual_type}). Aborting spawn."` No entity created. No event emitted. Wave Manager configuration error.

**EC-6.4 — SPAWN cell occupied by another monster**
Situation: A new spawn request arrives for a SPAWN cell currently occupied by another monster at the head of its path.
What happens: No occupancy check is performed for SPAWN cells (Rule 9 extends to all PATH and SPAWN cells). Both entities coexist. Both proceed independently. No collision, no error.

---

### Category 7: Formula Boundary Edge Cases

**EC-7.1 — `base_hp` authored below 1.0 in MonsterResource**
Situation: MonsterResource has `base_hp = 0.5` (authoring error).
What happens: Formula 1 computes `scaled_hp` from 0.5. Monster System floors `scaled_hp` at 1.0 before assigning. Monster spawns with 1 HP — dies in one hit. Content authoring error; QA must catch. The floor prevents a zero-HP entity from triggering instant DEAD state before becoming ACTIVE.

**EC-7.2 — `base_damage = 0` for a BOSS MonsterResource**
Situation: BOSS resource has `base_damage = 0` (authoring error or intentional zero-attack BOSS variant).
What happens: Formula 3 computes `boss_effective_damage = 0`. BOSS attack logic runs normally — `boss_tower_attack_attempted` emits with `base_damage = 0`. Tower System applies 0 damage. No error logged. Zero-attack BOSS is a valid (degenerate) configuration. Authors intending to suppress attack spam on a non-attacking BOSS should set `base_attack_interval` to a very large value, not rely on `base_damage = 0` alone.

**EC-7.3 — `tarot_speed_scalar` is 0**
Situation: Tarot modifier fires `mission_modifier_applied` with `modifier_value = 0.0`.
What happens: Formula 2 computes `scaled_speed = base_speed × multiplier × 0.0 = 0.0`. Monster System floors `scaled_speed` at 0.1 cells/sec. All monsters spawned after this modifier are near-stationary. Monsters already ACTIVE retain their previously assigned `scaled_speed` (modifier applies at instantiation only, not retroactively). The Tarot GDD must bound `monster_speed_scalar` modifier values at minimum 0.50 — the floor is a safety net, not a design target.

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **EventBus System** | Mutual | Infrastructure backbone | Monster emits: `monster_spawned`, `monster_died`, `boss_died`, `boss_hp_changed`, `boss_tower_attack_attempted`, `monster_breached`, `monster_hp_absorbed`. Monster subscribes to: `wave_started`, `wave_completed`, `mission_phase_changed`, `mission_modifier_applied`, `monster_damage_taken`, `monster_spawn_requested`, `path_invalidated` |
| **Grid System** | Grid → Monster (read) | Spatial data | Direct read API: `get_cell_type()`, `get_spawn_cells()`, `cell_to_world()`, `world_to_cell()`, `get_towers_in_range()`. Grid is an Autoload — Monster System calls directly, no EventBus. |
| **Pathfinding System** | Pathfinding → Monster (read) | Pre-built path data | Direct API call: `PathfindingSystem.get_path(from_cell, tier) -> Array[Vector2i]`. Called once at spawn; again on `path_invalidated`. |
| **Wave Manager** | Wave → Monster (commands) · Monster → Wave (signals) | Spawn commands and wave lifecycle signals | Wave Manager emits `monster_spawn_requested`, `wave_started`, `wave_completed`; Monster System emits `monster_died`, `boss_died` which Wave Manager consumes to track wave-clear condition |
| **Damage & Status System** | Bidirectional | Damage resolution + lifesteal round-trip | D&S resolves all incoming hits, emits `monster_damage_taken`; Monster applies resolved values and flushes `monster_hp_absorbed` at end of frame (accumulated, not per-hit). D&S subscribes to `monster_hp_absorbed` to resolve lifesteal heals. Monster emits `boss_tower_attack_attempted`; D&S is NOT in that path at MVP (Tower System resolves boss-to-tower directly). **Amended 2026-08-13:** burn/poison status-effect ticks and slow status-effect speed reduction (damage-status.md Formulas D5/D6) both bypass D&S entirely — Monster System reads `tower_attacked`'s `effect_type`/`effect_value`/`effect_duration` fields directly and applies them in its own status-effects pass (see damage-status.md Rule I.1's second named exception for why). |
| **Tower System** | Monster → Tower | Boss attack damage application | Monster emits `boss_tower_attack_attempted` (`boss_entity_id`, `target_tower_id`, `base_damage`); Tower applies `base_damage` directly to tower HP (pure subtraction, no mitigation, MVP). |
| **Resource Economy System** | Monster → Economy (downstream) | Material drop resolution | Monster emits `monster_died` with `drop_table_id`, `menagerie_attraction_drop_chance`, and `wave_reward_scalar`; Economy resolves drops scaled by the reward scalar. **REQUIRED cross-system contract:** Resource Economy MUST filter `kill_source == "wave_end"` events and suppress all drop resolution for those emissions — force-removed monsters never earn drops (`resource-economy.md` Rule 5, confirmed shipped). `menagerie_attraction_drop_chance` resolves to the `menagerie_lure` material (`resource-economy.md` Rule 6, see OQ-8) and is fully implemented, not a stale prerequisite gap. |
| **Mission HUD** | Monster → HUD (downstream) | Display updates | HUD subscribes to `monster_spawned`, `monster_died`, `boss_died`, `monster_breached`. All relationship is through EventBus. |
| **Hero System** | Hero → Monster (indirect) | Combat hits | Hero attacks route through D&S; Hero System reads target `tier` at attack-roll time and passes `hero_bonus_tier: int` in `HeroAutoAttackEvent`. D&S applies tier multiplier to ELITE/BOSS, emits `monster_damage_taken`. Monster System receives the resolved `amount`. |
| **Tarot System** | Tarot → Monster (modifier source) | Wave composition and speed modifiers | Monster subscribes to `mission_modifier_applied` during SCOUT. Modifier stored and applied at entity instantiation only — not retroactive to ACTIVE entities. |
| **Constellation System** | Monster → Constellation (downstream) | Tower-kill credit | Constellation subscribes to `monster_died`, reads `kill_source: "tower"` to credit tower kills toward pattern bonuses. |
| **Menagerie System** | Monster → Menagerie (indirect) | Rare attraction material chain | `menagerie_attraction_drop_chance` in `monster_died` → Resource Economy resolves material drop → player uses at Menagerie. No direct Monster → Menagerie link exists. |

## Tuning Knobs

| Knob | Default | Safe Range | Too High | Too Low | Interaction Warning |
|------|---------|-----------|---------|---------|---------------------|
| `hp_wave_growth_rate` | 0.15 | 0.12–0.20 | Late waves become damage sponges; time-to-kill spikes; DPS builds feel inadequate | No escalation felt; wave 8 no harder than wave 3 | Multiplicative with `difficulty_hp_multiplier` — extremes compound. Adjust one at a time. |
| `hp_difficulty_growth_rate` | 0.35 | 0.25–0.50 | Brutal difficulty unreachable for most players | Hard/Brutal feel identical to Normal | Same compound interaction as above. |
| `speed_wave_growth_rate` | 0.06 | 0.04–0.10 | Fast monsters require radical repositioning rather than adaptation | Speed threat imperceptible; all waves equally mobile | Tarot `monster_speed_scalar` stacks multiplicatively — validate ceiling at `(max_base_speed × max_wave_mult × 2.0)` before adjusting. |
| `boss_dmg_wave_growth_rate` | 0.10 | 0.08–0.15 | Final-wave BOSS one-shots Tier 3–4 towers | BOSS attacks negligible; players ignore boss position | Calibrated against `tower_hp_boss_damage_provisional_range` [40–200]. Changes invalidate Formula 3 calibration examples. |
| `elite_penultimate_wave_hp_amplifier` | 1.35 | 1.20–1.40 | Penultimate wave spike overwhelms builds that aren't ready | Penultimate wave not perceived as distinct from adjacent waves | Combined multiplier at penultimate wave (N-1): `wave_N-1_mult × amplifier`. **Corrected 2026-07-15** — the prior "must stay ≤1.41 to preserve monotonic escalation... breaks when amplifier ≥1.354" warning was arithmetically impossible: at `rate=0.12` (the safe range's own floor), `(1+rate×(N-1))/(1+rate×(N-2))` — the ratio the old invariant needed the amplifier to stay under — only ranges from 1.0698 (8-wave) to 1.088 (5-wave) across documented mission lengths, meaning the amplifier's own safe-range **floor** (1.20) already exceeds it. That old invariant (penultimate ELITE HP < next-wave STANDARD HP) has been formally retired — see Formula 4's "Escalation invariant" note. **The invariant this knob must now respect is: penultimate-wave ELITE HP must never exceed the mission's final-wave BOSS HP** (authored independently per BOSS MonsterResource, not derived from this formula) — this holds by construction for any amplifier value in the documented safe range against any authored BOSS `base_hp`, since BOSS HP pools (per Formula 3's context and typical authoring) sit far above STANDARD/ELITE HP pools. No numeric co-dependency check against `hp_wave_growth_rate` is required under the corrected invariant. Applied only when `is_penultimate_wave == true` (Wave Manager Rule 15c). |
| `menagerie_attraction_drop_chance` | Per MonsterResource | 0.02–0.15 per type | Menagerie trivialised; materials accumulate faster than usable | Menagerie inaccessible; specific monster hunting feels like grind | Stacks with wave monster count (10–40) and Menagerie GDD consumption rate. Balance against target missions-to-full-Menagerie. |
| `base_speed` | Per MonsterResource | 0.5–3.0 cells/sec | Fast STANDARD monsters overwhelm early-game layouts before adaptation | Slow monsters trivialise placement; hero never needs to reposition | Cross-referenced with `speed_wave_growth_rate` and `tarot_speed_scalar` ceiling. Fastest authored `base_speed` sets Formula 2 real-world ceiling. |
| `base_hp` | Per MonsterResource | 40–800 | Tanky STANDARD monsters on early waves punish under-built loadouts; frustrating not challenging | HP so low DPS overflow makes wave difficulty invisible | Cross-referenced with `hp_wave_growth_rate` and `elite_penultimate_wave_hp_amplifier`. Heaviest ELITE on the penultimate wave (N-1) is peak non-BOSS HP. |
| `base_damage` (BOSS only) | Per BOSS MonsterResource | Early-wave: 15–25 · Final-wave: **55–80** (narrowed from 40–80, corrected 2026-07-15 — see Formula 3's calibration note; the old 40–54 sub-range let a wave-5 boss take 18 hits to kill a Tier 4 tower, above the 8-15 hit target and reading as a passive threat) | BOSS destroys towers faster than player can respond | BOSS feels cosmetic; players learn to ignore its position | Two-tier calibration. Validate against `tower_max_hp` output at the BOSS's intended wave index. `boss_dmg_wave_growth_rate` compounds — always test at target wave. |
| `path_arrival_threshold` | 4.0 world units | 2.0–8.0 | Monster overshoots target cell position before arrival registers; movement stutters | Monster snaps to cell center before reaching it; movement looks teleport-like | Must be less than one full cell's world-unit width. Used in Rule 11c; referenced in AC-8. |
| `boss_scan_interval_frames` | 6 frames | 3–12 | Lag between tower entering range and BOSS targeting it; BOSS fires late | Per-frame Grid scan cost on every BOSS entity every frame; affects performance budget | At 60 FPS, default = 10 scans/second. Reduce if BOSS targeting feels unresponsive; increase if many simultaneous BOSSes strain the 2 ms frame budget. |
| `boss_attack_prepare_frames` | 4 frames | 2–8 | BOSS attack telegraph is so long it feels disconnected from the impact | Player cannot react to the attack at all; telegraph is imperceptible | At 60 FPS, default = ~67ms. Long enough to read an animation but short enough to feel urgent. Pairs with the `"attack_prepare"` animation frame count — keep them matched. |
| `MAX_ACTIVE_MONSTERS` | 150 | 100–200 | No enforced ceiling — runtime entity count can grow unbounded under heavy Tarot modifiers | Players can trivially overflow the budget; wave difficulty meaningless | If a spawn is discarded due to cap, Wave Manager's wave composition may be silently incomplete. Validate this cannot produce stuck waves by ensuring Wave Manager can clear with fewer-than-scheduled entities. |

## Visual/Audio Requirements

**Design principle:** Every visual and audio cue communicates a game-state fact. A monster's tier, health state, and death or breach must be legible within one second of onset. Effects that add visual noise without informational content are out of scope.

---

### Animation Requirements

#### Minimum Required Animations by Tier

| Animation key | STANDARD | ELITE | BOSS | Notes |
|---|---|---|---|---|
| `"walk"` | Required | Required | Required | Plays during ACTIVE state. |
| `"death"` | Required | Required | Required | Plays on DEAD entry. NOT on breach — entity is freed immediately on breach. |
| `"attack_prepare"` | Not present | Not present | Required | Plays when BOSS enters the attack-prepare phase (Rule 17d). Duration = `boss_attack_prepare_frames` (default 4 frames). Must be visually distinct — this is the player's only warning before `boss_tower_attack_attempted` emits. Plays on the **overlay AnimatedSprite2D** (see BOSS scene structure below); `"walk"` continues uninterrupted on the base layer. |
| `"attack"` | Not present | Not present | Required | Plays when `boss_tower_attack_attempted` emits (at end of prepare phase). Does NOT interrupt `"walk"`. Plays on the overlay layer. |

#### Frame Count Guidance

| Animation | STANDARD | ELITE | BOSS | FPS |
|---|---|---|---|---|
| `"walk"` | 4 frames | 4–6 frames | 6–8 frames | 8 FPS |
| `"death"` | 4 frames | 4–6 frames | 6–8 frames | 10–12 FPS |
| `"attack"` | N/A | N/A | 4–6 frames | 12 FPS |

#### BOSS Scene Structure — Two-Layer AnimatedSprite2D

BOSS entities use two stacked `AnimatedSprite2D` nodes to layer walk and attack animations without `AnimationTree` (which cannot additively blend `SpriteFrames` frame indices in Godot 4):

```
Area2D  (BOSS root — see Rule 5)
├── AnimatedSprite2D  (base layer — "walk" animation, always playing during ACTIVE)
└── AnimatedSprite2D  (overlay layer — attack animations only)
      SpriteFrames: "idle_overlay" (transparent placeholder), "attack_prepare", "attack"
```

- The overlay `AnimatedSprite2D` plays `"idle_overlay"` (a single fully-transparent frame, looped) during non-attack phases. No animation state logic needed — the overlay is invisible when not attacking.
- On prepare-phase entry (Rule 17d): overlay plays `"attack_prepare"`.
- On fire (Rule 17d.1): overlay plays `"attack"`.
- On death: both `AnimatedSprite2D` nodes are controlled by the death sequence — base plays `"death"`, overlay stops.

**Art pipeline constraint:** BOSS attack sprite sheets must be authored at the same canvas size and pivot as the base walk sheet so overlays align pixel-perfectly. Overlay frames must have a fully transparent background except for the attack effect itself. Art Director owns this pipeline spec.

**Implementation owner:** godot-gdscript-specialist. This replaces all prior references to `AnimationTree` additive blend nodes for BOSS animation layering.

---

#### Pivot / Origin Standard

- Pivot at the **vertical center-base of the sprite** (feet/base contact point with path). A center-pivot sprite sits half a cell above its logical position, creating Z-sort and VFX spawn errors.
- Sprites must be power-of-two canvas sizes padded to contain the full silhouette without canvas clipping mid-animation.

| Tier | Canvas width | Canvas height |
|---|---|---|
| STANDARD | 32 px | 32 px |
| ELITE | 48 px | 48 px |
| BOSS | 64 px | 96 px |

---

### Visual Differentiation — Tier Readability

The player must identify a monster's tier within one second at any supported zoom level.

#### Scale (Relative to Grid Cell)

| Tier | On-screen scale |
|---|---|
| STANDARD | 50–65% of one cell |
| ELITE | 75–85% of one cell |
| BOSS | 110–130% of one cell (bleeds over cell boundary) |

**QA test:** Place one STANDARD, one ELITE, one BOSS on adjacent cells. All three tiers must be distinguishable by scale alone from a screenshot. A tester identifies all three correctly without prior knowledge of the specific monster type.

#### Silhouette Language

- **STANDARD:** Simple, compact. Reads as a unit of a group.
- **ELITE:** Same archetype as a STANDARD but with at least one distinct silhouette addition (enlarged shoulders, spine ridge, carried object, extending limb) visible at STANDARD thumbnail scale.
- **BOSS:** Fully distinct from any STANDARD or ELITE in the same wave. At least two of: significant vertical extension, exaggerated width, non-humanoid body mass, or environmental reactivity (orbiting particles). Identifiable in silhouette-only form (no color) from across the grid.

#### Color and Shader Differentiation

| Tier | Treatment | Implementation |
|---|---|---|
| STANDARD | As-authored color. No shader. | Default sprite. |
| ELITE | Silver / cold-white (`#C8D8E8` provisional) edge highlight. Persistent during ACTIVE state. NOT confused with: damage flash (white, subsecond), hero rim (pale gold), tower affinity aura (warm gold). | Edge-detect shader or second sprite layer with offset. godot-shader-specialist owns implementation. |
| BOSS | Distinct base palette per BOSS type. Persistent dark desaturated aura: low-alpha shadow vignette extending ~8–12 px from sprite base, present throughout ACTIVE state. Not black (reads as shadow); choose a color that reads against PATH tile beneath. | Per-BOSS authored sprite + aura as separate `Sprite2D` child node. |

#### Tier Badge / Icon

| Tier | Badge | Notes |
|---|---|---|
| STANDARD | None | No badge at MVP. |
| ELITE | 12×12 px world-space icon, top-right of sprite bounding box. Single downward chevron or elite-mark glyph. | Follows same spec pattern as tower pre-placement perk badge. |
| BOSS | 16×16 px world-space icon, top-right. Skull or crown glyph (art bible to define). Plus: floating `display_name` nameplate above sprite, Y-offset above bounding box top, using HUD font. | Nameplate: `Label` node child, must not overlap other on-screen elements at default zoom. |

Both ELITE badge and BOSS nameplate are **MVP-required** — battlefield legibility is a pillar requirement.

---

### Archetype Tag Visual Feedback

#### Armored Hit Effect (`archetype_tag = &"armored"`)

When a tower deals damage to an `armored` entity, the 50% mitigation must be visually distinguishable from an unmitigated hit. Players cannot make informed placement decisions near armored enemies if mitigated hits look identical to normal hits.

**Required visual (one of):**
- Metallic spark burst: 2–4 particles, silver/grey palette, at the hit point — distinct from the standard damage-flash white
- Shield flash highlight: silver-tinted sprite overlay, 2–3 frames duration, distinct from standard white damage flash

**Not required:** Modification to the floating damage number — the number already reflects the mitigated amount. The visual should communicate "this hit was reduced", not duplicate the number.

**Art/UX delegation:** Exact treatment (spark vs. flash) is delegated to Art Director and UX Designer. This requirement specifies the information need — armored mitigation must be visually distinguishable — not the execution.

**Hero damage is unaffected:** Hero hits on armored entities use no mitigation and therefore no armored-hit visual. The armored visual is tower-hit-only.

**MVP required:** Yes.

---

### Death VFX — `death_vfx_scene` Specification

Instantiated at `entity.global_position` (center-base pivot) when `lifecycle_state = DEAD`. Self-terminates and queue-frees after playing. Monster System does not manage VFX lifecycle after instantiation. Death VFX is **NOT instantiated on breach**.

| Tier | Duration | Minimum content |
|---|---|---|
| STANDARD | 0.3–0.5s | Particle burst (8–12 particles, base palette color) + sprite dissolve (alpha fade or noise, 0.2–0.3s). |
| ELITE | 0.4–0.7s | Particle burst (12–20 particles, silver/cold-white accent) + sprite dissolve + single shockwave ring expanding to ~one cell diameter, fading fully before 0.7s. |
| BOSS | 0.8–1.2s | Sprite dissolve + particle burst (20–30 particles, BOSS aura color) + shockwave ring (~two cell diameter) + screen micro-shake (0.1–0.15s, low amplitude). No full-screen flash. Effect spatially contained to ~2-cell radius. |

**MVP scene count:** 1 STANDARD shared · 1 ELITE shared · 1 per BOSS type (BOSS aura color is type-specific). Total at MVP: 4–5 death VFX scenes.

---

### Breach — Visual Feedback

No `"death"` animation and no `death_vfx_scene` on breach. Entity is freed immediately. Breach feedback is the Mission HUD's responsibility (subscribes to `monster_breached`).

**Required HUD breach feedback (forward spec for Mission HUD GDD):**

| Trigger | Visual | Audio | Notes |
|---|---|---|---|
| STANDARD/ELITE breach | Goal-side screen edge flashes red (0.2–0.3s, fades over 0.5s). Breach counter pulses (scale pop 1.2×, 0.3s). | Warning sting (global, non-spatial). | One flash per event, no stacking. |
| BOSS breach (`tier==2`) | Full-screen edge ring (all four edges, not goal-side only). Counter pulse. | Distinct heavy warning sting (global). | `boss_died` IS emitted on BOSS breach with `cause = "breached"` (see EC-3.2). Wave Manager subscribes to `boss_died` to determine mission outcome. Mission HUD subscribes to `monster_breached` (`tier=2`) to trigger this visual and audio feedback. |

**QA test:** Trigger STANDARD breach. Within 0.5s, a tester must identify (a) breach occurred and (b) breach counter incremented — without having watched the monster vanish.

---

### Audio Events

| Event | Sound type | Spatial | MVP? |
|---|---|---|---|
| BOSS spawns (SPAWNING → ACTIVE) | Weighty arrival sound. | Positional (spawn cell) | MVP Required |
| BOSS walking (ACTIVE loop) | Rhythmic thud loop. | Positional | MVP Required |
| BOSS attack telegraph (`boss_attack_prepare_remaining` set to `boss_attack_prepare_frames`) | Short charge / wind-up sound. Signals imminent attack. Must be distinct from the attack-fire sound. | Positional (BOSS world position) | MVP Required |
| BOSS attack fires (`boss_tower_attack_attempted`) | Single-shot impact, heavier than any tower attack. | Positional (BOSS world position) | MVP Required |
| STANDARD death | Light death sound. Distinguishable from ELITE. | Positional | MVP Required (1 shared sound) |
| ELITE death | Heavier than STANDARD. Silver/armor-break quality. | Positional | MVP Required (1 shared sound) |
| BOSS death (`boss_died` + `monster_died`) | Two layers: impact (positional) + global resonance tail (non-spatial — signals battlefield significance). | Impact: Positional. Tail: Global | MVP Required |
| STANDARD/ELITE breach warning | Warning sting. Not triumphant. Communicates loss. | Global | MVP Required |
| BOSS breach warning (`tier==2`) | Heavier sting, distinct from STANDARD/ELITE breach. | Global | MVP Required |
| STANDARD spawn sound | Light emergence sound. | Positional | Deferred (Alpha) |
| STANDARD walk loop | Light footstep loop. | Positional | Deferred (Alpha) |
| ELITE spawn sound | Slightly heavier than STANDARD. | Positional | Deferred (Alpha) |
| ELITE walk loop | Heavier loop. | Positional | Deferred (Alpha) |

**Polyphony caps (provisional — Audio System GDD owns final policy):**

| Category | Max voices | Overflow |
|---|---|---|
| STANDARD death | 6 | Oldest dropped |
| ELITE death | 3 | Oldest dropped |
| BOSS sounds (all) | 1 per BOSS instance | Priority override — never dropped |
| Breach warning stings | 2 (combined) | Newest dropped |

**Monster System responsibility:** Emit events at the correct moment with world position. Monster System does not own audio playback directly — audio is driven by EventBus event subscribers defined in the Audio System GDD.

---

### Asset Volume Summary

| Asset type | MVP count | Notes |
|---|---|---|
| Sprite animation sets (SpriteFrames) | 15–24 (5–8 types × 2–3 anims) | Shared resources across instances |
| Death VFX scenes (PackedScene) | 4–5 | 1 STANDARD + 1 ELITE + 1 per BOSS type |
| Audio files | ~8–10 events | BOSS sounds + death sounds + breach stings |
| Tier badge icons | 2 (ELITE 12px + BOSS 16px) | Plus per-BOSS nameplate font/style |

After art bible approval, run `/asset-spec system:monster` to produce per-asset descriptions and generation prompts from this section.

## UI Requirements

The Monster System has no player-interactive UI of its own — players do not click monsters, drag them, or configure them. All UI related to monsters is owned by the Mission HUD (which subscribes to monster events) and is specified in the Mission HUD GDD. Requirements listed here are forward specs: data that must be available in event payloads for the HUD to implement correctly.

### Data the Monster System Must Expose via Events

| UI Element (owned by Mission HUD GDD) | Data source from Monster System | Event carrying it |
|---------------------------------------|--------------------------------|-------------------|
| Active enemy count display | `active_monsters.size()` (via `monster_spawned` +1, `monster_died` −1, `monster_breached` −1) | `monster_spawned`, `monster_died`, `monster_breached` |
| Breach counter | Incremented per `monster_breached` | `monster_breached` (payload: `tier`) |
| BOSS HP bar | `current_hp` / `max_hp` — exposed via `boss_hp_changed` event (Rule 21c) | `boss_hp_changed` (`entity_id`, `current_hp`, `max_hp`) |
| Kill feed (monster type + kill source) | `monster_id`, `tier`, `kill_source` | `monster_died` |
| BOSS nameplate label | `display_name` from MonsterResource | MonsterResource direct read at spawn time — HUD subscribes to `monster_spawned` to instantiate the nameplate, reads `display_name` from the resource |
| Wave-clear countdown (enemies remaining) | `active_monsters.size()` derived from events | `monster_died`, `monster_breached` |
| Breach screen-edge flash | `tier` in `monster_breached` | `monster_breached` |

### BOSS HP Bar — RESOLVED

Monster System emits `boss_hp_changed` (payload: `entity_id: int`, `current_hp: float`, `max_hp: float`) each time a BOSS receives `monster_damage_taken` and survives (Rule 21c). This is **MVP-required**. Mission HUD subscribes to `boss_hp_changed` to drive the BOSS HP bar widget. The event is registered in the EventBus GDD. No action needed from D&S or Mission HUD GDD beyond subscribing.

### No Monster Selection or Inspection UI

At MVP there is no click-to-inspect mechanic for monsters. Players read monster state from:
- Visual tier differentiation (scale, silhouette, badge)
- BOSS nameplate
- HUD active-count and breach counter

Any future monster codex or inspection panel is an Encyclopedia System feature (Full Vision tier) — not Monster System UI.

## Acceptance Criteria

45 criteria total (**updated 2026-07-15, `/design-review`** — AC-44/AC-45 added, closing a Formula 3 boundary-value gap and a Formula 4 wave-4-regression gap respectively). **44 are BLOCKING for the current sprint.** AC-10 is `[Post-MVP · NOT TESTED IN SPRINT]`. No ADVISORY criteria — every listed behavior is a correctness requirement, not a feel or visual quality target.

| Gate | Type | Count |
|------|------|-------|
| BLOCKING — Logic unit test | Automated | 37 |
| BLOCKING — Integration test | Automated + stubs | 2 (AC-1, AC-29) |
| BLOCKING — Performance profiler | Manual + profiler evidence | 3 (AC-28, AC-40, AC-43) |
| BLOCKING — Cross-system contract | Integration + stubs | 2 (AC-32, AC-34) |

---

### Area 1: Spawn

**AC-1** `[Integration · BLOCKING]`
GIVEN a `monster_spawn_requested` event is published with a valid `monster_id`, a valid SPAWN-typed `spawn_cell`, `wave_index=1`, `difficulty_tier=1`, and a Pathfinding stub returns a non-empty path,
WHEN the Monster System processes the event,
THEN exactly one entity is added to `active_monsters`; `lifecycle_state == ACTIVE`; `monster_spawned` is emitted once with the correct `entity_id` and `monster_id`.

**AC-2** `[Logic · BLOCKING]`
GIVEN a `monster_spawn_requested` event references a `monster_id` with no corresponding MonsterResource in `assets/data/monsters/`,
WHEN the Monster System processes the event,
THEN no entity is created; `active_monsters` is unchanged; `monster_spawned` is not emitted; an error is logged containing the unrecognized `monster_id`.

**AC-3** `[Logic · BLOCKING]`
GIVEN a `monster_spawn_requested` event references a valid `monster_id` but a `spawn_cell` whose `Grid.get_cell_type()` returns PATH, PLACEABLE, GOAL, or BLOCKED,
WHEN the Monster System processes the event,
THEN no entity is created; `active_monsters` is unchanged; `monster_spawned` is not emitted; an error is logged containing the cell coordinates and actual cell type.

**AC-4** `[Logic · BLOCKING]`
GIVEN a MonsterResource with `base_hp = 300` and spawn parameters `wave_index=4`, `difficulty_tier=1`, `hp_wave_growth_rate=0.15`, `hp_difficulty_growth_rate=0.35`,
WHEN `scaled_hp` is calculated at spawn,
THEN `scaled_hp == 435.0` exactly; the value is immutable after spawn; `current_hp` is initialised to `scaled_hp`.

**AC-5** `[Logic · BLOCKING]`
GIVEN a MonsterResource with `base_speed = 1.5` and spawn parameters `wave_index=4`, `speed_wave_growth_rate=0.06`, no Tarot modifier active (`tarot_speed_scalar = 1.0`),
WHEN `scaled_speed` is calculated at spawn,
THEN `scaled_speed == 1.77` (±0.001); value is immutable after spawn.

**AC-6** `[Logic · BLOCKING]`
GIVEN a `monster_spawn_requested` event arrives with a valid `monster_id` and valid `spawn_cell`,
WHEN the Pathfinding stub returns an empty `Array[Vector2i]`,
THEN the entity stays in `SPAWNING` state; `active_monsters` does not contain the entity; `monster_spawned` is not emitted; a warning is logged.

**AC-7** `[Logic · BLOCKING]`
GIVEN five sequential `monster_spawn_requested` events are processed during the same mission (wave_index > 1 so counter is not reset),
WHEN all five entities spawn successfully,
THEN each entity receives a unique `entity_id` strictly greater than the previous; no two entities share an `entity_id` within the mission.

---

### Area 2: Path Consumption

**AC-8** `[Logic · BLOCKING]`
GIVEN an ACTIVE monster with `scaled_speed = 2.0` cells/second, a `current_path` of 6 cells (each cell 64 world units wide), and `PATH_ARRIVAL_THRESHOLD = 4.0` world units,
WHEN `_physics_process` is called 120 times with `delta = 1/60.0` (2.0 seconds of simulated time),
THEN `path_step_index == 4` (the monster has advanced through cells 0–3 and is now targeting cell 4); no cells are skipped; `lifecycle_state` remains ACTIVE (cells 4 and 5 remain — GOAL not yet reached).

**AC-9** `[Logic · BLOCKING]`
GIVEN an ACTIVE monster whose `path_step_index` advances to `current_path.size()` (GOAL reached) with `current_hp > 0`,
WHEN the movement step executes,
THEN `lifecycle_state == BREACHED`; entity removed from `active_monsters`; `monster_breached` emitted once with correct `entity_id`, `monster_id`, `tier`; `monster_died` is NOT emitted.

**AC-10** `[Integration · Post-MVP · NOT TESTED IN SPRINT]`
*(EC-1.2 establishes that `path_invalidated` cannot fire during WAVE_ACTIVE at MVP — Grid locks all tower-write operations during active waves. This AC is unreachable in MVP builds. The subscription and handler must remain in code for post-MVP, but this criterion is excluded from the sprint gate.)*
GIVEN an ACTIVE monster is mid-path and `path_invalidated` is published containing a cell in the monster's `current_path`,
WHEN the Monster System processes the event,
THEN `PathfindingSystem.get_path()` is called exactly once from the monster's current grid cell; `current_path` and `path_step_index` are replaced with the fresh path; movement continues on the next frame.

**AC-11** `[Logic · BLOCKING]`
GIVEN an ACTIVE monster with `scaled_speed = 120.0` (cells/sec, test override), `path_step_index = 3`, at least 5 cells remaining in `current_path`, and `delta = 1.0/60.0`,
WHEN `_physics_process(delta)` executes,
THEN `path_step_index` increments by exactly 2 (from 3 to 5) in that frame; no cells are silently skipped; if GOAL is reached mid-overshoot (e.g. the 5th cell is GOAL), BREACHED triggers in that same frame.

---

### Area 3: BOSS Attack

**AC-12** `[Logic · BLOCKING]`
GIVEN an ACTIVE BOSS with `boss_attack_range_cells=3`, `boss_attack_cooldown_remaining=0`, `boss_attack_prepare_remaining=0`, `boss_attack_prepare_frames=4`, and two towers within Chebyshev-3 range — tower A at Chebyshev distance 1 (HP 120), tower B at Chebyshev distance 2 (HP 80),
WHEN `_physics_process(delta)` runs and scan executes,
THEN `boss_attack_prepare_remaining` is set to 4 (prepare phase entered); `"attack_prepare"` animation begins; `boss_tower_attack_attempted` is NOT emitted this frame (attack fires only after prepare completes per Rule 17d.1); `boss_attack_cooldown_remaining` remains 0 (reset happens at fire, not at prepare-entry); tower A is the selected target (closest Chebyshev, not lowest-HP); `path_step_index` advances normally in the same frame (movement not interrupted).

**AC-13** `[Logic · BLOCKING]`
GIVEN an ACTIVE BOSS with `boss_attack_cooldown_remaining = 1.5` and a tower within range,
WHEN `_physics_process(0.0167)` runs,
THEN `boss_tower_attack_attempted` is NOT emitted; `boss_attack_cooldown_remaining == 1.4833` (±0.001).

**AC-14** `[Logic · BLOCKING]`
GIVEN an ACTIVE BOSS with `boss_attack_cooldown_remaining = 0`, `boss_attack_prepare_remaining = 0`, and `Grid.get_towers_in_range()` returning an empty array on the scan,
WHEN `_physics_process(delta)` runs,
THEN `boss_tower_attack_attempted` is NOT emitted; `boss_attack_cooldown_remaining` remains 0 (BOSS stays primed — cooldown is NOT reset when no towers are in range, per Rule 17c design decision); `boss_attack_prepare_remaining` remains 0.

**AC-15** `[Logic · BLOCKING]`
GIVEN STANDARD (tier=0) and ELITE (tier=1) ACTIVE monsters with towers within any range,
WHEN `_physics_process(delta)` is called for 10 frames,
THEN `boss_tower_attack_attempted` is never emitted from either entity.

---

### Area 4: Death

**AC-16** `[Logic · BLOCKING]`
GIVEN an ACTIVE STANDARD monster with `current_hp = 10.0`,
WHEN `monster_damage_taken` is received with `entity_id` matching the monster, `amount = 10`, `source_type = 0` (tower),
THEN `lifecycle_state == DEAD`; entity removed from `active_monsters`; `monster_died` emitted exactly once; payload contains `kill_source="tower"`, correct `entity_id`, `monster_id`, `tier`, `drop_table_id`, `menagerie_attraction_drop_chance`, `world_position`, and `wave_reward_scalar` matching the value from the original `monster_spawn_requested` event.

**AC-17** `[Logic · BLOCKING]`
GIVEN an ACTIVE BOSS with `current_hp = 1.0`,
WHEN `monster_damage_taken` is received with `entity_id` matching the BOSS and `amount = 1`,
THEN `boss_died` emits first, then `monster_died` emits; both events fire in the same frame; `boss_died` payload contains `entity_id`, `monster_id`, `wave_index`, and `cause == "killed"`.

**AC-18** `[Logic · BLOCKING]`
GIVEN an ACTIVE STANDARD monster with `current_hp = 5.0`,
WHEN two `monster_damage_taken` events both arrive in `_pending_damage` in the same frame with `amount = 10` each,
THEN during the damage pass: `lifecycle_state == DEAD` is set after the first event is processed; the second event is discarded (entity already DEAD); `monster_died` is emitted exactly once. The entity remains in the `active_monsters` array until the movement pass filter (`active_monsters = active_monsters.filter(...)` at the end of pass 3) — it is NOT removed from the array mid-damage-pass.

**AC-19** `[Logic · BLOCKING]` — **Corrected 2026-07-31 (ADR-0033)**: this fixture's 22-death count exceeds `eventbus_batch_threshold` (20), which now correctly triggers batching rather than 22 individual emissions — the assertion below was updated to match; see ADR-0033 for why Monster System (not Wave Manager) owns this decision.
GIVEN 22 ACTIVE monsters (21 STANDARD, 1 BOSS) all receive lethal `monster_damage_taken` events in the same physics frame,
WHEN the frame completes,
THEN `boss_died` has been emitted synchronously during the frame (not deferred) with `cause == "killed"`; because 22 exceeds `eventbus_batch_threshold` (20), Monster System emits exactly one `monsters_died_batch` (containing all 22 payloads) instead of 22 individual `monster_died` events — `monster_died` fires zero times for this frame; Monster System, not Wave Manager, owns and performs this batching decision.

---

### Area 5: Breach

**AC-20** `[Logic · BLOCKING]`
GIVEN an ACTIVE ELITE monster reaches a GOAL cell with `current_hp > 0`,
WHEN breach resolution executes,
THEN `lifecycle_state == BREACHED`; `monster_died` is NOT emitted; `monster_breached` IS emitted with `tier=1`; entity node is queued for immediate free (no death animation delay).

**AC-21** `[Logic · BLOCKING]`
GIVEN an ACTIVE BOSS with `boss_attack_prepare_remaining = 1` and a tower in range, whose `path_step_index` reaches `current_path.size()` in the same frame,
WHEN the frame processes (attack/prepare pass runs before breach check),
THEN `boss_attack_prepare_remaining` decrements to 0; `boss_tower_attack_attempted` emits (prepare completed) before breach resolution; `boss_died` emits with `cause == "breached"`; `monster_breached` emits with `tier=2`; `monster_died` is NOT emitted.

---

### Area 6: Wave State Contract

**AC-22** `[Logic · BLOCKING]`
GIVEN the Monster System has not received a `wave_started` event (SCOUT or pre-mission state),
WHEN `monster_spawn_requested` events are published,
THEN no entities are created; `active_monsters` remains empty; no events are emitted by Monster System.

**AC-23** `[Logic · BLOCKING]`
GIVEN 3 ACTIVE monsters (STANDARD, ELITE, BOSS tier) remain in `active_monsters` when `wave_completed` is received,
WHEN force-removal executes,
THEN all three entities are removed from `active_monsters` and queued for free within the same frame; `boss_died` emits for the BOSS with `cause == "force_removed"` before its `monster_died`; `monster_died` emits for all three entities with `kill_source = "wave_end"`; `active_monsters.size() == 0` after the removal pass; a subsequent `monster_spawn_requested` event received without an intervening `wave_started` does not add any entity to `active_monsters` (verifies idle state — spawn handler is inactive).

**AC-24** `[Logic · BLOCKING]`
GIVEN one entity exists in `spawning_entities` (path pending, never ACTIVE) when `wave_completed` fires,
WHEN force-removal executes,
THEN the entity is queue-freed immediately; `monster_died` is NOT emitted; `monster_spawned` is NOT emitted; `active_monsters` is unaffected.

**AC-25** `[Logic · BLOCKING]`
GIVEN a previous wave ended with 2 force-removed monsters (properly cleared),
WHEN `wave_started` fires for the next wave,
THEN `active_monsters` is empty at the moment wave processing begins; no prior-wave entity is present.

---

### Area 7: Formula Correctness

**AC-26** `[Logic · BLOCKING]`
GIVEN a MonsterResource with `base_hp=300`, `base_speed=1.5`, tier=ELITE, spawn params `wave_index=4`, `is_penultimate_wave: true`, `difficulty_tier=1`, `hp_wave_growth_rate=0.15`, `speed_wave_growth_rate=0.06`, `elite_penultimate_wave_hp_amplifier=1.35`,
WHEN scaled values are calculated,
THEN `scaled_hp == 587.25` (300 × 1.45 × 1.35) and `scaled_speed == 1.77` (±0.001) (1.5 × 1.18); speed is NOT amplified.

**AC-27** `[Logic · BLOCKING]`
GIVEN (a) a MonsterResource with `base_hp=0.1` at `wave_index=1`, `difficulty_tier=1`; (b) a MonsterResource with `base_speed=0.5` spawned at `wave_index=1` with `tarot_speed_scalar=0.5` (Tarot GDD minimum valid value),
WHEN scaled values are calculated,
THEN (a) `scaled_hp == 1.0` (floored from `0.1 × 1.0 × 1.0 = 0.1`); (b) `scaled_speed == 0.25` (`0.5 × 1.0 × 0.5`, above the 0.1 floor); no divide-by-zero or negative value occurs.

**AC-44** `[Logic · BLOCKING]` *(added 2026-07-15, `/design-review` — closes a boundary-value gap: the prior Formula 3 calibration table checked only one worked example and missed a failing combination)*
GIVEN a BOSS MonsterResource authored at the final-wave `base_damage` floor of **55** (narrowed 2026-07-15 from the prior floor of 40), spawned at `wave_index=5` (earliest legal final-wave index), `boss_dmg_wave_growth_rate=0.10`,
WHEN `boss_effective_damage` is calculated via Formula 3,
THEN `boss_effective_damage == 77.0` (`55 × 1.40`); hits-to-kill vs. a Tier 4 tower (1000 HP) is `ceil(1000/77) == 13`, inside the documented 8–15 hit target. **AND GIVEN** the same BOSS is authored at the old, now-invalid floor of `base_damage=40`, **THEN** load-time validation must reject this as an authoring error — `base_damage` below 55 is no longer valid for a final-wave (`wave_index ∈ [5,8]`) BOSS MonsterResource.

**AC-45** `[Logic · BLOCKING]` *(added 2026-07-15, `/design-review` — closes a regression gap: AC-26 only exercises the 5-wave-mission case where wave 4 is coincidentally both the fixed worked-example index and the true penultimate wave, so a future regression toward hardcoded "wave 4 is special" logic would not be caught)*
GIVEN a MonsterResource with `base_hp=300`, tier=ELITE, spawned in an **8-wave mission** with `wave_index=4`, `is_penultimate_wave=false` (this mission's true penultimate wave is wave 7, not wave 4), `difficulty_tier=1`, `hp_wave_growth_rate=0.15`,
WHEN `scaled_hp` is calculated,
THEN `scaled_hp == 435.0` (Formula 1 only: `300 × 1.45`) — `elite_penultimate_wave_hp_amplifier` is **NOT** applied, confirming the amplifier is gated strictly on the `is_penultimate_wave` payload field (Wave Manager Rule 15c), never on a hardcoded wave index.

---

### Area 8: Performance

**AC-28** `[Performance · BLOCKING]` — Evidence: profiler output at `production/qa/evidence/monster-perf-[date].png`
GIVEN 150 ACTIVE STANDARD monsters are simultaneously present in `active_monsters` (the `MAX_ACTIVE_MONSTERS` cap), each traversing a 16×12 grid path,
WHEN the scene runs for 60 consecutive physics frames (1 second simulated) with Godot profiler enabled on the minimum spec target machine,
THEN total Monster System `_physics_process` CPU time does not exceed 2.0 ms/frame; no frame drops below 60 FPS; profiler output is saved as evidence.

Note: This AC requires a real Godot scene with Grid Autoload and Pathfinding stubs populated. Cannot be verified headlessly without a profiler-capable build.

**Measured 2026-08-01** (`TD-monster-004`, was open since 2026-07-10): avg 0.328ms/frame, max 0.857ms/frame — **PASS**, well within budget. No interactive profiler session was available in this environment, so evidence was saved as a `.md` file with real numeric `Time.get_ticks_usec()` measurements instead of a literal `.png` screenshot (same accepted deviation as `TD-perf-001`) — see `production/qa/evidence/monster-perf-2026-08-01.md` for full method and numbers.

---

### Area 9: BOSS HP Tracking

**AC-29** `[Integration · BLOCKING]`
GIVEN an ACTIVE BOSS with `current_hp = 200.0` and `scaled_hp = 200.0`,
WHEN `monster_damage_taken` is received with `entity_id` matching the BOSS and `amount = 50`,
THEN `boss_hp_changed` is emitted exactly once with `entity_id` matching the BOSS, `current_hp == 150.0`, `max_hp == 200.0`; `boss_hp_changed` is NOT emitted for STANDARD or ELITE entities that receive the same event.

**AC-30** `[Logic · BLOCKING]`
GIVEN an ACTIVE BOSS reaches a GOAL cell with `current_hp > 0`,
WHEN breach resolution executes,
THEN `boss_died` emits with `cause == "breached"` before `monster_breached`; `monster_breached` emits with `tier=2`; `monster_died` is NOT emitted; `boss_hp_changed` is NOT emitted.

**AC-31** `[Logic · BLOCKING]`
GIVEN a BOSS remains in `active_monsters` when `wave_completed` fires (never killed),
WHEN force-removal executes,
THEN `boss_died` emits with `cause == "force_removed"` before `monster_died`; `monster_died` emits with `kill_source == "wave_end"`; no Monster System event other than these two fires for this entity. *(Whether drops resolve is the Resource Economy System's decision upon receiving `kill_source == "wave_end"` — not directly testable by Monster System tests. Resource Economy's suppression behavior is specified in the Dependencies cross-system contract.)*

---

### Area 10: BOSS Targeting Contract

**AC-32** `[Cross-system contract · BLOCKING]`
GIVEN an ACTIVE BOSS with `boss_attack_cooldown_remaining = 0`, `boss_attack_prepare_remaining = 0`, `boss_attack_prepare_frames = 4`, and two towers within `boss_attack_range_cells` range — tower A at Chebyshev distance 1 with HP 200, tower B at Chebyshev distance 3 with HP 10,
WHEN `_physics_process` runs and the scan executes,
THEN `boss_attack_prepare_remaining` is set to 4 (prepare phase entered targeting tower A); `boss_tower_attack_attempted` is NOT emitted this frame; `boss_attack_cooldown_remaining` remains 0. The closest tower (A) — not the lowest-HP tower (B) — is the stored target for when prepare completes.

---

### Area 11: Archetype Tag and Field Contract

**AC-33** `[Logic · BLOCKING]`
GIVEN a MonsterResource with `archetype_tag = &"armored"` and one with `archetype_tag = &""` (default), both spawned as ACTIVE entities,
WHEN `entity.resource.archetype_tag` is read from each entity's `MonsterResource` reference,
THEN the first entity returns `&"armored"` exactly; the second returns `&""` exactly; no error or crash occurs; no type coercion changes the `StringName` value.

**AC-34** `[Integration · BLOCKING]`
GIVEN a `monster_spawn_requested` event with `wave_reward_scalar = 1.5` is received by Monster System,
WHEN the entity spawns and its `scaled_hp` and `scaled_speed` are computed,
THEN neither `scaled_hp` nor `scaled_speed` incorporate `wave_reward_scalar`; the value is not applied in Formula 1 or Formula 2; no error is logged.

---

### Area 12: Absorbed HP Event

**AC-35** `[Logic · BLOCKING]`
GIVEN an ACTIVE STANDARD monster with `current_hp = 50.0`, and two `monster_damage_taken` events with `amount = 10` each arrive for the same `entity_id` in the same `_physics_process` frame,
WHEN the absorbed flush pass executes at end of `_physics_process`,
THEN exactly one `monster_hp_absorbed` event is emitted for that `entity_id`; payload `absorbed == 20` (both hits accumulated and summed); `current_hp == 30.0`; entity remains ACTIVE.

**AC-36** `[Logic · BLOCKING]`
GIVEN an ACTIVE STANDARD monster with `current_hp = 5.0`, and a `monster_damage_taken` event with `amount = 10` arrives (lethal hit),
WHEN the damage pass processes this event,
THEN `lifecycle_state == DEAD`; `monster_died` is emitted; `_pending_absorbed[entity_id]` accumulates `min(10, 5.0) = 5.0` (the killing blow's absorbed amount, capped at the monster's pre-hit HP); the absorbed flush pass at end of frame emits `monster_hp_absorbed(entity_id, absorbed=5)` for this entity like any other hit. *(Corrected 2026-07-15: previously asserted `monster_hp_absorbed` is NOT emitted on lethal hits — that behavior made lifesteal-on-kill impossible, contradicting `damage-status.md`'s Rule VII. See Rule 21f's correction note.)*

---

### Area 13: BOSS Scan Throttle

**AC-37** `[Logic · BLOCKING]`
GIVEN an ACTIVE BOSS with `boss_scan_interval_frames = 6`, `boss_scan_frames_remaining = 0` (scan fires on first frame), and a tower within `boss_attack_range_cells`,
WHEN `_physics_process` is called 12 consecutive frames,
THEN `Grid.get_towers_in_range()` is called exactly twice (once on frame 1, once on frame 7); it is NOT called on frames 2–6 or 8–12.

---

### Area 14: Entity ID Counter

**AC-38** `[Logic · BLOCKING]`
GIVEN a mission where wave 1 spawned 3 monsters (assigned `entity_id` 1, 2, 3), wave 1 completed, and `wave_started` fires with `wave_index = 2`,
WHEN the first monster spawns in wave 2,
THEN it receives `entity_id = 4`; the counter is NOT reset (reset occurs only when `wave_index == 1`); all wave-2 entity IDs are strictly greater than all wave-1 entity IDs.

---

### Area 15: Tarot Modifier Timing

**AC-39** `[Logic · BLOCKING]`
GIVEN two ACTIVE monsters (entity_id 1, entity_id 2) with `scaled_speed = 2.0` each, and `mission_modifier_applied` fires with `modifier_type = "monster_speed_scalar"` and `modifier_value = 0.5` while both are ACTIVE,
WHEN a third monster (entity_id 3) is spawned after the modifier fires,
THEN entity 1 and entity 2 retain `scaled_speed = 2.0` (modifier not applied retroactively to ACTIVE entities); entity 3 spawns with `scaled_speed = base_speed × wave_speed_multiplier × 0.5` (modifier applied at spawn time only).

---

### Area 16: AoE Death Burst Performance

**AC-40** `[Performance · BLOCKING]` — Evidence: profiler output at `production/qa/evidence/monster-aoe-perf-[date].png` — **Corrected 2026-07-31 (ADR-0033)**: this fixture's 22-death count exceeds `eventbus_batch_threshold` (20), which now correctly triggers batching (one `monsters_died_batch` emission, not 22 individual `monster_died` dispatches) — the assertion below was updated to match, and batching should if anything *improve* the measured CPU time versus the prior unconditional per-kill dispatch this AC's budget was originally calibrated against.
GIVEN 22 ACTIVE monsters (21 STANDARD, 1 BOSS) all receive lethal `monster_damage_taken` events in the same physics frame (AoE kill scenario), with all `death_vfx_scene` instantiations deferred,
WHEN the damage pass, death sequences, and absorbed flush all complete within a single `_physics_process` call,
THEN total Monster System CPU time for that frame does not exceed 4.0 ms; because 22 exceeds `eventbus_batch_threshold` (20), Monster System emits exactly one `monsters_died_batch` (all 22 payloads) instead of 22 individual `monster_died` events; `boss_died` still emits synchronously (unbatched) for the BOSS entity; no frame drops below 60 FPS; profiler output saved as evidence.

**Measured 2026-08-01** (`TD-monster-004`): 0.128ms — **PASS**, 3.2% of budget. Every clause independently verified via real spy listeners (batch shape, mutual exclusivity, `boss_died` timing, active-count drop), not just the timing number. No interactive profiler session was available in this environment, so evidence was saved as a `.md` file with real numeric measurements instead of a literal `.png` screenshot (same accepted deviation as AC-28) — see `production/qa/evidence/monster-aoe-perf-2026-08-01.md`.

**AC-43** `[Performance · BLOCKING]` — Evidence: profiler output at `production/qa/evidence/monster-waveend-perf-[date].png`
GIVEN 150 ACTIVE monsters (the `MAX_ACTIVE_MONSTERS` cap) remain in `active_monsters` when `wave_completed` fires,
WHEN force-removal executes (all 150 entities force-removed, each emitting `monster_died` synchronously),
THEN all 150 `monster_died` events emit within the same `_physics_process` call; total Monster System CPU time for that frame does not exceed 4.0 ms; no frame drops below 60 FPS; profiler output saved as evidence. *(If any of the 150 entities is a BOSS, `boss_died` must also emit before `monster_died` for that entity — within the same frame.)*

---

### Area 17: BOSS Attack Telegraph

**AC-41** `[Logic · BLOCKING]`
GIVEN an ACTIVE BOSS with `boss_attack_cooldown_remaining = 0`, `boss_attack_prepare_remaining = 0`, `boss_attack_prepare_frames = 4`, and a tower within `boss_attack_range_cells` when the scan executes,
WHEN `_physics_process(delta)` runs,
THEN `boss_attack_prepare_remaining` is set to 4; `boss_tower_attack_attempted` is NOT emitted this frame (prepare phase not yet complete); `boss_attack_cooldown_remaining` remains 0 (cooldown reset happens only when `boss_tower_attack_attempted` actually fires after prepare completes per Rule 17d.1).

**AC-42** `[Logic · BLOCKING]`
GIVEN an ACTIVE BOSS with `boss_attack_prepare_remaining = 1`, `base_attack_interval = 3.0`, and `_locked_target_id` set to a valid tower_id (prepare phase was entered on a prior frame),
WHEN `_physics_process(delta)` runs,
THEN `boss_attack_prepare_remaining` decrements to 0; `boss_tower_attack_attempted` emits with the `_locked_target_id` as `target_tower_id` and `base_damage`; `boss_attack_cooldown_remaining` resets to `base_attack_interval` (3.0); `boss_attack_prepare_remaining` is now 0 (ready for next prepare cycle); `_locked_target_id` is cleared to -1; overlay `AnimatedSprite2D` plays `"attack"` animation.

## Open Questions

**OQ-1: RESOLVED** — `monster_spawn_requested` is registered in the EventBus GDD (Wave Manager events section). Field name corrected: `wave_difficulty_scalar` → `wave_reward_scalar`. Rule 6 and all related ACs updated.

**OQ-2: RESOLVED** — `path_invalidated` is registered in the EventBus GDD (Pathfinding System events section). Payload: `affected_cells: Array[Vector2i]`. No Monster GDD changes required.

**OQ-3: RESOLVED** — `monster_breached` is registered in the EventBus GDD. Payload: `entity_id: int`, `monster_id: StringName`, `tier: int`. No Monster GDD changes required.

**OQ-4: RESOLVED** — D&S GDD defines `MonsterDamageTaken` Resource with: `entity_id: int`, `amount: int`, `source_type: int`, `is_crit: bool`, `hero_bonus_tier: int`. Rules 20–21 updated to use `amount` and `source_type`. `source_type` mapping: `0 = "tower"`, `1 = "hero"`. `hero_bonus_tier` values: `0 = STANDARD` (no bonus), `1 = ELITE`, `2 = BOSS`. The `resolved_damage`, `hit_source`, `is_lethal`, and `hero_bonus_applied` fields do not exist in the D&S payload. (`hero_bonus_applied: bool` was replaced by `hero_bonus_tier: int` in the D&S GDD revision 2026-05-12.)

**OQ-5: RESOLVED** — Option A adopted. Monster System emits `boss_hp_changed` (payload: `entity_id: int`, `current_hp: float`, `max_hp: float`) each time a BOSS receives `monster_damage_taken` and survives. This is an **MVP-required event**. EventBus GDD updated (2026-04-26). See Rule 21c and AC-29.

**OQ-6: RESOLVED** — `boss_died` now fires on both breach and force-removal with a `cause: String` discriminator (`"killed"` / `"breached"` / `"force_removed"`). EC-3.2 and EC-4.2 updated. Wave Manager GDD must handle all three `cause` values in its wave-clear logic.

**OQ-7: RESOLVED** — BOSS breach is informational only: increments a breach counter, triggers HUD feedback. No gameplay consequence is defined at MVP beyond the counter. "Highest stakes / mission-ending" framing removed from Overview and Player Fantasy. If playtesting reveals BOSS breaches feel unpunishing, a loss condition can be added — but that requires Game Concept and Hero System GDD changes. No Monster System changes needed to close this question.

**OQ-8: RESOLVED** (found already answered elsewhere, not marked here — `/design-review` 2026-08-27) — `resource-economy.md` Rule 6 names the material `menagerie_lure`, rolled independently from `menagerie_attraction_drop_chance` (flat 0.0–1.0, per-monster-type, deliberately not scaled by `wave_reward_scalar` — a rare-find mechanic, not part of the wave-escalating economy) and delivered to Inventory via `materials_earned`. No rarity tiers — `menagerie_lure` is a single flat material. Consumption is fully specified and shipped in `menagerie.md`/`src/core/menagerie/menagerie.gd`: `Menagerie.attempt_lure()` queries `Inventory.has_item_quantity(&"menagerie_lure", cost)` and consumes it via `consume_stackable()`, emitting `materials_spent`. `menagerie_attraction_drop_chance` values in MonsterResource are live-consumed data, not placeholders.

**OQ-9: Architectural note — spawn must route through EventBus**
Wave Manager must emit `monster_spawn_requested` (EventBus event) to initiate monster spawning. Calling `MonsterSystem.spawn(...)` directly is prohibited — it violates EventBus Rule 1 (no direct system references). Documented to prevent this from being re-proposed during implementation.

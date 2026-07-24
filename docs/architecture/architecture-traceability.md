# Architecture Traceability Index

**Last Updated**: 2026-07-17 (Pass 5, scoped gap-analysis — see `architecture-review-2026-07-17.md` — verdict **CONCERNS**. Not a full re-derivation: Phase 4/5 not re-run since no existing ADR content changed, only 9 new zero-coverage GDDs were added. See that report's own Scope Note.)
**Engine**: Godot 4.6.2 / GDScript
**ADRs**: 19 total, **all Accepted** for the systems they cover — **0 of 19 cover any of the 9 systems designed 2026-07-16/17** (Constellation, Crafting, Tarot, Menagerie, Defense Building, Tower Mastery, Mission Select, Hero Skill Build, Equipment Forge)
**TR Registry Version**: 7

## Pass 5 Findings (2026-07-17) — new, non-blocking (no Foundation/Core gaps)

Full detail in `architecture-review-2026-07-17.md`. Summary: 9 GDDs authored 2026-07-16/17 (all Feature/Advanced tier per `systems-index.md`) have **zero ADR coverage**, confirmed via grep of all 19 existing ADR files — none reference any of the 9 systems by name. 27 new TR-IDs registered (`tr-registry.yaml` v7), all ❌ Gap. Two cross-system ordering questions flagged but not resolved (matching, not duplicate, findings): whether Hero Skill Build's restore needs Tower Mastery's state already restored first (`TR-heroskill-002` / `TR-towermast-003`), and `architecture.md`'s pre-2026-07-13 Module Ownership guesses for these 9 systems are now superseded by real GDD contracts (e.g. its `constellation_broken` guess vs. the actual `constellation_deactivated` event) and need a refresh pass. 11 ADRs recommended, in dependency order — see the report's "ADR Dependency Order" and "Required ADRs" sections. Recommended first ADR: a **Direct-Autoload-call exception pattern** ADR, since this pattern (Grid Rule 8/9, Mission Select's `retry_current_mission()`, Mission HUD's new DEFEAT Retry button) has now been independently re-justified in prose 3 times without ever being formalized once.

## Pass 4 Findings (2026-07-13d) — new, non-blocking

Full detail in `architecture-review-2026-07-13d.md`. Summary:

1. ~~**ADR-0019 status staleness**~~ — **RESOLVED 2026-07-13, same-day follow-up.** ADR-0019 was Accepted (all dependency ADRs already Accepted, no blocking `godot-specialist` findings, its own Ordering Note confirmed it was implementation-ready). This document, `control-manifest.md`, and `architecture.md`'s ADR Audit section have all been corrected to reflect 19/19 ADRs Accepted and TR-tower-007 now ✅ Covered.
2. ~~**ADR-0005 self-contradiction**~~ — **RESOLVED 2026-07-13, same-day follow-up.** Its Engine Compatibility table previously said "Post-Cutoff APIs Used: None" while its Decision text used `Dictionary[Vector2i, CellType]`/`Dictionary[Vector2i, int]` (Godot 4.4+ typed Dictionaries). Corrected to list the typed Dictionaries used; the associated "may not compile" Risk entry was also closed as resolved (already verified working per `grid-system.md`'s own Engine Risk Notes table). Documentation-accuracy fix only — no behavior change.
3. **`mission-hud.md` registered for the first time** — was a zero-TR, zero-ADR skeleton GDD; its three locked signal contracts (PC-1/PC-2/PC-3) are now tracked as `TR-hud-001..003` (see Full Matrix and TR registry) even though the rest of the GDD is unfinished.
4. **28 new granular TR-IDs added** across EventBus, Grid, Save, Hero, Tower, Monster, Pathfinding, Wave Manager, Inventory, Resource Economy, and Mission HUD — cross-system binding contracts, gotchas, and known gaps surfaced by a full GDD re-read that weren't previously registered (existing registry entries are deliberately coarse; these are finer-grained but still genuinely architectural — see `tr-registry.yaml` v6 for the full list). Two are flagged as **gaps needing follow-up**: `TR-inv-005` (Tower→Inventory `item_added` wiring missing on tower destruction) and `TR-hero-007` (payload mismatch between shipped `hero_skill_activated` and Mission HUD's design assumption — blocks HUD skill-button implementation until reconciled).
5. ~~Two long-open "Verification Required" engine risks~~ — both now live-tested. **FileAccess semantics (`save-persistence.md`/ADR-0003) VERIFIED 2026-07-13** via a live MCP smoke test against the actual pinned Godot 4.6.2.stable binary (`save_slot()`→`load_slot()` round-trip, atomic rename, bool-return checks all confirmed correct — see ADR-0003). **Godot 4.6 glow rework (`hero.md`/`tower.md`) partially characterized 2026-07-13** — live MCP test found no visible bloom on overbright 2D content without `Viewport.use_hdr_2d` enabled, and enabling `use_hdr_2d` darkens the *entire* scene globally, independent of glow — confirmed by isolating the variable (tested with glow off). This narrows the risk from "unknown behavior" to "known integration cost": glow VFX for this project needs a deliberate whole-scene brightness/contrast pass alongside `use_hdr_2d` opt-in, not a simple toggle. Still recommend a follow-up test with the project's actual planned VFX assets before locking texture import presets — see `docs/engine-reference/godot/VERSION.md`.

## Cross-ADR Conflicts (2026-07-13, Pass 2) — both now RESOLVED

Full `/architecture-review` Phase 4 contract-diffing (not just requirement-existence checking) surfaced two implementation-breaking-*looking* contradictions between Accepted ADRs' text that no prior pass caught. Full detail in `architecture-review-2026-07-13b.md`. Both turned out to be pure documentation drift — the shipped code was already self-consistent in both cases.

1. ~~**`tower_id` type/arity conflict**~~ — **RESOLVED 2026-07-13.** ADR-0005 (Grid) typed it `int`; ADR-0008 (Tower)'s text said `String` and passed a String into Grid's int-typed `place_tower()`; ADR-0010 (Hero) expected `int` with a different signal argument order than ADR-0008's text showed. Checked against shipped `grid.gd`/`tower_system.gd`/`event_bus.gd`/`hero.gd`: the actual implementation was already fully consistent — `TowerSystem.place_tower(blueprint_id: StringName, top_left)` takes a catalog key and mints its own runtime `int tower_id`, which is what's passed to Grid and the bus; `tower_placed`/`tower_removed`/`tower_destroyed` are 5/3/4-arg signals that Hero's handlers already match exactly. ADR-0008 and ADR-0010 revised to document the real, shipped contract instead of stale placeholder sketches.
2. ~~**SaveRestorer interface drift**~~ — **RESOLVED 2026-07-13.** ADR-0003 (Save & Persistence, Foundation) previously specified `apply_save_data()` + a static hardcoded key list, while ADR-0016/0017/0010 (and the already-shipped S2-02 code) all used a different `restore_save_data()` + `register(self, restore_order)` pattern ADR-0003 never defined. ADR-0003 has been revised to formally adopt the `SaveRestorer` interface (`get_save_key()`/`get_save_data()`/`restore_save_data()`/`reset_to_defaults()`/`register()`) as canonical, matching the shipped code and every consuming ADR. No behavioral/code change — text-only correction.

Both blocking items are now closed. The coverage percentages below can be read as implementation-safe for the Tower/Hero/Grid/Save boundaries. One informational (non-blocking) item surfaced during the ADR-0008 revision: Gate 2 (resource check) uses `TowerSystem`'s own locally-cached `_player_gold` rather than calling `MissionEconomy.can_afford()` — `MissionEconomy` (ADR-0018, Accepted same day) has not yet been implemented. Not a conflict, just a pending follow-up once that Autoload is built.

## Coverage Summary

| Status | Count | % |
|--------|-------|---|
| ✅ Covered | 78 | 67% |
| ⚠ Partial | 3 | 3% |
| ❌ Gap | 36 | 31% |
| **Total** | **117** | 100% |

*Pass 5 (2026-07-17) added 27 new TR-IDs (90 → 117), all ❌ Gap — first-time registration for 9 systems (constellation, crafting, tarot, menagerie, defense-building, tower-mastery, mission-select, hero-skill-build, equipment-forge), none of which have any ADR yet. This is a real, expected drop in the Covered percentage (87%→67%) from adding a large batch of freshly-designed, not-yet-architected systems in one pass — not a regression in the 90 pre-existing entries, which are all unchanged.*

*ADR-0019 Accepted 2026-07-13 (same-day follow-up to Pass 4) — TR-tower-007 moved from ❌ Gap to ✅ Covered. Corrected 2026-07-13 (confirmation re-run): the Partial count was previously miscounted as 2 (79 Covered), omitting TR-tower-009 — which Pass 4 itself added as a new ⚠ Partial row — from the summary tally. Actual Full Matrix partials: TR-tower-005, TR-path-007, TR-tower-009 (3 total).*

*Pass 4 (2026-07-13d) added 25 new TR-IDs (65 → 90). Of these, 18 are
✅ Covered, 6 are new ❌ Gap (TR-hero-007 conflict, TR-inv-004, TR-inv-005,
TR-hud-001/002/003), and 1 is new ⚠ Partial (TR-tower-009 — cross-GDD
timing constraint not independently re-verified against shipped Wave
Manager code this pass). Pre-existing counts (60 covered / 1 partial /
4 gap out of 65) are unchanged from Pass 3 — the pre-existing summary
table and Full Matrix had a known minor bookkeeping mismatch (Full Matrix
showed 2 partials pre-Pass-4: TR-tower-005, TR-path-007). **Reconciled
2026-07-13 (confirmation re-run following ADR-0019 acceptance)**: the
Coverage Summary table above now correctly totals 3 partials
(TR-tower-005, TR-path-007, TR-tower-009) and 78 covered — this note is
kept for history rather than deleted, since it explains why the drift
happened (TR-tower-009 was added in the same pass that also introduced
this disclaimer, and wasn't folded into the disclaimer's own count).*

*2026-07-13 Pass 2: added TR-tower-007 (projectile pooling — `tower.md` Rules 18/19 firmly mandate a fixed-size pool and re-acquisition rate limit; no prior ADR or registry entry existed). All 64 pre-existing entries confirmed still active/unchanged; recommend reclassifying TR-gc-004 out of the registry (design/balance target, not architectural) — flagged for user decision, not auto-changed.*

*2026-07-13 Pass 1 (earlier same day): added 6 new TRs (TR-inv-001..003, TR-econ-001..003) covering `inventory.md` and `resource-economy.md`, both authored 2026-07-10/11 and never previously registered. ADR-0016 and ADR-0017 had their flagged conflicts fixed (restore_order collision; Wave Manager precedent misattribution) and were Accepted. **ADR-0018 (Mission Economy — Runtime Gold Balance Ownership)** was then authored and Accepted the same day, resolving TR-econ-003's remaining Partial status by adding a new Autoload (`MissionEconomy`, boot position 8) that tracks the runtime gold balance — closing the last open question from ADR-0017.*

## Roadmap Numbering

| ADR | System | Status |
|-----|--------|--------|
| ADR-0001 | EventBus | Accepted |
| ADR-0002 | Scene/Autoload structure | Accepted (revised 2026-05-24) |
| ADR-0003 | Save file format | Accepted |
| ADR-0004 | Pathfinding strategy | Accepted |
| ADR-0005 | Grid system data model | Accepted |
| ADR-0006 | Monster movement | Accepted |
| ADR-0007 | Damage pipeline | Accepted |
| ADR-0008 | Tower placement gate | Accepted (2026-05-19) |
| ADR-0009 | Resource data model | Accepted |
| ADR-0010 | Hero Tower-Synced Class | Accepted |
| ADR-0011 | UI dual-focus | Accepted (2026-07-13) — reusable `InputModeTracker` helper, scene-instanced per UI screen |
| ADR-0012 | Wave Manager FSM | Accepted |
| ADR-0013 | Sprite atlas / draw-call batching | Accepted (2026-06-30) |
| ADR-0014 | Pause system | Accepted (2026-07-08) |
| ADR-0015 | Collision layer convention | Accepted (2026-07-08) |
| ADR-0016 | Inventory storage model | Accepted (2026-07-11; `restore_order` corrected 20→10 and Accepted 2026-07-13) |
| ADR-0017 | Resource Economy drop resolution | Accepted (2026-07-11; Wave Manager precedent citation corrected and Accepted 2026-07-13) |
| ADR-0018 | Mission Economy — runtime gold balance ownership | Accepted (2026-07-13) — new Autoload `MissionEconomy` at boot position 8 |
| ADR-0019 | Projectile pooling | **Accepted (2026-07-13)** — closes TR-tower-007; HOMING/BALLISTIC tower-weapon stories are now unblocked |

## Full Matrix

| TR-ID | GDD | Requirement | ADR Coverage | Status |
|-------|-----|-------------|--------------|--------|
| TR-eb-001 | event-bus | Typed signal catalogue (74 events as of 2026-07-13) | ADR-0001 | ✅ |
| TR-eb-002 | event-bus | Cascade depth ≤ 2 levels | ADR-0001 | ✅ |
| TR-eb-003 | event-bus | Deferred dispatch for physics callers | ADR-0001 | ✅ |
| TR-eb-004 | event-bus | Batch threshold 20/frame for monster_died | ADR-0001 | ✅ |
| TR-eb-005 | event-bus | Resource subclass payloads for 5+ field events | ADR-0001 | ✅ |
| TR-eb-006 | event-bus | ≤1.667 ms/frame total EventBus processing | ADR-0001 | ✅ |
| TR-grid-001 | grid-system | 16×12 default grid; 5 cell types | ADR-0005 | ✅ |
| TR-grid-002 | grid-system | Direct read API (Autoload); write restricted to Tower | ADR-0005 | ✅ |
| TR-grid-003 | grid-system | `world_to_cell` uses `floor()` | ADR-0005 | ✅ |
| TR-grid-004 | grid-system | Returns copies, not references | ADR-0005 | ✅ |
| TR-save-001 | save-persistence | 3 save slots; atomic write (.tmp → .dat) | ADR-0003 | ✅ |
| TR-save-002 | save-persistence | FileAccess `bool` return check (4.4+) | ADR-0003 | ✅ |
| TR-save-003 | save-persistence | Restore order 10–33; deferred 1 frame | ADR-0003 | ✅ |
| TR-save-004 | save-persistence | Format version + migration registry | ADR-0003 | ✅ |
| TR-save-005 | save-persistence | Save format decision | ADR-0003 | ✅ |
| TR-save-006 | save-persistence | 4 auto-save triggers via EventBus | ADR-0003 | ✅ |
| TR-hero-001 | hero | CharacterBody2D scene root | ADR-0002 | ✅ |
| TR-hero-002 | hero | 12 stats; Tower-Synced Class (Chebyshev 3-cell) | ADR-0010 | ✅ |
| TR-hero-003 | hero | Tower Affinity sqrt scaling | ADR-0010 | ✅ |
| TR-hero-004 | hero | Event-driven targeting (no direct Monster refs) | ADR-0007 | ✅ |
| TR-hero-005 | hero | 4 active skills + Ultimate | — (Alpha: Hero Skill Build) | ❌ |
| TR-hero-006 | hero | 6 stat formulas (crit, lifesteal, affinity, etc.) | ADR-0010 (F1/F2); ADR-0007 (F4/F5/F6) | ✅ |
| TR-tower-001 | tower | 4 component slots; 4 archetypes; 4 tiers | ADR-0009 | ✅ |
| TR-tower-002 | tower | Placement blocked during WAVE_ACTIVE | ADR-0008 | ✅ |
| TR-tower-003 | tower | Monster cache via EventBus; no direct refs | ADR-0007 | ✅ |
| TR-tower-004 | tower | `would_block_all_paths()` gate before placement | ADR-0008 | ✅ |
| TR-tower-005 | tower | Pre-placement perk (Scout phase only) | ADR-0009 (perk data only) | ⚠ Partial (Scout-only activation rule has no ADR) |
| TR-tower-006 | tower | Support archetype aura pulse model | ADR-0009 | ✅ |
| TR-tower-007 | tower | Projectile pooling (fixed pool at mission start, size 192) + re-acquisition rate limit (8/frame) | ADR-0019 (Accepted 2026-07-13) | ✅ |
| TR-monster-001 | monster | Area2D scene root (not CharacterBody2D) | ADR-0002, ADR-0006 | ✅ |
| TR-monster-002 | monster | MonsterResource data-driven stats; 3 tiers | ADR-0009, ADR-0006 | ✅ |
| TR-monster-003 | monster | `_pending_damage` buffer flushed in `_physics_process` | ADR-0006 | ✅ |
| TR-monster-004 | monster | Position-based movement (not physics-driven) | ADR-0002, ADR-0004, ADR-0006 | ✅ |
| TR-monster-005 | monster | Dual-layer AnimatedSprite2D | ADR-0006 | ✅ |
| TR-monster-006 | monster | Boss scan throttle + prepare-frames telegraph | ADR-0006 | ✅ |
| TR-ds-001 | damage-status | Two pipelines: direct hit + DoT | ADR-0007 | ✅ |
| TR-ds-002 | damage-status | `await` + `is_instance_valid` guard pattern | ADR-0007 | ✅ |
| TR-ds-003 | damage-status | `_lifesteal_pending` Dictionary[int, float] | ADR-0007 | ✅ |
| TR-ds-004 | damage-status | 5 status effect types + stack/duration rules | — (separate ADR required post-MVP) | ❌ |
| TR-ds-005 | damage-status | No direct call API — EventBus only | ADR-0007 | ✅ |
| TR-path-001 | pathfinding | AStar2D Autoload (not NavigationServer) | ADR-0004, ADR-0002 | ✅ |
| TR-path-002 | pathfinding | Route templates with `cell_index_map` | ADR-0004 | ✅ |
| TR-path-003 | pathfinding | Super-goal node for multi-goal convergence | ADR-0004 | ✅ |
| TR-path-004 | pathfinding | `templates_ready` event gates all spawning | ADR-0004 | ✅ |
| TR-path-005 | pathfinding | `would_block_all_paths()` speculative check | ADR-0004 | ✅ |
| TR-path-006 | pathfinding | Deferred dirty rebuild on tower changes | ADR-0004 | ✅ |
| TR-path-007 | pathfinding | 100+ simultaneous agents at 60 FPS | ADR-0004, ADR-0006 | ⚠ Partial (perf-budgeted; ADR-0006 Accepted; profiling evidence still required — prototype recommended) |
| TR-wave-001 | wave-manager | 7-state phase lifecycle FSM | ADR-0012 | ✅ |
| TR-wave-002 | wave-manager | WaveConfig/WaveScript/WaveSpawnEntry Resources | ADR-0009 | ✅ |
| TR-wave-003 | wave-manager | BOSS breach = wave-clear | ADR-0012 | ✅ |
| TR-wave-004 | wave-manager | `templates_ready` gate before first spawn | ADR-0004, ADR-0012 | ✅ |
| TR-wave-005 | wave-manager | Wave-stuck watchdog (30 s stalled / 60 s force-clear) | ADR-0012 | ✅ |
| TR-wave-006 | wave-manager | `wave_reward_scalar` semantic contract | ADR-0012 | ✅ |
| TR-wave-007 | wave-manager | Penultimate-wave rule (sub-boss at wave N-1) | ADR-0012 | ✅ |
| TR-wave-008 | wave-manager | Waves 2+ rebuild-pending gate (`is_rebuild_pending()` check at INTERMISSION→PRE_WAVE) | ADR-0004, ADR-0012 | ✅ (retroactively registered 2026-07-07 — closes the `TR-wave-004` registry gap; already shipped in Story 005) |
| TR-gc-001 | game-concept | All 9 systems communicate via EventBus only | ADR-0001 | ✅ |
| TR-gc-002 | game-concept | Autoload boot order | ADR-0002 | ✅ |
| TR-gc-003 | game-concept | Mission states: SCOUT/WAVE_ACTIVE/INTERMISSION/etc. | ADR-0002 (outer), ADR-0012 (inner FSM) | ✅ |
| TR-gc-004 | game-concept | 15–25 min default mission (session length formula) | — (design tuning, not architecture) | ❌ (N/A — no ADR needed) |
| TR-inv-001 | inventory | 10-slot start; type-driven stack caps (1 vs 99) | ADR-0016 | ✅ (Accepted) |
| TR-inv-002 | inventory | `instance_id`-keyed unique-item identity — stat-rolled duplicates never merge (AC-18) | ADR-0016 | ✅ (Accepted) |
| TR-inv-003 | inventory | `SaveRestorer` interface + `restore_order` below Hero's 30 | ADR-0016 | ✅ (fixed 2026-07-13: `restore_order` corrected to 10, matching `save-persistence.md`'s Formula 4 table; Accepted) |
| TR-econ-001 | resource-economy | Stateless calculator pattern (Core Rule 1) | ADR-0017 | ✅ (Accepted) |
| TR-econ-002 | resource-economy | `DropTableResource`/`DropEntry` schema + Formulas 1–4 | ADR-0017 | ✅ (Accepted) |
| TR-econ-003 | resource-economy | Gold track via `resources_changed`, separate from materials | ADR-0017, ADR-0018 | ✅ (gold-balance ownership resolved by ADR-0018's new `MissionEconomy` Autoload, Accepted 2026-07-13) |
| TR-eb-007 | event-bus | `hero_healed` sync cascade-depth-1 exemption from `monster_hp_absorbed` handler | ADR-0001 | ✅ |
| TR-eb-008 | event-bus | EventBus Autoload must be first entry in Project Settings → Autoloads | ADR-0002 | ✅ |
| TR-grid-005 | grid-system | Grid ACTIVE_WRITABLE/ACTIVE_READONLY driven exclusively by `mission_phase_changed` | ADR-0005 | ✅ |
| TR-grid-006 | grid-system | Grid never emits EventBus events directly; Tower includes cell data in payloads | ADR-0005, ADR-0008 | ✅ |
| TR-save-007 | save-persistence | Exclusive disk-I/O contract — no other system may call `FileAccess` directly | ADR-0003 | ✅ (process/code-review criterion) |
| TR-save-008 | save-persistence | SaveRestorer 3-function interface mandatory for all registered systems | ADR-0003 | ✅ |
| TR-hero-007 | hero | `hero_skill_activated` payload contract vs Mission HUD's `skill_slot:int` assumption | — | ❌ **GAP (conflict)** — blocks Mission HUD skill-button implementation until reconciled |
| TR-hero-008 | hero | `hero_position_changed` emitted only on cell-boundary crossing, not per-frame | ADR-0010 | ✅ |
| TR-tower-008 | tower | Monster-cache subscription-mode table (sync vs `CONNECT_DEFERRED`) authoritative per AC B-13 | ADR-0007 | ✅ |
| TR-tower-009 | tower | Wave Manager must yield ≥1 frame between `wave_completed` and next `wave_started` (`CONNECT_DEFERRED`) | ADR-0012 | ⚠ Partial — cross-GDD binding constraint, not independently verified against Wave Manager's shipped implementation this pass |
| TR-tower-010 | tower | `is_siege:bool` must be read by Monster/Boss on `tower_attacked` (not `boss_tower_attack_attempted`) | ADR-0006, ADR-0007 | ✅ |
| TR-monster-007 | monster | `MAX_ACTIVE_MONSTERS=150` hard ceiling — spawns above cap silently discarded | ADR-0006 | ✅ |
| TR-monster-008 | monster | `hero_damage_bonus_eligible` field deprecated — must not be read by any system | ADR-0006 | ✅ |
| TR-path-008 | pathfinding | Exactly one SPAWN cell per mission (MVP hard constraint); CI must hard-fail multi-SPAWN | ADR-0004 | ✅ |
| TR-path-009 | pathfinding | Row-major point-ID encoding is a binding convention | ADR-0004 | ✅ |
| TR-path-010 | pathfinding | `get_path()` not thread-safe — forbidden from Thread/WorkerThreadPool | ADR-0004 | ✅ |
| TR-path-011 | pathfinding | `_compute_cost()` override for zero-cost super-goal edges mandatory (separate from `_estimate_cost()`) | ADR-0004 | ✅ |
| TR-wave-009 | wave-manager | `hero_died` always → DEFEAT, takes priority over same-frame wave-clear | ADR-0012 | ✅ |
| TR-wave-010 | wave-manager | `MAX_BASE_QUALITY_PROBABILITY=0.2097` cross-system constant, Resource Economy must calibrate against | ADR-0012, ADR-0017 | ✅ |
| TR-inv-004 | inventory | `item_pickup_rejected` signal must be added to `event-bus.md`'s catalogue | — | ❌ **GAP** — signal shipped but undocumented in catalogue |
| TR-inv-005 | inventory | Tower must call `item_added` with `metadata.damaged` on tower destruction | — | ❌ **GAP** — cross-system wiring missing, non-blocking |
| TR-econ-004 | resource-economy | `resources_changed(gold)` is a signed delta, not absolute balance — MissionEconomy must accumulate | ADR-0017, ADR-0018 | ✅ |
| TR-hud-001 | mission-hud | On `path_invalidated`, call `get_path()` to re-derive route — never render `affected_cells` as a route line | — | ❌ **GAP** — no ADR yet, GDD still a skeleton |
| TR-hud-002 | mission-hud | On `tower_placement_blocked`, distinguish `primary_blocking_cell` sentinel (-1,-1) from single-cell case | — | ❌ **GAP** — no ADR yet |
| TR-hud-003 | mission-hud | On `tower_destroyed` during WAVE_ACTIVE, display "path update queued for next intermission" | — | ❌ **GAP** — no ADR yet |
| TR-const-001 | constellation | Localized Chebyshev-radius (radius=3) pattern-detection algorithm, O(local) not O(total towers) | — | ❌ **GAP** — no ADR yet |
| TR-const-002 | constellation | Discovery Ledger persistence (restore_order=24) | — | ❌ **GAP** — no ADR yet |
| TR-const-003 | constellation | `constellation_eligibility_tag` subscriber-side read path | — | ❌ **GAP** — no ADR yet |
| TR-craft-001 | crafting | `RecipeResource` data schema via `GameDataRegistry` (extends ADR-0009's convention) | — | ❌ **GAP** — no ADR yet |
| TR-craft-002 | crafting | Dual-gate discovery trigger architecture (`tech_unlocked` AND `item_added`) | — | ❌ **GAP** — no ADR yet |
| TR-craft-003 | crafting | Inventory API additions (`has_room_for`, `clear_damaged_flag`, `has_items`) + `component_repaired` event | — | ❌ **GAP** — no ADR yet, shared scope with TR-equipforge-001 |
| TR-tarot-001 | tarot | Modifier aggregation architecture (4 `modifier_type`s, MULTIPLICATIVE/REPLACE) | — | ❌ **GAP** — no ADR yet |
| TR-tarot-002 | tarot | 5-tier mastery progression persistence (restore_order=22) | — | ❌ **GAP** — no ADR yet |
| TR-tarot-003 | tarot | Rune discovery layer data model | — | ❌ **GAP** — no ADR yet |
| TR-menag-001 | menagerie | 3-state creature lifecycle (RESERVE/HABITAT/BREEDING_PEN, terminal SACRIFICED) | — | ❌ **GAP** — no ADR yet |
| TR-menag-002 | menagerie | Happiness decay/tend formulas ticking on `mission_launched`, not wall-clock | — | ❌ **GAP** — no ADR yet |
| TR-menag-003 | menagerie | Save persistence for creature instances + aggregate bonus (restore_order=20) | — | ❌ **GAP** — no ADR yet |
| TR-defbuild-001 | defense-building | 5-node tech tree data schema (2 categories) | — | ❌ **GAP** — no ADR yet |
| TR-defbuild-002 | defense-building | `sanctuary_structure_built` contract for Habitat Expansion (verified matches menagerie.md exactly) | — | ❌ **GAP** — no ADR yet |
| TR-defbuild-003 | defense-building | Persistence for unlock-tree state (restore_order=21) | — | ❌ **GAP** — no ADR yet |
| TR-towermast-001 | tower-mastery | Live proximity-detection performance during WAVE_ACTIVE — HIGH engine risk, recommend prototype first | — | ❌ **GAP** — no ADR yet |
| TR-towermast-002 | tower-mastery | `TowerSystem.get_component_loadout(tower_id)` query API | — | ❌ **GAP** — no ADR yet |
| TR-towermast-003 | tower-mastery | `build_signature` persistence keying (restore_order=34); ordering question vs. TR-heroskill-002 unresolved | — | ❌ **GAP** — no ADR yet |
| TR-missel-001 | mission-select | `retry_current_mission()` — 3rd unformalized instance of the direct-Autoload-call exception pattern | — | ❌ **GAP** — no ADR yet |
| TR-missel-002 | mission-select | `GridConfig` same-instance guarantee across DEFEAT→retry restart | — | ❌ **GAP** — no ADR yet |
| TR-missel-003 | mission-select | Save persistence for completion flags/best times (restore_order=11) | — | ❌ **GAP** — no ADR yet |
| TR-heroskill-001 | hero-skill-build | Ultimate-derivation lookup table (35 raw profiles → 19 fixed IDs, re-verified correct) | — | ❌ **GAP** — no ADR yet |
| TR-heroskill-002 | hero-skill-build | Save persistence for unlocked skills (restore_order=31); ordering question vs. TR-towermast-003 unresolved | — | ❌ **GAP** — no ADR yet |
| TR-equipforge-001 | equipment-forge | `Inventory.apply_rune_to_item()` in-place mutation API — shared scope with TR-craft-003 | — | ❌ **GAP** — no ADR yet |
| TR-equipforge-002 | equipment-forge | `Menagerie.request_sacrifice(creature_id, target_item_id)` cross-system call boundary | — | ❌ **GAP** — no ADR yet |
| TR-equipforge-003 | equipment-forge | Persistence for crafted/imbued gear (restore_order=32); Constellation restore_order dependency now assignable | — | ❌ **GAP** — no ADR yet |

## Known Gaps

### Feature/Advanced Layer — 9 systems designed 2026-07-16/17, zero ADR coverage (added Pass 5, 2026-07-17)
- Constellation, Crafting, Tarot, Menagerie, Defense Building: Feature layer — TR-const-*, TR-craft-*, TR-tarot-*, TR-menag-*, TR-defbuild-* all ❌ gaps, no ADR exists. None are Foundation/Core, so none block the project's current Approved-system implementation work — but all block these 5 systems' own future epics/stories from reaching `Ready`.
- Tower Mastery, Mission Select, Hero Skill Build, Equipment Forge: Advanced layer — TR-towermast-*, TR-missel-*, TR-heroskill-*, TR-equipforge-* all ❌ gaps. Equipment Forge (7 upstream dependencies) should get its ADR last, per `systems-index.md`'s own explicit guidance. Two systems (Tower Mastery, Hero Skill Build) share one still-open restore-ordering question that whichever ADR is written second should resolve, not re-open.
- See `architecture-review-2026-07-17.md`'s "ADR Dependency Order" section for the full recommended write-order across all 11 suggested ADRs.

### Foundation Layer
- ✅ All Foundation TRs fully covered and implementable (EventBus, Save, Grid, Pathfinding).

### Core Layer
- Monster: All 6 TRs ✅ fully covered and implementable (ADR-0006 + ADR-0009 Accepted).
- Damage & Status: TR-ds-001/002/003/005, TR-hero-004, TR-tower-003 ✅ (ADR-0007 Accepted). TR-ds-004 (status effects) deferred to post-MVP ADR — ❌ gap, no ADR needed at this stage.
- Tower: TR-tower-002/004 ✅ (ADR-0008); TR-tower-001/006 ✅ (ADR-0009 Accepted); TR-tower-005 ⚠ partial (Scout-only perk activation rule has no ADR); TR-tower-007 ✅ (ADR-0019 Accepted 2026-07-13 — projectile pooling, HOMING/BALLISTIC weapon stories now unblocked).

### Feature Layer
- Wave Manager: All 7 TRs ✅ fully covered (ADR-0012 Accepted 2026-05-24). No Wave Manager TRs are impl-blocked.

### Hero subsystem (ADR-0010 Accepted 2026-05-24)
- TR-hero-002, 003, 006 ✅ — all covered by ADR-0010.
- TR-hero-004 ✅ — covered by ADR-0007 (event-driven targeting).
- TR-hero-005 ❌ — Alpha-tier gap (Hero Skill Build); no ADR needed at this stage.
- TR-hero-007 ❌ (new Pass 4) — **conflict, not just a gap**: shipped `hero_skill_activated` payload is `(skill_id:String, target_position:Vector2)`, but `mission-hud.md`'s design assumes `skill_slot:int`. Blocks Mission HUD skill-button implementation until reconciled — needs a design decision (rename the field in the HUD design, or add a derived `skill_slot` lookup) before that GDD section is finished.

### Mission HUD (new Pass 4 — skeleton GDD, no ADR yet)
- TR-hud-001/002/003 ❌ — three locked signal-response contracts (`path_invalidated`, `tower_placement_blocked`, `tower_destroyed` during WAVE_ACTIVE) are independently testable now, but the GDD itself is unfinished and has no governing ADR. Lower priority than Foundation/Core gaps since Mission HUD is a leaf consumer with no downstream dependents — track but don't block on it.

### Inventory (ADR-0016 Accepted 2026-07-13)
- TR-inv-001/002/003 ✅ — covered by ADR-0016.
- TR-inv-004 ❌ (new Pass 4) — `item_pickup_rejected` signal is shipped but missing from `event-bus.md`'s catalogue. Documentation-only gap, low risk.
- TR-inv-005 ❌ (new Pass 4) — Tower System doesn't yet call `item_added` with `metadata.damaged` on tower destruction. Cross-system wiring gap flagged non-blocking by the Inventory GDD's own author.

### Presentation Layer (ADR-0011 Accepted 2026-07-13)
- UI dual-focus handling — resolved. `InputModeTracker` (scene-instanced, not Autoload) is the reusable pattern for any future Presentation GDD (Sanctuary UI, Tarot Deck UI) needing gamepad-navigable, dual-focus-aware widgets. ADR-0010's original "Hero stat display" framing for this ADR was corrected — Hero's HUD elements are non-interactive and need no focus handling; the concrete driver was Inventory's Story 007.

### Core Economy (Inventory + Resource Economy) — updated 2026-07-13
- Inventory: TR-inv-001/002/003 ✅ — ADR-0016 Accepted 2026-07-13 after fixing the `restore_order` collision with `save-persistence.md` (Conflict 1: was 20, now 10, matching the GDD's own Formula 4 table).
- Resource Economy: TR-econ-001/002/003 ✅ — ADR-0017 Accepted 2026-07-13 after correcting its Wave Manager precedent citation (Conflict 2, did not change the underlying scene-instanced decision). TR-econ-003 (gold-balance ownership) is now fully Covered too: **ADR-0018 (Mission Economy — Runtime Gold Balance Ownership, Accepted 2026-07-13)** adds a new Autoload, `MissionEconomy` (boot position 8), resolving the previously-open question.
- ADR-0016, ADR-0017, ADR-0018, and ADR-0011 are all now Accepted. This retroactively legitimizes the 13 Epic 03 stories that were already `Status: Ready` against 0016/0017 while still Proposed (the process-gate violation flagged as Finding 4 in `architecture-review-2026-07-13.md`), and additionally unblocks Story 013 (gold balance, via ADR-0018) and Story 007 (UI dual-focus, via ADR-0011). **All 15 of Epic 03's stories are now `Status: Ready`.**

## Superseded Requirements

None — TR registry is at v5 with all 65 entries `active`.

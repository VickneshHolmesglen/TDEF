# Tech Debt Register

Tracks known technical debt, test coverage gaps, and deferred architectural work.
Items are resolved by creating a follow-up story and linking it here.

---

## TD-craft-002 — `recipe_tier4_component` was ungated, bypassing the entire production tech tree (fixed)

**Logged**: 2026-08-23 (found and fixed same session)
**Fixed**: 2026-08-23 (same session)
**Severity**: Medium — an economy/progression bug, not a crash: the top-tier (T4) tower-component recipe was fully craftable from the very start of a save file with zero tech investment, while `tech_production_4` (a real, purchasable, 150-gold + 45/24/12-material tech node) gated nothing at all and was a complete dead end.
**Area**: `assets/data/recipes/recipe_tier4_component.tres` (content only — `src/core/crafting/crafting.gd`'s gating logic itself was already correct: `tech_prerequisite == "" or GDefenseBuilding.is_tech_unlocked(...)`, so an empty `tech_prerequisite` is *intentionally* valid schema for "ungated," this was purely a wrong value on one recipe, not a code defect)

### Gap

Found by cross-referencing every recipe's `quality_tier` against its `tech_prerequisite`: quality_tier 2 recipes uniformly gate on `tech_production_2`, quality_tier 3 recipes uniformly gate on `tech_production_3` — a clean, consistent 1:1 pattern across 6 recipes. The one quality_tier=4 recipe (`recipe_tier4_component`, output `tier4_power_component`) had `tech_prerequisite = &""` instead of the expected `tech_production_4`, breaking the pattern. Confirmed as a real bug, not an intentional exception, by reading `tech_production_4.tres`'s own `gates` field (content-authoring documentation only, never read at runtime): `"Crafting quality_tier=4"` — the tech node's own author-facing description explicitly claims to gate this exact recipe.

### Resolution
- [x] Fixed 2026-08-23 — set `tech_prerequisite = &"tech_production_4"` on `recipe_tier4_component.tres`, closing the pattern and giving `tech_production_4` a real purpose.
- [ ] Not re-verified via the test suite this session, per the standing "no unrequested testing" instruction. Worth a save-compatibility check if any existing save already discovered this recipe pre-fix — `is_discovered()` records are one-way/permanent per Crafting's own discovery-ledger convention (mirrors Tarot's rune ledger), so a save that discovered it under the old ungated rule would keep it discovered even after this fix (not retroactively re-gated) — this is the existing, established discovery-ledger behavior working as designed, not a new gap this fix introduces.

---

## TD-craft-003 — 13 of 23 Equipment Forge recipes were ungated, bypassing the tech tree far more broadly than `TD-craft-002` (fixed)

**Logged**: 2026-08-23 (found and fixed same session, immediately after `TD-craft-002`)
**Fixed**: 2026-08-23 (same session)
**Severity**: Medium-High — same bug shape as `TD-craft-002` but 13x the scope: over half the entire Equipment Forge recipe catalogue (every quality_tier 3/4 recipe, plus one quality_tier 2 outlier) was fully craftable with zero tech investment.
**Area**: `assets/data/equipment_recipes/*.tres` (content only — `equipment_forge.gd`'s gating logic mirrors `crafting.gd`'s and was already correct)

### Gap

Ran the same `quality_tier` vs `tech_prerequisite` cross-reference that found `TD-craft-002`, this time against Equipment Forge's 23 recipes. `equipment-forge.md` Rule 5 explicitly states `quality_tier` "reuses Crafting's own authoritative definition" — the GDD's own Dependencies table even warns this must stay in lockstep with Crafting's tier convention "or Equipment Forge's recipes silently diverge." Found exactly that divergence: only 2 recipes (`recipe_iron_greaves`, `recipe_reinforced_plate` — both quality_tier=2) were gated on `tech_production_2`, matching Crafting's pattern. The other 21 were all `tech_prerequisite=""`, including all 6 quality_tier=4 recipes, all 6 quality_tier=3 recipes, and one stray quality_tier=2 recipe (`recipe_steel_greatsword`) that should have matched its 2 quality_tier=2 siblings but didn't.

### Resolution
- [x] Fixed 2026-08-23 — set `tech_prerequisite` on all 13 affected recipes to match Crafting's exact tier convention: quality_tier=3 → `tech_production_3` (6 recipes: `brute_gauntlets`, `goblin_signet`, `lurker_fang_blade`, `sentinel_visor`, `troll_hide_mantle`, `warlords_greaves`), quality_tier=4 → `tech_production_4` (6 recipes: `bogpearl_amulet`, `brutes_bulwark_plate`, `goblin_fang_circlet`, `sentinels_aegis`, `trollmarrow_band`, `warlords_greatblade`), quality_tier=2 → `tech_production_2` (1 recipe: `steel_greatsword`). Quality_tier=1 recipes (10 of them) left ungated — matches Crafting's own T1 convention exactly (every T1 `tower_component`/`crafted_good` recipe is also ungated by design).
- [ ] Not re-verified via the test suite this session, per the standing "no unrequested testing" instruction. Same save-compatibility note as `TD-craft-002`: any existing save that already discovered one of these 13 recipes under the old ungated rule keeps it discovered (one-way ledger, by design, not a new gap).

---

## TD-hero-skill-001 — `elem_firestorm` skill looks orphaned/unwired, not investigated further (fixed)

**Logged**: 2026-08-23
**Severity**: Low — cosmetic/content-authoring ambiguity, not a functional defect (an empty `source_build_signature` is explicitly valid per the schema, "unreachable via mastery" is a real allowed state, not necessarily a bug).
**Area**: `assets/data/skills/definitions/elem_firestorm.tres`

### Gap

Found while closing out the last 2 towers with no mastery-linked skill (Firebolt Turret, Venom Dart Turret — this session). `elem_firestorm.tres` exists with `display_name="Firestorm"`, `category="elemental"`, `passive_slot_count=3` (the maximum), and `source_build_signature=&""` (empty — not reachable via Tower Mastery). The name strongly suggests it was authored for Firebolt Turret (a fire-elemental tower) but never had its `source_build_signature` filled in — possibly an oversight, possibly deliberate (unlocked some other way not investigated here). Did not touch it: editing an existing skill's mastery-reachability is a mechanics/balance change, not additive content, and is out of scope for this session's "add new content" pattern — flagging for a real decision instead. Added `elem_venom.tres` (Venom Dart Turret) as a clean, unambiguous new skill instead, closing that tower's real gap without touching this one.

### Recommended fix

Read `hero-skill-build.md`/`tower-mastery.md` for whether `elem_firestorm` was ever intentionally scoped as mastery-unreachable (e.g. unlocked via a quest, tech node, or other path). If it was simply never finished, set `source_build_signature = &"found_firebolt_t1|weap_firebolt_t1|focus_firebolt_t1|power_firebolt_burn_t1"` to match Firebolt Turret, mirroring every other elemental skill's pattern.

### Resolution
- [x] Fixed 2026-08-23 — superseded by events, not by the originally-recommended fix. `found_firebolt_t1|...` was no longer available to reuse: this session later gave Firebolt Turret its own dedicated skill (`elem_firebolt.tres`, closing the tower-to-skill coverage gap directly). Instead, `elem_firestorm` (name, `passive_slot_count=3` maximum) turned out to match a *different* real gap found in the same audit pass: the Elemental archetype had T1×3/T2/T3 towers but no T4. Added `blueprint_firestorm_spire.tres` (T4 Elemental, `element="fire"`, large `aoe_radius_cells=3` matching the "storm" scale the name implies) and linked `elem_firestorm`'s `source_build_signature` to it — same resolution shape as the fix, different actual tower.

---

## TD-tower-007 — `AURA` weapons are never processed at all — Rally Banner (the only Support tower) deals zero DPS and applies zero buff (fixed)

**Logged**: 2026-08-23
**Severity**: High — an entire archetype's sole existing tower is completely non-functional in combat, not just under-tuned. This is more severe than a balance issue: Support archetype currently provides zero player value.
**Area**: `src/core/tower/tower_system.gd` (`_try_attack()`/`_tick_combat()` — no code path for `projectile_type == "AURA"` exists anywhere; `AURA` weapons never fire, never pulse, never emit `tower_aura_pulse`)
**Fixed (partial)**: 2026-08-23 — see Resolution below; the buff-application half of this gap is now split out as `TD-tower-008`.

### Gap

**Found while starting to author a Tier 3 Support tower** (this session, immediately after `TD-tower-006`) — before authoring content for an archetype, checked whether it actually works. It doesn't: `grep`ing `tower_system.gd` for `"AURA"`/`"aura"` returns zero matches. `blueprint_rally_banner.tres` (the project's only Support-archetype, only AURA-`projectile_type` tower) has `aura_effect_type="damage_buff"`, `aura_effect_value=0.15`, `aura_radius_cells=3` fully authored — none of it is ever read. `event_bus.gd` and `tower_aura_pulse_event.gd` exist (the payload schema is defined), but nothing in `TowerSystem` ever constructs or emits one. Support towers are placeable, cost gold, occupy a grid cell, and do nothing.

Stopped here rather than continuing to author more content for a non-functional archetype (would compound the "authored but inert" problem `TD-tower-006` already names) or unilaterally implementing an aura-pulse system with no way to verify it under the current no-testing constraint — same reasoning the user already applied to `TD-tower-006`.

### Recommended fix

Add aura-pulse handling to `TowerSystem` — likely a periodic tick (matching `_tick_combat`'s existing per-frame timer pattern) for any placed tower with `weapon.projectile_type == "AURA"`, applying `aura_effect_value` to all allied towers within `aura_radius_cells` (Chebyshev, matching this project's established convention) and emitting `tower_aura_pulse` per `event_bus.gd`'s existing payload schema. `aura_effect_type` needs a real consumer too — likely Tower System itself for `"damage_buff"` (a temporary damage multiplier on affected towers), unless a dedicated buff-tracking system is the intended owner (not confirmed — GDD cross-check needed before implementing).

### Resolution
- [x] Fixed 2026-08-23 — `_try_attack()` now branches on `state.weapon.projectile_type == "AURA"` before any targeting/damage logic runs: per tower.md's "Support archetype state exceptions" table (Rule 5a) and the two BLOCKING ACs at lines 1036/1068, it unconditionally emits `tower_aura_pulse` (no monster target found or required) carrying `tower_id`/`aura_effect_type`/`aura_effect_value`/`aura_radius_cells` straight from the weapon component, then returns — never falls through to `_find_target()`/`tower_attacked`. This closes the emission-side half of the bug: Rally Banner's aura pulse now fires every attack cycle (confirmed by re-reading `mission_scene.gd`'s existing `_on_tower_aura_pulse` VFX subscriber, which was already correctly wired and waiting for an emission that never came).
- [ ] **Not fixed — split out as `TD-tower-008`**: `tower_aura_pulse`'s own doc comment names "Damage & Status (apply effect to entities in radius)" as a key subscriber, but `damage_status.gd` has no such handler and no mechanism exists anywhere (`TowerMissionState` has no buff/debuff fields) for an aura pulse to actually modify an allied tower's combat stats. The pulse now fires and is visually confirmed, but `aura_effect_type`/`aura_effect_value` are inert past the VFX layer — Rally Banner is visible and "active" but still grants no real mechanical buff. Not fixed here: this needs a buff-state design decision (duration-based? re-applied every pulse? stacking rules?) beyond this fix's scope of "make the documented emission happen."

---

## TD-tower-008 — `tower_aura_pulse` fires (per `TD-tower-007`'s fix) but nothing consumes it to apply a real buff to allied towers (fixed)

**Logged**: 2026-08-23 (split out of `TD-tower-007` during that entry's fix — see its Resolution section)
**Severity**: Medium — Support archetype is no longer *invisible* (VFX pulse now fires, `tower_wave_summary.aura_applications_this_wave` would count real pulses once that summary system itself is wired), but it still provides zero actual combat value. Downgraded from `TD-tower-007`'s own High because the more severe "completely inert, not even visible" half of the original bug is now fixed.
**Area**: `src/core/damage_status/damage_status.gd` (no `tower_aura_pulse` subscriber exists), `src/core/tower/tower_mission_state.gd` (no buff/debuff state fields to receive an aura effect)
**Fixed**: 2026-08-23 — see Resolution below. Applied inside `TowerSystem` instead of `damage_status.gd` (deliberate deviation from this entry's own recommended fix — see Resolution for why).

### Gap

`weapon_component.gd`'s `aura_effect_type`/`aura_effect_value` are free-form strings/floats with no defined effect vocabulary anywhere in code (tower.md itself says "D&S System owns the valid range per effect_id" — i.e. by design, D&S is meant to interpret them, not Tower System). Building this requires a genuine design decision this session did not make: does an aura buff re-apply fresh on every pulse (simplest — no duration tracking needed) or use a duration+stacking model matching `damage_status.gd`'s existing burn/poison/slow DoT pattern? Does it modify `weapon_damage`, `attack_speed`, or something else on the buffed tower's `TowerMissionState`? None of this is specified in tower.md beyond the field's own one-line doc comment.

### Recommended fix

Design the aura effect vocabulary and application model first (likely a `/quick-design` or GDD amendment to tower.md, not a silent code decision), then add a `tower_aura_pulse` subscriber to `damage_status.gd` that looks up allied towers within `aura_radius_cells` (via a new TowerSystem query method, mirroring `_candidates_in_range()`'s pattern) and applies the resolved effect.

### Resolution
- [x] Fixed 2026-08-23. Made 2 deliberate design calls not specified anywhere in tower.md (documented in the code, not silently decided): **(1) Ownership** — applied inside `TowerSystem` itself, NOT `damage_status.gd` as the GDD's own `tower_aura_pulse` doc comment names. Reason: buff application mutates `TowerMissionState` (grid position, combat stats), which is `TowerSystem`-private state — `damage_status.gd` has no read/write access to it and would need a new cross-system query surface to get any, whereas `TowerSystem` already owns both the aura tower's position and every candidate ally's position (same data `_apply_splash_damage()` already uses for its own tower-to-monster distance check). D&S stays scoped to what it already does everywhere else: converting attack events into monster-facing damage/status, never touching tower-internal state directly. **(2) Effect model** — re-applied fresh (not stacked) on every pulse, decaying via a flat `AURA_BUFF_DURATION = 2.0`s timer (`TowerMissionState.damage_buff_fraction`/`damage_buff_remaining`, decayed in `_tick_combat()`) rather than a permanent "reapply forever" flag — a buffed tower that later walks out of every Support tower's radius needs *something* to eventually clear its bonus, and there's no terminal event for "this tower left an aura's range" to hook instead. Only `aura_effect_type == "damage_buff"` (the one effect id any shipped content — Rally Banner — actually authors) is implemented; any other value is a documented no-op, matching this project's established "unrecognized content-driven string = inert" convention. `_try_attack()`'s damage formula gained one more independent multiplier: `damage = base_damage × crit_mult × vs_tag_mult × boss_mult × (1.0 + damage_buff_fraction)`.
- [ ] Not yet re-verified via the test suite — no test run this session, per the standing "no unrequested testing" instruction.

---

## TD-tower-006 — `targeting_mode` is fully specified but never consumed — every tower always targets lowest-HP (fixed)

**Logged**: 2026-08-23
**Severity**: Medium — a real, silent gameplay bug, not just an unbuilt feature. 3 of 6 (now 8) shipped tower blueprints author a `targeting_mode` other than the one mode that actually works, so their authored identity doesn't match their real behavior: `blueprint_longshot_sniper.tres` says `HIGHEST_HP` (a sniper meant to snipe the toughest target) but behaves identically to every other tower (lowest-HP); `blueprint_archer.tres`/`blueprint_rally_banner.tres` say `CLOSEST_TO_GOAL` with the same silent mismatch.
**Area**: `src/core/tower/tower_system.gd` (`_try_attack()` calls the hardcoded `_find_lowest_hp_target()`, never reads `state.focus.targeting_mode`), `src/core/tower/focus_component.gd` (schema field, correctly documented as unused-by-code nowhere)

### Gap

`design/gdd/tower.md` fully specifies 5 targeting modes (`CLOSEST_TO_GOAL`/`SPAWN_ORDER`/`LOWEST_HP`/`HIGHEST_HP`/`SCATTER`, Rule 15) with a universal tiebreaker chain, a stateful deterministic SCATTER round-robin cycle (with a documented repeat-guard bug already found and fixed once in the spec itself), a `TowerSystem._get_best_target(tower_id, targeting_mode)` method HOMING projectiles are supposed to call on re-acquisition, and at least 8 BLOCKING acceptance criteria covering all of this. None of it is implemented — `tower_system.gd` has exactly one target-selection function, `_find_lowest_hp_target()`, called unconditionally regardless of what any tower's Focus component actually says.

**Found while authoring a new Tier 4 tower** (`blueprint_siege_cannon.tres`, this session) — its intended "targets the boss/toughest enemy" identity would have required `HIGHEST_HP`, which surfaced this gap. Shipped as `LOWEST_HP` instead (accurately reflecting current behavior) rather than authoring inert/misleading data.

**User decision (2026-08-23)**: presented as a real found bug with 3 remediation options (full 5-mode fix, 4-mode fix skipping SCATTER, or defer). User chose to defer — flag it, don't touch core targeting logic this pass. This entry is that flag.

### Recommended fix

Implement a `_find_target(state: TowerMissionState) -> int` dispatcher in `tower_system.gd` replacing `_find_lowest_hp_target()`, branching on `state.focus.targeting_mode` per Rule 15's exact specification (candidate filter unchanged — Formula 2 range/cone check — then mode-specific sort, then the universal tiebreaker chain: highest `path_step_index` → lowest `current_hp` → lowest `entity_id`). SCATTER needs 2 new per-`TowerMissionState` fields (`_scatter_index: int`, `_last_scatter_target_id: int`) reset on `wave_started`, plus the repeat-guard logic already fully specified in Rule 15. `TowerSystem._get_best_target(tower_id, targeting_mode)` must also be added and wired into HOMING re-acquisition (currently re-acquisition logic — see Rule 19 area — likely has its own gap here too, not independently audited this pass). Existing blueprints' authored `targeting_mode` values (`archer`=CLOSEST_TO_GOAL, `longshot_sniper`=HIGHEST_HP, `rally_banner`=CLOSEST_TO_GOAL) can stay as-authored once this lands — they were already correct, just inert.

### Resolution
- [x] Fixed 2026-08-23 (user reversed the earlier defer decision: "lets deal wit hthe combat log bugs"). Added a `_find_target(state) -> int` dispatcher plus 4 new mode-specific helpers (`_find_highest_hp_target`, `_find_closest_to_goal_target`, `_find_spawn_order_target`, `_find_scatter_target`) implementing all 5 documented `targeting_mode` values per Rule 15, including its universal tiebreaker chain and SCATTER's stateful round-robin (`scatter_index`/`last_scatter_target_id`, new fields on `TowerMissionState`, reset on `wave_started`). `_try_attack()` now calls `_find_target()` instead of the hardcoded `_find_lowest_hp_target()` (which itself remains, unchanged in signature, since `tower_combat_test.gd` calls it directly). Also added `TowerSystem._get_best_target(tower_id, targeting_mode)` as the system-level dispatch surface Rule 19 names for future HOMING re-acquisition (not itself implemented — that's `TD-tower-005`, unchanged, still open). `path_step_index` is now tracked live in `_monster_cache` (previously discarded in `_on_monster_cell_entered`) and cleared on `monster_breached` (new EventBus subscription — closes a named Edge Case where a breached monster could otherwise remain a stale, unreachable-but-cached target for CLOSEST_TO_GOAL/SPAWN_ORDER).
- [ ] Not yet re-verified via the test suite — `tower_combat_test.gd` was not run this session per the standing "no unrequested testing" instruction. `blueprint_siege_cannon.tres`'s `targeting_mode` (authored as `LOWEST_HP` to "match reality" per the original defer decision) is now stale relative to its own thematic intent (`HIGHEST_HP`) and was NOT re-touched here — that would be new content-authoring scope, not this bug fix.

---

## TD-save-003 — `test_mission_launched_signal_wired_after_ready_triggers_checkpoint` deleted its own checkpoint mid-test (fixed)

**Logged**: 2026-08-23 (Sprint 8, S8-02 — carried forward from Sprint 7's own smoke check/QA cycle, where it was flagged but not yet root-caused)
**Fixed**: 2026-08-23 (same session)
**Severity**: Low — test-only defect, no production code was ever wrong; confirmed via full 2256-test regression before and after
**Area**: `tests/unit/save_persistence/save_persistence_restore_test.gd:178` (test only — `src/foundation/save_persistence/save_persistence.gd` and `src/core/scene_manager.gd` both confirmed correct as-is)

### Gap

`test_mission_launched_signal_wired_after_ready_triggers_checkpoint` asserted a checkpoint file exists after emitting `GEventBus.mission_launched`, but the assertion ran after an extra `await get_tree().process_frame` following the emit. Root-caused via direct Godot MCP tracing (`run_script`, not guessing): the checkpoint **is** written synchronously and correctly by `SavePersistence._on_mission_launched()` as part of the `.emit()` call — confirmed present immediately after emit. The real `WaveManager` Autoload is also live in the test's tree and reacts to the same signal; since the test's `"forest_01"` mission id has no real `WaveConfig` content in this suite's environment, `WaveManager` fails its load, hits 0 spawn cells, and short-circuits straight to `MISSION_COMPLETE` (`wave_manager.gd:815`). `SceneManager._on_mission_phase_changed()` turns that into `transition_to_sanctuary()`, which emits `scene_transition_completed("SANCTUARY", "")` within 1-2 frames. The test's own `sp` instance is independently subscribed to that same signal and correctly deletes its own just-written checkpoint in response (`SavePersistence`'s documented Rule 5 "normal flow" cleanup — this is correct, intended production behavior, not a bug). The extra post-emit `await` gave that real, unrelated cascade enough time to race the assertion and delete the very file the test exists to confirm.

### Resolution
- [x] Root cause confirmed via live Godot MCP `run_script` tracing (not assumed): checkpoint present immediately after `.emit()`, gone by frame 1 — isolated by removing the post-emit await and re-testing, confirming the file persists when asserted immediately.
- [x] Fixed 2026-08-23 — removed the unneeded post-emit `await get_tree().process_frame` from the test (signal `.emit()` already invokes connected handlers synchronously, so no await was ever needed for `_on_mission_launched()` to have run). Added a doc comment explaining the race for future readers. Made the test's own cleanup (`DirAccess.remove_absolute`) defensive against the file already being gone, matching the now-understood cascade.
- [x] Re-verified: `save_persistence_restore_test.gd` 14/14 passing in isolation, 0 errors, 0 orphans. Full project regression: 2256/2256, 0 failures.

---

## TD-menag-006 — `test_lure_creature_success_full_flow` fails in isolation (AC-2 placement state) (fixed)

**Logged**: 2026-07-18 (Sprint 6, S6-08 — found running the full suite for the first time this session, unrelated to any S6-08 change)
**Fixed**: 2026-07-25
**Severity**: Medium — a currently-Complete Epic 05 story's own AC test is failing, pre-existing (confirmed via isolated single-file re-run, not a cross-test leakage artifact)
**Area**: `src/core/menagerie/menagerie.gd` (`lure_creature()`'s placement rule), `tests/unit/menagerie/lure_acquisition_test.gd:77`

### Gap

`test_lure_creature_success_full_flow` asserts a freshly-lured creature's `state` equals `CreatureInstance.CreatureState.RESERVE` (AC-2's stated default placement) — fails with `Expecting: '0' but was '1'` (i.e., actual state is enum index 1, `HABITAT`, not `RESERVE`). Confirmed NOT a cross-test state leak: reproduces when running `tests/unit/menagerie/lure_acquisition_test.gd` alone. Likely cause (not yet investigated): `lure_creature()`'s HABITAT-vs-RESERVE placement decision (Story 008) may be defaulting to HABITAT under some condition this test's `before_test()` setup satisfies, contradicting AC-2's literal "no habitat capacity seeded -> RESERVE" expectation — or the story's placement logic itself regressed. Not investigated further this pass (out of scope for S6-08's Constellation work; found opportunistically while running a full-suite regression check after the `constellation_eligibility_tag` EventBus fix).

### Recommended fix

Read `menagerie.gd`'s `lure_creature()`/placement-decision logic and Story 008/009's stated Habitat-capacity rule; determine whether the code or the test's expectation is wrong, fix whichever is incorrect, and re-verify via gdUnit4.

### Resolution
- [x] Root cause identified (2026-07-25) — the **test's expectation was wrong, not the code**. `menagerie.md`'s own AC-4 (Core Rule 2) is explicit: "GIVEN HABITAT has at least one open slot at the moment Lure succeeds... it is placed directly into HABITAT (not RESERVE)." `menagerie.gd`'s `lure_creature()` (line 143-144) correctly implements this: `if _habitat_count() < _habitat_capacity: move_to_habitat(...)`. This test's fresh `Menagerie.new()` + default `habitat_base_capacity = 4` means the very first lure in the test always has an open HABITAT slot, so `state == HABITAT` is the GDD-correct outcome, not a regression.
- [x] Fixed (2026-07-25) — corrected `tests/unit/menagerie/lure_acquisition_test.gd:77`'s assertion from `CreatureState.RESERVE` to `CreatureState.HABITAT`, updated the test's own comment to reference AC-4. Re-verified via gdUnit4: 6/6 passing, 0 errors, 0 failures, 0 orphans.
- [x] This entry closed

---

## TD-test-004 — Full-suite orphan-node count grew sharply after Sanctuary UI screen work (158 → 2258, fixed down to 185 via a workaround for the `mission_launched` cross-Autoload interaction) (substantially resolved — residual explained by TD-test-006)

**Logged**: 2026-07-25 (autonomous overnight session — Menagerie/Defense Building screens + `SanctuaryScene.tscn` real-shell wiring)
**Fixed**: 2026-07-25 (87% reduction); residual fully explained 2026-08-01 (see below)
**Severity**: Medium — no test failures/errors caused (1610/1610 test cases still pass, 0 errors, only the pre-existing unrelated `TD-menag-006` failure), but a real, measured regression in test-run cleanliness
**Area**: `src/scenes/SanctuaryScene.tscn` (now instances the full `SanctuaryUI.tscn` shell instead of a placeholder `Label`), `src/gameplay/ui/menagerie_screen/menagerie_screen.gd`, `src/gameplay/ui/defense_building_screen/defense_building_screen.gd` (both dynamically rebuild their Button/Panel lists via `queue_free()` + re-instantiate, potentially multiple times per test with no intervening frame)

### Gap

A full project regression's `Overall Summary` orphan count climbed in direct correlation with this session's changes: ~158 (baseline, pre-session) → 1043 (after Menagerie screen + wiring it into `ROOM_SCENES`) → 1248 (after Defense Building screen + `SanctuaryScene.tscn`'s real-shell wiring). Isolated re-runs of every suite touched this session (`scene_manager_transition_test.gd`, `pause_menu`, `sanctuary-ui`, `menagerie-screen`, `defense-building-screen`) all report **0 orphans** individually — this only manifests at full-168-suite-run scale, suggesting either (a) a cross-suite accumulation effect where `queue_free()`'d nodes from these dynamic-rebuild screens never get an intervening idle frame before the whole process later exits, with the leak only surfacing in the final process-wide `ObjectDB` check rather than attributed to the specific suite that caused it, or (b) something in the now-much-heavier `SanctuaryScene.tscn` (full shell vs. a single `Label`) that any OTHER pre-existing test exercising a real `SceneManager.transition_to_sanctuary()` call now multiplies. Not root-caused this session — flagged honestly rather than either ignored or a rushed guess-fix applied.

### Recommended fix

Bisect by running the full suite with `SanctuaryScene.tscn` reverted to its placeholder `Label` (isolate whether the scene-weight theory is correct) versus reverted only in the 2 new screens' `_rebuild_*()` methods changed to free-and-immediately-`add_child()` without a `queue_free()` deferral gap (isolate whether the dynamic-rebuild theory is correct). Whichever isolates the count back toward baseline identifies the real mechanism; fix by adding an explicit `await get_tree().process_frame` at each dynamic-rebuild call site if it's mechanism (a), or by investigating what in the full `SanctuaryUI` tree isn't cleanly torn down if it's mechanism (b).

### Resolution
- [x] Root cause identified (2026-07-25) — **neither original theory (a)/(b)**. Bisected by running progressively smaller subsets: `tests/integration/sanctuary-ui/` alone reproduced the full 955-orphan signature at just 86 tests (12 suites), and running each of its 12 suite files individually isolated it to exactly 2 files: `exit-mission-select_test.gd` (679 orphans / 8 tests) and `tab-strip-navigation_test.gd` (178 orphans / 17 tests). Both files call real `SanctuaryUI` methods (`confirm_launch_depart()`, tab-6/Loadout navigation) that trigger genuine `GSceneManager.transition_to_mission("")` / `transition_to_tarot_deck_ui()` calls — but **neither test file used `SceneManager`'s own established `_inject()` stub-scene test seam** (the pattern `loadout-handoff_test.gd` already correctly uses). Before this session, those transition targets (`MissionScene.tscn`, `TarotDeckUIScene.tscn`) either didn't exist or weren't wired yet, so the calls were inert — each transition-target scene becoming real and heavy over the course of this session (Tarot Deck UI hand-off, then Mission Select) is what turned these 2 already-existing, previously-harmless tests into the dominant orphan source, since the real node-heavy scene tree they now load on every relevant test was never torn down afterward (`scene_runner()`'s auto-free only manages its own instantiated `SanctuaryUI`, not whatever `SceneManager.change_scene_to_packed()` separately swapped `current_scene` to).
- [x] Fixed, partially (2026-07-25) — added the identical `_inject(STUB_SCENE_PATH, STUB_SCENE_PATH, STUB_SCENE_PATH)` / restore-in-`after_test()` seam to both files, matching `loadout-handoff_test.gd`'s exact pattern. Verified in isolation: `exit-mission-select_test.gd` 679→11 orphans (8/8 still passing), `tab-strip-navigation_test.gd` 178→9 orphans (17/17 still passing), full `sanctuary-ui` directory 955→48 orphans (86/86 still passing) — a ~95% reduction within that directory. **However, the full 173-suite/1662-test regression only dropped from 2258→1343 orphans** (0 errors, 0 failures both before and after — this was never a correctness issue) — a real, meaningful ~40% reduction confirming these 2 files were a genuine major contributor, but **not the only one**.
- **Second bisection pass (2026-07-25, continued)**: subdivided the remaining ~1343 by top-level test directory: `tests/unit/` alone = 1062, `tests/integration/` alone = 281 (sums exactly, no cross-contamination). Within `tests/unit/`, narrowed via repeated bisection (constellation/crafting/.../inventory = 47; menagerie/mission-select/.../resource_economy = 10; save_persistence/scene_manager/tarot = 0; **tower/tower-mastery/wave_manager = 1005**, almost entirely in `tests/unit/tower/` = 996) down to 2 files: `tower_combat_test.gd` (540 orphans/19 tests) and `tower_placement_test.gd` (456 orphans/16 tests) — both average ~28 orphans/test.
  - **Root cause narrowed further, NOT fully identified.** Confirmed via a minimal scratch reproduction (`GEventBus.mission_launched.emit()` called twice per test, in `before_test()`/`after_test()`, across 5 `gdUnit4` test-case boundaries in one file) that `TowerSystem` itself is **not involved at all** — the identical ~28-orphans-per-test signature reproduces with zero `TowerSystem` instances, zero `EventBusSpy` usage, zero combat ticking. The leak is purely a property of repeatedly emitting `mission_launched` across multiple test-case boundaries within one gdUnit4 suite run (0 orphans when the same emissions happen inside a single test body, or across a single create/free cycle — it specifically requires the **gdUnit4 before_test/after_test test-boundary repetition**).
  - Bisected which of `mission_launched`'s 5 real Autoload subscribers (`GSavePersistence`, `GWaveManager`, `GMissionEconomy`, `GMenagerie`, `GHeroSkillBuild`) is responsible by disconnecting all and reconnecting subsets: **all 5 disconnected → 0 orphans** (confirms these Autoloads, not gdUnit4 itself, are the mechanism). But — surprisingly — **either half reconnected alone also shows 0 orphans** (`{GMenagerie, GHeroSkillBuild}` alone = 0; `{GSavePersistence, GWaveManager, GMissionEconomy}` alone = 0). The leak only manifests with some combination requiring subscribers from *both* halves simultaneously (or is order-of-connection-dependent — my bisection's `disconnect()`/`connect()` cycling does not preserve the original Autoload boot-order connection sequence, which could itself be the actual variable). This rules out a single-subscriber root cause; it's an interaction effect.
  - **Deliberately stopped here** rather than continuing an unbounded pairwise/combinatorial search — the value-per-effort of continuing dropped sharply once "single culprit" was ruled out, and this is a test-hygiene issue with zero correctness impact (0 errors/0 failures throughout every measurement in both bisection passes). The specific reproduction recipe above (disconnect all 5, reconnect combinations, emit `mission_launched` across `gdUnit4` test-case boundaries) is a complete, ready-to-resume starting point for whoever picks this back up — no need to re-derive it.
- **Third bisection pass (2026-07-25, continued)**: found a 3rd confirmed contributor using the same subdivide-and-isolate methodology, this time in `tests/integration/`. `tests/integration/` alone = 281 orphans (matches the `1062 unit + 281 integration = 1343` total exactly, confirming no cross-contamination between the two top-level directories). Bisected `tests/integration/` down to `tests/integration/core/mission_economy_test.gd` (8 tests, 232 orphans — nearly the entire 281). This file matches the identical signature already found in `tower_combat_test.gd`/`tower_placement_test.gd`: it emits `GEventBus.mission_launched` directly (not via a real `SceneManager` transition) in `before_test()`/`after_test()` across 8 gdUnit4 test-case boundaries, with no `TowerSystem`/scene involvement at all — confirming this is a general "repeated direct `mission_launched` emission across gdUnit4 test-case boundaries" mechanism, not specific to any one test file's own subject matter. Likely several more files across the suite share this exact pattern (any test emitting `mission_launched` directly to reset an Autoload's state, per this file's own header comment citing that convention as established practice elsewhere) — not enumerated exhaustively this pass. Not fixed (same combinatorial-interaction wall as the tower files) — logged as the 3rd confirmed data point for whoever resumes the root-cause search, which now has 3 independent reproduction sites instead of 1.
- **New contributor added passively, 2026-07-25 (Sanctuary UI Story 013)**: building the real Diorama (`tests/integration/sanctuary-ui/diorama_test.gd`, 8 new tests emitting `sanctuary_structure_built`/`creature_acquired`/`creature_happiness_changed` across gdUnit4 test-case boundaries) raised the full-suite total from 1343 → 1459 (+116), 0 errors/failures throughout. Consistent with the same general "EventBus emission across test boundaries" family already documented above, not investigated as a 4th distinct bisection target this pass — noted here so the running total stays accurate for whoever resumes the root-cause search.
- **Workaround applied, 2026-07-25 (continued autonomous session)** — rather than continuing the combinatorial root-cause search (explicitly deemed low value-per-effort above), tested and applied a practical fix to the 3 confirmed contributor files (`tests/integration/core/mission_economy_test.gd`, `tests/unit/tower/tower_combat_test.gd`, `tests/unit/tower/tower_placement_test.gd`): all 3 used `GEventBus.mission_launched.emit(...)` purely as `before_test()`/`after_test()` boilerplate to reset `GMissionEconomy`'s gold balance to a known baseline — none of them were actually testing the broadcast mechanism itself (the 2 tests in `mission_economy_test.gd` that DO test AC-11's broadcast behavior still use the real `GEventBus.mission_launched.emit()` inside their own test bodies, unchanged). Replacing the boilerplate reset calls with a direct call to `GMissionEconomy._on_mission_launched(...)` (the exact same reset logic, without cascading into WaveManager/SavePersistence/Menagerie/HeroSkillBuild/Tarot's own handlers) eliminated the orphans in isolation: `mission_economy_test.gd` 232→0 (8/8 still passing), `tower_combat_test.gd` + `tower_placement_test.gd` 996→0 combined (35/35 still passing). **Full 183-suite/1762-test regression: 1459 → 185 orphans (an 87% reduction), 0 errors/0 failures both before and after** — confirms `WaveManager._on_mission_launched()` (the only one of the 5 subscribers that creates/manages real Node-based state — phase timers, spawn scheduling — per its own handler at `wave_manager.gd:748`) as the dominant real mechanism, without needing to fully resolve the "combination/order-dependent" interaction effect noted in the second bisection pass above.
- **185 orphans remain**, scattered across the suite (not isolated to a single dominant contributor this pass) — genuinely closing this to 0 would need either (a) a similar audit for any other test files using `mission_launched` (or a similar broadcast-heavy signal) purely as reset boilerplate rather than as the thing under test, or (b) finally root-causing why `WaveManager`'s own reset path leaks a Node when repeated across gdUnit4 test-case boundaries (deferred — 87% reduction achieved, further chasing judged lower priority than other outstanding work).
- [x] Substantially resolved (2026-07-25) — 1459→185 orphans (87% reduction), 0 correctness impact throughout. Reopen only if the residual 185 or a future regression becomes worth a dedicated pass.
- [x] **Residual 185 fully explained (2026-08-01) — see `TD-test-006`.** This entry's own bisection had already found the key symptom without naming its cause: "0 orphans when the same emissions happen inside a single test body... requires the gdUnit4 before_test/after_test test-boundary repetition." `TD-test-006` root-caused this directly from gdUnit4's own source: its orphan snapshot fires immediately after the test body returns, *before* `after_test()` runs in a separate, later stage — so any correctly-freed-in-`after_test()` object gets miscounted, regardless of which Autoload or EventBus signal is involved. This fully accounts for the residual 185 without needing the "WaveManager Node leak" theory floated as the reopen condition below — the extensive `mission_launched`-subscriber combinatorial bisection above was a reasonable path to follow at the time, but the actual mechanism was in the test framework's snapshot timing, not in any of the 5 Autoload subscribers' own cleanup code. No further bisection needed.

---

## TD-craft-001 — RecipeResource.inputs vocabulary split: item_type (craftable) vs. rarity (content-accurate to Formula 1-3, not yet craftable) (fixed)

**Logged**: 2026-07-18
**Partially fixed**: 2026-07-18 (Story 002) — the item_type-keyed half
**Reopened/escalated**: 2026-07-18 (Story 006) — Formula 1-3 are explicitly rarity-based, reintroducing the same underlying gap this entry originally closed
**Fully fixed**: 2026-07-18 (Sprint 6, S6-06b) — see Resolution below
**Story**: Discovered during Story 002 (Recipe Discovery State Machine), escalated during Story 006 (Material Cost Formulas)
**Severity**: Medium — this is now confirmed to be the SAME underlying open design question as `TD-defbuild-002` (rarity vs. item_type vocabulary), manifesting in a second system
**Area**: `src/core/crafting/recipe_resource.gd`, `assets/data/recipes/*.tres`, `tests/unit/crafting/*_test.gd`

### Gap

ADR-0023's Key Interfaces comment describes `RecipeResource.inputs: Dictionary[StringName, int]` as `"material_id -> quantity"`. But `Inventory.has_items(cost: Dictionary) -> bool`'s actual, already-shipped contract (per `inventory.md` line 147) sums by **item_type** (`Equipment`/`TowerComponent`/`Material`/`CraftedGood`), not by item_id or rarity. A recipe authored with `inputs = {&"iron_ore": 5}` would call `has_items({&"iron_ore": 5})`, checking for 5 units of `item_type == "iron_ore"` — a value no `ItemDefinitionResource` ever has — always failing regardless of what the player owns.

**Escalation (Story 006)**: `crafting.md`'s Formula 1 (`recipe_tier4_component`) and Formula 3 (repair, Story 005) are explicitly rarity-based (`Common`/`Uncommon`/`Rare`) — the SAME vocabulary `defense-building.md`'s Formula 1 uses, and the SAME gap `TD-defbuild-002` already tracks for Defense Building. `RecipeResource.validate()` now accepts EITHER vocabulary (a real item_type, which is genuinely `has_items()`-compatible, OR a rarity string, which is content-accurate to the GDD's formulas but NOT `has_items()`-compatible) — by explicit user decision, to let Formula 1/2/3's exact numbers be authored and validated as data without inventing a premature resolution. Any recipe authored with rarity keys (`recipe_tier4_component`) is content-correct but **not genuinely craftable** — `resolve_craft()` would reject it via `has_items()` regardless of real inventory contents, the same class of silent-rejection risk `TD-defbuild-002` already describes for Defense Building.

### Fix (partial — item_type half only)

Story 002 fixed the item_type-keyed half: `RecipeResource.inputs` documented/validated to accept `item_type` keys, and Story 001's 2 initial recipes use `&"Material"` correctly. This half is genuinely `has_items()`-compatible and craftable today.

### Recommended fix (rarity half — not resolved)

Same recommendation as `TD-defbuild-002` — this is one design decision that should resolve BOTH systems' instances at once:
1. Add a `rarity` field to `ItemDefinitionResource` (or an equivalent lookup), so a rarity key can resolve to real `item_id`s, OR
2. Change both Crafting's and Defense Building's rarity-keyed cost fields to use `item_type` directly, OR
3. Route to game-designer or `/architecture-decision`.

### Resolution
- [x] item_type-keyed half: documented, validated, craftable (Story 002)
- [x] rarity-keyed half (2026-07-18, Sprint 6 S6-06b): added `ItemDefinitionResource.rarity` as a genuinely separate aggregation axis (option 1 of the recommended fixes below) plus `Inventory.has_items_by_rarity()`/`consume_by_rarity()`, mirroring `has_items()`/`consume_by_type()` exactly. `recipe_tier4_component`/`recipe_healing_salve_bulk` and Story 005's repair cost are now genuinely craftable. Crafting's `resolve_repair()` and a second, newly-discovered instance of the same bug in `is_craftable()`/`resolve_craft()`/both discovery triggers (new `_has_recipe_inputs()`/`_consume_recipe_inputs()` helpers splitting a mixed item_type/rarity cost Dictionary) were both fixed.
- [x] Resolved jointly with `TD-defbuild-002` — confirmed same underlying design question, same fix
- [x] ADR-0021 amended with the full decision record
- [x] Live-verified via gdUnit4: `tests/unit/inventory/has_items_by_rarity_test.gd` (7 tests), `tests/unit/crafting/mixed_vocabulary_recipe_inputs_test.gd` (4 tests) — all passing, plus full regression across `tests/unit/crafting`, `tests/integration/crafting`, `tests/unit/defense_building`, `tests/integration/defense_building`, `tests/unit/inventory`: 220/220 passing, 0 failures
- [x] This entry closed (2026-07-18)

---

## TD-defbuild-002 — Material consumption (ADR-0024 Rule 9 step d) not implemented — rarity-vs-item_type vocabulary mismatch (vocabulary half fixed)

**Logged**: 2026-07-18
**Escalated**: 2026-07-18 (Story 025) — from a latent future risk to an active test regression
**Vocabulary mismatch fixed**: 2026-07-18 (Sprint 6, S6-06b) — see Resolution below. Material consumption (step d) itself remains a separate, still-open design question — deliberately NOT resolved by this fix.
**Story**: Discovered during Story 022 (flagged), traced further during Story 023 (Resolution Ordering & Idempotency), confirmed active during Story 025 (Cost Formulas 1–3)
**Severity**: Medium — blocks a real gameplay effect (unlock/build actions never actually spend materials); now also actively breaks test correctness for 3 already-Complete stories, not just a future test-coverage gap
**Area**: `src/core/defense_building/defense_building.gd` (`resolve_tech_unlock()`/`resolve_structure_build()`), `src/core/inventory/inventory.gd`, `design/gdd/defense-building.md`, `design/gdd/inventory.md`, `tests/unit/defense_building/currency_dual_gate_test.gd`, `tests/unit/defense_building/resolution_ordering_test.gd`, `tests/integration/defense_building/persistence_through_defeat_test.gd`

### Gap

`TechNodeResource.material_costs`/`StructureResource.material_costs` are keyed by material **rarity** (`"Common"`/`"Uncommon"`/`"Rare"`, per `defense-building.md` Formula 1) — a distinct vocabulary from `ItemDefinitionResource.item_type`'s fixed 4-category system (`Equipment`/`TowerComponent`/`Material`/`CraftedGood`, per `inventory.md`). `Inventory.consume_stackable()` requires a specific `ItemDefinitionResource` to target a real stack; there is no mapping anywhere in this project from a rarity key to any specific `item_id`/`ItemDefinitionResource` (multiple materials could plausibly share a rarity — `common_scrap`/`iron_ore` are both currently authored as `item_type = "Material"` with no rarity field at all). `defense-building.md`'s own Open Questions table already flags this mismatch.

As a direct consequence, `resolve_tech_unlock()`/`resolve_structure_build()` (Story 022/023) implement 5 of ADR-0024 Rule 9's 6 sub-steps — eligibility, materials-check (`has_items()`, which itself only sums by `item_type` and is unaffected by this gap), gold debit, ledger write, and domain event emission — but never actually consume/deduct the materials a player spends. Gameplay-wise: unlocking a tech node or building a structure currently costs gold but is materials-free in practice.

**Escalation (Story 025)**: once real, non-zero `material_costs` values were authored, this stopped being latent. `has_items()` will now ALWAYS return `false` for every real tech node/structure's `material_costs`, since `totals_by_item_type` can never contain a `"Common"`/`"Uncommon"`/`"Rare"` key (no real `ItemDefinitionResource` has that as its `item_type`) — meaning `resolve_tech_unlock()`/`resolve_structure_build()` reject unconditionally for every real caller from this point forward, regardless of what the player actually owns. This broke every "successful resolve" test in `currency_dual_gate_test.gd`, `resolution_ordering_test.gd`, and `persistence_through_defeat_test.gd` (Stories 022/023/024, all already Complete). **Worked around, not fixed**, in all three test files: each now seeds the real `GInventory` Autoload with schema-invalid, rarity-typed test-local `ItemDefinitionResource` instances (`item_type` deliberately set to the rarity string itself) purely so those tests can keep exercising `resolve_*()`'s success path — clearly commented as a test-only workaround for this exact gap, not a resolution of it, and not a pattern used anywhere in production code.

### Recommended fix

This needs a design decision, not a unilateral coding fix, since it spans two systems' data models:
1. Add a `rarity` field to `ItemDefinitionResource` (or an equivalent lookup table) so a rarity key can resolve to one or more real `item_id`s, OR
2. Change `TechNodeResource`/`StructureResource`'s `material_costs` to be keyed by `item_type` (or a specific `item_id`) directly instead of rarity, reconciling with how `has_items()` already works, OR
3. Some other explicit reconciliation — route to game-designer or `/architecture-decision` to decide.

Once resolved: (a) add step (d) to `resolve_tech_unlock()`/`resolve_structure_build()` (a loop over `material_costs` calling `Inventory.consume_stackable()` per resolved entry), (b) un-defer AC-18 (Story 022) and AC-24's full 6-step coverage (Story 023) with real tests, and (c) remove the rarity-typed test-workaround seeding from all 3 affected test files, replacing it with real, schema-valid `ItemDefinitionResource` content that actually resolves against the (by-then-real) rarity vocabulary.

### Resolution
- [x] Rarity-vs-item_type vocabulary reconciled (2026-07-18, Sprint 6 S6-06b): added `ItemDefinitionResource.rarity` as a separate aggregation axis + `Inventory.has_items_by_rarity()`, resolved jointly with `TD-craft-001` (same underlying question). `resolve_tech_unlock()`/`resolve_structure_build()`'s materials-check now correctly resolves rarity-keyed `material_costs` against real inventory contents. ADR-0021 amended.
- [ ] Material consumption (step d) implemented in both `resolve_tech_unlock()` and `resolve_structure_build()` — **deliberately NOT part of this fix**; the vocabulary mismatch that made this unimplementable is resolved, but the consumption step itself is a separate, still-open design question (which material rarity/item_id gets debited, since a rarity can span multiple item_ids) — remains open, tracked here
- [ ] AC-18 (Story 022) and AC-24's full 6-step coverage (Story 023) un-deferred with real tests
- [x] Test-workaround seeding removed from `currency_dual_gate_test.gd`/`resolution_ordering_test.gd`/`persistence_through_defeat_test.gd` (2026-07-18) — replaced with real, genuinely registered `common_scrap`/`iron_ore` content (a second, independent bug was found in the same pass: the workaround's fabricated item_ids could never resolve through `GGameDataRegistry.get_item_definition()` in the first place, so these 3 tests' "successful resolve" paths could never actually have passed even with the vocabulary gap open — see ADR-0021's amendment for the full explanation). `edge_cases_shared_guard_test.gd` had the same bug and was fixed in the same pass, though it wasn't originally listed here.
- [x] **Step (d) implemented 2026-08-25** in both `resolve_tech_unlock()` and `resolve_structure_build()`: a loop over `material_costs` calling `Inventory.consume_by_rarity()` per entry, inserted between the gold debit and the ledger write (matching ADR-0024 Rule 9's documented step order exactly). No new design decision was actually needed — the "which item_id gets debited" question is `consume_by_rarity()`'s own already-shipped, already-documented answer ("any N items of this rarity," slot order), the same mechanism `attempt_expand_slots()` (`TD-inv-003`) and Crafting's `_consume_recipe_inputs()` already use; the original 3-option "needs a design decision" framing predates the rarity-vocabulary resolution above and is now moot. **Same fix also applied to `BuildingUpgrade.resolve_upgrade()`** (`src/core/building_upgrade/building_upgrade.gd`), which had explicitly mirrored this exact deferral, citing this same tech-debt entry, for the identical reason — closing it here closes both. New tests: `currency_dual_gate_test.gd` (2 consumption + 1 rejection-consumes-nothing), `building_upgrade_test.gd` (1 consumption test). Doc comments updated across `defense_building.gd`, `building_upgrade.gd`, `resolution_ordering_test.gd`, `edge_cases_shared_guard_test.gd`, `persistence_through_defeat_test.gd`, and `design/gdd/defense-building.md` (4 stale `has_items(material_costs)` references corrected to `has_items_by_rarity`, a pre-existing inaccuracy predating this fix). **Not live-verified against the pinned Godot binary this session** — code-only, per the standing instruction to skip running tests; existing tests in the 4 touched suites were checked by hand against the real authored `.tres` cost values (`tech_production_2`=15 Common, `habitat_expansion_tier_1`=20 Common, both well within each test's seeded pool) to confirm none silently under-afford now that consumption is real, not just assumed safe.
- [x] This entry closed (2026-08-25).

---

## TD-defbuild-001 — DefenseBuilding not yet registered as Autoload #10 per ADR-0024 (fixed)

**Logged**: 2026-07-18
**Fixed**: 2026-07-18 (Story 019)
**Story**: Discovered during Story 018 (TechNode/Structure Data Schema & Two Independent Ledgers) code review
**Severity**: Advisory — expected, tracked intermediate state, not a defect
**Area**: `src/core/defense_building/defense_building.gd`, `project.godot` `[autoload]`

### Gap

ADR-0024's Decision requires `DefenseBuilding` to be registered as Autoload #10 (after Inventory #9), so that `is_tech_unlocked()` is callable as a bare global from Crafting's boot-time discovery sweep (Criterion A, ADR-0020). Story 018 deliberately implemented only the two ledger fields (`_tech_ledger`, `_structure_ledger`) on a plain, unregistered `Node` — no Autoload entry was added to `project.godot`, since none of this session's 5 reclassified Feature-layer systems (Inventory, DefenseBuilding, Menagerie, MissionSelect, HeroSkillBuild) are wired in yet, and wiring DefenseBuilding in ahead of Inventory (which shipped scene-instanced in Epic 03 and still isn't Autoload-registered either) was judged out of order. This is explicitly guarded by `test_defense_building_is_not_registered_as_autoload()` in `tests/unit/defense_building/tech_structure_data_schema_test.gd`, so the gap cannot silently close by accident — it must be resolved deliberately.

### Recommended fix

Story 019 (the story that adds `is_tech_unlocked()`, the resolution sequence, and `SaveRestorer` persistence) must also add DefenseBuilding's `[autoload]` entry to `project.godot` at position #10, update `test_defense_building_is_not_registered_as_autoload()` (it will need to invert or be removed once registration is intended), and confirm Inventory's own still-open Autoload registration gap is resolved first or in the same pass, since DefenseBuilding's resolution sequence calls `Inventory.has_items()`/batch-consume directly (Criterion A).

### Resolution
- [x] Inventory Autoload registration gap resolved (2026-07-18, Story 019) — `GInventory` added to `project.godot` at position #9, per ADR-0016's 2026-07-17 amendment
- [x] `DefenseBuilding` added to `project.godot` `[autoload]` at position #10 (2026-07-18, Story 019)
- [x] `test_defense_building_is_not_registered_as_autoload()` renamed to `test_defense_building_is_registered_as_autoload()` and flipped to assert the Autoload entry exists (2026-07-18, Story 019)
- [x] Bonus find during the same story's code review: `src/gameplay/ui/inventory_screen/inventory_screen.gd`'s `_ready()` fallback (`inventory = Inventory.new()`) would have silently created a second, disconnected Inventory instance — now that `GInventory` is the canonical Autoload, that fallback path independently re-registered with `GSavePersistence` under the same `"inventory"` save key (no duplicate-key guard exists there), a real split-brain-inventory risk. Fixed in the same pass: defaults to `GInventory` instead.
- [x] This entry closed (2026-07-18) — verified by direct file inspection only; not yet confirmed via an executed test run (no headless Godot runner available this session).

---

## TD-econ-008 — TowerSystem's `resources_changed` payload violated the delta contract, corrupting MissionEconomy (fixed)

**Logged**: 2026-07-16
**Fixed**: 2026-07-16 (same session)
**Story**: Discovered during Story 013 (Gold Track & Scout Starting Grant) code review, by both the godot-gdscript-specialist and qa-tester reviews independently
**Severity**: High (fixed) — live, reachable gold-balance corruption bug, not hypothetical
**Area**: `src/core/tower/tower_system.gd` (Epic 02, shipped/Complete)

### Gap

`design/gdd/event-bus.md` (catalogued 2026-07-13) documents `resources_changed`'s `gold` field as a **signed delta**, explicitly naming Mission Economy as the accumulating subscriber. `TowerSystem` (shipped in Epic 02, before `MissionEconomy` existed) violated this contract: it self-tracked its own `_player_gold: int` field, treated every incoming `resources_changed` delta as an absolute overwrite (`_player_gold = gold`), and on tower placement/sale emitted its own resulting *absolute balance* as the payload (`resources_changed.emit(_player_gold, ...)`) instead of the signed delta. The moment `MissionEconomy` (new, Story 013) went live, every tower placement/sale would have caused `MissionEconomy._gold_balance` to inflate by TowerSystem's entire running balance on top of the correct delta — a real corruption bug, reachable in any live mission with both systems active.

### Fix

`TowerSystem`'s `_player_gold` field, its `resources_changed` subscription, and its `_on_resources_changed()` handler were removed entirely. Gate 2 (`place_tower()`, `get_placement_preview()`) now reads live via `GMissionEconomy.can_afford(cost)`. `place_tower()`/`sell_tower()` now emit signed deltas (`-placement_cost` / `+refund`) instead of absolute balances. `tests/unit/tower/tower_placement_test.gd` and `tests/unit/tower/tower_combat_test.gd` (which directly poked `_player_gold` as test setup/readback) were updated to seed/read gold via the real `GMissionEconomy` Autoload instead, with `mission_launched` resets in `before_test()`/`after_test()` to avoid cross-test state leakage (matching `tests/integration/core/mission_economy_test.gd`'s established convention). `src/gameplay/missions/the_gap/the_gap.gd`'s debug gold-seed stopgap (which directly poked the now-removed `_player_gold` field) was updated to seed via `resources_changed.emit(500, &"debug_seed")`, fired after `_launch_mission()` so `mission_launched`'s balance reset doesn't wipe it. Full suite verified: 811/811 passing, 0 regressions.

## TD-econ-007 — Combined-ERI validator (Story 015) cannot fail for any realistic content (resolved)

**Logged**: 2026-07-16
**Resolved**: 2026-07-31
**Story**: Discovered during Story 015 (Combined-ERI Content-Authoring Validator) code review, via qa-tester's testability review
**Severity**: Low-Medium — not a code defect, but the story's stated deliverable (a content-authoring safety net) may currently have near-zero practical value
**Area**: `src/core/resource_economy/combined_eri_validator.gd`, `design/gdd/resource-economy.md` Formula 4

### Gap

Story 015 built `CombinedEriValidator` to catch content authored with an unreasonably generous quantity/quality combination (Formula 4, `combined_ERI > WAVE_ERI_CEILING_COMBINED × ROUNDING_TOLERANCE`). Formula 4 itself was independently corrected on 2026-07-14 (see the GDD's own "Corrected during `/design-review`" note) — the corrected formula is mathematically bounded to a maximum of `23.84` for any `DropEntry` authored within Formula 3's stated range (`base_quality_probability` 0.05–0.15), confirmed by an exhaustive property-sweep test in `tests/unit/resource_economy/combined_eri_validator_test.gd`.

The only inputs that can trigger a failure are: (a) a degenerate `base_quality_probability=0.0`, which a schema-level `DropEntry.validate()` check could arguably already catch, or (b) an extreme `guaranteed_min_quantity` distortion — verified via a dedicated test to only *lower* the result further, never push it past the ceiling. Both were logged as new tests during this story's code review to make the finding explicit and regression-proof rather than silent.

This means the validator, as currently specified by the (now-corrected) GDD, cannot meaningfully catch the "plausible but overly generous" authoring mistake it was originally built to guard against — its real-world guardrail value is currently near zero for the input space content authors would actually produce.

### Recommended fix

Not resolved here — this is a design-judgment call (belongs to game-designer/qa-lead, tracked as a new Open Question in `design/gdd/resource-economy.md`), not something to redesign unilaterally during implementation. Options for a follow-up: (1) accept the check as a defense-in-depth guard against degenerate/malformed content only, and rescope its documented purpose accordingly; (2) redesign Formula 4 a second time with different bounds now that the corrected version's practical ceiling is understood; (3) decide the check is no longer worth maintaining and fold its concerns into `DropEntry.validate()`'s existing schema checks instead.

### Resolution
- [x] Decision made (2026-07-31, user): **Option (1) — accept as defense-in-depth only.** No code or formula change — Formula 4's own text already documented this framing correctly ("it exists to catch a future authoring mistake... not to reject ordinary content"), it just hadn't closed the loop against this entry's own Open Question.
- [x] `design/gdd/resource-economy.md`'s Open Questions table updated (2026-07-31) — the corresponding OQ marked resolved, cross-referencing this entry and the formula's own existing framing rather than duplicating it.
- [x] This entry closed.

## TD-econ-006 — `monster_died`/`monsters_died_batch` exclusivity invariant has no verifying test (fixed)

**Logged**: 2026-07-16
**Story**: Discovered during Story 014 (Batch Resolution Independence) code review
**Severity**: Medium — currently-relied-upon invariant with no regression coverage; a violation is a real-money-adjacent bug (double-awarded materials/gold)
**Area**: Monster System / Wave Manager kill-dispatch code (the emitter side), not Resource Economy

### Gap

ADR-0017 (Resource Economy Drop Resolution) documents an implicit exclusivity assumption: a given kill must fire exactly one of `monster_died` / `monsters_died_batch` for a given `entity_id`, never both. `ResourceEconomy` is a deliberately stateless calculator (per ADR-0017's own Decision — "no accumulator," "no hidden mutable history") and structurally cannot detect or prevent a violation of this invariant; it can only react to whatever events actually arrive.

`tests/unit/resource_economy/batch_resolution_independence_test.gd`'s third test (`test_resource_economy_monster_died_and_batch_firing_for_same_entity_id_is_not_deduplicated_at_this_layer`) documents this honestly: if the invariant is ever violated, `ResourceEconomy` double-awards materials. That test proves Resource Economy's reactive behavior is as designed — it does **not** prove the invariant itself holds. No test anywhere in the codebase currently verifies that Monster System / Wave Manager's kill-dispatch code actually maintains mutual exclusivity between the two signals for a given `entity_id`.

ADR-0017 was amended 2026-07-16 (see its Last Verified log) to correct its own Validation Criteria, which had asked for a guarantee this layer cannot structurally provide — the corrected criteria point here.

### Recommended fix

A dedicated story (or a scoped addition to whichever Monster System / Wave Manager story is picked up next) should add an integration test on the emitter side asserting: for any given kill, `monster_died` and `monsters_died_batch` are never both dispatched for the same `entity_id` within the same frame. This closes the actual risk; the Resource Economy tripwire test alone only documents the consequence if it's ever broken.

### Follow-up (2026-07-31): the recommended fix was vacuous until TD-monster-005 closed it

Investigated this entry to write the recommended mutual-exclusivity test and found `monsters_died_batch` is **never emitted anywhere in the codebase** — `MonsterManager._emit_death()` is the sole death-emission path and unconditionally fires `monster_died` (singular) for every kill, regardless of how many die in one frame. `event_bus.md`'s own signal doc comments ("Wave Manager owns the accumulator") describe intended behavior that doesn't exist: `WaveManager._on_monster_died()` only decrements `_enemies_alive`, no accumulation or re-emission logic exists there or anywhere else. This means the exclusivity invariant this entry worries about trivially held at the time (only one signal path was even live) — writing the requested test as originally scoped would have proven nothing meaningful. Logged as a new, more accurately-scoped entry, `TD-monster-005`, since the real gap (the batching mechanism itself doesn't exist) was bigger than a test-gap and deserved its own tracking rather than conflating two different problems under one entry.

### Resolution
- [x] `TD-monster-005` implemented and Accepted as `ADR-0033` (2026-07-31) — `MonsterManager` now buffers deaths and decides once per frame whether to emit individually or as one `monsters_died_batch`, making true mutual exclusivity a real, enforced guarantee rather than an accident of no code existing.
- [x] The originally-requested test now exists and is meaningful: `test_monster_died_and_monsters_died_batch_are_mutually_exclusive_per_frame` and `test_emit_death_never_emits_monster_died_synchronously_only_buffers` in `tests/unit/monster/monster_death_batch_accumulator_test.gd` directly verify the emitter-side guarantee this entry asked for, at multiple death counts on both sides of the threshold.
- [x] This entry closed.

## TD-monster-005 — `monsters_died_batch`'s accumulator was never implemented; the signal has 3 real subscribers but can never fire (fixed)

**Logged**: 2026-07-31
**Fixed**: 2026-07-31 (ADR-0033)
**Story**: Discovered while investigating TD-econ-006's recommended fix (a mutual-exclusivity test between `monster_died`/`monsters_died_batch`), which turned out to be vacuous once this was found.
**Severity**: Medium — no known reachable defect (the code that exists behaves correctly for what it does), but this is a real, silent gap between documented intent and shipped behavior: 3 real subscribers (`WaveManager`, `MissionHUD`, `ResourceEconomy`) all have working `_on_monsters_died_batch()` handlers for a signal that structurally cannot fire, and the documented performance mitigation (batching at high kill counts) doesn't exist to mitigate anything.
**Area**: `src/core/monster/monster_manager.gd` (`_emit_death()`, the sole death-emission path), `src/foundation/event_bus/event_bus.gd` (signal doc comments describing the undelivered intent)

### Gap

`event_bus.md`/`event_bus.gd`'s own signal declarations state the intended contract explicitly:
- `monster_died`: "At > 20 firings/frame: Wave Manager batch accumulator emits `monsters_died_batch` instead."
- `monsters_died_batch`: "Batch variant of `monster_died` — fires when >= 20 monsters die in one frame. Wave Manager owns the accumulator. EventBus remains a pure dispatcher."

Neither half of this exists in code. `MonsterManager._emit_death()` (`monster_manager.gd:126-140`) is the only place `monster_died` is emitted, and it does so unconditionally per-kill — no per-frame count tracking, no threshold check, no buffering. `WaveManager._on_monster_died()` (`wave_manager.gd:967`) — the system the comments say "owns the accumulator" — only decrements `_enemies_alive`; it contains no accumulation logic and never calls `GEventBus.monsters_died_batch.emit(...)` anywhere. A grep for `monsters_died_batch.emit` across `src/` returns zero results.

Despite this, 3 systems have real, tested `_on_monsters_died_batch()` subscriber logic waiting for a payload that can never arrive: `WaveManager` (`wave_manager.gd:1084`), `MissionHUD` (`mission_hud.gd:365`), `ResourceEconomy` (`resource_economy.gd:111`) — all correctly implemented against the documented contract, just permanently unreachable.

Real-world consequence: at genuinely high simultaneous kill counts (AoE towers, a dense wave clearing many monsters in one frame — exactly the >20/frame scenario this mechanism exists to handle), the game currently dispatches 20+ individual `monster_died` signals in the same frame instead of one batched `monsters_died_batch`. Every subscriber's per-event handler still runs correctly (this is not a correctness bug), but the specific performance/reasoning-load mitigation the batch path was designed for never engages.

### Recommended fix

- Implement the accumulator in `WaveManager` per the doc comments' own stated ownership: track kills within the current frame (e.g. a `_deaths_this_frame: Array[MonsterDiedEvent]` reset each physics/process frame), and at frame-end either emit one `monsters_died_batch` (if count ≥ 20) or let the already-fired individual `monster_died` signals stand (if below threshold) — the exact fire-both-vs-fire-one-or-the-other mechanics need a design decision, since `MonsterManager` currently emits `monster_died` unconditionally and unaware of any batching threshold; either `MonsterManager` needs to stop emitting individually above the threshold (requiring it to know about batching), or `WaveManager` needs to consume individual `monster_died` events and re-derive a batch without double-processing them downstream — this is a real architecture question, not just an implementation detail, and should probably go through `/architecture-decision` rather than being decided implicitly during implementation.
- Once implemented, TD-econ-006's original recommended fix (a mutual-exclusivity test) becomes meaningful and should be added at that point.
- Add a threshold constant (`>20`/`>=20` — the two doc comments disagree on `>` vs `>=`; reconcile before implementing) to Tuning Knobs if this is GDD-governed, or to `WaveManager` directly if purely a performance-implementation detail with no design-visible knob.

### Resolution
- [x] Ran through `/architecture-decision` as recommended, not decided inline (2026-07-31) — surfaced a real cross-GDD contradiction along the way (see `docs/architecture/adr-0033-monster-death-batch-accumulator.md`'s own Context section): `event-bus.md`'s AC-10/Formula 2 required true mutual exclusivity while `monster.md`'s own AC required unconditional per-kill emission, directly contradicting it. Resolved via 3 rounds of `AskUserQuestion`, not decided unilaterally.
- [x] `>` vs `>=` reconciled: `> 20` (21+ triggers batch), matching `event-bus.md`'s Formula 2 (`F_per_frame > 20`) exactly — the `>=` variant in the other doc comment was the inaccurate one, corrected.
- [x] Implemented (2026-07-31) — `MonsterManager` (not `WaveManager`) buffers deaths in `_pending_deaths` during Pass 1 and decides once at the existing Pass 4 flush point, mirroring the established `_pending_absorbed`/`_pending_damage` pattern (ADR-0006). `WaveManager` remains a subscriber only, unchanged.
- [x] **Real bug found and fixed during implementation**: the first implementation cleared `_pending_deaths` in place immediately after `emit()`-ing it — since GDScript `Array`s are reference types, this retroactively emptied the exact array any subscriber (or this feature's own test) held a reference to. Fixed by reassigning to a fresh array instead of clearing in place. See ADR-0033's own Implementation Notes for the full writeup — flagged there as a generally-applicable GDScript gotcha, not unique to this feature.
- [x] 8 new tests (`tests/unit/monster/monster_death_batch_accumulator_test.gd`) cover all 4 of ADR-0033's own Validation Criteria plus the aliasing-bug regression. 1 existing test updated for the renamed flush function. Full project regression: 1801/1801, 0 errors, 0 failures, 185 orphans (unchanged baseline).
- [x] 3 GDDs + the architecture registry corrected alongside the code (`monster.md`, `event-bus.md`, `docs/registry/architecture.yaml`) — see ADR-0033 for the exact diffs.
- [x] This entry closed.

## TD-pause-001 — No pause mechanism exists anywhere in the codebase (fixed)

**Logged**: 2026-07-07
**Fixed**: 2026-07-08 (ADR-0014)
**Story**: Discovered while triaging `design/ux/pause-menu.md`'s Open Questions
**Severity**: High — this is a committed Standard-tier accessibility feature, not a nice-to-have
**Area**: Entire codebase — no owning system exists yet

### Gap

A full search of `src/`, `design/gdd/event-bus.md`, and `docs/architecture/adr-0002-scene-autoload-structure.md`
found zero references to `game_paused`, `game_unpaused`, `SceneTree.paused`, or `get_tree().paused`
anywhere. No pause mechanism of any kind is implemented. `design/accessibility-requirements.md`'s
Motor Accessibility section commits to "pause anywhere, including mid-wave, with no penalty" as a
feature explicitly *in scope beyond the Standard-tier baseline* — this is not deferred or optional
per that document, but nothing has been built toward it yet.

`design/ux/pause-menu.md` (the UX spec) exists and assumes this mechanism will exist, but its own
Open Questions correctly flagged the gap rather than assuming it away.

### Recommended fix

A dedicated story should:
1. Decide the pause mechanism: `SceneTree.paused = true` (built-in engine pause, requires every
   node that must keep running during pause — e.g. the Pause Menu's own UI — to set
   `process_mode = Node.PROCESS_MODE_ALWAYS`) vs. a custom EventBus-driven pause where every
   timer-owning system (Wave Manager phase timers, spawn coroutines, Hero auto-attack) manually
   checks a paused flag. The engine-native approach is almost certainly simpler and more reliable
   — recommend starting there unless a concrete reason rules it out.
2. Add `game_paused`/`game_unpaused` (or equivalent) to `design/gdd/event-bus.md`'s catalogue if
   any system needs to react beyond what `SceneTree.paused` handles automatically.
3. Wire the Pause Menu's actual pause/resume trigger once built.
4. Verify pause is reachable and functional in every mission phase including WAVE_ACTIVE and mid-boss-fight, per the accessibility commitment's explicit wording.

### Resolution (2026-07-08)

Fixed via ADR-0014 (`docs/architecture/adr-0014-pause-system.md`, Accepted). Chose the
engine-native `SceneTree.paused` approach (Alternative 1 above), per user decision.
`src/gameplay/ui/pause_menu/pause_menu.gd` + `.tscn` — a `CanvasLayer` with
`process_mode = PROCESS_MODE_ALWAYS`, instanced into `the_gap.tscn` — owns the toggle on the
new `pause` input action (Esc / gamepad Start), and emits the new `game_paused`/`game_unpaused`
EventBus signals (informational only; `SceneTree.paused` propagation does the real work).
Scoped down from the full UX spec per user decision: Resume + Quit to Sanctuary only — Settings,
Objective, and Quit to Main Menu deferred, since none of those exist as systems yet (Settings
overlay, Objective panel, and any Main Menu scene/SceneManager transition are all unbuilt).

Found and fixed one real gap during implementation: `wave_manager.gd`'s spawn coroutine used
`get_tree().create_timer(entry.pre_delay).timeout` with the default `process_always: true`,
meaning scheduled mid-wave spawns would have kept firing while the game was "paused" — a direct
violation of the pause-anywhere accessibility commitment during the single most consequential
case (mid-`WAVE_ACTIVE`). Fixed by passing `process_always: false`. This was already flagged as
a risk in ADR-0012's own Negative/Risk section but never resolved until now.

Test evidence: `tests/unit/pause_menu/pause_menu_test.gd` (10 new tests, all passing, 0
orphans). Full regression: 609/609 executed, 0 errors, 1 pre-existing unrelated failure
(`hero_lifecycle_test.gd` AC-13, TD-hero-005), 26 pre-existing orphans confined entirely to
`event_payload_validation_test.gd` (untouched by this change) — 0 new failures, 0 new orphans.

### Resolution
- [x] Pause mechanism decided (2026-07-08, ADR-0014) — engine-native `SceneTree.paused`, per user decision.
- [x] Implemented and wired to Pause Menu (2026-07-08) — `src/gameplay/ui/pause_menu/pause_menu.gd`/`.tscn` instanced into both `MissionScene.tscn` and `the_gap.tscn` (verified present, 2026-09-02).
- [x] Verified functional in every mission phase, no exceptions — including the mid-`WAVE_ACTIVE` spawn-coroutine gap this same fix found and closed (`wave_manager.gd`'s `create_timer(..., process_always: false)`). Test evidence: `tests/unit/pause_menu/pause_menu_test.gd`, 10/10 passing at the time of the fix.
- [x] This entry closed (2026-09-02) — this checklist itself was the only thing left open; the "Resolution (2026-07-08)" narrative above it already documented full closure over a year of commits ago but the checklist was never ticked to match.

---

## TD-save-001 — SavePersistence integration test coverage gaps (fixed)

**Logged**: 2026-05-25
**Fixed**: 2026-07-08
**Story**: S2-02 Save & Persistence Autoload Implementation
**Severity**: Advisory
**Area**: `src/foundation/save_persistence/save_persistence.gd`

### Gaps

| Gap | AC | Why untested |
|-----|----|--------------|
| `store_32()`/`store_var()` abort path | AC-3 | No FileAccess DI seam — cannot force `store_*` to return false in unit tests |
| `sanctuary_state_restored` deferred exactly 1 frame | AC-8 | Requires `await get_tree().process_frame` in a running SceneTree — integration test needed |
| EventBus signal wiring (`mission_launched`, `mission_phase_changed`) | AC-12 | `_ready()` not called in unit tests; wiring untested at any level |
| `register()` public API | AC-10 | All restore tests bypass `register()` by directly appending to `_registered_systems` |

### Recommended fix

Create `tests/integration/save_persistence/save_persistence_integration_test.gd` covering:
1. `register()` API round-trip (register → load → verify data routed correctly)
2. EventBus signal wiring (`emit mission_launched` → verify checkpoint written)
3. Deferred emit: `await process_frame` after `_restore_all_systems`, verify `sanctuary_state_restored` fires

This work is a prerequisite for S2-05 (Foundation boot-order integration test) being fully representative.

### Resolution
- [x] AC-8, AC-10, AC-12 — **already covered in a prior session** (never checked off here): `save_persistence_write_test.gd`/`save_persistence_restore_test.gd` already had dedicated "TD-save-001 debt closure" sections for deferred-emit timing, `register()`'s `get_save_data()` call count, and EventBus wiring (`mission_launched`/`mission_phase_changed`). Discovered during this pass — same stale-checkbox pattern as S5-01/S5-02.
- [x] AC-3 (2026-07-08): added a real DI seam — `_force_store_32_failure`/`_force_store_var_failure` test-only flags in `save_persistence.gd`, since `FileAccess`'s `store_32()`/`store_var()` are native/non-virtual and cannot be subclassed to fake a failure. 3 new tests: `_write_slot()` abort on `store_32` failure, `_write_slot()` abort on `store_var` failure, `_write_checkpoint()` abort on `store_var` failure (checkpoint has no atomic tmp-swap like slot writes do, so only the return value — not file-non-existence — is a reliable failure signal there).
- [x] Full `register()` round-trip through the real restore path (2026-07-08): existing restore tests all bypassed `register()` by directly appending to `_registered_systems` — added `test_register_save_load_round_trip_routes_data_through_real_restore_path`, exercising `register()` → `save_slot()` → `load_slot()` → `_restore_all_systems()` end to end with a real stub system.
- [x] This entry closed. Test evidence: `tests/unit/save_persistence` 25/25 passing (up from 21), 0 orphans. Full regression: 650/650, 0 errors, 0 failures.

---

## TD-monster-001 — ADR-0001 deferred dispatch compliance in MonsterManager (accepted deviation)

**Logged**: 2026-07-01
**Resolved**: 2026-07-08
**Story**: S3-02 Monster System Implementation
**Severity**: Advisory
**Area**: `src/core/monster/monster_manager.gd`

### Issue

Several signals emitted from within `_physics_process` use synchronous dispatch:
`monster_died`, `monster_breached`, `boss_died`, `monster_cell_entered`, `monster_spawned`.
ADR-0001 Rule 2 states physics callers should use deferred dispatch for most signals.

`monster_spawned` is intentionally synchronous (Tower GDD Rule 14a — towers must register
the entity before the next physics frame). All others are candidates for deferral.

### Risk

If any signal subscriber triggers logic that modifies `active_monsters` or `_entity_lookup`
during the physics frame, concurrent modification could cause silent data loss or incorrect
breach/death ordering. No such subscriber exists today, but Wave Manager will subscribe to
`monster_died` to track remaining enemies — if that handler reads `active_monsters.size()`,
it will see the count BEFORE the swap-buffer prunes dead entities (swap runs end of Pass 3).

### Recommended fix

Before Wave Manager integration (S3-06), audit each emitted signal:
1. `monster_died` — convert to deferred; Wave Manager must handle one-frame delay
2. `monster_breached` — convert to deferred
3. `boss_died` — convert to deferred
4. `monster_cell_entered` — convert to deferred (tower targeting reads this)

Keep `monster_spawned` synchronous (documented exception).

### Resolution
- [x] Reviewed (2026-07-08, after S3-06/epic-04 Wave Manager integration already shipped) — audited every real subscriber of the 4 signals that has since gone live: `WaveManager._on_boss_died()`, `WaveManager._on_monster_breached()`, `TowerSystem._on_monster_cell_entered()`, `Hero._on_monster_cell_entered()`. None reads `MonsterManager`'s live `active_monsters`/`_entity_lookup` collections — each tracks its own independent local counter/cache (e.g. `WaveManager._enemies_alive` decrements on the event itself, never derived from `MonsterManager`'s collection size). The specific race this ticket originally feared does not exist in any shipped subscriber.
- [x] Deferral decision recorded in ADR-0001 amendment (2026-07-08) — user decision: accept synchronous dispatch as a documented, justified deviation rather than convert to deferred. Converting now would introduce a real 1-frame delay into stable, fully-tested wave-clear and targeting-cache timing, for a compliance technicality with no corresponding safety gain once the audit ruled out the original risk. Recorded directly in `adr-0001-eventbus-architecture.md`'s Rule 2 section as a dated amendment, including the "revisit if a future subscriber reads MonsterManager's collections directly" condition.
- [x] This entry closed. No code change — decision-and-documentation only.

---

## TD-monster-002 — MonsterManager untested code paths (fixed)

**Logged**: 2026-07-01
**Fixed**: 2026-07-08
**Story**: S3-02 Monster System Implementation
**Severity**: Advisory
**Area**: `src/core/monster/monster_manager.gd`

### Gaps

| Gap | Method | Why untested |
|-----|--------|--------------|
| HP absorption tracking | `_pass4_absorbed_flush` | No test for `monster_hp_absorbed` signal or absorbed accumulator |
| Wave-end force-death | `_on_wave_completed` | No test for the BOSS `boss_died` + `monster_died` force-emit path |
| High difficulty scaling | `_spawn_entity` | All tests use `difficulty_tier=1`; diff_mult path (tier ≥ 2) untested |
| BOSS `boss_hp_changed` on non-lethal hit | `_pass1_damage` | Non-lethal BOSS damage signal not exercised |

### Recommended fix

Add follow-up tests in a future story or as part of S3-05 (Combat loop integration):
1. `_pass4_absorbed_flush` — spawn entity, inject non-lethal damage, run all 4 passes, assert `monster_hp_absorbed` emitted with correct value
2. `_on_wave_completed` — spawn active monster, emit `wave_completed`, verify `monster_died` fires with `kill_source == &"wave_end"`
3. `difficulty_tier=2` — verify `diff_mult = 1.35` is applied correctly to HP

### Resolution
- [x] Tests added (2026-07-08) — new `tests/unit/monster/monster_manager_debt_coverage_test.gd` (8 tests): `_pass4_absorbed_flush` HP absorption (normal + overkill-clamped cases), `_on_wave_completed` force-death (`monster_died` with `kill_source == &"wave_end"` + `boss_died` with `"force_removed"` cause), `difficulty_tier=2` HP scaling (`diff_mult = 1.35` applied correctly, verified against `difficulty_tier=1`'s no-op case), and `boss_hp_changed` on non-lethal BOSS hits (plus a negative case confirming non-BOSS tiers never emit it).
- [x] Real test-isolation issue found and fixed during this work (not itself tech debt, a byproduct of writing these specific tests): `MonsterManager` is a live scene-tree `Node` with its own `_physics_process`; the `_on_wave_completed` tests' `queue_free()`+collection-clear calls could interleave with an engine-driven automatic physics tick between test cases, producing "previously freed" runtime errors. Fixed by calling `_mm.set_physics_process(false)` in this file's `before_test()` (every pass is invoked manually anyway, so no functional loss).
- [x] This entry closed. Test evidence: 8/8 passing, 0 errors, 0 orphans. Full regression: 650/650, 0 errors, 0 failures.

---

## TD-monster-003 — Spawned MonsterEntity nodes never added to the scene tree (fixed)

**Logged**: 2026-07-03
**Fixed**: 2026-07-06
**Story**: Discovered during S3-06 Wave Manager Phase 1 integration testing
**Severity**: Advisory
**Area**: `src/core/monster/monster_manager.gd:272` (`_spawn_entity`)

### Gap

`_spawn_entity()` creates each `MonsterEntity` via `MonsterEntity.new()` and appends it to
`active_monsters` / `spawning_entities`, but never calls `add_child()` to parent it into the
scene tree. Every spawned entity is therefore a Godot "orphan node" from creation until it is
explicitly `.free()`'d — confirmed by gdUnit4's orphan-node detector flagging 1–2 orphans per
test in `tests/integration/wave_manager/wave_manager_spawn_integration_test.gd` (which spawns
monsters through the real `MonsterManager.spawn_monster()` path). No test failures resulted —
`is_instance_valid` guards and array bookkeeping remain correct even without a parent — but
this deviates from normal Godot node lifecycle (no `_ready()`/`_process()` on the entity itself,
no visibility in the scene tree for debugging, and reliance on manual `.free()` instead of
`queue_free()` + parent removal for cleanup).

### Recommended fix

Add `add_child(entity)` (or parent to a dedicated `MonsterContainer` node) in `_spawn_entity()`
right after `MonsterEntity.new()`, and reconcile with existing `entity.queue_free()` call in
`_emit_death()` (monster_manager.gd:133) which already assumes a parent for the deferred free
to take effect correctly against the scene tree.

### Resolution
- [x] `add_child()` added in `_spawn_entity` (2026-07-06, S4-18) — parents to `MonsterManager`
  itself rather than a dedicated container. Real integration hazard found and fixed in the
  same pass: `src/gameplay/missions/the_gap/the_gap.gd::_on_monster_spawned()` (written later,
  during S4-09, after this debt was logged) had its own scene-local `_monsters_container.add_child(entity)`
  workaround for this exact gap — now updated to `entity.reparent(_monsters_container)` since
  the entity already has a parent (`MonsterManager`) by the time that handler runs.
- [x] Existing monster unit/integration tests re-verified with node parenting in place
  (2026-07-06) — required additional fixes beyond the single-line recommendation above: three
  pure-unit-test files (`monster_spawn_test.gd`, `monster_movement_test.gd`, `monster_boss_test.gd`)
  created `MonsterManager` without ever adding it to the SceneTree (`add_child(_mm)` was
  missing), so spawned entities — though now parented to `_mm` — were still unreachable from
  the live tree and continued to show as orphans. Fixed by adding `add_child(_mm)` (before
  overriding DI stub seams, since `_ready()` unconditionally sets `_grid`/`_pathfinding` to the
  real autoloads) and `remove_child(_mm)` before `_mm.free()` in `after_test()`, matching the
  pattern already used in this codebase's integration test files. Also confirmed (empirically,
  not by assumption) that `Node.free()` does NOT recursively free children — it only detaches
  them, leaving them as genuine leaked orphans — so the existing per-entity manual `.free()`
  loops in every affected test file's `after_test()` remain necessary and were kept as-is.
- [x] This entry closed (2026-07-06) — verified via headless gdUnit4 run:
  `tests/unit/monster` + `tests/integration/wave_manager` + `tests/integration/core` +
  `tests/integration/mission_scene` + `tests/integration/monster` = 125/125 passing, 0 errors,
  0 failures, **0 orphans** (down from the pre-fix baseline). Full project regression:
  557/557 executed, 0 errors, 1 pre-existing unrelated failure (`TD-hero-005`), 0 new failures,
  total project orphan count down to 10 (remaining orphans are pre-existing and tracked
  separately under `TD-test-001`/`TD-test-002`, out of this entry's scope).

---

## TD-monster-004 — AC-28/AC-40 field-scale active-agent performance never measured (real profiler required) (fixed)

**Logged**: 2026-07-10
**Fixed**: 2026-08-01
**Story**: Discovered while confirming a `systems-design-2026-07-10-revalidation.md` gate-check
follow-up (Technical Director flagged S4-10's stress test as candidate-but-unconfirmed
closing evidence for this exact risk)
**Severity**: Advisory — same category as `TD-perf-001` (measurement gap, not a known
performance failure)
**Area**: `src/core/monster/monster_manager.gd` (`_pass3_movement`, `_physics_process`)

### Gap

`design/gdd/monster.md` AC-28 and AC-40 (both `[Performance · BLOCKING]`) require: **150
ACTIVE monsters simultaneously present in `active_monsters`, each traversing a path, over 60
consecutive physics frames (1 second simulated), with the real Godot profiler enabled on a
minimum-spec machine, THEN total Monster System `_physics_process` CPU time ≤ 2.0ms/frame**.
Both ACs explicitly require profiler-output evidence saved to
`production/qa/evidence/monster-perf-[date].png` / `monster-aoe-perf-[date].png` — neither file
exists (confirmed via `find`, zero results).

S4-10 (`production/stories/foundation/s4-10-pathfinding-perf-stress-test.md`,
`tests/performance/sprint-04-profiler.md`) was initially assumed to be closing evidence for
"the 100-agent performance risk" in general, but re-reading it confirms it measures a
**different dimension entirely**: `find_path()` QUERY cost — a one-time A* lookup per monster
at spawn (AC-3's "150-monster spawn burst, single frame") and repeated warm-cache query
throughput (AC-4). It never simulates 150 monsters remaining ACTIVE and MOVING across 60
consecutive frames, and never touches `_pass3_movement()`'s per-frame `_advance_entity()` cost
(Vector math, arrival checks, `monster_cell_entered` emission) at that scale. AC-28/AC-40's own
GDD text independently confirms this is unmeasured: "Cannot be verified headlessly without a
profiler-capable build" — the same category of gap as `TD-perf-001` (draw-call/FPS
measurement), which was later closed via live Godot MCP bridge access when that tooling was
available.

### Recommended fix

Once live Godot MCP/editor tooling is available again (this environment's `godot-ai` server
has been intermittently unreachable across sessions — see `reference_godot_mcp_servers.md`),
run a real scene with 150 ACTIVE monsters simultaneously pathing across 60 consecutive physics
frames, capture `Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)` or an equivalent
profiler sample isolating Monster System's own cost, and save the evidence per AC-28/AC-40's
literal path requirements. If the measured cost exceeds the 2.0ms budget, this becomes a real
optimization story, not just a measurement gap.

### Resolution
- [x] Real evidence captured for AC-28 (2026-08-01) — 150 ACTIVE monsters (real `Grid`+`PathfindingSystem`+`MonsterManager`, real production `spawn_monster()` API, no stubs), 60 consecutive real `_physics_process()` calls, timed individually via `Time.get_ticks_usec()` and live-verified against the pinned Godot 4.6.2.stable binary through the Godot MCP bridge. **Result: avg 0.328ms/frame, max 0.857ms/frame — well within the 2.0ms budget** (16.4%/42.9% of budget respectively). Real movement confirmed directly (`distance_moved == 128` world units, matching `scaled_speed=2.0` over 1 simulated second) — an earlier pass in the same session had omitted `_is_wave_active = true` (the flag `MonsterManager._physics_process()` gates all 4 passes behind) and produced an invalid, suspiciously-fast 0.0002ms/frame reading with zero actual movement; caught by directly checking a monster's position changed, not by trusting the first number. Evidence: `production/qa/evidence/monster-perf-2026-08-01.md` (a `.md` file with real numeric measurements, not a literal `.png` profiler screenshot — matches the same already-accepted deviation `TD-perf-001` and the Tower Mastery profiling evidence both used, for the same "no interactive profiler session available in this environment" reason).
- [x] Real evidence captured for AC-40 (2026-08-01) — 22 simultaneous lethal hits (21 STANDARD + 1 BOSS), real `MonsterManager.spawn_monster()`/`_physics_process()`, damage payloads injected directly into `_pending_damage` (bypassing the shared `GEventBus.monster_damage_taken` signal deliberately, to avoid cross-talk with whatever real scene happened to be running concurrently — the EventBus hop isn't what this AC measures). **Result: 0.128ms — 3.2% of the 4.0ms budget.** Every behavioral clause of the AC independently verified via real spy listeners, not just the timing: exactly one `monsters_died_batch` emission with all 22 payloads, zero individual `monster_died` calls (mutual exclusivity confirmed), `boss_died` fired synchronously exactly once for the BOSS entity, `active_monsters` correctly dropped 22→0. Evidence: `production/qa/evidence/monster-aoe-perf-2026-08-01.md`.
- [x] This entry closed (2026-08-01) — both AC-28 and AC-40 now have real, live-measured evidence.

---

## TD-wave-001 — WaveManager registered at the wrong Autoload boot position (fixed)

**Logged**: 2026-07-03
**Fixed**: 2026-07-03
**Story**: S3-06 Wave Manager Phase 1 — surfaced during `/code-review`
**Severity**: Advisory
**Area**: `project.godot` `[autoload]`, `src/gameplay/wave_manager.gd`

### Gap

ADR-0002 (revised 2026-05-24) specifies the Autoload boot order as: EventBus(1) →
SavePersistence(2) → Grid(3) → Pathfinding(4) → GameDataRegistry(5) → SceneManager(6) →
WaveManager(7). Neither `GameDataRegistry` nor `SceneManager` exist yet in this project, so
`GWaveManager` was registered as the 5th autoload (immediately after `GPathfindingSystem`) as a
pragmatic placeholder — WaveManager doesn't functionally depend on either missing system for its
current (S3-06) scope. This is safe today, but nothing currently prevents a future story from
adding `GameDataRegistry` or `SceneManager` *after* `GWaveManager` in `project.godot`, silently
violating the documented boot order (ADR-0002 calls this a "build invariant").

### Recommended fix

When `GameDataRegistry` and/or `SceneManager` are implemented, insert their `[autoload]` entries
in `project.godot` *before* `GWaveManager`, matching ADR-0002's table exactly. Update the header
comment in `src/gameplay/wave_manager.gd` to drop the "registered as 5th autoload" caveat once
resolved.

### Resolution
- [x] `GameDataRegistry` and `SceneManager` implemented and inserted before `GWaveManager` (S4-02, S4-01)
- [x] `project.godot` autoload order matches ADR-0002 exactly — verified: EventBus, SavePersistence, Grid, PathfindingSystem, GameDataRegistry, SceneManager, WaveManager
- [x] `wave_manager.gd` header comment updated
- [x] This entry closed — 2026-07-03

---

## TD-tower-002 — Tower test suites leak orphan Node instances (fixed)

**Logged**: 2026-07-03
**Fixed**: 2026-07-06
**Story**: Discovered while fixing S3-03's broken tower test files during `/smoke-check` follow-up
**Severity**: Advisory
**Area**: `tests/unit/tower/tower_placement_test.gd`, `tests/unit/tower/tower_combat_test.gd`

### Gap

`TowerSystem` (`src/core/tower/tower_system.gd`) extends `Node`. Both test files create it via
`_ts = TowerSystem.new()` in `before_test()` but `after_test()` only sets `_ts = null` — this
does not free a `Node`-derived object (unlike `RefCounted`, which is reference-counted and would
be garbage-collected). Confirmed via gdUnit4's orphan-node detector: 15+ orphan nodes reported
across the two suites after the parse-error fix (see TD-monster-003 for a related but distinct
production-code orphan issue).

### Recommended fix

In each file's `after_test()`, replace `_ts = null` with `_ts.free()` (or `_ts.queue_free()` if
any deferred cleanup is pending) before nulling the reference.

### Resolution
- [x] `after_test()` updated in both files to explicitly free `_ts` (2026-07-06, S4-18) —
  `_ts.free()` before `_ts = null`, confirmed `_ts` is never added to the scene tree in either
  file so `.free()` (not `queue_free()`) is correct and immediate.
- [x] Orphan count confirmed at 0 for `tests/unit/tower/` (2026-07-06) — verified via headless
  gdUnit4 run: 60/60 test cases passing, 0 errors, 0 failures, 0 orphans.
- [x] This entry closed (2026-07-06)

---

## TD-path-001 — AC-4 profiler test measures cold fallback path, not warm template lookup (fixed)

**Logged**: 2026-07-03
**Fixed**: 2026-07-06
**Story**: Discovered while filling `tests/performance/sprint-03-profiler.md` (Sprint 3 sign-off condition closure)
**Severity**: Advisory
**Area**: `tests/integration/core/combat_loop_test.gd::test_pathfinding_profiler_find_path_100_samples`

### Gap

AC-4 (`design/gdd/pathfinding.md:396`) requires measuring 100 `find_path()` calls against a
**populated grid with pre-built route templates** — the O(1) template-lookup scenario. The
current test calls the real `GPathfindingSystem` autoload directly without ever building route
templates (the file's `before_test()` only stubs pathfinding for the combat-loop tests under
test, not the profiler tests). Every call falls through to a cold full-A* fallback build instead
of a template lookup. Measured: 34.043ms avg per call — 34× over the 1ms target — but this
number reflects the fallback path repeated 100×, not the warm-path scenario AC-4 specifies.
Corroborated by AC-24a's own baseline measurement (30.645ms for a single fallback call) being
nearly identical to the "100-sample avg," which would not be true if the 100-sample test were
actually hitting a fast template cache after the first call.

### Recommended fix

Add route-template setup to `test_pathfinding_profiler_find_path_100_samples` before its
measurement loop — e.g. populate `GGrid` and trigger `GPathfindingSystem`'s template-build path
(simulate `mission_launched` → await `templates_ready`), matching the "populated grid" precondition
AC-4's GDD text requires. Re-run and record a real PASS/WARNING/FAIL verdict once templates are
warm.

### Resolution
- [x] Route-template setup added to the AC-4 profiler test
- [x] Test re-run with warm templates; real verdict recorded in `tests/performance/sprint-03-profiler.md`
- [x] This entry closed

**Closed**: 2026-07-06 (S4-10). `test_pathfinding_profiler_find_path_100_samples` now builds
real route templates via a fresh isolated `PathfindingSystem`/`Grid`/`EventBus` instance
(`_setup_isolated_pathfinding()` in `tests/integration/core/combat_loop_test.gd`), warmed
through the real production template-build path (`_on_mission_phase_changed("", "SCOUT", 0.0)`),
before its measurement loop — matching the recommended fix above. Re-measured on a warm 16×12
grid (avg path length 25): **p50=0.0960ms, p95=0.0990ms, p99=0.1200ms, p99.9=0.1370ms** for a
100-call batch — roughly 250× under-budget vs the ≤1ms p99.9 target, and two orders of magnitude
different from the invalid 34.043ms cold-fallback number this entry originally flagged. Real
**PASS** verdict recorded in `tests/performance/sprint-04-profiler.md` (supersedes the INVALID
verdict in `tests/performance/sprint-03-profiler.md`, which is left in place with a pointer for
historical record — see S4-10 story). Note: the measurement window uses 1000 batches of 100
calls (100,000 total calls) with one forced GC-trigger allocation mid-run, as a documented
substitute for AC-4's literal "10-second wall-clock window" (impractical for a CI unit test) —
see `tests/performance/sprint-04-profiler.md` for the deviation rationale.

---

## TD-test-001 — `assert_error(func...).is_push_error(...)` leaves orphan nodes (accepted gdUnit4 library limitation)

**Logged**: 2026-07-03
**Fixed**: 2026-07-07 (documented as accepted, not a code fix)
**Story**: S4-02 GameDataRegistry Autoload
**Severity**: Advisory
**Area**: `tests/unit/game_data_registry/game_data_registry_test.gd`

### Gap

Two tests use gdUnit4's `assert_error(func() -> void: ...).is_push_error(...)`
combinator to assert a `push_error()` call happens inside `GameDataRegistry._ready()`
(`test_ready_logs_push_error_for_invalid_monster_resource`,
`test_get_perk_registry_missing_file_returns_null_without_crash`). Both report
"possible orphan nodes" warnings (6 total across the suite) despite `after_test()`
correctly calling `.free()` on the test's own `_registry` instance — unlike the
already-tracked TD-monster-003/TD-tower-002 orphan bugs, this is not a missing
`.free()` call. This `assert_error(func...)` pattern has no precedent elsewhere in
the codebase (confirmed via grep), so there's no known-good comparison to isolate
whether this is a gdUnit4 internal implementation detail (e.g. an error-capture
proxy object) or a subtler issue in how the lambda closure interacts with the
awaited assertion. All 26 tests in the suite pass (0 errors, 0 failures) —
this is a warning-only gap, not a correctness issue.

### Recommended fix

Investigate gdUnit4's `GdUnitGodotErrorAssertImpl` source
(`addons/gdUnit4/src/asserts/GdUnitGodotErrorAssertImpl.gd`) to determine whether
it internally instantiates a Node-derived spy/monitor object that isn't cleaned
up after the awaited assertion resolves. If it's a gdUnit4 library quirk, consider
filing upstream or switching to a manual `push_error` capture pattern (redirect
stderr / use a signal-based error hook) for these two specific tests. If it's
something in this test file, add `collect_orphan_node_details()` at the end of
one of the affected tests to get the object type name (which the current gdUnit4
output truncates to "1 possible orphan node" with no further detail).

### Resolution
- [x] Root cause identified as **gdUnit4 internal, not a test-file issue** (2026-07-07). Static trace of `GdUnitGodotErrorAssertImpl.gd`: the class chain (`GdUnitGodotErrorAssertImpl` → `GdUnitGodotErrorAssert` → `GdUnitAssert extends RefCounted`) is entirely `RefCounted`, not `Node` — ruled out as the orphan source directly, since Godot's orphan-node detector only tracks `Node` instances. The `_logger := GodotGdErrorMonitor.GdUnitLogger.new(...)` field traces through `GdUnitMonitor extends RefCounted` too — also ruled out. `GdUnitLogger extends Logger`, and `Logger` resolves to Godot's own **built-in `Logger` engine class, added in Godot 4.5** (confirmed via web search — this project's LLM knowledge cutoff predates 4.5, so this class was unknown territory; now confirmed real and intentional, not an addon bug). A web search for this exact symptom surfaced a matching upstream report — **`godot-gdunit-labs/gdUnit4` issue #122**, "Run test via `GdUnitCmdTool` --verbose shows a lot of orphan nodes" — strongly suggesting this is a **known gdUnit4 framework-level quirk**, not specific to this project's test file or the `assert_error(func...)` pattern's usage here. The issue's full discussion/resolution status was not read in this session (GitHub fetch was skipped per user instruction) — the match is based on the search snippet's title/description only.
- [x] Documented as an accepted gdUnit4 library limitation (2026-07-07) — not fixed, since the cause lives in the addon's own `Logger`-based error-capture mechanism, not in this project's code. No test-file change is warranted.
- [x] This entry closed (2026-07-07) — **caveat**: closure is based on static source tracing + a plausible but unconfirmed upstream issue match, not a live re-run of the affected tests with `collect_orphan_node_details()` (the originally recommended fallback diagnostic). If the orphan count changes with a future gdUnit4 addon update, re-open and verify against the actual upstream issue thread.
- [x] **Related finding, 2026-08-01**: `TD-test-006` independently root-caused a *different* (but related-in-spirit) gdUnit4 timing artifact — the orphan snapshot fires before `after_test()` runs, not specifically tied to `assert_error(func...)`. This entry's `Logger`-class theory remains a distinct, separate mechanism (confirmed via a different investigation path) — not superseded, just adjacent. Worth checking `TD-test-006` first if this symptom recurs, since it's the more general and more thoroughly confirmed explanation.

---

## TD-test-002 — "3 resources still in use at exit" after SceneManager tests (accepted as benign)

**Logged**: 2026-07-03
**Fixed**: 2026-07-07 (documented as accepted, not a code fix)
**Story**: S4-01 SceneManager Autoload
**Severity**: Advisory
**Area**: `tests/integration/foundation/scene_manager_transition_test.gd`, `tests/unit/scene_manager/scene_manager_test.gd`

### Gap

Running the full test suite after S4-01's tests are added produces an engine-exit
warning: `ERROR: 3 resources still in use at exit (run with --verbose for details).`
This did not appear in prior full-suite runs this session (verified: 0 test
failures, 341/341 passing — this is a cleanup-only warning at process exit, not
a test failure). Likely cause: `SceneManager._do_transition()` calls
`get_tree().change_scene_to_packed(packed_scene)` using a `PackedScene` loaded
via `ResourceLoader.load()` — the loaded stub scene resource(s) from repeated
transitions across multiple tests may not be released before the test process
exits, since `SceneManager` is a real, persistent Autoload with no test-suite-level
teardown hook.

### Recommended fix

Run with `--verbose` to identify the specific 3 leaked resources. If they are the
stub `PackedScene` loads, consider whether `ResourceLoader.load()` should use a
cache mode that doesn't pin the resource, or whether the test fixture scene
should be a `Resource` freed explicitly in `after_test()`. Low priority — no test
failures result, and this is likely benign for the actual game (Autoloads and
their loaded scenes are expected to persist for the process lifetime in normal
play, just not in a test-suite context that loads/unloads them repeatedly).

### Resolution
- [x] Root cause identified via static analysis (2026-07-07) — the `--verbose` run itself still isn't possible in this environment (same headless-runner limitation as `TD-test-003`), but reading `scene_manager_transition_test.gd` confirms the hypothesis directly: the suite uses the **real `GSceneManager` autoload** (not a test-local instance) and calls `transition_to_mission()`/`transition_to_sanctuary()` repeatedly across multiple tests, each performing a genuine `get_tree().change_scene_to_packed()` swap of the actual scene tree's current scene. `after_test()` restores `_inject()`'s paths and the `_transition_in_progress` flag, but never restores the scene tree itself to a blank/empty state. Whichever scene was swapped in by the *last* test to run in this suite is still resident as the tree's current scene when the whole gdUnit4 process eventually exits — nothing ever explicitly frees it. This is a strong, consistent explanation for "3 resources still in use at exit," though the exact 3 resource identities weren't confirmed (would require the `--verbose` output this environment still can't produce).
- [x] Documented as expected/benign for Autoload-driven scene loads (2026-07-07) — confirmed low priority as originally assessed: `SceneManager` is designed to own scene transitions for the entire game session (Autoload #6, ADR-0002), so a scene remaining loaded at process end is completely normal in real play. It only surfaces as a *warning* here because gdUnit4's test process itself exits without the game's normal lifecycle ever calling for a final scene teardown — an artifact of testing a persistent-by-design Autoload, not a real leak.
- [x] This entry closed (2026-07-07) — **not fixed, deliberately**: forcing `after_test()` to reset the scene tree back to empty was considered but not applied without live verification that doing so wouldn't disrupt other test files sharing the same real `GSceneManager` singleton and scene tree across a single test process run. If this warning ever escalates to an actual test failure (not just an exit-time warning), revisit with real `--verbose` output in hand.

---

## TD-adr-001 — ADR-0010 incorrectly states "Hero System is an Autoload" (fixed)

**Logged**: 2026-07-03
**Fixed**: 2026-07-08
**Story**: Discovered during S4-01 code review, independently reconfirmed during S4-03 code review
**Severity**: Advisory (documentation only — no code impact, both implementations already correctly ignore this line)
**Area**: `docs/architecture/adr-0010-hero-tower-synced-class.md`, Context → Constraints section

### Gap

`adr-0010-hero-tower-synced-class.md`'s Constraints list states: "Hero System is an
Autoload; Tower System is not — no reverse dependency allowed." This directly
contradicts:
- `docs/architecture/control-manifest.md` Core Layer Rules: "Hero scene root:
  `CharacterBody2D`"
- `docs/architecture/adr-0002-scene-autoload-structure.md`'s Autoload/Scene-Instanced
  Boundary table, which explicitly lists Hero as "Scene-instanced | Mission-only;
  recreated each mission"

Both `src/core/hero/hero.gd` (S4-03) and the broader Sprint 4 plan (S4-04 Hero
Movement) correctly implement Hero as a scene-instanced `CharacterBody2D`, matching
the authoritative sources — the ADR-0010 line appears to be a one-line wording slip
that was never actually load-bearing in that ADR's own Decision/Key Interfaces
sections (nothing there requires Autoload registration; the ADR's real requirement is
"no direct cross-system reference to TowerSystem," which holds regardless of node
type). Two independent code reviews (S4-01 SceneManager, S4-03 Hero Stat Resolution)
confirmed this same finding, treating it as non-blocking each time.

### Recommended fix

Correct `adr-0010-hero-tower-synced-class.md`'s Constraints section to read "Hero
System is scene-instanced (CharacterBody2D, per ADR-0002); Tower System is also
scene-instanced — no direct cross-system reference allowed" (or similar), removing
the incorrect Autoload claim. Low priority — purely a documentation correction, no
code changes needed.

### Resolution
- [x] ADR-0010 Constraints section corrected (2026-07-08) — now reads "Hero System is scene-instanced (`CharacterBody2D`, per ADR-0002); Tower System is also scene-instanced — no reverse dependency allowed."
- [x] This entry closed

---

## TD-adr-002 — Collision-layer convention needs a formal ADR before S4-09 depends on it (fixed)

**Logged**: 2026-07-03
**Fixed**: 2026-07-08
**Story**: Discovered during S4-04 (Hero Movement) code review
**Severity**: Advisory
**Area**: `src/core/hero/hero.gd` (class doc comment), future: `docs/architecture/`

### Gap

S4-04 established this project's first collision-layer convention — `COLLISION_LAYER_ENVIRONMENT = 1` (BLOCKED-cell tilemap collision shapes + tower physics bodies) and `COLLISION_LAYER_HERO = 2` — documented only in `hero.gd`'s class doc comment. The architecture specialist flagged this as genuine cross-system architectural surface (S4-09's mission scene assembly and tower placement collision will need to conform to it), and doc comments aren't discoverable by `/architecture-review` tooling or the control manifest generator, unlike a proper ADR.

### Recommended fix

Before S4-09 (mission scene assembly) begins, write a short ADR (or amend an existing spatial/physics-adjacent ADR, e.g. ADR-0002 or ADR-0005) capturing the collision-layer table as a documented, tooling-visible contract.

### Resolution
- [x] ADR written — `docs/architecture/adr-0015-collision-layer-convention.md` (Accepted). Also documents a real finding made while writing it: Layer 1 (environment) is currently unoccupied — no `CollisionShape2D`/`StaticBody2D` exists anywhere in `src/core/tower/`, and the BLOCKED-cell tilemap in `the_gap.tscn` is a pure visual `Node2D` with no collision shapes. Hero's `move_and_slide()` currently resolves against nothing in practice — a pre-existing gap, not introduced by this fix, but now visible instead of silently assumed.
- [x] `hero.gd`'s doc comment updated to reference ADR-0015 instead of being the sole source of truth
- [x] This entry closed

---

## TD-story-001 — Story 004 AC-05 and AC-06 describe mechanics that don't exist yet (fixed)

**Logged**: 2026-07-03
**Fixed**: 2026-07-08
**Story**: S4-06 Hero Combat Formula Integration (`production/epics/epic-02-core-combat/story-004-hero-combat-integration.md`)
**Severity**: Advisory
**Area**: Story authoring — `story-004-hero-combat-integration.md`, `design/gdd/hero.md`, `src/core/hero/hero.gd`

### Gap

Story 004 originally specified 4 acceptance criteria. Two do not correspond to shipped
behaviour or GDD intent:

- **AC-05** (monster armor reduction, `ARMOR_COEFFICIENT = 100` applied to hero-dealt damage)
  describes a mechanic that exists nowhere. `design/gdd/hero.md` Formula 5 and
  `design/gdd/damage-status.md` D4 both define armor reduction as applying only to
  **incoming damage the hero receives** — never damage the hero deals to monsters.
  `MonsterResource` has no armor field at all; the only monster-side mitigation is the
  `is_armored` tag, which is explicitly tower-only
  (`design/gdd/damage-status.md:136`: "hero damage is never reduced by the armored tag").
- **AC-06** (lifesteal overheal clamp) is Hero System's GDD-assigned responsibility
  (`design/gdd/damage-status.md:389`: "Hero owns lifesteal clamping... and overheal
  clamping; D&S owns the heal-amount calculation"), but `src/core/hero/hero.gd` has no
  `current_hp` field and no `hero_healed` subscriber yet.

Both were caught during `/dev-story` before any test code was written (see
`production/session-state/active.md` S4-06 extract), and the user approved descoping the
story to AC-03/AC-04 only.

### Recommended fix

1. AC-05: either strike it from Story 004 entirely, or re-author it against a real
   mechanic if a monster-vs-hero armor system is actually intended by design — route to
   game-designer for a decision.
2. AC-06: re-attempt once Story 008 (Hero Lifecycle, Death & Save) lands `current_hp` and
   a `hero_healed` subscriber on Hero. At that point AC-06 becomes testable as originally
   written.

### Resolution
- [x] AC-05 struck (2026-07-08, user decision) — removed entirely from `story-004-hero-combat-integration.md` rather than re-authored; it described a mechanic that never existed and contradicted this project's own GDDs.
- [x] AC-06 re-attempted and implemented (2026-07-08) — Story 008 had already landed `_current_hp`/`_max_hp` on Hero (checked, not assumed); the remaining gap was a `hero_healed` subscriber, added as `hero.gd::_on_hero_healed()`: applies the overheal clamp (`min(current_hp + amount, max_hp)`, GDD Formula 6) and emits `hero_health_changed` for Mission HUD observability. New `tests/unit/hero/hero_lifesteal_test.gd` (5 tests: within-missing-HP, exceeds-missing-HP clamp, full-HP no-op, signal emission, outside-COMBAT/INTERMISSION no-op).
- [x] This entry closed. Test evidence: hero suite 72/72 passing (up from 67), 0 orphans. Full regression: 650/650, 0 errors, 0 failures.

---

## TD-story-002 — Story 004 AC-04 claims a distinct BOSS multiplier that doesn't exist in shipped code (fixed)

**Logged**: 2026-07-03
**Fixed**: 2026-07-08
**Story**: S4-06 Hero Combat Formula Integration (`production/epics/epic-02-core-combat/story-004-hero-combat-integration.md`)
**Severity**: Advisory
**Area**: `src/core/damage_status/damage_status.gd:13,56` (`HERO_DAMAGE_BONUS_MULTIPLIER`)

### Gap

Story 004's Formula 4 sketch and its QA Test Cases section (AC-04 edge case) claim
`bonus_tier_multiplier: STANDARD=1.0, ELITE=1.5, BOSS=2.0` — i.e. BOSS should hit 2.0×
as hard as STANDARD. The shipped `damage_status.gd` applies a single flat
`HERO_DAMAGE_BONUS_MULTIPLIER = 1.50` constant to **any** `hero_bonus_tier > 0`
(`_on_hero_auto_attacked`, line 56) — ELITE and BOSS resolve identically (both 1.5×).
This was discovered while writing `tests/integration/hero/hero_combat_formula_test.gd`;
the test asserts the real shipped behaviour (135 damage for both tiers on a 90 base) and
documents the discrepancy inline rather than silently matching the story's stale claim.

### Recommended fix

Open design question for game-designer: is the flat 1.5× multiplier for any bonus tier
correct (i.e. the story's Formula 4 sketch is stale and should be corrected to match
code), or was a distinct, harder-hitting BOSS multiplier actually intended (i.e. the code
is missing a tier-2 case and needs a fix)? Whichever direction is chosen, update
`design/gdd/hero.md`'s Formula 4 section and either `damage_status.gd` or Story 004's
AC-04 text to match.

### Resolution
- [x] Design decision made (2026-07-08, user decision): the flat 1.5× multiplier is correct — no code change. Also confirmed the GDD itself already specified this correctly all along (`design/gdd/hero.md` Formula 4's `elite_boss_multiplier` range is `{1.0, 1.5}`, no distinct BOSS value) — only Story 004's own text and pseudocode sketch were stale/wrong.
- [x] GDD, code, and story text reconciled (2026-07-08) — `story-004-hero-combat-integration.md`'s AC-04, Implementation Notes Formula 4 pseudocode, and QA Test Cases all corrected to state the flat 1.5× explicitly (was previously claiming a distinct BOSS=2.0×). `damage_status.gd::_on_hero_auto_attacked()` doc comment updated to record this resolution and cite the GDD as the authoritative confirming source. No GDD change needed — it was already correct.
- [x] This entry closed.

---

## TD-hero-001 — Tower Affinity bonus not yet applied to Damage/Skill Power (fixed)

**Logged**: 2026-07-04
**Damage half fixed**: 2026-07-08
**Skill Power half — design specification complete**: 2026-08-25
**Skill Power half — GDScript implementation complete**: 2026-08-26
**Story**: S4-12 Hero Tower Affinity (`production/epics/epic-02-core-combat/story-005-hero-tower-affinity.md`)
**Severity**: Advisory
**Area**: `src/core/hero/hero.gd` (`_apply_tower_affinity_bonus`, `_on_attack_timer_timeout`, `activate_skill`, `_resolve_skill_hit`); `src/core/damage_status/damage_status.gd` (`_on_hero_skill_attacked`); design spec lives in `design/gdd/damage-status.md` Rule IX / Formula D7

### Gap

`design/gdd/hero.md` Formula 2 specifies that `tower_affinity_bonus` multiplies both
Damage and Skill Power:
```
effective_damage_final = effective_damage × (1 + tower_affinity_bonus)
effective_skill_power_final = effective_skill_power × (1 + tower_affinity_bonus)
```
Story 005 correctly implements `get_effective_stat(&"tower_affinity")` as a standalone,
fully-tested stat value (this was its stated scope), but no code path anywhere folds
that value into Damage or Skill Power. `_on_attack_timer_timeout()` (Story 003) reads
`get_effective_stat(&"damage")` directly with no `(1 + tower_affinity)` term. Skill Power
has no consumer yet either. Net effect: Tower Affinity currently has zero observable
gameplay impact — towers can be placed, the stat computes correctly, but nothing reads it.

### Recommended fix

A future story (likely a Hero Combat Formula Integration follow-up, or whichever story
first makes real use of Skill Power) must apply `(1 + get_effective_stat(&"tower_affinity"))`
to both the Damage value fed into `HeroAutoAttackEvent.base_damage` and to Skill Power
wherever it is first consumed.

### Resolution
- [x] Damage path updated to fold in tower_affinity (2026-07-08): `hero.gd:561`'s `_on_attack_timer_timeout()` now sets `payload.base_damage = get_effective_stat(&"damage") * (1.0 + get_effective_stat(&"tower_affinity"))`, matching GDD Formula 2 exactly.
- [x] Regression test added covering the combined effect (2026-07-08): `tests/unit/hero/hero_auto_attack_test.gd` — `test_attack_timeout_folds_tower_affinity_bonus_into_base_damage` (4 qualifying towers, 100 damage → 150 with the bonus applied) and `test_attack_timeout_zero_tower_affinity_leaves_base_damage_unchanged` (no towers → unchanged). Full hero suite 57/57 passing, 0 orphans; `tests/integration/hero` + `tests/unit/damage_status` re-run clean (1 pre-existing unrelated failure, `hero_lifecycle_test.gd` AC-13, `TD-hero-005` — confirmed unaffected by this change).
- [x] **Skill Power path — design specification complete 2026-08-25**: `design/gdd/damage-status.md` retrofitted with a new Rule IX ("Skill Damage Pipeline") and Formula D7 ("Hero Skill Damage Resolution") — `skill_power = effective_skill_power_final` (already includes `tower_affinity_bonus`, folded upstream by Hero System exactly paralleling the already-shipped Damage path) is multiplied by a new per-skill `skill_power_coefficient` field, then the same tier/crit steps Formula D2 already uses. `systems-designer` (formula validation) and `qa-lead` (acceptance-criteria validation) both consulted before writing, per this project's specialist-consultation rule for high-risk GDD sections. This closes the "no consumer is even specified" half of the original gap — Tower Affinity's Skill Power bonus now has a real, fully-specified formula to fold into.
- [x] **GDScript implementation complete (2026-08-26)**: `SkillResource` (`src/core/hero/skill_resource.gd`) gained `skill_power_coefficient: float` directly (not wrapped in a still-nonexistent `effect_data` sub-resource — `hero-skill-build.md`'s own amended Group 1 row confirms only this one field's existence/type was fixed by the downstream requirement, not the rest of `effect_data`'s shape). The 4 currently-authored skills (`assets/data/skills/*.tres`) got real placeholder coefficients (fireball 1.2, earth_slam 1.5, frost_nova 1.0, chain_lightning 0.8) — MVP/placeholder balance values, not a final content-authoring pass, flagged here so a future balance-calibration session knows to revisit them (same deferred-to-calibration pattern as `hero.md` OQ-9/Tower Affinity). `HeroSkillAttackEvent` (`src/foundation/event_bus/event_payloads/hero_skill_attack_event.gd`) and the `hero_skill_attacked` signal (`event_bus.gd`) added — `event-bus.md`'s catalogue already described both since 2026-08-25; only the actual `.gd` declaration was missing. `Hero.activate_skill()` now calls a new `_resolve_skill_hit()` which reuses `_select_target()`'s existing auto-attack target-priority logic (Rule IX leaves target resolution to Hero System, unspecified further) and emits one `HeroSkillAttackEvent` per cast that finds a target — a whiffed cast (no target in range) still consumes the cooldown but emits nothing, mirroring `_on_attack_timer_timeout()`'s identical no-target early return. `DamageStatus._on_hero_skill_attacked()` implements Formula D7 exactly (verified by hand against all 3 worked examples in the GDD) and Rule IX.9's explicit lifesteal exclusion (`HeroSkillAttackEvent` has no `hero_lifesteal_fraction` field at all).
- [x] This entry closed — GDScript implementation matches the design spec; new unit tests were NOT written this pass (not requested this turn — see `production/session-state/active.md` for why). A future session should add `hero_skill_attack_test.gd`/extend `damage_status` tests against the GDD's existing AC-36 through AC-45 before this is considered fully verified.

### New gap found while implementing this (not TD-hero-001, logged separately below): `damage-status.md` Rule VIII (Hero-Death Cleanup, documented as already shipped since 2026-07-15d) has no actual implementation in `damage_status.gd` — grep-confirmed zero `hero_died` subscription anywhere in that file. See `TD-damage-002` below.

---

## TD-hero-002 — Hero Skill System has no SkillDatabase/SkillResource pipeline (fixed)

**Logged**: 2026-07-04
**Fixed**: 2026-07-08
**Story**: S4-14 Hero Skill System (`production/epics/epic-02-core-combat/story-007-hero-skill-system.md`)
**Severity**: Advisory
**Area**: `src/core/hero/hero.gd` (`_skill_cooldowns`, `_ultimate_lookup`)

### Gap

No `SkillDatabase`/`SkillResource` data pipeline exists anywhere in the codebase —
`GameDataRegistry` only handles `MonsterResource` and `TowerPerkRegistry`. Story 007's
skill cooldowns and Ultimate combo lookup table are hardcoded, empty-for-MVP `Dictionary`
fields on `hero.gd` (`_skill_cooldowns: Dictionary[StringName, float]`, `_ultimate_lookup:
Dictionary[String, StringName]`), per the story's own stated MVP fallback. This is
consistent with skill effect authoring and passive pools already being out of this
story's scope — but real skill data (cooldowns, Ultimate combos) has nowhere to live
once actual skills are authored.

### Recommended fix

A future story should extend `GameDataRegistry` with a `SkillResource` type and a
`res://assets/data/skills/` loader, following the exact pattern already established for
`MonsterResource` (ADR-0009) — then migrate `hero.gd`'s hardcoded fields to read through
`GGameDataRegistry.get_skill_resource(skill_id)` instead.

### Resolution
- [x] `SkillResource` class authored (2026-07-08) — `src/core/hero/skill_resource.gd`: `skill_id`, `base_cooldown`, `validate()`. Cooldown data only, matching Story 007's own stated scope — no effect hook, since no system consumes `hero_skill_activated` anywhere yet (grep-confirmed skill effect resolution remains entirely unimplemented, out of scope here as it was for Story 007).
- [x] `GameDataRegistry` extended with a skills loader + `get_skill_resource()` (2026-07-08) — mirrors the `MonsterResource`/`TowerData` loader pattern exactly (`_load_skill_resources()`, does-not-abort validation policy). Also added `UltimateComboTable` (`src/core/hero/ultimate_combo_table.gd`) as a single-resource table mirroring `TowerPerkRegistry`'s pattern, since Ultimate combos have no natural per-entry identity the way skills/monsters/towers do — loaded via `_load_ultimate_combo_table()` / `get_ultimate_combo_table()`. Both scan `res://assets/data/skills/`; placeholder MVP content authored there (4 skills + 1 combo) purely to prove the pipeline end-to-end — real skill balance/design content is separate design work, not claimed as done here.
- [x] `hero.gd`'s `_skill_cooldowns`/`_ultimate_lookup` migrated to read from the registry (2026-07-08) — self-populate-if-empty at `_ready()`, mirroring MonsterManager/TowerSystem's established self-populate pattern (S5-01). `_inject_skill_data()` test seam preserved untouched — it overwrites both fields wholesale after self-populate runs, so all 13 pre-existing skill-system tests needed zero changes.
- [x] This entry closed. Test evidence: 12 new `game_data_registry_test.gd` tests (skill loader: valid/unknown/invalid/malformed/duplicate/missing-dir cases mirroring the tower blueprint loader's shape exactly; combo table: valid/unknown-key/malformed/missing cases) + 3 new `hero_skill_system_test.gd` tests proving self-populate actually wires through from the real registry (not just the test injection seam). Full hero suite 60/60 passing, 0 orphans. Full regression: 626/626 executed, 0 errors, 1 pre-existing unrelated failure (`hero_lifecycle_test.gd` AC-13, `TD-hero-005`), orphans confined to `game_data_registry_test.gd`'s pre-existing per-test-instance pattern (scaled proportionally with the 12 new tests added — not a new bug, same ratio as before this change).

---

## TD-hero-003 — hero_skill_cooldown_updated and hero_ultimate_activated unwired (fixed)

**Logged**: 2026-07-04
**Fixed**: 2026-07-08
**Story**: S4-14 Hero Skill System (`production/epics/epic-02-core-combat/story-007-hero-skill-system.md`)
**Severity**: Advisory
**Area**: `src/core/hero/hero.gd`

### Gap

`src/foundation/event_bus/event_bus.gd` documents two signals as Hero-System-owned:
`hero_skill_cooldown_updated(skill_slot, cooldown_remaining, cooldown_max)` (doc comment:
"Emitted by Hero System each second while a skill slot is on cooldown... Key subscribers:
Mission HUD") and `hero_ultimate_activated()` (doc comment: "Emitted by Mission HUD when
player presses the Ultimate button... Key subscribers: Hero System"). Neither is
implemented in Story 007 — there is no per-second cooldown broadcast loop, and Hero does
not subscribe to `hero_ultimate_activated` at all. Rules 8-12 and this story's ACs did not
require them, so this is a reasonable scope boundary, not an oversight, but Mission HUD's
cooldown-fill display and Ultimate-button handling both depend on this gap closing.

### Recommended fix

A future story (likely alongside Mission HUD skill-bar implementation) should: (1) add a
per-second cooldown broadcast — e.g. a repeating Timer or `_process()` check — emitting
`hero_skill_cooldown_updated` for any slot with `not timer.is_stopped()`; (2) subscribe to
`hero_ultimate_activated` and implement Ultimate effect resolution + cooldown start,
mirroring `activate_skill()`'s pattern.

### Resolution
- [x] Per-second `hero_skill_cooldown_updated` broadcast implemented (2026-07-08) — new `_cooldown_broadcast_timer` (repeating, 1s) in `hero.gd`, `_on_cooldown_broadcast_timeout()` emits for any of the 4 skill-slot timers currently running (slot indices 0-3) plus the Ultimate's own timer (`ULTIMATE_SLOT_INDEX = 4`, "same mechanism as skill buttons" per the GDD's own UI Requirements note).
- [x] `hero_ultimate_activated` subscription + Ultimate activation implemented (2026-07-08) — `_on_hero_ultimate_activated()`: no-op if no Ultimate is resolved (`_ultimate_id == &""`) or still on cooldown; otherwise starts a new `_ultimate_cooldown_timer` using `UltimateComboTable.get_cooldown_for_ultimate()` (GDD Rule 10: "The Ultimate has its own cooldown defined by its data entry" — required extending `UltimateComboTable` with an `ultimate_cooldowns: Dictionary` field, added as part of this fix). Confirmed Rule 12's CDR formula does NOT apply to the Ultimate — that rule is explicitly scoped to "active skill cooldowns" only, so the raw data-defined cooldown is used unmodified. Also implemented GDD Rule 10's EC: `_recompute_ultimate()` now unconditionally discards (`stop()`s) the Ultimate cooldown timer on every slot change, since "any active Ultimate cooldown timer is discarded" when the source combo changes. No effect resolution — same pre-existing gap as `activate_skill()` (no consumer of the resulting effect exists anywhere in the codebase yet).
- [x] Tests added for both (2026-07-08) — 7 new tests in `hero_skill_system_test.gd`: no-op with no resolved Ultimate, cooldown timer starts with the real registry-sourced value (against the real production `elemental_cataclysm` combo, not just an injected fixture), reactivation rejected while on cooldown, cooldown timer discarded on slot-change recompute, broadcast emits for an on-cooldown skill slot, broadcast does not emit when nothing is on cooldown, broadcast emits for the Ultimate slot index. Full hero suite 67/67 passing, 0 orphans.
- [x] This entry closed. `design/gdd/hero.md`'s UI Requirements table updated to reflect both signals now wired. Full regression: 633/633 executed, 0 errors, 1 pre-existing unrelated failure (`hero_lifecycle_test.gd` AC-13, `TD-hero-005`), orphans unchanged from before this fix (same pre-existing pattern, confined to `game_data_registry_test.gd`).

---

## TD-hero-004 — No registry preventing SaveRestorer `restore_order` collisions (fixed)

**Logged**: 2026-07-04
**Docs fixed**: 2026-07-08
**Story**: S4-07 Hero Lifecycle, Death & Save (`production/epics/epic-02-core-combat/story-008-hero-lifecycle.md`)
**Severity**: Advisory
**Area**: `src/foundation/save_persistence/save_persistence.gd`, `src/core/hero/hero.gd`

### Gap

Hero is the first real (non-test-stub) implementor of the ADR-0003 SaveRestorer
interface anywhere in the codebase, registering with `GSavePersistence.register(self, 30)`.
`restore_order` is a plain `int` passed at each call site with no central registry
or enum tracking which values are already in use by which system. Hero's ADR-0003
Decision Summary claims `restore_order = 30` runs "after Foundation (order 0-9) and
before Feature layer systems (order 50+)," but since Hero is currently the *only*
registered system, this ordering claim is unverified — there is nothing yet to
collide with, and nothing preventing a future system from accidentally reusing 30
or breaking the intended Foundation → Core → Feature ordering.

### Recommended fix

Before or alongside the next SaveRestorer implementor, add a central reference
(e.g. a comment block in `save_persistence.gd` or a small constants file) listing
every registered `restore_order` value and its owning system, so new registrations
can be checked for collisions at review time rather than discovered at runtime.

### Resolution
- [x] Central `restore_order` reference created (2026-07-08) — doc comment block in `save_persistence.gd` directly above `register()`, listing every registered value/system/layer/source, so a reviewer can check a new registration for collisions without grepping the codebase. Documents ADR-0003's reserved band (Foundation 0-9, Core 10-49, Feature 50+).
- [x] Hero's entry (30) documented there (2026-07-08)
- [x] Second (and third through fifteenth) SaveRestorer implementor's order verified against the reference (2026-09-02) — this entry's "still genuinely blocked, Hero remains the only registered implementor" note went stale as the project grew: a direct grep of every `RESTORE_ORDER` constant in `src/` found 15 real, live registrations today (Inventory=10, Mission Select=11, Menagerie=20, Defense Building=21, Tarot=22, Constellation=24, Crafting=25, Hero=30, Hero Skill Build=31, Equipment Forge=32, Building Upgrade=33, Tower Mastery=34, Encyclopedia=35, Tower Assembly=36, Hero Skill Tree=37) — all 15 values distinct, no collisions, all within ADR-0003's reserved Core band (10-49). The reference table this entry's original fix added to `save_persistence.gd` had itself gone stale (still listing only Inventory/Hero from 2026-07-08) — updated to list all 15.
- [x] This entry closed (2026-09-02).

---

## TD-data-001 — MonsterManager and TowerSystem have no production data loader (fixed)

**Logged**: 2026-07-05
**Fixed**: 2026-07-07
**Story**: S4-09 Assemble The Gap Mission Scene (`production/epics/epic-04-wave-manager/story-008-assemble-the-gap-mission-scene.md`)
**Severity**: High
**Area**: `src/core/monster/monster_manager.gd` (`_resource_table`), `src/core/tower/tower_system.gd` (`_tower_table`, `_player_gold`)

### Gap

Both `MonsterManager._resource_table` and `TowerSystem._tower_table` carry doc comments
claiming they are "Populated from disk in production" / "Injected in _ready() from disk;
overridable in tests" — but a full grep of both files (and everything that constructs
them) confirms **no code anywhere populates either dictionary outside unit tests.**
`MonsterManager._ready()` wires `_grid`/`_pathfinding` from Autoloads but never touches
`_resource_table`. `TowerSystem._ready()` wires `_grid`/`_pathfinding` the same way but
never touches `_tower_table`, and `_player_gold` has no production seed path either
(Resource Economy System is Not Started, per `systems-index.md`).

Net effect: **every mission scene assembled before this story would have silently
spawned zero monsters and placed zero towers** — `spawn_monster()` aborts immediately
via `if not _resource_table.has(monster_id): push_error(...); return null`, and
`place_tower()` aborts the same way via `if not _tower_table.has(blueprint_id)`. This
was invisible until now because every existing test manually injects these dictionaries
directly, and no story before S4-09 ever assembled a real scene that would have exercised
the production (non-test) path.

### Recommended fix

A dedicated follow-up story should:
1. Add a `MonsterManager._load_resource_table()` (or equivalent) that populates
   `_resource_table` from `GGameDataRegistry` for every monster_id referenced by the
   mission's loaded `WaveConfig` (or, more simply, exposes all cached monsters via a new
   `GameDataRegistry.get_all_monster_resources() -> Dictionary` and copies the whole
   table) — called from `MonsterManager._ready()` or `_on_wave_started()`.
2. Add an equivalent production loader for `TowerSystem._tower_table`, reading
   `TowerData` `.tres` blueprints from a `res://assets/data/towers/blueprints/` directory
   (mirroring `GameDataRegistry._load_monster_resources()`'s directory-scan pattern), and
   wire `_player_gold` to the (not-yet-built) Resource Economy System once it exists.
3. Once fixed, remove the scene-local DI-seam workaround this story added in
   `src/gameplay/missions/the_gap/the_gap.gd` (`_wire_monster_data()` /
   `_wire_tower_data()`), which populates both dictionaries directly from within the
   mission scene as a stopgap — every future mission scene should not need to repeat
   this workaround.

### Resolution
- [x] `MonsterManager` production resource-table loader implemented (2026-07-07, S5-01) — `GameDataRegistry.get_all_monster_resources()` added; `MonsterManager._ready()` self-populates `_resource_table` from it when empty (test-injection seam preserved via the same `is_empty()` guard)
- [x] `TowerSystem` production blueprint loader implemented (2026-07-07, S5-01) — `GameDataRegistry._load_tower_blueprints()` added, scanning the new `res://assets/data/towers/blueprints/` directory (mirrors the existing monster loader exactly); `TowerSystem._ready()` self-populates `_tower_table` the same way. `_player_gold` wiring to Resource Economy explicitly remained OUT OF SCOPE — that system is still Not Started; the existing `500`-debug-seed stopgap in `the_gap.gd` was kept, just re-commented to point at this entry instead of being silently duplicated by future mission scenes.
- [x] `the_gap.gd`'s scene-local DI-seam workaround removed (2026-07-07) — `_wire_monster_data()`/`_wire_tower_data()` deleted entirely; the scene's header doc comment (Deviation #2) updated to record the closure.
- [x] This entry closed (2026-07-07) — verified live via the Godot MCP bridge: `run_script` confirmed `MonsterManager._resource_table` and `TowerSystem._tower_table` are populated with the exact same keys as `GameDataRegistry`'s own cache (`forest_troll_elite`, `goblin_runner`, `goblin_warlord_boss`, `archer`) with zero scene-local wiring code. Ran a full SCOUT → WAVE_ACTIVE cycle afterward — a real monster spawned using registry-sourced `MonsterResource` data and pathed correctly, zero runtime errors. New test coverage: `tests/unit/game_data_registry/game_data_registry_test.gd` (9 new tests covering the tower blueprint loader — valid load, missing/malformed/invalid/duplicate cases, plus `get_all_monster_resources()`/`get_all_tower_blueprints()`), `tests/unit/monster/monster_spawn_test.gd` (1 new test confirming the production self-populate path against the real Autoload).

---

## TD-wave-002 — WaveManager never populated `_wave_spawn_entries` from the real loaded WaveConfig (found and fixed)

**Logged**: 2026-07-05
**Story**: S4-09 Assemble The Gap Mission Scene
**Severity**: Critical (found and fixed same-session — logged for traceability, not as an open item)
**Area**: `src/gameplay/wave_manager.gd` (`_enter_wave_active()`)

### Gap (now fixed)

`_wave_spawn_entries` was declared, and read by `_run_spawn_sequence()`, but was never
assigned from the real, loaded `WaveConfig` anywhere in production code — Story 006/007
wired real `WaveConfig` loading and `_build_composition_preview()` (the SCOUT/INTERMISSION
forewarning display) correctly, but never wired the actual per-wave entries used to drive
real spawning. Every real (non-test-injected) mission therefore spawned exactly 0 monsters
in actual gameplay, for every wave, always. Confirmed via a live headless run of the real
`mission_launched` -> real `WaveConfig` `.tres` -> real `WAVE_ACTIVE` chain, the first time
this codebase ever exercised that full path end-to-end (every prior test injects
`_wave_spawn_entries` directly).

### Fix applied

`_enter_wave_active()` now assigns `_wave_spawn_entries = _wave_config.wave_scripts[_wave_index - 1].entries`
when a real `_wave_config` with a script for the current wave index is loaded, leaving the
existing test-injection seam (direct assignment to `_wave_spawn_entries`) fully intact for
`_wave_config == null` cases (the entire pre-existing unit test suite). Verified via a live
headless re-run: real monsters now spawn, become visible, and are trackable through a full
mission after this fix.

### Resolution
- [x] Fixed in `wave_manager.gd::_enter_wave_active()` — 2026-07-05
- [x] Verified via live headless run (real spawn observed) — 2026-07-05
- [x] Full existing test suite re-run: 542/542 test cases, 0 errors, 1 pre-existing unrelated failure (see TD-hero-005), 0 new failures — 2026-07-05
- [x] Dedicated regression test added (2026-09-02) — `tests/integration/wave_manager/wave_manager_spawn_integration_test.gd::test_wave_active_entry_populates_spawn_entries_from_a_real_loaded_wave_config()`. Sets a real `_wave_config` (never touching the `_wave_spawn_entries` test-injection seam every other test in that file uses), transitions to `WAVE_ACTIVE`, and asserts `_wave_spawn_entries` matches the config's own wave-1 entries plus that both monsters actually spawned via the real `MonsterManager` in the same suite — closing the exact gap this recommendation named.
- [x] This entry closed (2026-09-02).

---

## TD-wave-003 — `_on_templates_ready()`'s `_phase_locked` guard discarded the real, nested `templates_ready` emission (found and fixed)

**Logged**: 2026-07-05
**Story**: S4-09 Assemble The Gap Mission Scene
**Severity**: Critical (found and fixed same-session — logged for traceability, not as an open item)
**Area**: `src/gameplay/wave_manager.gd` (`_on_templates_ready()`), `src/foundation/pathfinding/pathfinding_system.gd` (`_on_mission_phase_changed()` / `_build_all_templates()`)

### Gap (now fixed)

`PathfindingSystem` also subscribes to `mission_phase_changed` and, on `"SCOUT"`,
synchronously builds route templates and emits `templates_ready` — nested inside
`WaveManager._transition_to(Phase.SCOUT)`'s own `mission_phase_changed.emit()` call, i.e.
while `WaveManager._phase_locked` is still `true` (cleared only at the very end of
`_transition_to`, after the entire `mission_phase_changed` subscriber chain — including
PathfindingSystem's nested emit — has already run). `WaveManager._on_templates_ready()`'s
`if _phase_locked: return` guard discarded that real emission every time, so
`_templates_ready` never became `true` in real gameplay, and wave 1's
`_run_spawn_sequence()` awaited a `templates_ready` signal that had already fired and would
never fire again — permanently stalling every mission at 0 spawned monsters (stacked with
TD-wave-002 above; both had to be fixed together to get real spawning working). Confirmed
via the same live headless run that found TD-wave-002.

### Fix applied

Removed the `if _phase_locked: return` guard from `_on_templates_ready()`. Unlike
`_check_wave_clear_or_start_watchdog()` and `_on_hero_died()` (which legitimately defer via
`call_deferred()` when `_phase_locked` is true because they need to call `_transition_to()`
again), this handler only ever sets a boolean flag — there is no reentrancy hazard to guard
against, and no legitimate call path where discarding this signal is correct.

### Resolution
- [x] Fixed in `wave_manager.gd::_on_templates_ready()` — 2026-07-05
- [x] Verified via live headless run (real spawn observed after both TD-wave-002 and this fix) — 2026-07-05
- [x] Full existing test suite re-run: 542/542 test cases, 0 errors, 1 pre-existing unrelated failure (see TD-hero-005), 0 new failures — 2026-07-05
- [x] This entry closed (2026-09-02 — fix, verification, and regression were all already complete as of 2026-07-05; only this checkbox was never ticked).

---

## TD-damage-001 — `DamageStatusSystem` never instanced in `the_gap.tscn`; real Hero auto-attacks never damaged monsters (found and fixed)

**Logged**: 2026-07-06
**Story**: S4-09 Assemble The Gap Mission Scene — code review follow-up (Required Change 3: AC-6 real-combat test coverage)
**Severity**: Critical (found and fixed same-session — logged for traceability, not as an open item)
**Area**: `src/gameplay/missions/the_gap/the_gap.tscn`, `src/core/damage_status/damage_status.gd`

### Gap (now fixed)

`docs/architecture/adr-0002-scene-autoload-structure.md` documents `DamageStatusSystem`
as "Scene-instanced | Mission-only" — every mission scene must instance it alongside
Grid/MonsterManager/TowerSystem/Hero. `the_gap.tscn` never did. Net effect: `Hero`'s real
`hero_auto_attacked` emission (Epic 02, story-003) had no subscriber anywhere in the real
assembled scene — `DamageStatus._on_hero_auto_attacked()` never ran, `monster_damage_taken`
never emitted, and `MonsterManager._pass1_damage()` never applied any hero-dealt damage.
A real Hero auto-attacking a real spawned monster in this mission scene had **zero
gameplay effect on that monster's HP**, silently, in every real playthrough — this had
zero test coverage before now (the exact gap flagged by code review's Required Change 3),
and was undisclosed in this story's original QA evidence. Caught immediately by the new
AC-6 integration test (`mission_scene_the_gap_test.gd::
test_the_gap_real_hero_auto_attack_engages_real_spawned_monster_and_reduces_its_hp`):
the test asserted the monster's `current_hp` decreased after a real attack, and it did
not (`current_hp` stayed exactly at its pre-attack value).

### Fix applied

Added a `DamageStatus` node (`res://src/core/damage_status/damage_status.gd`) to
`the_gap.tscn`, mirroring the existing `MonsterManager`/`TowerSystem` node pattern — a
plain `Node` that self-wires entirely via its own `_ready()`/`_exit_tree()` EventBus
subscriptions, requiring no scene-local wiring in `the_gap.gd`.

### Resolution
- [x] `DamageStatus` node added to `the_gap.tscn` — 2026-07-06
- [x] Verified via the new AC-6 integration test (real monster HP decreases after a real Hero auto-attack) — 2026-07-06
- [x] Full regression suite re-run with no new failures introduced — 2026-07-06
- [x] This entry closed (2026-09-02 — fix, verification, and regression were all already complete as of 2026-07-06; only this checkbox was never ticked).

---

## TD-hero-005 — `hero_lifecycle_test.gd::test_ac13_damage_equal_to_current_hp_triggers_death_at_exactly_zero` fails (fixed)

**Logged**: 2026-07-05
**Fixed**: 2026-07-08
**Story**: Discovered during S4-09's full-suite regression re-run (not caused by S4-09 — `hero.gd` and this test file were not modified this session; failure reproduces in complete isolation)
**Severity**: Advisory
**Area**: `tests/integration/hero/hero_lifecycle_test.gd:83`

### Gap

`test_ac13_damage_equal_to_current_hp_triggers_death_at_exactly_zero` fails both as part of
the full suite and in complete isolation: `Expecting: '1' but was '2'` at line 83. Neither
`src/core/hero/hero.gd` nor this test file were touched during S4-09 (verified: this
session only Read `hero.gd`, never Write/Edit'd it). This is a pre-existing failure,
surfaced (not introduced) by this story's full-suite regression run — out of this story's
scope to fix (Epic 02/Hero is marked Complete; the fix belongs to whichever
agent/session owns Hero System follow-ups).

### Recommended fix

Investigate whether this is a genuine regression from a change made after Hero's last
green full-suite run, or an ordering/count-off-by-one issue in the test's own assertion at
line 83. Route to whichever agent owns Hero System maintenance.

### Resolution
- [x] Root cause identified (2026-07-08): a genuine duplicate-emission bug, not a test ordering/off-by-one issue. `hero.gd::_on_hero_damage_taken()` directly emitted `mission_phase_changed(..., "DEFEAT", ...)` on lethal damage — but `WaveManager._on_hero_died()` (Story 001, epic-04, shipped 2026-07-05) is ALSO connected to `hero_died` and ALSO calls `_transition_to(Phase.DEFEAT)`, which emits its own `mission_phase_changed("DEFEAT")` with proper `_phase_locked` reentrancy guards. Both fired for a single `hero_died` emission — exactly 2 instead of 1. The stale doc comment justifying Hero's own emission ("WaveManager's own DEFEAT transition logic is explicitly Out of Scope for its current implementation") was true when Hero's Story 008 was written (2026-07-04) but false the very next day once Wave Manager's Story 001 shipped real DEFEAT handling — never updated to match, so the duplicate went undetected until S4-09's full-suite regression run surfaced it.
- [x] Fixed (2026-07-08): removed Hero's own `mission_phase_changed` emission — WaveManager is the sole mission-phase FSM owner (matching ADR-0002's architecture), and Hero already correctly reacts to WaveManager's `mission_phase_changed("DEFEAT")` via its existing `_on_mission_phase_changed()` match arm, so no functional behavior is lost. Hero's direct `_phase = HeroPhase.DEAD` assignment (and the `hero_died` emission that triggers WaveManager's transition) are both kept, preserving AC-13's same-frame guarantee unconditionally rather than making it depend on WaveManager's internal locking state. Also removed the now-fully-dead `_last_phase_string` field (existed solely to feed the removed emission's `previous_phase` argument — grep-confirmed no other reader anywhere).
- [x] This entry closed. Test evidence: `tests/integration/hero` 49/49 passing, 0 orphans (up from 1 known failure). Full regression: 633/633 executed, 0 errors, **0 failures** — this was the last remaining known pre-existing failure; the suite is now fully green.

---

## TD-perf-001 — "The Gap" mission scene FPS / draw-call / memory measurement never captured (AC-8, accepted non-blocking debt) (fixed)

**Logged**: 2026-07-06
**Fixed**: 2026-07-07
**Story**: S4-09 Assemble The Gap Mission Scene (`production/epics/epic-04-wave-manager/story-008-assemble-the-gap-mission-scene.md`)
**Severity**: Advisory
**Area**: `src/gameplay/missions/the_gap/the_gap.tscn` / `the_gap.gd` — no code area, a measurement gap

### Gap

Story 008's AC-8 requires real FPS, draw-call count, and memory-usage measurement of
the assembled mission scene under a rendered (non-headless) run with the full 6-wave
mission, real Hero movement input, and multiple simultaneous monsters on screen. The
Godot MCP server's runtime tools (`run_project`, `simulate_input`, `take_screenshot`,
`get_debug_output`) were not actually invocable in the agent session that produced this
story's QA evidence, and headless mode has no rendering context (`Performance.get_monitor
(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` requires one). No FPS/draw-call/memory
numbers were fabricated or estimated in place of a real measurement — this is a genuine,
disclosed measurement gap, not a silently skipped AC.

### Decision

Accepted as tracked, non-blocking technical debt for Story 008's closure. All other
Story 008 ACs (phase progression, real spawning, real Hero combat, tower placement,
the full 6-wave loop to MISSION_COMPLETE, DEFEAT) are verified via real headless engine
execution and are not affected by this gap. This entry exists so the still-open
performance measurement is not lost once the story closes.

### Recommended fix

A short manual/windowed session (or a working MCP `run_project` + `simulate_input` +
`take_screenshot` + `get_debug_output` pipeline, once reachable from an agent context)
to capture real FPS/draw-call/memory numbers against the Technical Preferences budgets
(60 FPS / 16.67ms frame budget, 200 draw calls, 1 GB memory ceiling) and a human
visual/feel pass over monster pathing and Hero movement responsiveness.

### Resolution
- [x] Real FPS/draw-call/memory numbers captured (2026-07-07) via the Godot MCP bridge, now reachable in this environment — `run_project` on `the_gap.tscn`, `run_script` sampling `Performance` monitors over 120 frames during WAVE_ACTIVE (Wave 1/6, 0–2 monsters active, Hero present, one tower absent):
  - **FPS**: 60 min/avg/max (vsync-capped — no drops observed)
  - **Frame time**: p50 16.79ms, p99 16.87ms — at the 16.67ms budget edge, consistent with a clean 60 FPS cap, not a warning sign on its own
  - **Draw calls**: **387 avg, flat regardless of monster count (0 vs 2 monsters made no difference)** — this is **~1.9× over the 200 draw-call budget**, and the flatness indicates it's baseline scene cost (grid rendering + HUD + Hero), not something that scales with entity count. This is worse than a scaling concern — the budget is already blown before wave content contributes meaningfully.
  - **Memory**: 46.7 MB static — well under the 1GB ceiling, no concern
- [x] Numbers checked against Technical Preferences budgets (2026-07-07): FPS/frame-time/memory all PASS; **draw calls FAIL** (387 vs 200 budget)
- [x] This entry closed (2026-07-07) — **but a new, more specific gap is opened as a result**: see the new `TD-render-001` entry below. This session's measurement only covers Wave 1 with 0–2 monsters, not the full 6-wave mission with peak simultaneous monster count (AC-8's original ask) — the draw-call finding is severe enough at this low load that peak-load numbers are likely worse, not better, but were not directly measured. A human visual/feel pass over Hero movement responsiveness (part of AC-8) was also not performed — this was a headless-bridge performance sample, not a played session.

---

## TD-workflow-001 — New `class_name` files require a manual global-class-cache update outside the editor (fixed)

**Logged**: 2026-07-07
**Fixed**: 2026-07-08
**Story**: Discovered while implementing S5-02 (MissionResource)
**Severity**: Advisory (workflow friction, not a code defect)
**Area**: `.godot/global_script_class_cache.cfg` — Godot engine-level project cache, not project source

### Gap

When a brand-new `class_name` GDScript file is added, a bare `godot --headless` **game-mode**
boot (as used by `run_project` in this environment, and previously by headless CI test runs
per this project's session history) does **not** rescan the project for new `class_name`
declarations — it trusts the existing `.godot/global_script_class_cache.cfg` as-is. Only the
Godot **editor** performs that rescan automatically (via its file-system watcher / import
pipeline). Since editor launches are restricted to explicit user request in this environment
(agent-driven sessions use headless tooling only), a new class remains unresolvable
("Could not find type 'X' in the current scope" / "Failed to instantiate an autoload, script
... does not inherit from 'Node'" if the new class is referenced by an Autoload) until the
cache is updated by some other means.

This has now been hit **three times** across this project's history (this session's
MissionResource addition; at least one prior session per the `active.md`/session-log
reference to "a Godot class-cache rescan (new class_name declarations weren't indexed for
headless test runs)").

### Fix applied this session (workaround, not a root-cause fix)

Manually appended the missing entry to `.godot/global_script_class_cache.cfg`, matching the
exact format of adjacent entries (`{"base": &"Resource", "class": &"MissionResource", "icon":
"", "is_abstract": false, "is_tool": false, "language": &"GDScript", "path":
"res://src/core/mission_resource.gd"}`), inserted in alphabetical order. This is a direct,
surgical edit to a generated/cache file — normally something to avoid hand-editing, but the
alternative (no working boot) was worse, and the entry format is simple and low-risk to
replicate correctly.

### Recommended fix

1. **Immediate**: whenever a new `class_name` file is added going forward, check whether
   `.godot/global_script_class_cache.cfg` already contains it before assuming `run_project`
   will work — if not, either ask the user to briefly open the real editor once (which
   rebuilds the cache correctly and durably), or manually add the entry as done here.
2. **Process fix**: consider documenting this explicitly in `tests/README.md` or a new
   troubleshooting note in `docs/engine-reference/godot/`, so this isn't rediscovered from
   scratch a fourth time.
3. **Root cause investigation** (optional, lower priority): confirm whether a specific Godot
   CLI flag (e.g. `--headless --editor --quit`, if that combination is valid in 4.6.2) can
   trigger the same rescan without a full interactive editor session — would make this a
   fully agent-automatable fix instead of a manual cache edit or a user-mediated editor launch.

### Resolution
- [x] Manual cache-entry workaround applied for `MissionResource` (2026-07-07) — unblocked this session's work
- [x] Documented in `tests/README.md` (already present from the 2026-07-07 session; updated 2026-07-08 with the confirmed CLI-flag fix below)
- [x] CLI-flag root-cause investigated and CONFIRMED (2026-07-08): `godot --headless --editor --quit` performs a full editor-mode rescan (`update_scripts_classes` step) and rewrites `.godot/global_script_class_cache.cfg` with **no GUI window opened** — fully agent-automatable. Verified live: created a throwaway `class_name` probe script, confirmed absent from cache, ran the command, confirmed the class appeared in the cache (`update_scripts_classes | TdWorkflow001ProbeClass` in the log output); deleted the probe script, ran the command again, confirmed the stale entry was pruned. This upgrades the fix from "workaround" to a real root-cause resolution — no manual cache-editing or interactive editor session is needed going forward.
- [x] This entry closed

---

## TD-render-001 — Draw call budget exceeded at baseline, before wave content scales up (found and fixed)

**Logged**: 2026-07-07
**Story**: Discovered while closing `TD-perf-001`; fixed same session
**Severity**: High (real budget violation, not just an unmeasured gap) — resolved
**Area**: `src/gameplay/missions/the_gap/grid_visual.gd`

### Gap

A live-engine measurement of "The Gap" during WAVE_ACTIVE (Wave 1/6, 0–2 monsters active) recorded **387 draw calls per frame, flat regardless of monster count** — vs. the 200 draw-call budget in `.claude/docs/technical-preferences.md`. The flatness (0 monsters and 2 monsters both measured exactly 387) strongly suggests this is baseline scene cost — likely the `GridVisual` node rendering the 16×12 grid without batching, plus HUD `Label`/`PanelContainer` overhead — rather than a per-entity cost that would scale with wave content. This means the budget is already exceeded before any tower placement, stacked-sprite monster rendering, or peak-wave monster count contributes anything. Sprint 1's `TD-t1`/ADR-0013 (shared per-class atlas strategy) addressed *entity stacking* draw-call cost specifically and was verified `✅ Mitigated` at "~40 DC estimated at MVP entity counts" — that estimate did not account for whatever is producing this 387-call baseline, since it's present even at 0 entities.

### Root cause CONFIRMED (2026-07-07)

`src/gameplay/missions/the_gap/grid_visual.gd::_draw()` calls `draw_rect()` **twice per cell**
(once filled with the cell-type color, once as a 1px black outline) in a nested loop over the
full 16×12 = 192-cell grid — 384 `draw_rect()` calls every redraw, matching the measured 387
almost exactly (the remaining ~3 are HUD/hero). This is a deliberate, documented choice
(`grid_visual.gd`'s own header comment: "Deliberately NOT a TileMap/TileSet node... a simple
`_draw()`-based colored-rect renderer avoids that [Godot 4.4-4.6 API] risk entirely at zero
gameplay cost") — the risk-avoidance reasoning was sound (TileMap/TileSet did have real
post-cutoff API changes to verify), but "zero gameplay cost" undersold the real rendering cost:
per-cell `draw_rect()` calls with varying fill colors and a separate outline primitive don't
batch into a single draw call the way a uniform-material approach would.

### Recommended fix

1. Replace the per-cell double-`draw_rect()` loop with one of: (a) a single pre-rendered texture
   (draw the grid once into an `Image`/`ImageTexture` at `configure()` time, display via one
   `Sprite2D` — the grid is static per-mission, never needs per-frame redraw); (b) a
   `MultiMeshInstance2D` with per-instance color (one draw call for all filled cells, another
   for all outlines — 2 draw calls total instead of 384); (c) revisit `TileMapLayer` now that
   `docs/engine-reference/godot/VERSION.md`'s 4.4-4.6 API risk items have mostly been verified
   this sprint (S3-07 annotation pass) — the original risk-avoidance reasoning may no longer
   apply as strongly.
2. Re-measure after any fix; confirm draw calls drop well under 200 at 0 entities, then
   re-measure again at peak wave load (6 waves, max simultaneous monster count) to confirm the
   full original AC-8 ask (Story 008) is finally satisfied — this session's measurement only
   covered Wave 1 with 0–2 monsters.

### Resolution
- [x] Root cause identified (2026-07-07) — `grid_visual.gd::_draw()`'s per-cell double-`draw_rect()` loop, confirmed via direct source reading, not just inference
- [x] Fix applied and re-measured at 0 entities (2026-07-07) — replaced the per-cell `_draw()` loop with a one-time pre-rendered `Image`/`ImageTexture` built at `configure()` time (grid is static per-mission, never needs per-frame redraw), displayed via a single `draw_texture()` call. Border outlines approximated by pre-blending the alpha=0.25 black outline into solid border-pixel colors (`base_color.lerp(Color.BLACK, 0.25)`), since `Image.fill_rect()` writes opaque final pixels rather than alpha-compositing at render time the way the original `draw_rect()` did. **Result: 387 → 4 draw calls (96.7% reduction)**, verified live via the Godot MCP bridge — `Performance.get_monitor(RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` sampled over 60 frames, min=max=4. FPS unaffected (59-60). Visual output confirmed identical via screenshot comparison (grid colors, cell borders, SPAWN/GOAL/PATH/PLACEABLE/BLOCKED all rendering correctly).
- [x] Re-measured through a live SCOUT→WAVE_ACTIVE transition (2026-07-07) — confirmed the fix holds during actual gameplay, not just a static frame: monster spawned and pathed correctly, grid rendering unchanged, zero runtime errors.
- [x] This entry closed (2026-07-07). **Note**: this session's re-measurement, like the original, only covered Wave 1 with 0–2 monsters — the original AC-8 ask (Story 008: full 6-wave mission, peak simultaneous monster count) still hasn't been directly measured. Given the grid-rendering cost (this entry's entire subject) is now fixed and provably flat at 4 draw calls regardless of grid content, and Sprint 1's `TD-t1`/ADR-0013 already verified entity-stacking cost separately (~40 DC estimated at MVP entity counts), there's no longer a known mechanism that would cause peak-wave draw calls to spike unexpectedly — but this remains an assumption, not a direct peak-load measurement, until someone runs one.

---

## TD-path-002 — GDD OQ-6's `path_invalidated` monster-refresh-burst framing is stale/inaccurate (fixed)

**Logged**: 2026-07-06
**Fixed**: 2026-07-07
**Story**: S4-10 100-Agent Pathfinding Performance Stress Test
**Severity**: Advisory (documentation accuracy, not a code defect)
**Area**: `design/gdd/pathfinding.md` OQ-6; `production/qa/reference-hardware.md`'s
"Path-invalidation frame note"

### Gap

`design/gdd/pathfinding.md` OQ-6 and `production/qa/reference-hardware.md` (line ~35) both
describe the "100+ simultaneous agents" performance scenario as: "When `path_invalidated`
fires, up to 150 monsters simultaneously call `get_path()` to refresh their local path
copies." This mechanism does **not** exist in shipped code.
`src/core/monster/monster_manager.gd::_on_path_invalidated()` (line 367) is an explicit no-op:

```gdscript
func _on_path_invalidated(_affected_cells: Array) -> void:
    # Dead code at MVP (Grid locks tower writes during WAVE_ACTIVE). Kept for post-MVP.
```

Grid's `ACTIVE_READONLY` write lock during `WAVE_ACTIVE` (`src/foundation/grid/grid.gd`,
`_on_mission_phase_changed`) means tower placement/removal cannot occur mid-wave, so
`path_invalidated` never fires during `WAVE_ACTIVE` at MVP — there is no monster-side refresh
burst to measure. The only real `find_path()` call site is `monster_manager.gd:286`, once per
monster **at spawn**, not on `path_invalidated`.

Additionally, real wave data (`assets/data/waves/the_gap_waves.tres`) shows every
`WaveSpawnEntry.pre_delay` is 2.0–5.0 seconds, and `src/gameplay/wave_manager.gd::_run_spawn_sequence()`
awaits `get_tree().create_timer(entry.pre_delay).timeout` between spawn entries — so even the
*spawn* burst this discrepancy was corrected to (S4-10's AC-3) does not occur as "150 in one
frame" in any shipped wave data; spawns are staggered several seconds apart in practice.

### Recommended fix

Update `design/gdd/pathfinding.md` OQ-6 and `production/qa/reference-hardware.md`'s
"Path-invalidation frame note" to either (a) describe the real spawn-burst scenario
(`monster_manager.gd:286`, once per monster at spawn, real cadence staggered by
`WaveSpawnEntry.pre_delay`) instead of the non-existent `path_invalidated` refresh burst, or
(b) explicitly mark the `path_invalidated` monster-refresh mechanism as a documented post-MVP
feature gap alongside `_on_path_invalidated()`'s own doc comment, so future readers of the GDD
don't re-derive a test scenario against dead code.

### Resolution
- [x] `design/gdd/pathfinding.md` OQ-6 updated to reflect the real spawn-at-cadence trigger — already done in a prior session (S4-10): OQ-6's own text (line 483) correctly documents the real resolution, and the original stale "150-monster simultaneous refresh" text was preserved but explicitly marked superseded with a cross-reference to this entry (line 485), rather than deleted — good practice for historical traceability.
- [x] `production/qa/reference-hardware.md`'s path-invalidation frame note corrected (2026-07-07) — this was the one piece still using the stale framing; rewrote it to match the corrected framing already established in `pathfinding.md`, with the same real numbers (150-spawn burst = 0.164ms, S4-10) and explicit cross-references both ways.
- [x] This entry closed (2026-07-07)

---

## TD-test-003 — `tests/gdunit4_runner.gd` calls a nonexistent `GdUnitTestCIRunner` method (fixed)

**Logged**: 2026-07-06
**Fixed**: 2026-07-07
**Story**: S4-10 100-Agent Pathfinding Performance Stress Test (discovered while attempting to
run the documented headless test invocation)
**Severity**: Advisory (test infrastructure, devops-engineer territory — not fixed as part of
this story)
**Area**: `tests/gdunit4_runner.gd`

### Gap

`tests/README.md`'s documented headless invocation is:

```
godot --headless --script tests/gdunit4_runner.gd
```

Running this against the project's pinned engine (`Godot_v4.6.2-stable_win64.exe`) fails
immediately:

```
SCRIPT ERROR: Invalid call. Nonexistent function 'run_tests' in base 'Node (GdUnitTestCIRunner)'.
   at: _init (res://tests/gdunit4_runner.gd:12)
```

`tests/gdunit4_runner.gd` calls `instance.run_tests()` on a `GdUnitTestCIRunner` instance, but
that method does not exist on the class in the currently-installed gdUnit4 addon version
(`addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd`). The addon does ship a working CLI
entry point at `addons/gdUnit4/bin/GdUnitCmdTool.gd`, invoked as:

```
godot --headless --path <project> -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

This alternate invocation was verified working during S4-10 (used to produce this story's real
profiler numbers) — `tests/gdunit4_runner.gd` itself was not touched or fixed, since fixing CI
test-runner infrastructure is outside this story's scope (devops-engineer territory).

### Recommended fix

Either update `tests/gdunit4_runner.gd` to delegate to `GdUnitCmdTool.gd`'s working code path,
or replace `tests/README.md`'s documented invocation with the `GdUnitCmdTool.gd` command above,
and verify `.github/workflows/tests.yml` uses whichever invocation is actually functional (CI
may currently be silently broken or using a different path than `tests/README.md` documents —
worth auditing as part of this fix).

### Resolution
- [x] `tests/gdunit4_runner.gd` fixed (2026-07-07) — root cause was calling a nonexistent `run_tests()` method directly. Traced `GdUnitTestCIRunner`'s actual contract via source (`addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd` + `GdUnitTestSessionRunner.gd`): it self-drives entirely from `OS.get_cmdline_args()` once added to the scene tree (`_ready()` → `init_runner()` → `init_gd_unit()` → parses args, discovers tests, runs them). Fixed to match `GdUnitCmdTool.gd`'s exact working pattern: `root.add_child(runner)`, nothing else. New usage requires passing `-a res://tests --ignoreHeadlessMode` after `--`.
- [x] `tests/README.md` updated (2026-07-07) — corrected the invocation, and relabeled the section from "Headless (CI)" to "Headless (local/manual)" since CI never used this script.
- [x] `.github/workflows/tests.yml` audited (2026-07-07) — confirmed CI uses the `MikeSchulze/gdUnit4-action` GitHub Action directly, entirely independent of `tests/gdunit4_runner.gd`. CI was never affected by this bug.
- [x] This entry closed (2026-07-07) — **caveat**: the actual CLI invocation could not be executed live in this environment (no `godot` binary reachable from this shell, and the Godot MCP bridge's `run_project`/`run_script` tools operate on a live scene-tree bridge, not a raw `--script` main-loop invocation, so they can't exercise this specific launch mode). The fix's correctness is based on directly matching `GdUnitCmdTool.gd`'s proven-working pattern (confirmed via source trace, not just inference) rather than live execution. **Recommend a human run the documented command once locally to fully close the loop** — same category of caveat as the smoke check's sandbox launch-path quirk.

---

## TD-test-005 — `tests/gdunit4_runner.gd` silently ran zero tests despite TD-test-003's fix (fixed)

**Logged**: 2026-07-31
**Fixed**: 2026-07-31
**Story**: Live-verification pass on manual/automated test evidence, prompted by the user
double-checking whether prior test claims were real — this was the first time the script was
actually executed end-to-end (with a real `godot` binary reachable from the shell) since
TD-test-003's fix, which closed itself with an explicit caveat that it hadn't been.
**Severity**: Medium — masked, not a regression from TD-test-003's fix, which was itself
correct against the engine version it was written against. CI was never affected (uses the
`MikeSchulze/gdUnit4-action` GitHub Action directly, per TD-test-003's own audit).
**Area**: `tests/gdunit4_runner.gd`

### Gap

Running the documented invocation exactly as written —
`godot --headless --script tests/gdunit4_runner.gd -- -a res://tests --ignoreHeadlessMode` —
printed `GdUnitTestCIRunner`'s help text and exited 0 without running a single test. No error,
no warning; looked identical to a deliberate no-op invocation.

Root cause, confirmed via a throwaway diagnostic script printing both accessors: as of
Godot 4.6.2, `OS.get_cmdline_args()` no longer includes arguments passed after the `--`
separator — only `OS.get_cmdline_user_args()` does. This is a genuine post-cutoff engine
behavior change (see `docs/engine-reference/godot/VERSION.md`'s Knowledge Gap Warning) that
had not been previously tracked anywhere in this project's API-tracking table.
`GdUnitTestCIRunner.get_cmdline_args()` (in
`addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd`) calls `OS.get_cmdline_args()` unless
its `_debug_cmd_args` override is set, so `tests/gdunit4_runner.gd`'s post-TD-test-003 version
— which only did `root.add_child(runner)` and relied on the runner reading real cmdline args —
received an effectively empty argument list every time, regardless of what was passed after
`--`. `CmdArgumentParser.parse()` treats an argument list with no recognizable options as
"show help and exit 0," which is exactly what was observed.

A second, compounding quirk found while fixing this: `CmdArgumentParser.parse()`
(`addons/gdUnit4/src/cmd/CmdArgumentParser.gd`) discards every argument up to and including
the first one containing the literal substring `"GdUnitCmdTool.gd"` before it starts reading
options — normally satisfied for free by `OS.get_cmdline_args()` including the `--script`
path. Feeding it `OS.get_cmdline_user_args()` directly (with no such token present) also
silently produces zero parsed commands.

### Fix

`tests/gdunit4_runner.gd` now reads `OS.get_cmdline_user_args()` directly, prepends a
`"GdUnitCmdTool.gd"` sentinel token to satisfy `CmdArgumentParser`'s skip-until logic, and
sets the combined array on the runner's `_debug_cmd_args` property (via `.set()`, since the
property isn't otherwise exposed) before adding it to the tree.

### Resolution
- [x] Root cause confirmed live (2026-07-31) — reproduced with a throwaway script printing
  `OS.get_cmdline_args()` vs `OS.get_cmdline_user_args()` side by side against the pinned
  `Godot_v4.6.2-stable_win64.exe` binary; only the latter contained the post-`--` arguments.
- [x] Fixed and live-verified (2026-07-31) — `godot --headless --script tests/gdunit4_runner.gd
  -- -a res://tests -c --ignoreHeadlessMode` now runs the real suite: 1765 test cases, 183
  suites, 0 errors, 0 failures, 0 flaky, 185 orphans (pre-existing, unrelated), exit code 101
  (orphan-warning code, not a failure). Also re-verified against a small subset
  (`res://tests/unit/grid`, exit code 0) to confirm normal-path exit codes still work correctly.
- [x] This entry closed (2026-07-31) — unlike TD-test-003, this fix carries no live-execution
  caveat: it was run to completion twice, against both a subset and the full suite, on the
  actual pinned engine binary in this environment.

---

## TD-project-001 — `project.godot`'s main scene setting was silently never active (fixed)

**Logged**: 2026-07-10
**Fixed**: 2026-07-10
**Story**: Discovered while debugging the user's report "every time I try to run the project,
it keeps telling me no scene has been defined" — the first time anyone actually tried to boot
the compiled game outside the editor/MCP tooling for a real playtest session.
**Severity**: High — silently blocked the game from running via the editor's Play button, any
headless run, and any exported build, despite every other verification path (unit/integration
tests via gdUnit4, live Godot MCP scene manipulation) working correctly and masking the bug for
the project's entire history.
**Area**: `project.godot` `[application]` section

### Gap

`project.godot`'s `[application]` section declared:
```
config/run/main_scene="res://src/gameplay/missions/the_gap/the_gap.tscn"
config/run/flush_stdout_on_print=true
```
Both keys have an erroneous extra `config/` prefix. Godot's real, engine-checked settings for
these are `application/run/main_scene` and `application/run/flush_stdout_on_print` — **not**
`application/config/run/*`. The file as written created a harmless, unused bogus setting
(`application/config/run/main_scene`) while the actual setting Godot's boot logic reads
(`application/run/main_scene`) was always empty. Confirmed directly via a diagnostic script
querying `ProjectSettings.has_setting()`/`get_setting()` for both key paths: the bogus key
held the correct value, the real key was `''`.

Net effect: `godot --headless --path .` (and, by the same code path, the editor's Play button
and any exported build) always printed `Error: Can't run project: no main scene defined in the
project.` and refused to boot — a total, silent blocker on ever actually playing the compiled
game, for the entire project history. This went undetected because every verification method
used throughout development sidesteps this exact boot path: gdUnit4 test runs use `-s
<script>` (script mode, never checks main_scene), and the Godot MCP bridge's `run_project`/
`attach_project` tools operate on a live editor-injected bridge, not the "run main scene"
boot path either.

### Recommended fix

Remove the erroneous `config/` prefix from both keys.

### Resolution
- [x] `project.godot` fixed (2026-07-10) — `config/run/main_scene` → `run/main_scene`,
  `config/run/flush_stdout_on_print` → `run/flush_stdout_on_print`. Confirmed via the same
  diagnostic script: `application/run/main_scene` now correctly resolves to the real scene
  path; the bogus `application/config/run/main_scene` setting no longer exists.
- [x] Verified the project actually boots (2026-07-10) — `godot --headless --path .` now runs
  continuously (process stays alive under a timeout wrapper instead of exiting with the "no
  main scene" error) instead of failing immediately.
- [x] Confirmed no other `config/*` keys in the same section are similarly misplaced — `config/name`,
  `config/description`, `config/version`, `config/features` are all correctly namespaced as-is
  (only the two `run/*` keys had the bogus prefix).
- [x] Full regression re-run (2026-07-10): 650/650 executed, 0 errors, 0 failures — confirmed
  this config fix introduces no regressions.
- [x] This entry closed.

## TD-inv-001 — Inventory's `restore_save_data()` lacks defense-in-depth range/collision validation on restored data (fixed)

**Logged**: 2026-07-15
**Fixed**: 2026-07-31
**Story**: Story 001 (Slot & Stack Model, Epic 03) — flagged during `/code-review`
**Severity**: Low — no known reachable path produces the malformed condition today (the only writer of save data is `get_save_data()` itself, which always emits well-formed output); this is defense against a hand-edited or future-corrupted save file, matching a risk ADR-0016 itself calls out in its Consequences > Negative section as needing unit-test coverage.
**Area**: `src/core/inventory/inventory.gd`

### Gap

`restore_save_data()` validates every field's *type* (int, bool, String, Dictionary) before mutating state, but does not validate *range or cross-field consistency*:
- `quantity` is not checked against `STACK_CAP_STACKABLE`/`STACK_CAP_UNIQUE`, nor against being negative.
- `instance_id` is not checked to be `>= -1`, nor checked for uniqueness across slots, nor checked to be `< next_instance_id` — a malformed save could restore two slots with the same `instance_id`, or an `instance_id` at or above the restored counter, producing a future collision the moment a new unique item is added.

Separately, `add_stackable()` has no `quantity <= 0` guard — a zero or negative input quantity is a no-op that returns the input value unchanged as "leftover," which is a confusing (negative) contract for callers rather than an explicit rejection.

### Recommended fix

- Add `quantity >= 0` and `instance_id >= -1` bounds checks to `restore_save_data()`'s per-slot validation, plus a duplicate/out-of-range `instance_id` check against the restored `next_instance_id`.
- Add an explicit `if quantity <= 0: push_error(...); return quantity` guard at the top of `add_stackable()`.
- Add unit tests locking down both behaviors (currently untested per the QA testability review accompanying this story's `/code-review`).

### Resolution
- [x] `add_stackable()` guard already closed via `TD-inv-006` (2026-07-31) — same fix, tracked under that entry.
- [x] `restore_save_data()` bounds/collision checks added (2026-07-31): `quantity >= 0`; per-slot cap check against `STACK_CAP_UNIQUE`/`STACK_CAP_STACKABLE` depending on whether `instance_id == -1`; `instance_id >= -1`; duplicate-`instance_id`-across-restored-slots rejection; `instance_id >= next_instance_id` collision rejection.
- [x] 6 new tests added to `tests/unit/inventory/slot_stack_model_test.gd` (negative quantity, instance_id below -1, duplicate instance_ids, instance_id at/above next_instance_id, unique-slot quantity over cap, stackable quantity over cap) — each tampers with real `get_save_data()` output rather than hand-building malformed data, matching this file's own existing convention.
- [x] Live-verified: full project regression 1812/1812, 0 errors, 0 failures.
- [x] This entry closed.

## TD-inv-002 — Tab categorization test gaps + story-type header mismatch (fixed)

**Logged**: 2026-07-15
**Fixed**: 2026-07-31
**Story**: Story 002 (Tab Categorization, Epic 03) — flagged during `/code-review`
**Severity**: Low — cosmetic/test-completeness only, no known reachable defect.
**Area**: `src/core/inventory/inventory.gd` (`get_tab_for_item_type()`), `tests/unit/inventory/tab_categorization_test.gd`, `production/epics/epic-03-core-economy/story-002-tab-categorization.md`

### Gap

1. `get_tab_for_item_type()`'s `push_error()` call on an unknown `item_type` is unasserted — the test suite only checks the `&""` return value, not that the "fail loudly" half of AC-7's edge case actually logs. A future refactor could silently drop the diagnostic with no test failure.
2. Empty StringName (`&""`, an uninitialized/default `item_type`) is not tested as its own distinct case, separate from "a wrong but non-empty string."
3. The story file's header declared `Type: Config/Data` when the actual content is Logic-shaped (a real branching function with a required unit test) — corrected in the story file itself during `/story-done`, but the underlying coding-standards.md Type-classification guidance should be double-checked on future stories at `/create-stories` time to avoid recurrence.

### Recommended fix

- Add a GdUnit4 `assert_error()`-style assertion confirming `push_error()` fires on the rejection path.
- Add an explicit test case for `&""` as input to `get_tab_for_item_type()`.
- No code fix needed for item 3 — already corrected in the story file; only a process note for `/create-stories` going forward.

### Resolution
- [x] Fixed (2026-07-31) — 2 new tests added to `tests/unit/inventory/tab_categorization_test.gd`: `test_get_tab_for_item_type_rejects_unknown_item_type_push_error_message` (exact `push_error` text asserted, via the established `assert_error(func...).is_push_error(...)` combinator) and `test_get_tab_for_item_type_rejects_empty_string_name` (`&""` as its own distinct case).
- [x] Item 3: no code fix needed, as originally noted — process-note-only, already applied.
- [x] Live-verified: full project regression 1812/1812, 0 errors, 0 failures.
- [x] This entry closed.

## TD-inv-003 — Slot expansion's rarity resolution is caller-supplied, not resolved from real Inventory contents; no expansion-completion event; one test gap (fixed)

**Logged**: 2026-07-15
**Fixed**: 2026-08-25 (items 1 and 2 — item 3 was already fixed 2026-07-31)
**Story**: Story 003 (Slot Expansion & Cost Table, Epic 03) — flagged during design proposal and `/code-review`
**Severity**: Low — this is a deliberate, pre-identified scope boundary, not an accidental gap. No known reachable defect; the caller-input design was chosen specifically because the alternative (inventing a rarity system) would be unauthorized scope creep.
**Area**: `src/core/inventory/inventory.gd` (`attempt_expand_slots()`), `src/core/inventory/slot_expansion_cost_table.gd`, `tests/unit/inventory/slot_expansion_test.gd`

### Gap

1. **Rarity resolution deferred.** `ItemDefinitionResource` (Story 001) has no `rarity` field, and the GDD (`design/gdd/inventory.md`, Formulas section) explicitly states "Common/Uncommon/Rare material" are placeholder rarity-tier names — no real material-rarity vocabulary exists anywhere in the project yet (Crafting's GDD, not yet designed, will eventually assign real material item_ids to these tiers). `attempt_expand_slots(rarity_quantities_available: Dictionary[StringName, int])` therefore takes rarity-quantities as an explicit caller-supplied input rather than resolving them from real Materials-tab Inventory contents. Once Crafting exists and assigns real rarity data, a follow-up story must wire the real resolution path (likely: Inventory gains a `_resolve_rarity_quantities() -> Dictionary[StringName, int]` internal method that walks `_slots` via a new `ItemDefinitionResource.rarity` field, then `attempt_expand_slots()` either gains an overload or callers stop passing the dictionary manually).
2. **No EventBus signal for expansion completion.** The GDD's Visual/Audio Requirements section implies slot-expansion completion should be player-visible (a "Herald Gold flash" milestone moment), but Inventory emits no signals yet (Story 001's deliberate scope) and no such signal exists in `event-bus.md`'s catalogue. A future story should add e.g. `slot_expansion_completed(new_tier: int, new_slot_count: int)` once Inventory's event-emission scope opens up (likely alongside Story 005's `item_added`/`item_pickup_rejected` wiring).
3. **Minor test gap**: `test_expansion_missing_rarity_key_entirely_treated_as_zero_available` proves the missing-key case rejects correctly, but there's no paired test proving an explicit `{key: 0}` rejects identically — the equivalence is currently only guaranteed by code inspection of `_can_afford_expansion()`'s `.get(key, 0)` default.

### Recommended fix

- Items 1 and 2 are blocked on other systems (Crafting GDD, Inventory's broader EventBus emission story) — not actionable in isolation; re-visit once those land.
- Item 3: add a paired test with `{&"common": 0}` (or the relevant rarity key set explicitly to 0) at a tier that requires that rarity, asserting identical rejection/no-side-effects to the missing-key case.

### Resolution
- [x] Item 3 fixed (2026-07-31) — added `test_expansion_explicit_zero_rarity_key_treated_identically_to_missing_key` to `tests/unit/inventory/slot_expansion_test.gd`, directly beside the existing missing-key test, proving `{KEY_COMMON: 0}` rejects identically (`expanded == false`, tier unchanged).
- [x] **Items 1 and 2 fixed 2026-08-25**: `attempt_expand_slots()` no longer takes a caller-supplied availability Dictionary — it now resolves affordability via `has_items_by_rarity()` and spends via `consume_by_rarity()` against real Inventory contents (a new `_RARITY_KEY_TO_NAME`/`_resolve_rarity_cost()` pair reconciles `SlotExpansionCostTable`'s lowercase `&"common"`/`&"uncommon"`/`&"rare"` keys against `ItemDefinitionResource.rarity`'s capitalized `"Common"`/`"Uncommon"`/`"Rare"` vocabulary — two independently-evolved key spaces that had never needed reconciling before). `_can_afford_expansion()` (now redundant with `has_items_by_rarity()`) removed. Item 2: added `GEventBus.slot_expansion_completed(new_tier: int, new_slot_count: int)`, emitted on success, catalogued in `event-bus.md`. `attempt_expand_slots()`'s zero-production-caller status (noted 2026-08-24) is unchanged by this fix — still nothing wires slot expansion into a real UI screen, that remains separate future work. Rewrote `slot_expansion_test.gd`'s 15 call sites to seed real, already-`GGameDataRegistry`-registered rarity-tagged materials (`common_scrap`/`iron_ore`/`goblin_fang`, matching `has_items_by_rarity_test.gd`'s own established real-content convention) instead of constructing fake dictionaries — added dedicated coverage for real consumption (exact-amount and all-three-rarities-at-tier-4 cases) and the new signal (fires with correct args on success, does not fire on failure). Two of the original tests (`test_expansion_missing_rarity_key_entirely_treated_as_zero_available`/`test_expansion_explicit_zero_rarity_key_treated_identically_to_missing_key`) tested a distinction (missing-key vs. explicit-zero-key in a caller dict) that no longer exists as a code path once resolution moved to real inventory contents — collapsed into one `test_expansion_with_zero_common_material_owned_rejects`, with the collapse explained in a comment rather than silently deleted. **Not live-verified against the pinned Godot binary this session** — code-only, per the standing instruction to skip running tests.

## TD-inv-004 — `remove_item()` on a partial-quantity stackable slot is unasserted; AC-12 wording mismatch with Story 001's data model (item 1 fixed)

**Logged**: 2026-07-15
**Fixed**: 2026-07-31
**Story**: Story 004 (Equipped-Item Lock, Epic 03) — flagged during `/code-review`
**Severity**: Low-Medium — no known reachable defect today, but this is the one gap from this story with real regression risk once Story 006 (Partial Stack Consumption Stability) begins touching the same area.
**Area**: `src/core/inventory/inventory.gd` (`remove_item()`), `tests/unit/inventory/equipped_lock_test.gd`, `production/epics/epic-03-core-economy/story-004-equipped-item-lock.md`

### Gap

1. `remove_item()`'s documented and implemented behavior is to null the entire slot regardless of `quantity` (full removal, not partial consumption — that's explicitly Story 006's future territory). No test in `equipped_lock_test.gd` exercises this against a stackable slot holding a partial quantity (e.g. 50/99, unlocked) — the existing stackable tests only cover full-stack (99) or single-unit (1) fills, and none call `remove_item()` on a stackable slot at all except in the locked-rejection case. A future change that "helpfully" turns `remove_item()` into a decrement instead of a full null would not be caught by the current suite.
2. AC-12's literal wording ("verify this holds for both Equipment (cap=1) and installed Tower Components... the lock rule is orthogonal to stack-cap type") doesn't match Story 001's actual data model — Equipment and Tower Components are both `is_unique_instance=true` (cap=1), not two distinct cap-type cases. The test suite correctly tested the real orthogonal axis (unique-instance vs. stackable) instead of the AC's literal (and slightly incorrect) framing. Story file corrected in place during `/story-done`; this entry just tracks the underlying imprecision for whoever reviews future AC wording against this GDD.

### Recommended fix

- Add a test: unlocked stackable slot at partial quantity (e.g. 50/99), `remove_item()` called, assert the slot is fully null afterward (not decremented) — a regression guard, cheapest to add before Story 006 begins.
- No further action needed on item 2 — already corrected in the story file.

### Resolution
- [x] Item 1 fixed (2026-07-31) — added `test_remove_item_on_unlocked_partial_quantity_stackable_slot_nulls_the_whole_slot_not_decrements` to `tests/unit/inventory/equipped_lock_test.gd`: adds 50/99 of a stackable item, calls `remove_item()`, asserts the slot is fully null (not decremented to 49 or similar).
- [x] Item 2: no further action needed — already corrected in the story file, as originally noted.
- [x] This entry closed (2026-07-31) — live-verified: `equipped_lock_test.gd` passing alongside the rest of `tests/unit/inventory/` (94/94, 0 errors, 0 orphans); full project regression 1793/1793, 0 errors, 0 failures.

## TD-inv-005 — `consume_stackable()` push_error message content unasserted (fixed)

**Logged**: 2026-07-15
**Fixed**: 2026-07-31
**Story**: Story 006 (Partial Stack Consumption Stability, Epic 03) — flagged during `/code-review`
**Severity**: Low — return-value/state behavior (what callers actually depend on) is fully tested; only the diagnostic message text itself is unverified.
**Area**: `src/core/inventory/inventory.gd` (`consume_stackable()`), `tests/unit/inventory/stack_consumption_test.gd`

### Gap

None of `consume_stackable()`'s `push_error()` call sites (null definition, unique-instance rejection, quantity<=0, item-not-found, no-unlocked-slot-with-sufficient-quantity — 5 sites; this entry's original "6" count was itself slightly off) had their message content asserted — only the return value (`0`) and non-emission were checked. A future refactor could silently corrupt the error text (wrong interpolated value, wrong wording) without any test failing.

### Recommended fix

Add at least one `push_error` content assertion using this codebase's established GdUnit4 error-capture facility, if used elsewhere, for consistency with how thoroughly the rest of this method is tested.

### Resolution
- [x] Fixed (2026-07-31) — added 5 new tests to `tests/unit/inventory/stack_consumption_test.gd` using gdUnit4's established `assert_error(func...).is_push_error(...)` combinator (precedent: `tests/unit/game_data_registry/game_data_registry_test.gd`), one per call site: null definition, unique-instance rejection, zero/negative quantity, item-not-found, insufficient-quantity. All 5 exact message strings verified against the real source.
- [x] This entry closed (2026-07-31) — live-verified: 94/94 across `tests/unit/inventory/`, 0 errors, 0 orphans; full project regression 1793/1793, 0 errors, 0 failures.

## TD-inv-006 — `add_stackable()` has no `quantity <= 0` guard; now surfaces via a negative-quantity EventBus payload (fixed)

**Logged**: 2026-07-15
**Fixed**: 2026-07-31
**Story**: Story 005 (Mid-Mission Pickup Rejection, Epic 03) — flagged independently by both the GDScript specialist and QA tester during `/code-review`
**Severity**: Low — no crash or corruption; current control flow happens to be inert for `quantity <= 0` (both fill/overflow loops are skipped, `placed == 0`), but this is unverified by any test, and Story 005's new emission logic means a negative `quantity` would now produce a `GEventBus.item_pickup_rejected` payload with a negative `quantity` field — a malformed-looking signal a downstream subscriber (e.g. a future Mission HUD toast) shouldn't have to defend against.
**Area**: `src/core/inventory/inventory.gd` (`add_stackable()`), `tests/integration/inventory/pickup_rejection_test.gd`

### Gap

`add_stackable()` has never had a `quantity <= 0` guard, unlike its sibling `consume_stackable()` (Story 006), which explicitly rejects with `push_error()`. This predates Story 005 (present since Story 001) but was previously low-visibility since no EventBus emission depended on it. Story 005 wired `item_pickup_rejected`/`item_added` into this method's return path, so a negative `quantity` input now flows through to a real signal payload with a negative value, rather than just an odd internal return value.

### Recommended fix

- Add an explicit `if quantity <= 0: push_error(...); return quantity` guard at the top of `add_stackable()`, mirroring `consume_stackable()`'s existing idiom exactly.
- Add a regression test (`test_add_stackable_zero_or_negative_quantity_rejected` or similar, matching `slot_stack_model_test.gd`'s naming for the analogous `add_unique_item()` case) proving no signal fires and no mutation occurs.

### Resolution
- [x] Fixed (2026-07-31) — added the guard to `add_stackable()` (`src/core/inventory/inventory.gd`) exactly mirroring `consume_stackable()`'s existing idiom: `if quantity <= 0: push_error(...); return quantity`.
- [x] Regression tests added (2026-07-31) — `test_add_stackable_rejects_zero_or_negative_quantity` in `tests/unit/inventory/slot_stack_model_test.gd` (proves no mutation: all discretionary slots remain empty for both `quantity=0` and `quantity=-5`); `test_add_stackable_zero_or_negative_quantity_does_not_emit_either_signal` in `tests/integration/inventory/pickup_rejection_test.gd` (proves neither `item_added` nor `item_pickup_rejected` fires, via real `EventBusSpy` against the real `GEventBus`) — closing both halves the recommended fix asked for.
- [x] Live-verified (2026-07-31) — both affected test files: 28/28 passing, 0 errors, 0 orphans. Full project regression: 1786/1786, 0 errors, 0 failures.
- [x] This entry closed.

## TD-ui-001 — InventoryScreen's gamepad dual-focus behavior verified via keyboard only; physical hardware confirmation still open (item 2 fixed)

**Logged**: 2026-07-15
**Fixed**: Not yet (item 1 — item 2 fixed 2026-08-01)
**Story**: Story 007 (Two-Panel Screen Presentation, Epic 03) — flagged during live Godot MCP verification and `/code-review`
**Severity**: Medium — this is ADR-0011's own explicitly stated "Verification Required" item (gamepad `focus_entered` firing order under Godot 4.6's dual-focus split is not documented at the signal-order level), still not closed despite Story 007's own live verification pass.
**Area**: `src/ui/input_mode_tracker.gd`, `src/gameplay/ui/inventory_screen/inventory_screen.gd`, ADR-0011

### Gap

Story 007's live Godot MCP verification (`production/qa/evidence/two-panel-presentation-evidence.md`) exercised `InputModeTracker`'s `KEYBOARD_GAMEPAD` branch using a real `InputEventKey` (keyboard arrow press), not a literal `InputEventJoypadButton` — the MCP bridge's `simulate_input` tool has no gamepad-button input type, and no physical gamepad is attached to this environment. Both event types are handled by the identical code branch, so risk is assessed as low, but ADR-0011's own Verification Required item #1 is specifically about gamepad-originated `focus_entered` firing order, which remains genuinely untested.

Separately, the godot-specialist review flagged that raw `InputEventJoypadMotion` events reaching `InputModeTracker._input()` are NOT deadzone-filtered (Godot's deadzone handling lives in `Input.get_action_strength()`, not the raw event stream) — a real controller resting in the player's hands can emit continuous low-magnitude axis noise, which could cause spurious `KEYBOARD_GAMEPAD`/`MOUSE` mode-flipping on real hardware. This was not (and could not be) exercised by MCP-simulated events.

### Recommended fix

- Perform an actual live gamepad smoke test (physical controller, `ui_down` action, confirm `focus_entered` fires and the ring renders) once real gamepad hardware is available in a testing environment — this closes ADR-0011's own standing requirement.
- Add a manual deadzone threshold inside `InputModeTracker`'s `InputEventJoypadMotion` branch before this pattern is exercised on real hardware, to guard against idle-controller mode-flipping.

### Resolution
- [x] Item 2 fixed (2026-08-01) — added `JOYPAD_MOTION_DEADZONE: float = 0.5` (matches every configured InputMap action's own deadzone in `project.godot`) to `src/ui/input_mode_tracker.gd`; `_input()` now discards `InputEventJoypadMotion` events with `absf(axis_value) < 0.5` before they can flip the tracked mode. This item was miscategorized as hardware-blocked in every session-state extract this session — re-scanning the entry directly (not trusting the carried-forward summary) found it was a pure code fix, fully testable without physical hardware. Added `tests/unit/ui/input_mode_tracker_test.gd` (7 tests, previously no dedicated unit coverage existed for this class at all) — covers default mode, mouse/joypad-button transitions, sub-deadzone motion on both positive and negative axes not flipping mode, at-threshold motion flipping it, and the `input_mode_changed` signal firing exactly once per real transition (not on filtered noise).
- [x] Live-verified: `tests/unit/ui/input_mode_tracker_test.gd` 7/7, 0 errors, 0 orphans. Full project regression: 1823/1823, 0 errors, 0 failures.
- [ ] Item 1 (physical gamepad hardware confirmation) remains genuinely blocked — unchanged from the original assessment.

## TD-ui-002 — InventoryScreen: untested Tab-traversal and multi-resolution layout; FocusRing lookup fragility (fixed)

**Logged**: 2026-07-15
**Fixed**: 2026-08-01
**Story**: Story 007 (Two-Panel Screen Presentation, Epic 03) — flagged during `/code-review`
**Severity**: Low — none of these are confirmed defects, only unverified paths/style fragility.
**Area**: `src/gameplay/ui/inventory_screen/inventory_screen.gd`

### Gap

1. **Tab/`ui_focus_next` traversal untested.** `focus_neighbor_*` (including the self-referencing edge sentinel) only governs directional arrow-key/D-pad traversal — Godot's Tab-key traversal uses a separate automatic algorithm entirely unaffected by this wiring. Slots will likely traverse in correct index order by incidental tree-child order (no other focusable siblings exist), but this was never explicitly exercised by Story 007's live verification pass.
2. **Multi-resolution `GridContainer` layout untested.** `SlotGrid` has no `size_flags_horizontal` override (defaults to `FILL`, not `EXPAND`), so it sizes to its natural 5-column content width rather than stretching to fill `LeftPanel`'s allocated width. At the tested viewport this looks correct, but variable dead space between the grid and `RightPanel` could appear at different resolutions — `technical-preferences.md`/`ui-code.md` both require min/max-resolution testing, not yet performed for this screen.
3. **`get_node("FocusRing")` string-based lookup** (`_build_slot_grid()`) — works correctly today (live-verified), but is more fragile than returning the ring reference directly from `_create_slot_button()`; a future rename of the child node's name string without updating this lookup would fail silently (`null`) with no compile-time warning, then crash on the next `.visible` access.

### Recommended fix

- Add a Tab-key traversal test/manual check alongside the existing arrow-key verification.
- Test this screen at the project's minimum and maximum supported resolutions per `technical-preferences.md`.
- Refactor `_create_slot_button()` to return both the `Button` and its `FocusRing`/`HoverHighlight` children directly (e.g. via a small local struct or by populating `_slot_buttons`/`_slot_focus_rings` from within the function itself) rather than re-discovering the ring by name afterward.

### Resolution
- [x] Item 1 fixed (2026-08-01) — added `tests/integration/inventory-screen/tab-traversal_test.gd` (3 tests): proves Tab advances focus in slot-index order, Shift+Tab moves backward, and Tab from the last slot doesn't crash. The doc comment's own prediction ("likely traverse in correct index order by incidental tree-child order") was correct — now actually verified, not just assumed.
- [x] Item 2 fixed (2026-08-01) — **live-verified via Godot MCP that this was a real bug**, not just an untested-but-fine path: `SlotGrid`'s default `size_flags_horizontal` (`SIZE_FILL`) stretched its own bounding rect to fill `LeftPanel`'s full width (1011px at the default viewport) but did NOT stretch its columns to match, leaving ~675px of dead space between the grid and `RightPanel` while all 10 fixed-size 64x64 slot buttons stayed clustered top-left. Fixed by setting `SlotGrid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN` in `_build_slot_grid()`, collapsing the dead space. Verified live at 3 viewport sizes (default, 1920x1080, 1024x600) via Godot MCP `run_script` — grid stayed at its natural ~336px content width regardless. Added `tests/integration/inventory-screen/slot-grid-layout_test.gd` (2 tests) as an automated regression guard for both the base case and viewport-resize robustness. No documented minimum/maximum "supported resolution" values actually exist anywhere in the project (`technical-preferences.md` lists target platforms only, no numeric range) — tested at 2 representative sizes instead of literal min/max, since those aren't defined.
- [x] Item 3 fixed (2026-08-01) — `_create_slot_button()` now uses the already-existing, previously-unused-here `FocusRingFactory.build(button)` (extracted 2026-07-20 from Mission HUD, whose own doc comment already referenced "matching inventory_screen.gd's established FocusRing pattern" — this screen had just never actually been updated to use it). Returns the built `Panel` directly and appends it to `_slot_focus_rings` at creation time; the `get_node("FocusRing")` string-based lookup in `_build_slot_grid()` is gone entirely. Also removes the now-redundant local `FOCUS_RING_COLOR` constant (the factory owns that value).
- [x] Live-verified: `tests/integration/inventory-screen/` 5/5, 0 errors, 0 orphans. Full project regression: 1828/1828, 0 errors, 0 failures, orphan count unchanged at 185 (expected — see `TD-test-006`).
- [x] This entry closed.

## TD-econ-001 — ResourceEconomy: heterogeneous-batch resolution (two different drop_table_ids in one monsters_died_batch call) untested (fixed)

**Logged**: 2026-07-16
**Fixed**: 2026-07-31
**Story**: Story 010 (Drop Table Schema & Registry Lookup, Epic 03) — flagged during `/code-review`
**Severity**: Low — no known reachable defect; `_on_monsters_died_batch()`'s loop structure (`for payload in payloads: _resolve_drop_table(payload)`) has no shared/accumulated state between iterations by construction, so a heterogeneous-batch bug is unlikely, but it is genuinely unproven by any test.
**Area**: `src/core/resource_economy/resource_economy.gd`, `tests/unit/resource_economy/drop_table_schema_registry_test.gd`

### Gap

`test_resource_economy_resolves_registered_table_identically_via_monsters_died_batch` uses two batch entries that both cite the SAME `drop_table_id`. No test proves a batch containing entries for TWO DIFFERENT `drop_table_id`s each independently resolve to their own correct table — current coverage proves "no shared rounding state" for same-table entries and proves the loop doesn't crash, but doesn't rule out an indexing/closure mistake that resolves every batch entry against the first payload's id.

### Recommended fix

Add a test seeding two different `DropTableResource`s, constructing a `monsters_died_batch` payload array with one entry per table, and asserting each resolves independently to its own correct table (not the other's).

### Resolution
- [x] Fixed (2026-07-31) — added `test_resource_economy_heterogeneous_batch_resolves_each_entry_to_its_own_table` to `tests/unit/resource_economy/drop_table_schema_registry_test.gd`, directly beside the existing same-table batch test.
- [x] Live-verified: full project regression 1812/1812, 0 errors, 0 failures.
- [x] This entry closed.

## TD-econ-002 — [RESOLVED] wave_end despawns currently award spurious materials until Story 011 lands

**Logged**: 2026-07-16
**Fixed**: **2026-07-16, Story 011 (Despawn Drop Suppression)**
**Story**: Story 008 (Drop Occurrence & Quantity Resolution, Epic 03) — flagged during `/code-review`
**Severity**: Medium (time-sensitive) — a real, currently-live GDD Rule 5/AC-06/AC-07 violation, not a hypothetical. This is not "someday" debt — it's an active gap between Story 008 landing and Story 011 landing.
**Area**: `src/core/resource_economy/resource_economy.gd` (`_process_drops()`), `src/core/monster/monster_manager.gd` (confirmed source of the `wave_end` `monster_died` emission)

### Gap

`monster_manager.gd`'s wave-completion force-clear path unconditionally emits `GEventBus.monster_died.emit(ev)` with `ev.kill_source = &"wave_end"` for monsters force-despawned at wave end (not actually killed by the player). GDD Rule 5 / AC-06 / AC-07 (`design/gdd/resource-economy.md`) require these despawns to NEVER produce a drop — but Story 008's `_process_drops()` has no `kill_source` filtering at all (that's explicitly Story 011's scope, "Despawn Drop Suppression"). Until Story 011 ships, every wave-end force-clear spuriously awards materials via `_process_drops()`'s normal resolution path.

### Recommended fix

Implement Story 011 (already next in the planned sequence) — it owns the `kill_source == "wave_end"` (and the force-cleared-monster / BOSS-breach case) suppression filter. No standalone fix needed here; this entry exists to make the urgency explicit and trackable rather than letting it blend into the general backlog, since it's actively wrong in shipped behavior right now, not merely undertested.

### Resolution
- [x] Fixed 2026-07-16 via Story 011: added `KILL_SOURCE_WAVE_END` const + a hard early-return guard as the first statement in `_process_drops()`, before any table lookup. Also found and corrected a second issue while implementing: Story 011's own original ADR Decision Summary/Implementation Notes wrongly claimed no code was needed at all — corrected in the story file before implementation began. Independently re-verified by two specialist reviews (GDScript specialist traced guard ordering, per-payload independence, and const-value correctness against `monster_manager.gd`'s actual emission; QA tester confirmed the fix genuinely closes this item, not just passes tests coincidentally). Live-verified: 770/770 full project suite, 0 regressions.

## TD-econ-003 — materials_earned's `source` field semantics unconfirmed against GDD (resolved)

**Logged**: 2026-07-16
**Resolved**: 2026-07-31
**Story**: Story 008 (Drop Occurrence & Quantity Resolution, Epic 03) — flagged during `/code-review`
**Severity**: Low — a plausible reading, not contradicted by any test or GDD text, but not explicitly confirmed either.
**Area**: `src/core/resource_economy/resource_economy.gd`, `design/gdd/event-bus.md`

### Gap

`materials_earned(material_type, quantity, source)`'s `source` parameter is populated with `payload.kill_source` (values: `"tower"`, `"hero"`, `"wave_end"`). The sibling `resources_changed(gold, source)` signal uses `source` for *economic-event* strings (`"mission_start_grant"`, `"wave_completion_grant"`) — a different naming pattern than "which entity/mechanism performed the kill." `event-bus.md`'s catalogue entry for `materials_earned` doesn't define `source`'s intended semantics precisely enough to confirm or rule out this choice.

### Recommended fix

Confirm with game-designer/economy-designer whether `kill_source` is the intended `source` value for `materials_earned`, or whether it should instead describe the economic event (e.g. `"monster_kill"`) for consistency with `resources_changed`'s pattern. Update `event-bus.md`'s catalogue to document the decision either way.

### Resolution
- [x] Decision made (2026-07-31, user): **keep `kill_source` as-is.** The two signals answer genuinely different questions — `materials_earned.source` answers "what killed it," `resources_changed.source` answers "why did the balance change" — this is an intentional divergence, not an inconsistency to fix. No code change.
- [x] `event-bus.md`'s `materials_earned` catalogue row updated to document this explicitly, closing the "doesn't define source's intended semantics precisely enough" gap.
- [x] This entry closed.

## TD-econ-004 — Drop occurrence/quantity: two testability gaps (multi-entry-per-table Rule 9; realistic-rate-in-pipeline) (gap 2 fixed)

**Logged**: 2026-07-16
**Fixed**: Gap 2 fixed 2026-07-31; gap 1 remains documented residual risk (unchanged, low priority)
**Story**: Story 008 (Drop Occurrence & Quantity Resolution, Epic 03) — flagged during `/code-review`
**Severity**: Low — both are coverage gaps, not known defects; the underlying code paths are low-complexity.
**Area**: `src/core/resource_economy/resource_economy.gd`, `tests/unit/resource_economy/drop_occurrence_quantity_test.gd`

### Gap

1. No test exercises `_roll_drop_occurs()` at a realistic rate (e.g. 0.45) in combination with the full `_process_drops()` pipeline — AC-12 only tests the pure function in isolation; AC-01/AC-02 use `base_drop_rate=1.0`/`0.0` for determinism. An integration bug in how the boolean result is consumed (e.g. an inverted condition) wouldn't be caught by either test alone.
2. No test proves Rule 9's "no shared/accumulated rounding state" for MULTIPLE `DropEntry` items within ONE table on a single kill — existing coverage only proves independence across separate `monster_died`/batch events against single-entry tables.

### Recommended fix

- Add a test with a 2-entry `DropTableResource`, one `monster_died` event, asserting both entries resolve independently (closes gap 2 — the more concrete of the two).
- Gap 1 is lower priority given the trivial branch complexity (`if not ...: continue`) — acceptable as documented residual risk.

### Resolution
- [x] Gap 2 fixed (2026-07-31) — added `test_resource_economy_resolves_multiple_entries_in_one_table_independently_on_a_single_kill` to `tests/unit/resource_economy/drop_occurrence_quantity_test.gd`: a 2-entry table (different `material_id`/`base_quantity` per entry), one `monster_died` event, asserts both entries resolve to their own independently-computed quantity.
- [ ] Gap 1 remains open, as originally assessed — lower priority, acceptable documented residual risk, not fixed this pass.
- [x] Live-verified: full project regression 1812/1812, 0 errors, 0 failures.

## TD-econ-005 — Despawn suppression: no all-wave_end-batch test (defense-in-depth) (fixed)

**Logged**: 2026-07-16
**Fixed**: 2026-07-31
**Story**: Story 011 (Despawn Drop Suppression, Epic 03) — flagged during `/code-review`
**Severity**: Low — not a known gap in current coverage (the mixed-batch test already proves per-payload suppression), purely defense-in-depth against a future batch-iteration regression.
**Area**: `tests/integration/resource_economy/despawn_drop_suppression_test.gd`

### Gap

The existing `test_batch_with_normal_kill_and_wave_end_payload_resolves_only_normal_kill` proves a MIXED batch (one normal kill, one wave_end) suppresses only the wave_end entry. No test exercises a batch of 2+ ALL-wave_end payloads asserting zero emissions — this would guard against an off-by-one/early-exit bug that only suppresses the first wave_end entry in a batch.

### Recommended fix

Add a test: `monsters_died_batch` with 2+ wave_end payloads against a guaranteed-drop table, assert 0 `materials_earned` emissions.

### Resolution
- [x] Fixed (2026-07-31) — added `test_batch_with_multiple_wave_end_payloads_suppresses_all_of_them` to `tests/integration/resource_economy/despawn_drop_suppression_test.gd`: a batch of 3 all-wave_end payloads against a guaranteed-drop table, asserts 0 `materials_earned` emissions.
- [x] Live-verified: full project regression 1812/1812, 0 errors, 0 failures.
- [x] This entry closed.

## TD-test-006 — The full regression's "185 orphans" figure is a gdUnit4 reporting-timing artifact, not a real leak (investigated, not a bug)

**Logged**: 2026-08-01
**Investigated**: 2026-08-01
**Story**: Carried in every session-state extract's "recommended next pickup" list since at least Sprint 5 as an unexplained number — investigated on request to root-cause it once and for all.
**Severity**: None (informational) — does not fail tests (0 errors/0 failures alongside it every run), does not affect shipped game behavior. Logged purely so no future session re-investigates this from scratch.
**Area**: gdUnit4 framework internals (`addons/gdUnit4/src/core/execution/stages/single/GdUnitTestCaseSingleTestStage.gd`), plus the 9 test suites the count currently comes from.

### Root cause

gdUnit4's own execution-stage ordering snapshots orphan nodes **before** `after_test()` runs:

```gdscript
# GdUnitTestCaseSingleTestStage._execute()
await context.test_case.execute()               # runs the test body
await context.gc(GC_ORPHANS_CHECK.TEST_CASE)     # <- orphan snapshot taken HERE

# GdUnitTestCaseSingleExecutionStage._execute() -- after_test() runs in a LATER, separate stage:
await _stage_test.execute(...)   # test body + orphan snapshot (above)
await _stage_after.execute(...)  # after_test() -- runs AFTER the snapshot already happened
```

Any test that follows this project's own established, idiomatic convention — create a `Node` via `.new()` mid-test, free it correctly in `after_test()` (e.g. `GameDataRegistry.new()` + `_inject()` + `_ready()`, explicitly documented as convention in `drop_table_schema_registry_test.gd`'s own header comment) — gets miscounted, because the snapshot fires before that correct cleanup has had a chance to run.

Verified directly: attributed one orphan to the exact `_registry` member field mid-test via gdUnit4's own `collect_orphan_node_details()` diagnostic, confirming it was simply "not freed yet," not abandoned — `after_test()` frees it moments later, just after the count was already taken.

A related, second cause covers just over half the total (102 of 185, `exit-mission-select_test.gd` 82 + `loadout-handoff_test.gd` 20): `SceneManager._do_transition()`'s `get_tree().change_scene_to_packed()` defers its actual old-scene cleanup to Godot's next idle frame — also not yet run by the time the same snapshot fires. Confirmed by a temporary debug probe (`await get_tree().process_frame` before test end) dropping one suite's count from 82→11; reverted after confirming, not kept as a permanent change.

### Suites currently contributing (185 total, 2026-08-01 full regression)

| Suite | Orphans | Pattern |
|-------|---------|---------|
| `tests/integration/sanctuary-ui/exit-mission-select_test.gd` | 82 | Deferred `change_scene_to_packed()` cleanup |
| `tests/integration/sanctuary-ui/loadout-handoff_test.gd` | 20 | Deferred `change_scene_to_packed()` cleanup |
| `tests/unit/game_data_registry/game_data_registry_test.gd` | 37 | `.new()`-in-test / `free()`-in-`after_test()` |
| `tests/unit/defense_building/tech_structure_data_schema_test.gd` | 9 | `.new()`-in-test / `free()`-in-`after_test()` |
| `tests/unit/resource_economy/drop_table_schema_registry_test.gd` | 10 | `.new()`-in-test / `free()`-in-`after_test()` |
| `tests/unit/tower-mastery/tower_mastery_feedback_test.gd` | 9 | `.new()`-in-test / `free()`-in-`after_test()` |
| `tests/unit/event_bus/event_bus_signals_test.gd` | 1 | `.new()`-in-test / `free()`-in-`after_test()` |
| `tests/integration/sanctuary-ui/tab-strip-navigation_test.gd` | 10 | Same family (not individually isolated) |
| `tests/integration/sanctuary-ui/load-bearing-edge-cases_test.gd` | 7 | Same family (not individually isolated) |

### Why not fixed

The `.new()`/`after_test()` pattern is this project's own correct, idiomatic convention — not a bug to change. The `change_scene_to_packed()` timing is real but only cosmetic (the nodes are freed a frame later regardless). Silencing the count would mean adding a `await get_tree().process_frame` to the end of 9 test files to outrun gdUnit4's own snapshot timing — a real code change whose only purpose is to make an already-harmless number read 0, not something worth the maintenance surface. Left open/informational rather than actioned.

### Resolution
- [x] Root-caused and documented (2026-08-01) — no code change made, by design (see "Why not fixed" above).
- [x] This entry closed as informational — nothing further to do unless the count changes unexpectedly in a future run (which would then warrant fresh investigation, not assumption that it's still this same cause).

## TD-save-002 — EC-3/EC-5 UI (crash-recovery dialog, corrupt-save warning) not yet built (fixed)

**Logged**: 2026-08-01
**Fixed**: 2026-08-23
**Story**: Follow-up from `design/ux/main-menu.md`'s Continue/New Game/Load Game implementation — discovered EC-3 (crash recovery)/EC-5 (corrupt-save) were documented in `save-persistence.md` but never actually implemented in code, at all, at any layer.
**Severity**: Low — no known reachable defect (both scenarios are real but rare: a mid-mission crash, or a corrupted save file), and the backend now degrades safely even with no UI on top (`load_slot()` on a corrupt file still recovers to a real, playable fresh Sanctuary rather than getting stuck; a stray checkpoint is silently cleaned up over time as normal saves occur).
**Area**: `src/scenes/main_menu.gd`

### Gap

The backend half of EC-3/EC-5 was implemented 2026-08-01 (`SavePersistence.load_slot()` now returns a `LoadResult` enum distinguishing `SUCCESS`/`NOT_FOUND`/`VERSION_TOO_NEW`/`CORRUPT_RECOVERED`; `has_pending_checkpoint()`/`restore_from_checkpoint()` exist for EC-3) — see `save-persistence.md`'s own EC-3/EC-5 text for the full contract. No UI consumed any of this:

- Main Menu's own `_on_continue_pressed()`/`_on_slot_button_pressed()` called `GSavePersistence.load_slot(slot)` and ignored the returned `LoadResult` entirely — a corrupt save silently recovered with no player-facing message at all (contradicted EC-5's own "warn the player that their save could not be loaded" requirement).
- Nothing checked `has_pending_checkpoint()` before loading, so EC-3's own recovery-choice dialog ("Load last Sanctuary save" vs. "Restore from checkpoint") was never presented — a post-crash player's checkpoint just sat there until the next normal save silently cleaned it up (Rule 5), with no chance to explicitly choose to restore from it first.

### Recommended fix

- On Main Menu `_ready()` (or wherever save-state is first checked), call `GSavePersistence.has_pending_checkpoint(slot)` for the most-recently-modified occupied slot; if true, show a recovery-choice modal (matching `design/ux/main-menu.md`'s own already-specified EC-3 dialog: two buttons, no cancel — see that spec's Interaction Map) before anything else.
- After any `load_slot()` call, check the returned `LoadResult`; on `CORRUPT_RECOVERED`, show a non-blocking warning ("Your save could not be loaded and the game has started fresh — the original file has been preserved as `save_slot_N.corrupt` for debugging.").

### Resolution
- [x] Fixed 2026-08-23 — `_load_or_offer_recovery(slot)` is now the entry point for both Continue and every Load Game slot click: checks `has_pending_checkpoint()` first and shows a new `RecoveryChoicePanel` (Load Last Sanctuary Save / Restore From Checkpoint) before anything loads. `_perform_load(slot)` routes `load_slot()`'s `LoadResult` to a new `SaveWarningPanel` on `CORRUPT_RECOVERED` (proceeds to Sanctuary on OK, since the load did succeed with defaults) and `VERSION_TOO_NEW` (stays at the menu on OK, per AC-11 — load was aborted, file untouched). One deliberate deviation from the recommended-fix note above: the panel DOES respond to `ui_cancel`/Escape (dismisses without loading), matching this screen's own established modal convention (every other panel does the same) — not a spec violation, since EC-3's actual text only names the two choices, it doesn't forbid a third dismissal path.
- [x] 15 new tests in `tests/integration/main-menu/main_menu_test.gd` (recovery panel open/skip logic, both button choices, cancel, both warning-panel branches, ui_cancel on both new panels, Tab-focus containment) — all passing, plus 1 pre-existing test updated for the 2 new scalable-control entries. Full suite: 48/48, 0 errors, 0 orphans. Live-verified end-to-end via Godot MCP (seeded a real checkpoint, clicked through the recovery dialog, confirmed the panel renders and both choices work).

---

## TD-tower-003 — 3 of 4 tower blueprints are unreachable — no Tower Placement selection UI exists (stale, resolved)

**Logged**: 2026-08-07
**Story**: Found opportunistically during a content-audit pass checking `assets/data/` for orphaned entries (same pass that closed the equipment-forge accessory/sacrifice-recipe gaps and the mission-catalogue gap).
**Severity**: Low — no correctness defect; all 4 blueprints load cleanly and pass `GameDataRegistry`'s own generic directory-scan/`validate()`, and `TowerSystem.place_tower(tower_id, cell)` accepts any valid `tower_id` already. This is a missing *reachability path* (a UI), not broken data.
**Area**: `assets/data/towers/blueprints/` (4 files, one per archetype — `blueprint_archer.tres`, `blueprint_frostbolt_turret.tres`, `blueprint_longshot_sniper.tres`, `blueprint_rally_banner.tres`), `src/core/tower/tower_system.gd` (`place_tower()` — generic, unaffected)

### Gap

Grepped every `.gd` file in `src/` and `tests/` for each blueprint's `tower_id`. Only `&"archer"` is referenced anywhere — hardcoded as the sole placeable tower in every debug placement path (`src/gameplay/missions/the_gap/the_gap.gd`, `src/scenes/mission_scene.gd`). `frostbolt_turret` (elemental), `longshot_sniper` (ranged), and `rally_banner` (support) are never referenced by any production code or test file, anywhere. No Tower Placement selection UI exists in the codebase at all (confirmed: no `TowerShop`, `tower_select`, or blueprint-listing code found via grep) — so nothing ever calls `place_tower()` with any `tower_id` other than the one hardcoded value. All 3 non-archer archetypes are fully implemented, valid content, just currently impossible to place in any real playthrough.

### Recommended fix

Design and build a real Tower Placement selection UI (likely part of Mission HUD's own scope — `mission-hud.md` doesn't yet specify this) that lists all `GameDataRegistry`-loaded tower blueprints and lets the player choose which to place, replacing the hardcoded `&"archer"` debug call sites. A meaningfully bigger scope item than a content-authoring fix — logged here rather than actioned immediately.

### Resolution
- [x] **Stale, closed 2026-08-24** — resolved by later work that was never marked here. `src/presentation/mission_hud/planning_cluster.gd` (Zone E) now builds one placement tile per `GGameDataRegistry.get_all_tower_blueprints()` entry (line 488), with its own doc comment (line 60) explicitly confirming it replaces the old hardcoded single-blueprint debug click. All 12 tower blueprints (up from 4 at logging time) are reachable in-game via this UI.

---

## TD-craft-000 — All 5 Crafting recipes were unreachable — no Crafting UI screen existed (stale, resolved; renumbered from a duplicate TD-craft-002 to fix an ID collision with the unrelated, later `recipe_tier4_component` tech-gate entry)

**Logged**: 2026-08-07
**Story**: Found during the same orphaned-content-data audit that logged `TD-tower-003` — same class of gap (a real, valid, `GameDataRegistry`-loaded catalogue with no UI path to reach it), this time for the Crafting System rather than Tower Placement.
**Severity**: Low — no correctness defect; all 5 recipes (including the 2 fixed in this session's own `89aa082` commit) load cleanly and pass `RecipeResource.validate()`. This is a missing *reachability path* (a UI), not broken data — already self-documented in the code, not a hidden discovery.
**Area**: `src/core/crafting/crafting.gd` (core logic only, no companion screen exists — contrast with Defense Building/Equipment Forge/Menagerie, which each have a real `*_screen.gd`+`.tscn`), `src/presentation/sanctuary_ui/sanctuary_ui.gd` (`ROOM_SCENES`, `&"ROOM_INVENTORY_CRAFTING"` maps to `InventoryScreen.tscn`, not a Crafting screen)

### Gap

`sanctuary_ui.gd`'s own doc comment (line 71) already discloses this: Equipment Forge's screen built its own equipment-recipe list "instead of literally reusing a nonexistent Crafting panel." Confirmed via `find`/`grep`: no `crafting_screen.gd` exists anywhere in `src/`, and the Sanctuary tab labeled "Inventory & Crafting" (`ROOM_INVENTORY_CRAFTING`) actually loads `InventoryScreen.tscn` — a real screen, but not one that lists or lets the player craft any of the 5 `RecipeResource` entries in `assets/data/recipes/`. Every recipe (Tower Component and Crafted Good alike) is genuinely valid, loadable content with no in-game way to discover or craft it.

### Recommended fix

Design and build a real Crafting UI screen (likely following the same pattern Defense Building/Equipment Forge/Menagerie already established: a dedicated `*_screen.gd`/`.tscn` wired into `sanctuary_ui.gd`'s `ROOM_SCENES`) that lists `GameDataRegistry.get_all_recipes()` and lets the player craft against the Discovery Ledger/Craftability rules `crafting.gd` already implements. A UI build, not a content fix — logged here rather than actioned immediately, matching `TD-tower-003`'s own disposition.

### Resolution
- [x] **Stale, closed 2026-08-24** — resolved by the "Forge→Crafting relocation" work (session extract 2026-08-21) that was never marked here. `src/gameplay/ui/inventory_screen/inventory_screen.gd` now has a fully built Crafting panel directly inside `InventoryScreen` (recipe list/tab strip, craft-preview rings, `recipe_discovered`/`component_crafted` EventBus wiring) rather than a separate dedicated screen — a different UI shape than this entry's own recommended fix assumed, but the same underlying gap (reachability) is genuinely closed. `ROOM_INVENTORY_CRAFTING` correctly still maps to `InventoryScreen.tscn`, which is now accurate rather than stale.

---

## TD-mission-001 — MissionResource (objective text) has no display path anywhere (fixed)

**Logged**: 2026-08-07
**Fixed**: 2026-08-23
**Story**: Found during the same orphaned-content-data audit that logged `TD-tower-003`/`TD-craft-002` — same class of gap (valid content/mechanism with no consumer), this time the objective-text mechanism rather than a missing screen entirely.
**Severity**: Low — no correctness defect; `the_gap.tres` (the one authored `MissionResource`) loads cleanly and passes `validate()`. Unlike the other two entries in this class, the screen this content would appear on (`mission_select_screen.gd`) already exists and is fully built — it just never grew a label for this specific field.
**Area**: `src/core/mission_resource.gd`, `assets/data/missions/*.tres`, `src/gameplay/ui/mission_select_screen/mission_select_screen.gd`/`.tscn`

### Gap

`MissionResource`/`objective_text` was built specifically to give players mission-descriptive text (`mission_resource.gd`'s own doc comment: "S5-02 — closes the missing-MissionResource gap flagged in `design/ux/pause-menu.md`"). `GameDataRegistry.get_mission_resource()` exists and is documented with a usage example in its own doc comment — but grepped every `.gd` file in `src/` and found zero real call sites, anywhere. Only `the_gap.tres` has one authored; `the_foothills`/`the_hollow`/`the_narrows` (added this session, `a6dc10c`/`1214e40`) don't, though that's moot while nothing reads any of them.

### Recommended fix

Add an objective/description `Label` to `mission_select_screen.gd` (or wherever the UX spec eventually places it) that reads `GameDataRegistry.get_mission_resource(mission_id).objective_text` for the currently-selected mission, then author the missing 3 `MissionResource` files to match. Smaller than `TD-tower-003`/`TD-craft-002` (a label addition to an existing screen, not a new screen), but still a design/UI decision (where it goes, how it's styled) rather than a pure content fix — logged here rather than actioned immediately.

### Resolution
- [x] Fixed 2026-08-23 — added `ObjectiveLabel` to `MissionSelectScreen.tscn`'s `ConfigPanel` (above the difficulty tier row, autowrap on), wired via a new `_refresh_objective_label()` called from the existing `_refresh_config_panel()` refresh path (fires whenever the selected mission changes, same trigger as the tier/modifier button label refreshes). Falls back to an empty string for a mission with no authored `MissionResource`, matching `get_mission_resource()`'s own does-not-abort policy — never an error state.
- [x] Authored the 3 missing `MissionResource` files (`the_foothills.tres`, `the_hollow.tres`, `the_narrows.tres`) matching `the_gap.tres`'s established format, each with real flavor text reflecting that mission's actual layout/difficulty (Foothills: open Tier-1 intro; Narrows: tight Tier-2 chokepoint; Hollow: long Tier-3/Brutal grind). All 4 missions in the catalogue now have real objective text.

---

## TD-tower-004 — Pre-Placement Perk mechanism has no gameplay effect, only an event/audio cue (fixed)

**Logged**: 2026-08-07
**Story**: Found during a continued orphaned-content-data audit (same family as `TD-tower-003`/`TD-craft-002`/`TD-mission-001`) — this time `GameDataRegistry.get_perk_registry()`.
**Severity**: Low — no correctness defect; `assets/data/towers/perk_registry.tres` loads cleanly with 4 real, valid perk definitions (`DAMAGE_BOOST`, `RANGE_BOOST`, `SPEED_BOOST`, `AURA_EXTEND`, each with a `label`/`description`/`archetype_restrictions`). This is a missing gameplay-effect application, not broken data.
**Area**: `src/core/game_data_registry.gd` (`get_perk_registry()`), `assets/data/towers/perk_registry.tres`, `src/core/tower/foundation_component.gd` (`pre_placement_perk` field, always `""` on all 4 real blueprints), `src/core/tower/tower_system.gd` (emits `pre_placement_perk_activated`, never reads `pre_placement_perk` or the registry)

### Gap

`tower.md` Rule 12: "A tower placed during the `SCOUT` phase... receives a bonus perk defined in its component data." `TowerSystem.place_tower()` genuinely emits `GEventBus.pre_placement_perk_activated(tower_id, archetype)` on Scout-phase placement (`tower_system.gd:155`) — but the payload carries only `tower_id` and `archetype`, never a `perk_type`/`perk_power`. Grepped every `.gd` file in `src/` for `get_perk_registry()`: the only call site is the method's own doc-comment usage example, never a real call. All 4 authored tower blueprints have `pre_placement_perk = ""` (unassigned) today, so the field itself has never been exercised by content either. The only real consumer of the emitted event is `audio_cue_dispatcher.gd`, which plays a sound cue — the actual described mechanical effect (e.g. "Weapon DPS multiplied by (1.0 + perk_power)") is never computed or applied anywhere.

### Recommended fix

Wire `foundation_component.gd`'s `pre_placement_perk` field through to a real effect application at the moment `pre_placement_perk_activated` fires — read the perk_id, look it up via `GameDataRegistry.get_perk_registry()`, and apply its described stat modification to the placed tower (respecting `archetype_restrictions`). Then author real `pre_placement_perk` values onto at least one blueprint per eligible archetype so the mechanism has something to exercise. A design/implementation decision (what "perk_power" values are, where the stat mutation lives), not a pure content-authoring fix — logged here rather than actioned immediately, matching this family's own disposition.

### Resolution
- [x] Fixed 2026-08-24. Added `perk_power: float` to `FoundationComponent` (tower.md's own per-type range table: DAMAGE_BOOST/SPEED_BOOST [0.05,0.25], RANGE_BOOST [0.0625,0.25], AURA_EXTEND [0.10,0.25]), enforced at load time in `validate()`. Added `TowerSystem._apply_pre_placement_perk(state)`, called once at Scout-Phase placement right before `pre_placement_perk_activated` fires — mutates the tower's own already-`duplicate_deep()`'d component copies directly (matching ADR-0008 isolation, same pattern as `damaged`), checking `archetype_restrictions` (case-normalized via `.capitalize()` against the registry's capitalized archetype strings) before applying: `DAMAGE_BOOST` → `weapon_damage *= (1.0+power)`, `SPEED_BOOST` → `attack_speed = min(4.0, attack_speed*(1.0+power))`, `RANGE_BOOST` → `attack_range_cells = min(8, attack_range_cells + round(power*8))`, `AURA_EXTEND` → `aura_radius_cells = min(6, aura_radius_cells + round(power*6))`. Authored real, non-wasteful `pre_placement_perk`/`perk_power` values onto one blueprint per eligible archetype: Archer (Physical, `RANGE_BOOST` 0.125), Longshot Sniper (Ranged, `DAMAGE_BOOST` 0.20), Storm Turret (Elemental, `SPEED_BOOST` 0.15), Barrier Ward (Support, `AURA_EXTEND` 0.15) — checked each against its own clamp ceiling by hand to confirm no wasted benefit.
- [x] **Implemented 2026-09-02**: `TowerBlueprintData.warn_if_perk_benefit_wasted()` — the cross-component view this needed turned out to already exist on `TowerBlueprintData` itself (it holds Foundation and Weapon/Focus simultaneously), no Tower Assembly changes required. Mirrors `_apply_pre_placement_perk()`'s exact formulas for `SPEED_BOOST`/`RANGE_BOOST`/`AURA_EXTEND` (`DAMAGE_BOOST` excluded — no paired hard cap to check), `push_warning()`s (not a `validate()` failure) when the boosted value would exceed the paired stat's cap. Wired at both real content-load boundaries: `GameDataRegistry._load_tower_blueprints()` (the 18 static `.tres` blueprints) and `register_dynamic_tower_blueprint()` (Tower Assembly's own equip-time path this entry's text specifically named). New tests: `tests/unit/tower/tower_blueprint_data_test.gd` (9 cases — one warning + one no-warning boundary per perk type, plus `DAMAGE_BOOST`/no-perk/null-foundation no-op cases). Not run this session, per the standing "no unrequested testing" instruction — hand-verified against `_apply_pre_placement_perk()`'s own formulas and against AC-Rule-12a's exact worked example (3.5 attack_speed, 0.25 perk_power → 4.375, warns; 3.0 → 3.75, silent).
- [x] This entry closed (2026-09-02).


## TD-visualpres-001 — the_gap.tscn missing BreachFlashOverlay nodes mission_hud.gd unconditionally expects (fixed)

### Gap
`mission_hud.gd`'s `@implicit_ready` (lines ~126-129) calls `get_node()` for `BreachFlashOverlay/TopEdge`, `BottomEdge`, `LeftEdge`, `RightEdge` unconditionally. `MissionScene.tscn` has these nodes; `the_gap.tscn` does not — confirmed live via Godot MCP (loading `the_gap.tscn` and adding it to the tree logs 4 "Node not found" errors from `mission_hud.gd`, reproducible from plain scene instantiation, unrelated to any camera/3D work). Found during Epic 15 Story 003 (3D Visual Presentation Layer) live-verification, not caused by it — `the_gap.tscn` and `MissionScene.tscn` appear to be parallel scene structures that have drifted out of sync on this specific HUD subtree.

### Recommended fix
Either add the missing `BreachFlashOverlay/{TopEdge,BottomEdge,LeftEdge,RightEdge}` `ColorRect` nodes to `the_gap.tscn` (matching `MissionScene.tscn`'s existing structure exactly), or make `mission_hud.gd`'s `@implicit_ready` tolerate their absence (`get_node_or_null()` + guard) if the breach-flash effect is intentionally not wanted on `the_gap.tscn`'s host scene. Needs a design call on which scene is authoritative before actioning — not a pure mechanical fix.

### Resolution
- [x] Fixed 2026-08-24 — went with the first option (add the missing nodes) rather than making `mission_hud.gd` tolerant, since `MissionScene.tscn` already treats the breach-flash effect as a real, wanted feature and there was no indication `the_gap.tscn` should be an intentional exception. Added `BreachFlashOverlay/{TopEdge,BottomEdge,LeftEdge,RightEdge}` `ColorRect` nodes directly under `the_gap.tscn`'s `HUD` node (confirmed via grep that `mission_hud.gd` is attached to that exact node in both scenes, so the `$BreachFlashOverlay/...` relative paths resolve identically), copied property-for-property from `MissionScene.tscn`'s existing structure — same anchors, `mouse_filter = 2`, and initial `Color(1, 0, 0, 0)` (fully transparent red, matching the flash-on-demand pattern). Not re-verified via live Godot MCP this session per the standing "no unrequested testing" instruction.

## TD-tower-005 — ADR-0019 (Projectile Pooling Strategy) was never implemented; TR-tower-007 still open (fixed)

### Gap
ADR-0019 ("Projectile Pooling Strategy," Status: Accepted) describes a 192-slot pooled `Projectile`/`ProjectileManager` system — plain `Node2D` instances warmed up once at mission start, released/reused via `visible=false`+`process_mode=PROCESS_MODE_DISABLED` toggling, driven by a single centralized `ProjectileManager._physics_process()` pass, with a real flight-time delay before `tower_attacked` fires (HOMING re-acquisition throttled at `MAX_REACQUISITIONS_PER_FRAME = 8`). **Confirmed during Epic 15 Story 006 (2026-08-20) that none of this exists in the codebase.** Grep for `class_name ProjectileManager`, `POOL_SIZE`, `_free_indices` returns zero matches anywhere in `src/` or `tests/`. `TowerSystem._try_attack()` (`src/core/tower/tower_system.gd`) still emits `GEventBus.tower_attacked.emit.call_deferred(...)` immediately and unconditionally for every weapon type — no flight delay, no pool, no branching on `projectile_type`. The only real projectile-related code is `ProjectileVisual` (`src/scenes/projectile_visual.gd`), a purely cosmetic, non-pooled `Node2D` instantiated fresh per shot by `mission_scene.gd`'s `_on_tower_attacked()` handler and `queue_free()`'d at end-of-flight. ADR-0019's own Migration Plan already stated "Greenfield — no existing Projectile/ProjectileManager code to migrate" at authoring time; that remains true today. `TR-tower-007` (the requirement ADR-0019 exists to close) is still open.

**Why this matters beyond the missing pool itself**: gameplay currently has damage land *instantly* on attack (no flight-time delay) rather than the delayed-arrival model ADR-0019's Decision assumes downstream systems (Mission HUD combat feedback timing, Encyclopedia/audio cue timing, balance around DPS-vs-travel-time) may already assume is real. Epic 15 Story 006 needed to build a 3D visual companion for "the pooled Projectile system" per its own story text and explicitly could not, since the target doesn't exist — it was redirected to attach the companion to the real `ProjectileVisual` create/destroy lifecycle instead (see that story's Completion Notes and `production/qa/evidence/projectile-visual-companion-evidence.md`'s "ADR-0019 Gap Finding" section for the full resolution).

### Recommended fix
This is a real implementation gap, not a documentation error — either (a) implement ADR-0019 as originally decided (a genuine gameplay-timing change: introduces real projectile flight delay before damage lands, touches `TowerSystem`'s fire path, closes `TR-tower-007`), or (b) formally supersede/revise ADR-0019 to match the instant-damage model that's actually shipped, if the delayed-arrival design is no longer wanted. Either way this is a design/architecture decision for game-designer/technical-director, not a mechanical fix — explicitly out of scope for Epic 15 (a visual-presentation-only epic that holds zero-gameplay-logic-changes as a hard boundary).

### Resolution
- [x] Fixed 2026-08-24 (user choice: "Implement ADR-0019 as originally decided"). Built `Projectile` (`src/core/tower/projectile.gd`) and `ProjectileManager` (`src/core/tower/projectile_manager.gd`) exactly per ADR-0019's Decision: 192-slot pool pre-instantiated once at `_ready()`, `visible=false`+`process_mode=PROCESS_MODE_DISABLED` release/reacquire, single centralized `_physics_process()` pass (no per-instance physics-process), `MAX_REACQUISITIONS_PER_FRAME=8` throttle, HOMING re-acquisition bounded to the firing tower's own range/cone via the previously-unwired `TowerSystem._get_best_target()`/new `reacquire_target()` dispatch surface (Rule 19), graceful pool-exhaustion degradation (dropped shot + `push_warning`, never a crash). `ProjectileManager` is instantiated as a real child of `TowerSystem` in `_ready()` (ADR-0019's Ownership section — intra-system, not cross-system). `TowerSystem._try_attack()` now branches on `projectile_type`: `BEAM` unchanged (immediate `tower_attacked`), `HOMING`/`BALLISTIC` route through `_projectile_manager.fire()` instead, with `tower_attacked` (and AoE splash, previously always fire-time) now firing at real arrival via the new `on_projectile_arrived()` accessor, which re-resolves `is_armored` fresh from `_monster_cache` rather than trusting fire-time data that could be up to `base_flight_time_sec` (0.5s) stale.
  - **One deliberate deviation from the ADR's own code sample, documented in `projectile.gd`'s own doc comment**: the pooled `Projectile` has no visual child at all. The ADR's sketch had the pooled node own its own `AnimatedSprite2D`; this project already has a richer, already-shipped, already-3D-companion'd cosmetic system (`ProjectileVisual`) that would have been thrown away for no correctness gain. Instead, a new EventBus signal `tower_projectile_fired` (fires at real fire time, decoupled from `tower_attacked`'s now-delayed arrival) drives the tower's own recoil/punch animation and spawns the existing per-shot `ProjectileVisual`, unchanged otherwise. `event-bus.md`'s catalogue updated (79→80 events) with both the new row and `tower_attacked`'s changed timing/Key-Subscribers documented.
  - **Known, documented, NOT fixed here**: `ProjectileVisual`'s own cosmetic flight duration (distance/900 world-units-per-sec) is not synchronized with the pooled `Projectile`'s fixed `base_flight_time_sec=0.5s` logical arrival — at long range (~1280 units, this project's grid diagonal) the cosmetic bolt can visually arrive up to ~1s after damage has already logically landed. ADR-0019's own Risks section explicitly scopes exact easing/interpolation as "a visual-polish decision left to implementation and art review, not gated by this ADR" — flagged as a real follow-up, not silently accepted as correct.
  - **Tests NOT run or updated this session**, per the standing "no unrequested testing" instruction — this is a genuine architecture-level change to combat timing. At minimum, `tests/unit/tower/tower_combat_test.gd` almost certainly has assertions that `tower_attacked` fires synchronously/immediately for HOMING/BALLISTIC weapons, which are now false by design (real flight delay). `event_bus_signals_test.gd` and/or `event-bus.md`'s own AC-08-style event-count assertions may also need a 79→80 update. ADR-0019's own Validation Criteria checklist (8 items, all still `[ ]`) is genuinely unverified — do not treat this fix as test-confirmed until that checklist is actually run against.
- [x] **Fixed 2026-08-26 (live gdUnit4 full regression sweep, user-requested)**: this prediction was exactly right — `tower_combat_test.gd` crashed on every HOMING/BALLISTIC-path test (`_StubGrid` had no `cell_to_world()`/`world_to_cell()`, and the bare-constructed `TowerSystem.new()` never ran `_ready()` so `_projectile_manager` stayed null, crashing on `.fire()`). Fixed: added real `cell_to_world()`/`world_to_cell()` to `_StubGrid` (mirroring `grid.gd`'s exact formula); added a new `_StubProjectileManager extends ProjectileManager` (must extend the real class — `TowerSystem._projectile_manager` is strictly typed, unlike the untyped `_grid`/`_pathfinding` stub fields) whose `fire()` override skips flight-time simulation and calls back into the real, unmodified `TowerSystem.on_projectile_arrived()` synchronously — this file's own header scopes it to damage/splash *formula* testing, not pooled-flight *timing*, so a dedicated integration test for the latter (see below) is still a real, separate gap. Three pure DPS/targeting tests (`test_continuous_fire_t1`/`t2`, `test_find_lowest_hp_target_selects_lower_hp_enemy`) additionally got an explicit `projectile_type = "BEAM"` override since they don't exercise splash and BEAM's immediate/synchronous path is simpler and risk-free for them.
- [x] **Real regression found and fixed in production code during this pass, not just the tests**: `on_projectile_arrived()` applied splash purely on `aoe_radius_cells > 0`, with **no `projectile_type == "BALLISTIC"` check at all** — despite `tower.md` line 80/Formula 1c explicitly stating `aoe_radius_cells` is "BALLISTIC only." `WeaponComponent.validate()` doesn't enforce this pairing either (range-checks the value only). This was a live, real, both-layers gap — a HOMING weapon with a nonzero `aoe_radius_cells` (nothing prevented content from shipping one) would have splashed exactly like a BALLISTIC one. Fixed by gating splash behind `state.weapon.projectile_type == "BALLISTIC"` in `on_projectile_arrived()`, restoring `test_splash_disabled_for_non_ballistic_weapon`'s real, correct, GDD-backed expectation (not a stale assumption — verified against the GDD before fixing, not just made the test pass).
- [ ] **Still open, not fixed this pass**: a real integration test exercising the actual pooled/flight-delayed path (`ProjectileManager` inside a live scene tree, `_physics_process()` actually driven, real `base_flight_time_sec` timing) does not exist anywhere. This session's fix makes the unit-level formula tests pass again via a synchronous stub that deliberately bypasses flight timing — appropriate for *this* test file's stated scope, but it means ADR-0019's Validation Criteria checklist (8 items, still all `[ ]`) remains genuinely unverified. Recommended: a new `tests/integration/tower/projectile_pooling_test.gd` that adds a real `ProjectileManager` to the test's own scene tree and asserts on actual elapsed-time arrival.

## TD-damage-002 — `damage-status.md` Rule VIII (Hero-Death Cleanup) documented as shipped, never actually implemented (fixed)

### Gap
`design/gdd/damage-status.md` Rule VIII ("Hero-Death Cleanup," dated 2026-07-15d in that GDD, with substantial follow-up detail added across at least two later `/review-all-gdds` passes) describes `DamageStatus` subscribing to `hero_died` and synchronously clearing `_lifesteal_pending` the instant it fires, with a documented and fairly intricate frame-timing rationale (racing against `monster_hp_absorbed`'s `_physics_process`-pinned flush). Found while implementing `TD-hero-001`'s Skill Power GDScript half (2026-08-26): `src/core/damage_status/damage_status.gd` has no `hero_died` subscription anywhere — grep-confirmed. Only `tower_attacked`, `hero_auto_attacked`, `hero_skill_attacked` (new, this pass), and `monster_hp_absorbed`/`wave_completed` are wired. The GDD's own Rule I.2 says D&S owns "six event subscriptions" including `hero_died` as the sixth — the code has five.

**Real, live consequence**: `_lifesteal_pending` is never cleared on hero death. A lifesteal-fraction entry registered by a hit landed just before the hero dies stays in the dictionary; if `monster_hp_absorbed` for that hit arrives after `hero_died`, Rule VI's existing "if not present: ignore" guard does NOT save this — the entry IS present (nothing removed it), so `hero_healed` fires on an already-dead hero, exactly the bug Rule VIII's own Rationale (`damage-status.md` Rule VIII.3) describes trying to prevent. `hero.gd`'s Formula 6 `hero_healed` handler does carry a defensive `state == DEAD` guard (per that Rule's own note, "as a second layer in case this dependency is ever silently broken") — so this is very likely NOT currently visibly broken in practice (the defensive guard on the Hero side probably masks it), but the GDD's own documented two-layer design is currently running on only one layer.

### Recommended fix
Add a `_on_hero_died()` handler to `damage_status.gd`, subscribed/unsubscribed in `_ready()`/`_exit_tree()` alongside the existing four, implementing Rule VIII.2 exactly: `_lifesteal_pending.clear()` synchronously, no `await` (unlike `_on_wave_completed`'s deferred clear). Small, mechanical, well-specified — the GDD already fully describes the required behavior and its rationale; this is an implementation gap, not a design gap.

### Resolution
- [x] Fixed 2026-08-26. Added `_on_hero_died()` to `damage_status.gd`, subscribed/unsubscribed in `_ready()`/`_exit_tree()` alongside the existing five (now six, matching the GDD's own Rule I.2 count). Implements Rule VIII.2 exactly: `_lifesteal_pending.clear()` synchronously, no `await` — deliberately different from `_on_wave_completed()`'s deferred (`await get_tree().process_frame`) clear, per Rule VIII.4's explicit distinction. No new fields, no new constants, no behavior change to any other handler — `_on_monster_hp_absorbed()`'s existing "if not present: ignore" guard does the rest of the work once the entry is gone.
- [x] Not live-verified this session (no live Godot MCP run) — the fix is small and mechanical, and hand-traced against the GDD's own Rule VIII.2-VIII.6 text, but the actual cross-system frame-timing race this rule defends against (Rule VIII.6's dependency on Monster System's `_physics_process`-pinned flush) was not exercised live. Flag for a future live-verification pass if this specific race is ever suspected of regressing.

## TD-visualpres-002 — 6 of 8 monster types had no `CreatureAtlasMappingResource` — `MonsterSwarmRenderer3D.register_creature()` rejected them outright (fixed)

### Gap
Found while live-verifying Phase 2/4 dormant infrastructure (2026-08-26 session): only `goblin_runner` (STANDARD) and `goblin_warlord_boss` (BOSS) had a `res://assets/data/creature_atlases/*.tres` entry. Every other monster in `assets/data/monsters/` — `armored_brute`, `spore_skitterling` (STANDARD), `bog_lurker_elite`, `forest_troll_elite`, `iron_colossus_elite` (ELITE), `rift_sentinel_boss` (BOSS) — had none, so `MonsterSwarmRenderer3D.register_creature()`/spawning any of them logged `push_error("... unknown creature_id ...")` and left them with no 3D swarm presentation at all. Harmless in current shipped behavior only because `Camera3D`/the swarm renderer are both dormant (`Camera2D` remains active per Epic 15's "no premature cutover" policy) — this would be a real, visible gap the moment a camera cutover ships.

Also found: `MonsterManager._spawn_entity()` (`src/core/monster/monster_manager.gd` ~line 732) only special-cases `tier == 2` for the boss presenter path (`register_boss()`) — `tier == 1` (ELITE) goes through the same `register_creature()` standard-batch path as `tier == 0` (STANDARD), despite `monster_swarm_renderer_3d.gd`'s own class doc comment saying "Bosses, elites, and Menagerie" all use the exceptional presenter path. Confirmed against `design/art/animation-pipeline.md` §2 ("standard/elite at 64px" — the same display scale) and `monster_instance.gd`'s own `TARGET_LONG_EDGE_BY_TIER` (`{0: 64.0, 1: 64.0, 2: 112.0}`) that ELITE and STANDARD really do share the same visual tier in this project's actual shipped tuning — the doc comment's "elites" mention is aspirational/stale, not a contradicted contract; not fixed/reconciled here, just verified before authoring new mappings so they'd match the real code path rather than the stale comment.

### Resolution
- [x] Fixed 2026-08-26 for 5 of 6 monsters — authored `armored_brute.tres`, `spore_skitterling.tres`, `bog_lurker_elite.tres`, `forest_troll_elite.tres` (all `presentation_class = "standard"`, `world_width/height = 1.0/1.0`, matching `goblin_runner.tres`'s exact precedent and the tier-64px convention above) and `rift_sentinel_boss.tres` (`presentation_class = "exceptional"`, `approved_presenter_class = "BossCreaturePresenter3D"`, `world_width/height = 2.5/3.0`, matching `goblin_warlord_boss.tres`'s precedent) in `assets/data/creature_atlases/`. All 5 reference real, already-shipped 2D sprite art (`assets/art/monsters/*.png`) — no new art generated, this is pure plumbing. Live-verified via Godot MCP: spawned all 6 non-blocked monster types in a real running mission, confirmed each resolves `swarm_handle`/`boss_presenter_handle` correctly with zero `register_creature`/`register_boss` errors (previously every one of these 5 logged `push_error`).
- [x] **`iron_colossus_elite` — closed (2026-09-02), found already resolved.** This entry's own "genuinely blocked, no source art exists" note went stale without being revisited: Codex generated real base-pose + walk-cycle art for this monster in the same 2026-08-29/30 batch that closed the other 5 (`design/art/asset-generation-prompts.md`'s "combined base-pose+walk request for Iron Colossus"), and `assets/art/monsters/iron_colossus_elite.png` plus a fully-populated `assets/data/creature_atlases/iron_colossus_elite.tres` (`presentation_class="standard"`, matching the other 5's precedent, `idle`+`walk` clips) both already exist and are committed (`1795b59`, 2026-08-30) — this checklist item was just never ticked to match. All 6 of the original 6 gap monsters are now mapped; 0 remain blocked.
- [x] This entry closed (2026-09-02).

## TD-save-004 — save-persistence.md Rule 9 (DEFEAT-triggered save, deferred 1 frame) has no implementation anywhere in shipped code (fixed)

### Gap
Found 2026-08-27 while writing the checkpoint-race integration test flagged as genuinely untested in mission-select.md/save-persistence.md (`tests/integration/mission-select/defeat-retry-checkpoint-race_test.gd`). `save-persistence.md` Rule 9 documents a dedicated mechanism in detail (with EC-11 and AC-13): on `mission_phase_changed` reaching `DEFEAT`, Save & Persistence defers exactly 1 frame (matching the existing `sanctuary_state_restored` deferral pattern) then calls `get_save_data()` on every registered system and writes `save_slot_N.dat` — a crash/quit safety net for a DEFEAT-time state that is otherwise never durably written until the player next reaches Sanctuary or an autosave timer fires.

`save_persistence.gd`'s actual `_ready()` subscribes to exactly two signals: `mission_launched` and `scene_transition_completed`. There is no `mission_phase_changed` subscription anywhere in the file, and a project-wide grep for `GSavePersistence.save_slot(`/`GSavePersistence.save_checkpoint(` outside `save_persistence.gd` itself turns up nothing — no other file drives a save on DEFEAT either. Rule 9's mechanism does not exist in code today.

**Real consequence**: a player who reaches DEFEAT and then quits (or crashes) *without* first retrying or returning to Sanctuary loses that mission's resolved state — most concretely, `tower.md` Rule 24's `tower_destroyed` -> `tower_component_returned` -> Inventory `item_added(damaged: true)` cascade (the exact scenario Rule 9/EC-11/AC-13 were written to protect, per `save-persistence.md`'s own text) is not durably saved anywhere until a later, unrelated save trigger fires. In the common case (player retries immediately), this is masked: `retry_current_mission()` re-emits `mission_launched`, which re-triggers the already-shipped `_on_mission_launched()` -> `save_checkpoint()` path, and that checkpoint *does* capture current (post-cascade) state correctly (confirmed by this test's `test_retry_checkpoint_reflects_current_state_not_the_stale_original_launch`). The gap only bites the immediate-quit-after-DEFEAT path, which the checkpoint mechanism never touches.

This is also *why* the DEFEAT-save-then-retry "race" mission-select.md/save-persistence.md flagged as untested was untestable as originally framed — one side of the imagined race (a separate DEFEAT-triggered save) does not exist to race against.

### Recommended fix
Add a `mission_phase_changed` subscription to `save_persistence.gd`'s `_ready()`/`_exit_tree()` (matching every other Autoload's subscribe/unsubscribe pattern in this file), with a handler that checks `new_phase == "DEFEAT"` and defers exactly 1 frame (`call_deferred` or `await get_tree().process_frame`, matching Rule 10's existing `sanctuary_state_restored` deferral idiom already in this file) before calling `save_slot(_active_slot)`. Small, mechanical, fully specified by the GDD's own Rule 9/EC-11/AC-13 text — an implementation gap, not a design gap.

### Resolution
- [x] Fixed 2026-08-27 (same day, user approved implementing it). `save_persistence.gd`'s `_ready()`/`_exit_tree()` now subscribe/unsubscribe `GEventBus.mission_phase_changed`; a new `_on_mission_phase_changed()` handler checks `new_phase == "DEFEAT"` and calls `save_slot.call_deferred(_active_slot)` — the exact recommended fix, using the same `call_deferred` one-frame-defer idiom `sanctuary_state_restored` already established elsewhere in this file. No new fields, no new constants, no change to any other handler.
- [x] `tests/integration/mission-select/defeat-retry-checkpoint-race_test.gd` (already open from writing the original interaction test) extended with 2 new regression tests: `test_defeat_does_not_write_synchronously_but_does_write_after_one_frame` (proves the defer is real — not written immediately after the emit, written after one frame) and `test_defeat_deferred_save_captures_state_current_at_defeat_time` (proves the write actually persists a registered system's real state, round-tripped through `load_slot()`). The 3 pre-existing tests updated to emit the real `GEventBus.mission_phase_changed` signal (`_emit_defeat()` helper) instead of calling `MissionSelect`'s own handler directly, so `GSavePersistence`'s new real subscription is actually exercised, not bypassed.
- [x] Live-verified 2026-08-27 via Godot MCP against the real pinned 4.6.2.stable binary (`GSavePersistence.start_new_game(95)` → real `mission_launched`/DEFEAT emissions → inspected `user://saves/save_slot_95.dat` directly): confirmed `save_slot_95.dat` is absent immediately after DEFEAT and still absent immediately after an immediate retry, then present after one process frame — the defer is real, not merely asserted by the test harness's own mocking.
- [x] Full gdUnit4 suite re-run same day after the fix: 2355 test cases, 0 errors, 0 failures caused by this change (1 unrelated pre-existing failure in `monster_swarm_channel_test`, not touched).

## TD-save-005 — a retry's own crash-recovery checkpoint can be clobbered by a still-pending DEFEAT save from the attempt it superseded (investigated, accepted as correct-by-construction — no fix needed)

### Gap
Found 2026-08-27 while running (not just writing) the TD-save-004 regression tests. TD-save-004 made `save_persistence.gd` defer a real `save_slot()` write on `mission_phase_changed(DEFEAT)` via `call_deferred`. `save_slot()` itself has pre-existing Rule 5 "normal flow" behavior: any successful save deletes whatever pending checkpoint exists for that slot (already covered in isolation by `save_persistence_ec3_ec5_test.gd`'s `test_save_slot_deletes_a_pending_checkpoint_on_success`).

Sequence: DEFEAT fires -> Save & Persistence queues its deferred `save_slot()` write (not yet executed) -> the player immediately presses Retry -> `MissionSelect.retry_current_mission()` re-emits `mission_launched` -> Save & Persistence's pre-existing, synchronous `_on_mission_launched()` handler writes a FRESH checkpoint for the NEW retry attempt -> one frame later, the still-pending DEFEAT-triggered `save_slot()` finally executes, and its own Rule 5 cleanup deletes "the pending checkpoint for this slot" — which is now the retry's checkpoint, not the DEFEAT attempt's, since `save_slot()` has no way to distinguish "a checkpoint from the attempt I'm superseding" from "a checkpoint from a brand-new attempt that started after me."

**Real consequence, narrower than TD-save-004's**: the retried mission attempt has no crash-recovery checkpoint of its own for a brief window (until the next natural save event — autosave, Sanctuary return, or the *next* `mission_launched`). This is NOT the catastrophic case TD-save-004 fixed — the DEFEAT attempt's own full `save_slot_N.dat` write still lands correctly either way, so no resolved mission state is lost. It's a much smaller gap: a crash during the first few frames of a retried attempt has no checkpoint to recover from, when in the pre-TD-save-004 world (no DEFEAT-save at all) this specific scenario wasn't any different anyway.

Confirmed via `tests/integration/mission-select/defeat-retry-checkpoint-race_test.gd`'s `test_defeat_then_immediate_retry_in_the_same_call_stack_produces_no_error`, which documents and asserts this exact behavior (checkpoint absent, full save present) rather than silently asserting it away.

### Design decision (2026-08-27)
Two mechanical options were originally floated — a monotonic "supersede" counter to decide whose write wins, or cancelling the deferred DEFEAT save once a same-frame retry fires — but both solve a problem that turns out not to exist. **`save_checkpoint()` and `save_slot()` both call the identical, parameterless `_collect_save_data()` snapshot function** (confirmed by reading both call sites — `save_slot()` at line 174, `save_checkpoint()` at line 184 of `save_persistence.gd`). Neither embeds a timestamp, event source, or anything else that would make one call's output differ from another's. `retry_current_mission()` touches only `MissionRuntimeState`, which Rule 10 already excludes from every save payload — no registered system's *persisted* state changes between DEFEAT resolving and an immediate retry.

That means in the exact scenario this entry describes, the checkpoint that gets deleted and the full save that replaces it **contain byte-identical data**. The retried attempt loses nothing real: `load_slot()` (the other EC-3 recovery choice) already holds everything the checkpoint would have offered, because it's the same snapshot. The only user-visible difference is which of the two EC-3 recovery-dialog choices would be offered on next boot — and offering "load the main save" instead of "restore from checkpoint" when both point at identical data is not a regression worth engineering around.

**Decision: accept current behavior as correct-by-construction. No code change.** Building either mechanical fix (a supersede counter, or save cancellation) would add real complexity to guard against a data-loss scenario that this analysis shows cannot actually occur under the current save-payload model. If a future change ever makes `retry_current_mission()` (or anything else that can fire between DEFEAT and the deferred save flushing) mutate a *persisted* field, this reasoning would need to be re-checked — flagged here so a future reader knows exactly what assumption to re-verify, not just "trust it's fine."

### Resolution
- [x] Investigated 2026-08-27 — root-caused to `save_checkpoint()`/`save_slot()` sharing one deterministic, parameterless snapshot function; the two writes this entry worried about racing are provably identical in content whenever no persisted state changes in between (always true for an immediate DEFEAT->retry with no other player action). Closed as a non-issue rather than fixed as a bug.
- [x] Live-verified 2026-08-27 via Godot MCP against the real pinned 4.6.2.stable binary, independent of the gdUnit4 harness (`GSavePersistence.start_new_game(95)`, real `mission_launched`/`DEFEAT` emissions, real `MissionSelect.retry_current_mission()` call, direct `FileAccess`/`DirAccess` inspection of `user://saves/save_slot_95_checkpoint.dat` at each step). Reproduced exactly as predicted: checkpoint present right after DEFEAT, still present right after an immediate retry (the retry's own fresh write), then **gone** after one process frame once the deferred DEFEAT save lands.
- [x] `tests/integration/mission-select/defeat-retry-checkpoint-race_test.gd`'s `test_defeat_then_immediate_retry_in_the_same_call_stack_produces_no_error` and its class doc comment updated to state the accepted-behavior conclusion, not just describe the mechanism as an open question.

## TD-test-007 — `monster_swarm_channel_test.gd`: `RendererDummy` never backs `MultiMesh` per-instance readback — deterministic capability gap, not a race, not a code bug (root-caused AND fixed 2026-08-27)

### Gap (original, 2026-08-27 investigation)
Found while checking the one pre-existing failure left over from a prior session's gdUnit4 runs (`monster_swarm_channel_test.gd::test_hit_sets_and_the_frame_after_slightly_decays_swarm_hit_flash`). That pass live-verified the underlying production code is correct (reproduced the same scenario via Godot MCP against a real Vulkan/Forward+ renderer: `custom_g = 0.9074`, matching expected math and the test's own `[0.9, 1.0]` assertion) but only got as far as "likely a headless/RendererDummy MultiMesh interaction" — three CLI runs had produced varying failure counts (1, then 4, then 4) and a standalone repro attempt outside gdUnit4 had hung and was abandoned.

### Root cause (definitively confirmed, follow-up session 2026-08-27)

**It is not a race condition. It is a deterministic, unconditional capability gap in `RendererDummy`.**

Reproduced directly with an isolated `--headless -s` SceneTree script (`extends SceneTree`, no gdUnit4 involved) against the pinned `Godot_v4.6.2-stable_win64.exe` binary:

1. A bare `MultiMesh` (`use_custom_data = true`, `instance_count = 4`), 20 trials of `set_instance_custom_data()` immediately followed by `get_instance_custom_data()` on the same slot: **every single trial, every run (3 separate process invocations), returned the default `Color(0,0,0,1)`** — never the just-written value. 0/60 round-trips succeeded.
2. Waiting 1 frame, 3 frames, or calling `RenderingServer.force_draw()` before reading back made **no difference** — ruling out "hasn't been processed yet" as the mechanism. This is not a timing window; there is nothing to wait for.
3. Reading `MultiMesh.buffer` (the raw `PackedFloat32Array`) directly returned **empty** (`size() == 0`) even after `instance_count` was set and data written — the Dummy backend allocates no readable backing store at all.
4. Scope check: `set_instance_transform()`/`get_instance_transform()` on the same `MultiMesh` fails identically (written origin `(5,6,7)` read back as `(0,0,0)`). **This is not custom-data-specific — no per-instance `MultiMesh` state is readable under `RendererDummy`,** by design (it is a stub/null renderer with no GPU buffer to read from; writes are accepted as no-ops).

**Confirmed this is exactly what CI hits, and confirmed it is NOT what this dev machine hits by default**: running `addons/gdUnit4/runtest.sh` locally (Windows, real AMD GPU) shows the CLI actually initializes **Vulkan 1.4.315 - Forward+** even though the script passes `--headless` — `--headless` only suppresses the window; it falls back to `RendererDummy` only when no usable GPU/driver is found (this machine has one, so all 7 tests in the file pass locally, 0 failures — matches the original session's live-verification result). Forcing `--rendering-driver dummy` explicitly reproduced the exact CI failure signature: `test_hit_sets_and_the_frame_after_slightly_decays_swarm_hit_flash` fails with `Expecting: '0.000000' in range between '0.900000' <> '1.000000'` — i.e., the channel read back as the `RendererDummy` default, exactly as predicted from the isolated repro. GitHub Actions' `ubuntu-latest` runner (`.github/workflows/tests.yml`, `MikeSchulze/gdUnit4-action`) has no GPU, so it always falls through to `RendererDummy` — this dev machine's default local runs do not, which is why the failure was never seen outside CI/forced-dummy conditions.

**Reconciling the earlier "1 vs 4 failures, non-deterministic" observation**: given the readback gap is deterministic, exactly 4 of the 7 tests in this file must always fail under `RendererDummy` — the 4 that assert a *non-default* channel value (`test_hit_sets_and_the_frame_after_slightly_decays_swarm_hit_flash` [asserts g∈[0.9,1.0], default reads 0.0], `test_status_mask_set_while_a_dot_effect_is_active` [asserts b≈1.0], `test_status_mask_set_while_a_slow_effect_is_active` [asserts b≈1.0], `test_facing_variant_is_right_facing_moving_toward_positive_x` [asserts a≈0.0, default a=1.0]); the other 3 assert a value that happens to equal the Dummy default (0.0 or, for left-facing, 1.0) and pass by coincidence, not because the mechanism works. Separately (and this is itself worth recording): passing `--rendering-driver dummy` through `runtest.sh` was found to make gdUnit4's own CLI arg parser execute only 1 of the 7 test cases (always the first), regardless of where the flag is placed relative to `-a`. This is a second, independent flakiness source — if the original CI environment's actual invocation ever varies its flag set between runs (a wrapper action's own internal retry/argument handling, not something this investigation could inspect from outside GitHub Actions), that alone would produce exactly the "1 vs 4 tests actually executed" pattern observed, on top of the always-4-fail baseline once a test does run. Not chased further — the underlying `RendererDummy` capability gap is root-caused and sufficient to explain and fix the failure regardless of exactly how many of the 4 affected tests any given CI run happens to execute.

**Scope**: affects `monster_swarm_channel_test.gd` specifically, and by the same mechanism, any *future* test that reads back live `MultiMesh` transform or custom-data state via `get_instance_transform()`/`get_instance_custom_data()`/`.buffer` under headless CI with no GPU. No other current test in the suite does this. Production code (`MonsterManager`/`MonsterSwarmRenderer3D`/`MonsterSwarmBatch`) remains proven correct — confirmed twice now, independently, under two different real (non-Dummy) renderer paths.

### Fix implemented (2026-08-27, same-day follow-up)

Option 1 (CPU-side mirror) implemented in `src/core/visual_presentation/monster_swarm_batch.gd`: added `_slot_body_custom: Array[Color]`, a per-slot mirror of the last-written body custom data, updated in `register()`, `update()`, and both sides of `remove()`'s swap-remove copy (the swap-remove's own internal slot-copy previously read `_body_multimesh.get_instance_custom_data(last)` to relocate data — the exact same broken call, now sourced from the mirror instead, fixing a latent production-path dependency on GPU readback, not just the test's). Added a public `get_custom_data(handle) -> Color` accessor that resolves through the mirror, never `RenderingServer`.

`tests/integration/visual_presentation/monster_swarm_channel_test.gd`'s `_read_custom_data()` updated to call `batch.get_custom_data(handle)` instead of reaching into `_body_multimesh.get_instance_custom_data(slot)` directly.

**Verified fixed, not just plausible**: ran the file via `addons/gdUnit4/runtest.sh` with `--rendering-driver dummy` (forcing the exact CI-equivalent backend) — **7/7 passed, 0 failures** (previously, under the same forced-dummy conditions, this reproduced the CI failure deterministically). Also ran the full `tests/integration/visual_presentation/` suite normally (real renderer) to check for regressions: **75/75 passed, 0 errors, 0 failures**.

**Known residual, not fixed, scoped out deliberately**: `remove()`'s swap-remove still reads `_body_multimesh.get_instance_transform(last)`/`_shadow_multimesh.get_instance_transform(last)` (position, not custom data) directly from `RenderingServer` for its own internal copy — the same class of gap, dormant today because no current test exercises multi-entity swap-remove with a transform assertion under headless CI. Not mirrored in this pass to keep the fix scoped to what TD-test-007 actually needed; worth applying the identical pattern if a future test ever needs it.

### Resolution
- [x] Fixed 2026-08-27 — root cause definitively confirmed (`RendererDummy` never backs `MultiMesh` per-instance readback; deterministic, not a race) and the CPU-side-mirror fix implemented, verified fixed under forced `--rendering-driver dummy` (CI-equivalent), and verified zero regressions across the full `visual_presentation` integration suite.

## TD-tower-009 — `tower_blueprint_data.gd` has no `base_cost` field or T4 `placement_cost` cap validation, despite `tower.md` Formula 4 describing both (found 2026-08-27, fixed 2026-08-28)

### Gap
Found while authoring the 5 T3/T4 tower blueprints that closed `tower.md` OQ-4's coverage gaps (`design/gdd/tower-content-catalogue.md`). `tower.md` Formula 4 defines `placement_cost = round(base_cost × archetype_cost_factor × tier_cost_factor)`, with `base_cost` a standalone field in range `[10, 60]`, and a hard rule that any `tier = 4` Foundation must have `base_cost ≤ 30` — "a load-time error otherwise" (Formula 4, Edge Cases → Formula Boundary, added 2026-07-14 resolving OQ-11).

The shipped schema does not implement this at all: `FoundationComponent` (`src/core/tower/foundation_component.gd`) has no `base_cost` field, and `TowerBlueprintData` (`src/core/tower/tower_blueprint_data.gd`) stores `placement_cost` as a single directly-authored `int` with no derivation from `archetype_cost_factor`/`tier_cost_factor` and no T4 ceiling check anywhere — confirmed via `grep -rn "base_cost" src/` (zero matches) and reading both components' `validate()` methods in full (neither checks `placement_cost` against tier at all).

**Not currently causing a real bug**: every one of the 18 shipped blueprints (13 original + 5 authored 2026-08-27) happens to comply with the GDD's intended T4 ceiling — the two original T4 towers cost 28/30, the two newly-authored T4 towers cost 30/30 — but this is content-author discipline (matching precedent by eye), not an enforced invariant. A future T4 blueprint authored without checking precedent (by a human, or a future session working from `tower.md`'s text alone without also reading the actual `.gd` schema) could set `placement_cost` arbitrarily high with no load-time error to catch it, silently violating the GDD's own documented economic-balance intent (OQ-11's bimodal-affordability fix).

### Fix implemented (2026-08-28, `/design-review` re-review on tower.md)

Option 1 (match the GDD) implemented, per user decision. `FoundationComponent` (`src/core/tower/foundation_component.gd`) gained a real `base_cost: int` field with a doc comment explaining Formula 4's relationship to `placement_cost`, plus per-tier range validation.

**T4 floor deviation from the GDD's literal text, made explicitly and by user decision, not silently**: `tower.md` describes a single `base_cost` range `[10, 60]` for all tiers. Applying that literally to T4 (`tier_cost_factor = 4.0`) implies a minimum possible T4 `placement_cost` of 40 — but both pre-existing shipped T4 towers (`siege_cannon`=28, `firestorm_spire`=30, before this fix) were already below that floor. Rather than silently re-costing shipped content upward by 33-43% (a real balance change) or silently picking a lower floor, this was surfaced to the user directly; the user chose to lower T4's floor to `7` (matching what `siege_cannon` already needed) rather than raise existing tower costs. Implemented as a tier-conditional range in `FoundationComponent.validate()`: `[10,60]` for T1-T3, `[7,30]` for T4.

All 18 blueprints (13 original + 5 authored 2026-08-27) migrated to add `base_cost`, computed backward from their existing `placement_cost` via Formula 4's own math. 14 of 18 needed no other change (`base_cost × archetype_cost_factor × tier_cost_factor` already rounded exactly to their existing `placement_cost`). 4 needed a ±2 gold `placement_cost` adjustment because integer `base_cost` × their `tier_cost_factor` couldn't land exactly on the original value: `warbreaker` 25→26, `firestorm_spire` 30→32, `railgun_emplacement` 30→32, `grand_rally_spire` 30→28 — all 4 are towers authored in this same session (2026-08-27), not long-shipped content, so this is a same-day design-value correction, not a retroactive balance change to established content.

**Real regression found and fixed, not glossed over**: the Formula 4 cross-check (`placement_cost == round(base_cost × archetype_cost_factor × tier_cost_factor)`) was first added directly inside `TowerBlueprintData.validate()`. A full-suite gdUnit4 run caught a real break: `tower_assembly_test.gd::test_assembled_blueprint_is_immediately_registered_and_placeable` failed, because `TowerAssembly.assemble_tower()` (`src/core/tower_assembly/tower_assembly.gd`, a player-facing "quick-spec" feature) computes `placement_cost` via its own, intentionally *different* formula (`BASE_ASSEMBLY_COST × tier_cost_factor × 1.75`, an assembly markup unrelated to Formula 4) from the same `FoundationComponent.base_cost` the source component carries — a legitimate, pre-existing design, not a bug. Folding the Formula 4 check into the general-purpose `validate()` broke this real feature. **Fix**: the cross-check was moved out of `validate()` into a new, separately-callable `TowerBlueprintData.validate_placement_cost_matches_formula_4()`, wired only into `GameDataRegistry._load_tower_blueprints()` — the actual content-load boundary Formula 4 is about — leaving `validate()` itself (and everything that calls it, including `TowerAssembly`) unaffected.

**Verified, not just implemented**: a headless load-and-validate script confirmed all 18 blueprints load and pass both `validate()` and `validate_placement_cost_matches_formula_4()` with zero errors after migration. The exact 4 AC boundary scenarios `tower.md`'s own Acceptance Criteria specify were independently constructed and checked against `FoundationComponent.validate()` directly: `tier=4, base_cost=35` → load-time error (correct, above the new 30 ceiling); `tier=4, base_cost=30` → no error (correct, at the ceiling); `tier=3, base_cost=55` → no error (correct, T3 isn't T4-capped); `tier=1, base_cost=9` → load-time error (correct, below the general 10 floor). After the `TowerAssembly` fix: `tests/unit/tower/` (74/74), `tests/unit/tower_assembly/` (15/15), `tests/unit/game_data_registry/` (45/45), and the full `visual_presentation` integration suite all pass clean. A full-suite run afterward showed one further failure in an unrelated file (`mission_scene_test.gd`) that reproduced as a clean pass when re-run in isolation — consistent with this project's known full-suite-only test-ordering flakiness (see `TD-test-006`), not caused by this change.

### Resolution
- [x] Fixed 2026-08-28 — `base_cost` field added, T4 floor lowered to `[7,30]` by explicit user decision (not silently re-costing shipped towers), Formula 4 cross-check added at the correct boundary (content-load, not general `validate()`) after a real regression against `TowerAssembly` was caught and fixed, all 18 blueprints migrated and re-verified, and the GDD's own 4 boundary-case ACs independently confirmed behaving correctly.

---

## TD-hero-skill-002 — 4 of 13 skill-modifier items can't be expressed by Rule 13's `requires_tag: String` schema; effect application is entirely unbuilt (schema gap fixed)

**Logged**: 2026-09-02 (found while closing `hero-skill-build.md`'s own flagged `skill_modifier` item_type gap, user-approved full implementation)
**Severity**: Medium — 9 of 13 catalogued items are real, equippable, correctly-gated content; the other 4 are simply absent (not faked with a wrong gate), and none of the 13 mechanically do anything yet.
**Area**: `assets/data/items/sup_mod_*.tres`, `src/core/inventory/item_definition_resource.gd` (`requires_tag`), `src/core/hero_skill_build/hero_skill_build.gd` (`get_effective_passive_loadout()`), `design/gdd/hero-skill-build.md` Rule 13/14

### Gap

Rule 13 (revised 2026-09-01) specifies `requires_tag: String` as "one of the 8 tag values Rule 2's `effect_data.tags` uses, or `\"any\"`" — a single-axis, tag-membership-only compatibility check. Rule 14's own 13-item catalogue table doesn't actually stay within that schema: 9 items genuinely key off a tag (`Projectile`×2, `Area`×2, `Melee`×2, `Totem`, `Channeling`, `any`) and were authored as real `ItemDefinitionResource` `.tres` files (`sup_mod_multiple_projectiles`, `sup_mod_chain`, `sup_mod_increased_aoe`, `sup_mod_faster_casting`, `sup_mod_concentrated_effect`, `sup_mod_ruthless`, `sup_mod_fortify`, `sup_mod_totem_life`, `sup_mod_spell_echo`). The remaining 4 key off a *different* field entirely, which `requires_tag` cannot represent without misrepresenting the design: `sup_mod_elemental_focus` ("any non-`physical` `damage_type`"), `sup_mod_vile_toxins` (`secondary_effect` = `dot_poison` or `dot_burn`), `sup_mod_immolate` (`damage_type` = `fire`), `sup_mod_arcane_surge` (`damage_type` ∈ {`lightning`,`frost`,`fire`,`arcane`}) — none of these are tag values, and one (`arcane_surge`) is even multi-valued. Authoring these 4 as `requires_tag = "any"` would silently make them universally equippable, contradicting the design table's actual restriction — worse than leaving them unauthored, so they were not created.

**Also found, same investigation**: even for the 9 real items, nothing anywhere folds a skill-modifier's actual mechanical effect (the catalogue table's "Effect" column — e.g. "+2 projectiles; −20% `skill_power_coefficient` per added projectile") into a skill's `effect_data` at cast time. `HeroSkillBuild.get_effective_passive_loadout()` only resolves which item_ids are validly equipped (Rule 12's "additive-bucket-then-emit pattern" is named but not implemented for this input). The 9 real items are correctly typed, gate-checked at equip time (`HeroSkillBuild._is_skill_modifier_compatible()`, added this same pass), and inventory-visible — but mechanically inert.

### Recommended fix

1. Extend `requires_tag`'s schema (or add a second field, e.g. `requires_condition: String` with a small `field:value` grammar) so `damage_type`/`secondary_effect` conditions can be expressed without overloading the tag axis — a design/schema decision for whoever owns Rule 13 next, not a unilateral pick.
2. Author the 4 remaining items once the schema question above is resolved.
3. Design and implement the actual effect-folding pipeline for all 13 (or 9, if the schema question is deferred) — likely a new step in `HeroSkillBuild`'s effective-loadout resolution, folding each equipped modifier's stat delta into a copy of the socketed skill's `effect_data` before it reaches Damage & Status's Formula D7. This is real combat-math scope, not a data-authoring task.

### Resolution
- [x] 9 of 13 items authored and equip-time-gated (2026-09-02) — see Gap section above for the full list and reasoning.
- [x] **Schema decision made and implemented (2026-09-02, user-approved)**: added two sibling gating axes to `ItemDefinitionResource` — `requires_damage_type: Array[String]` and `requires_secondary_effect: Array[String]` — alongside the existing `requires_tag: String`. Exactly one of the 3 must be set per skill-modifier item (validated), matching Rule 14's own table where each item has exactly one stated condition; array-typed (not a single String) so multi-valued conditions like `sup_mod_arcane_surge`'s 4-element damage_type set are representable without inventing sentinel keywords. `HeroSkillBuild._is_skill_modifier_compatible()` extended to check whichever axis is populated. All 4 remaining items authored: `sup_mod_elemental_focus` (`requires_damage_type = [fire, frost, poison, lightning, arcane]`), `sup_mod_immolate` (`[fire]`), `sup_mod_arcane_surge` (`[lightning, frost, fire, arcane]`), `sup_mod_vile_toxins` (`requires_secondary_effect = [dot_poison, dot_burn]`). All 13 catalogued skill-modifier items now exist as real, equip-gated content.
- [ ] Effect-folding pipeline not designed or implemented — all 13 items are currently equip-only, mechanically inert. This is real combat-math scope (folding each equipped modifier's stat delta into a copy of the socketed skill's `effect_data` before Damage & Status's Formula D7), not a data-authoring task — this entry stays open for that alone.

---

## TD-hero-006 — Hero's live combat read the wrong skill catalogue — all 32 real, player-equippable skills dealt zero damage (fixed)

**Logged**: 2026-09-02 (found while scoping the skill-modifier effect-folding pipeline, at user's request)
**Fixed**: 2026-09-02 (same session, user-approved)
**Severity**: Critical — a real, shipped, silent production bug, not a hypothetical. Every skill in the actual player-facing 32-skill catalogue (`assets/data/skills/definitions/`, built out this session) dealt zero damage in live combat, and used a wrong, always-floored 0.5s cooldown, since neither existed in the catalogue Hero.gd was actually reading from.
**Area**: `src/core/hero/hero.gd` (`_ready()`'s self-populate block, `_resolve_skill_hit()`), `src/core/skill_definition_resource.gd` (new `base_cooldown` field), `assets/data/skills/definitions/*.tres` (32 files)

### Gap

`Hero._resolve_skill_hit()` (the function that builds and emits `HeroSkillAttackEvent`, the trigger for Damage & Status's Formula D7) called `GGameDataRegistry.get_skill_resource(skill_id)` — this reads the **legacy `SkillResource` catalogue** (`assets/data/skills/*.tres`: `fireball`, `earth_slam`, `frost_nova`, `chain_lightning` — 4 skills, predates this session's 32-skill catalogue and TD-hero-002's original MVP scope). It does not read `SkillDefinitionResource` (`assets/data/skills/definitions/*.tres`), the real catalogue Hero Skill Build actually manages, equips, and that skill-modifier items (Rule 13) gate against.

There is **zero `skill_id` overlap** between the two catalogues (confirmed by directory listing — the real catalogue is entirely `phys_*`/`rng_*`/`elem_*`/`sup_*`-prefixed). The result: `get_skill_resource(skill_id)` returned `null` for all 32 real skills, and `_resolve_skill_hit()` returned early before ever emitting `hero_skill_attacked` — every equipped skill cast silently whiffed, dealing 0 damage, with no error logged. `Hero._ready()`'s self-populate block had the identical bug for `_skill_cooldowns` (sourced from `get_all_skill_resources()`), so every real skill's `base_cooldown` lookup also missed and fell back to `0.0`, making `activate_skill()`'s CDR formula (`max(0.5, base * (1-cdr))`) always floor to a flat 0.5s regardless of the skill's actual intended pacing.

No test caught this: the only existing skill-cooldown self-populate test asserted against `"fireball"` (a legacy catalogue skill_id, still valid against the wrong-but-consistent old code) rather than any real catalogue skill_id, and no test anywhere exercised `_resolve_skill_hit()`'s actual payload construction against real content at all.

**Not a design-document bug** — `damage-status.md`'s Formula D7 documentation always correctly stated `skill_power_coefficient` is "read from the cast skill's `effect_data`" (i.e. `SkillDefinitionResource.effect_data`, the real catalogue). Only the code was wrong.

### Fix applied

1. Added `base_cooldown: float` to `SkillDefinitionResource` (with `validate()` rule, `must be > 0.0`) — this catalogue is now the single, correct source of truth for a skill's full activation contract (cooldown + damage), matching its own doc comment's "shared skill catalogue entry" framing. Authored real, per-tier structural-placeholder values on all 32 `.tres` files: opener 4.0s, core 6.0s, capstone 10.0s (matches the legacy catalogue's own historical 3.0–8.0s spread; not yet through a dedicated balance pass, same precedent as `skill_power_coefficient`).
2. `Hero._ready()`'s self-populate block now reads `GGameDataRegistry.get_all_skill_definitions()`/`get_skill_definition()` instead of the legacy `get_all_skill_resources()`/`get_skill_resource()`.
3. `Hero._resolve_skill_hit()` now reads `GGameDataRegistry.get_skill_definition(skill_id)` and `skill.effect_data.skill_power_coefficient` instead of the legacy `SkillResource` path.
4. Legacy `SkillResource` (`assets/data/skills/*.tres`, the class itself, `GameDataRegistry.get_skill_resource()`/`get_all_skill_resources()`) is left in place, now fully unreferenced by production code — flagged as a candidate for a future deletion pass, not removed here (out of scope for a bug fix).
5. Tests: `tests/unit/hero/hero_skill_system_test.gd`'s 2 self-populate tests switched from `"fireball"` to `"phys_cleave"` (a real catalogue skill_id, `tier="opener"` → `base_cooldown=4.0`, which happens to match the old fixture's expected value exactly, so assertion numbers are unchanged). Added 2 new tests exercising `_resolve_skill_hit()`'s payload construction against real content for the first time — `test_activate_skill_emits_hero_skill_attacked_with_real_catalogue_skill` (confirms `hero_skill_attacked` actually fires with `phys_cleave`'s real `skill_power_coefficient=1.2`) and `test_activate_skill_with_no_target_in_range_does_not_emit_hero_skill_attacked` (the whiff path).

### Resolution
- [x] Fixed 2026-09-02 — see Fix applied above.
- [x] New/updated test coverage added, closing the real gap that let this ship undetected.
- [x] Targeted gdUnit4 regression run 2026-09-02: `tests/unit/hero`, `tests/unit/game_data_registry`, `tests/unit/hero-skill-build`, `tests/integration/hero-skill-build`, `tests/integration/hero-skill-build-screen` — 194/194 passing, 0 errors, 0 failures. 37 orphans, isolated to `game_data_registry_test.gd` alone (unmodified by this fix) — confirmed pre-existing baseline noise, not a regression, matching this project's own established TD-test-001/002/004/006 precedent for that suite.
- [x] This entry closed (2026-09-02).

---

## TD-hero-skill-003 — Damage-classification reclassification pass: open items not yet decided (fixed)

**Logged**: 2026-09-04 (player-directed reclassification of Hero skill damage types)
**Severity**: Low — content-authoring completeness gap, not a bug. Nothing shipped is broken; some real content (`poison`, used by `elem_poison_nova`) simply carries no classification tags yet.
**Area**: `src/core/hero_skill_effect_resource.gd` (`VALID_TAGS`, `VALID_DAMAGE_TYPES`), `assets/data/skills/definitions/*.tres`

### What landed this pass

Player-directed reclassification of Hero skill damage types into a tag-based taxonomy (own `tags` array, not a separate lookup table):
- **Basic Elemental** (fire, water, earth, wind): own name + `Basic` + `Elemental` + `DifferentDamage`. Only `fire` has real content today (3 skills) — water/earth/wind added to nothing yet, no content authored.
- **Advanced Elemental** (ice, lightning, light, dark, solar, steam, spark): `Advanced` + `Elemental` + `DifferentDamage`, no self-name tag. `ice` (renamed from `frost` — same type, name only) and `lightning` have real content (5 skills total); light/dark/solar/steam/spark have none yet.
- **Magic** (arcane): `Basic` + `Magic` + `DifferentDamage`, no self-name tag. No skill currently authors `arcane` as its `damage_type` — classification is ready, unused.
- `physical` and `""` (non-damage support/buff skills): no classification tags — this is the deliberate baseline `DifferentDamage` is relative to.
- `frost` → `ice` renamed everywhere it appeared for Hero skills (`HeroSkillEffectResource.VALID_DAMAGE_TYPES`, the 3 affected skills' `damage_type`, and the 2 skill-modifier items — `sup_mod_elemental_focus`, `sup_mod_arcane_surge` — whose `requires_damage_type` arrays included it). **Tower's own `WeaponComponent.element` still uses `frost`** — deliberately not touched, out of scope for this pass (player asked to rework skill classifications, not tower weapons).

### Resolved 2026-09-08 (player decisions)

- **`poison`'s classification**: **Basic Elemental**, same treatment as fire. `elem_poison_nova.tres`'s `tags` now reads `["Area", "Poison", "Basic", "Elemental", "DifferentDamage"]` (was `["Area"]`).
- **`bleed` (still a future, not-yet-authored `damage_type`)**: **Physical + a new `DoT` tag**, not `Physical` alone. `DoT` added to `HeroSkillEffectResource.VALID_TAGS` in advance of that content — no skill carries it yet, since neither `bleed` nor `haemorrhage` has a `damage_type` value or any authored content.
- **`haemorrhage`**: still named only as a future "advanced" version of bleed — no `damage_type` value, no content, not scoped. Unaffected by this pass.
- **`ItemDefinitionResource.VALID_REQUIRES_TAGS`** (skill-modifier `requires_tag` compatibility) still intentionally does NOT include the classification tags (Fire/Basic/Elemental/Poison/DoT/etc.) — no skill-modifier currently needs to gate on a damage classification. Unchanged by this pass; extend if one ever does.

### Resolution
- [x] Confirmed portion implemented and tested 2026-09-04 (287/287 passing, 0 errors, 0 failures) — see "What landed this pass" above.
- [x] `poison` classification resolved and implemented 2026-09-08 — Basic Elemental.
- [x] `DoT` tag added to `VALID_TAGS` 2026-09-08 (bleed/haemorrhage still have no content to apply it to).
- [x] Entry closed — no further open items.

---

## TD-tower-010 — Tower HP never reset between waves; `tower_wave_summary` never emitted at all (fixed)

**Logged**: 2026-09-05 (found while implementing a fork-subagent survey finding, fixed same session)
**Severity**: High — a real, live gameplay bug, not just missing telemetry. `tower_system.gd` had no `wave_completed` subscription anywhere in the file; `TowerMissionState.current_hp` was only ever set once, at placement (`current_hp = max_hp`). Boss damage taken by a tower in one wave carried over permanently into every subsequent wave for that tower's entire mission lifetime, directly contradicting `tower.md` Rule 23's own text ("a tower that survives a wave at 1 HP begins the next wave at full HP"). The `tower_wave_summary` event itself (payload class `TowerWaveSummary`, `src/foundation/event_bus/event_payloads/tower_wave_summary.gd`, already fully built) was never emitted by anything, so no downstream consumer could ever have observed a tower's per-wave engagement stats either.
**Area**: `src/core/tower/tower_system.gd`, `src/core/tower/tower_mission_state.gd`

### Gap

A fork-subagent survey (dispatched to hunt for "GDD says X, code does Y" bugs in systems not otherwise touched this session, matching `TD-hero-006`'s class) flagged that `tower_wave_summary` is never emitted. Investigating the emission gap surfaced a larger root cause: `_on_wave_started()` existed (resetting SCATTER's `scatter_index`/`last_scatter_target_id`), but no `_on_wave_completed()` handler, and no `GEventBus.wave_completed` subscription, existed anywhere in `tower_system.gd` — confirmed by grepping the whole file for `wave_completed` and for every `current_hp =` assignment (exactly one hit, at placement). Rule 23 bundles both halves as one rule: HP resets to Foundation-defined max on `wave_completed`, AND the Tower System emits `tower_wave_summary` once per active tower immediately after that reset — neither half was implemented.

### Fix implemented (2026-09-05)

- `TowerMissionState` (`tower_mission_state.gd`) gained 5 new per-wave counters: `shots_fired`, `damage_dealt`, `idle_ticks`, `aura_applications_this_wave` (Support/AURA only), `scatter_target_cycle` (SCATTER Focus only, `Dictionary[int,int]` entity_id→hit_count).
- `tower_system.gd` now subscribes to `GEventBus.wave_completed` in `_ready()`/unsubscribes in `_exit_tree()`.
- `_on_wave_started()` extended to also reset the 5 new counters (mirrors the existing SCATTER reset).
- New `_on_wave_completed()` handler: for every active tower, resets `current_hp = max_hp`, then constructs and emits a fully-populated `TowerWaveSummary`.
- `_try_attack()` now increments `idle_ticks` on both no-valid-target paths, `aura_applications_this_wave` on the AURA branch, and calls a new `_record_shot()` helper (increments `shots_fired`/`damage_dealt`, and `scatter_target_cycle` for SCATTER towers) only on a confirmed successful fire (after `ProjectileManager.fire()` succeeds for BALLISTIC/HOMING, or immediately for BEAM).
- `_apply_splash_damage()` adds splash damage to `damage_dealt` (not to `shots_fired`/`scatter_target_cycle` — splash is real damage but not itself a distinct shot, per Rule 23's own AC wording).

### Resolution
- [x] Fixed 2026-09-05 — HP-reset mechanic and `tower_wave_summary` emission both implemented and wired together, matching Rule 23's bundled contract.
- [x] Regression tests added `tests/unit/tower/tower_wave_summary_test.gd` covering: HP reset after damage, counter accuracy (`shots_fired`/`idle_ticks`/`damage_dealt`), counter reset on the next `wave_started`, AURA/SCATTER-specific fields, and one-summary-per-active-tower.

---

## TD-test-008 — Running the test suite overwrote the player's real save slot and settings (fixed)

**Logged**: 2026-10-04 (found during the full smoke check, fixed same session)
**Severity**: High for developers/playtesters — every full gdUnit4 run silently rewrote `user://saves/save_slot_0.dat` (shown in-game as Slot 1) and `user://audio_settings.cfg`/`display_settings.cfg` in the real game profile, because `SavePersistence`, `AudioSystem` and `MainMenu` built their paths from hardcoded `user://` constants that tests shared.
**Area**: `src/foundation/user_data_paths.gd` (new), `save_persistence.gd`, `audio_system.gd`, `main_menu.gd`, 7 test files

### Fix
New `UserDataPaths.root()` returns `user://` normally and `user://test_sandbox/` when the process was launched by a gdUnit4 runner (detected from the command line: local runner, CI `GdUnitCmdTool.gd`, editor panel). The path constants became `static var`s with unchanged names, so every `SavePersistence.SAVE_PATH % slot` caller compiles unchanged. Tests that hardcoded `"user://saves/..."` now build paths from the same root. Verified: a 304-test save/audio/main-menu run left the real profile byte-for-byte untouched and wrote only under `test_sandbox/`.

---

## TD-menag-007 — Every Lure charged its cost twice; crafting could consume Menagerie Lures as generic Material (fixed)

**Logged**: 2026-10-04 (found live during the smoke check, fixed same session)
**Severity**: High — economy. (1) `Menagerie.lure_creature()` called `GInventory.consume_stackable()` AND emitted `materials_spent`, which `Inventory._on_materials_spent()` also consumes on — live: 11 lures minus two Tier-1 lures (3 each) left 2, not 5. (2) `menagerie_lure` shares `item_type = "Material"`, so `has_items()`/`consume_by_type()` counted and consumed lures for any `"Material": N` recipe, though `menagerie.md` Rule 2 reserves them for the Lure action. (3) The Lure action itself had no UI caller anywhere — the backend was tested but a player could never acquire a creature.
**Area**: `menagerie.gd`, `inventory.gd`, `item_definition_resource.gd`, `menagerie_lure.tres`, `menagerie_screen.gd`, `inventory_screen.gd`

### Fix
(1) Removed the direct consume — `materials_spent` is the consume step, as `materials_wiring_test` already pinned. (2) New data flag `ItemDefinitionResource.excluded_from_type_costs`, set on `menagerie_lure.tres`, honored by `has_items()`, `consume_by_type()`, the crafting panel's owned totals and its craft-preview highlight. (3) Menagerie screen gained a Lure panel (one button per species with its Formula 4 cost, disabled when unaffordable) plus an empty-roster hint. Regression tests: `reserved_item_type_cost_test.gd`, `lure_acquisition_test.gd::test_lure_creature_charges_the_cost_exactly_once`. `mixed_vocabulary_recipe_inputs_test.gd` used lures as its "rarity-less Material" fixture; switched to an injected synthetic material.

---

## TD-tower-011 — `TowerMissionState.top` defaulted to null; `_try_attack()` reads it unguarded (fixed)

**Logged**: 2026-10-04 (the only failing test in the full smoke-check suite run)
**Severity**: Medium — `combat_loop_test.gd` built its state directly and crashed with 10 script errors per run; any future restore path that builds a state outside `place_tower()` would crash the same way. `shaft`/`top` now default to inert `ShaftComponent.new()`/`TopComponent.new()`; `place_tower()` still overwrites both.

---

## TD-test-009 — `hero_damage_chain_test.gd` errors ("Trying to cast a freed object") only when run after `tests/unit/visual_presentation` (open)

**Logged**: 2026-10-04
**Severity**: Low — test hygiene, not a product bug. Order-dependent: 3 errors raised inside gdUnit4's `GdUnitOrphanNodesMonitor.gd:202` when this suite runs after the visual-presentation unit suites; 0 errors in isolation, and reproduced identically with all 2026-10-04 changes stashed (pre-existing). Likely cause: its `after_test()` frees `MonsterEntity` nodes directly while another structure still references them. Not seen in the default full-suite ordering.

---

## TD-perf-002 — Texture memory is ~850 MB because generated art ships at native generation resolution (RESOLVED 2026-10-06)

**Resolved**: 9d592d3 — import `process/size_limit` per category (items/towers/monsters/species 256, tarot 384, terrain 512, hero 768); live mission texture memory 847 → 115.5 MB. **Side effect found 2026-10-07**: per-texture caps scale each tower Base/Shaft/Top layer by a different factor, splitting placed towers into 3 pieces; fixed in ee3c21a (`TowerInstance.LAYER_SOURCE_MAX_DIMENSIONS`, see `design/art/codex-art-overhaul.md` §5.5). `Hero.tscn` Sprite2D scale is now 0.078125 (mission hero enlarged 1.5×), not the 0.052083 quoted below.

**Logged**: 2026-10-04 (live `Performance` sample during The Gap: `RENDER_TEXTURE_MEM_USED` 847 MB of 894 MB VRAM; static RAM ~100 MB; 60 FPS; 84 draw calls)
**Severity**: Low today — fits the reference GPUs (6–8 GB) and the 1 GB budget is a RAM ceiling — but it grows with every new asset. Sprites displayed at ~64 px are uploaded at 1000–1500 px (e.g. `hero_warden_smith.png` 1024×1536, tower parts ~1000 px, `mission_frame_background.png` 1672×941). `animation-pipeline.md` §4 deliberately keeps Lossless/no-mipmaps, so GPU compression is not the lever.
**Suggested fix**: add a downscale-to-~2×-display-size step to Claude Code's art processing pass (the alpha-cut step already owns `assets/art/`), and re-derive the one hand-tuned Sprite2D scale (`Hero.tscn`, `0.052083 = 80/1536`). Code that sizes by `texture.get_height()` (12 sites) adapts automatically.

---

## TD-ui-003 — Main-menu modal overlays (Settings, Load Game, overwrite/recovery confirms) use unthemed default controls (open)

**Logged**: 2026-10-04
**Severity**: Low — functional and legible (96%-opaque dim), but plain default buttons/sliders over a dark dim read as unfinished next to the painted menu buttons. Deferred to a UI theme pass because the visual direction for UI chrome is not locked (`CLAUDE.md` Asset Generation); not invented ad hoc.

# Tech Debt Register

Tracks known technical debt, test coverage gaps, and deferred architectural work.
Items are resolved by creating a follow-up story and linking it here.

---

## TD-menag-006 — `test_lure_creature_success_full_flow` fails in isolation (AC-2 placement state)

**Logged**: 2026-07-18 (Sprint 6, S6-08 — found running the full suite for the first time this session, unrelated to any S6-08 change)
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

## TD-test-004 — Full-suite orphan-node count grew sharply after Sanctuary UI screen work (158 → 2258, partially fixed → 1343, residual narrowed to a `mission_launched` cross-Autoload interaction in `tests/unit/tower/`)

**Logged**: 2026-07-25 (autonomous overnight session — Menagerie/Defense Building screens + `SanctuaryScene.tscn` real-shell wiring)
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
- [ ] This entry closed — reopened as a smaller-scoped follow-up (2 of at least 3 contributors found and fixed; the residual ~1343-orphan count needs its own dedicated bisection pass)

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
- [ ] This entry closed — kept open: step (d) material consumption is still unimplemented

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

## TD-econ-007 — Combined-ERI validator (Story 015) cannot fail for any realistic content

**Logged**: 2026-07-16
**Story**: Discovered during Story 015 (Combined-ERI Content-Authoring Validator) code review, via qa-tester's testability review
**Severity**: Low-Medium — not a code defect, but the story's stated deliverable (a content-authoring safety net) may currently have near-zero practical value
**Area**: `src/core/resource_economy/combined_eri_validator.gd`, `design/gdd/resource-economy.md` Formula 4

### Gap

Story 015 built `CombinedEriValidator` to catch content authored with an unreasonably generous quantity/quality combination (Formula 4, `combined_ERI > WAVE_ERI_CEILING_COMBINED × ROUNDING_TOLERANCE`). Formula 4 itself was independently corrected on 2026-07-14 (see the GDD's own "Corrected during `/design-review`" note) — the corrected formula is mathematically bounded to a maximum of `23.84` for any `DropEntry` authored within Formula 3's stated range (`base_quality_probability` 0.05–0.15), confirmed by an exhaustive property-sweep test in `tests/unit/resource_economy/combined_eri_validator_test.gd`.

The only inputs that can trigger a failure are: (a) a degenerate `base_quality_probability=0.0`, which a schema-level `DropEntry.validate()` check could arguably already catch, or (b) an extreme `guaranteed_min_quantity` distortion — verified via a dedicated test to only *lower* the result further, never push it past the ceiling. Both were logged as new tests during this story's code review to make the finding explicit and regression-proof rather than silent.

This means the validator, as currently specified by the (now-corrected) GDD, cannot meaningfully catch the "plausible but overly generous" authoring mistake it was originally built to guard against — its real-world guardrail value is currently near zero for the input space content authors would actually produce.

### Recommended fix

Not resolved here — this is a design-judgment call (belongs to game-designer/qa-lead, tracked as a new Open Question in `design/gdd/resource-economy.md`), not something to redesign unilaterally during implementation. Options for a follow-up: (1) accept the check as a defense-in-depth guard against degenerate/malformed content only, and rescope its documented purpose accordingly; (2) redesign Formula 4 a second time with different bounds now that the corrected version's practical ceiling is understood; (3) decide the check is no longer worth maintaining and fold its concerns into `DropEntry.validate()`'s existing schema checks instead.

## TD-econ-006 — `monster_died`/`monsters_died_batch` exclusivity invariant has no verifying test

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
- [ ] Pause mechanism decided (engine-native `SceneTree.paused` vs. custom EventBus-driven)
- [ ] Implemented and wired to Pause Menu once that screen is built
- [ ] Verified functional in every mission phase, no exceptions
- [ ] This entry closed

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

## TD-monster-003 — Spawned MonsterEntity nodes never added to the scene tree

**Logged**: 2026-07-03
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

## TD-monster-004 — AC-28/AC-40 field-scale active-agent performance never measured (real profiler required)

**Logged**: 2026-07-10
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
- [ ] Real profiler evidence captured for AC-28 (150 active monsters, 60 frames, ≤2.0ms)
- [ ] Real profiler evidence captured for AC-40 (AoE variant, per its own GDD text)
- [ ] Evidence files saved to `production/qa/evidence/` per the GDD's literal path spec
- [ ] This entry closed

---

## TD-wave-001 — WaveManager registered at the wrong Autoload boot position

**Logged**: 2026-07-03
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

## TD-tower-002 — Tower test suites leak orphan Node instances

**Logged**: 2026-07-03
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

## TD-path-001 — AC-4 profiler test measures cold fallback path, not warm template lookup

**Logged**: 2026-07-03
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

## TD-test-001 — `assert_error(func...).is_push_error(...)` leaves orphan nodes

**Logged**: 2026-07-03
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

---

## TD-test-002 — "3 resources still in use at exit" after SceneManager tests

**Logged**: 2026-07-03
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

## TD-hero-001 — Tower Affinity bonus not yet applied to Damage/Skill Power (Damage half fixed)

**Logged**: 2026-07-04
**Damage half fixed**: 2026-07-08
**Story**: S4-12 Hero Tower Affinity (`production/epics/epic-02-core-combat/story-005-hero-tower-affinity.md`)
**Severity**: Advisory
**Area**: `src/core/hero/hero.gd` (`_apply_tower_affinity_bonus`, `_on_attack_timer_timeout`)

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
- [ ] Skill Power path updated to fold in tower_affinity — **still blocked**: grep-confirmed `skill_power` (`src/core/hero/hero.gd`, `the_gap.gd`) has zero consumers anywhere in the codebase; it is only ever set as a stat default, never read. Nothing exists yet to fold this bonus into. Remains open until a future system (Skill data pipeline, `TD-hero-002`) gives Skill Power a real consumer.
- [x] Regression test added covering the combined effect (2026-07-08): `tests/unit/hero/hero_auto_attack_test.gd` — `test_attack_timeout_folds_tower_affinity_bonus_into_base_damage` (4 qualifying towers, 100 damage → 150 with the bonus applied) and `test_attack_timeout_zero_tower_affinity_leaves_base_damage_unchanged` (no towers → unchanged). Full hero suite 57/57 passing, 0 orphans; `tests/integration/hero` + `tests/unit/damage_status` re-run clean (1 pre-existing unrelated failure, `hero_lifecycle_test.gd` AC-13, `TD-hero-005` — confirmed unaffected by this change).
- [ ] This entry closed — narrowed to the Skill Power half only; re-close once that half has a real consumer to wire into.

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

## TD-hero-004 — No registry preventing SaveRestorer `restore_order` collisions (docs fixed)

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
- [ ] Second SaveRestorer implementor's order verified against the reference — **still genuinely blocked**: Hero remains the only registered implementor anywhere in the codebase. ADR-0003's "runs after Foundation, before Feature layer" ordering claim stays structurally unverified until a second system actually registers. Narrowed rather than force-closed, same pattern as `TD-hero-001`'s Skill Power half.
- [ ] This entry closed — will close once a second implementor registers and its order is checked against the reference table above.

---

## TD-data-001 — MonsterManager and TowerSystem have no production data loader

**Logged**: 2026-07-05
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
- [ ] Dedicated regression test added to `tests/integration/wave_manager/` asserting `_wave_spawn_entries` is populated from a real (non-injected) `_wave_config` at `WAVE_ACTIVE` entry (partially covered by `tests/integration/mission_scene/mission_scene_the_gap_test.gd`'s end-to-end assertion; a WaveManager-suite-local unit test is still recommended)
- [ ] This entry closed

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
- [ ] This entry closed

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
- [ ] This entry closed

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

## TD-perf-001 — "The Gap" mission scene FPS / draw-call / memory measurement never captured (AC-8, accepted non-blocking debt)

**Logged**: 2026-07-06
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

## TD-path-002 — GDD OQ-6's `path_invalidated` monster-refresh-burst framing is stale/inaccurate

**Logged**: 2026-07-06
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

## TD-test-003 — `tests/gdunit4_runner.gd` calls a nonexistent `GdUnitTestCIRunner` method

**Logged**: 2026-07-06
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

## TD-inv-001 — Inventory's `restore_save_data()` lacks defense-in-depth range/collision validation on restored data

**Logged**: 2026-07-15
**Fixed**: Not yet
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
- [ ] Not yet started.

## TD-inv-002 — Tab categorization test gaps + story-type header mismatch

**Logged**: 2026-07-15
**Fixed**: Not yet
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
- [ ] Not yet started.

## TD-inv-003 — Slot expansion's rarity resolution is caller-supplied, not resolved from real Inventory contents; no expansion-completion event; one test gap

**Logged**: 2026-07-15
**Fixed**: Not yet
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
- [ ] Not yet started.

## TD-inv-004 — `remove_item()` on a partial-quantity stackable slot is unasserted; AC-12 wording mismatch with Story 001's data model

**Logged**: 2026-07-15
**Fixed**: Not yet
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
- [ ] Not yet started. **Note (2026-07-15)**: Story 006 added `consume_stackable()` (a separate method from `remove_item()`) with its own full-depletion-nulls-slot test coverage, but did not add the specific `remove_item()`-on-partial-quantity test this entry asks for — that gap is still open, distinct from Story 006's new method.

## TD-inv-005 — `consume_stackable()` push_error message content unasserted

**Logged**: 2026-07-15
**Fixed**: Not yet
**Story**: Story 006 (Partial Stack Consumption Stability, Epic 03) — flagged during `/code-review`
**Severity**: Low — return-value/state behavior (what callers actually depend on) is fully tested; only the diagnostic message text itself is unverified.
**Area**: `src/core/inventory/inventory.gd` (`consume_stackable()`), `tests/unit/inventory/stack_consumption_test.gd`

### Gap

None of `consume_stackable()`'s 6 `push_error()` call sites (null definition, unique-instance rejection, quantity<=0, item-not-found, no-unlocked-slot-with-sufficient-quantity) have their message content asserted — only the return value (`0`) and non-emission are checked. A future refactor could silently corrupt the error text (wrong interpolated value, wrong wording) without any test failing.

### Recommended fix

Add at least one `push_error` content assertion using this codebase's established GdUnit4 error-capture facility, if used elsewhere, for consistency with how thoroughly the rest of this method is tested.

### Resolution
- [ ] Not yet started.

## TD-inv-006 — `add_stackable()` has no `quantity <= 0` guard; now surfaces via a negative-quantity EventBus payload

**Logged**: 2026-07-15
**Fixed**: Not yet
**Story**: Story 005 (Mid-Mission Pickup Rejection, Epic 03) — flagged independently by both the GDScript specialist and QA tester during `/code-review`
**Severity**: Low — no crash or corruption; current control flow happens to be inert for `quantity <= 0` (both fill/overflow loops are skipped, `placed == 0`), but this is unverified by any test, and Story 005's new emission logic means a negative `quantity` would now produce a `GEventBus.item_pickup_rejected` payload with a negative `quantity` field — a malformed-looking signal a downstream subscriber (e.g. a future Mission HUD toast) shouldn't have to defend against.
**Area**: `src/core/inventory/inventory.gd` (`add_stackable()`), `tests/integration/inventory/pickup_rejection_test.gd`

### Gap

`add_stackable()` has never had a `quantity <= 0` guard, unlike its sibling `consume_stackable()` (Story 006), which explicitly rejects with `push_error()`. This predates Story 005 (present since Story 001) but was previously low-visibility since no EventBus emission depended on it. Story 005 wired `item_pickup_rejected`/`item_added` into this method's return path, so a negative `quantity` input now flows through to a real signal payload with a negative value, rather than just an odd internal return value.

### Recommended fix

- Add an explicit `if quantity <= 0: push_error(...); return quantity` guard at the top of `add_stackable()`, mirroring `consume_stackable()`'s existing idiom exactly.
- Add a regression test (`test_add_stackable_zero_or_negative_quantity_rejected` or similar, matching `slot_stack_model_test.gd`'s naming for the analogous `add_unique_item()` case) proving no signal fires and no mutation occurs.

### Resolution
- [ ] Not yet started.

## TD-ui-001 — InventoryScreen's gamepad dual-focus behavior verified via keyboard only; physical hardware confirmation still open

**Logged**: 2026-07-15
**Fixed**: Not yet
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
- [ ] Not yet started.

## TD-ui-002 — InventoryScreen: untested Tab-traversal and multi-resolution layout; FocusRing lookup fragility

**Logged**: 2026-07-15
**Fixed**: Not yet
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
- [ ] Not yet started.

## TD-econ-001 — ResourceEconomy: heterogeneous-batch resolution (two different drop_table_ids in one monsters_died_batch call) untested

**Logged**: 2026-07-16
**Fixed**: Not yet
**Story**: Story 010 (Drop Table Schema & Registry Lookup, Epic 03) — flagged during `/code-review`
**Severity**: Low — no known reachable defect; `_on_monsters_died_batch()`'s loop structure (`for payload in payloads: _resolve_drop_table(payload)`) has no shared/accumulated state between iterations by construction, so a heterogeneous-batch bug is unlikely, but it is genuinely unproven by any test.
**Area**: `src/core/resource_economy/resource_economy.gd`, `tests/unit/resource_economy/drop_table_schema_registry_test.gd`

### Gap

`test_resource_economy_resolves_registered_table_identically_via_monsters_died_batch` uses two batch entries that both cite the SAME `drop_table_id`. No test proves a batch containing entries for TWO DIFFERENT `drop_table_id`s each independently resolve to their own correct table — current coverage proves "no shared rounding state" for same-table entries and proves the loop doesn't crash, but doesn't rule out an indexing/closure mistake that resolves every batch entry against the first payload's id.

### Recommended fix

Add a test seeding two different `DropTableResource`s, constructing a `monsters_died_batch` payload array with one entry per table, and asserting each resolves independently to its own correct table (not the other's).

### Resolution
- [ ] Not yet started.

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

## TD-econ-003 — materials_earned's `source` field semantics unconfirmed against GDD

**Logged**: 2026-07-16
**Fixed**: Not yet
**Story**: Story 008 (Drop Occurrence & Quantity Resolution, Epic 03) — flagged during `/code-review`
**Severity**: Low — a plausible reading, not contradicted by any test or GDD text, but not explicitly confirmed either.
**Area**: `src/core/resource_economy/resource_economy.gd`, `design/gdd/event-bus.md`

### Gap

`materials_earned(material_type, quantity, source)`'s `source` parameter is populated with `payload.kill_source` (values: `"tower"`, `"hero"`, `"wave_end"`). The sibling `resources_changed(gold, source)` signal uses `source` for *economic-event* strings (`"mission_start_grant"`, `"wave_completion_grant"`) — a different naming pattern than "which entity/mechanism performed the kill." `event-bus.md`'s catalogue entry for `materials_earned` doesn't define `source`'s intended semantics precisely enough to confirm or rule out this choice.

### Recommended fix

Confirm with game-designer/economy-designer whether `kill_source` is the intended `source` value for `materials_earned`, or whether it should instead describe the economic event (e.g. `"monster_kill"`) for consistency with `resources_changed`'s pattern. Update `event-bus.md`'s catalogue to document the decision either way.

### Resolution
- [ ] Not yet started.

## TD-econ-004 — Drop occurrence/quantity: two testability gaps (multi-entry-per-table Rule 9; realistic-rate-in-pipeline)

**Logged**: 2026-07-16
**Fixed**: Not yet
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
- [ ] Not yet started.

## TD-econ-005 — Despawn suppression: no all-wave_end-batch test (defense-in-depth)

**Logged**: 2026-07-16
**Fixed**: Not yet
**Story**: Story 011 (Despawn Drop Suppression, Epic 03) — flagged during `/code-review`
**Severity**: Low — not a known gap in current coverage (the mixed-batch test already proves per-payload suppression), purely defense-in-depth against a future batch-iteration regression.
**Area**: `tests/integration/resource_economy/despawn_drop_suppression_test.gd`

### Gap

The existing `test_batch_with_normal_kill_and_wave_end_payload_resolves_only_normal_kill` proves a MIXED batch (one normal kill, one wave_end) suppresses only the wave_end entry. No test exercises a batch of 2+ ALL-wave_end payloads asserting zero emissions — this would guard against an off-by-one/early-exit bug that only suppresses the first wave_end entry in a batch.

### Recommended fix

Add a test: `monsters_died_batch` with 2+ wave_end payloads against a guaranteed-drop table, assert 0 `materials_earned` emissions.

### Resolution
- [ ] Not yet started.


# Epic 05: Sanctuary Production Systems

> **Layer**: Feature
> **GDDs**: `design/gdd/crafting.md`, `design/gdd/menagerie.md`, `design/gdd/defense-building.md`
> **Architecture Module**: Crafting System, Menagerie System, Defense Building System (`architecture.md`'s Module Ownership rows for all three are pre-emptive stubs written before these GDDs existed — due for a refresh once this epic's stories land)
> **Status**: Complete (implementation + code review). 26/26 stories Complete (2026-07-18). **Boot-verified and code-reviewed 2026-07-18 (Sprint 6, S6-01/S6-06)** — see notes below.
> **Stories**: 26 created and implemented (6 Crafting, 11 Menagerie, 9 Defense Building) — **all Complete**. Governing ADRs (0020/0021/0023/0024/0026) accepted 2026-07-17, outside the normal `/architecture-review` gate (user decision during this skill run). `TD-craft-001`/`TD-defbuild-002` (rarity-vs-item_type vocabulary) **resolved 2026-07-18 (Sprint 6, S6-06b)** — see notes below. Crafting's own SavePersistence mid-session-restore exposure was resolved earlier the same day (S6-01).
>
> **⚠️ Boot-verification finding (2026-07-18, Sprint 6 S6-01)**: every story in this epic was implemented with tests "created but not executed — no headless Godot runner available," per each story's own Completion Notes. The first actual live Godot run of this epic's code (during S6-01's SavePersistence work) found the project **did not boot** — `menagerie.gd` (and, further upstream, `game_data_registry.gd`, `defense_building.gd`) failed to parse with "type not found" errors for `CreatureInstance`/`BreedingPen`/`SpeciesResource`/`RecipeResource`/`TechNodeResource`/`StructureResource`. **Root cause was not a code defect** — `.godot/global_script_class_cache.cfg` was stale (last built 2026-07-16, before any of this epic's classes existed) because the project had only ever been driven headlessly via MCP `run_project`, which does not trigger Godot's class-registration scan. Fixed by running `Godot.exe --headless --editor --path . --quit` to force the rescan; the project now boots with zero errors and no code changes were needed. See `.claude/docs/context-management.md` → "Godot MCP Session Gotchas" and `docs/engine-reference/godot/VERSION.md` for the full writeup. **Lesson**: "tests created, not executed" should not be treated as equivalent to "verified" for an entire epic without at least one live boot check — this gap went undetected for 26 stories.
>
> **✅ Deferred `/code-review` complete (2026-07-18, Sprint 6 S6-06)**: reviewed all 9 source files across Crafting, Defense Building, and Menagerie via `feature-dev:code-reviewer`. Found and fixed 1 Critical + 2 Important issues, all live-verified via Godot MCP after fixing:
> - **Critical — `Menagerie.pair_for_breeding()` allowed self-pairing** (`menagerie.gd`): calling it with the same `creature_id` for both slots passed the species-equality check trivially (same object) and the second `move_to_breeding_pen()` call's `false` return was silently ignored, producing a pen with `occupant_ids = [id, id]` that would breed indefinitely from a single creature. Fixed with an early `creature_id_a == creature_id_b` guard; regression test added (`breeding_pen_test.gd`).
> - **Important — missing regression test for the already-documented `_tick_decay()` ordering bug**: the code's own comment described a real, already-fixed bug (bonus computed mid-loop instead of after all decay completed), but no test asserted per-emission bonus *values* were identical and correct — only emission *count*. Added `test_all_emissions_in_one_decay_pass_share_the_same_final_bonus` (`mission_tick_decay_scope_test.gd`).
> - **Important — missing regression test for the already-documented happiness-clamp defensive fix**: `restore_save_data()`'s out-of-range happiness clamp had no test exercising an actual out-of-range value. Added `test_restore_save_data_clamps_out_of_range_happiness` (`persistence_test.gd`).
>
> All three fixes live-verified via Godot MCP `run_script` against the real shipped code — self-pairing rejected (normal pairing still works), decay bonuses now consistent across all emissions in a pass, and out-of-range happiness values now clamp correctly on restore. Reviewer found no issues in Crafting's or Defense Building's resolution logic, or in any of the 4 Resource-subclass data models (`RecipeResource`, `StructureResource`, `TechNodeResource`, `SpeciesResource`) — static typing, allocation discipline, and state-machine guards all checked out.
>
> **✅ `TD-craft-001`/`TD-defbuild-002` RESOLVED (2026-07-18, Sprint 6 S6-06b)**: both TDs were the same open design question — `crafting.md`'s Formulas 1–3 and `defense-building.md`'s `material_costs` are authored against a material-**rarity** vocabulary (Common/Uncommon/Rare), but `Inventory.has_items()`/`consume_by_type()` only ever summed by `item_type`, so any rarity-keyed cost was structurally uncraftable/unaffordable. Resolved by adding `ItemDefinitionResource.rarity` as a genuinely separate aggregation axis (an item can be both `item_type="Material"` and `rarity="Common"`) plus `Inventory.has_items_by_rarity()`/`consume_by_rarity()`, mirroring the existing item_type-keyed pair exactly. Crafting's `resolve_repair()` and a **second, newly-discovered instance of the same bug** in `is_craftable()`/`resolve_craft()`/both discovery triggers (`_has_recipe_inputs()`/`_consume_recipe_inputs()` helpers, splitting a mixed item_type/rarity cost Dictionary) were both updated; Defense Building's `resolve_tech_unlock()`/`resolve_structure_build()` likewise. ADR-0021 amended with the full decision record. **Found and fixed a genuine, unrelated test-authoring bug in the same pass**: `has_items_by_rarity()` (like `has_items()`) resolves a slot's rarity via `GGameDataRegistry.get_item_definition(slot.item_id)`, never from the object passed to `add_stackable()` — 5 test files (`currency_dual_gate_test.gd`, `resolution_ordering_test.gd`, `persistence_through_defeat_test.gd`, `component_repair_test.gd`, `edge_cases_shared_guard_test.gd`) seeded Inventory with fabricated, unregistered item_ids and could never actually have passed; corrected to use the real registered `common_scrap`/`iron_ore` content. Live-verified via gdUnit4: 220/220 tests passing, 0 failures, across `tests/unit/crafting`, `tests/integration/crafting`, `tests/unit/defense_building`, `tests/integration/defense_building`, `tests/unit/inventory` (11 new/updated tests this pass).

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | RecipeResource Data Model & Content Validation | Config/Data | Complete | ADR-0023 |
| 002 | Recipe Discovery State Machine (3-Trigger) | Logic | Complete | ADR-0023 |
| 003 | Craftability Re-Check | Logic | Complete | ADR-0023 |
| 004 | Crafting Resolution Flow | Integration | Complete | ADR-0023 + ADR-0021 |
| 005 | Component Repair (In-Place Mutation) | Integration | Complete | ADR-0023 + ADR-0021 |
| 006 | Material Cost Formulas | Logic | Complete | ADR-0023 |
| 007 | Species Roster & Lure Acquisition | Logic | Complete | ADR-0026 |
| 008 | Placement on Acquisition (HABITAT/RESERVE) | Logic | Complete | ADR-0026 |
| 009 | Habitat Capacity & Defense Building Subscription | Integration | Complete | ADR-0026 + ADR-0024 |
| 010 | HABITAT-Only Quality Bonus & Aggregate Formula | Logic | Complete | ADR-0026 |
| 011 | Aggregate Recompute-and-Push (highest-risk rule) | Logic | Complete | ADR-0026 |
| 012 | Happiness Start Value, Decay & Floor | Logic | Complete | ADR-0026 |
| 013 | Mission-Tick Decay Scope | Logic | Complete | ADR-0026 |
| 014 | Tend Action | Logic | Complete | ADR-0026 |
| 015 | Breeding Pen — Pairing & Deterministic Breeding | Logic | Complete | ADR-0026 |
| 016 | Sacrifice Validation & `request_sacrifice()` | Integration | Complete | ADR-0026 |
| 017 | Menagerie Persistence & `creature_acquired` | Integration | Complete | ADR-0026 |
| 018 | TechNode/Structure Data Schema & Two Ledgers | Config/Data | Complete | ADR-0024 |
| 019 | Tech Tree Prerequisite Chain Enforcement | Logic | Complete | ADR-0024 |
| 020 | Habitat Expansion 3-Tier Contract | Integration | Complete | ADR-0024 |
| 021 | Watchtower Scaffolding | Config/Data | Complete | ADR-0024 |
| 022 | Currency Dual-Gate & Gold Debit | Logic | Complete | ADR-0024 |
| 023 | Resolution Ordering & Idempotency | Logic | Complete | ADR-0024 |
| 024 | Sanctuary-Only Scope & Persistence Through Defeat | Integration | Complete | ADR-0024 |
| 025 | Cost Formulas 1–3 | Logic | Complete | ADR-0024 |
| 026 | Edge Cases — Stale UI & Shared Double-Confirm Guard | Logic | Complete | ADR-0024 |

## Overview

This epic covers the three Sanctuary-context production systems that let the player convert accumulated resources into permanent capability between missions: **Crafting** (materials → Tower Components and Crafted Goods, via a recipe/discovery model), **Menagerie** (a living-care loop that turns tended creatures into an aggregate quality-of-loot bonus), and **Defense Building** (a tech tree + physical structure catalogue that permanently expands what the Sanctuary can do). All three share the same underlying shape — a Sanctuary-only, instant-on-confirm resolution against Inventory's material stock, gated by a permanent one-way discovery/unlock ledger — and are bundled here because their implementation order is naturally interleaved: Defense Building's tech tree gates Crafting's advanced recipes and Menagerie's Habitat Expansion capacity simultaneously, so building one in isolation leaves the other two partially blocked.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0023 (Crafting recipe data model) | `RecipeResource` (GameDataRegistry-backed) + Discovery Ledger; 3-trigger discovery (tech_unlocked, item_added, boot-sweep) resolving a confirmed implementability gap in the GDD's own Rule 4 | LOW |
| ADR-0024 (Defense Building tech tree data model) | `TechNodeResource`/`StructureResource` + 2 independent ledgers; **DefenseBuilding reclassified Autoload #10** so `is_tech_unlocked()` is callable by Crafting's boot sweep | LOW |
| ADR-0026 (Menagerie creature lifecycle) | `CreatureInstance` (RefCounted) + fixed 2-pen breeding structure; **Menagerie reclassified Autoload #11** so `request_sacrifice()` is callable by Equipment Forge (Epic 08) | LOW |
| ADR-0021 (Inventory cross-system query/mutation API) | Shared dependency — `has_items()`, `has_room_for()`, `clear_damaged_flag()`, `reserve_instance_id()` all three systems in this epic call directly | LOW |
| ADR-0020 (Direct-Autoload-call exception pattern) | Governs why all three systems' Inventory/inter-system calls are direct, not EventBus | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| TR-craft-001 | `RecipeResource` data schema via GameDataRegistry, extending ADR-0009's Resource-subclass convention | ✅ ADR-0023 |
| TR-craft-002 | Dual-gate discovery trigger architecture (tech_unlocked AND item_added); 3rd init-time-sweep implementability gap | ✅ ADR-0023 (resolves the gap explicitly) |
| TR-craft-003 | Inventory API-boundary additions (`has_room_for`, `clear_damaged_flag`, `has_items`) + `component_repaired` event | ✅ ADR-0021 |
| TR-menag-001 | 3-state creature lifecycle (RESERVE/HABITAT/BREEDING_PEN, terminal SACRIFICED); `request_sacrifice()` signature | ✅ ADR-0026 |
| TR-menag-002 | Happiness decay/tend formulas ticking on `mission_launched`, not wall-clock/`_process()` | ✅ ADR-0026 |
| TR-menag-003 | Save persistence for creature instances + aggregate `menagerie_quality_bonus` (restore_order=20) | ✅ ADR-0026 |
| TR-defbuild-001 | 5-node tech tree data schema (2 categories) and unlock-gating logic | ✅ ADR-0024 |
| TR-defbuild-002 | `sanctuary_structure_built` contract for Habitat Expansion's 3-tier structure | ✅ ADR-0024 |
| TR-defbuild-003 | Persistence for unlock-tree state (restore_order=21) | ✅ ADR-0024 |

**All 9 requirements across the 3 systems now have full ADR coverage** — 0 untraced.

## Known Blockers

- **⚠️ Project-wide SavePersistence gap (blocks Crafting)**: ADR-0029 (Tower Mastery) surfaced, and godot-specialist review of ADR-0003 confirmed, that `SavePersistence` has no mechanism to re-restore a system that registers mid-session — only at initial game/save load. Crafting is a scene-instanced `SanctuaryScene` child (destroyed/recreated on every Mission↔Sanctuary transition); its Discovery Ledger would silently reset to defaults on the second-and-later instantiation within a play session, even though it's correctly saved to disk. **Do not start Crafting stories until this is resolved** — flagged in `docs/registry/architecture.yaml`'s `crafting_discovery_ledger` entry. Menagerie and Defense Building are unaffected (both are Autoloads, per ADR-0026/ADR-0024, and Autoloads never re-register mid-session).
- 8 of 9 systems from this session's ADR batch (including all 3 in this epic) are `Needs Revision` per `systems-index.md` — every specific blocker was fixed same-day during the 2026-07-17 `/design-review --depth lean` pass, but none have been re-reviewed to flip to `Approved`. Same documentation-process status as Epic 03's Inventory/Resource Economy — not blocking for architecture/implementation purposes.
- Defense Building's `restore_order=21` must complete before Crafting's boot-time discovery sweep (ADR-0023) reads `is_tech_unlocked()` — already enforced by Crafting's own `restore_order` constraint (`> 21`), not an open item, but worth calling out for story-sequencing: implement Defense Building's persistence before Crafting's boot sweep story.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/crafting.md`, `design/gdd/menagerie.md`, and `design/gdd/defense-building.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- The SavePersistence mid-session-restore gap (see Known Blockers) is resolved before Crafting's persistence-dependent stories are marked Complete

## Next Step

Stories are written and `Ready` (production/epics/epic-05-sanctuary-production/story-001 through story-026). Run `/story-readiness [story-path]` then `/dev-story [story-path]` per story, in dependency order (Story 001→006 Crafting, 007→017 Menagerie, 018→026 Defense Building). Recommend sequencing Defense Building first (no blockers), Menagerie second (no blockers), Crafting last (its persistence stories — Story 002, Story 017-equivalent — remain gated by the SavePersistence mid-session-restore gap; its non-persistence stories, e.g. Story 004's resolution flow and Story 006's cost formulas, can proceed in parallel).

# Epic 08: Meta-Progression Convergence

> **Layer**: Advanced (depends on Feature layer + Hero)
> **GDDs**: `design/gdd/hero-skill-build.md`, `design/gdd/equipment-forge.md`
> **Architecture Module**: Hero Skill Build System, Equipment Forge System (both currently stale pre-emptive stubs in `architecture.md`'s Module Ownership section)
> **Status**: Complete — all 4 governing ADRs `Accepted`; Hero Skill Build (Stories 001-007) Complete 2026-07-19; Equipment Forge Stories 008-016 all Complete 2026-07-19 — **EPIC 08 FULLY COMPLETE**, batch `/code-review` completed 2026-07-19, APPROVED (see note below — this header line was stale, corrected 2026-08-13)
> **Stories**: 16/16 stories `Complete`
>
> **✅ Equipment Forge Story 015 (Concurrency Guard & Orphaned Rune References) implemented 2026-07-19** — single shared `_forge_resolving` guard now spans all 3 operation types (craft/imbue/sacrifice), replacing Story 010's narrower `_craft_resolving`. New `is_rune_id_known()` classifier (checks Constellation's fixed shape set, Tarot cards, Sacrifice recipes — no unified rune catalogue exists in this codebase) drives orphan handling for the Available Rune Ledger at restore time: orphaned entries retained but unselectable, load never blocked (AC-25 fully implemented). AC-24 (orphaned already-imbued runes) left explicitly PARTIAL — it presumes a rune_id→stat_delta lookup for consumed items that doesn't exist, the exact gap Story 013 already flagged; not silently expanded into. 15 new tests, all passing.
>
> **✅ Equipment Forge Story 016 (Rune Ledger Persistence Across Save/Load) implemented 2026-07-19** — verification story, no production code changes needed. Confirmed structurally (`Tarot.RESTORE_ORDER=22 < Constellation.RESTORE_ORDER=24 < EquipmentForge.RESTORE_ORDER=32`) and behaviorally that both a Constellation-sourced and a Tarot-sourced rune round-trip correctly and remain genuinely imbuable post-restore. Closes the GDD's own previously-flagged-unverifiable AC-26 gap (Constellation had no assigned `restore_order` when `equipment-forge.md` was written; ADR-0022 has since assigned it). 4 new tests, all passing.
>
> **✅ Deferred batch `/code-review` across all of Equipment Forge (Stories 008-016) completed 2026-07-19 — Verdict: APPROVED.** 3 parallel specialist passes (godot-gdscript-specialist, godot-specialist architecture, qa-tester testability). No BLOCKING or ARCHITECTURAL VIOLATION findings; ADR-0025 fully COMPLIANT. One real bug found and fixed during review: `EquipmentForge.RUNE_SLOT_COUNT_FOR_SLOT` (a dead constant keyed by Inventory's 5-name equip-slot vocabulary) was still indexed by `rune-slot-model-ledger_test.gd` using the GDD's 4-name output_slot vocabulary — a latent KeyError crash for the first `output_slot="accessory"` recipe, masked only by no such recipe existing yet. Removed the duplicate constant; repointed the test at `EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT` (the actual single source of truth). Re-verified clean: 82/82 equipment-forge tests, then a full project regression at 1364/1364 (0 errors, same 1 pre-existing `TD-menag-006` failure). Suggestions logged (not blocking): test coverage for `resolve_sacrifice()`'s dangling-item-id/unknown-creature-id branches and `get_save_key()`; an ADR-0025 sync note for the save-key naming and Story 015's `is_known` field addition. **EPIC 08 IS NOW FULLY CLOSED OUT.**
>
> **✅ Equipment Forge Story 013 (Rune Imbuing Action) implemented 2026-07-19** — `Inventory.apply_rune_to_item(instance_id, rune_id, stat_delta)` (never checks `locked`, never fires `item_added`/`item_removed`) + `EquipmentForge.resolve_imbue()` (consumes an `AVAILABLE` rune, one-time-use, emits `item_rune_imbued`). Real gap explicitly flagged not silently solved: `stat_delta` isn't persisted anywhere retrievable after imbuing — Hero's eventual stat-bonus application has no data source yet, out of this story's own testable scope. 8 new tests, all passing. Full regression clean at 1336/1337 (same pre-existing `TD-menag-006` failure).
>
> **✅ Equipment Forge Story 014 (Creature Sacrifice Resolution) implemented 2026-07-19** — closes `menagerie.md`'s explicitly-flagged `target_item_id` open question: `EquipmentForge.resolve_sacrifice()` implements Rule 19's strict step order (species pre-check → room check → reserve a prospective instance id via new `Inventory.reserve_instance_id()` → `Menagerie.request_sacrifice()` → construct the item pre-imbued with its species rune). New `SacrificeRecipeResource` content type + `GameDataRegistry` loader added. Real finding: `Menagerie.request_sacrifice()` already existed in code (landed ahead of schedule by an Epic 05 story), narrowing this story's actual scope to the Equipment Forge calling side only. 7 new tests, all passing.
>
> **✅ Equipment Forge Stories 011+012 implemented 2026-07-19** (Story 012 done first — a real sequencing correction, since Story 011's own Dependencies list Story 012 as a prerequisite). Story 012: `_available_runes` ledger populated exclusively via `constellation_rune_discovered`/`tarot_rune_discovered`, Menagerie-sourced runes excluded by construction (no subscription to `creature_sacrificed` exists at all). Story 011: full `SaveRestorer` added to `EquipmentForge` (`restore_order=32`), persisting exactly the 2 ledgers with zero item-instance data, plus the 3rd discovery-trigger boot sweep Story 009 had deferred. 16 new tests (50 total across equipment-forge). Full regression clean at 1328/1329 (same pre-existing `TD-menag-006` failure).
>
> **✅ Equipment Forge Story 010 (Crafting Resolution & Material Cost) implemented 2026-07-19** — `EquipmentForge.resolve_craft()` (5-step synchronous/atomic resolution, own `_craft_resolving` guard) + `material_qty()` (Formula 1, replicating `design/registry/entities.yaml`'s worked table, reusing `tower.md`'s registered `tier_dps_multiplier`). Extended `InventorySlot` with `rune_slot_count`/`imbued_runes` (ahead of Story 013, since AC-10 required it now) via a backward-compatible `add_unique_item()` parameter. 9 new tests, all passing. Full regression clean at 1312/1313 (same pre-existing `TD-menag-006` failure).
>
> **✅ Equipment Forge Story 009 (Equipment Recipe Model & Discovery) implemented 2026-07-19** — `EquipmentRecipeResource` (new `src/core/equipment_forge/equipment_recipe_resource.gd`, sibling to Crafting's `RecipeResource`, per ADR-0025) + `EquipmentForge` (new `src/core/equipment_forge/equipment_forge.gd`, scene-instanced, not Autoload). Discovery state machine mirrors Crafting's own pattern verbatim for `recipe_category="hero_equipment"`. 3 Alpha recipes authored (weapon/armor/trinket, one tech-gated). SaveRestorer persistence deliberately deferred to Story 011 (its own scope). 11 new tests, all passing. Full regression clean at 1303/1304 (same pre-existing `TD-menag-006` failure).
>
> **✅ Equipment Forge Story 008 (Hero Equipment Slots & Non-Coupling) implemented 2026-07-19** — per ADR-0025, equip/unequip mechanics landed in `Inventory` (`src/core/inventory/inventory.gd`), not a new Equipment Forge class — Equipment Forge itself (Stories 009+) only crafts/imbues items, never touches slots directly. 5 named Hero equipment slots (`weapon`/`armor`/`accessory_a`/`accessory_b`/`trinket`) reserved as permanently-locked placeholders at the last 5 indices of Inventory's existing 10-slot array, per `inventory.md` Rule 5a's explicit "locked items still occupy and count against the current slot cap." New `ItemDefinitionResource.equipment_category` field for category-mismatch validation (AC-2). 14 new tests, all passing. **Real, expected regression found and fixed**: this was the first code to actually implement Rule 5a (present in the GDD since an earlier design-review pass but never wired up) — broke 6 pre-existing Epic 03 Inventory tests that assumed all 10 slots were generically fillable; fixed to reflect the now-real 5-discretionary/5-locked split. Full project regression clean at 1292/1293 (same pre-existing `TD-menag-006` failure).
>
> **✅ Hero Skill Build (Stories 001-007) implemented 2026-07-19** — built from scratch as Autoload #13 (`src/core/hero_skill_build/hero_skill_build.gd`), per ADR-0030. Shared `SkillDefinitionResource` (Story 001, amends ADR-0029), the pure Formula 1-3 Ultimate-derivation pipeline with a full 35-profile exhaustiveness proof (Story 002), recompute/ownership boundary (Story 003), passive slots as internal state (Story 004), full `SaveRestorer` persistence at `restore_order=31` (Story 005), orphaned-data edge cases (Story 006), and a registry-dependency tracking pass (Story 007) that found 2 of 3 originally-blocked ACs already resolved on re-verification. **Real cross-epic architecture conflict found and fixed** (Story 003): `hero.gd` (Epic 02) had its own pre-existing Ultimate self-derivation mechanism that directly violated ADR-0030's ownership rule — surfaced to the user before touching it (not silently decided, given the size of the blast radius), user chose full migration; ~20 existing Hero tests rewritten to match the corrected ownership model. 62 new tests across 6 files, all passing. Batch `/code-review` at the end found and fixed 2 real bugs (Ultimate-activation guard missing Hero Skill Build's "EMPTY" sentinel causing a spurious error log; an Inventory-return log message that claimed success even when Inventory was full) — APPROVED WITH SUGGESTIONS. Full regression held at 1277+/1278 throughout (same pre-existing `TD-menag-006` failure).

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Slots & Skill Catalogue Data Model | Logic | Complete | ADR-0030 |
| 002 | Ultimate Derivation & Combinatorial Tractability Proof | Logic | Complete | ADR-0030 |
| 003 | Ultimate Recompute & Ownership | Integration | Complete | ADR-0030 |
| 004 | Passive Slots as Internal State | Logic | Complete | ADR-0030 |
| 005 | Persistence Boundary & Cross-Mission State | Integration | Complete | ADR-0030 |
| 006 | Orphaned Data & Content-Change Edge Cases | Logic | Complete | ADR-0030 |
| 007 | Cross-GDD Interface & Registry Dependencies | Config/Data | Complete (AC-18 still independently blocked on `inventory.md` revision; AC-19/AC-20 found already resolved on re-verification — see story) | ADR-0030 |
| 008 | Hero Equipment Slots & Non-Coupling | Integration | Complete | ADR-0025 |
| 009 | Equipment Recipe Model & Discovery | Logic | Complete | ADR-0025 |
| 010 | Equipment Crafting Resolution & Material Cost | Logic | Complete | ADR-0025 |
| 011 | Save Payload Ownership Clarification | Integration | Complete | ADR-0025 |
| 012 | Rune Slot Model & Available Rune Ledger | Logic | Complete | ADR-0025 |
| 013 | Rune Imbuing Action | Integration | Complete | ADR-0025, ADR-0021 |
| 014 | Creature Sacrifice Resolution | Integration | Complete | ADR-0025, ADR-0026 |
| 015 | Concurrency Guard & Orphaned Rune References | Logic | Complete | ADR-0025 |
| 016 | Rune Ledger Persistence Across Save/Load | Integration | Complete | ADR-0025 |

All 4 ADRs are now Accepted, and the interfaces the GDDs themselves still mark `[BLOCKED — depends on unimplemented API]` (rune imbuing, sacrifice resolution, `has_room_for`) are fully specified — ADR-0021 (Inventory API) and ADR-0026 (Menagerie lifecycle). Story 014's (creature sacrifice) sequencing dependency is also satisfied: Menagerie (Epic 05) is fully implemented (26/26 stories Complete, 2026-07-18).

## Overview

This epic covers the two Advanced-layer systems that convert everything the player has earned elsewhere into a final, committed build: **Hero Skill Build** (the 4-slot active-skill loadout whose category-count combination deterministically derives a 5th slot, the Ultimate, via a mathematically-proven 19-ID lookup) and **Equipment Forge** (the project's most convergent system, aggregating rune inputs from Constellation, Tarot, and Menagerie into an in-place equipment-imbuing mechanic). Both are correctly sequenced last among this session's ADR batch, per `systems-index.md`'s own explicit guidance for Equipment Forge ("design last among Sanctuary systems") — this epic should not start until Epic 05 (Menagerie) and Epic 06/07 (Constellation, Tarot) are substantially underway, since Equipment Forge's Creature Sacrifice flow calls directly into Menagerie.

**Hero Skill Build is flagged HIGH-risk in `systems-index.md`'s own risk table** (Ultimate combinatorial-explosion scope risk) — this is the one risk in the batch that's already fully closed at the architecture level: ADR-0030's Ultimate derivation is a proven pure function (35 raw profiles → 19 fixed IDs), not a discipline of keeping a lookup table in sync, so catalogue growth structurally cannot reopen this risk.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0030 (Hero Skill Build Ultimate lookup-table architecture) | Pure 3-function derivation pipeline, never a persisted lookup table; unified `SkillDefinitionResource` with Tower Mastery (amended ADR-0029 in place); **HeroSkillBuild is Autoload #13** — its own new-system reason: resolved Ultimate/slot state must exist continuously across the SANCTUARY→MISSION boundary | LOW |
| ADR-0025 (Equipment Forge cross-system aggregation) | `EquipmentRecipeResource`/`SacrificeRecipeResource` mirroring ADR-0023's pattern; explicitly deferred (not fabricated) the `Menagerie.request_sacrifice()` Autoload dependency, later resolved by ADR-0026 | LOW |
| ADR-0026 (Menagerie creature lifecycle) | Resolves ADR-0025's flagged Menagerie-Autoload dependency directly — `request_sacrifice()` is now fully implementable | LOW |
| ADR-0021 (Inventory API) | `apply_rune_to_item()`, `has_room_for()`, `reserve_instance_id()` — all called directly by Equipment Forge | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| TR-heroskill-001 | Ultimate-derivation lookup-table architecture — 35 raw profiles → 19 fixed Ultimate IDs | ✅ ADR-0030 (pure function, mathematically proven exhaustive) |
| TR-heroskill-002 | Save persistence for unlocked skills/slot assignment (restore_order=**31**, corrected from the GDD's colliding self-proposed 32) | ✅ ADR-0030 — also resolves `save-persistence.md`'s own flagged open ordering question against Tower Mastery |
| TR-equipforge-001 | `Inventory.apply_rune_to_item()` in-place mutation API | ✅ ADR-0021 |
| TR-equipforge-002 | `Menagerie.request_sacrifice(creature_id, target_item_id)` cross-system call boundary | ✅ ADR-0025 (specified) + ADR-0026 (Autoload status resolved — fully implementable) |
| TR-equipforge-003 | Persistence for crafted/imbued gear (restore_order=32); Constellation's `restore_order` dependency (AC-26) | ✅ ADR-0025 — Constellation's restore_order=24 (ADR-0022) confirmed compatible |

**All 5 requirements now have full ADR coverage** — 0 untraced.

## Known Blockers

- ~~**Project-wide SavePersistence gap (blocks Equipment Forge only, not Hero Skill Build)**~~ **RESOLVED 2026-07-18 (Sprint 6, S6-01)**: Equipment Forge is a scene-instanced `SanctuaryScene` child, subject to the same mid-session-restore gap as Crafting/Constellation/Tarot. Fixed by ADR-0003's 2026-07-18 revision. Hero Skill Build was never affected (Autoload, ADR-0030).
- ~~**Governing ADRs still Proposed**~~ **RESOLVED 2026-07-18 (Sprint 6, S6-04)**: ADR-0025 and ADR-0030 both accepted (lightweight manual cross-check, outside the normal `/architecture-review` gate — see each ADR's own Acceptance Note). ADR-0021/ADR-0026 were already Accepted 2026-07-17 with Epic 05's batch. All 16 stories now `Ready`.
- ~~**Sequencing dependency, not an open design gap**~~ **RESOLVED 2026-07-18**: Equipment Forge's Creature Sacrifice resolution flow calls `Menagerie.request_sacrifice()` directly — Menagerie (Epic 05) is now fully implemented (26/26 stories Complete), so this dependency is satisfied in code, not just in the ADR.
- `_generate_prospective_item_id()` — fixed in ADR-0025 to call `Inventory.reserve_instance_id()` (added to ADR-0021) rather than minting an ID from Equipment Forge's own scene-local state — verify this is implemented as specified, not reverted to the original (buggier) approach during story implementation.
- Hero Skill Build's `SkillDefinitionResource` is shared with Tower Mastery (Epic 06) — implement or verify the unified schema (ADR-0029's amended definition, canonical path `assets/data/skills/`) before either system's content-loading story, to avoid two divergent `.tres` file sets being authored independently.
- Both GDDs are `Needs Revision` (Hero Skill Build is the sole exception — **Approved**) per `systems-index.md`; same documentation-process caveat as prior epics for Equipment Forge only.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/hero-skill-build.md` and `design/gdd/equipment-forge.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Hero Skill Build's Ultimate derivation has an automated test confirming all 19 fixed IDs are reachable across the 35 raw category-count profiles, with zero reachable `NONE`/`EMPTY` outcome for any valid 4-skill combination (per ADR-0030's own Validation Criteria)
- The SavePersistence mid-session-restore gap is resolved before Equipment Forge's persistence-dependent stories are marked Complete

## Next Step

Run `/create-stories epic-08-meta-progression-convergence` to break this epic into implementable stories. Recommend starting Hero Skill Build first (no blockers, and its shared `SkillDefinitionResource` should be authored once, early, for Tower Mastery/Epic 06 to consume too) — hold Equipment Forge's sacrifice-flow stories until Menagerie (Epic 05) has landed its Autoload/lifecycle stories.

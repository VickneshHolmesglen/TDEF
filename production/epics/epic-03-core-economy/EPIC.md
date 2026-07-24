# Epic 03: Core Economy

> **Layer**: Core
> **GDDs**: `design/gdd/inventory.md`, `design/gdd/resource-economy.md`
> **Architecture Module**: Inventory, Resource Economy (both currently stale
>   placeholder stubs in `docs/architecture/architecture.md`'s Module Ownership
>   section — written before either GDD existed; needs a real rewrite once
>   ADRs land)
> **Status**: **Complete — all 15 of 15 stories Complete as of 2026-07-16.** ADR-0016, ADR-0017, ADR-0018, ADR-0011 all Accepted. Both GDDs remain formally `Needs Revision` pending a final `/design-review` re-run (documentation-process status, independent of code).
> **Stories**: 15 created (7 Inventory, 8 Resource Economy)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Slot & Stack Model | Logic | **Complete** | ADR-0016 |
| 002 | Tab Categorization | Logic *(corrected from Config/Data during `/story-done`)* | **Complete** | ADR-0016 |
| 003 | Slot Expansion & Cost Table | Logic | **Complete** | ADR-0016 |
| 004 | Equipped-Item Lock | Logic | **Complete** | ADR-0016 |
| 005 | Mid-Mission Pickup Rejection | Integration | **Complete** | ADR-0016 |
| 006 | Partial Stack Consumption Stability | Logic | **Complete** | ADR-0016 |
| 007 | Two-Panel Screen Presentation | UI | **Complete** | ADR-0016 (data side) + ADR-0011 (dual-focus UI, Accepted 2026-07-13) |
| 008 | Drop Occurrence & Quantity Resolution | Logic | **Complete** | ADR-0017 |
| 009 | Quality Tier Roll & Menagerie Bonus Scope | Logic | **Complete** | ADR-0017 |
| 010 | Drop Table Schema & Registry Lookup | Logic | **Complete** | ADR-0017 |
| 011 | Despawn Drop Suppression | Integration | **Complete** *(closed TD-econ-002 — wave_end despawns no longer award spurious materials)* | ADR-0017 |
| 012 | Menagerie Attraction Material (Lure) | Logic | **Complete** | ADR-0017 |
| 013 | Gold Track & Scout Starting Grant | Integration | **Complete** *(code review found and fixed a live cross-epic bug in TowerSystem — see TD-econ-008)* | ADR-0017 (emission side) + ADR-0018 (gold-balance ownership) |
| 014 | Batch Resolution Independence | Logic | **Complete** *(verify-only — surfaced and fixed an ADR-0017 internal inconsistency; logged TD-econ-006)* | ADR-0017 |
| 015 | Combined-ERI Content-Authoring Validator | Config/Data | **Complete** *(enforcement-workflow question remains genuinely open; found and logged TD-econ-007 — the corrected Formula 4 leaves this check unable to fail for realistic content)* | ADR-0017 |

**ADR-0016 (Inventory Storage Model) unblocked 6 of 7 Inventory stories; fixed and Accepted 2026-07-13** (`restore_order` corrected from 20 to 10 — was colliding with Menagerie's slot in `save-persistence.md`'s own Formula 4 table). **ADR-0017 (Resource Economy Drop Resolution) unblocked 7 of 8 Resource Economy stories; fixed and Accepted 2026-07-13** (corrected a factually-wrong Wave Manager precedent citation — the underlying scene-instanced decision was unaffected; further amended 2026-07-16 during Story 008 to add a `base_drop_rate` field the original schema had omitted). **ADR-0018 (Mission Economy — Runtime Gold Balance Ownership, Accepted 2026-07-13)** resolves the gold-balance-ownership gap via a new `MissionEconomy` Autoload (boot position 8) — Story 013 is now Ready. **ADR-0011 (UI Dual-Focus Handling, Accepted 2026-07-13)** resolves the last remaining gap via a reusable, scene-instanced `InputModeTracker` helper — Story 007 is now Ready, and further amended 2026-07-15 during Story 007's implementation with a signal-connection-dedup lesson for future UI screens. **All 15 of 15 stories were `Status: Ready` as of 2026-07-13; implementation began 2026-07-15/16 and 11 are now Complete** (see Stories table).

**Implementation summary (2026-07-15/16)**: **All 15 stories are Complete** — 7 Inventory (001-007) and 8 Resource Economy (008-015) — code, tests, and live verification (screenshots/scripted state inspection for Story 007's UI ACs) all done via `/dev-story` → `/code-review` → `/story-done`. Full project test suite: 811/811 passing, 0 regressions. TD-econ-002 (Medium, wave-end despawns spuriously awarding materials) was closed by Story 011. TD-econ-006 (Medium, `monster_died`/`monsters_died_batch` exclusivity invariant unverified at the emitter) logged during Story 014. TD-econ-007 (Low-Medium, Combined-ERI validator can't fail for realistic content post-Formula-4-correction) logged during Story 015. **TD-econ-008 (High, resolved same-session)**: Story 013's code review found and fixed a live gold-corruption bug in Epic 02's already-shipped `TowerSystem` (violated the `resources_changed` delta-payload contract). See `docs/tech-debt-register.md` and `production/session-state/active.md` for full detail.

## Overview

Epic 03 covers the two Core-layer economy systems that everything downstream
(Crafting, Menagerie, Constellation, Equipment Forge) depends on. **Inventory**
is the storage ledger — a stack-based, type-driven item system with a
two-panel Sanctuary UI presentation and two operating states
(`INVENTORY_ACTIVE` in Sanctuary, `INVENTORY_HEADLESS` but still write-active
during missions). **Resource Economy** is the pure-calculation accounting
layer that converts monster kills into materials (stored by Inventory) and
gold (a separate always-available track, now owned at runtime by the `MissionEconomy`
Autoload per ADR-0018). Both systems now have shipped, tested code — see
Implementation summary above. Both GDDs are content-complete and passed
`/consistency-check` (2026-07-11) and multiple `/review-all-gdds` cycles
(2026-07-14/15) but remain formally `Needs Revision` pending a final
per-document `/design-review` re-run to flip to Approved — this is a
documentation-process status, independent of the code being implemented and
tested.

## Governing ADRs

*(Section last accurate as of epic creation, 2026-07-11 — corrected 2026-07-13, see below)*

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0016 (Accepted — fixed 2026-07-13, restore_order 20→10) | Inventory storage model: two-tier `ItemDefinitionResource` (GameDataRegistry) + runtime `InventorySlot` (RefCounted, monotonic instance IDs) | MEDIUM (inherited from Save & Persistence boundary) |
| ADR-0017 (Accepted — fixed 2026-07-13, corrected Wave Manager precedent citation) | Resource Economy drop resolution: mission-scoped node (scene-instanced per ADR-0002's own boundary table), `DropTableResource`/`DropEntry` via GameDataRegistry | MEDIUM (same profile as ADR-0016) |
| ADR-0018 (Accepted 2026-07-13) | Mission Economy — new `MissionEconomy` Autoload (boot position 8) resolves gold-balance ownership, previously deferred out of ADR-0017 | LOW |
| ADR-0011 (Accepted 2026-07-13) | UI Dual-Focus Handling — reusable, scene-instanced `InputModeTracker` helper resolves Story 007's gamepad/dual-focus requirement | HIGH (Godot 4.6 dual-focus, post-cutoff — live gamepad verification still required per the ADR) |

✅ **All four governing ADRs are now Accepted.** `architecture.md`'s Module
Ownership entries for both systems were corrected 2026-07-13 but its ADR
Audit/Traceability Matrix has not yet been re-verified — run
`/architecture-review` (fresh session) to confirm.

## GDD Requirements

TR-IDs now exist for both systems (registered 2026-07-13 via `/architecture-review`,
`tr-registry.yaml` v4): `TR-inv-001`/`002`/`003` (inventory.md) and
`TR-econ-001`/`002`/`003` (resource-economy.md). All six are ✅ Covered.

| Requirement | Source | TR-ID | ADR Coverage |
|---|---|---|---|
| Type-driven stack caps (Equipment/Components=1, Materials/Crafted Goods=99) | inventory.md Core Rules | TR-inv-001 | ✅ ADR-0016 |
| `instance_id`-keyed unique-item identity — stat-rolled duplicates never merge (AC-18) | inventory.md AC-18 | TR-inv-002 | ✅ ADR-0016 |
| `SaveRestorer` + `restore_order` below Hero's 30 | inventory.md Dependencies | TR-inv-003 | ✅ ADR-0016 (restore_order=10) |
| Stateless drop-resolution calculator; no owned persistent data | resource-economy.md Core Rule 1 | TR-econ-001 | ✅ ADR-0017 |
| `DropTableResource`/`DropEntry` schema + drop quantity/quality Formulas 1-4 | resource-economy.md Core Rules/Formulas | TR-econ-002 | ✅ ADR-0017 |
| Gold track via `resources_changed`, separate from materials (incl. balance ownership) | resource-economy.md Core Rule 7-8 | TR-econ-003 | ✅ ADR-0017 (emission) + ADR-0018 (balance ownership) |
| `item_added`/`item_removed`/`equipment_slot_changed` EventBus contract | inventory.md / event-bus.md (frozen) | — | ✅ Already-shipped signals, no ADR needed |
| `item_pickup_rejected` new signal (full-inventory mid-mission rejection) | inventory.md Edge Cases | — | ✅ Catalogued in `event-bus.md` 2026-07-13 |

## Known Blockers (status as of 2026-07-13)

- ~~No system owns the runtime gold balance~~ — **Resolved.** ADR-0018's `MissionEconomy` Autoload owns it.
- **Tower → Inventory event gap** (still open): `tower.md` claims destroyed components
  "return to inventory" but emits no event for it. Needs a small `tower.md` +
  `event-bus.md` follow-up before an Inventory story can implement component
  recovery. Not architecturally blocking — no story in this epic currently requires it.
- ~~`item_pickup_rejected` and `resources_changed` missing from `event-bus.md`'s formal catalogue~~ — **Resolved 2026-07-13.** Both are now catalogued (`item_pickup_rejected` under Inventory System; `resources_changed` under Resource Economy System); `item_added`'s payload also extended with an optional `metadata: Dictionary` field.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/inventory.md` and
  `design/gdd/resource-economy.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- ~~ADRs exist covering the requirements table above~~ — **Done**: ADR-0016, ADR-0017, ADR-0018, ADR-0011 all Accepted (2026-07-13)
- Both GDDs have passed `/design-review` (still not yet run — outstanding, non-blocking for architecture purposes)
- ~~`event-bus.md` catalogue updated with `item_pickup_rejected` and `resources_changed`~~ — **Done** (2026-07-13)

## Next Step

**Epic 03 is complete — all 15 of 15 stories Complete (2026-07-16).** No
implementation stories remain. Recommended next actions:
1. A fresh-session `/architecture-review` to confirm the full ADR chain
   (including the mid-implementation ADR-0008/ADR-0011/ADR-0017/Story-014/015
   amendments) — not blocking, but good hygiene before formally closing the epic.
2. A final per-document `/design-review` re-run on `inventory.md` and
   `resource-economy.md` to flip both GDDs from `Needs Revision` to `Approved`.
3. Downstream epics that depend on Core Economy (Crafting, Menagerie,
   Constellation, Equipment Forge) can now be scoped, since their shared
   dependency is fully implemented and tested.

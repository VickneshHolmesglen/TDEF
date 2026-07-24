# Story 010: Equipment Crafting Resolution & Material Cost

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/equipment-forge.md`
**Requirement**: `TR-equipforge-001`

**ADR Governing Implementation**: ADR-0025 (Equipment Forge Cross-System Aggregation)
**ADR Decision Summary**: On confirmation of a craftable Equipment Recipe, Equipment Forge performs 5 steps synchronously and atomically, mirroring Crafting Rule 8 exactly: re-validate `has_items`, validate `has_room_for`, batch-consume inputs, construct the output item with free rune slots, emit `hero_equipment_crafted`. Material cost reuses Crafting's registered `crafting_material_qty` formula unchanged.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `has_room_for()` is now specified by ADR-0021 (Inventory API) — no longer an unimplemented-interface blocker at the architecture level, only pending ADR-0021's own acceptance.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0025 directly.
- Forbidden: Steps (a)–(e) must execute synchronously and atomically within one confirm — instant on confirmation, no timer, no queue (Sanctuary is a deliberate-planning space, not an idle-waiting space).
- Guardrail: Formula 1 reuses `tower.md`'s `tier_dps_multiplier` unchanged via Crafting's own registered formula — never fork a separate Equipment-Forge-only copy.

---

## Acceptance Criteria

*From GDD `design/gdd/equipment-forge.md`, scoped to this story:*

- [x] AC-8 — stale-UI insufficient-materials re-validation at confirm rejects the craft cleanly, zero consumption
- [x] AC-9 *(interface now specified by ADR-0021, pending its acceptance)* — no-room pre-check rejects the craft in full before any material is consumed
- [x] AC-10 — sufficient materials + room: steps (a)–(e) execute synchronously, item added with `rune_slot_count` free empty slots, `hero_equipment_crafted` fires exactly once
- [x] AC-11 — Formula 1 worked example: Tier-2 `weapon`-slot recipe costs exactly 13 Common + 6 Uncommon + 0 Rare

---

## Implementation Notes

*Derived from ADR-0025 Implementation Guidelines:*

- Resolution order (Rule 9), mirroring Crafting Rule 8 exactly: (a) re-validate `has_items(inputs)`; (b) validate `has_room_for(output_slot, 1)` (Inventory pre-check); (c) batch-consume `inputs` via Inventory; (d) construct the output item (`rune_slot_count` free rune slots per Rule 11's table, all empty) and add via `item_added`; (e) emit `hero_equipment_crafted(item_id, item_type=output_slot, quality_tier)`. All synchronous and atomic within one confirm.
- **Formula 1** (material cost): `material_qty(rarity, T) = round(base_qty[rarity] × tier_dps_multiplier(T))` — reuses Crafting's registered `crafting_material_qty` formula unchanged, itself reusing `tower.md`'s `tier_dps_multiplier` (`{1.0, 1.6, 2.4, 4.0}` for T=1–4). `base_qty`: Common=8, Uncommon=4, Rare=2.
- Worked example: Tier 2 → `base_qty × 1.6`: Common `8×1.6=12.8→13` (round), Uncommon `4×1.6=6.4→6`, Rare `2×1.6=3.2→0` at this tier per the registered table (0 Rare at T≤2 per Crafting's own table) — identical arithmetic to a Tier 2 Tower Component recipe, since both consume the same registered formula.
- Any future change to `tower.md`'s `tier_dps_multiplier` automatically re-scales this formula's output for both Crafting and Equipment Forge simultaneously — do not fork a separate copy.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: the recipe schema/discovery this resolution flow consumes
- Story 015: the `_forge_resolving` concurrency guard spanning this and the other two operation types

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-8**: Stale-UI insufficient materials
  - Given: a craftable Equipment Recipe whose required materials are spent by another action between UI render and confirm
  - When: confirm is pressed
  - Then: step (a)'s `has_items(inputs)` re-validation returns false, craft rejected, zero materials consumed, no event beyond a UI refresh

- **AC-9**: No-room pre-check *(interface specified by ADR-0021, pending acceptance)*
  - Given: a craftable Equipment Recipe whose output slot has no free Inventory room
  - When: confirm is pressed
  - Then: step (b)'s `has_room_for(output_slot, 1)` pre-check returns false, craft rejected in full before step (c) ever runs, zero materials consumed

- **AC-10**: Successful craft, synchronous
  - Given: a craftable Equipment Recipe with sufficient materials and room
  - When: confirm is pressed
  - Then: steps (a)–(e) execute synchronously within the same frame — materials batch-consumed, item added with `rune_slot_count` free empty slots, `hero_equipment_crafted(item_id, item_type=output_slot, quality_tier)` fires exactly once

- **AC-11**: Formula 1 worked example
  - Given: a Tier-2 `weapon`-slot Equipment Recipe
  - When: Formula 1 is evaluated
  - Then: material cost is exactly 13 Common + 6 Uncommon + 0 Rare

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/equipment-forge/crafting-resolution-material-cost_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/equipment-forge/crafting-resolution-material-cost_test.gd` (9 tests, passing)

---

## Dependencies

- Depends on: Story 008, Story 009
- Unlocks: Story 011, Story 015

**Unblocked**: ADR-0025 accepted 2026-07-18 (Sprint 6, S6-04).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 4/4 passing (9 unit tests, all passing).
**Deviations**: `InventorySlot.rune_slot_count`/`imbued_runes` fields added now (ahead of Story 013/ADR-0021) since AC-10 explicitly requires the crafted item to carry free rune-slot capacity at creation — `Inventory.add_unique_item()` extended with a new optional, backward-compatible parameter (default 0, no existing call site affected). Filling the slots (imbuing) remains Story 013's own scope, untouched here. `_forge_resolving` (the full 3-operation shared guard) is Story 015's scope — `resolve_craft()` uses its own narrower `_craft_resolving` flag for this operation type only, consistent with the story's own Out-of-Scope note.
**Test Evidence**: Logic — `tests/unit/equipment-forge/crafting-resolution-material-cost_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Equipment Forge checkpoint, per this session's established pattern.

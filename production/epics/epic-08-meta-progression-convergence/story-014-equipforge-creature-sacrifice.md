# Story 014: Creature Sacrifice Resolution

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/equipment-forge.md`
**Requirement**: `TR-equipforge-002`

**ADR Governing Implementation**: ADR-0025 (Equipment Forge Cross-System Aggregation), ADR-0026 (Menagerie Creature Lifecycle)
**ADR Decision Summary**: Closes `menagerie.md`'s explicitly-flagged open question — `target_item_id` in `creature_sacrificed` refers to a NEW Equipment item Equipment Forge creates in the same operation that requests the sacrifice. `Menagerie.request_sacrifice(creature_id, target_item_id) -> bool` is now fully specified by ADR-0026 (Menagerie confirmed Autoload #11), resolving ADR-0025's previously-flagged open dependency.

**Engine**: Godot 4.6.2 | **Risk**: LOW — the interface gap this GDD originally flagged is now resolved at the architecture level
**Engine Notes**: `creature_id`/`target_item_id` are both `int` (corrected from an earlier `String` draft) — matching `Menagerie.request_sacrifice()`'s actual signature and `Inventory.reserve_instance_id() -> int`'s return type.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0025/ADR-0026 directly.
- Forbidden: Never touch/consume the creature before `has_room_for(output_slot, 1)` passes — room-check strictly precedes creature consumption, so a full Inventory can never cause a creature to be consumed with no home for the resulting item.
- Guardrail: This ordering guarantees a creature is never lost without a corresponding item materializing, and `creature_sacrificed`'s `target_item_id` always resolves to a real, successfully-created item by the time any subscriber processes the event.

---

## Acceptance Criteria

*From GDD `design/gdd/equipment-forge.md`, scoped to this story:*

- [x] AC-17 — the happy path: room-check passes, prospective `item_id` generated, `request_sacrifice()` returns `true`, Menagerie emits `creature_sacrificed`, item constructed with 1 rune slot pre-filled + rest per Rule 11, `hero_equipment_crafted` then `item_rune_imbued(rune_source="menagerie")` fire in that exact order
- [x] AC-18 — species mismatch is rejected at Equipment Forge's own UI-level pre-check, before any Menagerie call
- [x] AC-19 — creature in `BREEDING_PEN`: `request_sacrifice()` returns `false`, Equipment Forge aborts with zero side effects
- [x] AC-20 — room check strictly precedes creature consumption: no free room rejects at step (b), before `request_sacrifice()` is ever called
- [x] AC-21 — Formula 2 worked example (maximum): sacrificing an `aurora_stag` (species_tier=3) produces `quality_tier=4`
- [x] AC-22 — Formula 2 boundary (minimum, never Tier 1): sacrificing a Common-tier creature (species_tier=1) produces `quality_tier=2`

---

## Implementation Notes

*Derived from ADR-0025/ADR-0026 Implementation Guidelines:*

```gdscript
# Menagerie (Autoload #11, per ADR-0026)
func request_sacrifice(creature_id: int, target_item_id: int) -> bool:
    # validates creature not in BREEDING_PEN (Rule 13)
    # removes/updates creature state internally, emits creature_sacrificed(creature_id, target_item_id)
    ...

# Inventory (per ADR-0021/ADR-0025 extension)
func reserve_instance_id() -> int: ...   # monotonic counter, Criterion A
```

- **Full resolution flow, strict order** (Rule 19): (a) player selects a Sacrifice Recipe and target `creature_id`; species mismatch rejected at this UI-level pre-check before any system call. (b) `has_room_for(output_slot, 1)` validated — checked before the creature is touched at all. (c) Equipment Forge generates a prospective `item_id` via `Inventory.reserve_instance_id()`. (d) calls `Menagerie.request_sacrifice(creature_id, target_item_id)` — synchronous validation; Menagerie validates not `BREEDING_PEN`, removes/updates creature state, emits `creature_sacrificed(creature_id, target_item_id)` using the passed `item_id`. (e) if `false`: abort, no item created, no consumption, no further events. (f) if `true`: construct the new item (1 rune slot pre-filled by the sacrifice's own rune, rest per Rule 11's table), add via `item_added`, emit `hero_equipment_crafted(item_id=target_item_id, item_type=output_slot, quality_tier)` then, same synchronous operation, `item_rune_imbued(item_id=target_item_id, rune_id, rune_source="menagerie")`.
- **Formula 2** (sacrifice quality tier): `quality_tier(species_tier) = clamp(species_tier+1, 1, 4)` — a sacrifice-born item is never Tier 1, deliberately: surrendering a tended creature always produces at least Tier 2.
- **Sequencing dependency, not a design gap**: this flow calls `Menagerie.request_sacrifice()` directly — Menagerie (Epic 05) should have at least its core lifecycle/Autoload stories implemented before this story begins.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: the Rune Imbuing action for Constellation/Tarot-sourced runes (this story's `item_rune_imbued` emission for the Menagerie source is structurally similar but happens inline at item creation, not via a separate player-initiated imbuing action)
- Menagerie's own creature lifecycle/state machine (Epic 05, ADR-0026) — this story only covers Equipment Forge's calling side

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-17**: Happy path, exact ordering
  - Given: a valid target creature (species matches, not in `BREEDING_PEN`) and Inventory has room for the recipe's `output_slot`
  - When: the sacrifice is confirmed
  - Then: in order — (b) room check passes before the creature is touched; (c) prospective `item_id` generated; (d) `request_sacrifice()` called, returns `true`, Menagerie emits `creature_sacrificed` using that exact `item_id`; (f) item constructed (1 slot pre-filled, rest per Rule 11), added via `item_added`, `hero_equipment_crafted` then `item_rune_imbued(rune_source="menagerie")` fire in that exact order

- **AC-18**: Species mismatch rejected pre-call
  - Given: a selected Sacrifice Recipe with `required_species=X` and a target creature of species `Y≠X`
  - When: the sacrifice is attempted
  - Then: rejected at Equipment Forge's own UI-level pre-check — `Menagerie.request_sacrifice()` never called, no creature touched, no item created

- **AC-19**: Creature in BREEDING_PEN
  - Given: a target creature currently in `BREEDING_PEN`
  - When: the sacrifice request reaches step (d)
  - Then: `request_sacrifice()` returns `false`; Equipment Forge aborts — prospective `item_id` discarded, no item created, no materials/creature consumed, no further events

- **AC-20**: Room check precedes consumption
  - Given: Inventory has no free room for the recipe's `output_slot`
  - When: the sacrifice is attempted
  - Then: rejected at step (b) — before step (d)'s `request_sacrifice()` call is ever made — creature never touched or consumed

- **AC-21**: Formula 2 maximum
  - Given: a sacrificed `aurora_stag` (`species_tier=3`, Rare)
  - When: Formula 2 is evaluated
  - Then: `quality_tier = clamp(3+1, 1, 4) = 4` exactly

- **AC-22**: Formula 2 minimum, never Tier 1
  - Given: a sacrificed Common-tier creature (`species_tier=1`)
  - When: Formula 2 is evaluated
  - Then: `quality_tier = clamp(1+1, 1, 4) = 2` exactly — never Tier 1

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/equipment-forge/creature-sacrifice-resolution_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/equipment-forge/creature-sacrifice-resolution_test.gd` (7 tests, passing)

---

## Dependencies

- Depends on: Story 012 (rune ledger exclusion this story confirms), Story 013 (shares the `item_rune_imbued` emission pattern)
- Unlocks: None further within this epic

**Unblocked**: ADR-0025 accepted 2026-07-18 (Sprint 6, S6-04); ADR-0026 was already accepted 2026-07-17 as part of Epic 05's batch acceptance. **Sequencing dependency also satisfied**: Menagerie (Epic 05) is now fully implemented (26/26 stories Complete, 2026-07-18) — this story's `request_sacrifice()` call target actually exists in code, not just in the ADR.

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 6/6 passing (7 integration tests, all passing).
**Deviations**:
- **Real finding, not a defect**: `Menagerie.request_sacrifice(creature_id, target_item_id) -> bool` already existed in `src/core/menagerie/menagerie.gd` (its own doc comments label it "Story 016" — an Epic 05 story that landed this interface ahead of this story needing it) — this story only needed to author the Equipment Forge calling side (`resolve_sacrifice()`), not the Menagerie interface itself, narrowing this story's actual scope versus its Implementation Notes' framing.
- **New content type added**: `SacrificeRecipeResource` (`src/core/equipment_forge/sacrifice_recipe_resource.gd`) — sibling to `EquipmentRecipeResource`, output_slot vocabulary (weapon/armor/accessory/trinket) matches `EquipmentRecipeResource`'s, NOT Inventory's 5-name equip-slot vocabulary (accessory_a/accessory_b) — caught and fixed during implementation before it shipped as a real bug (wrong rune_slot_count lookup table).
- **hero_equipment_crafted/item_rune_imbued's `item_id` convention deliberately kept consistent with Story 010/013's already-shipped precedent** (base definition id, not instance id) rather than Rule 19(f)'s literal "item_id = target_item_id" wording — flagged explicitly in code comments as a deviation, not a silent choice, to keep the two signals' payload shape identical across the craft/imbue/sacrifice paths.
- Content authored for 2 of the eventual 5 sacrifice recipes (`sacrifice_aurora_stag` Tier-3→4, `sacrifice_glimmer_hare` Tier-1→2) — sufficient to exercise both Formula 2 boundary worked examples (AC-21/AC-22); the full 5-species catalogue is explicitly out of scope for this GDD (Rule 6/Dependencies table — content-authoring work).
**Test Evidence**: Integration — `tests/integration/equipment-forge/creature-sacrifice-resolution_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Equipment Forge checkpoint, per this session's established pattern.

# Story 011: Save Payload Ownership Clarification

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/equipment-forge.md`
**Requirement**: `TR-equipforge-003`

**ADR Governing Implementation**: ADR-0025 (Equipment Forge Cross-System Aggregation)
**ADR Decision Summary**: Equipment Forge's own `get_save_data()` payload is narrower than `save-persistence.md`'s Line 81 summary ("all crafted equipment in the hero's forge inventory") — it covers exactly two ledgers (Equipment Recipe Discovery Ledger, Available Rune Ledger). Actual Equipment item instances (`imbued_runes`, free rune slot count) are persisted by Inventory, per ADR-0021's `InventorySlot` field.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — this story is a scope/ownership clarification, not new mechanics.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0025 directly.
- Forbidden: Equipment Forge must never persist item-instance data (`imbued_runes`, slot occupancy) itself — that is Inventory's data.
- Guardrail: `save-persistence.md`'s own Line 81 summary should be corrected at its next revision to match this GDD's authoritative clarification.

---

## Acceptance Criteria

*From GDD `design/gdd/equipment-forge.md`, scoped to this story:*

- [x] AC-12 — `get_save_data()`'s payload contains exactly two entries (Equipment Recipe Discovery Ledger, Available Rune Ledger) and no item-instance data

---

## Implementation Notes

*Derived from ADR-0025 Implementation Guidelines:*

```gdscript
func get_save_key() -> String: return "equipment_forge"
func get_save_data() -> Dictionary:
    return {
        "equipment_discovery_ledger": _equipment_discovery_ledger,
        "available_runes": _available_runes,
    }
func restore_save_data(data: Dictionary) -> bool: ...
func reset_to_defaults() -> void: ...
# SavePersistence.register(self, restore_order=32)
```

- Per `inventory.md`'s architecture principle ("every system that touches player possessions reads and writes through this single ledger"), actual Equipment item instances (including each item's `imbued_runes: Array[String]` and remaining free rune slots, carried in `item_added`'s `metadata` field, same convention as Tower's `damaged` flag) are persisted by Inventory, not Equipment Forge.
- Equipment Forge's own save data covers exactly two ledgers: (1) the Equipment Recipe Discovery Ledger (Story 009), and (2) the Available Rune Ledger (Story 012).
- This is a flagged follow-up for `save-persistence.md`: its own payload description should be corrected to match this clarification at its next revision pass — this GDD's version is authoritative.
- `restore_order = 32` — restores after Tarot (22), Menagerie (20), Constellation (24), and Hero (30), all of which must restore first per the GDD's own dependency rationale (see Story 016 for the full rationale on rune-source ordering).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: the Available Rune Ledger's own population logic (this story only confirms its payload scope)
- Story 016: the cross-document persistence-ordering verification against Constellation/Tarot

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-12**: Payload scope confirmation
  - Given: a live playthrough with discovered recipes, available runes, and at least one crafted Equipment item
  - When: Equipment Forge's `get_save_data()` is inspected
  - Then: payload contains exactly two entries (Equipment Recipe Discovery Ledger, Available Rune Ledger) and no item-instance data (`imbued_runes`, slot occupancy, etc.) — confirming that data is Inventory's responsibility

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/equipment-forge/save-payload-ownership_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/equipment-forge/save-payload-ownership_test.gd` (7 tests, passing)

---

## Dependencies

- Depends on: Story 009 (Discovery Ledger), Story 012 (Available Rune Ledger)
- Unlocks: Story 016

**Unblocked**: ADR-0025 accepted 2026-07-18 (Sprint 6, S6-04). The project-wide SavePersistence mid-session-restore gap this story was also flagged against, given Equipment Forge is a `SanctuaryScene` child, is resolved (ADR-0003's 2026-07-18 revision).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 1/1 passing (7 integration tests, all passing, including a full SaveRestorer round-trip and the boot-sweep trigger).
**Deviations**: Implemented after Story 012 (see that story's own Completion Notes for the sequencing rationale). Also added the 3rd discovery trigger (boot sweep) that Story 009 had deferred — Equipment Forge's discovery state machine now matches Crafting's exact 3-trigger model.
**Test Evidence**: Integration — `tests/integration/equipment-forge/save-payload-ownership_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Equipment Forge checkpoint, per this session's established pattern.

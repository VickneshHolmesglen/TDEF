# Story 013: Rune Imbuing Action

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/equipment-forge.md`
**Requirement**: `TR-equipforge-001`

**ADR Governing Implementation**: ADR-0025 (Equipment Forge Cross-System Aggregation), ADR-0021 (Inventory Cross-System API)
**ADR Decision Summary**: Rune Imbuing calls `Inventory.apply_rune_to_item(item_id, rune_id, stat_delta) -> bool` — now fully specified by ADR-0021, including its explicit, scoped exemption to Inventory's Rule 5 equipped-item lock (a metadata mutation, not a removal, so it must succeed on a currently-equipped item). A rune is consumed on imbue — one-time use, never re-imbuable, no "un-imbue" action exists.

**Engine**: Godot 4.6.2 | **Risk**: LOW — this is the GDD's own flagged highest-risk fragility item (Dependencies row #11), but the interface itself is now fully specified, not merely proposed
**Engine Notes**: `InventorySlot` is a plain `RefCounted`, not a Resource tree — `apply_rune_to_item()`'s in-place mutation of `imbued_runes` does not require `duplicate_deep()`.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0021/ADR-0025 directly.
- Forbidden: `apply_rune_to_item()` must never check the `locked` flag — this is an explicit, architecturally-stated exemption to Inventory's Rule 5, not left to per-caller discipline. If it were blocked by the lock check, players would be forced into an unequip→imbue→re-equip cycle for every rune, which this GDD explicitly rejects.
- Guardrail: `apply_rune_to_item()` never fires `item_added`/`item_removed` — it's an in-place mutation, not a removal/recreation. A future caller must not assume it triggers a UI refresh via those events.

---

## Acceptance Criteria

*From GDD `design/gdd/equipment-forge.md`, scoped to this story:*

- [x] AC-16(a) — imbuing a currently-equipped item succeeds: `apply_rune_to_item` returns `true`, `imbued_runes` appended in place, `item_rune_imbued` fires once, item remains equipped throughout, no `equipment_slot_changed` side effect
- [x] AC-16(b) — the rune is consumed one-time-use: transitions `AVAILABLE → IMBUED`, absent from `available_runes` afterward, no path can reintroduce it
- [x] AC-16(c) — no free rune slot: `apply_rune_to_item` returns `false`, no mutation, rune remains `AVAILABLE`, no forced "replace an existing rune" prompt
- [x] AC-16(d) — each of the 3 rune sources (`constellation`/`tarot`/`menagerie`) records the exact literal string in `item_rune_imbued`'s `rune_source` field

---

## Implementation Notes

*Derived from ADR-0021/ADR-0025 Implementation Guidelines:*

```gdscript
# Inventory (ADR-0021)
func apply_rune_to_item(item_id: String, rune_id: String, stat_delta: Dictionary) -> bool:
    # validates target item still has a free rune slot (false, no mutation, if not)
    # mutates the existing item instance in place: imbued_runes appended, one slot consumed
    # does NOT check `locked` — explicit exemption to Rule 5
    # does NOT fire item_added/item_removed
    ...
```

- Rune Imbuing is Sanctuary-only, player-initiated: the player selects (a) an owned Equipment item with at least one free rune slot — **equipped or unequipped, no restriction** — and (b) one `available_runes` entry. On confirm, Equipment Forge calls `apply_rune_to_item()`; on success, removes the rune from `available_runes` and emits `item_rune_imbued(item_id, rune_id, rune_source)` where `rune_source` is exactly `"constellation"`, `"tarot"`, or `"menagerie"`.
- A rune is consumed on imbue — permanently removed from `available_runes`, cannot be un-imbued, moved, or refunded by any means. Matches the project's established "meaningful, costly choice" pattern (same register as Menagerie's sacrifice, Constellation's fixed shape commitments).
- If the target item has no free rune slot, `apply_rune_to_item()` returns `false` without mutating anything — the action is rejected cleanly, the player is never forced to choose which existing rune to replace (no "swap out" mechanic exists). The rune remains `AVAILABLE`, unconsumed.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: the ledger population this story's imbuing consumes from
- Story 014: Menagerie-sourced rune creation (this story covers the imbuing action itself, applicable to all 3 sources once a rune is `AVAILABLE` or created)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-16(a)**: Imbuing a currently-equipped item
  - Given: an Equipment item currently equipped in a Hero slot, with at least one free rune slot, and a `rune_id` in state `AVAILABLE`
  - When: the player confirms Rune Imbuing targeting that item
  - Then: `apply_rune_to_item(item_id, rune_id, stat_delta)` is called and returns `true`, `imbued_runes` appended in place (no `item_removed`/`item_added` pair), `item_rune_imbued(item_id, rune_id, rune_source)` fires exactly once, the item remains equipped throughout — no unequip→imbue→re-equip cycle, `equipment_slot_changed` does not fire as a side effect

- **AC-16(b)**: One-time-use consumption
  - Given: `rune_id=R` was successfully imbued into item `A` per AC-16(a)
  - When: the Imbuing UI's rune pool is queried afterward
  - Then: `R` is absent from `available_runes` (transitioned `AVAILABLE → IMBUED`, terminal); no subsequent call — targeting `A` again, targeting a different item `B`, or any other path — can select `R` as an input

- **AC-16(c)**: Clean rejection, no free slot
  - Given: a target item whose every rune slot is already `FILLED`
  - When: Rune Imbuing is confirmed against it with any `AVAILABLE` rune
  - Then: `apply_rune_to_item()` returns `false`, `imbued_runes` unchanged, candidate rune remains `AVAILABLE`, no `item_rune_imbued` fires, player never prompted to choose an existing rune to replace

- **AC-16(d)**: Rune source literal strings
  - Given: a Constellation-sourced rune successfully imbued
  - When: `item_rune_imbued` fires
  - Then: `rune_source == "constellation"` exactly
  - Edge cases: repeat for a Tarot-sourced rune (`"tarot"`) and a Menagerie-sourced rune imbued at item creation (`"menagerie"`) — all three verify exact literal strings, no numeric enum, no case variance

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/equipment-forge/rune-imbuing-action_test.gd` — must exist and pass, specifically including a case where the target item is currently equipped (`locked == true`)

**Status**: [x] Created — `tests/integration/equipment-forge/rune-imbuing-action_test.gd` (8 tests, passing, including an equipped-item case)

---

## Dependencies

- Depends on: Story 012 (Available Rune Ledger)
- Unlocks: Story 014 (the Menagerie sacrifice flow's own imbuing step reuses this mechanism), Story 015

**Unblocked**: ADR-0025 accepted 2026-07-18 (Sprint 6, S6-04). ADR-0021 (the Inventory API this story calls) was already accepted 2026-07-17 as part of Epic 05's batch acceptance.

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 4/4 passing (8 integration tests, all passing). `apply_rune_to_item()` targets by `instance_id`, not `item_id` — the same naming correction already established by `clear_damaged_flag()` for the identical ADR-0021 parameter-naming ambiguity.
**Deviations**: **Real gap explicitly flagged, not silently solved**: `stat_delta` is accepted per ADR-0021's signature but neither Inventory nor Equipment Forge persists it anywhere retrievable after the imbue call — `InventorySlot.imbued_runes` stores only `rune_id`, and the Available Rune Ledger (the only place `stat_delta` lived) is erased on imbue. Hero's eventual reading of an already-imbued rune's bonus magnitude has no data source yet — out of this story's own AC-16 scope (imbuing mechanics only, not stat application), documented for a future story/session rather than assumed solved. Also surfaced: Story 008's `equip_item()` has no path to relocate an already-crafted item into a named equipment slot — tests represent "currently equipped" via `InventorySlot.locked` directly, which is what that field means; not a defect, just a documented test-design note.
**Test Evidence**: Integration — `tests/integration/equipment-forge/rune-imbuing-action_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Equipment Forge checkpoint, per this session's established pattern.

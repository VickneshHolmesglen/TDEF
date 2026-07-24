# Story 006: Orphaned Data & Content-Change Edge Cases

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/hero-skill-build.md`
**Requirement**: `TR-heroskill-001`

**ADR Governing Implementation**: ADR-0030 (Hero Skill Build Ultimate Lookup-Table Architecture)
**ADR Decision Summary**: Orphaned slot bindings, library entries, and passive-slot occupants are preserved (never discarded) and marked `UNKNOWN` internally, mirroring `hero.md`'s `class_id` orphan handling and `tower-mastery.md`'s `skill_id` orphan handling precedent. A `passive_slot_count` reduction is the one orphan case that actively returns something to the player.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — pure data-integrity/defensive-guard logic.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0030 directly.
- Forbidden: Never auto-clear an orphaned slot binding or discard orphaned library/passive-slot data — always preserve, mark `UNKNOWN`, log a warning, never block the load.
- Guardrail: An `UNKNOWN` slot occupant is treated identically to an empty slot for Ultimate derivation purposes (resolves to `EMPTY`) until the player manually reassigns it at Sanctuary.

---

## Acceptance Criteria

*From GDD `design/gdd/hero-skill-build.md`, scoped to this story:*

- [x] AC-21 — orphaned `skill_id` in an active slot binding is preserved, marked `UNKNOWN`, Ultimate treats it as unfilled
- [x] AC-22 — orphaned `skill_id` in the equippable library is preserved but hidden from UI
- [x] AC-23 — removed skill-modifier item in a passive slot is treated as empty for effects, binding preserved
- [x] AC-24 — `passive_slot_count` reduction returns the orphaned item to Inventory (the one orphan case that actively returns something)
- [x] AC-25 — off-build passive configuration is allowed for unequipped skills

---

## Implementation Notes

*Derived from ADR-0030 Implementation Guidelines / hero-skill-build.md's Edge Cases:*

- **Orphaned active-slot binding**: if a save references a `skill_id` no longer in the current catalogue, restore the binding as orphaned (don't discard), mark `UNKNOWN` internally, log a warning, never block the load. For Ultimate derivation, an `UNKNOWN`-bound slot is treated identically to empty (Rule 7's "known skill" precondition not met) — Ultimate resolves to `EMPTY` until manually reassigned.
- **Orphaned library entry**: distinct from the above — the equippable-skill library itself containing a `skill_id` no longer in the catalogue. Mark `UNKNOWN`, don't surface as assignable in the UI, don't discard from persisted data, log a warning, never block.
- **Removed skill-modifier item**: if an item installed in a passive slot is removed from game content (post-launch, not player action), mark the slot's occupant `UNKNOWN`, apply no effect (treat as empty for `effect_data` folding), don't auto-clear the binding, log a warning, never block.
- **`passive_slot_count` reduction**: if a skill's slot count is reduced by a content patch and a save has an item bound to the now-nonexistent slot, treat the excess binding as orphaned (don't silently delete), restore internally, don't surface in UI (only current slot count sockets render), and **return the bound item to the player's Inventory** unlocked — the one orphan case that actively returns something, since an item stuck in a structurally-nonexistent slot has no other path back to usability.
- **Off-build passive configuration**: allowed — passive slot configuration is per-`skill_id`, not per-currently-equipped-slot. A skill sitting unequipped in the library still has its own persistent passive loadout, letting players pre-configure passives before deciding to slot it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: the happy-path persistence boundary this story's edge cases build on
- Story 004: passive-slot assignment mechanics themselves

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-21**: Orphaned active-slot binding preserved
  - Given: a save references a `skill_id` in an active slot no longer in the current catalogue
  - When: the save is restored
  - Then: the binding is preserved, marked `UNKNOWN` internally (not auto-cleared), warning logged, load never blocked, Ultimate derivation treats that slot as unfilled (resolves to `EMPTY`) until manually reassigned

- **AC-22**: Orphaned library entry hidden from UI
  - Given: the persisted equippable-skill library contains a `skill_id` no longer in the catalogue
  - When: the save is restored
  - Then: the entry is marked `UNKNOWN`, not surfaced as assignable, not discarded, warning logged, load never blocked

- **AC-23**: Removed passive item treated as empty
  - Given: a skill-modifier item in a passive slot is removed from content data
  - When: the save is restored or the skill activates
  - Then: the passive slot's occupant is marked `UNKNOWN`, contributes no effect, binding preserved (not discarded), warning logged, load never blocked

- **AC-24**: passive_slot_count reduction returns the item
  - Given: a skill's `passive_slot_count` is reduced (e.g. 3→2) and a save has an item bound to the now-nonexistent 3rd slot
  - When: the save loads post-patch
  - Then: the excess binding is restored internally but not rendered (only current sockets show), the bound item is returned to Inventory unlocked

- **AC-25**: Off-build passive configuration allowed
  - Given: a skill exists in the library but is not currently occupying any active slot
  - When: the player equips a skill-modifier item into one of that skill's passive slots
  - Then: the equip succeeds — passive slot configuration is per-`skill_id`, not per-currently-equipped-slot

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/hero-skill-build/orphaned-data-content-change_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/hero-skill-build/orphaned-data-content-change_test.gd` (9 tests, passing)

---

## Dependencies

- Depends on: Story 005 (persistence boundary these edge cases wrap)
- Unlocks: None further within this epic

**Unblocked**: ADR-0030 accepted 2026-07-18 (Sprint 6, S6-04).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 5/5 passing (9 unit tests, all passing). New `get_assignable_skills()`/`get_effective_passive_loadout()` query methods; `_reconcile_passive_slot_overflow()` added to `restore_save_data()`.
**Deviations**: AC-24's "restore internally, don't surface, return the item" was interpreted as relocation (trim the excess array entry, grant the item via `GInventory.add_unique_item()`/`add_stackable()`) rather than literal dual preservation (keeping both the array entry AND returning the item) — documented in the code comment as the chosen reading of an internally ambiguous ADR sentence. Skill-modifier items don't exist as real content yet (Story 004/007's own flagged, still-open `inventory.md` gap), so this path is currently exercised only by test fixtures using real unrelated items (e.g. `iron_ore`) as stand-ins.
**Test Evidence**: Logic — `tests/unit/hero-skill-build/orphaned-data-content-change_test.gd`.
**Code Review**: Complete (batch review across Stories 001-007) — APPROVED WITH SUGGESTIONS, required fixes applied (including a fix to this story's own Inventory-return logging accuracy).

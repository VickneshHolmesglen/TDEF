# Story 016: Rune Ledger Persistence Across Save/Load

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/equipment-forge.md`
**Requirement**: `TR-equipforge-003`

**ADR Governing Implementation**: ADR-0025 (Equipment Forge Cross-System Aggregation)
**ADR Decision Summary**: `restore_order = 32` must restore after Tarot (22), Menagerie (20), Constellation (24), and Hero (30) — all four confirmed to restore first. **Constellation's previously-missing `restore_order` (which left the GDD's own AC-26 explicitly unverifiable) is now resolved by ADR-0022's `restore_order=24`** — this ADR confirms 24 < 32, satisfying the GDD's own dependency rationale. This closes what the GDD text itself still describes as an open cross-document gap.

**Engine**: Godot 4.6.2 | **Risk**: LOW — the blocking cross-document gap this GDD originally flagged is now resolved
**Engine Notes**: No new engine subsystem — this story is a persistence-ordering verification.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0025 directly.
- Forbidden: Do not mark Constellation-sourced rune persistence unverifiable — the GDD's own text (written before ADR-0022 landed) says this cannot be tested; ADR-0025 explicitly confirms it now can be, since Constellation's `restore_order=24` is assigned and compatible.
- Guardrail: Equipment Forge's own restore work reconstructs its ledgers from scratch — this requires each rune source's own Discovery Ledger to already be in its final restored state, or the rebuild would be incomplete.

---

## Acceptance Criteria

*From GDD `design/gdd/equipment-forge.md`, scoped to this story:*

- [x] AC-26 *(previously flagged unverifiable by the GDD text — now resolved by ADR-0022's `restore_order=24`)* — a Constellation-sourced rune already `AVAILABLE` before save is still correctly present and selectable in `available_runes` post-restore
- [x] AC-27 *(contrast case, always verifiable)* — a Tarot-sourced rune already `AVAILABLE` before save is still correctly present post-restore

---

## Implementation Notes

*Derived from ADR-0025 Implementation Guidelines:*

- **`restore_order = 32` dependency rationale**: Equipment Forge's own restore work is reconstructing its two ledgers from scratch on load — this requires each rune source's own Discovery Ledger to already be in its final restored state, or `available_runes` could be rebuilt incompletely.
  - **Tarot (22)** must restore first so Equipment Forge's rebuild correctly reflects every `tarot_rune_discovered` event that has legitimately fired across the playthrough.
  - **Hero (30)** must restore first so any item already carrying imbued runes can be cross-validated against Hero's restored 5-slot loadout without a race.
  - **Menagerie (20)** must restore first for consistency with the Feature-before-Advanced layering discipline (no sacrifice-in-progress state persists across saves, so this is structural, not data-race-driven).
  - **Constellation (24)** — this GDD's text originally flagged this AC as unverifiable because Constellation had no assigned `restore_order` anywhere. **ADR-0022 has since assigned `restore_order=24`**, and this ADR (ADR-0025) confirms 24 < 32 is compatible — the gap is closed. Do not perpetuate the GDD's stale "unverifiable" framing when implementing or testing this story.
- The actual restore mechanism: on `restore_save_data()`, Equipment Forge does **not** re-subscribe-and-replay past `constellation_rune_discovered`/`tarot_rune_discovered` events — it restores its own persisted `available_runes` Dictionary directly (the ledger itself is the save payload, per Story 011's ownership clarification), so correctness here depends on Equipment Forge's own ledger having been correctly populated and saved *before* the save point, not on re-deriving it live from the source systems' ledgers at restore time.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: the save payload's own scope/ownership (this story verifies its cross-document restore-ordering correctness)
- Story 012: the ledger's live population logic during active play (this story covers only the save/load round-trip)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-26**: Constellation-sourced rune persistence
  - Given: a Constellation-sourced rune already `AVAILABLE` in `available_runes` before save
  - When: a save/load cycle completes (`restore_order=32`, depending on Constellation's own ledger — `restore_order=24` per ADR-0022 — having already restored)
  - Then: the rune is still correctly present and selectable in `available_runes` post-restore
  - Edge cases: this AC is now verifiable — do not treat it as blocked per the GDD's own pre-ADR-0022 text; confirm 24 < 32 ordering explicitly in the test setup

- **AC-27**: Tarot-sourced rune persistence *(contrast case)*
  - Given: a Tarot-sourced rune already `AVAILABLE` in `available_runes` before save
  - When: a save/load cycle completes
  - Then: the rune is still correctly present post-restore — verifiable today since Tarot's `restore_order=22` already exists and is confirmed to restore before Equipment Forge's 32

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/equipment-forge/rune-ledger-persistence-save-load_test.gd` — must exist and pass, covering both Constellation (24) and Tarot (22) source ordering against Equipment Forge's 32

**Status**: [x] Created — `tests/integration/equipment-forge/rune-ledger-persistence-save-load_test.gd` (4 tests, passing)

---

## Dependencies

- Depends on: Story 011 (save payload ownership), Story 012 (ledger population)
- Unlocks: None further within this epic — completes Equipment Forge's persistence coverage

**Unblocked**: ADR-0025 accepted 2026-07-18 (Sprint 6, S6-04). The project-wide SavePersistence mid-session-restore gap this story was also flagged against, given Equipment Forge is a `SanctuaryScene` child, is resolved (ADR-0003's 2026-07-18 revision).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 2/2 passing (4 integration tests, all passing).
**Deviations**: None. This was a verification story — Story 011's `get_save_data()`/`restore_save_data()` already round-trip `available_runes` directly (no live re-derivation from Constellation's/Tarot's own ledgers at restore time), so no production code changes were needed. Confirmed structurally (`Tarot.RESTORE_ORDER=22 < Constellation.RESTORE_ORDER=24 < EquipmentForge.RESTORE_ORDER=32`) and behaviorally (both a Constellation-sourced and a Tarot-sourced rune round-trip correctly and remain genuinely imbuable post-restore, not just present in the ledger). Closes the GDD's own previously-flagged-unverifiable AC-26 gap.
**Test Evidence**: Integration — `tests/integration/equipment-forge/rune-ledger-persistence-save-load_test.gd`.
**Code Review**: Pending — deferred to a batch pass now that all of Equipment Forge (Stories 008-016) is Complete.

# Story 007: State Tables & Persistence

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tarot.md`
**Requirement**: `TR-tarot-002`, `TR-tarot-003`

**ADR Governing Implementation**: ADR-0027 (Tarot Modifier Aggregation Pipeline)
**ADR Decision Summary**: All three ledger structures (`_mastery_missions_played`, `_rune_discovered`, `_card_unlocked`) plus `_deck_template` (the Sanctuary-time equipped list) are covered by one `SaveRestorer` implementation at `restore_order = 22` (already assigned in `save-persistence.md`). `_active_mission_deck` (the mission-locked snapshot) is explicitly excluded — ephemeral, mission-scoped only.

**Engine**: Godot 4.6.2 | **Risk**: LOW (architecture) — but see Guardrail below for the project-wide gap this story is subject to
**Engine Notes**: Three `Dictionary` structures are primitive-only, satisfying ADR-0003's save-data constraint directly.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0003/ADR-0027 directly.
- Forbidden: Never include `_active_mission_deck` in `get_save_data()`'s payload — only `_deck_template` persists.
- Guardrail: **Project-wide SavePersistence gap** — Tarot is a `SanctuaryScene` child (scene-instanced, not Autoload), subject to the same mid-session-restore gap as Crafting/Constellation (flagged in ADR-0029's Risks, applies project-wide). Do not mark this story's persistence behavior fully verified until that gap is resolved — see `EPIC.md` Known Blockers.

---

## Acceptance Criteria

*From GDD `design/gdd/tarot.md`, scoped to this story:*

- [x] AC-40 — `EDITABLE` → `LOCKED` transition on `mission_launched`, remains locked for the mission's full duration
- [x] AC-41 — `LOCKED` → `EDITABLE` on mission end (either outcome)
- [x] AC-42 — Tier 3 → Tier 4 transition at `mastery_missions_played` crossing 25, `mastery_tier_scalar` becomes `1.75`, terminal
- [x] AC-43 — `UNDISCOVERED` default state at fresh save/playthrough start: no rune effect applies, no discovery event fired
- [x] AC-44 — `DISCOVERED` state survives a save reload in a later session, `restore_order = 22`, never reverts

---

## Implementation Notes

*Derived from ADR-0027 Implementation Guidelines:*

```gdscript
func get_save_key() -> String: return "tarot"
func get_save_data() -> Dictionary:
    return {
        "mastery_missions_played": _mastery_missions_played,
        "rune_discovered": _rune_discovered,
        "card_unlocked": _card_unlocked,
        "deck_template": _deck_template,
    }
func restore_save_data(data: Dictionary) -> bool: ...
func reset_to_defaults() -> void: ...
```

- Register with `SavePersistence.register(self, restore_order=22)`.
- `_active_mission_deck` (mission-locked snapshot) is never persisted — only `_deck_template` (the Sanctuary-time editable list) crosses save/load.
- Deck Lock Lifecycle: `EDITABLE` (default, player at SANCTUARY) → `LOCKED` (on `mission_launched`, immutable for mission duration) → `EDITABLE` (mission ends, either outcome, returns to SANCTUARY).
- Per-Card Mastery Progression state table (Tier 0 Novice `m=1.00` through Tier 4 Master `m=1.75`) is fully derived from Story 003's `_lookup_mastery_tier()` — no separate storage.
- Rune Discovery Ledger mirrors Constellation's Discovery Ledger exactly: `UNDISCOVERED` (default) → `DISCOVERED` (terminal, one-way, never reverts).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003/004: the accrual/discovery logic that produces the values this story persists
- Resolving the project-wide SavePersistence mid-session-restore gap itself (tracked as a cross-epic blocker, not owned by this story)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-40**: Deck lock on launch
  - Given: `EDITABLE` state at SANCTUARY
  - When: `mission_launched` fires
  - Then: transitions to `LOCKED`, remains so for the mission's full duration regardless of player input

- **AC-41**: Deck unlock on mission end
  - Given: `LOCKED` state
  - When: the mission ends (either `MISSION_COMPLETE` or `DEFEAT`)
  - Then: returns to `EDITABLE` at SANCTUARY

- **AC-42**: Tier 4 terminal transition
  - Given: a card at Tier 3 (`mastery_missions_played` in `[15,24]`)
  - When: `mastery_missions_played` crosses `25`
  - Then: `mastery_tier_scalar` transitions from `1.50` to `1.75` (Tier 4), remains terminal regardless of additional missions played

- **AC-43**: Fresh-save default state
  - Given: the `UNDISCOVERED` default state at a fresh save/playthrough start
  - When: queried before any mission completes with that card equipped
  - Then: no rune effect applies, `tarot_rune_discovered` has not fired for that `rune_id`

- **AC-44**: Discovery survives reload
  - Given: a rune has entered `DISCOVERED`
  - When: the save is reloaded in a later session
  - Then: the ledger reads `DISCOVERED` for that `rune_id` — permanent and save-persisted (`restore_order=22`), never reverting

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/tarot/state-tables-persistence_test.gd` — 12 tests covering AC-40/41/42/43/44, `RESTORE_ORDER == 22`, a full save/load round-trip across all 4 persisted structures, `_active_mission_deck` exclusion, primitive-only serialization, malformed-payload rejection, and `reset_to_defaults()`. All passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1183/1184 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 001, Story 003, Story 004
- Unlocks: None further within this epic

**Unblocked**: ADR-0027 accepted 2026-07-18 (Sprint 6, S6-03). The project-wide SavePersistence mid-session-restore gap this story was also flagged against is resolved (ADR-0003's 2026-07-18 revision).

**Implemented (2026-07-19, Sprint 7)**: added the full `SaveRestorer` interface to `tarot.gd` — `get_save_key()`/`get_save_data()`/`restore_save_data()`/`reset_to_defaults()` — covering all 4 persisted structures (`_mastery_missions_played`, `_rune_discovered`, `_card_unlocked`, and `_current_deck` saved under the `"deck_template"` key to match the ADR's own naming), registered via `GSavePersistence.register(self, RESTORE_ORDER)` with `RESTORE_ORDER = 22` (`save-persistence.md`'s already-assigned slot). StringName keys/values explicitly converted to String on save (matching `hero.gd`'s own established convention, never relying on `store_var()`'s native StringName serialization). `_active_mission_deck` is deliberately never included in `get_save_data()`'s payload — confirmed via a dedicated test. Live-verified via gdUnit4: 12/12 new tests passing (65/65 across all 7 Tarot test files); full regression 1183/1184 (same pre-existing unrelated `TD-menag-006` failure). **This closes out all 7 Tarot stories in Epic 07** (004/005/006 pending only Story 006's own genuinely-blocked AC-37/38).

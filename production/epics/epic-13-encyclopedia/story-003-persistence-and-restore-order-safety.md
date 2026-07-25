# Story 003: Persistence — `restore_order = 35`, Restored Last, No Restore-Time Re-Emission

> **Epic**: Encyclopedia System
> **Status**: Complete (2026-07-25)
> **Layer**: Advanced Feature
> **Type**: Integration
> **Estimate**: 3h
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/encyclopedia.md`
**Requirement**: `TR-encyclopedia-???` (no TR-ID registered — scoped from GDD's Interactions table and Edge Cases, AC Group 4 + remainder of Group 5)

**ADR Governing Implementation**: N/A — see Story 001's identical note. Uses the established `SaveRestorer` interface pattern (`get_save_key()`/`get_save_data()`/`restore_save_data()`/`reset_to_defaults()`) per `save-persistence.md`'s own ADR-0003.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None beyond the standard `SaveRestorer` registration pattern already used by every other persisted system in this project (Menagerie, Defense Building, Tarot, etc.).

**Control Manifest Rules (this layer)**:
- Required: `restore_order = 35` (last of all currently-registered systems) — Encyclopedia's own data only ever references what every other system already restored, so it must go last

---

## Acceptance Criteria

*From GDD `design/gdd/encyclopedia.md`, AC Group 4 + remainder of Group 5:*

- [x] **AC-12**: GIVEN entries exist across multiple categories, WHEN the game saves and reloads, THEN every entry is present post-load with identical `category`/`entry_id`/`DISCOVERED` state and identical `discovered_at` timestamp. Verified via `test_save_then_restore_round_trips_entries_across_multiple_categories`.
- [x] **AC-13**: GIVEN a fresh save with no prior discoveries, WHEN Encyclopedia initializes, THEN every category (`skill`, `constellation_rune`, `tarot_rune`, `recipe`, `creature`, `tech`) reports 0 entries. Verified via `test_reset_to_defaults_produces_zero_entries_in_every_category`, `test_restore_with_empty_entries_matches_reset_to_defaults`.
- [x] **AC-15a**: GIVEN `restore_save_data()` is called, WHEN it processes the saved ledger, THEN Encyclopedia itself emits none of its 7 inbound discovery-event types as a side effect, and emits `encyclopedia_entry_added` only for entries that are genuinely new relative to the ledger being restored (i.e. never for entries the save data itself already contains). Verified via `test_restore_does_not_reemit_any_inbound_discovery_event`, `test_restore_does_not_emit_encyclopedia_entry_added_for_restored_entries`, `test_repeated_restore_of_the_same_data_never_reemits_encyclopedia_entry_added`.
- [x] **AC-15b**: GIVEN a full save/restore cycle across Encyclopedia and at least 2 of its upstream systems (e.g. Constellation, Tarot), WHEN restoration completes, THEN none of those upstream systems fire a live discovery event as a side effect of their own restore — jointly-owned evidence with those systems' own test suites, not solely Encyclopedia's. Verified via `test_full_save_restore_cycle_does_not_cause_upstream_systems_to_refire_discovery_events`, exercising real `Constellation`/`Tarot` instances (both scene-instanced, not Autoloads — discovered this during implementation, not silently assumed).

---

## Implementation Notes

Standard `SaveRestorer` interface (`get_save_key()`/`get_save_data()`/`restore_save_data()`/`reset_to_defaults()`), registered with `GSavePersistence` at `restore_order = 35` — the highest (last) restore order of any currently-registered system in this project, since Encyclopedia's data references every other system's own discoveries and has nothing to reconstruct that isn't already implied by everything restored before it.

**Not a real race** (Edge Cases): being restored last only means Encyclopedia's own ledger is the last one populated from disk — `restore_save_data()` populates the ledger directly from disk and never itself re-fires any of the 7 inbound discovery events (those only ever originate from live gameplay, none of which can occur before Save & Persistence's own full restore sequence completes and `sanctuary_state_restored` fires).

**Fresh-install default** (Edge Cases): `get_save_data()` returns an empty structure for every category on a fresh save; `restore_save_data({})` and `reset_to_defaults()` produce an identical empty-ledger result — no special-cased "first ever boot" branch needed.

**AC-15a/AC-15b split** (per the GDD's own text): AC-15a is narrowly what Encyclopedia's own code can prove (no self-triggered re-emission during restore). AC-15b is the broader claim about upstream systems not re-firing their own discovery events during their own restore — jointly owned with those systems, test at least 2 real upstream systems' actual restore behavior, not just assert it in isolation.

---

## Out of Scope

- Story 001: the ledger's own insert/duplicate-suppression logic — this story assumes it already works correctly and tests the save/restore round-trip on top of it
- Story 002: the query contract itself — this story uses `get_entries()` as a verification tool for round-trip correctness, doesn't re-test the contract's own generic behavior
- Bestiary/monster codex, completion-percentage tracking — out of this epic's scope entirely (GDD Core Rules 6-7)

---

## QA Test Cases

- **AC-12**
  - Given: entries exist across at least 3 categories with distinct `discovered_at` timestamps
  - When: `get_save_data()` is called, then a fresh Encyclopedia instance calls `restore_save_data()` with that exact data
  - Then: every entry round-trips with identical `category`/`entry_id`/`discovered_at`
  - Edge cases: verify via `get_entries()` (Story 002's query contract), not by reaching into private state

- **AC-13**
  - Given: a fresh Encyclopedia instance, no prior save data
  - When: `reset_to_defaults()` is called (or `restore_save_data({})`)
  - Then: `get_entries()` for every one of the 6 categories returns an empty array
  - Edge cases: confirm `reset_to_defaults()` and `restore_save_data({})` produce an identical empty-ledger result

- **AC-15a**
  - Given: a saved ledger with 2+ pre-existing entries
  - When: `restore_save_data()` processes it
  - Then: none of the 7 inbound discovery-event signals are emitted by Encyclopedia itself as a side effect; `encyclopedia_entry_added` fires 0 times for entries already in the restored data
  - Edge cases: restore a ledger containing an entry, then restore again with the same data — confirm no re-emission on the second restore either

- **AC-15b**
  - Given: a real save/restore cycle involving Encyclopedia + at least 2 upstream systems (e.g. Constellation, Tarot) with pre-existing discoveries
  - When: `GSavePersistence.load_slot()` runs the full restore sequence
  - Then: neither upstream system's own `constellation_rune_discovered`/`tarot_rune_discovered` (or equivalent) fires during restore
  - Edge cases: this test necessarily touches real upstream system state — scope it to reading their own public state/signals, not reimplementing their restore logic

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/encyclopedia/persistence-and-restore-order-safety_test.gd`

**Status**: [x] Created and passing — 10/10 test cases (7 original + 3 code-review regression tests), 0 errors, 0 failures, 0 orphans (`tests/integration/encyclopedia/persistence-and-restore-order-safety_test.gd`, run 2026-07-25). Real scene instantiation exercising the real `GEventBus`/`GSavePersistence` and real `Constellation`/`Tarot` instances — not mocked.

---

## Dependencies

- Depends on: Story 001 (the ledger this story saves/restores), Story 002 (`get_entries()` used to verify round-trip correctness)
- Unlocks: None (final story in this epic)

---

## Completion Notes
**Completed**: 2026-07-25
**Criteria**: 4/4 passing (AC-12, AC-13, AC-15a, AC-15b)
**Deviations**: None
**Test Evidence**: Integration — `tests/integration/encyclopedia/persistence-and-restore-order-safety_test.gd`, 7/7 passing, 0 orphans
**Code Review**: Complete (`godot-gdscript-specialist` spawned 2026-07-25). Found and fixed 2 real WARNING-level gaps: `restore_save_data()` had no `is Array`/`is Dictionary`/per-field type guards before its typed loop — a malformed save (e.g. `entries` as a String, or a non-Dictionary element) would have thrown a runtime type error instead of returning `false` gracefully. Fixed to match Menagerie's own established defense-in-depth pattern exactly (whole-restore rejection on any malformed entry, no partial-restore side effects) — the same bug class this session already found and fixed in Menagerie's own `restore_save_data()`. Added 3 regression tests. Also fixed 1 INFO nit: `get_entries()` now returns typed `Array[Dictionary]`. Epic 13 (Encyclopedia System) is now fully implemented, tested (28 gdUnit4 tests across all 3 stories), and code-reviewed.

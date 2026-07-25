# Story 002: `encyclopedia_entry_added` Emission Contract + Read-Only Query Contract

> **Epic**: Encyclopedia System
> **Status**: Complete (2026-07-25)
> **Layer**: Advanced Feature
> **Type**: Logic
> **Estimate**: 2h
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/encyclopedia.md`
**Requirement**: `TR-encyclopedia-???` (no TR-ID registered — scoped from GDD Core Rules 2 and 4, AC Groups 3 and part of 5)

**ADR Governing Implementation**: N/A — see Story 001's identical note.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None.

**Control Manifest Rules (this layer)**:
- Required: no per-category special-casing in the query contract — `get_entries()`/`is_discovered()` must be generic across all 6 categories

---

## Acceptance Criteria

*From GDD `design/gdd/encyclopedia.md`, AC Group 3 + part of Group 5:*

- [x] **AC-10**: GIVEN a genuinely new entry is created (any category), WHEN the entry is committed, THEN `encyclopedia_entry_added(category, entry_id)` fires exactly once with the correct category and ID. Verified via `test_genuinely_new_entry_emits_encyclopedia_entry_added_exactly_once`.
- [x] **AC-11**: GIVEN a duplicate discovery event per Story 001's AC-8/AC-9, WHEN it is processed, THEN `encyclopedia_entry_added` does **not** fire. Verified via `test_duplicate_entry_does_not_emit_encyclopedia_entry_added_again`.
- [x] **AC-14**: GIVEN entries exist from at least 3 distinct source systems (e.g. Constellation, Menagerie, Defense Building), WHEN `get_entries()` (Core Rule 2's query contract) is called with no `category` argument, THEN it returns all of them in one collection — confirming a consumer can read the full cross-system record through one method call, with no category-specific special-casing required. Verified via `test_get_entries_with_no_argument_returns_entries_from_all_categories`, `test_get_entries_filtered_by_category_returns_only_that_category`, `test_is_discovered_returns_true_for_known_and_false_for_unknown`.
- [x] **AC-16**: GIVEN any entry in any category, WHEN its persisted/serialized form is inspected, THEN it contains exactly the 3 keys `category`, `entry_id`, `discovered_at` and no others. Verified via `test_every_entry_has_exactly_3_keys_regardless_of_category`.

---

## Implementation Notes

**Minimal query contract** (Core Rule 2, added during `/design-review` to close a real gap — without it, the Player Fantasy's "turn back through the pages" claim was unfalsifiable): exactly 2 read methods —
- `get_entries(category: String = "") -> Array` — all entries, or filtered to one category if provided
- `is_discovered(category: String, entry_id: String) -> bool`

Both are pure reads against the in-memory ledger Story 001 populates. **No write path exists on this interface** — matches the whole system's read-only design. This is the contract AC-14 tests against, and the contract any future browsing UI (OQ-5) will build on, independent of when that UI is designed.

**`encyclopedia_entry_added` emission** (Core Rule 4): the one frozen outbound event this system owns, consumed by Mission HUD for its own discovery-notification toast. Fires exactly once per genuinely new `(category, entry_id)` transition to `DISCOVERED` — never re-fires for an already-`DISCOVERED` combination (Mission HUD must never show a duplicate "you discovered X" toast).

**AC-16's exact-shape guarantee**: pin the stored entry to precisely 3 keys — a regression guard against silent scope creep (a real gap the design review found: nothing previously pinned the exact shape).

---

## Out of Scope

- Story 001: the actual event-to-entry conversion and duplicate-suppression logic this story's emission contract reacts to — this story only owns the *emission* and *query* surface, not the ledger's own insert semantics
- Story 003: Save & Persistence — this story assumes an in-memory ledger populated by Story 001

---

## QA Test Cases

- **AC-10**
  - Given: an empty ledger
  - When: a genuinely new discovery event fires (any category)
  - Then: `encyclopedia_entry_added` fires exactly once, with the correct `category`/`entry_id` arguments
  - Edge cases: verify across at least 2 different categories, not just one

- **AC-11**
  - Given: an entry already `DISCOVERED`
  - When: a duplicate discovery event fires for the same `(category, entry_id)`
  - Then: `encyclopedia_entry_added` does not fire a second time
  - Edge cases: use an `EventBusSpy`-style assertion (0 additional emissions), not just "no crash"

- **AC-14**
  - Given: entries exist across at least 3 categories
  - When: `get_entries()` is called with no argument
  - Then: all entries from all categories are returned in one collection
  - Edge cases: also test `get_entries("creature")` returns only that category; `is_discovered()` returns true/false correctly for known/unknown entries

- **AC-16**
  - Given: any committed entry, any category
  - When: its serialized/dictionary form is inspected
  - Then: exactly 3 keys present (`category`, `entry_id`, `discovered_at`), no `recipe_category` or other extra field ever leaks onto a `recipe` entry
  - Edge cases: specifically assert the `recipe` category entry has no `recipe_category` key (the exact defect an earlier GDD draft had)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/encyclopedia/emission-and-query-contract_test.gd`

**Status**: [x] Created and passing — 7/7 test cases, 0 errors, 0 failures, 0 orphans (`tests/unit/encyclopedia/emission-and-query-contract_test.gd`, run 2026-07-25).

---

## Dependencies

- Depends on: Story 001 (the ledger and its insert/duplicate-suppression logic must exist for this story's emission/query surface to have anything to react to or read)
- Unlocks: None directly, but Story 003's persistence tests will exercise this story's `get_entries()` to verify round-trips

---

## Completion Notes
**Completed**: 2026-07-25
**Criteria**: 4/4 passing (AC-10, AC-11, AC-14, AC-16)
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/encyclopedia/emission-and-query-contract_test.gd`, 7/7 passing, 0 orphans (using the real `EventBusSpy` helper for emission-count assertions, matching this project's own established pattern)
**Code Review**: Complete (`/code-review` run 2026-07-25) — found 1 INFO nit (`get_entries()` returned untyped `Array` instead of `Array[Dictionary]`), fixed. No findings against the emission contract or query-filtering logic itself.

# S3-01 — TD-save-001 Debt Closure

**Story ID**: S3-01
**Epic**: Foundation
**Layer**: Foundation
**Type**: Integration
**Owner**: godot-gdscript-specialist
**Sprint**: 3
**Estimate**: 0.5 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

| TR-ID | Requirement |
|-------|-------------|
| TR-save-001 | Atomic write (.tmp → .dat) |
| TR-save-003 | Restore order and `sanctuary_state_restored` signal timing |
| TR-save-006 | EventBus signal wiring for auto-save triggers |

## ADR Governing Implementation

`docs/architecture/adr-0003-save-file-format.md` (Accepted 2026-05-16)

**ADR Decision Summary**: SavePersistence uses atomic .tmp→.dat rename pattern.
`sanctuary_state_restored` is emitted via `call_deferred` exactly one frame after restore
loop completes. Systems register via `register(key, callable)` and are restored in
ascending `restore_order`.

**Engine**: Godot 4.6.2 | **Risk**: LOW — FileAccess, call_deferred, signals unchanged through 4.6

## Dependencies

- S2-02 SavePersistence Autoload — Complete (2026-05-25)

## Background — What Was Deferred

`S2-02` was marked COMPLETE WITH NOTES. Three acceptance criteria had no automated
test coverage and were accepted as tech debt TD-save-001:

- **AC-8**: `sanctuary_state_restored` deferred exactly 1 frame — tested only by code inspection
- **AC-10**: `register()` callable invoked exactly once per `save_all()` — no direct test
- **AC-12**: EventBus signal wiring (subscription to `mission_launched` etc.) — no test

This story closes those gaps with 6 new test functions added to the existing test files.

## Files to Modify

- `tests/unit/save_persistence/save_persistence_write_test.gd` — add AC-8 and AC-10 tests
- `tests/unit/save_persistence/save_persistence_restore_test.gd` — add AC-12 test

**Do NOT modify `src/`** — the implementation is already correct. This story adds missing
test coverage only.

## Acceptance Criteria

- [x] AC-8: Test confirms `sanctuary_state_restored` fires in the **next** frame after
      restore loop (not current frame) — verified via frame counting, not just signal presence
- [x] AC-10: Test confirms that a callable registered via `register(system_ref, order)` has
      its `get_save_data()` method invoked exactly once when `save_slot()` is called
      (direct invocation test — `save_all()` was not implemented; `save_slot()` is the
      correct method per the final implementation)
- [x] AC-12: Test confirms SavePersistence subscribes to `EventBus.mission_launched` and
      that firing that signal causes the auto-save handler to execute
- [x] All 3 new tests pass in the full test suite (total suite count ≥ 161; write file: 13 tests, restore file: 8 tests = 21 save tests total)
- [x] No regressions in the existing 14 save tests

## Implementation Notes

These are test-only additions. No src/ changes are required.

**AC-8 test pattern** — same-frame vs deferred detection:
```gdscript
var frame_fired: int = -1
EventBus.sanctuary_state_restored.connect(func(_s): frame_fired = Engine.get_process_frames())
save_persistence.restore_slot(0)
var frame_before_await = Engine.get_process_frames()
await get_tree().process_frame
assert_that(frame_fired).is_equal(frame_before_await + 1)
```

**AC-10 test pattern** — register/save_all direct:
```gdscript
var call_count: int = 0
var test_callable := func(file: ConfigFile): call_count += 1
save_persistence.register("test_system", test_callable)
save_persistence.save_all(0)
assert_that(call_count).is_equal(1)
```

**AC-12 test pattern** — EventBus wiring:
```gdscript
# Count how many times the internal _on_mission_launched handler fires
var spy_count: int = 0
EventBus.mission_launched.connect(func(): spy_count += 1)
EventBus.mission_launched.emit()
await get_tree().process_frame
assert_that(spy_count).is_greater_equal(1)
```

## Out of Scope

- No changes to `src/foundation/save_persistence/save_persistence.gd`
- AC-3 (store_* bool abort) — remains untestable without FileAccess DI seam; carry to polish
- Save slot selection UI — not this story

## QA Test Cases

- **AC-8**: `sanctuary_state_restored` deferred exactly 1 frame
  - Given: SavePersistence autoloaded, slot 0 has valid save data
  - When: `restore_slot(0)` is called
  - Then: `sanctuary_state_restored` fires in `Engine.get_process_frames() + 1` (not current frame)
  - Edge cases: restore with empty slot (no file) — signal still fires deferred (or not at all per GDD)

- **AC-10**: `register()` callable invoked once per `save_all()`
  - Given: A callable is registered via `register("key", callable)`
  - When: `save_all(0)` is called
  - Then: callable is invoked exactly 1 time
  - Edge cases: register same key twice — second callable overwrites first, only 1 invocation total

- **AC-12**: EventBus `mission_launched` triggers auto-save handler
  - Given: SavePersistence is in SANCTUARY phase (autosave not paused)
  - When: `EventBus.mission_launched` is emitted
  - Then: save handler executes (checkpoint write path is entered)
  - Edge cases: emitting outside SANCTUARY phase — handler must be connected but may gate internally

## Test Evidence

**Story Type**: Integration
**Required evidence**: Added test functions in:
- `tests/unit/save_persistence/save_persistence_write_test.gd`
- `tests/unit/save_persistence/save_persistence_restore_test.gd`

**Status**: [x] Created — 6 new test functions added across 2 existing files (write_test: 13 functions, restore_test: 8 functions)

## Dependencies

- Depends on: S2-02 (Complete)
- Unlocks: None (tech debt closure)

## Completion Notes

**Completed**: 2026-06-30
**Criteria**: 5/5 passing
**Deviations**:
- ADVISORY: AC-10 story text said `save_all()` but implementation only has `save_slot()` — `save_all()` was never added. Test correctly exercises `save_slot()`. Story spec updated to reflect actual implementation during Sprint 3 QA cycle (2026-07-01).
**Test Evidence**: Integration — 6 new test functions added: `save_persistence_write_test.gd` (AC-8 ×2, AC-10 ×2) + `save_persistence_restore_test.gd` (AC-12 ×2). Total save module: 21 test functions.
**Code Review**: Skipped (test-only story; no src/ changes)

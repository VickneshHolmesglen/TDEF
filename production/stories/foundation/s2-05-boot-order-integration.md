# S2-05: Foundation Boot-Order Integration Test

**ID**: S2-05
**Layer**: Foundation
**Type**: Integration
**TR-ID**: TR-gc-002
**ADR Governing Implementation**: docs/architecture/adr-0002-scene-autoload-structure.md
**Manifest Version**: 2026-05-16
**Estimate**: 0.5 days
**Status**: Complete

**Story**: As a developer, I need verified proof that all 4 Foundation Autoloads boot in
declared order (ADR-0002) without null-reference errors, so Sprint 3 Core-layer stories
can safely depend on the Foundation being stable.

## Dependencies
- S2-01 (EventBus autoload): Complete
- S2-02 (SavePersistence autoload): Complete
- S2-03 (Grid System autoload): Complete
- S2-04 (Pathfinding autoload): Complete

## Acceptance Criteria

- [ ] AC-1: EventBus global singleton is accessible and correct type at test runtime
- [ ] AC-2: SavePersistence global singleton is accessible and correct type (proves EventBus existed at SavePersistence boot)
- [ ] AC-3: Grid global singleton is accessible and correct type
- [ ] AC-4: PathfindingSystem global singleton is accessible and correct type (proves Grid existed at PathfindingSystem boot)
- [ ] AC-5: PathfindingSystem builds templates when Grid.initialize() is called before SCOUT
- [ ] AC-6: EventBus.mission_phase_changed.emit() reaches PathfindingSystem exactly once (no dropped signals)
- [ ] AC-7: ≥6 integration tests in `tests/integration/foundation/`

## Implementation Notes

This story produces only a test file — no new source code.

**Global singleton tests** (AC-1–AC-4): Use `get_node_or_null("/root/[Name]")` to verify each
autoload is present and the correct class. The fact that SavePersistence and PathfindingSystem
exist without errors proves EventBus and Grid booted before them respectively.

**Functional integration tests** (AC-5–AC-6): Create local EventBus + Grid + PathfindingSystem
instances using the `_inject()` seam (same pattern as S2-04 unit tests) to avoid mutating
global singleton state between tests.

## Out of Scope
- New source code changes to any Autoload script
- SceneManager, WaveManager, GameDataRegistry (not yet implemented)
- Testing the project.godot Autoload registration order directly (verified via MCP tool)

## Test Evidence
**Required**: `tests/integration/foundation/foundation_boot_order_test.gd`
**Minimum**: 6 tests

## Completion Notes
**Completed**: 2026-06-30
**Criteria**: 7/7 passing
**Deviations**: None
**Test Evidence**: Integration test at `tests/integration/foundation/foundation_boot_order_test.gd` (7 tests)
**Code Review**: Skipped — Lean mode

## QA Test Cases
1. `/root/EventBus` exists and is class EventBus
2. `/root/SavePersistence` exists and is class SavePersistence
3. `/root/Grid` exists and is class Grid
4. `/root/PathfindingSystem` exists and is class PathfindingSystem
5. templates_ready fires after Grid.initialize() + SCOUT emit
6. templates_ready fires exactly once via EventBus signal chain
7. get_path(spawn_cell) returns non-empty path ending at GOAL after full boot sequence

# Tech Debt Register

Tracks known technical debt, test coverage gaps, and deferred architectural work.
Items are resolved by creating a follow-up story and linking it here.

---

## TD-save-001 — SavePersistence integration test coverage gaps

**Logged**: 2026-05-25
**Story**: S2-02 Save & Persistence Autoload Implementation
**Severity**: Advisory
**Area**: `src/foundation/save_persistence/save_persistence.gd`

### Gaps

| Gap | AC | Why untested |
|-----|----|--------------|
| `store_32()`/`store_var()` abort path | AC-3 | No FileAccess DI seam — cannot force `store_*` to return false in unit tests |
| `sanctuary_state_restored` deferred exactly 1 frame | AC-8 | Requires `await get_tree().process_frame` in a running SceneTree — integration test needed |
| EventBus signal wiring (`mission_launched`, `mission_phase_changed`) | AC-12 | `_ready()` not called in unit tests; wiring untested at any level |
| `register()` public API | AC-10 | All restore tests bypass `register()` by directly appending to `_registered_systems` |

### Recommended fix

Create `tests/integration/save_persistence/save_persistence_integration_test.gd` covering:
1. `register()` API round-trip (register → load → verify data routed correctly)
2. EventBus signal wiring (`emit mission_launched` → verify checkpoint written)
3. Deferred emit: `await process_frame` after `_restore_all_systems`, verify `sanctuary_state_restored` fires

This work is a prerequisite for S2-05 (Foundation boot-order integration test) being fully representative.

### Resolution
- [ ] Integration test story created
- [ ] Tests passing
- [ ] This entry closed

# Story 005: Deferred Routing Notification Banner (PC-3)

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-003` — "On tower_destroyed during WAVE_ACTIVE, display path-update-queued-for-next-intermission messaging"

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture)
**ADR Decision Summary**: Pure EventBus consumer, outer-root-owned (must survive the Planning Cluster's own destruction at WAVE_ACTIVE, since this banner is specifically a WAVE_ACTIVE-only element).

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None.

**Control Manifest Rules (this layer)**:
- Required: N/A.
- Forbidden: At most one banner instance at a time — never stack a second.
- Guardrail: Purely informational — gates no player action.

---

## Acceptance Criteria

*From GDD Core Rules Group 5 (Rules 13-15) + Confirmed Signal Contract PC-3, plus the `hero_class_unlocked` notification (Interactions table, reuses this same pattern):*

- [x] AC-23 — on `tower_destroyed` received while `phase == WAVE_ACTIVE`: display a non-modal banner, "Path update queued for next intermission," top-center, auto-dismiss after 3 seconds
- [x] AC-24 — at most one such banner exists at a time — a second `tower_destroyed` while one is already showing re-triggers/resets the 3-second timer rather than stacking a second banner
- [x] AC-25 — force-dismissed on `mission_phase_changed → INTERMISSION` if still visible at that point
- [x] AC-26 — `hero_class_unlocked(class_id)` triggers a notification reusing this same transient-banner mechanism (distinct message content, same lifecycle: non-modal, auto-dismiss, no stacking)
- [x] AC-27 (edge case) — if `tower_destroyed` and the `wave_completed`-driven INTERMISSION transition fire in the same frame with `tower_destroyed` processed after the phase flip: the banner does not show — accepted as a deliberate non-issue, not a bug to work around

---

## Implementation Notes

*Derived from ADR-0031/GDD Implementation Guidelines:*

- Lives on the outer `MissionHud` root (Story 001's scaffold) — `tower_destroyed` subscription already exists there or is added here; must NOT live inside the Planning Cluster, since PC-3 is specifically triggered during WAVE_ACTIVE, when the Planning Cluster does not exist (Story 002).
- Build a single reusable `_show_transient_banner(text: String, duration: float)` function — both PC-3 (AC-23) and `hero_class_unlocked` (AC-26) call it with different text, same underlying timer/re-trigger/dismiss mechanism (AC-24's "reset the timer" behavior applies identically to both).
- The `phase == WAVE_ACTIVE` gate (AC-23) reads local phase-tracking state already established by Story 001's `mission_phase_changed` handler — no new phase subscription needed.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: any other Combat Cluster notification/toast content (Inventory `item_added`/`item_pickup_rejected` toasts) — those reuse a DIFFERENT toast mechanism per the GDD's own Interactions table wording, not necessarily this exact banner

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-23/AC-24**: Banner display and no-stacking
  - Given: `phase == WAVE_ACTIVE`, no banner currently showing
  - When: `tower_destroyed` fires
  - Then: banner appears with the correct text, top-center, dismisses after 3s
  - Edge cases: a second `tower_destroyed` while the banner is still showing resets the 3s timer — never a second concurrent banner instance

- **AC-25**: Force-dismiss on INTERMISSION
  - Given: the banner is showing
  - When: `mission_phase_changed → INTERMISSION` fires before the 3s timer elapses
  - Then: banner is immediately dismissed

- **AC-26**: hero_class_unlocked reuses the mechanism
  - Given: no banner showing
  - When: `hero_class_unlocked("berserker")` fires
  - Then: a banner appears via the same `_show_transient_banner()` path, with class-unlock-specific text

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/deferred-routing-notification-evidence.md` OR an interaction test at `tests/integration/mission-hud/deferred-routing-notification_test.gd`

**Status**: [x] Created — `tests/integration/mission-hud/deferred-routing-notification_test.gd` (7 tests, passing)

---

## Dependencies

- Depends on: Story 001 (HUD Scaffold & Local State Model)
- Unlocks: None further within this epic

---

## Completion Notes
**Completed**: 2026-07-20
**Criteria**: 5/5 passing (7 integration tests, all passing; live-MCP-verified end-to-end against the real running `the_gap.tscn` — banner shown on `tower_destroyed` during WAVE_ACTIVE, force-dismissed on INTERMISSION entry, zero errors).
**Deviations**:
- New `_current_phase: String` field added to `MissionHud` — Story 001's Rule 4 fields don't track current phase directly (each handler branches on the `new_phase` argument it receives per-call), but AC-23's gate needs to know the phase at the moment `tower_destroyed` fires, independent of any transition. Set at the top of `_on_mission_phase_changed()`.
- `hero_class_unlocked`'s real signature is `(archetype: StringName, is_deep: bool)`, not the GDD's loose `(class_id)` — matches this project's established "GDD prose vs. shipped API" precedent.
- `Timer.start()`'s own restart-from-full-duration behavior implements AC-24's "reset the timer" requirement with zero extra bookkeeping — no manual timer-state tracking needed.
**Test Evidence**: UI/Integration — `tests/integration/mission-hud/deferred-routing-notification_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Mission HUD checkpoint.

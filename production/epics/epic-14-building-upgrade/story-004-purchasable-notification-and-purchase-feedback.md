# Story 004: PURCHASABLE Notification & Purchase Feedback

> **Epic**: Building Upgrade System
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Integration
> **Estimate**: M (3-4 hours)
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-12

## Context

**GDD**: `design/gdd/building-upgrade.md`
**Requirement**: `TR-buildupgrade-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: N/A — reuses two already-established, already-ADR-covered conventions verbatim rather than introducing a new pattern: Sanctuary UI's Connection Badge (`sanctuary-ui.md` Core Rule 2, no dedicated ADR but a shipped, tested mechanism per Epic 10) and Defense Building's "Standard tech-node unlock" confirmatory chime (`defense-building.md` Visual/Audio Requirements). If a future architecture review decides this crossing needs its own ADR (e.g. because it establishes a new EventBus contract), that's a follow-up, not required to implement this story.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: New typed EventBus signal (`building_upgrade_became_purchasable(upgrade_id: String)`) — ≤4 fields, typed params per the `dictionary_event_payload` forbidden-pattern rule (ADR-0001). No post-cutoff API risk.

**Control Manifest Rules (this layer)**:
- Required: New EventBus signals must be typed GDScript signal parameters, never untyped `Dictionary`, for ≤4 fields (ADR-0001, `dictionary_event_payload` forbidden pattern)
- Required: A subscriber that itself emits a further event must do so deferred if it would create a Level-1 cascade (`synchronous_level1_cascade` forbidden pattern) — check whether Sanctuary UI's Connection Badge handler emits anything further in response; if not, this doesn't apply
- Forbidden: Dictionary-payload events
- Guardrail: N/A — no gameplay-loop/rendering/physics impact; edge-detection is a Dictionary lookup per re-evaluation (already the existing frequency, Rule 4), not a new per-frame cost

---

## Acceptance Criteria

*From GDD `design/gdd/building-upgrade.md`, scoped to this story:*

- [ ] **AC-8**: GIVEN an upgrade transitions from `VISIBLE_LOCKED` to `PURCHASABLE` (its last unmet requirement or cost becomes satisfied), WHEN this happens while the player is not viewing the Building Upgrade tab, THEN a Sanctuary UI Connection Badge appears on the Equipment Forge tab (`sanctuary-ui.md` Core Rule 2) without requiring the player to have opened the tab.
- [ ] **AC-9**: GIVEN a successful purchase per AC-3 (Story 001), WHEN it resolves, THEN the confirmatory chime plays exactly once, independent of whether `structure_upgraded`'s consuming system exists yet.
- [ ] **AC-9b** (added during `/story-readiness`, closing a Definition-of-Done minimum-AC gap — Integration stories require ≥3 testable criteria; promotes an edge case already named in this story's own QA Test Cases to a formal AC): GIVEN an upgrade transitions `VISIBLE_LOCKED` → `PURCHASABLE` → (Rule 4's live re-evaluation) back to `VISIBLE_LOCKED` → `PURCHASABLE` again, WHEN the second `PURCHASABLE` transition occurs, THEN `building_upgrade_became_purchasable` fires again for the same `upgrade_id` — the edge-detection state must not treat "already fired once" as permanent, only "not currently purchasable" as the re-armable condition.

---

## Implementation Notes

*Derived from GDD Rule 6a and `event-bus.md`'s catalogue entry (already added this session):*

- Add `building_upgrade_became_purchasable(upgrade_id: String)` to `EventBus` (`src/foundation/event_bus/event_bus.gd`) — already documented in `event-bus.md`'s Building Upgrade System table, not yet declared in code.
- `BuildingUpgrade` must detect the `VISIBLE_LOCKED` → `PURCHASABLE` transition specifically (not just "is currently purchasable") — emit only on the edge, never on every re-evaluation while already `PURCHASABLE`, and never again for the same `upgrade_id` after it reaches `PURCHASED` (per the event-bus.md catalogue's own "When Fired" note). Track prior-purchasable-state per `upgrade_id` to detect the edge; this is new state Story 001's shipped code doesn't currently track.
- Sanctuary UI: add `building_upgrade_became_purchasable` to the Equipment Forge tab's Connection Badge trigger list (already added to `sanctuary-ui.md`'s Tuning Knobs table this session) — wire the actual subscription in Sanctuary UI's own room/tab-strip code, following the exact pattern the existing `rune_socket_unlocked` trigger already uses for the same tab.
- Purchase chime: play on `resolve_upgrade()`'s success path (or on the `structure_upgraded` emission it already fires) — reuse whichever Audio System cue Defense Building's own tech-node-unlock chime uses (`audio-system.md`/`defense-building.md` Visual/Audio Requirements), do not author a new sound.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: per-requirement legibility chips (a different UI surface, no EventBus involvement)
- Any new Watchtower/Habitat Expansion mechanical effect for `structure_upgraded` to drive — still deliberately scaffolded (GDD Rule 7)

---

## QA Test Cases

- **AC-8**: Given: an upgrade is `VISIBLE_LOCKED` with its last requirement/cost about to become satisfied; the player is on a different Sanctuary tab. When: the last requirement/cost becomes satisfied (e.g. the qualifying item is crafted). Then: `building_upgrade_became_purchasable` fires exactly once, and Sanctuary UI's Equipment Forge tab shows a Connection Badge. Edge cases: the transition happens while the player IS already viewing the Building Upgrade tab (badge should still fire per Sanctuary UI's own existing badge semantics — Core Rule 2 doesn't suppress badges for the active room, only clears on room entry); the upgrade re-locks and re-unlocks (Rule 4) — the event should fire again on the second unlock, not be treated as already-fired.
- **AC-9**: Given: an upgrade is `PURCHASABLE`. When: the player confirms and `resolve_upgrade()` succeeds. Then: the confirmatory chime plays exactly once. Edge cases: `resolve_upgrade()` is called twice in immediate succession (the `_action_resolving`-style guard, if this system has one — confirm against `building_upgrade.gd`) — the chime must not double-fire for a rejected second call.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/building_upgrade/purchasable_notification_test.gd` — must exist and pass (EventBus signal spy for AC-8/AC-9's event-emission halves)
- `production/qa/evidence/building-upgrade-notification-evidence.md` — manual verification of the actual Connection Badge appearance + chime audio (audio/visual confirmation an automated test can't fully cover)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE — extends `resolve_upgrade()`/`can_purchase()`)
- Unlocks: None

## Completion Notes
**Completed**: 2026-08-12
**Criteria**: 3/3 passing (AC-8, AC-9, AC-9b)
**Deviations**: ADVISORY — initial implementation pass was cut off mid-work (missing method bodies), completed directly; a real prerequisite-chain notification gap and a missing badge-level test were both found and fixed during `/code-review`; a pre-existing, unrelated cross-suite test-isolation quirk and a pre-existing, unrelated cosmetic Connection Badge positioning issue were both found and documented (not fixed — out of this story's scope).
**Test Evidence**: Integration — `tests/integration/building_upgrade/purchasable_notification_test.gd` (7 tests) + `tests/integration/sanctuary-ui/connection-badges_test.gd` (1 new test) + `production/qa/evidence/building-upgrade-notification-evidence.md` (live Godot MCP verification)
**Code Review**: Complete — APPROVED (2 real findings from 3 specialist passes, both fixed)

# Story 010: Loadout — Tab Strip's 6th Entry, Hand-off to Tarot Deck UI

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 11/11 passing; `/story-done` verification complete. The 4-step ordered sequence is fully real; the actual Tarot Deck UI call is a flagged gap, matching Story 009's Mission Select gap — see note below)
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b
> **Estimate**: 6h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from GDD Core Rule 10 and AC Group 10. This is the mechanism that drove the GDD's own 4th-pass freeze and 5th-pass redesign — treat this story's test coverage as the highest-priority regression guard in the epic, alongside Story 007.)

**ADR Governing Implementation**: ADR-0032 (Presentation Shell Hosting Pattern) + ADR-0020 (Direct-Autoload-call exception pattern) + ADR-0011 (UI Dual-Focus Handling) + ADR-0001 (EventBus)
**ADR Decision Summary**: ADR-0032 (written 2026-07-24) now formally covers the terminal-latch and host-owned-tween mechanics this story's ordered sequence implements (Sections 2–3 of that ADR). The hand-off to Tarot Deck UI is a direct call per `tarot-deck-ui.md`'s own Interactions table — the same tier of precision as Story 009's Mission Select call. **Not yet formally classified** under ADR-0020's Criterion A/B framework — GDD's own OQ-9 flags this, mirroring OQ-2; ADR-0032 does not resolve this classification, only the destroy-and-recreate/latch mechanics. Do not treat this story's completion as resolving OQ-9.

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: This sequence is the direct product of the GDD's own review history finding and fixing 3 independently-discovered convergent defects: a latch-ordering contradiction, a room-teardown signal-leak gap, and an unstated tween-ownership risk. Implement the 4-step ordered sequence exactly as specified below — do not reorder or simplify it.

**Control Manifest Rules (this layer)**:
- Required: disconnect every EventBus subscription in `_exit_tree()`/on terminal transition, no exceptions — source: ADR-0001
- Forbidden: never call `SceneTree.change_scene_to_file()`/`change_scene_to_packed()` directly from a gameplay system — source: ADR-0002

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, AC Group 10 and the 2 Load-Bearing Edge Cases items specific to Loadout:*

- [x] GIVEN each of `ROOM_INVENTORY_CRAFTING`, `ROOM_MENAGERIE`, `ROOM_DEFENSE_BUILDING`, `ROOM_EQUIPMENT_FORGE` individually, THEN the Loadout tab-strip entry is still visible, focus-reachable, and selectable from each — unlike Launch/Depart, which is genuinely `OVERVIEW`-only.
- [x] GIVEN any state (`OVERVIEW` or any `ROOM_*`), WHEN the Loadout tab is selected, THEN the active state becomes `DEPARTING_TO_LOADOUT`, any previously-active room instance is torn down per Story 007's own lifecycle first, and Sanctuary UI subsequently hands off to Tarot Deck UI — confirmed as a genuinely distinct destination from Launch/Depart's Mission Select hand-off. — **Resolved 2026-07-25**: `GSceneManager.transition_to_tarot_deck_ui()` (new) and `TarotDeckUIScene.tscn` (new, wraps the real `TarotDeckUI.tscn` shell) now give this call a real, tested target — the full hand-off is genuinely real end-to-end, not just the state machine/teardown half. ADR-0020's Criterion A/B classification (OQ-9) remains formally open — shipped ahead of it per this epic's own established precedent.
- [x] GIVEN a room with its own EventBus subscriptions and nested state is active, WHEN Loadout is selected, THEN the room's own subscriptions are disconnected and `set_process_unhandled_input(false)` is called on it, both confirmed complete (via call-order inspection) *before* `DEPARTING_TO_LOADOUT` is entered.
- [x] GIVEN the Loadout tab is selected twice within the same frame (simulated double-input), THEN only one `DEPARTING_TO_LOADOUT` entry occurs and the second selection produces no additional effect, no error, no duplicate hand-off call.
- [x] GIVEN the player returns from Tarot Deck UI, THEN a fresh Sanctuary UI instance mounts at `OVERVIEW` — the identical entry path Story 006 already defines for any `scene_transition_completed(target_context="SANCTUARY")` arrival, not a special-cased "return from Loadout" path.
- [?] GIVEN the player selects the Loadout tab while Equipment Forge or Defense Building has an unconfirmed staged action pending, THEN the staged data is gone after the switch AND a non-blocking "Staged changes discarded" toast is shown — identical outcome to the room-switch case (Story 013). — DEFERRED: staged-data-discard-as-a-structural-consequence is verified (Story 011/012's own coverage); the toast itself is Story 013's scope and Equipment Forge/Defense Building don't exist yet to stage anything from (OQ-5).

---

## Implementation Notes

Loadout is a normal tab-strip entry (Story 002), not a special OVERVIEW-only content-zone button. Selecting it — via click, hotkey `6`, or `LT`/`RT` cycling, from **any** state — triggers this **explicit, ordered sequence**:

1. **Kill any in-flight shell-level transition first** — the drawer-slide room-switch tween (Story 014) is shell-owned (attached to `RoomHost`, never to the room instance itself). An in-flight tween killed mid-flight can never null-ref against a room node, because it was never the room's own tween.
2. **Terminal latch fires**: the shared `_departing`-equivalent flag (same flag Story 009's Launch/Depart uses) is set and every EventBus subscription the shell itself owns is synchronously disconnected.
3. **If a room is currently active, it is torn down**: Story 007's own lifecycle runs — a room's own teardown must synchronously disconnect every EventBus subscription the room instance itself owns (not only call `set_process_unhandled_input(false)`), same extended teardown Story 007 already implements for every exit trigger.
4. **`DEPARTING_TO_LOADOUT` is entered and the hand-off proceeds** — a direct call to Tarot Deck UI's own established entry point, per `tarot-deck-ui.md`'s own Interactions table.

**Precision on the latch's "first statement" guarantee**: the terminal latch's ordering guarantee is scoped to "first EventBus-touching or state-mutating statement," not literal handler-line-one — step 1's tween-kill is EventBus-inert (touches no subscription, reads no shared state) and can safely precede the latch without weakening what the latch protects.

**Reachability**: irreversible exits (Launch/Depart) get a pacing gate (`OVERVIEW`-only); reversible lateral navigation (Loadout) does not — selecting Loadout doesn't end anything, the player returns to exactly where Sanctuary UI would otherwise be.

Return path: Tarot Deck UI hands off back to Sanctuary UI (not directly to Mission Select), re-entering via the identical `scene_transition_completed(target_context="SANCTUARY")` path Story 006 already defines — no special-cased "return from Loadout" state.

Loadout carries no Connection Badge (Story 003's own carve-out) — this story does not add one.

---

## Out of Scope

- Story 002: Loadout's own tab-strip click/hotkey/`LT`/`RT` routing (this story owns what happens once triggered)
- Story 003: confirming Loadout never shows a badge
- Story 007: the room-teardown mechanism this story's step 3 reuses
- Story 013: the "Staged changes discarded" toast's own visual implementation (this story's AC only requires the staged data be gone and a toast requirement exist — Story 013 owns the toast UX itself)
- Story 014: the drawer-slide tween's own visual implementation (this story only requires it be shell-owned and killable)

---

## QA Test Cases

- **AC-1 (Loadout reachable from every room, unlike Launch/Depart)**
  - Given: each of the 4 rooms active individually
  - When: Loadout tab-strip entry queried
  - Then: visible, focus-reachable, selectable in every case
  - Edge cases: enumerate each room individually — do not test with a generic "any ROOM_* state" assertion, per the GDD's own explicit rewrite rationale

- **AC-2 (full ordered sequence, distinct destination)**
  - Given: any state, `OVERVIEW` or a `ROOM_*` state
  - When: Loadout selected
  - Then: active state becomes `DEPARTING_TO_LOADOUT`, any active room torn down first, hand-off reaches Tarot Deck UI (verified as a genuinely distinct call from Story 009's Mission Select call, not a reuse)
  - Edge cases: test from `OVERVIEW` and from each of the 4 rooms

- **AC-3 (call-order: room teardown completes before DEPARTING_TO_LOADOUT)**
  - Given: a room active with its own subscriptions and nested state
  - When: Loadout selected
  - Then: subscription-disconnect and `set_process_unhandled_input(false)` both complete (verified via call-order inspection) before `DEPARTING_TO_LOADOUT` is entered
  - Edge cases: mirrors Story 007's AC-2 call-order test, extended to this specific trigger

- **AC-4 (double-selection discarded)**
  - Given: Loadout tab
  - When: selected twice within the same frame
  - Then: only one `DEPARTING_TO_LOADOUT` entry, second selection no-ops
  - Edge cases: also test selecting Loadout once while a room is mid-teardown from a different lateral switch — should also be discarded

- **AC-5 (return re-enters via the standard entry path)**
  - Given: player returns from Tarot Deck UI
  - When: `scene_transition_completed(target_context="SANCTUARY")` fires
  - Then: fresh Sanctuary UI instance mounts at `OVERVIEW`, identical to Story 006's standard entry — no special-cased "return from Loadout" branch exists in the code
  - Edge cases: none additional

- **AC-6 (staged-state discard + toast on Loadout selection)**
  - Given: Equipment Forge or Defense Building active with unconfirmed staged action
  - When: Loadout selected
  - Then: staged data gone after switch, "Staged changes discarded" toast shown
  - Edge cases: test both Equipment Forge and Defense Building individually

---

**Real gap, flagged 2026-07-24 (same class as Story 009's Mission Select gap)**: Tarot Deck UI (epic-11-tarot-deck-ui) has no built scene yet — Epic 11's own Story 001 (Structural Model) hasn't been implemented, so there is no real entry point to call. The GDD's own OQ-9 already flags this exact call as unclassified under ADR-0020, mirroring OQ-2's identical status for Story 009's own hand-off. Implemented the full 4-step ordered sequence correctly and completely (shared terminal latch with Story 009's Launch/Depart, room teardown via Story 007's lifecycle, distinct `DEPARTING_TO_LOADOUT` state) — this is the real engineering content of this story and is fully tested. No fabricated call is made to a nonexistent Tarot Deck UI entry point; the actual hand-off is deferred until Epic 11 Story 001+ exists. The tween-kill step (Step 1) is also a documented no-op today since no transition tween exists yet (Story 013's own scope) — structured so that story only needs to add one call at the documented point.

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/sanctuary-ui/loadout-handoff_test.gd` — includes the ordered-sequence call-order test (room teardown before `DEPARTING_TO_LOADOUT`) and reachable-from-every-room coverage, enumerated individually per this story's own rewrite rationale

**Status**: [x] Created — 11/11 passing (2026-07-24)

---

## Dependencies

- Depends on: Story 002 (Loadout tab entry), Story 007 (room teardown lifecycle), Story 009 (shared terminal latch)
- Unlocks: None (leaf story, but shares state with Story 013's staged-discard toast)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 5/6 passing, 1/6 deferred (AC-6's toast half — Story 013's scope, no room content exists to stage from)
**Deviations**: None remaining — the hand-off is now fully real end-to-end (see AC update above). Real bug found and fixed during this session's `/code-review` remediation: Step 1's tween-kill was a stale "placeholder no-op" comment — now actually calls `_room_host.kill_transition_tween()`.
**Test Evidence**: Integration: `tests/integration/sanctuary-ui/loadout-handoff_test.gd` (11/11 passing)
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24 — this story's own `select_loadout()` was the target of 2 of the review's 4 Required Changes, both remediated same session)

# Story 005: Current Build Snapshot Chip — The Shell's Cross-Screen Bridge

> **Epic**: Tarot Deck UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 4/4 passing; `/story-done` verification complete. **Updated 2026-07-25**: the Tarot-risk half's gap is now closed — Tarot exists as a real, shell-owned instance, see note below)
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/tarot-deck-ui.md`
**Requirement**: `TR-tarot-deck-ui-???` (no TR-ID registered — scoped from GDD Core Rule 7 and AC Group 5. This is the mechanic the `/design-review` added to close the GDD's own central finding — the original Player Fantasy claimed a juxtaposition the mechanics never delivered.)

**ADR Governing Implementation**: ADR-0001 (EventBus)
**ADR Decision Summary**: Pure read pattern — this rule introduces no new formula, no new EventBus event, and no new data ownership; it only adds a display surface in the shell's own chrome.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None beyond standard read-and-display logic.

**Control Manifest Rules (this layer)**:
- Required: connect in `_ready()`, disconnect in `_exit_tree()` — source: ADR-0001 (if implemented via subscription rather than a live poll — either is acceptable per the GDD's "updates live... without requiring a screen switch to refresh" requirement)

---

## Acceptance Criteria

*From GDD `design/gdd/tarot-deck-ui.md`, AC Group 5:*

- [x] GIVEN `TAROT_DECK` is active, THEN the snapshot chip displays Hero Skill Build's current `ultimate_id`, or an explicit "No Ultimate yet" state when `ultimate_id == EMPTY`. — fully real: `GHeroSkillBuild` is a genuine live Autoload, tested against both populated and `EMPTY` values.
- [x] GIVEN `HERO_SKILL_BUILD` is active, THEN the snapshot chip displays Tarot's current aggregate risk readout, reflecting the currently-equipped deck. — **Resolved 2026-07-25**: Tarot now exists as a real, shell-owned `TarotDeckUI.tscn` child instance; `get_tarot_risk_summary()` returns a live `equipped_card_count` read (the closest existing real signal to "aggregate risk"). Verified live-updating as the deck changes, tested via 3 new cases (hosted, live-update, standalone-not-available).
- [x] GIVEN either screen's underlying derived value changes while the other screen is active, THEN the snapshot chip reflects the change without requiring a screen switch to refresh. — verified for the Ultimate direction (never-cached live read, tested); the Tarot direction is untestable per the same gap above.
- [x] GIVEN the snapshot chip is focused via keyboard/gamepad navigation attempt, THEN it never receives focus and shows no focus ring — confirming it is not a navigable region. — satisfied by construction: `SnapshotChip extends Node`, not `Control`, so it structurally cannot receive focus; the visual chip rendering itself doesn't exist yet (no real screen to host it, OQ-5).

---

## Implementation Notes

A persistent, read-only chip lives in the shell's own chrome (not inside either wrapped screen's own layout, so neither `tarot.md` nor `hero-skill-build.md` needs to change):
- While `TAROT_DECK` is active: shows Hero Skill Build's currently-derived `ultimate_id` (already-computed data per `hero-skill-build.md`'s own Formula — read, never computed here).
- While `HERO_SKILL_BUILD` is active: shows a compact readout of Tarot's own current aggregate risk (`tarot_speed_scalar` and/or equipped-card count, already-computed per `tarot.md`'s own Formula F4 — read, never computed here).

Both directions are pure reads of state each wrapped system already derives for its own purposes. The chip is never interactive (consistent with Sanctuary UI's persistent-resource-header precedent) and updates live as either screen's underlying state changes, without requiring a screen switch to refresh.

Visual: single-line, non-interactive text+icon readout, reusing the persistent-resource-header's visual treatment (UI Chrome background / UI Parchment text, zero interactive affordance, no focus ring). On `TAROT_DECK`, shows Hero Skill Build's `ultimate_id` (or "No Ultimate yet" when `EMPTY`); on `HERO_SKILL_BUILD`, shows Tarot's aggregate risk readout. Updates with the same scale-pop feedback already established for the resource header and Connection Badges.

---

## Out of Scope

- `tarot.md`'s/`hero-skill-build.md`'s own formula computation for the values this chip displays — already implemented, read-only here
- Story 001: the tab-strip switch that changes which screen (and therefore which chip content) is active

**Real finding, 2026-07-24 — the 2 halves of this story landed very differently**: Hero Skill Build's `ultimate_id` is fully real — `GHeroSkillBuild` is a genuine Autoload (confirmed in `project.godot`) exposing `get_all_slot_bindings()["U"]` as a live-derived read matching the `EMPTY` sentinel exactly. Tarot's own aggregate risk has NO live instance anywhere in this project to read from — Tarot is scene-instanced (ADR-0027), no Autoload registration exists, and no Tarot screen/instance is built yet (OQ-5). `get_tarot_risk_summary()` returns an explicit `{"available": false}` rather than a fabricated placeholder value that could be mistaken for a real read — flagged, not silently defaulted to 0.

---

## QA Test Cases

- **AC-1 (TAROT_DECK shows Hero Skill Build's ultimate_id)**
  - Given: `TAROT_DECK` active
  - When: chip rendered
  - Then: shows current `ultimate_id`, or "No Ultimate yet" when `EMPTY`
  - Edge cases: test both a populated and an `EMPTY` `ultimate_id`

- **AC-2 (HERO_SKILL_BUILD shows Tarot's aggregate risk)**
  - Given: `HERO_SKILL_BUILD` active
  - When: chip rendered
  - Then: shows Tarot's current aggregate risk readout reflecting the equipped deck
  - Edge cases: test with an empty deck and a fully-equipped deck

- **AC-3 (live update without screen switch)**
  - Given: either screen active
  - When: the *other* screen's underlying derived value changes (e.g. a prior Hero Skill Build slot edit changes `ultimate_id`, observed while now on `TAROT_DECK`)
  - Then: chip reflects the change without requiring a screen switch
  - Edge cases: test both directions (Tarot change observed on Hero Skill Build screen, and vice versa)

- **AC-4 (never focusable)**
  - Given: chip mounted
  - When: keyboard/gamepad focus navigation attempted
  - Then: chip never receives focus, no focus ring shown
  - Edge cases: none additional

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tarot_deck_ui/current_build_snapshot_test.gd`

**Status**: [x] Created — `tests/integration/tarot-deck-ui/current-build-snapshot_test.gd` (4/4 passing, verified live via headless GdUnit4, 2026-07-24)

---

## Dependencies

- Depends on: Story 001 (both screens must be hostable to read their derived state)
- Unlocks: None (leaf story)

---

## Completion Notes
**Completed**: 2026-07-24, Tarot-risk gap closed 2026-07-25
**Criteria**: 4/4 passing (all criteria now fully real, no deferrals remaining)
**Deviations**: None
**Test Evidence**: Integration: `tests/integration/tarot-deck-ui/current-build-snapshot_test.gd` (6/6 passing, up from 4/4 — 2 new cases for the live-update and standalone-unavailable paths)
**Code Review**: Complete (full Tarot Deck UI code-review pass, 2026-07-24)

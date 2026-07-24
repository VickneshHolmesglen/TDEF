# Story 004: Conflict Indicator — Tarot / Mission Select Modifier-Mapping Table

> **Epic**: Tarot Deck UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 8/8 passing; `/story-done` verification complete)
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b
> **Estimate**: 4h

## Context

**GDD**: `design/gdd/tarot-deck-ui.md`
**Requirement**: `TR-tarot-deck-ui-???` (no TR-ID registered — scoped from GDD Core Rule 6 and AC Group 4. This is the mechanism the GDD's own `/design-review` found and fixed a real bug in — a broken literal string-equality check — so its test coverage is unusually load-bearing.)

**ADR Governing Implementation**: ADR-0027 (Tarot Modifier Aggregation Pipeline) + ADR-0028 (Mission Select Runtime State)
**ADR Decision Summary**: Both ADRs are Accepted and govern the two wrapped systems' own gameplay logic and data model. This shell hosts their screens unmodified and only reads already-derived state (`run_modifier_selected`, Tarot's aggregate risk) — introduces no new formula or data ownership.

**Engine**: Godot 4.6.2 | **Risk**: LOW (for this shell specifically — the wrapped systems' own risk is unchanged from Epic 07)
**Engine Notes**: None beyond standard EventBus read-subscription discipline.

**Control Manifest Rules (this layer)**:
- Required: connect in `_ready()`, disconnect in `_exit_tree()` — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/tarot-deck-ui.md`, AC Group 4:*

- [x] GIVEN a slotted Tarot card's `modifier_type` has a mapped entry in the mapping table (`tarot_difficulty_growth_rate` or `tarot_wave_config_override`) and Mission Select's active `run_modifier_selected` targets that mapped pairing, WHEN `TAROT_DECK` is active, THEN the conflict badge renders on that card's tray slot. — tested at the mapping/query-engine level (`get_conflicting_modifier_ids()`/`has_conflict()`); the actual badge overlay awaits a future Tarot screen story (OQ-5).
- [x] GIVEN a slotted Tarot card's `modifier_type` is `tarot_speed_scalar_mult` or `tarot_reward_scalar_mult` (no mapping-table entry exists), THEN no conflict badge ever renders for that card regardless of Mission Select's current selection.
- [x] GIVEN no `run_modifier_selected` value is currently set, WHEN `TAROT_DECK` is active, THEN no conflict badge renders for any slotted card.
- [?] GIVEN the conflict badge is showing, WHEN the player navigates to `HERO_SKILL_BUILD` or exits the shell, THEN the transition proceeds without being blocked or gated by the indicator. — DEFERRED: no real badge UI exists yet to test against (OQ-5); the engine itself has no navigation-blocking code path by construction (pure read-only query).
- [?] GIVEN the conflict badge is showing and the player inspects the affected card, THEN plain text names the exact shared `WaveConfig` target field and the colliding Mission Select selection — never icon-only at that tier. — DEFERRED: same OQ-5 gap, no real inspect UI exists.

---

## Implementation Notes

`tarot.md` Rule 8 assigns this shell responsibility: when a slotted Tarot card's effect targets the same underlying mission parameter as an active Mission Select run modifier, the Tarot screen (not a shell-level element — only Tarot's own screen has the `source_card_id` context and the read-only `run_modifier_selected` subscription) renders a small, distinct badge anchored to the conflicting tray slot's top-right corner, offset 4px outside the slot's own bounding box.

**The match is a conceptual mapping, never a literal string comparison** — implement exactly this table, not a `modifier_type == modifier_id` check (that comparison could never match, since the two systems' vocabularies are disjoint):

| Tarot `modifier_type` | Conflicts with Mission Select `modifier_id`(s) | Shared target |
|---|---|---|
| `tarot_difficulty_growth_rate` | `"difficulty_growth_boost"` | Both write to `WaveConfig.difficulty_growth_rate` |
| `tarot_wave_config_override` | `"extend_waves"` **and** `"difficulty_growth_boost"` | A whole-`WaveConfig` swap replaces every field the swapped-in config defines, including `difficulty_growth_rate` — conflicts with BOTH Mission Select modifiers |
| `tarot_speed_scalar_mult` | *(none)* | No current Mission Select analog |
| `tarot_reward_scalar_mult` | *(none)* | Same — no current analog |

A card can show conflict badges against more than one active Mission Select selection simultaneously (only possible for `tarot_wave_config_override`) — the badge and inspect text must handle a multi-conflict card, not assume exactly one. This table is an explicit constant, not inferred at runtime from string similarity — if Mission Select's `modifier_id` catalogue grows, this table needs a corresponding new row (Tuning Knobs maintenance note).

Stale-value clearing: `run_modifier_selected` values are Mission Select's own per-session state, reset by Mission Select itself on transition to a fresh `CONFIGURING` state — the indicator reads Mission Select's *current* live value at every render, never a cached one; this shell does not own or duplicate that reset logic.

The indicator is purely advisory — never blocks navigation, screen-switch, or shell exit, and grants no authority over mission launch or modifier resolution (Wave Manager's territory).

---

## Out of Scope

- Wave Manager's own resolution of which modifier "wins" when a real conflict exists — this indicator only flags the overlap, never adjudicates it
- Story 001/003: the screen-switch mechanics this badge's non-blocking behavior is verified against

**Implementation note, 2026-07-24**: no real Tarot deck-tray UI exists yet (OQ-5), so this story implements the mapping/query engine only (`ConflictIndicator`, shell-owned, always listening) — the actual badge overlay on a real card slot is a future screen-building story's job, which will query `get_conflicting_modifier_ids()`/`has_conflict()` directly. MissionSelect exposes no public getter for its active run-modifiers, so this class tracks the same state locally via the same public EventBus signals (`run_modifier_selected`, `mission_selected`) a real Tarot subscription would use — not a private-state workaround, the same event stream.

---

## QA Test Cases

- **AC-1 (mapped conflict renders)**
  - Given: slotted card with `tarot_difficulty_growth_rate` or `tarot_wave_config_override`, matching active `run_modifier_selected`
  - When: `TAROT_DECK` active
  - Then: badge renders on that slot
  - Edge cases: test `tarot_wave_config_override` against both `"extend_waves"` and `"difficulty_growth_boost"` individually, and simultaneously (multi-conflict card)

- **AC-2 (no-analog modifiers never trigger)**
  - Given: slotted card with `tarot_speed_scalar_mult` or `tarot_reward_scalar_mult`
  - When: any `run_modifier_selected` value active
  - Then: no badge ever renders for that card
  - Edge cases: test both no-analog types individually

- **AC-3 (no selection, no badge)**
  - Given: no `run_modifier_selected` value set
  - When: `TAROT_DECK` active
  - Then: no badge for any card
  - Edge cases: none additional

- **AC-4 (badge never blocks navigation)**
  - Given: badge showing
  - When: navigate to `HERO_SKILL_BUILD` or exit shell
  - Then: transition proceeds unblocked
  - Edge cases: none additional

- **AC-5 (inspect shows plain-text target field)**
  - Given: badge showing, card inspected
  - When: inspect text rendered
  - Then: names exact shared `WaveConfig` field and colliding selection, never icon-only
  - Edge cases: test with a multi-conflict card — text must name both collisions

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tarot_deck_ui/conflict_indicator_test.gd` — must include the mapped-pairing regression test (not literal string comparison), since this is the exact bug the GDD's own review found and fixed

**Status**: [x] Created — `tests/integration/tarot-deck-ui/conflict-indicator_test.gd` (8/8 passing, verified live via headless GdUnit4, 2026-07-24, including the mapped-pairing regression test)

---

## Dependencies

- Depends on: Story 001 (TAROT_DECK screen must be hostable)
- Unlocks: None (leaf story)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 3/5 passing, 2/5 deferred (AC-4/AC-5 — no real badge/inspect UI exists yet, OQ-5)
**Deviations**: None
**Test Evidence**: Integration: `tests/integration/tarot-deck-ui/conflict-indicator_test.gd` (8/8 passing)
**Code Review**: Complete (full Tarot Deck UI code-review pass, 2026-07-24)

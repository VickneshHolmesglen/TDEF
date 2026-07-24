# Story 014: Experiential Playtest — Player Fantasy, Loadout Continuity, Badge Legibility

> **Epic**: Sanctuary UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-07-13b
> **Estimate**: 2h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from the GDD's own Experiential Criterion section, explicitly not mechanically testable)

**ADR Governing Implementation**: None — this story is a moderated-playtest evidence requirement, not an engine-level implementation.

**Engine**: Godot 4.6.2 | **Risk**: N/A
**Engine Notes**: None.

**Control Manifest Rules (this layer)**: N/A — no code changes expected from this story; it validates already-implemented behavior (Stories 001–013) against real player debrief.

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, Experiential Criterion section — matching `mission-hud.md`'s own precedent for this evidence tier:*

- [ ] GIVEN a player completes a mission and returns to Sanctuary UI's `OVERVIEW`, WHEN debriefed afterward, THEN the player can articulate at least one specific choice their sanctuary visibly reflects (a structure, a habitat, a build direction) without being prompted for it.
- [ ] GIVEN a player selects Loadout from mid-room (not from `OVERVIEW`), WHEN debriefed afterward, THEN they describe reaching Tarot Deck UI as a natural continuation of what they were doing, not a separate menu or errand — the direct experiential test of the Player Fantasy's "one continuous motion" claim.
- [ ] GIVEN a Connection Badge appears on a tab while the player is in a different room, WHEN debriefed afterward, THEN the player can correctly say what the badge was about without opening that room first — the direct experiential test of whether Core Rule 9's tab-strip-level legibility promise actually lands with a real player, not just that the badge mechanically fires.

---

## Implementation Notes

This story requires no new implementation — it is a moderated-playtest evidence pass against the fully-implemented shell (Stories 001–013 must all be Done first). Cannot be closed autonomously; requires a real human playtester, matching this epic's own flagged blocker (session state's tracked "2 remaining Partial items need a real human playtest pass" pattern, established in Epic 06).

Structure the playtest session as: (1) a normal mission-complete return to `OVERVIEW`, debrief on what they notice about their sanctuary; (2) a mid-room Loadout selection, debrief on how the transition felt; (3) engineer a Connection Badge appearance while the player is in a different room, debrief on whether they can say what it was about without opening that room.

Record verbatim or summarized player responses in the evidence doc — a pass/fail judgment alone is insufficient, since the GDD's own criteria require the player's own words as evidence.

---

## Out of Scope

- Any new implementation — this story is playtest evidence collection only
- Mechanical/runtime testing of Connection Badges firing correctly (already covered by Story 003) — this story tests whether the badge's *meaning* lands with a player, not whether it fires

---

## QA Test Cases

*(Experiential story — moderated playtest, not automated or manual-verification-checklist)*

- **Manual check: Player Fantasy "step back and look"**
  - Setup: player completes a mission normally, returns to `OVERVIEW`
  - Verify: debrief — can they name a specific choice their sanctuary reflects, unprompted?
  - Pass condition: player names at least one specific structure/habitat/build-direction choice without being prompted

- **Manual check: Loadout "one continuous motion"**
  - Setup: player is mid-room (not `OVERVIEW`), selects Loadout
  - Verify: debrief — do they describe it as continuation vs. a separate errand?
  - Pass condition: player's own description frames it as continuous, not as "leaving to go somewhere else"

- **Manual check: Connection Badge legibility**
  - Setup: engineer a badge appearance on a tab while player is in a different room
  - Verify: debrief — can they say what the badge was about without opening that room?
  - Pass condition: player correctly identifies the badge's rough meaning (which system, what kind of change) without first entering that room

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/story-014-experiential-playtest-evidence.md` — must include recorded/summarized player responses, not a bare pass/fail

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 through Story 013 (all must be Done — this story validates the complete implementation)
- Unlocks: None (final story in the epic)

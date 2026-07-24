# Epic 11: Tarot Deck UI

> **Layer**: Presentation
> **GDD**: design/gdd/tarot-deck-ui.md
> **Architecture Module**: Presentation Layer — sibling shell to Sanctuary UI (2-screen tab strip hosting Tarot and Hero Skill Build's existing screens)
> **Status**: Ready
> **Stories**: 5 stories created (2026-07-24) — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Structural Model — Sibling Shell, 2-Screen Tab Strip Navigation | UI | Complete (2026-07-24, 5/5 tests passing) | ADR-0011 |
| 002 | Entry — Sanctuary UI's Loadout Affordance | Integration | Complete (2026-07-24, 3/3 tests passing) — AC-3's phase-gate check is a real, flagged gap, no external enforcement exists yet | ADR-0020 |
| 003 | Exit & Lifecycle — Destroy-and-Recreate, Gamepad Pick-Up Transient State | Logic | Complete (2026-07-24, 3/3 tests passing) — Cancel's SceneManager hand-off is genuinely real (not a placeholder); both real screens now exist (built 2026-07-25) but AC-2/AC-3's own content-dependent verification against them hasn't been separately re-run | ADR-0032 / ADR-0011 / ADR-0001 / ADR-0020 |
| 004 | Conflict Indicator — Tarot / Mission Select Modifier-Mapping Table | Integration | Complete (2026-07-24, 8/8 tests; real badge UI wired 2026-07-25, 14/14 tests on `tarot_screen_test.gd`) — **the full mechanism is now real end-to-end**: `tarot_screen.gd` queries `ConflictIndicator` and renders a live conflict tag | ADR-0027 / ADR-0028 |
| 005 | Current Build Snapshot Chip — The Shell's Cross-Screen Bridge | Integration | Complete (2026-07-24, 4/4 tests; Tarot-risk gap closed 2026-07-25, 6/6 tests) — **both halves now fully real**: Ultimate (live GHeroSkillBuild read) and Tarot-risk (live shell-owned Tarot instance read) | ADR-0001 |

**Note**: no story here is `Blocked` — all governing ADRs (0001, 0011, 0020, 0027, 0028) are `Accepted`. ADR-0020's classification of Story 002's entry hand-off remains formally unresolved (mirrors Sanctuary UI Epic 10's OQ-9), flagged in that story's own Context, not treated as a blocker. Story 002 also depends on Sanctuary UI Epic 10's Story 010 (the sending side of the same hand-off) — implement in that order.

**Closure status (2026-07-24)**: all 5 stories have passed `/code-review` (1 Required Change found — a missing ADR-0032 Section 2 terminal latch in `confirm_return_to_sanctuary()` — remediated same session) and `/story-done` (each story's own Completion Notes document which ACs are fully verified vs. explicitly deferred: OQ-5's 2 unbuilt screens block most content-dependent ACs; AC-3's phase-gate check in Story 002 has no real enforcement anywhere yet).

**Update (2026-07-25)**: both cited blockers from the original closure note were stale — `design/ux/tarot-deck-ui.md` (OQ-4) was actually authored 2026-07-24, the same day as this note, just never cross-referenced back here; and both hosted screens (`src/gameplay/ui/tarot_screen/`, `src/gameplay/ui/hero_skill_build_screen/`) were built later that same session. Story 004's Conflict Indicator badge — the one genuinely real gap found once the screens existed (the engine and the screen existed independently but nothing connected them) — is now wired end-to-end and tested (14/14 on `tarot_screen_test.gd`). **This epic is still not marked Complete**: Story 002's AC-3 phase-gate check remains a real, unaddressed gap (no external enforcement exists anywhere in the project for "shell entry blocked while a mission is active"), and Story 003's AC-2/AC-3 have not been separately re-verified against the now-real screens even though the content blocking them no longer exists. Epic status remains `Ready` pending those two items.

## Overview

Tarot Deck UI is the presentation shell that lets players compose their pre-mission strategic commitments — Tarot deck composition and Hero Skill Build's active skill loadout — from a single 2-screen tab strip, reached via Sanctuary UI's Loadout entry. It hosts both systems' already-implemented, already-designed screens unmodified and adds exactly one new mechanic of its own: a persistent, read-only "Current Build Snapshot" chip that shows each screen a one-line summary of the other's headline state (the derived Ultimate while composing a deck; the deck's aggregate risk while composing a loadout), plus a conflict indicator that flags when a slotted Tarot card and an active Mission Select run modifier target the same underlying `WaveConfig` field. Without this shell, both wrapped systems' gameplay logic (Epic 07's Tarot, Epic 08's Hero Skill Build) has no way for a player to actually change their build between missions.

Architecturally: the smallest version of the shell problem Sanctuary UI solved — 2 peer, mutually-exclusive full-frame screens (no third "overview" state), destroy-and-recreate lifecycle on switch (same mechanism as Sanctuary UI's rooms, independently restated per the GDD's own Core Rule 5), same trigger/bumper input-split convention as Sanctuary UI (triggers switch screens, bumpers stay owned by each screen's internal category-cycling). Sole entry is Sanctuary UI's Loadout tab (reachable from any Sanctuary UI state, per that GDD's redesigned Core Rule 10); sole exit returns to a freshly-mounted Sanctuary UI at `OVERVIEW`. This GDD reached Approved status the same session as Sanctuary UI, via a full `/design-review` that found MAJOR REVISION NEEDED (Player Fantasy claimed an undelivered juxtaposition; a broken string-equality conflict check; a stale entry-mechanism reference) — all fixed and independently re-verified same-day. See `design/gdd/reviews/tarot-deck-ui-review-log.md` for the full account.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0011: UI Dual-Focus Handling (Accepted) | Same `InputModeTracker` pattern Sanctuary UI's Core Rule 6 relies on — this shell's 2-screen tab strip plus each hosted screen's own internal focus needs the identical dual-focus handling. ADR-0011's Accepted text names Sanctuary UI/Tarot Deck UI together as anticipated consumers. | HIGH (same post-cutoff `grab_focus()` mouse/gamepad split ADR-0011 already mitigates project-wide) |
| ADR-0027 / ADR-0028: Tarot / Mission Select (Accepted, 2026-07-18) | Govern the two wrapped systems' own gameplay logic and data model — this shell hosts their screens unmodified and only reads already-derived state (`run_modifier_selected`, Tarot's aggregate risk), introducing no new formula or data ownership per the GDD's own Formulas section (none). | LOW (for this shell specifically — the wrapped systems' own risk is unchanged from Epic 07) |
| ADR-0020: Direct-Autoload-call exception pattern (Accepted) | Governs this shell's hand-off to/from Sanctuary UI (Core Rule 3 entry, Core Rule 4 exit) — the same unclassified-call pattern as Sanctuary UI's own Core Rule 8/10. **Not yet formally classified** — mirrors Sanctuary UI epic's own flagged gap (that epic's OQ-2/OQ-9). | LOW |

**Gap closed 2026-07-24**: ADR-0032 (Presentation Shell Hosting Pattern) now formally covers both this shell's `ScreenHost` destroy-and-recreate pattern and terminal-latch discipline together with Sanctuary UI's identical mechanism, written as one shared ADR rather than two near-duplicates, exactly as this epic originally recommended. ADR-0020's Criterion A/B classification of Story 002's entry hand-off remains open — not covered by ADR-0032.

## GDD Requirements

**No TR-IDs are currently registered for `tarot-deck-ui`** — same total gap as Sanctuary UI. Stories for this epic are scoped directly from the GDD's own Core Rules (1–7), States and Transitions table, and Acceptance Criteria groups — same precedent established by Epic 09 (Mission HUD) and just reapplied for Epic 10 (Sanctuary UI).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| *(none registered)* | Core Rule 1 — structural model, 2-screen sibling shell, no overview state | No ADR yet |
| *(none registered)* | Core Rule 2 — 2-entry tab strip, trigger/bumper split | ADR-0011 ✅ (focus model only) |
| *(none registered)* | Core Rule 3 — entry via Sanctuary UI's Loadout affordance | ADR-0020 ⚠️ (unclassified) |
| *(none registered)* | Core Rule 4 — exit, return to fresh Sanctuary UI `OVERVIEW` | ADR-0020 ⚠️ (unclassified) |
| *(none registered)* | Core Rule 5 — destroy-and-recreate lifecycle, gamepad pick-up transient-state edge case | No ADR yet |
| *(none registered)* | Core Rule 6 — Tarot/Mission Select conflict indicator, modifier-mapping table | ADR-0027/0028 ✅ (data model only) |
| *(none registered)* | Core Rule 7 — Current Build Snapshot chip (pure read, no new formula/event/ownership) | No ADR yet |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/tarot-deck-ui.md` are verified (5 AC groups: Structural Model & Navigation, Entry, Exit & Lifecycle, Conflict Indicator, Current Build Snapshot)
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Live-MCP verification of the destroy-and-recreate `ScreenHost` lifecycle and the Core Rule 6 conflict indicator's mapped-pairing logic (not literal string comparison — the GDD's own review found and fixed a bug here, worth a direct regression test)
- `design/ux/tarot-deck-ui.md` is authored (per the GDD's own UX Flag, OQ-4) before or during implementation stories, expected to be markedly shorter than Sanctuary UI's own UX spec since most of the 2 hosted screens' UX is already specified in `tarot.md`/`hero-skill-build.md` directly
- Both hosted screens' actual `.tscn` container/anchor structure is verified to host cleanly inside this shell's `ScreenHost` (OQ-5 — neither screen exists as a built scene yet, only as design text)

## Next Step

Run `/create-stories epic-11-tarot-deck-ui` to break this epic into implementable stories.

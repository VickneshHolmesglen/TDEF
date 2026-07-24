# Epic 10: Sanctuary UI

> **Layer**: Presentation
> **GDD**: design/gdd/sanctuary-ui.md
> **Architecture Module**: Sanctuary UI (tab/panel navigation shell — architecture.md's own Presentation-layer module list, line 305)
> **Status**: Ready
> **Stories**: 14 stories created (2026-07-24) — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Structural Model — Full-Frame Diorama, RoomHost, Persistent Chrome | UI | Complete (2026-07-24, 8/8 tests passing) | ADR-0002 |
| 002 | Tab Strip Navigation — 6-Entry Strip, Hotkeys, Trigger/Bumper Split, Onboarding | UI | Complete (2026-07-24, 17/17 tests passing) | ADR-0011 |
| 003 | Connection Badges — Cross-System Legibility on the Tab Strip | Integration | Complete (2026-07-24, 8/8 tests passing) | ADR-0001 |
| 004 | Persistent Resource Header | Integration | Complete (2026-07-24, 3/3 tests passing) — 1 AC flagged as not-yet-implementable (no system owns a Sanctuary-context gold/materials balance, see story's own note) | ADR-0001 |
| 005 | Room Hosting — Inventory+Crafting, Menagerie, Defense Building, Equipment Forge | Integration | Complete (2026-07-24, 5/5 tests passing) — only Inventory & Crafting has a real scene to host; the other 3 fail safe, see story's own note | ADR-0002 |
| 006 | Entry Always Defaults to OVERVIEW; Player-Initiated Return | Logic | Complete (2026-07-24, 7/7 tests passing) | ADR-0002 |
| 007 | Room Lifecycle — Destroy-and-Recreate, EventBus Disconnect + Input Gate, InputModeTracker Roster | Logic | Complete (2026-07-24, 6/6 tests passing) — implemented ahead of Story 005 dependency, see story's own note | ADR-0032 / ADR-0011 / ADR-0001 |
| 008 | Back Navigation — Cancel Idiom | Logic | Complete (2026-07-24, 4/4 tests passing) | ADR-0011 |
| 009 | Exit — Launch/Depart to Mission Select, Terminal Latch | Integration | Complete (2026-07-24, 8/8 tests passing) — terminal latch fully real, actual hand-off is a flagged placeholder (no Mission Select browsing screen exists, see story's own note) | ADR-0020 |
| 010 | Loadout — Tab Strip's 6th Entry, Hand-off to Tarot Deck UI | Integration | Complete (2026-07-24, 11/11 tests passing) — ordered sequence fully real, actual Tarot Deck UI call is a flagged gap (Epic 11 not yet built, see story's own note) | ADR-0032 / ADR-0020 / ADR-0011 / ADR-0001 |
| 011 | Cross-Room Highlighting Stays Confined to a Room | Logic | Complete (2026-07-24, 4/4 tests passing) — no new production code, confirms a Story 007 structural guarantee; AC-2 has no real content to test against yet, see story's own note | None (behavioral scoping rule) |
| 012 | Load-Bearing Edge Cases — Rapid Input, Staged-Discard Toast, Watchtower No-Room Click | Integration | Complete (2026-07-24, 4/4 tests passing) — rapid-input mashing and staged-discard data fully real; toast UI, Watchtower click, and mount-time poll are gaps flagged not papered over, see story's own note | ADR-0001 / ADR-0011 |
| 013 | Visual/Audio Pass — Drawer-Slide, DEPARTING Beat, Shell Chrome Language | Visual/Feel | Partial (2026-07-24) — chrome/room-hosting/badge/header/DEPARTING-fade implemented and live-verified via Godot MCP screenshots; diorama-dependent visuals blocked on missing content, see evidence doc | ADR-0013 |
| 014 | Experiential Playtest — Player Fantasy, Loadout Continuity, Badge Legibility | Visual/Feel | Ready | None (playtest evidence) |

**Note**: no story here is `Blocked` — all 3 governing ADRs (0002, 0011, 0020, 0001, 0013) are `Accepted`. ADR-0020's classification of this epic's own hand-off calls (Stories 009/010) remains formally unresolved (OQ-2/OQ-9) — flagged in each story's own Context, not treated as a blocker, matching this epic's own precedent for shipping ahead of full ADR classification.

**Closure status (2026-07-24)**: Stories 001-012 have all passed `/code-review` (CHANGES REQUIRED verdict, all 4 Required Changes remediated same session — see `room_host.gd`/`sanctuary_ui.gd` fixes) and `/story-done` (each story's own Completion Notes document which ACs are fully verified vs. explicitly deferred against real gaps: OQ-5's 3 unbuilt rooms, Story 004's balance-ownership gap, Story 009/010's unwired Mission Select/Tarot Deck UI hand-offs). This epic is **not yet Complete**: Story 013 is Partial (diorama content blocks its remaining ACs) and Story 014 has not been attempted. Epic status remains `Ready` pending those two.

## Overview

Sanctuary UI is the presentation shell that makes the Sanctuary's five gameplay systems — the fused Inventory+Crafting two-panel screen, Menagerie, Defense Building, and Equipment Forge — navigable and visible to the player between missions, plus a full-frame `OVERVIEW` state showing the Sanctuary diorama and a 6th tab-strip entry ("Loadout") handing off to the separate Tarot Deck UI shell. It is the only way a player reaches Crafting, the tech tree, the menagerie, or equipment imbuing — without it, five already-implemented gameplay systems (Epics 05 and 08) have no player-facing surface at all.

Architecturally: a single shell built from two mutually-exclusive full-frame content states (`OVERVIEW`'s diorama, or a `RoomHost`-hosted `ROOM_*` screen) plus persistent chrome (a 6-entry tab strip with Connection Badges, a resource header). Rooms are destroyed-and-recreated on every switch (never kept alive-hidden), mirroring `mission_hud.gd`'s own Planning Cluster precedent. Two externally-visible hand-offs exist: Launch/Depart (`OVERVIEW`-only, to Mission Select) and Loadout (reachable from any state, to Tarot Deck UI) — both share one terminal-latch discipline. This is the largest and most heavily-revised GDD in the project's history (6 review passes across 2 sessions before reaching Approved status tonight — see `design/gdd/reviews/sanctuary-ui-review-log.md` for the full account, including a documented mid-cycle freeze-and-deliberate-redesign of its own hand-off mechanism).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0011: UI Dual-Focus Handling (Accepted) | `InputModeTracker` pattern — the exact mechanism this GDD's Core Rule 6 (6 tracker instances, tab strip default focus, room-instance-scoped trackers) is built on. ADR-0011's own Accepted note explicitly names Sanctuary UI as an anticipated future consumer. | HIGH (post-cutoff engine behavior — Godot 4.6's `grab_focus()` mouse/gamepad focus split — already mitigated project-wide via this ADR) |
| ADR-0002: Scene/Autoload Structure (Accepted) | Establishes the project's scene-vs-Autoload placement convention Sanctuary UI is expected to follow (scene-instanced under the Sanctuary scene, not an Autoload) — not yet explicitly extended to name Sanctuary UI, same gap noted below. | LOW |
| ADR-0020: Direct-Autoload-call exception pattern (Accepted) | Governs Core Rule 8's Launch/Depart (→ Mission Select) and Core Rule 10's Loadout (→ Tarot Deck UI) hand-off calls — both are direct, non-EventBus calls requiring Criterion A/B classification under this ADR. **Not yet formally classified** — the GDD's own Open Questions (OQ-2, OQ-9) flag both as pending. | LOW |

**Gap closed 2026-07-24**: ADR-0032 (Presentation Shell Hosting Pattern) now formally documents the `RoomHost`/destroy-and-recreate lifecycle and the terminal-latch's exact disconnect-first sequencing — written as one shared ADR covering both this epic and Epic 11 (Tarot Deck UI), rather than two near-duplicates, since both GDDs independently re-derived the identical mechanism through their own review histories. godot-specialist validated the pattern as sound Godot 4.6.2 usage during authoring. ADR-0020's Criterion A/B classification of the two hand-off calls (Launch/Depart, Loadout) remains open (OQ-2/OQ-9) — not covered by ADR-0032, still flagged for Stories 009/010.

## GDD Requirements

**No TR-IDs are currently registered for `sanctuary-ui` in `tr-registry.yaml`** — a real, larger version of the same gap Mission HUD's own epic flagged (3 of ~27 Core Rules registered there; here, 0 of 10). Stories for this epic are scoped directly from the GDD's own Core Rules (1–10), States and Transitions table, and Interactions table — the same precedent Epic 09 (Mission HUD) established for shipping against a GDD whose TR-ID coverage lags its own content. Recommend a `/architecture-review` TR-ID sync pass for `sanctuary-ui.md` at a future checkpoint, ideally paired with authoring the dedicated ADR noted above.

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| *(none registered)* | Core Rule 1 — full-frame diorama/room structural model, `RoomHost`, z-order guarantee | No ADR yet |
| *(none registered)* | Core Rule 2 — 6-entry tab strip, trigger/bumper split, Connection Badges | ADR-0011 ✅ (focus model only) |
| *(none registered)* | Core Rule 3 — persistent resource header | No ADR yet |
| *(none registered)* | Core Rule 4 — Menagerie hosted unmodified, full-bleed | No ADR yet |
| *(none registered)* | Core Rule 5 — entry defaults to `OVERVIEW`, player-initiated return | No ADR yet |
| *(none registered)* | Core Rule 6 — destroy-and-recreate room lifecycle, 6 `InputModeTracker` instances | ADR-0011 ✅ (focus model only) |
| *(none registered)* | Core Rule 7 — Cancel/back navigation | No ADR yet |
| *(none registered)* | Core Rule 8 — Launch/Depart hand-off to Mission Select | ADR-0020 ⚠️ (unclassified, OQ-2) |
| *(none registered)* | Core Rule 9 — Connection Badges as cross-system legibility | No ADR yet |
| *(none registered)* | Core Rule 10 — Loadout tab, hand-off to Tarot Deck UI, teardown/terminal-latch ordering | ADR-0020 ⚠️ (unclassified, OQ-9) |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/sanctuary-ui.md` are verified (Test Evidence per story type — this GDD's own AC section is unusually large given its review history: 10 Core Rule groups, a States/Transitions group, Cross-System Interaction Criteria, Load-Bearing Edge Cases, and an Experiential Criterion group)
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Live-MCP verification of the destroy-and-recreate room lifecycle's `_ready()`-refire guarantee and the terminal-latch's disconnect-before-teardown ordering (the exact mechanism the GDD's own 6-pass review history repeatedly found underspecified — this epic's stories should treat that history as a direct testing checklist, not just design prose)
- `design/ux/sanctuary-ui.md`'s own tracked staleness (OQ-9 in that document — wireframes/binding-table/Interaction sections still describe the pre-redesign 5-entry tab strip) is resolved before or during the stories that need it, since implementation stories should cite the UX spec, not the GDD directly, per this project's established precedent

## Next Step

Run `/create-stories epic-10-sanctuary-ui` to break this epic into implementable stories.

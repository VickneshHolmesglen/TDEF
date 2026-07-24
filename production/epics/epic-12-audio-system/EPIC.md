# Epic 12: Audio System

> **Layer**: Presentation
> **GDD**: design/gdd/audio-system.md
> **Architecture Module**: Audio System (`docs/architecture/architecture.md` — "Sound bus management; music cue state — EventBus subscriber — responds with audio")
> **Status**: Ready
> **Stories**: 6 stories created (2026-07-25) — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Mix Bus Architecture | Logic | Complete (2026-07-25) | N/A |
| 002 | State-Driven Music and Ambient | Integration | Complete (2026-07-25) | N/A |
| 003 | Data-Driven Cue Dispatch | Integration | Complete (2026-07-25) | N/A |
| 004 | Ducking and Voice Limiting | Logic | Complete (2026-07-25) | N/A |
| 005 | Volume Preference Persistence | Integration | Ready | N/A |
| 006 | Pause Behavior | Integration | Ready | ADR-0014 (informational-only pause signal precedent) |

**Note**: no story here is `Blocked`. None have a dedicated governing ADR (matches Sanctuary UI/Tarot Deck UI's own precedent — stories scoped directly from the GDD's 7 Core Rules). Story 003's `AudioCueMap` data-structure choice may warrant its own `/architecture-decision` pass during implementation if the shape proves non-trivial. Story 005's AC-13 (volume persists across a full process relaunch) needs either a scripted relaunch harness or a documented manual playtest — this project's standard in-process test runner cannot exercise it directly.

## Overview

The Audio System is the sonic-identity layer that gives every other system's already-fired EventBus events a voice — subscribing to 16 already-frozen events (mission phase transitions, tower combat, hero skills, discoveries, crafting, sanctuary construction, pause) and answering each with music, ambient atmosphere, or a one-shot cue, without any emitting system needing to know Audio exists. It is the shared home roughly 8-10 other already-written GDDs each independently flagged as a placeholder "Audio direction (category only, no audio bible yet)" note — this epic builds the mix architecture (4 player-facing buses per the accessibility commitment, internal sub-routing beneath them), the 7-family cue taxonomy those scattered notes sort into, the data-driven `AudioCueMap` dispatch mechanism, ducking/priority discipline, pause-duck behavior, and volume-preference persistence. It does not author the actual audio bible content (specific SFX assets, music tracks) — that remains separate Full Vision-tier content-authoring work, same as every other system's content-authoring is separate from its mechanical design.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| None yet | No dedicated architecture ADR exists for the `AudioCueMap` Resource shape, the bus-graph construction, or the generic event-dispatch mechanism. Matches Sanctuary UI/Tarot Deck UI's own precedent (both proceeded to stories without a dedicated ADR, scoping stories directly from the GDD's own Core Rules). Flagged honestly, not silently assumed covered by an unrelated existing ADR — closest related ADRs (ADR-0014 Pause System, ADR-0031 Mission HUD Architecture) govern adjacent but distinct concerns (pause-flag ownership, HUD layout) and do not cover Audio's own bus/dispatch architecture. | LOW (per `architecture.md`: "No audio API changes 4.4–4.6") |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| None registered | Zero TR-IDs exist for this system in `docs/architecture/tr-registry.yaml` — matches the identical gap Sanctuary UI and Tarot Deck UI both shipped through (a larger version of Mission HUD's own TR gap). Stories will scope directly from the GDD's 7 Core Rules, matching that established precedent. | ❌ No ADR, no TR-ID |

**Untraced requirements**: all of them — this is a real, pre-existing project-wide TR-registry gap for presentation-layer systems, not specific to this epic.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/audio-system.md` are verified (6 AC Groups: Mix Bus Architecture, State-Driven Music/Ambient, One-Shot Cue Triggering, Ducking/Voice Limiting, Persistence, Pause Behavior)
- All Logic and Integration stories have passing test files in `tests/`
- AC-13 (volume persistence across a full process relaunch) has its own documented resolution — this project's normal in-process test runner cannot exercise a real process kill/relaunch; the GDD itself flags this needs either a scripted headless-relaunch harness or a documented manual playtest, not a standard automated test
- The `AudioCueMap` dispatch mechanism and bus-graph construction are live-verified via Godot MCP against the actual pinned 4.6.2 engine, not just unit-tested in isolation (per this project's own "live-verify, don't just static-analyze" discipline)
- Content-authoring (populating `AudioCueMap` with real SFX/music assets, OQ-2) is explicitly **out of scope** for this epic's Definition of Done — the GDD itself frames this as separate Full Vision-tier work, distinct from the mechanical/architectural implementation this epic covers

## Next Step

Run `/create-stories epic-12-audio-system` to break this epic into implementable stories.

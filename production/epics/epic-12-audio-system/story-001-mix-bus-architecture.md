# Story 001: Mix Bus Architecture — 4 Player-Facing Buses, Internal Sub-Routing

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-audio-???` (no TR-ID registered — scoped from GDD Core Rule 1 and AC Group 1)

**ADR Governing Implementation**: N/A — no dedicated architecture ADR exists for this system yet. Matches Sanctuary UI/Tarot Deck UI's own precedent (both shipped stories without one, scoping directly from the GDD's own Core Rules).

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Godot's `AudioServer` bus API (`add_bus`, `set_bus_send`, `set_bus_volume_db`) has had no breaking changes 4.4–4.6 (per `docs/architecture/architecture.md`'s own Audio row). Buses are typically authored in the project's `default_bus_layout.tres` resource, not constructed procedurally at runtime — this story should confirm which approach this project uses before assuming either.

**Control Manifest Rules (this layer)**:
- Required: none specific to Audio yet exist in the manifest — this story's own conventions (documented below) become the reference for later Audio stories
- Guardrail: bus volume changes must never allocate per-frame (this is a rare, player-driven action, not a hot path)

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, AC Group 1:*

- [ ] **AC-1**: GIVEN the audio system initializes, THEN exactly 4 player-adjustable buses exist (Music, SFX, Voice, UI), each independently settable 0–100%, defaulting to 80% — matching `design/accessibility-requirements.md` exactly.
- [ ] **AC-2**: GIVEN the player adjusts the Music bus volume, WHEN a Combat Impact (SFX-bus) cue plays immediately after, THEN its volume is unaffected by the Music bus change, and vice versa for any other bus pair.

---

## Implementation Notes

Per Core Rule 1: internal bus graph is `Master (internal, no player slider) → {Music, SFX, Voice, UI}`, with **Ambient** sub-mixed as a true child bus under **Music** (inherits Music's volume automatically), and the two SFX sub-categories (world-diegetic combat/environmental vs. UI-triggered confirms/denials) routed to the peer **SFX** and **UI** top-level buses respectively — there is no single "mute all SFX including UI" node, by design.

**Voice** bus is reserved and currently silent (no VO content exists or is planned at MVP/Alpha scope per OQ-6) — it must still exist and function per the accessibility commitment, even though nothing plays through it yet.

Default all 4 buses to 80% (Tuning Knobs) on first-ever initialization (no `user://audio_settings.cfg` exists yet — Story 005 owns the persistence side of this default).

---

## Out of Scope

- Story 002: state-driven Music/Ambient crossfade behavior (this story only owns bus *existence* and volume independence, not what plays through them)
- Story 003: the `AudioCueMap`/cue-dispatch mechanism that decides which bus a given cue routes to
- Story 005: loading/saving the actual volume values to `user://audio_settings.cfg` — this story can assume in-memory defaults only
- The settings UI surface itself (GDD's own OQ-1 — no host screen decided yet)

---

## QA Test Cases

- **AC-1**
  - Given: a fresh `AudioSystem` instance (or Autoload) at first initialization
  - When: its bus configuration is queried
  - Then: exactly 4 player-facing buses exist (`Music`, `SFX`, `Voice`, `UI`), each independently gettable/settable in `[0, 100]`, each defaulting to `80`
  - Edge cases: setting one bus to `0` and another to `100` in the same test, confirming no cross-contamination

- **AC-2**
  - Given: Music bus set to a non-default value (e.g. `40`)
  - When: an SFX-bus cue's effective volume is queried
  - Then: it reflects only the SFX bus's own (still-default) volume, unaffected by Music's change
  - Edge cases: repeat for every other bus pair (SFX↔UI, Music↔UI, Voice↔any) — confirm no pair leaks into another

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/mix-bus-architecture_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (foundational story for this epic)
- Unlocks: Story 002 (Music/Ambient needs real buses to route through), Story 003 (cue dispatch needs real buses as a routing target), Story 004 (ducking operates on these same buses), Story 006 (pause-duck attenuates these bus levels)

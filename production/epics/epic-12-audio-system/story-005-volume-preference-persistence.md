# Story 005: Volume Preference Persistence — Outside Save & Persistence Entirely

> **Epic**: Audio System
> **Status**: Complete (2026-07-25)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 3h
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-audio-???` (no TR-ID registered — scoped from GDD Core Rule 6 and AC Group 5)

**ADR Governing Implementation**: N/A — see Story 001's identical note. This story deliberately establishes a **new cross-system precedent** (device/session preferences living outside `SavePersistence` entirely) — worth flagging to whoever next designs Input Remapping (GDD's own OQ-4), which the GDD explicitly names as the next candidate for this same pattern.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Use Godot's `ConfigFile` class directly (`load()`/`save()` against `user://audio_settings.cfg`) — this is a standard, stable Godot 4 API, not a project-specific abstraction.

**Control Manifest Rules (this layer)**:
- Forbidden: do NOT register this system with `GSavePersistence` / do NOT implement a `SaveRestorer` interface for this data — Core Rule 6's entire point is that this is explicitly outside that system

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, AC Group 5:*

- [x] **AC-13** *(process-relaunch harness required, not a standard in-process test — flagged explicitly by the GDD itself)*: GIVEN the player sets a non-default bus volume, WHEN the game process is fully killed and relaunched, THEN the volume is restored from `user://audio_settings.cfg` on the fresh process, not reset to default. **Verified via a real scripted 2-process relaunch harness** (`tools/audio-relaunch-harness/`), not an in-process simulation and not a manual playtest — see `production/qa/evidence/story-005-ac13-relaunch-evidence.md` for the full run transcript (2026-07-25): Music set to 40% and saved by process A, which then exits entirely; a genuinely separate process B reads back `HARNESS_READ_MUSIC_VOLUME=40.000000`.
- [x] **AC-14**: GIVEN volume settings exist in `user://audio_settings.cfg`, WHEN a save slot is loaded or a fresh game is started from the main menu, THEN volume settings are unaffected by either action — confirming they are genuinely slot-independent, not silently coupled to Save & Persistence's restore cycle. Verified via `test_loading_a_save_slot_does_not_alter_bus_volume` (real `GSavePersistence.load_slot()` call), `test_sanctuary_state_restored_signal_does_not_alter_bus_volume` (the real signal Save & Persistence's own restore cycle broadcasts), `test_audio_system_is_never_registered_as_a_save_restorer` (structural proof — no `SaveRestorer` interface exists on this class at all). **Note**: this codebase has no distinct "fresh game started from the main menu" event/mechanism to test against separately from picking a mission — the same architectural guarantee (AudioSystem never registers with `GSavePersistence`, never subscribes to any slot-scoped signal) covers that trigger path identically; flagged honestly rather than fabricating a second test against a mechanism that doesn't exist yet.

---

## Implementation Notes

Volume settings (the 4 accessibility-committed sliders) are a **device/session preference**, not per-save-slot progress — they must persist identically across every save slot and be available before any save slot even exists (main menu, first boot), which `save-persistence.md`'s own `restore_order`/`sanctuary_state_restored` model (scoped entirely to slot-restore) cannot provide.

Audio owns a small, independent `ConfigFile` at `user://audio_settings.cfg` (4 floats, one per bus), loaded in `_ready()` **before any cue plays** — no `restore_order` slot, no `SaveRestorer` registration of any kind.

**Fresh-install default** (Edge Cases): if `user://audio_settings.cfg` doesn't exist yet, all 4 buses default to 80% per `accessibility-requirements.md`'s own stated default — not 100%, not muted. Story 001 already implements this in-memory default; this story adds the load-from-disk override when the file exists.

**AC-13's test harness note**: this project's normal in-process gdUnit4 test runner cannot exercise a real process kill/relaunch. Per the GDD's own explicit flag, resolve this via either (a) a scripted headless-relaunch subprocess harness (spawn a second headless Godot process, write the config, kill, relaunch, verify), or (b) a documented manual playtest recorded as evidence — do not skip this AC silently, and do not fake it with an in-process "simulate relaunch" shortcut that doesn't actually exercise `ConfigFile.load()` against a real file written by a genuinely separate process lifetime.

---

## Out of Scope

- Story 001: in-memory bus volume defaults (this story only adds real disk load/save on top of that)
- The settings UI surface itself (OQ-1) — this story is the data layer only

---

## QA Test Cases

- **AC-13**
  - Given: a non-default bus volume set (e.g. Music = 40%)
  - When: the game process is fully killed and a fresh process launched
  - Then: `user://audio_settings.cfg` is read on the new process's `_ready()`, and Music bus reads back as 40%, not the 80% default
  - Edge cases: this is the one AC in this epic requiring a relaunch harness or documented manual playtest — see Implementation Notes

- **AC-14**
  - Given: `user://audio_settings.cfg` exists with a non-default value
  - When: a save slot is loaded, THEN separately, a fresh game is started from the main menu
  - Then: in both cases, the bus volume is unchanged from what was in the config file — neither action reads, writes, or resets it
  - Edge cases: test both trigger paths (load slot, fresh game) independently, not just one

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio/volume-preference-persistence_test.gd` (AC-14, standard in-process test) + a separate documented resolution for AC-13 (either a relaunch-harness script or `production/qa/evidence/story-005-ac13-relaunch-evidence.md`)

**Status**: [x] Created and passing — 5/5 test cases, 0 errors, 0 failures, 0 orphans (`tests/integration/audio/volume-preference-persistence_test.gd`, AC-14, run 2026-07-25). AC-13 separately verified via the real relaunch harness — see `production/qa/evidence/story-005-ac13-relaunch-evidence.md`.

---

## Dependencies

- Depends on: Story 001 (real buses must exist for their volume to be meaningfully persisted)
- Unlocks: None

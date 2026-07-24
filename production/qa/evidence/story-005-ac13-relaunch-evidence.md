# Story 005 (epic-12-audio-system) — AC-13 Relaunch Evidence

> **Story**: `production/epics/epic-12-audio-system/story-005-volume-preference-persistence.md`
> **AC**: AC-13 — volume settings survive a full process kill/relaunch
> **Evidence type**: Scripted headless relaunch harness (not an in-process simulation, not a manual playtest)
> **Run date**: 2026-07-25

## Why this exists

This project's normal in-process gdUnit4 test runner cannot exercise a real process kill/relaunch — a single test process cannot prove that `AudioSystem`'s disk-load path (`_load_settings_from_disk()` in `_ready()`) actually round-trips through a genuinely separate OS process lifetime, as opposed to merely reading back a value that never left memory. Per the story's own explicit flag, this required either a scripted relaunch harness or a documented manual playtest. This is the former.

## Harness

- `tools/audio-relaunch-harness/relaunch_harness.gd` — a `SceneTree`-extending script run as the engine's main loop via `--script`, in `write` or `read` mode (selected via a command-line user arg after `--`)
- `tools/audio-relaunch-harness/run_harness.sh` — runs the harness twice as two genuinely separate `Godot.exe` processes and asserts the result

## What it proves

1. **Process A ("write")**: boots the real project, waits 5 real frames for `GAudioSystem`'s own `_ready()` to run (bus configuration + disk-load), sets `Music` to 40% via the real `AudioSystem.set_bus_volume_percent()`, calls the real `AudioSystem.save_settings_to_disk()`, then **the process exits entirely**.
2. **Process B ("read")**: a brand-new `Godot.exe` process, with its own fresh engine boot — `GAudioSystem._ready()` runs its real `_load_settings_from_disk()` path against `user://audio_settings.cfg` (the same OS-level file location process A wrote to, since `user://` resolves to a fixed per-project directory regardless of which process is running). It reads back `Music`'s volume and prints it.

## Result (2026-07-25)

```
=== Phase 1: write (process A) ===
HARNESS_WRITE_RESULT=0

=== Phase 2: read (process B, a genuinely separate process) ===
HARNESS_READ_MUSIC_VOLUME=40.000000

PASS: AC-13 verified -- Music volume survived a real process kill/relaunch.
```

`HARNESS_WRITE_RESULT=0` confirms `ConfigFile.save()` returned `OK`. `HARNESS_READ_MUSIC_VOLUME=40.000000` — read back by a process that never shared memory with process A — confirms the 40% value was not the 80% in-memory default (Story 001), proving the disk round-trip is real, not simulated.

## Re-running this evidence

```
bash tools/audio-relaunch-harness/run_harness.sh [path-to-godot-exe]
```

Defaults to this machine's pinned `Godot_v4.6.2-stable_win64.exe` path if no argument is given. Exits non-zero with a `FAIL:` message if either phase's expected output is missing.

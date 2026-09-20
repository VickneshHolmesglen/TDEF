# Music and Ambient Stems Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `MusicAmbientController` real audio playback (per-state music stems + ambient base bed + combat layer, equal-power crossfades driven by its existing transition timing) and author six synthesized placeholder stems.

**Architecture:** A new `MusicAmbientMap` resource maps six slots to `AudioStream`s. The controller gains `AudioStreamPlayer`s and per-stem `level`s that `advance_time()` slews toward targets; audible volume is `linear_to_db(sqrt(level))`. `AudioSystem` loads the map and hands it to the controller it creates. Placeholder stems come from a reproducible ffmpeg script with built-in seam/peak checks.

**Tech Stack:** Godot 4.6.2, GDScript, gdUnit4, bash + ffmpeg (`C:\ffmpeg-8.0.1-full_build\bin\ffmpeg`, `libvorbis`).

**Spec:** `docs/superpowers/specs/2026-09-20-music-ambient-stems-design.md`

## Global Constraints

- Existing `MusicAmbientController` behavior and every existing accessor are preserved; existing controller tests (which never set a map) pass UNMODIFIED.
- The controller never loads content itself; only `AudioSystem` loads the map (and only for a controller it created).
- A null map or null slot is silent, never an error.
- All players: `process_mode = Node.PROCESS_MODE_ALWAYS`; music stems on bus `Music`, ambient on bus `Ambient`. `PauseDuckController` is untouched.
- Level math lives in `advance_time()`/pure helpers only (no `Tween`, no `_process` timing) so tests stay deterministic.
- New `class_name` (`MusicAmbientMap`) requires a class-cache rebuild before tests: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --editor --path G:\TDef --quit`. After adding audio files run the same command (import), and commit the `.import` sidecars.
- The `GAudioSystem` autoload is alive in every headless test and configures the `Music`/`Ambient` buses, so `AudioStreamPlayer.bus` reads back correctly in tests.
- Editing `.tres` in shell: never `sed`/`${var//&/}` for text with `&`. No `#` comments inside `.tres`.
- `ffmpeg -i <file>` with no output exits non-zero; under `set -o pipefail` append `|| true` to any such pipeline (this bit `selftest.sh` and this plan's script).
- Test runner: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a <res:// path> --ignoreHeadlessMode`. Run only the targeted suites named here.
- Commit and push after each task's tests pass (standing user rule); after committing, verify with `git show --name-only --format= HEAD` that no unrelated files (e.g. the pre-existing modified `addons/`) were included. Messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## File Structure

- Create `src/core/audio/music_ambient_map.gd` — the six-slot resource.
- Modify `src/core/audio/music_ambient_controller.gd` — players, levels, `set_stream_map()`, accessors.
- Modify `src/core/audio/audio_system.gd` — load and apply the map.
- Create `tools/audio/synth_stems.sh` — reproducible stem generator + verification.
- Create `assets/audio/music/{contemplative,measured,urgent,measured_urgent}.ogg`, `assets/audio/ambient/{ambient_base_bed,ambient_combat_layer}.ogg` (+ `.import`), `assets/data/audio/music_ambient_map.tres`.
- Create `tests/integration/audio/music-ambient-playback_test.gd`, `tests/unit/audio/music-ambient-content_test.gd`.
- Modify `assets/audio/sfx/SOURCES.md`, `production/qa/audio-cue-listening-pass.md`, `design/gdd/audio-system.md`, `production/session-state/active.md`.

---

### Task 1: `MusicAmbientMap` + controller playback (no content yet)

**Files:**
- Create: `src/core/audio/music_ambient_map.gd`
- Modify: `src/core/audio/music_ambient_controller.gd` (constants after `AMBIENT_COMBAT_LAYER_FADE_OUT_SECONDS`; new vars after `_paused`; `advance_time()`; `force_finish_transition()`; new methods at the end)
- Test: `tests/integration/audio/music-ambient-playback_test.gd`

**Interfaces:**
- Produces: `MusicAmbientMap` (fields `contemplative`, `measured`, `urgent`, `measured_urgent`, `ambient_base_bed`, `ambient_combat_layer`: `AudioStream`); on the controller: `set_stream_map(map: MusicAmbientMap) -> void`; `get_stem_level(state) -> float`; `is_stem_playing(state) -> bool`; `get_stem_volume_db(state) -> float`; `get_stem_player(state) -> AudioStreamPlayer`; `get_ambient_combat_level() -> float`; `is_ambient_combat_playing() -> bool`; `is_ambient_base_playing() -> bool`; `get_ambient_base_player() -> AudioStreamPlayer`; `get_ambient_combat_player() -> AudioStreamPlayer`; `static level_to_volume_db(level: float) -> float`; const `AMBIENT_COMBAT_LAYER_FADE_IN_SECONDS = 1.5`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GdUnitTestSuite

## Integration tests for real playback in MusicAmbientController (music-
## ambient-stems spec §3.3/§8, AC-2..AC-12). Levels are driven only via
## advance_time()/force_finish_transition() (no real waiting). Streams are
## tiny silent AudioStreamWAV fixtures.

const S := MusicAmbientController.MusicState

var _controller: MusicAmbientController


func before_test() -> void:
	_controller = MusicAmbientController.new()
	add_child(_controller)


func after_test() -> void:
	if _controller != null and is_instance_valid(_controller):
		remove_child(_controller)
		_controller.free()
	_controller = null


func _fixture_stream() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(4410 * 2)
	wav.data = data
	return wav


func _fixture_map() -> MusicAmbientMap:
	var map := MusicAmbientMap.new()
	map.contemplative = _fixture_stream()
	map.measured = _fixture_stream()
	map.urgent = _fixture_stream()
	map.measured_urgent = _fixture_stream()
	map.ambient_base_bed = _fixture_stream()
	map.ambient_combat_layer = _fixture_stream()
	return map


func _phase(previous: String, new_phase: String) -> void:
	GEventBus.mission_phase_changed.emit(previous, new_phase, 0.0)


func test_level_to_volume_db_is_equal_power() -> void:
	assert_float(MusicAmbientController.level_to_volume_db(1.0)).is_equal_approx(0.0, 0.001)
	assert_float(MusicAmbientController.level_to_volume_db(0.5)).is_equal_approx(-3.0103, 0.01)
	assert_float(MusicAmbientController.level_to_volume_db(0.0)).is_less(-60.0)


func test_set_stream_map_starts_contemplative_and_ambient_base_only() -> void:
	_controller.set_stream_map(_fixture_map())
	assert_float(_controller.get_stem_level(S.CONTEMPLATIVE)).is_equal_approx(1.0, 0.0001)
	assert_bool(_controller.is_stem_playing(S.CONTEMPLATIVE)).is_true()
	for state: int in [S.MEASURED, S.URGENT, S.MEASURED_URGENT]:
		assert_bool(_controller.is_stem_playing(state)).is_false()
		assert_float(_controller.get_stem_level(state)).is_equal_approx(0.0, 0.0001)
	assert_bool(_controller.is_ambient_base_playing()).is_true()
	assert_bool(_controller.is_ambient_combat_playing()).is_false()


func test_scout_crossfade_is_equal_power_and_completes() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SANCTUARY", "SCOUT")
	_controller.advance_time(0.5)
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(0.5, 0.001)
	assert_float(_controller.get_stem_level(S.CONTEMPLATIVE)).is_equal_approx(0.5, 0.001)
	assert_float(_controller.get_stem_volume_db(S.MEASURED)).is_equal_approx(-3.0103, 0.05)
	_controller.advance_time(0.5)
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(1.0, 0.001)
	assert_float(_controller.get_stem_level(S.CONTEMPLATIVE)).is_equal_approx(0.0, 0.001)
	assert_bool(_controller.is_stem_playing(S.CONTEMPLATIVE)).is_false()


func test_countdown_anticipatory_crossfade_lands_exactly_at_countdown_end() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SANCTUARY", "SCOUT")
	_controller.force_finish_transition()
	GEventBus.wave_countdown_warning.emit(10)
	_controller.advance_time(5.0)
	assert_float(_controller.get_stem_level(S.URGENT)).is_equal_approx(0.5, 0.001)
	_controller.advance_time(5.0)
	assert_float(_controller.get_stem_level(S.URGENT)).is_equal_approx(1.0, 0.001)
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(0.0, 0.001)


func test_wave_clear_hard_duck_takes_urgent_to_measured_urgent_in_point_four_seconds() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SCOUT", "WAVE_ACTIVE")
	_controller.force_finish_transition()
	_phase("WAVE_ACTIVE", "INTERMISSION")
	_controller.advance_time(0.4)
	assert_float(_controller.get_stem_level(S.URGENT)).is_equal_approx(0.0, 0.001)
	assert_float(_controller.get_stem_level(S.MEASURED_URGENT)).is_equal_approx(1.0, 0.001)


func test_interrupted_crossfade_retargets_smoothly_without_jumps() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SANCTUARY", "SCOUT")
	_controller.advance_time(0.4)
	var measured_before: float = _controller.get_stem_level(S.MEASURED)
	var contemplative_before: float = _controller.get_stem_level(S.CONTEMPLATIVE)
	_phase("SCOUT", "WAVE_ACTIVE")
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(measured_before, 0.0001)
	assert_float(_controller.get_stem_level(S.CONTEMPLATIVE)).is_equal_approx(contemplative_before, 0.0001)
	for i: int in range(20):
		_controller.advance_time(0.1)
		for state: int in [S.CONTEMPLATIVE, S.MEASURED, S.URGENT, S.MEASURED_URGENT]:
			assert_float(_controller.get_stem_level(state)).is_between(0.0, 1.0)
	assert_float(_controller.get_stem_level(S.URGENT)).is_equal_approx(1.0, 0.001)


func test_freeze_holds_levels_and_resume_continues_from_the_same_point() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SANCTUARY", "SCOUT")
	_controller.advance_time(0.3)
	var held: float = _controller.get_stem_level(S.MEASURED)
	_controller.freeze_transition()
	_controller.advance_time(5.0)
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(held, 0.0001)
	_controller.resume_transition()
	_controller.advance_time(0.7)
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(1.0, 0.001)


func test_force_finish_transition_snaps_levels_and_stops_zero_level_players() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SANCTUARY", "SCOUT")
	_controller.force_finish_transition()
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(1.0, 0.0001)
	assert_float(_controller.get_stem_level(S.CONTEMPLATIVE)).is_equal_approx(0.0, 0.0001)
	assert_bool(_controller.is_stem_playing(S.CONTEMPLATIVE)).is_false()
	assert_bool(_controller.is_stem_playing(S.MEASURED)).is_true()


func test_ambient_base_bed_starts_once_and_never_restarts() -> void:
	var map: MusicAmbientMap = _fixture_map()
	_controller.set_stream_map(map)
	var base: AudioStreamPlayer = _controller.get_ambient_base_player()
	_phase("SANCTUARY", "SCOUT")
	_phase("SCOUT", "WAVE_ACTIVE")
	_phase("WAVE_ACTIVE", "INTERMISSION")
	_controller.set_stream_map(map)
	assert_int(_controller.get_ambient_base_bed_start_count()).is_equal(1)
	assert_object(_controller.get_ambient_base_player()).is_same(base)
	assert_bool(_controller.is_ambient_base_playing()).is_true()


func test_combat_layer_fades_in_over_one_and_a_half_seconds_and_out_over_two() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SCOUT", "WAVE_ACTIVE")
	_controller.advance_time(0.75)
	assert_float(_controller.get_ambient_combat_level()).is_equal_approx(0.5, 0.001)
	assert_bool(_controller.is_ambient_combat_playing()).is_true()
	_controller.advance_time(0.75)
	assert_float(_controller.get_ambient_combat_level()).is_equal_approx(1.0, 0.001)
	_phase("WAVE_ACTIVE", "INTERMISSION")
	_controller.advance_time(1.0)
	assert_float(_controller.get_ambient_combat_level()).is_equal_approx(0.5, 0.001)
	_controller.advance_time(1.0)
	assert_float(_controller.get_ambient_combat_level()).is_equal_approx(0.0, 0.001)
	assert_bool(_controller.is_ambient_combat_playing()).is_false()


func test_null_map_and_null_slots_are_silent_and_error_free() -> void:
	_controller.set_stream_map(null)
	for state: int in [S.CONTEMPLATIVE, S.MEASURED, S.URGENT, S.MEASURED_URGENT]:
		assert_bool(_controller.is_stem_playing(state)).is_false()
		assert_float(_controller.get_stem_level(state)).is_equal_approx(0.0, 0.0001)
	assert_bool(_controller.is_ambient_base_playing()).is_false()
	var partial := MusicAmbientMap.new()
	partial.contemplative = _fixture_stream()
	_controller.set_stream_map(partial)
	assert_bool(_controller.is_stem_playing(S.CONTEMPLATIVE)).is_true()
	assert_object(_controller.get_stem_player(S.URGENT)).is_null()
	_phase("SANCTUARY", "SCOUT")
	_controller.advance_time(2.0)
	assert_bool(_controller.is_stem_playing(S.MEASURED)).is_false()


func test_players_are_pause_proof_and_on_the_right_buses() -> void:
	_controller.set_stream_map(_fixture_map())
	for state: int in [S.CONTEMPLATIVE, S.MEASURED, S.URGENT, S.MEASURED_URGENT]:
		var player: AudioStreamPlayer = _controller.get_stem_player(state)
		assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
		assert_str(String(player.bus)).is_equal("Music")
	for player: AudioStreamPlayer in [_controller.get_ambient_base_player(), _controller.get_ambient_combat_player()]:
		assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
		assert_str(String(player.bus)).is_equal("Ambient")


func test_streams_are_made_loopable() -> void:
	var map: MusicAmbientMap = _fixture_map()
	_controller.set_stream_map(map)
	var wav: AudioStreamWAV = map.contemplative as AudioStreamWAV
	assert_int(wav.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(wav.loop_end).is_equal(4410)
```

- [ ] **Step 2: Rebuild class cache (after Step 3's new class file exists), run the test, confirm it fails first**

First create only the empty-shell file below so the class exists, rebuild the cache, run the suite, and confirm the failures are all "method not found" (`set_stream_map` etc.) before implementing the controller. Run `res://tests/integration/audio/music-ambient-playback_test.gd`. Expected: FAIL.

- [ ] **Step 3: Implement**

`src/core/audio/music_ambient_map.gd`:

```gdscript
class_name MusicAmbientMap
extends Resource

## Maps each Music Energy state and the two ambient layers to an
## AudioStream (music-ambient-stems spec §3.1). A null slot means "no stream
## for this slot": that slot is silent, never an error. Content file:
## assets/data/audio/music_ambient_map.tres. Loaded by AudioSystem, never by
## MusicAmbientController itself.

@export var contemplative: AudioStream = null
@export var measured: AudioStream = null
@export var urgent: AudioStream = null
@export var measured_urgent: AudioStream = null
@export var ambient_base_bed: AudioStream = null
@export var ambient_combat_layer: AudioStream = null
```

`music_ambient_controller.gd` — after `AMBIENT_COMBAT_LAYER_FADE_OUT_SECONDS` add:

```gdscript

## Music-ambient-stems spec §3.3/§4.
const AMBIENT_COMBAT_LAYER_FADE_IN_SECONDS: float = 1.5
const MUSIC_BUS: StringName = &"Music"
const AMBIENT_BUS: StringName = &"Ambient"
## Floor for level_to_volume_db() so a zero level maps to a very quiet finite dB (about -80 dB), not -inf.
const MIN_AUDIBLE_LEVEL: float = 0.00000001
```

After the `var _paused: bool = false` line add:

```gdscript

## Real playback state (music-ambient-stems spec §3.3). Keyed by MusicState
## int. A stem with no stream has no entry (silent).
var _stem_players: Dictionary[int, AudioStreamPlayer] = {}
var _stem_levels: Dictionary[int, float] = {}
var _ambient_base_player: AudioStreamPlayer = null
var _ambient_combat_player: AudioStreamPlayer = null
var _ambient_combat_level: float = 0.0
```

In `advance_time()`, after the existing `if _ambient_combat_layer_fading_out:` block (still inside the function, after the `_paused` early return), add:

```gdscript

	_step_levels(delta)
```

In `force_finish_transition()`, after its existing body, add:

```gdscript
	_snap_stem_levels_to_targets()
```

Append at the end of the file:

```gdscript


# ---------------------------------------------------------------------------
# Real playback (music-ambient-stems spec §3.3). Everything below is inert
# until set_stream_map() is called with a non-null map.
# ---------------------------------------------------------------------------

## Equal-power volume for a level in [0, 1]: linear levels that sum to 1
## across a crossfade keep total power constant.
static func level_to_volume_db(level: float) -> float:
	return linear_to_db(sqrt(maxf(level, MIN_AUDIBLE_LEVEL)))


## Assigns (or clears) every stream slot from `map`. Idempotent: existing
## players are reused, and the ambient base bed is never restarted unless
## its stream actually changed. A null map or null slot leaves that slot silent.
func set_stream_map(map: MusicAmbientMap) -> void:
	_assign_stem(MusicState.CONTEMPLATIVE, map.contemplative if map != null else null)
	_assign_stem(MusicState.MEASURED, map.measured if map != null else null)
	_assign_stem(MusicState.URGENT, map.urgent if map != null else null)
	_assign_stem(MusicState.MEASURED_URGENT, map.measured_urgent if map != null else null)
	_ambient_base_player = _assign_ambient(_ambient_base_player, map.ambient_base_bed if map != null else null)
	_ambient_combat_player = _assign_ambient(_ambient_combat_player, map.ambient_combat_layer if map != null else null)
	if _ambient_base_player != null and not _ambient_base_player.playing:
		_ambient_base_player.play()
	_apply_combat_player()


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


## Makes `stream` loop at runtime, so no per-file .import loop settings are relied on.
static func _make_loopable(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		if wav.format == AudioStreamWAV.FORMAT_8_BITS or wav.format == AudioStreamWAV.FORMAT_16_BITS:
			var bytes_per_frame: int = (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = wav.data.size() / bytes_per_frame


func _assign_stem(state: int, stream: AudioStream) -> void:
	if stream == null:
		if _stem_players.has(state):
			_stem_players[state].queue_free()
			_stem_players.erase(state)
			_stem_levels.erase(state)
		return
	_make_loopable(stream)
	var player: AudioStreamPlayer = _stem_players.get(state)
	if player == null:
		player = _make_player(MUSIC_BUS)
		_stem_players[state] = player
	if player.stream != stream:
		player.stream = stream
		player.stop()
	_stem_levels[state] = 1.0 if state == _music_state else 0.0
	_apply_stem_player(state)


func _assign_ambient(player: AudioStreamPlayer, stream: AudioStream) -> AudioStreamPlayer:
	if stream == null:
		if player != null:
			player.queue_free()
		return null
	_make_loopable(stream)
	if player == null:
		player = _make_player(AMBIENT_BUS)
	if player.stream != stream:
		player.stream = stream
		player.stop()
	return player


func _apply_stem_player(state: int) -> void:
	var player: AudioStreamPlayer = _stem_players[state]
	var level: float = _stem_levels[state]
	if level > 0.0:
		player.volume_db = level_to_volume_db(level)
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()


func _apply_combat_player() -> void:
	if _ambient_combat_player == null:
		return
	if _ambient_combat_level > 0.0:
		_ambient_combat_player.volume_db = level_to_volume_db(_ambient_combat_level)
		if not _ambient_combat_player.playing:
			_ambient_combat_player.play()
	elif _ambient_combat_player.playing:
		_ambient_combat_player.stop()


## Slews every stem level toward its target (1.0 for the current state's
## stem, 0.0 for the rest) at 1/duration per second, reusing the existing
## transition duration verbatim; ramps the ambient combat layer up over
## AMBIENT_COMBAT_LAYER_FADE_IN_SECONDS and down over the existing fade-out.
## A transition interrupted mid-fade simply retargets from the current levels.
func _step_levels(delta: float) -> void:
	var step: float = delta / maxf(_last_transition_duration, 0.01)
	for state: int in _stem_players:
		var target: float = 1.0 if state == _music_state else 0.0
		_stem_levels[state] = move_toward(_stem_levels[state], target, step)
		_apply_stem_player(state)
	if _ambient_combat_player != null:
		var rising: bool = _ambient_combat_layer_active and not _ambient_combat_layer_fading_out
		if rising:
			_ambient_combat_level = move_toward(_ambient_combat_level, 1.0, delta / AMBIENT_COMBAT_LAYER_FADE_IN_SECONDS)
		else:
			_ambient_combat_level = move_toward(_ambient_combat_level, 0.0, delta / AMBIENT_COMBAT_LAYER_FADE_OUT_SECONDS)
		_apply_combat_player()


func _snap_stem_levels_to_targets() -> void:
	for state: int in _stem_players:
		_stem_levels[state] = 1.0 if state == _music_state else 0.0
		_apply_stem_player(state)


## Test/inspection accessors (music-ambient-stems spec §3.7).
func get_stem_level(state: int) -> float:
	return _stem_levels.get(state, 0.0)


func is_stem_playing(state: int) -> bool:
	var player: AudioStreamPlayer = _stem_players.get(state)
	return player != null and player.playing


func get_stem_volume_db(state: int) -> float:
	var player: AudioStreamPlayer = _stem_players.get(state)
	return player.volume_db if player != null else -80.0


func get_stem_player(state: int) -> AudioStreamPlayer:
	return _stem_players.get(state)


func get_ambient_combat_level() -> float:
	return _ambient_combat_level


func is_ambient_combat_playing() -> bool:
	return _ambient_combat_player != null and _ambient_combat_player.playing


func is_ambient_base_playing() -> bool:
	return _ambient_base_player != null and _ambient_base_player.playing


func get_ambient_base_player() -> AudioStreamPlayer:
	return _ambient_base_player


func get_ambient_combat_player() -> AudioStreamPlayer:
	return _ambient_combat_player
```

Note on typing: the tests pass `S.MEASURED` (a `MusicState` enum value) to accessors typed `int`; that is fine in GDScript. If a `get_stem_player()` typed-return of `null` complains, change its return type to `AudioStreamPlayer` with an explicit `return null` branch as above.

- [ ] **Step 4: Run tests**

Rebuild the class cache (the new `class_name`), then run: `res://tests/integration/audio/music-ambient-playback_test.gd`, `res://tests/integration/audio/state-driven-music-and-ambient_test.gd`, `res://tests/integration/audio/pause-behavior_test.gd`, `res://tests/unit/audio`. Expected: all PASS, existing tests unmodified. If `is_stem_playing()` is false in the headless dummy audio driver right after `play()`, print `player.playing` and `player.stream_paused` and investigate before adjusting any assertion (the fixture streams loop, so they must keep playing).

- [ ] **Step 5: Commit and push**

```bash
git add src/core/audio/music_ambient_map.gd src/core/audio/music_ambient_map.gd.uid src/core/audio/music_ambient_controller.gd tests/integration/audio/music-ambient-playback_test.gd tests/integration/audio/music-ambient-playback_test.gd.uid
git commit -m "Add real playback to MusicAmbientController (levels, equal-power crossfades)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
git show --name-only --format= HEAD
```
(Drop any `.uid` path from `git add` that does not exist, since one missing pathspec aborts the whole add; confirm with the `git show` line.)

---

### Task 2: Synthesize the stems, wire the map, content test, docs

**Files:**
- Create: `tools/audio/synth_stems.sh`, `assets/audio/music/*.ogg`, `assets/audio/ambient/*.ogg` (+ `.import`), `assets/data/audio/music_ambient_map.tres`, `tests/unit/audio/music-ambient-content_test.gd`
- Modify: `src/core/audio/audio_system.gd`, `assets/audio/sfx/SOURCES.md`, `production/qa/audio-cue-listening-pass.md`, `design/gdd/audio-system.md`, `production/session-state/active.md`

- [ ] **Step 1: Write the failing content test**

```gdscript
extends GdUnitTestSuite

## Content-integrity tests for the placeholder music/ambient stems and their
## wiring (music-ambient-stems spec §8: AC-1, AC-13/14 provenance, AudioSystem wiring).

const MAP_PATH: String = "res://assets/data/audio/music_ambient_map.tres"
const SOURCES_PATH: String = "res://assets/audio/sfx/SOURCES.md"
const STEM_FIELDS: Array[StringName] = [
	&"contemplative", &"measured", &"urgent", &"measured_urgent",
	&"ambient_base_bed", &"ambient_combat_layer",
]


func test_real_map_has_all_six_slots_filled_with_loopable_length_streams() -> void:
	var map: MusicAmbientMap = load(MAP_PATH) as MusicAmbientMap
	assert_object(map).is_not_null()
	for field: StringName in STEM_FIELDS:
		var stream: AudioStream = map.get(field) as AudioStream
		assert_object(stream).override_failure_message("%s is null" % field).is_not_null()
		assert_bool(stream is AudioStreamOggVorbis).override_failure_message("%s is not Ogg Vorbis" % field).is_true()
		assert_float(stream.get_length()).override_failure_message("%s is under 8 s" % field).is_greater_equal(8.0)


func test_sources_log_records_every_stem_as_synthesized() -> void:
	var sources: String = FileAccess.get_file_as_string(SOURCES_PATH)
	for field: StringName in STEM_FIELDS:
		assert_str(sources).override_failure_message("%s not in SOURCES.md" % field).contains(String(field))
	assert_str(sources).contains("synthesized")


func test_audio_system_applies_the_real_map_to_the_controller_it_creates() -> void:
	var audio: AudioSystem = AudioSystem.new()
	add_child(audio)
	assert_bool(audio.music_ambient.is_stem_playing(MusicAmbientController.MusicState.CONTEMPLATIVE)).is_true()
	assert_bool(audio.music_ambient.is_ambient_base_playing()).is_true()
	remove_child(audio)
	audio.free()
```

- [ ] **Step 2: Run it to verify it fails**

Run `res://tests/unit/audio/music-ambient-content_test.gd`. Expected: FAIL (map file missing).

- [ ] **Step 3: Write and run the stem generator**

Create `tools/audio/synth_stems.sh` with exactly this content, then `chmod +x tools/audio/synth_stems.sh` and run `bash tools/audio/synth_stems.sh` from `G:\TDef`:

```bash
#!/usr/bin/env bash
# Synthesize the six placeholder music/ambient stems (music-ambient-stems spec
# section 3.4) and verify each loop seam and peak level. Pure ffmpeg, no
# third-party audio. Output: Ogg Vorbis (libvorbis q5), 48 kHz stereo.
#
# Loop seams:
#  - Tonal stems: every partial/LFO frequency is a multiple of 1/16 Hz, so a
#    16 s window holds a whole number of cycles. Sources are synthesized for 32 s
#    and the SETTLED middle window [8 s, 24 s) is cut, so filter start-up
#    transients never reach the loop point.
#  - Noise stems: synthesized 12 s, then the last 1 s is crossfaded onto the
#    first 1 s (result 11 s), which makes the wrap continuous.
set -euo pipefail
cd "$(dirname "$0")/../.."
FFMPEG="${FFMPEG:-/c/ffmpeg-8.0.1-full_build/bin/ffmpeg}"
MUSIC_DIR="${MUSIC_DIR:-assets/audio/music}"
AMBIENT_DIR="${AMBIENT_DIR:-assets/audio/ambient}"
SEAM_MAX="${SEAM_MAX:-150}"          # max wrap-around sample jump (16-bit), about -47 dBFS; a real click is in the thousands
PEAK_MAX_DB="${PEAK_MAX_DB:--6}"     # every stem's peak must stay at or below this
mkdir -p "$MUSIC_DIR" "$AMBIENT_DIR"

enc() { "$FFMPEG" -hide_banner -loglevel error -y "$@" -c:a libvorbis -q:a 5; }
sin() { printf -- '-f lavfi -i sine=f=%s:d=32:r=48000 ' "$1"; }   # 32 s tone source
TAIL="atrim=start=8:end=24,asetpts=PTS-STARTPTS,aformat=channel_layouts=stereo"

# --- tonal music stems (16 s loops) ---------------------------------------
# contemplative: warm detuned A-minor pad, slow swell
enc $(sin 110) $(sin 110.25) $(sin 165) $(sin 165.25) $(sin 220) $(sin 220.25) \
  -filter_complex "[0][1][2][3][4][5]amix=inputs=6:normalize=0,tremolo=f=0.125:d=0.3,lowpass=f=800,volume=0.18,$TAIL[o]" \
  -map "[o]" "$MUSIC_DIR/contemplative.ogg"

# measured: expectant slow pulse (1 Hz gate) over a pad
enc $(sin 98) $(sin 147) $(sin 196) $(sin 294) \
  -filter_complex "[0][1][2]amix=inputs=3:normalize=0,tremolo=f=0.125:d=0.25[pad];[3]tremolo=f=1:d=0.9,volume=0.5[pulse];[pad][pulse]amix=inputs=2:normalize=0,lowpass=f=1000,volume=0.2,$TAIL[o]" \
  -map "[o]" "$MUSIC_DIR/measured.ogg"

# urgent: driving rhythm (2 Hz low gate + 4 Hz higher gate)
enc $(sin 55) $(sin 110) $(sin 220) $(sin 329) \
  -filter_complex "[0][1]amix=inputs=2:normalize=0,tremolo=f=2:d=1[kick];[2][3]amix=inputs=2:normalize=0,tremolo=f=4:d=0.9,volume=0.5[hat];[kick][hat]amix=inputs=2:normalize=0,lowpass=f=1800,volume=0.22,$TAIL[o]" \
  -map "[o]" "$MUSIC_DIR/urgent.ogg"

# measured_urgent: tense but calm minor pad with a slow gated tone
enc $(sin 110) $(sin 130.8125) $(sin 155.5625) $(sin 164.8125) $(sin 220) \
  -filter_complex "[0][1][2][3]amix=inputs=4:normalize=0,tremolo=f=0.125:d=0.35[pad];[4]tremolo=f=1:d=0.8,volume=0.4[pulse];[pad][pulse]amix=inputs=2:normalize=0,lowpass=f=700,volume=0.2,$TAIL[o]" \
  -map "[o]" "$MUSIC_DIR/measured_urgent.ogg"

# --- noise ambient stems (11 s loops via a 1 s end-onto-start crossfade) ---
noise_stem() {  # $1=out file, $2=noise sources, $3=filter graph producing [x]
  enc $2 \
    -filter_complex "$3;[x]asplit=3[h][t][m];[h]atrim=0:1,asetpts=PTS-STARTPTS[head];[t]atrim=start=11:end=12,asetpts=PTS-STARTPTS[tail];[m]atrim=start=1:end=11,asetpts=PTS-STARTPTS[mid];[tail][head]acrossfade=d=1[blend];[blend][mid]concat=n=2:v=0:a=1,aformat=channel_layouts=stereo[o]" \
    -map "[o]" "$1"
}
# ambient_base_bed: quiet low room tone plus a faint slow band
noise_stem "$AMBIENT_DIR/ambient_base_bed.ogg" \
  "-f lavfi -i anoisesrc=d=12:c=pink:r=48000:a=0.5:seed=7 -f lavfi -i anoisesrc=d=12:c=brown:r=48000:a=0.5:seed=11" \
  "[0]lowpass=f=400,volume=0.15[a];[1]bandpass=f=250:width_type=h:w=120,volume=0.1[b];[a][b]amix=inputs=2:normalize=0[x]"
# ambient_combat_layer: rough clash bed (3 Hz gated mid band) over a low rumble
noise_stem "$AMBIENT_DIR/ambient_combat_layer.ogg" \
  "-f lavfi -i anoisesrc=d=12:c=white:r=48000:a=0.5:seed=3 -f lavfi -i anoisesrc=d=12:c=brown:r=48000:a=0.5:seed=5" \
  "[0]bandpass=f=1500:width_type=h:w=2000,tremolo=f=3:d=0.6,volume=0.12[a];[1]lowpass=f=120,volume=0.3[b];[a][b]amix=inputs=2:normalize=0[x]"

# --- verification ------------------------------------------------------------
fail=0
seam_jump() {  # prints the wrap-around |last - first| sample jump of a stem
  "$FFMPEG" -hide_banner -loglevel error -y -i "$1" -f s16le -ac 1 -ar 48000 - \
    | od -An -v -t d2 -w2 | awk 'NR==1{first=$1} {prev=$1} END{w=first-prev; if(w<0)w=-w; print w}'
}
peak_db() {
  "$FFMPEG" -hide_banner -nostats -i "$1" -af volumedetect -f null - 2>&1 \
    | sed -n 's/.*max_volume: \(-\?[0-9.]*\) dB.*/\1/p' | tail -1
}
for f in "$MUSIC_DIR"/{contemplative,measured,urgent,measured_urgent}.ogg "$AMBIENT_DIR"/{ambient_base_bed,ambient_combat_layer}.ogg; do
  jump=$(seam_jump "$f"); peak=$(peak_db "$f")
  dur=$("$FFMPEG" -hide_banner -i "$f" 2>&1 | sed -n 's/.*Duration: [0-9]*:[0-9]*:\([0-9.]*\).*/\1/p' | head -1 || true)
  ok=$(awk -v j="$jump" -v s="$SEAM_MAX" -v p="$peak" -v m="$PEAK_MAX_DB" 'BEGIN{print (j<=s && p<=m) ? "OK" : "FAIL"}')
  printf "%-28s dur=%ss seam_jump=%s peak=%sdB %s\n" "$(basename "$f")" "$dur" "$jump" "$peak" "$ok"
  [ "$ok" = "OK" ] || fail=1
done
[ "$fail" = 0 ] && echo "synth_stems: all 6 stems OK" || { echo "synth_stems: FAILED"; exit 1; }
```

Expected output (prototype-verified): every stem line ends `OK`, durations 16.00 s (four music stems) and 11.00 s (two ambient beds), peaks between about -20 dB and -30 dB, and the final line `synth_stems: all 6 stems OK`. If a stem reports `FAIL`, do NOT loosen `SEAM_MAX`: a real click measures in the thousands (an unsettled filter start-up measured 910), so investigate the stem's seam construction first.

- [ ] **Step 4: Author the map, wire `AudioSystem`, import**

`assets/data/audio/music_ambient_map.tres`:

```
[gd_resource type="Resource" script_class="MusicAmbientMap" load_steps=8 format=3]

[ext_resource type="Script" path="res://src/core/audio/music_ambient_map.gd" id="1"]
[ext_resource type="AudioStream" path="res://assets/audio/music/contemplative.ogg" id="2"]
[ext_resource type="AudioStream" path="res://assets/audio/music/measured.ogg" id="3"]
[ext_resource type="AudioStream" path="res://assets/audio/music/urgent.ogg" id="4"]
[ext_resource type="AudioStream" path="res://assets/audio/music/measured_urgent.ogg" id="5"]
[ext_resource type="AudioStream" path="res://assets/audio/ambient/ambient_base_bed.ogg" id="6"]
[ext_resource type="AudioStream" path="res://assets/audio/ambient/ambient_combat_layer.ogg" id="7"]

[resource]
script = ExtResource("1")
contemplative = ExtResource("2")
measured = ExtResource("3")
urgent = ExtResource("4")
measured_urgent = ExtResource("5")
ambient_base_bed = ExtResource("6")
ambient_combat_layer = ExtResource("7")
```

`src/core/audio/audio_system.gd`: add a const near the other consts (`AUDIO_SETTINGS_PATH`):

```gdscript

## Music/ambient stem map (music-ambient-stems spec §3.2). Loaded here, not
## by MusicAmbientController, so controller tests stay content-free. Missing
## file = silent, as before.
const MUSIC_AMBIENT_MAP_PATH: String = "res://assets/data/audio/music_ambient_map.tres"
```

In `_ready()`, replace the `music_ambient` block with:

```gdscript
	var created_music_ambient: bool = false
	if music_ambient == null:
		music_ambient = MusicAmbientController.new()
		music_ambient.name = &"MusicAmbientController"
		created_music_ambient = true
	if music_ambient.get_parent() == null:
		add_child(music_ambient)
	if created_music_ambient and ResourceLoader.exists(MUSIC_AMBIENT_MAP_PATH):
		music_ambient.set_stream_map(load(MUSIC_AMBIENT_MAP_PATH) as MusicAmbientMap)
```

Then import the new audio: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --editor --path G:\TDef --quit`.

- [ ] **Step 5: Provenance, listening-pass section, GDD note**

Append to `assets/audio/sfx/SOURCES.md` (six rows; there is no third-party material to license):

```markdown
| contemplative (music stem) | synthesized | tools/audio/synth_stems.sh | n/a (generated, no third-party material) | - | 16 s loop: detuned A-minor sine pad, 0.125 Hz swell, low-passed 800 Hz; PLACEHOLDER |
| measured (music stem) | synthesized | tools/audio/synth_stems.sh | n/a (generated) | - | 16 s loop: pad plus 1 Hz gated tone; PLACEHOLDER |
| urgent (music stem) | synthesized | tools/audio/synth_stems.sh | n/a (generated) | - | 16 s loop: 2 Hz and 4 Hz gated low/high tones; PLACEHOLDER |
| measured_urgent (music stem) | synthesized | tools/audio/synth_stems.sh | n/a (generated) | - | 16 s loop: tense minor pad plus 1 Hz gated tone; PLACEHOLDER |
| ambient_base_bed | synthesized | tools/audio/synth_stems.sh | n/a (generated) | - | 11 s loop (1 s crossfade seam): low pink-noise room tone plus faint band; PLACEHOLDER |
| ambient_combat_layer | synthesized | tools/audio/synth_stems.sh | n/a (generated) | - | 11 s loop (1 s crossfade seam): 3 Hz gated mid noise over a rumble; PLACEHOLDER |
```

Append to `production/qa/audio-cue-listening-pass.md`:

```markdown

## Music and ambient stems (added 2026-09-20; ALL are synthesized placeholders)

Confirm in the running game: each stem is audible and fits its state; crossfades
(Sanctuary -> Scout -> Wave) feel smooth and the countdown crossfade lands with the
first wave spawn; the wave-clear duck feels like "a held breath released"; the ambient
base bed sits under everything; the combat layer swells in with the wave and recedes
after; no loop click is audible on any stem; pausing ducks (not stops) music and ambient.

| Stem | Audible | Fits its state | No loop click | Notes |
|---|---|---|---|---|
| contemplative | | | | |
| measured | | | | |
| urgent | | | | |
| measured_urgent | | | | |
| ambient_base_bed | | | | |
| ambient_combat_layer | | | | |
```

In `design/gdd/audio-system.md`, append one sentence to the OQ-2 row (same awk-on-the-row technique used for the 2026-09-20 cue update; do not use `sed` with `&`): "**2026-09-20 (music/ambient):** the four Music Energy stems, the ambient base bed and the ambient combat layer now have real playback and synthesized PLACEHOLDER content (see `docs/superpowers/specs/2026-09-20-music-ambient-stems-design.md`); real music, the sanctuary/scout/smoke ambient layers, and adaptive layering remain."

- [ ] **Step 6: Run tests**

Run: `res://tests/unit/audio/music-ambient-content_test.gd`, `res://tests/integration/audio/music-ambient-playback_test.gd`, `res://tests/unit/audio`, `res://tests/integration/audio`, `res://tests/integration/building_upgrade/purchasable_notification_test.gd`, `res://tests/integration/main-menu/main_menu_test.gd`.
Expected: all PASS. The `GAudioSystem` autoload now loads real stems in every headless run; if any unrelated suite starts failing, investigate whether it depended on the controller having no players before changing anything.

- [ ] **Step 7: Session state, commit, push**

Append an "Music and Ambient stems shipped" extract to `production/session-state/active.md` (playback design: levels slew via `advance_time()`, equal-power `sqrt` volume, players PROCESS_MODE_ALWAYS on Music/Ambient buses; the six placeholder stems are synthesized by `tools/audio/synth_stems.sh` with seam/peak checks; NOT listened to; the `ffmpeg -i` + pipefail gotcha struck again; real music, the other ambient layers, and adaptive layering remain).

```bash
git add tools/audio/synth_stems.sh assets/audio/music assets/audio/ambient assets/data/audio/music_ambient_map.tres src/core/audio/audio_system.gd tests/unit/audio/music-ambient-content_test.gd assets/audio/sfx/SOURCES.md production/qa/audio-cue-listening-pass.md design/gdd/audio-system.md production/session-state/active.md
git commit -m "Author synthesized music/ambient stems and wire the stream map

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
git show --name-only --format= HEAD
```
(Include any generated `.uid` files for new scripts; verify no unrelated files are in the commit.)

---

## Self-Review

- **Spec coverage:** §3.1 map -> Task 1 (`MusicAmbientMap`) + Task 2 (`.tres`); §3.2 wiring -> Task 2 Step 4 (`created_music_ambient` guard keeps injected controllers unchanged); §3.3 players/levels/looping/start-stop/base bed/combat layer/freeze -> Task 1 code; §3.4 stems + seams -> Task 2 script (constants match the spec table; seams and peaks verified in-script); §3.5/§3.6 -> no work needed (verified); §3.7 accessors -> Task 1; §4 formulas -> `_step_levels`/`level_to_volume_db`; §5 edge cases -> `test_null_map_and_null_slots...`, interrupted-fade, freeze, force-finish tests; AC-1 -> content test; AC-2..AC-12 -> `music-ambient-playback_test.gd` (AC-2 start state, AC-3 equal-power crossfade, AC-4 countdown, AC-5 duck, AC-6 interruption, AC-7 freeze, AC-8 force-finish, AC-9 base bed, AC-10 combat layer, AC-11 null/existing tests, AC-12 process mode + buses); AC-13 -> script self-checks; AC-14 -> SOURCES.md test + script; AC-15 -> Task 1 Step 4 and Task 2 Step 6 regression runs; AC-16 -> listening-pass section (manual by design).
- **Placeholders:** none. The two conditional notes (headless `playing` behavior; typed-return of `get_stem_player`) give concrete diagnosis steps rather than deferring content.
- **Type/name consistency:** `set_stream_map`, `get_stem_level`, `is_stem_playing`, `get_stem_volume_db`, `get_stem_player`, `get_ambient_combat_level`, `is_ambient_combat_playing`, `is_ambient_base_playing`, `get_ambient_base_player`, `get_ambient_combat_player`, `level_to_volume_db` are identical across the interface list, implementation, and tests; `MusicAmbientMap` field names match the `.tres` and the content test's `STEM_FIELDS`; stem filenames match the script, `.tres`, and SOURCES rows.

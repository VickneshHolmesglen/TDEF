# Audio Cue List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the 16 remaining wired audio events real, licensed, sourced sounds mapped through `AudioCueMap`, in three independently shippable priority tiers.

**Architecture:** Zero game-code changes. Tooling (`tools/audio/*.sh`, ffmpeg-based) converts raw CC0 files into normalized `.wav`s and generates `AudioCueEntry` `.tres` files plus the `audio_cue_map.tres` entry. A gdUnit4 content test locks the spec table, with a `SHIPPED_TIERS` constant so each tier lands independently.

**Tech Stack:** Godot 4.6.2, gdUnit4, bash + ffmpeg (`C:\ffmpeg-8.0.1-full_build\bin\ffmpeg`), CC0 audio packs.

**Spec:** `docs/superpowers/specs/2026-09-20-audio-cue-list-design.md`

## Global Constraints

- Sources are CC0 by default (Kenney.nl, Freesound.org CC0, itch.io CC0 packs). CC-BY only if its attribution is added to `assets/audio/sfx/LICENSE.txt` in the same commit. Every pack's license is verified on its own page before use; unclear license means do not use. No AI-generated or ripped audio.
- Format: `.wav`, 44.1 kHz, 16-bit; mono for `spatial = true` cues, stereo allowed for UI cues; silence-trimmed; peak-normalized to about -3 dBFS.
- Naming: `assets/audio/sfx/<event_name>.wav`; randomizer variants `<event_name>_v1.wav` ... `_vN.wav`. Raw, unprocessed source files live in `assets/source/audio/<event_name>/` (raw sheets are never engine-referenced, per CLAUDE.md).
- `polyphony_group` must be a `VoiceLimiter.DEFAULT_FAMILY_CAPS` key; bus is `SFX` or `UI`. Spec §4 is authoritative for every cue's family, bus, spatial flag, randomizer, and start dB.
- `mission_phase_changed` stays UNMAPPED. The 3 existing cues (`skill_unlocked`, `tower_mastery_proximity_entered`, `tower_mastery_proximity_exited`) are not touched.
- No `#` comments inside `.tres`. Editing `.tres` in shell: use `awk` with `ENVIRON`, never `sed`/`${var//&/}` for text containing `&` (StringName literals like `&"tower_attacked"`).
- After adding or changing any audio file, run the editor-mode import so `.import` sidecars exist and are committed: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --editor --path G:\TDef --quit`.
- Test runner: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a <res:// path> --ignoreHeadlessMode`. Run only the targeted suites named here.
- Commit and push after each task's tests pass (standing user rule). Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- **Human-in-the-loop:** choosing/auditioning sounds (Step 1 of each tier task) needs a person, or a session with network access that verifies each pack's license page. Do not pick sounds by keyword alone and do not commit anything whose license cannot be verified.

## File Structure

- Create `tools/audio/process_sound.sh` — trim + peak-normalize + convert one raw file to a spec-format `.wav`.
- Create `tools/audio/author_cue.sh` — generate one `AudioCueEntry` `.tres` and append it to `audio_cue_map.tres`.
- Create `tools/audio/lib.sh` — `proc_cue` helper (processes 1 raw file or N variants for an event).
- Create `tools/audio/selftest.sh` — verifies the two scripts on a synthetic tone in a temp dir.
- Create `assets/audio/sfx/SOURCES.md` — provenance log.
- Create `tests/unit/audio/audio-cue-content_test.gd` — the spec table as a test.
- Create per tier: `assets/source/audio/<event>/*` (raw), `assets/audio/sfx/<event>*.wav` (+ `.import`), `assets/data/audio/cues/<event>.tres`; modify `assets/data/audio/audio_cue_map.tres`.
- Create `production/qa/audio-cue-listening-pass.md` (AC-7); modify `design/gdd/audio-system.md` (OQ-2 note), `production/session-state/active.md`.

---

### Task 1: Tooling, content test, sourcing log

**Files:**
- Create: `tools/audio/process_sound.sh`, `tools/audio/author_cue.sh`, `tools/audio/lib.sh`, `tools/audio/selftest.sh`, `assets/audio/sfx/SOURCES.md`
- Test: `tests/unit/audio/audio-cue-content_test.gd`

**Interfaces:**
- Produces: `process_sound.sh <in> <out.wav> [mono|stereo]`; `author_cue.sh <event> <family> <bus> <spatial:true|false> <db> <file.wav>...` (1 file = plain stream, 2+ = `AudioStreamRandomizer`; writes `$CUES_DIR/<event>.tres` and appends to `$MAP`; idempotent on the map); `proc_cue <event> <mono|stereo> <raw>...` (from `lib.sh`). Env overrides: `FFMPEG`, `CUES_DIR` (default `assets/data/audio/cues`), `MAP` (default `assets/data/audio/audio_cue_map.tres`).

- [ ] **Step 1: Write the content test (it must pass with no tiers shipped)**

```gdscript
extends GdUnitTestSuite

## Content-integrity test for the audio cue map (audio-cue-list spec §4/§10,
## AC-1..AC-5). SPEC is the spec's authoritative table; SHIPPED_TIERS lists
## which priority tiers have real content committed -- append 1, 2, 3 as each
## tier ships (each tier is independently shippable).

const CUE_MAP_PATH: String = "res://assets/data/audio/audio_cue_map.tres"
const SFX_DIR: String = "res://assets/audio/sfx/"
const SOURCES_PATH: String = "res://assets/audio/sfx/SOURCES.md"

const SHIPPED_TIERS: Array[int] = []

const EXISTING: Array[StringName] = [
	&"skill_unlocked", &"tower_mastery_proximity_entered", &"tower_mastery_proximity_exited",
]

## tier, family, bus, spatial, variants (0 = single stream, N>=3 = randomizer)
const SPEC: Dictionary[StringName, Dictionary] = {
	&"tower_attacked": {"tier": 1, "family": &"combat_impact", "bus": &"SFX", "spatial": true, "variants": 4},
	&"hero_damage_taken": {"tier": 1, "family": &"combat_impact", "bus": &"SFX", "spatial": true, "variants": 3},
	&"hero_skill_activated": {"tier": 1, "family": &"combat_impact", "bus": &"SFX", "spatial": true, "variants": 0},
	&"tower_placed": {"tier": 1, "family": &"activation_confirm", "bus": &"SFX", "spatial": true, "variants": 0},
	&"wave_countdown_warning": {"tier": 1, "family": &"combat_impact", "bus": &"SFX", "spatial": false, "variants": 0},
	&"boss_died": {"tier": 1, "family": &"discovery_fanfare", "bus": &"UI", "spatial": false, "variants": 0},
	&"component_crafted": {"tier": 2, "family": &"progress_blip", "bus": &"UI", "spatial": false, "variants": 0},
	&"hero_equipment_crafted": {"tier": 2, "family": &"progress_blip", "bus": &"UI", "spatial": false, "variants": 0},
	&"component_repaired": {"tier": 2, "family": &"ui_confirm_cancel", "bus": &"UI", "spatial": false, "variants": 0},
	&"sanctuary_structure_built": {"tier": 2, "family": &"activation_confirm", "bus": &"UI", "spatial": false, "variants": 0},
	&"structure_upgraded": {"tier": 2, "family": &"activation_confirm", "bus": &"UI", "spatial": false, "variants": 0},
	&"constellation_activated": {"tier": 2, "family": &"discovery_fanfare", "bus": &"UI", "spatial": false, "variants": 0},
	&"pre_placement_perk_activated": {"tier": 3, "family": &"activation_confirm", "bus": &"SFX", "spatial": false, "variants": 0},
	&"hero_class_unlocked": {"tier": 3, "family": &"progress_blip", "bus": &"UI", "spatial": false, "variants": 0},
	&"game_paused": {"tier": 3, "family": &"ui_confirm_cancel", "bus": &"UI", "spatial": false, "variants": 0},
	&"game_unpaused": {"tier": 3, "family": &"ui_confirm_cancel", "bus": &"UI", "spatial": false, "variants": 0},
}


func _entries() -> Dictionary:
	var map: AudioCueMap = load(CUE_MAP_PATH) as AudioCueMap
	assert_object(map).is_not_null()
	var by_event: Dictionary = {}
	for entry: AudioCueEntry in map.entries:
		assert_bool(by_event.has(entry.event_name)).override_failure_message("duplicate event_name %s" % entry.event_name).is_false()
		by_event[entry.event_name] = entry
	return by_event


func _shipped_events() -> Array[StringName]:
	var out: Array[StringName] = []
	for event: StringName in SPEC:
		if SHIPPED_TIERS.has(SPEC[event]["tier"] as int):
			out.append(event)
	return out


func test_spec_table_has_16_new_cues() -> void:
	assert_int(SPEC.size()).is_equal(16)


func test_every_entry_is_well_formed() -> void:
	for event: StringName in _entries():
		var entry: AudioCueEntry = _entries()[event]
		assert_object(entry.stream).override_failure_message("%s has null stream" % event).is_not_null()
		assert_bool(entry.bus == &"SFX" or entry.bus == &"UI").override_failure_message("%s bad bus %s" % [event, entry.bus]).is_true()
		assert_bool(VoiceLimiter.DEFAULT_FAMILY_CAPS.has(entry.polyphony_group)).override_failure_message("%s bad family %s" % [event, entry.polyphony_group]).is_true()


func test_existing_three_cues_still_mapped() -> void:
	var by_event: Dictionary = _entries()
	for event: StringName in EXISTING:
		assert_bool(by_event.has(event)).override_failure_message("%s missing" % event).is_true()


func test_mission_phase_changed_is_deliberately_unmapped() -> void:
	assert_bool(_entries().has(&"mission_phase_changed")).is_false()


func test_shipped_tier_entries_match_the_spec_table() -> void:
	var by_event: Dictionary = _entries()
	for event: StringName in _shipped_events():
		assert_bool(by_event.has(event)).override_failure_message("%s not in map" % event).is_true()
		var entry: AudioCueEntry = by_event[event]
		var spec: Dictionary = SPEC[event]
		assert_str(String(entry.polyphony_group)).override_failure_message("%s family" % event).is_equal(String(spec["family"]))
		assert_str(String(entry.bus)).override_failure_message("%s bus" % event).is_equal(String(spec["bus"]))
		assert_bool(entry.spatial).override_failure_message("%s spatial" % event).is_equal(spec["spatial"] as bool)
		var variants: int = spec["variants"] as int
		if variants >= 3:
			assert_bool(entry.stream is AudioStreamRandomizer).override_failure_message("%s should be a randomizer" % event).is_true()
			assert_int((entry.stream as AudioStreamRandomizer).streams_count).override_failure_message("%s variants" % event).is_greater_equal(variants)
		else:
			assert_bool(entry.stream is AudioStreamRandomizer).override_failure_message("%s should be a plain stream" % event).is_false()


func test_shipped_tier_files_exist_and_are_logged() -> void:
	var sources: String = FileAccess.get_file_as_string(SOURCES_PATH)
	for event: StringName in _shipped_events():
		var variants: int = SPEC[event]["variants"] as int
		if variants >= 3:
			for i: int in range(1, variants + 1):
				assert_bool(FileAccess.file_exists(SFX_DIR + "%s_v%d.wav" % [event, i])).override_failure_message("%s_v%d.wav missing" % [event, i]).is_true()
		else:
			assert_bool(FileAccess.file_exists(SFX_DIR + "%s.wav" % event)).override_failure_message("%s.wav missing" % event).is_true()
		assert_str(sources).override_failure_message("%s not in SOURCES.md" % event).contains(String(event))
```

- [ ] **Step 2: Run the test to verify it passes with no tiers shipped**

Run `res://tests/unit/audio/audio-cue-content_test.gd`. Expected: PASS (it asserts only the 3 existing entries, well-formedness, and that `mission_phase_changed` is unmapped; the `SHIPPED_TIERS`-driven tests loop over nothing). A `SOURCES.md` file need not exist yet.

- [ ] **Step 3: Write the tooling**

`tools/audio/process_sound.sh`:

```bash
#!/usr/bin/env bash
# Trim leading/trailing silence, peak-normalize to -3 dBFS, convert to
# 44.1 kHz 16-bit wav. Usage: process_sound.sh <in> <out.wav> [mono|stereo]
set -euo pipefail
FFMPEG="${FFMPEG:-/c/ffmpeg-8.0.1-full_build/bin/ffmpeg}"
in="$1"; out="$2"; ch="${3:-mono}"
chn=1; [ "$ch" = "stereo" ] && chn=2
trim="silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse"
peak=$("$FFMPEG" -hide_banner -nostats -i "$in" -af "$trim,volumedetect" -f null - 2>&1 \
  | sed -n 's/.*max_volume: \(-\?[0-9.]*\) dB.*/\1/p' | tail -1)
[ -n "$peak" ] || { echo "process_sound: could not measure peak of $in" >&2; exit 1; }
gain=$(awk -v p="$peak" 'BEGIN{printf "%.2f", -3.0 - p}')
"$FFMPEG" -hide_banner -loglevel error -y -i "$in" -af "$trim,volume=${gain}dB" \
  -ar 44100 -ac "$chn" -c:a pcm_s16le "$out"
```

`tools/audio/author_cue.sh`:

```bash
#!/usr/bin/env bash
# Generate one AudioCueEntry .tres (plain stream for 1 file, AudioStreamRandomizer
# for 2+) and append it to the cue map. Idempotent on the map.
# Usage: author_cue.sh <event> <family> <bus> <spatial:true|false> <db> <file.wav>...
set -euo pipefail
event="$1"; family="$2"; bus="$3"; spatial="$4"; db="$5"; shift 5
cues_dir="${CUES_DIR:-assets/data/audio/cues}"
map="${MAP:-assets/data/audio/audio_cue_map.tres}"
out="$cues_dir/$event.tres"
n=$#
{
  echo "[gd_resource type=\"Resource\" script_class=\"AudioCueEntry\" load_steps=$((n > 1 ? n + 3 : 3)) format=3]"
  echo
  echo '[ext_resource type="Script" path="res://src/core/audio/audio_cue_entry.gd" id="1"]'
  i=2
  for f in "$@"; do
    echo "[ext_resource type=\"AudioStream\" path=\"res://assets/audio/sfx/$(basename "$f")\" id=\"$i\"]"
    i=$((i + 1))
  done
  echo
  if [ "$n" -gt 1 ]; then
    echo '[sub_resource type="AudioStreamRandomizer" id="Randomizer_1"]'
    echo 'random_pitch = 1.06'
    echo 'random_volume_offset_db = 1.5'
    echo "streams_count = $n"
    for ((k = 0; k < n; k++)); do
      echo "stream_$k/stream = ExtResource(\"$((k + 2))\")"
      echo "stream_$k/weight = 1.0"
    done
    echo
    stream_ref='SubResource("Randomizer_1")'
  else
    stream_ref='ExtResource("2")'
  fi
  echo '[resource]'
  echo 'script = ExtResource("1")'
  echo "event_name = &\"$event\""
  echo "stream = $stream_ref"
  echo "bus = &\"$bus\""
  echo "polyphony_group = &\"$family\""
  echo "volume_db_offset = $db"
  echo "spatial = $spatial"
} > "$out"

grep -q "id=\"cue_$event\"" "$map" && { echo "author_cue: $event already in map"; exit 0; }
export EV="$event"
ext_count=$(grep -c '^\[ext_resource' "$map")
awk -v steps="$((ext_count + 2))" '
  { lines[NR] = $0 }
  /^\[ext_resource/ { last = NR }
  END {
    for (i = 1; i <= NR; i++) {
      line = lines[i]
      if (i == 1) sub(/load_steps=[0-9]+/, "load_steps=" steps, line)
      if (line ~ /^entries = \[/) sub(/\]\r?$/, ", ExtResource(\"cue_" ENVIRON["EV"] "\")]", line)
      print line
      if (i == last) print "[ext_resource type=\"Resource\" path=\"res://assets/data/audio/cues/" ENVIRON["EV"] ".tres\" id=\"cue_" ENVIRON["EV"] "\"]"
    }
  }' "$map" > "$map.new" && mv "$map.new" "$map"
```

`tools/audio/lib.sh` (sourced, not executed):

```bash
# proc_cue <event> <mono|stereo> <raw file>...  -- one raw file writes
# assets/audio/sfx/<event>.wav; N files write <event>_v1.wav ... _vN.wav.
proc_cue() {
  local ev="$1" ch="$2"; shift 2
  if [ "$#" -eq 1 ]; then
    tools/audio/process_sound.sh "$1" "assets/audio/sfx/$ev.wav" "$ch"
  else
    local i=1 f
    for f in "$@"; do
      tools/audio/process_sound.sh "$f" "assets/audio/sfx/${ev}_v$i.wav" "$ch"
      i=$((i + 1))
    done
  fi
}
```

`tools/audio/selftest.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
FFMPEG="${FFMPEG:-/c/ffmpeg-8.0.1-full_build/bin/ffmpeg}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/cues"
"$FFMPEG" -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=440:duration=0.3" "$tmp/raw.wav"
tools/audio/process_sound.sh "$tmp/raw.wav" "$tmp/out.wav" mono
info=$("$FFMPEG" -hide_banner -i "$tmp/out.wav" 2>&1 | grep "Audio:" || true)
echo "$info" | grep -q "44100 Hz, mono, s16" || { echo "FAIL format: $info"; exit 1; }
vol=$("$FFMPEG" -hide_banner -nostats -i "$tmp/out.wav" -af volumedetect -f null - 2>&1 \
  | sed -n 's/.*max_volume: \(-\?[0-9.]*\) dB.*/\1/p' | tail -1)
awk -v v="$vol" 'BEGIN{ if (v < -3.6 || v > -2.4) { print "FAIL peak " v; exit 1 } }'
cp assets/data/audio/audio_cue_map.tres "$tmp/map.tres"
export CUES_DIR="$tmp/cues" MAP="$tmp/map.tres"
tools/audio/author_cue.sh selftest_single combat_impact SFX true -8 out.wav
tools/audio/author_cue.sh selftest_multi combat_impact SFX true -8 out.wav out.wav out.wav
grep -q 'event_name = &"selftest_single"' "$tmp/cues/selftest_single.tres"
grep -q 'stream = ExtResource("2")' "$tmp/cues/selftest_single.tres"
grep -q 'AudioStreamRandomizer' "$tmp/cues/selftest_multi.tres"
grep -q 'streams_count = 3' "$tmp/cues/selftest_multi.tres"
grep -q 'ExtResource("cue_selftest_single")' "$tmp/map.tres"
grep -q 'ExtResource("2"), ExtResource("3"), ExtResource("4")' "$tmp/map.tres"
before=$(grep -c cue_selftest_single "$tmp/map.tres")
tools/audio/author_cue.sh selftest_single combat_impact SFX true -8 out.wav
after=$(grep -c cue_selftest_single "$tmp/map.tres")
[ "$before" = "$after" ] || { echo "FAIL not idempotent"; exit 1; }
echo "audio tooling selftest: OK"
```

`assets/audio/sfx/SOURCES.md` (skeleton; rows are added per cue in each tier task):

```markdown
# Audio Sourcing Log

Every shipped sound in `assets/audio/sfx/` is recorded here (audio-cue-list spec §3.4, AC-4/AC-5).
CC0 by default; a CC-BY source also needs its attribution in `LICENSE.txt`.

| Event | Source pack | Original filename | License | URL | Edits |
|---|---|---|---|---|---|
| skill_unlocked | Kenney Interface Sounds | (see LICENSE.txt) | CC0 | https://kenney.nl | trimmed/normalized |
| tower_mastery_proximity_entered | Kenney Interface Sounds | (see LICENSE.txt) | CC0 | https://kenney.nl | trimmed/normalized |
| tower_mastery_proximity_exited | Kenney Interface Sounds | (see LICENSE.txt) | CC0 | https://kenney.nl | trimmed/normalized |
```

- [ ] **Step 4: Run the tooling selftest**

Run `bash tools/audio/selftest.sh` from `G:\TDef`. Expected: prints `audio tooling selftest: OK`. If the peak check fails, print the measured value and fix `process_sound.sh`'s gain math before continuing.

- [ ] **Step 5: Commit and push**

```bash
chmod +x tools/audio/*.sh
git add tools/audio assets/audio/sfx/SOURCES.md tests/unit/audio/audio-cue-content_test.gd
git commit -m "Add audio cue authoring tooling, content test, and sourcing log

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
```

---

### Task 2: Tier 1 cues (the six most-felt)

**Files:**
- Create: `assets/source/audio/<event>/*` (raw), `assets/audio/sfx/<event>*.wav` (+ `.import`), `assets/data/audio/cues/<event>.tres` for `tower_attacked` (4 variants), `hero_damage_taken` (3 variants), `hero_skill_activated`, `tower_placed`, `wave_countdown_warning`, `boss_died`
- Modify: `assets/data/audio/audio_cue_map.tres`, `assets/audio/sfx/SOURCES.md`, `assets/audio/sfx/LICENSE.txt` (only if CC-BY is used), `tests/unit/audio/audio-cue-content_test.gd` (`SHIPPED_TIERS`)

- [ ] **Step 1 (human / network-enabled session): choose and place raw sounds**

Per spec §4 (character and search keywords there), pick CC0 candidates and audition them. Verify each pack's license on its own page. Place raw files: one file in `assets/source/audio/<event>/` for single-stream cues; exactly 4 files for `tower_attacked` and exactly 3 for `hero_damage_taken` (randomizer variants). Append one row per cue to `SOURCES.md` (event, pack, original filename, license, URL, edits), and add attribution to `LICENSE.txt` only for CC-BY sources.

- [ ] **Step 2: Process the raw files**

```bash
cd /g/TDef && source tools/audio/lib.sh
proc_cue tower_attacked          mono   assets/source/audio/tower_attacked/*
proc_cue hero_damage_taken       mono   assets/source/audio/hero_damage_taken/*
proc_cue hero_skill_activated    mono   assets/source/audio/hero_skill_activated/*
proc_cue tower_placed            mono   assets/source/audio/tower_placed/*
proc_cue wave_countdown_warning  mono   assets/source/audio/wave_countdown_warning/*
proc_cue boss_died               stereo assets/source/audio/boss_died/*
ls assets/audio/sfx | grep -E "tower_attacked|hero_damage_taken|hero_skill_activated|tower_placed|wave_countdown|boss_died"
```
Expected: `tower_attacked_v1..v4.wav`, `hero_damage_taken_v1..v3.wav`, and one `.wav` each for the other four.

- [ ] **Step 3: Author the cue entries**

```bash
tools/audio/author_cue.sh tower_attacked         combat_impact      SFX true  -8 tower_attacked_v{1..4}.wav
tools/audio/author_cue.sh hero_damage_taken      combat_impact      SFX true  -3 hero_damage_taken_v{1..3}.wav
tools/audio/author_cue.sh hero_skill_activated   combat_impact      SFX true  -4 hero_skill_activated.wav
tools/audio/author_cue.sh tower_placed           activation_confirm SFX true  -4 tower_placed.wav
tools/audio/author_cue.sh wave_countdown_warning combat_impact      SFX false -6 wave_countdown_warning.wav
tools/audio/author_cue.sh boss_died              discovery_fanfare  UI  false  0 boss_died.wav
grep -c "ExtResource(\"cue_" assets/data/audio/audio_cue_map.tres
tail -3 assets/data/audio/audio_cue_map.tres
```
Expected: the map's `entries` line now lists the 3 original plus these 6 (9 entries).

- [ ] **Step 4: Import, mark tier shipped, run tests**

```bash
"/c/Users/Shaukan/Desktop/Godot_v4.6.2-stable_win64.exe" --headless --editor --path . --quit
```
In `tests/unit/audio/audio-cue-content_test.gd` change `const SHIPPED_TIERS: Array[int] = []` to `[1]`. Run `res://tests/unit/audio/audio-cue-content_test.gd`, `res://tests/unit/audio`, `res://tests/integration/audio`. Expected: all PASS. Fix any failure at its source (bad filename count, missing SOURCES.md row, wrong family/bus) before committing.

- [ ] **Step 5: Commit and push**

```bash
git add assets/source/audio assets/audio/sfx assets/data/audio tests/unit/audio/audio-cue-content_test.gd
git commit -m "Author tier 1 audio cues (tower attack, hero damage, skill cast, placement, countdown, boss death)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
```

---

### Task 3: Tier 2 cues (crafting, sanctuary, constellation)

**Files:**
- Create: raw sources, `assets/audio/sfx/*.wav` (+ `.import`), `assets/data/audio/cues/*.tres` for `component_crafted`, `hero_equipment_crafted`, `component_repaired`, `sanctuary_structure_built`, `structure_upgraded`, `constellation_activated` (all single-stream)
- Modify: `assets/data/audio/audio_cue_map.tres`, `assets/audio/sfx/SOURCES.md`, `assets/audio/sfx/LICENSE.txt` (CC-BY only), `tests/unit/audio/audio-cue-content_test.gd`

- [ ] **Step 1 (human / network-enabled session): choose and place raw sounds**

One raw file per event in `assets/source/audio/<event>/`, per spec §4 (note `component_crafted` and `hero_equipment_crafted` MUST sound distinct: light vs. heavy; `structure_upgraded` is a brighter/higher relative of `sanctuary_structure_built`). Verify licenses; add `SOURCES.md` rows.

- [ ] **Step 2: Process the raw files**

```bash
cd /g/TDef && source tools/audio/lib.sh
proc_cue component_crafted          stereo assets/source/audio/component_crafted/*
proc_cue hero_equipment_crafted     stereo assets/source/audio/hero_equipment_crafted/*
proc_cue component_repaired         stereo assets/source/audio/component_repaired/*
proc_cue sanctuary_structure_built  stereo assets/source/audio/sanctuary_structure_built/*
proc_cue structure_upgraded         stereo assets/source/audio/structure_upgraded/*
proc_cue constellation_activated    stereo assets/source/audio/constellation_activated/*
```

- [ ] **Step 3: Author the cue entries**

```bash
tools/audio/author_cue.sh component_crafted         progress_blip      UI false -4 component_crafted.wav
tools/audio/author_cue.sh hero_equipment_crafted    progress_blip      UI false -3 hero_equipment_crafted.wav
tools/audio/author_cue.sh component_repaired        ui_confirm_cancel  UI false -6 component_repaired.wav
tools/audio/author_cue.sh sanctuary_structure_built activation_confirm UI false -4 sanctuary_structure_built.wav
tools/audio/author_cue.sh structure_upgraded        activation_confirm UI false -3 structure_upgraded.wav
tools/audio/author_cue.sh constellation_activated   discovery_fanfare  UI false -2 constellation_activated.wav
```

- [ ] **Step 4: Import, mark tier shipped, run tests**

Run the editor-mode import (Task 2 Step 4 command). Change `SHIPPED_TIERS` to `[1, 2]`. Run `res://tests/unit/audio/audio-cue-content_test.gd`, `res://tests/unit/audio`, `res://tests/integration/audio`. Expected: all PASS.

- [ ] **Step 5: Commit and push**

```bash
git add assets/source/audio assets/audio/sfx assets/data/audio tests/unit/audio/audio-cue-content_test.gd
git commit -m "Author tier 2 audio cues (crafting, sanctuary, constellation)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
```

---

### Task 4: Tier 3 cues (perk, class unlock, pause) + listening-pass record

**Files:**
- Create: raw sources, `assets/audio/sfx/*.wav` (+ `.import`), `assets/data/audio/cues/*.tres` for `pre_placement_perk_activated`, `hero_class_unlocked`, `game_paused`, `game_unpaused` (all single-stream); `production/qa/audio-cue-listening-pass.md`
- Modify: `assets/data/audio/audio_cue_map.tres`, `assets/audio/sfx/SOURCES.md`, `assets/audio/sfx/LICENSE.txt` (CC-BY only), `tests/unit/audio/audio-cue-content_test.gd`, `design/gdd/audio-system.md`, `production/session-state/active.md`

- [ ] **Step 1 (human / network-enabled session): choose and place raw sounds**

One raw file per event; `game_paused`/`game_unpaused` should be a matched down-tick/up-tick pair. Verify licenses; add `SOURCES.md` rows.

- [ ] **Step 2: Process the raw files**

```bash
cd /g/TDef && source tools/audio/lib.sh
proc_cue pre_placement_perk_activated mono   assets/source/audio/pre_placement_perk_activated/*
proc_cue hero_class_unlocked          stereo assets/source/audio/hero_class_unlocked/*
proc_cue game_paused                  stereo assets/source/audio/game_paused/*
proc_cue game_unpaused                stereo assets/source/audio/game_unpaused/*
```

- [ ] **Step 3: Author the cue entries**

```bash
tools/audio/author_cue.sh pre_placement_perk_activated activation_confirm SFX false -6 pre_placement_perk_activated.wav
tools/audio/author_cue.sh hero_class_unlocked          progress_blip      UI  false -4 hero_class_unlocked.wav
tools/audio/author_cue.sh game_paused                  ui_confirm_cancel  UI  false -8 game_paused.wav
tools/audio/author_cue.sh game_unpaused                ui_confirm_cancel  UI  false -8 game_unpaused.wav
```

- [ ] **Step 4: Import, mark all tiers shipped, run tests**

Run the editor-mode import. Change `SHIPPED_TIERS` to `[1, 2, 3]`. Run `res://tests/unit/audio/audio-cue-content_test.gd`, `res://tests/unit/audio`, `res://tests/integration/audio`. Expected: all PASS, with all 16 new cues plus the 3 existing mapped and `mission_phase_changed` still absent (AC-1..AC-6).

- [ ] **Step 5: Listening-pass record, docs, state**

Create `production/qa/audio-cue-listening-pass.md` (AC-7) as a checklist to be filled by a person:

```markdown
# Audio Cue Listening Pass

**Status**: NOT YET RUN (requires a person listening in the running game)

For each shipped cue, confirm: audible at default volume, distinct within its family,
not fatiguing at expected repetition, sounds correct for its trigger.

| Event | Audible | Distinct in family | Not fatiguing | Notes |
|---|---|---|---|---|
| tower_attacked | | | | |
| hero_damage_taken | | | | |
| hero_skill_activated | | | | |
| tower_placed | | | | |
| wave_countdown_warning | | | | |
| boss_died | | | | |
| component_crafted | | | | |
| hero_equipment_crafted | | | | |
| component_repaired | | | | |
| sanctuary_structure_built | | | | |
| structure_upgraded | | | | |
| constellation_activated | | | | |
| pre_placement_perk_activated | | | | |
| hero_class_unlocked | | | | |
| game_paused | | | | |
| game_unpaused | | | | |
```

In `design/gdd/audio-system.md`, append one sentence to the OQ-2 row noting: "2026-09-20: all 20 wired event cues now have real content (mission_phase_changed deliberately unmapped); music/ambient stems, unwired UI-click/denial cues, spatial distance wiring, and per-element/per-skill variants remain — see `docs/superpowers/specs/2026-09-20-audio-cue-list-design.md` §9." Append an "Audio Cue List shipped" extract to `production/session-state/active.md` (what shipped, the tooling under `tools/audio/`, that the AC-7 listening pass and live verification are still pending, and the §9 follow-ups).

- [ ] **Step 6: Commit and push**

```bash
git add assets/source/audio assets/audio/sfx assets/data/audio tests/unit/audio/audio-cue-content_test.gd production/qa/audio-cue-listening-pass.md design/gdd/audio-system.md production/session-state/active.md
git commit -m "Author tier 3 audio cues and add listening-pass checklist

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
```

---

## Self-Review

- **Spec coverage:** §3.1/§3.2 entry authoring and randomizers → `author_cue.sh` + Task 2 (the two randomizer cues); §3.3 spatial flag → set per §4 in every `author_cue.sh` call (documented inert); §3.4 standards → `process_sound.sh`, naming in `lib.sh`, `SOURCES.md`, Global Constraints; §4 table → the test's `SPEC` and the three tiers' command lists (all 16 rows covered: tier 1 = 6, tier 2 = 6, tier 3 = 4); §5 priorities → Tasks 2-4; AC-1/AC-2/AC-3/AC-4 → `audio-cue-content_test.gd`; AC-5 → Step 1 license verification + `LICENSE.txt` rule (not automatable; enforced by process); AC-6 → each tier's Step 4 regression run; AC-7 → Task 4 Step 5 checklist (manual by design).
- **Placeholders:** none in code or commands. The only non-code steps are the explicit human sourcing steps, which the spec itself requires to be human.
- **Type/name consistency:** `author_cue.sh` argument order (event, family, bus, spatial, db, files) is identical in Task 1 and all tier commands; `proc_cue` (event, channels, raw files) likewise; `SHIPPED_TIERS` progression `[] -> [1] -> [1, 2] -> [1, 2, 3]`; event names and family/bus/dB values match spec §4 and the test's `SPEC`.

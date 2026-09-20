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

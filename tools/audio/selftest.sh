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

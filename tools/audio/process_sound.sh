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

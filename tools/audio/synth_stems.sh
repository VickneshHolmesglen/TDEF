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

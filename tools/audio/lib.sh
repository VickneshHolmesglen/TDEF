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

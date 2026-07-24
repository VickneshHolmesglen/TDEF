class_name AudioCueMap
extends Resource

## Authored table of event->cue mappings — Story 003 (epic-12-audio-system).
##
## Deliberately `Array[AudioCueEntry]`, not `Dictionary[StringName,
## AudioCueEntry]` — per this project's own live-verified engine risk note
## (docs/engine-reference/godot/VERSION.md), a Resource-valued Dictionary has
## no usable inspector editor in Godot 4.6. `AudioCueDispatcher` builds its
## own runtime `Dictionary[StringName, AudioCueEntry]` lookup once from this
## array at `_ready()`.
##
## Ships with 0 or very few real entries — content-authoring (OQ-2) is
## explicitly out of this epic's scope; this Resource is the mechanism only.

@export var entries: Array[AudioCueEntry] = []

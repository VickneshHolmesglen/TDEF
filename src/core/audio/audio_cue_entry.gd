class_name AudioCueEntry
extends Resource

## A single data-driven cue mapping — Story 003 (epic-12-audio-system).
##
## GDD source: design/gdd/audio-system.md — Core Rule 4.

@export var event_name: StringName = &""
@export var stream: AudioStream = null
@export var bus: StringName = &"SFX"

## Which of the 7 SFX cue families (Core Rule 3) this cue belongs to — used
## by Story 004's voice-limiting/ducking, not consulted by this story.
@export var polyphony_group: StringName = &""

@export var volume_db_offset: float = 0.0

## True for world-diegetic cues that use Formula F2 (world-space distance
## attenuation). False for UI/HUD-family cues (Core Rule 3 families #2-#5),
## which always play at authored volume regardless of world position.
@export var spatial: bool = false

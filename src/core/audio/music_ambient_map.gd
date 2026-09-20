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

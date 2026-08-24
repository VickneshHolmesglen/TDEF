class_name CreatureAnimationClip
extends Resource

## One named animation clip within a CreatureAtlasMappingResource's atlas
## (ADR-0038, hybrid-swarm-rendering-implementation-blueprint.md §"Data
## contracts" → CreatureAtlasMappingResource). Pure data — no runtime state.
##
## start_frame/frame_count index into the parent mapping's flat
## atlas_columns * atlas_rows frame grid (row-major, matching
## creature_swarm_body.gdshader's own `col = frame % atlas_cols`,
## `row = frame / atlas_cols` decode, live-verified in
## prototypes/hybrid-swarm-pilot/).

## Identifies this clip within its parent mapping (e.g. &"idle", &"walk",
## &"death"). Empty StringName is invalid.
@export var clip_name: StringName = &""

## First frame index in the parent mapping's atlas grid. Negative is invalid.
@export var start_frame: int = 0

## Number of frames this clip spans, starting at start_frame. Must be
## positive; start_frame + frame_count must not exceed the parent mapping's
## total frame_count (checked by the parent, which has that context).
@export var frame_count: int = 1

## Playback rate in frames per second. Must be positive.
@export var fps: float = 8.0

## Whether this clip repeats after its last frame.
@export var loop: bool = true


## Load-time validation for this clip in isolation (fields that don't need
## the parent mapping's frame_count for context). Returns [] when valid, one
## string per invalid field otherwise. Mirrors the project's established
## Array[String] validate() idiom (see VisualMeshMappingResource).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if clip_name == &"":
		errors.append("clip_name must not be empty")
	if start_frame < 0:
		errors.append("start_frame must not be negative (got %d)" % start_frame)
	if frame_count <= 0:
		errors.append("frame_count must be positive (got %d)" % frame_count)
	if fps <= 0.0:
		errors.append("fps must be positive (got %f)" % fps)
	return errors

class_name CreatureAtlasMappingResource
extends Resource

## Data definition mapping a creature/monster to its 2D animation sheet: the
## texture, its frame grid and named clips (walk/idle/prepare). Read by
## MonsterInstance to slice and play the sprite's frames.
##
## Follows ADR-0009's Resource + GameDataRegistry + validate() convention. One
## .tres per creature, e.g. assets/data/creature_atlases/goblin_runner.tres.
## Loaded and validated by GameDataRegistry at boot (push_error on invalid,
## does-not-abort policy, same as every other GameDataRegistry type).
##
## 2026-11-05: the ADR-0038 3D swarm renderer that also read this resource
## (body size, foot anchor, batch keys, presenter class, batch capacity) was
## removed when the presentation was locked to HD-2D; only the 2D sheet data
## remains.
##
## Usage:
##   var mapping: CreatureAtlasMappingResource = GGameDataRegistry.get_creature_atlas_mapping(&"goblin_runner")
##   if mapping == null:
##       return  # static sprite fallback
##   var clip: CreatureAnimationClip = mapping.get_animation_clip(&"walk")

## Creature/content ID this mapping resolves a sheet for (e.g.
## &"goblin_runner"). Empty StringName is invalid.
@export var creature_id: StringName = &""

## The engine-ready, alpha-cut sheet texture (assets/art/, never
## assets/source/ — per codex-art-overhaul.md §5.1). Null is invalid.
@export var atlas_texture: Texture2D = null

## Sheet grid columns. Must be positive.
@export var atlas_columns: int = 1

## Sheet grid rows. Must be positive.
@export var atlas_rows: int = 1

## Total usable frame count within the atlas_columns * atlas_rows grid. Must
## be positive and must not exceed atlas_columns * atlas_rows.
@export var frame_count: int = 1

## Named animation clips into the frame grid above. May be empty (a static
## pose) but each clip present must itself validate and must not run past
## frame_count.
@export var animation_clips: Array[CreatureAnimationClip] = []


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009
## contract). Returns [] when valid, one string per invalid field otherwise.
##
## Usage:
##   var errors: Array[String] = mapping.validate()
##   for err: String in errors:
##       push_error(err)
func validate() -> Array[String]:
	var errors: Array[String] = []

	if creature_id == &"":
		errors.append("creature_id must not be empty")
	if atlas_texture == null:
		errors.append("atlas_texture must be assigned")

	if atlas_columns <= 0:
		errors.append("atlas_columns must be positive (got %d)" % atlas_columns)
	if atlas_rows <= 0:
		errors.append("atlas_rows must be positive (got %d)" % atlas_rows)

	if frame_count <= 0:
		errors.append("frame_count must be positive (got %d)" % frame_count)
	elif atlas_columns > 0 and atlas_rows > 0 and frame_count > atlas_columns * atlas_rows:
		errors.append("frame_count (%d) exceeds atlas grid capacity (%d columns x %d rows = %d cells)" % [frame_count, atlas_columns, atlas_rows, atlas_columns * atlas_rows])

	var seen_clip_names: Dictionary[StringName, bool] = {}
	for clip: CreatureAnimationClip in animation_clips:
		if clip == null:
			errors.append("animation_clips contains a null entry")
			continue
		var clip_errors: Array[String] = clip.validate()
		for err: String in clip_errors:
			errors.append("animation clip '%s': %s" % [clip.clip_name, err])
		if clip.clip_name != &"":
			if seen_clip_names.has(clip.clip_name):
				errors.append("duplicate animation clip name '%s'" % clip.clip_name)
			seen_clip_names[clip.clip_name] = true
		if frame_count > 0 and clip.start_frame + clip.frame_count > frame_count:
			errors.append("animation clip '%s': start_frame (%d) + frame_count (%d) exceeds this mapping's frame_count (%d)" % [clip.clip_name, clip.start_frame, clip.frame_count, frame_count])

	return errors


## Returns the named clip, or null if this mapping has no clip with that
## name. O(n) over animation_clips — mappings carry a small, fixed clip list,
## so a linear scan is not a hot-path concern.
func get_animation_clip(clip_name: StringName) -> CreatureAnimationClip:
	for clip: CreatureAnimationClip in animation_clips:
		if clip != null and clip.clip_name == clip_name:
			return clip
	return null

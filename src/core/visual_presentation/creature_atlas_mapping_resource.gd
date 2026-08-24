class_name CreatureAtlasMappingResource
extends Resource

## Data definition mapping a creature/monster family to its 2D swarm-render
## atlas (ADR-0038, GameDataRegistry Story 5 — "Data registry integration").
##
## Follows ADR-0009's Resource + GameDataRegistry + validate() convention,
## mirroring VisualMeshMappingResource (Epic 15 Story 001, ADR-0037) and
## RecipeResource. One .tres per creature family, e.g.
## assets/data/creature_atlases/goblin_runner.tres. Loaded and validated by
## GameDataRegistry at boot — a missing/invalid mapping fails boot loudly
## (push_error, does-not-abort policy, same as every other GameDataRegistry
## type), matching ADR-0038's own "fails loudly" requirement.
##
## PRESENTATION_CLASS_STANDARD creatures are rendered by MonsterSwarmRenderer3D's
## batched MultiMesh path (Story 6+). PRESENTATION_CLASS_EXCEPTIONAL creatures
## (bosses/elites) use a capped individual Sprite3D/AnimatedSprite3D presenter
## instead (ADR-0038 "Bosses, elites, and Menagerie") and must name their
## approved_presenter_class.
##
## No rendering/scene-tree or batch-registration code lives here — this
## story is the data-layer foundation only, per the blueprint's own Story 5
## scope ("without changing live monsters"). MonsterSwarmRenderer3D consuming
## this data is Story 6's scope.
##
## Usage:
##   var mapping: CreatureAtlasMappingResource = GGameDataRegistry.get_creature_atlas_mapping(&"goblin_runner")
##   if mapping == null:
##       push_error("Unknown creature_id — no swarm atlas mapping for this creature.")
##       return
##   var clip: CreatureAnimationClip = mapping.get_animation_clip(&"walk")

const PRESENTATION_CLASS_STANDARD: StringName = &"standard"
const PRESENTATION_CLASS_EXCEPTIONAL: StringName = &"exceptional"

## Recognized render_mode_id values (ADR-0038 §"Body and shadow submissions":
## alpha scissor is the baseline; alpha hash is an evidence-backed optional
## variant; alpha blend is reserved for separately budgeted VFX, not standard
## creature bodies).
const RENDER_MODE_ALPHA_SCISSOR: StringName = &"alpha_scissor"
const RENDER_MODE_ALPHA_HASH: StringName = &"alpha_hash"

## Creature/content ID this mapping resolves an atlas for (e.g.
## &"goblin_runner"). Empty StringName is invalid. Distinct from
## family_atlas_id below — several creature_ids may legitimately share one
## family_atlas_id/BatchKey when they're recolors or minor variants of the
## same sheet (ADR-0038's BatchKey has no per-creature-id field).
@export var creature_id: StringName = &""

## Identifies the shared atlas/batch this creature draws from — part of
## ADR-0038's BatchKey tuple (creature_family_atlas_id, mesh_layout_id,
## material_shader_variant_id, render_mode_id). Empty StringName is invalid.
@export var family_atlas_id: StringName = &""

## The engine-ready, alpha-cut atlas texture (assets/art/, never
## assets/source/ — per codex-art-overhaul.md §5.1). Null is invalid.
@export var atlas_texture: Texture2D = null

## Atlas grid columns. Must be positive.
@export var atlas_columns: int = 1

## Atlas grid rows. Must be positive.
@export var atlas_rows: int = 1

## Total usable frame count within the atlas_columns * atlas_rows grid. Must
## be positive and must not exceed atlas_columns * atlas_rows (a grid cell
## count ceiling, not every cell need be used, but frame_count may never
## claim more cells than exist).
@export var frame_count: int = 1

## Named animation clips into the frame grid above. May be empty (a creature
## with only a static pose is technically representable, though ADR-0038
## expects swarms to animate) but each clip present must itself validate and
## must not run past frame_count.
@export var animation_clips: Array[CreatureAnimationClip] = []

## World-space body width/height in the same units as VisualMath.map_to_3d()
## output. Both must be positive.
@export var world_width: float = 1.0
@export var world_height: float = 1.0

## Offset from the body quad's local origin to its ground-contact point, in
## world units (ADR-0038 "foot anchor" — keeps the illustrated body visually
## grounded regardless of world_height). No sign constraint — a creature
## whose art has empty space above its feet may need a non-zero offset.
@export var foot_anchor_offset: Vector2 = Vector2.ZERO

## Batch-key components (ADR-0038's BatchKey tuple, minus family_atlas_id
## which is its own field above). All three must be non-empty.
@export var mesh_layout_id: StringName = &"quad_billboard"
@export var shader_variant_id: StringName = &"creature_swarm_body"
@export var render_mode_id: StringName = RENDER_MODE_ALPHA_SCISSOR

## PRESENTATION_CLASS_STANDARD or PRESENTATION_CLASS_EXCEPTIONAL. Must be one
## of the two recognized constants.
@export var presentation_class: StringName = PRESENTATION_CLASS_STANDARD

## Required when presentation_class == PRESENTATION_CLASS_EXCEPTIONAL — names
## the approved individual-presenter class (e.g. &"BossCreaturePresenter3D")
## this creature is allowed to use instead of the batched swarm path.
## ADR-0038: "exceptional assets without an approved presenter class" must
## fail validation. Ignored (may stay empty) for standard creatures.
@export var approved_presenter_class: StringName = &""

## Preallocated MultiMesh capacity this creature family requires from its
## batch (ADR-0038: "changing instance_count in the hot path is forbidden" —
## capacity is a boot-time allocation decision, not a runtime one). Must be
## positive for standard creatures; ignored for exceptional creatures (they
## don't share a MultiMesh batch at all).
@export var batch_capacity_requirement: int = 200

## Versions the INSTANCE_CUSTOM.z status/variant bit-mask schema (ADR-0038
## §"Per-instance channel budget": "This allocation may change only through
## a documented contract revision"). Must be positive; a mismatch between a
## creature's expected schema version and the renderer's current one is a
## content-authoring error the renderer is expected to catch at Story 6+,
## not this story's concern — this field only carries the value.
@export var status_mask_schema_version: int = 1


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009
## contract). Returns [] when valid, one string per invalid field otherwise.
## Mirrors VisualMeshMappingResource.validate()'s "empty array = pass" idiom.
##
## Usage:
##   var errors: Array[String] = mapping.validate()
##   for err: String in errors:
##       push_error(err)
func validate() -> Array[String]:
	var errors: Array[String] = []

	if creature_id == &"":
		errors.append("creature_id must not be empty")
	if family_atlas_id == &"":
		errors.append("family_atlas_id must not be empty")
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

	if world_width <= 0.0:
		errors.append("world_width must be positive (got %f)" % world_width)
	if world_height <= 0.0:
		errors.append("world_height must be positive (got %f)" % world_height)

	if mesh_layout_id == &"":
		errors.append("mesh_layout_id must not be empty")
	if shader_variant_id == &"":
		errors.append("shader_variant_id must not be empty")
	if render_mode_id != RENDER_MODE_ALPHA_SCISSOR and render_mode_id != RENDER_MODE_ALPHA_HASH:
		errors.append("render_mode_id must be one of %s/%s (got '%s')" % [RENDER_MODE_ALPHA_SCISSOR, RENDER_MODE_ALPHA_HASH, render_mode_id])

	if presentation_class != PRESENTATION_CLASS_STANDARD and presentation_class != PRESENTATION_CLASS_EXCEPTIONAL:
		errors.append("presentation_class must be one of %s/%s (got '%s')" % [PRESENTATION_CLASS_STANDARD, PRESENTATION_CLASS_EXCEPTIONAL, presentation_class])
	elif presentation_class == PRESENTATION_CLASS_EXCEPTIONAL and approved_presenter_class == &"":
		errors.append("approved_presenter_class must be set for exceptional presentation_class")
	elif presentation_class == PRESENTATION_CLASS_STANDARD and batch_capacity_requirement <= 0:
		errors.append("batch_capacity_requirement must be positive for standard presentation_class (got %d)" % batch_capacity_requirement)

	if status_mask_schema_version <= 0:
		errors.append("status_mask_schema_version must be positive (got %d)" % status_mask_schema_version)

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
## name. O(n) over animation_clips — mappings carry a small, fixed clip list
## (idle/walk/death, not per-frame data), so a linear scan is not a hot-path
## concern.
func get_animation_clip(clip_name: StringName) -> CreatureAnimationClip:
	for clip: CreatureAnimationClip in animation_clips:
		if clip != null and clip.clip_name == clip_name:
			return clip
	return null

class_name VisualMeshMappingResource
extends Resource

## Data definition mapping a gameplay entity/component type to its 3D visual
## mesh scene (ADR-0037, Epic 15 Story 001).
##
## ADR-0037: Visual Presentation 3D Companion Layer — introduces this
## GameDataRegistry-backed mesh-resolution data type. Follows ADR-0009's
## Resource + GameDataRegistry + validate() convention exactly, mirroring
## RecipeResource (src/core/crafting/recipe_resource.gd) and
## ItemDefinitionResource (src/core/inventory/item_definition_resource.gd).
##
## mesh_scene is a TYPED PackedScene @export (not a String path) — matches
## ItemDefinitionResource.icon: Texture2D's existing precedent for typed
## asset-reference exports. This was an explicit correction during
## ADR-0037's godot-specialist review: a typed export gets Godot's automatic
## UID-based dependency tracking, so moving/renaming the underlying
## .glb-derived scene doesn't silently break the reference the way a raw
## string path would. Do not revert to @export var mesh_scene_path: String.
##
## One .tres per mapped entity/component type, e.g.
## assets/data/visual_meshes/tower_round.tres. Loaded and validated by
## GameDataRegistry at boot alongside every other data Resource — a
## missing/invalid mapping fails boot loudly (push_error, same
## does-not-abort policy as every other GameDataRegistry-loaded type), per
## ADR-0037's Risks section: "rather than silently falling back to
## invisible."
##
## No rendering/scene-tree code lives here — this Story is the data-layer
## foundation only. Instantiating mesh_scene into a MeshInstance3D/
## VisualCompanion3D is Story 002's scope (see ADR-0037's Migration Plan).
##
## Usage:
##   var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(&"tower_round")
##   if mapping == null:
##       push_error("Unknown entity_or_component_id — no 3D visual for this entity.")
##       return
##   var mesh_node: Node3D = mapping.mesh_scene.instantiate() as Node3D

## Gameplay entity or tower-component type this mapping resolves a mesh for
## (e.g. &"tower_round", &"goblin_runner"). Empty StringName is invalid.
@export var entity_or_component_id: StringName = &""

## The 3D visual representation for entity_or_component_id. Typed PackedScene
## export — see class doc comment above for why this is not a String path.
## Null is invalid.
@export var mesh_scene: PackedScene = null


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009
## contract). Returns [] when valid; one string per invalid field otherwise.
## Mirrors RecipeResource.validate()/ItemDefinitionResource.validate()'s
## "empty array = pass" idiom exactly.
##
## Usage:
##   var errors: Array[String] = mapping.validate()
##   for err: String in errors:
##       push_error(err)
func validate() -> Array[String]:
	var errors: Array[String] = []
	if entity_or_component_id == &"":
		errors.append("entity_or_component_id must not be empty")
	if mesh_scene == null:
		errors.append("mesh_scene must be assigned")
	return errors

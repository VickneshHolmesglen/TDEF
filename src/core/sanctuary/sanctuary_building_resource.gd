class_name SanctuaryBuildingResource
extends Resource

## One Sanctuary town building in the OVERVIEW diorama (sanctuary town
## buildings spec, 2026-10-07, §4). Data only: where it stands, which tab it
## opens, and its 5 tier textures (null slots render the growing placeholder).

@export var building_id: StringName = &""
## strings.csv key for the display name (SANCTUARY_BUILDING_*).
@export var name_key: String = ""
## strings.csv key for the "grows with ..." hint (SANCTUARY_BUILDING_*_HINT).
@export var hint_key: String = ""
## Tab-strip target this building opens (TabStrip.TAB_TARGETS); &"" = not clickable.
@export var target_state: StringName = &""
## Bottom-centre of the footprint, in diorama world coordinates.
@export var position: Vector2 = Vector2.ZERO
@export var footprint: Vector2 = Vector2(120, 120)
## Placeholder body colour (until tier art exists).
@export var placeholder_color: Color = Color(0.5, 0.45, 0.4)
## Tier 1..5 art file paths, index 0..4. "" = placeholder for that tier.
## Paths, not textures (2026-10-11, VRAM step B): only the tier on screen is
## ever loaded -- see get_tier_texture().
@export_file("*.png") var tier_texture_paths: Array[String] = ["", "", "", "", ""]
## Loaded-texture cache, filled on demand by get_tier_texture(). A texture
## assigned here directly (tests) wins over the path.
var tier_textures: Array[Texture2D] = [null, null, null, null, null]


## True when tier `tier` (1-based) has art, without loading it.
func has_tier_texture(tier: int) -> bool:
	var i: int = tier - 1
	if i < 0:
		return false
	if i < tier_textures.size() and tier_textures[i] != null:
		return true
	return i < tier_texture_paths.size() and tier_texture_paths[i] != ""


## Tier `tier` (1-based) art, loaded on first request; null = placeholder.
func get_tier_texture(tier: int) -> Texture2D:
	var i: int = tier - 1
	if not has_tier_texture(tier):
		return null
	if tier_textures[i] == null:
		tier_textures[i] = load(tier_texture_paths[i]) as Texture2D
	return tier_textures[i]


## Load-time validation (registry convention: returns error strings).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if building_id == &"":
		errors.append("building_id must not be empty")
	if name_key.is_empty():
		errors.append("name_key must not be empty")
	if footprint.x <= 0.0 or footprint.y <= 0.0:
		errors.append("footprint must be positive")
	if tier_texture_paths.size() != SanctuaryProgress.TIER_COUNT:
		errors.append("tier_texture_paths must have %d slots" % SanctuaryProgress.TIER_COUNT)
	return errors

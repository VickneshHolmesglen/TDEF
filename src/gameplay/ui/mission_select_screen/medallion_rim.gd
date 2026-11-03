class_name MedallionRim
extends RefCounted
## Bronze / silver / gold rim drawn onto a Mission Select medallion for a
## map's best Ascension rank (AscensionRewards.rim_level();
## design/quick-specs/ascension-rewards-2026-11-03.md).
##
## The medallion art sits at a different spot on each mission card's canvas,
## so the rim is fitted to the medallion's visible (non-transparent) area
## (Image.get_used_rect()) and blended onto a copy of the image. Results are
## cached per (texture, level): the card list is rebuilt often, the images
## only once.
##
## Usage:
##   button.icon = MedallionRim.apply(entry.icon, AscensionRewards.rim_level(best_rank))

const RIM_TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/ui/rank_rim_bronze.png"),
	preload("res://assets/art/ui/rank_rim_silver.png"),
	preload("res://assets/art/ui/rank_rim_gold.png"),
]

static var _cache: Dictionary = {}


## `icon` with the rim for `level` (1 bronze, 2 silver, 3 gold) drawn on top;
## `icon` itself for level 0 or a null icon.
static func apply(icon: Texture2D, level: int) -> Texture2D:
	if icon == null or level <= 0:
		return icon
	level = mini(level, RIM_TEXTURES.size())
	var key: String = "%d:%d" % [icon.get_rid().get_id(), level]
	if _cache.has(key):
		return _cache[key]
	var image: Image = _rgba(icon.get_image())
	if image == null:
		return icon
	# Block-compressed art is stored padded to a multiple of 4 (701x561 ->
	# 704x564); crop back so the rimmed copy lays out exactly like the original.
	var size: Vector2i = Vector2i(icon.get_size())
	if image.get_size() != size:
		image.crop(size.x, size.y)
	var used: Rect2i = image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return icon
	var rim: Image = _rgba(RIM_TEXTURES[level - 1].get_image())
	if rim == null:
		return icon
	rim.resize(used.size.x, used.size.y, Image.INTERPOLATE_BILINEAR)
	image.blend_rect(rim, Rect2i(Vector2i.ZERO, used.size), used.position)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## A decompressed RGBA8 copy (card art is VRAM-compressed on import).
static func _rgba(source: Image) -> Image:
	if source == null:
		return null
	var image: Image = source.duplicate() as Image
	if image.is_compressed() and image.decompress() != OK:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image

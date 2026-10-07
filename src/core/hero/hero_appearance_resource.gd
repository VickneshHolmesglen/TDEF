class_name HeroAppearanceResource
extends Resource

## How the hero is drawn with gear on (hero equipment appearance spec,
## 2026-10-07): the base body plus where each shown slot's gear goes.
## Read by HeroAppearance. Fitted overlays (ItemDefinitionResource.
## worn_texture) are full-canvas and need no anchor; the anchors below only
## place the icon fallback for items whose overlay isn't made yet.
##
## Example:
##   var cfg: HeroAppearanceResource = load("res://assets/data/hero/hero_appearance.tres")
##   cfg.icon_anchors["helmet"]  # Vector2(0.49, 0.155), fraction of the base canvas

## The body the gear is layered on. Fitted overlays must share its canvas size.
@export var base_texture: Texture2D = null
## Shown slots, drawn back to front. Slots not listed (neck, rings) never show.
@export var layer_order: Array[String] = ["boots", "pants", "chest", "gloves", "helmet", "offhand", "main_hand"]
## Icon-fallback centre per slot, as a fraction of the base canvas (0..1).
@export var icon_anchors: Dictionary[String, Vector2] = {}
## Icon-fallback height per slot, as a fraction of the base canvas height.
@export var icon_heights: Dictionary[String, float] = {}


## Load-time validation (registry convention: returns error strings).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if base_texture == null:
		errors.append("base_texture must be set")
	for slot: String in layer_order:
		if not Inventory.EQUIPMENT_SLOT_INDEX.has(slot):
			errors.append("unknown slot '%s' in layer_order" % slot)
		if not icon_anchors.has(slot) or not icon_heights.has(slot):
			errors.append("slot '%s' needs an icon anchor and height" % slot)
	return errors

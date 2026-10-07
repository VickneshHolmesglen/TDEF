class_name HeroAppearance
extends Node2D

## Draws the hero's equipped gear on the hero (hero equipment appearance spec,
## 2026-10-07). One component, two hosts:
## - child of the mission hero's Sprite2D (Hero.tscn): copies the sprite's
##   horizontal flip and walk-bob offset, and uses its material so hit/death
##   flashes tint the gear too;
## - child of the Equipment paperdoll's HeroPortrait TextureRect: fits itself
##   to the rect the way STRETCH_KEEP_ASPECT_CENTERED draws the texture.
## Either way it sets its parent's texture to the configured base body, then
## layers one Sprite2D per equipped shown slot: the item's fitted
## `worn_texture` if it has one, else its icon pinned to the slot's anchor.
## Rebuilt on equipment_slot_changed; reads GInventory/GGameDataRegistry only.
##
## Example (what the paperdoll does):
##   var appearance := HeroAppearance.new()
##   portrait.add_child(appearance)   # portrait: TextureRect

const CONFIG_PATH: String = "res://assets/data/hero/hero_appearance.tres"

## Defaults to CONFIG_PATH when left null.
@export var config: HeroAppearanceResource = null

var _layers: Dictionary[String, Sprite2D] = {}
var _sprite_host: Sprite2D = null
var _rect_host: TextureRect = null


func _ready() -> void:
	if config == null:
		config = load(CONFIG_PATH)
	_sprite_host = get_parent() as Sprite2D
	_rect_host = get_parent() as TextureRect
	if config.base_texture != null:
		if _sprite_host != null:
			_sprite_host.texture = config.base_texture
		elif _rect_host != null:
			_rect_host.texture = config.base_texture
	if _rect_host != null:
		_rect_host.resized.connect(_fit_to_rect)
		_fit_to_rect()
	# Only a sprite host changes flip/offset at runtime (HeroFeedback's walk).
	set_process(_sprite_host != null)
	_sync_to_sprite()
	rebuild()
	GEventBus.equipment_slot_changed.connect(_on_equipment_slot_changed)


func _exit_tree() -> void:
	if GEventBus.equipment_slot_changed.is_connected(_on_equipment_slot_changed):
		GEventBus.equipment_slot_changed.disconnect(_on_equipment_slot_changed)


func _process(_delta: float) -> void:
	_sync_to_sprite()


## Re-reads every shown slot and rebuilds the gear layers (back to front).
func rebuild() -> void:
	for layer: Sprite2D in _layers.values():
		layer.queue_free()
	_layers.clear()
	var base_size: Vector2 = _base_size()
	if base_size == Vector2.ZERO:
		return
	for slot: String in config.layer_order:
		var equipped: Dictionary = GInventory.get_equipped_item(slot)
		if equipped.is_empty():
			continue
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(equipped.get("item_id", &"")))
		if definition == null:
			continue
		var layer := _make_layer(slot, definition, base_size)
		if layer != null:
			add_child(layer)
			_layers[slot] = layer


## The gear layer for `slot`, or null when nothing shows there.
func get_layer(slot: String) -> Sprite2D:
	return _layers.get(slot)


## True when `slot` shows a fitted overlay (not the icon fallback).
func is_fitted(slot: String) -> bool:
	var layer: Sprite2D = _layers.get(slot)
	return layer != null and layer.has_meta(&"fitted")


func _make_layer(slot: String, definition: ItemDefinitionResource, base_size: Vector2) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.name = "Gear_%s" % slot
	layer.use_parent_material = true
	if definition.worn_texture != null:
		# Same canvas as the base by contract; scale per axis if it isn't.
		layer.texture = definition.worn_texture
		layer.scale = base_size / Vector2(definition.worn_texture.get_size())
		layer.set_meta(&"fitted", true)
		return layer
	if definition.icon == null:
		return null
	var anchor: Vector2 = config.icon_anchors.get(slot, Vector2(0.5, 0.5))
	var height_fraction: float = config.icon_heights.get(slot, 0.15)
	layer.texture = definition.icon
	layer.position = (anchor - Vector2(0.5, 0.5)) * base_size  # host draws the base centred
	layer.scale = Vector2.ONE * (height_fraction * base_size.y / float(definition.icon.get_height()))
	return layer


func _base_size() -> Vector2:
	var texture: Texture2D = null
	if _sprite_host != null:
		texture = _sprite_host.texture
	elif _rect_host != null:
		texture = _rect_host.texture
	elif config.base_texture != null:
		texture = config.base_texture
	return Vector2(texture.get_size()) if texture != null else Vector2.ZERO


## Sprite host: mirror around the sprite's own centre and follow its offset,
## exactly how Sprite2D draws a centred, flip_h'd texture.
func _sync_to_sprite() -> void:
	if _sprite_host == null:
		return
	position = _sprite_host.offset
	scale = Vector2(-1.0 if _sprite_host.flip_h else 1.0, 1.0)


## Rect host: base-canvas coords -> the rect, keep-aspect, centred.
func _fit_to_rect() -> void:
	var base_size: Vector2 = _base_size()
	if _rect_host == null or base_size == Vector2.ZERO:
		return
	var fit: float = minf(_rect_host.size.x / base_size.x, _rect_host.size.y / base_size.y)
	position = _rect_host.size * 0.5
	scale = Vector2.ONE * fit


func _on_equipment_slot_changed(_slot: String, _new_item_id: String, _previous_item_id: String) -> void:
	rebuild()

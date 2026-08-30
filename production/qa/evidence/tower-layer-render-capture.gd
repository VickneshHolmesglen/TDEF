extends Node

## Reusable render-evidence harness for the processed tower layer pipeline.
## Run from the project root with the pinned Godot binary:
## Godot.exe --path . res://production/qa/evidence/TowerLayerRenderCapture.tscn

const TOWER_SCENE: PackedScene = preload("res://src/core/tower/TowerInstance.tscn")
const OUTPUT_DIR: String = "res://production/qa/evidence"
const VIEWPORT_SIZE: Vector2i = Vector2i(960, 800)
const BACKGROUND_COLOR: Color = Color("241a32")
const PANEL_COLOR: Color = Color("42344f")
const GRID_COLOR: Color = Color("766587")
const LABEL_COLOR: Color = Color("f4e8cf")
const CAPTURE_ZOOM: float = 2.0

const SHAPE_CASES: Array[Dictionary] = [
	{"label": "Round / Archer", "archetype": "physical", "element": "", "foundation": "found_archer_t1", "weapon": "weap_archer_t1"},
	{"label": "Square / Bulwark", "archetype": "physical", "element": "", "foundation": "found_bulwark_t2", "weapon": "weap_bulwark_t2"},
	{"label": "Stump / Rally", "archetype": "support", "element": "", "foundation": "found_rally_t1", "weapon": "weap_rally_t1"},
	{"label": "Stone / Venom", "archetype": "elemental", "element": "poison", "foundation": "found_venomdart_t1", "weapon": "weap_venomdart_t1"},
	{"label": "Octagon / Arcane", "archetype": "elemental", "element": "arcane", "foundation": "found_arcane_t3", "weapon": "weap_basic"},
	{"label": "Tiered / Standard", "archetype": "support", "element": "", "foundation": "found_standard_t3", "weapon": "weap_standard_t3"},
	{"label": "Scallop / Frost", "archetype": "elemental", "element": "frost", "foundation": "found_frostbolt_t1", "weapon": "weap_basic"},
	{"label": "Triangle / Longshot", "archetype": "ranged", "element": "", "foundation": "found_longshot_t1", "weapon": "weap_longshot_t1"},
	{"label": "Hex-plank / Siege", "archetype": "physical", "element": "", "foundation": "found_siege_t4", "weapon": "weap_basic"},
]

const WEAPON_CASES: Array[Dictionary] = [
	{"label": "Siege cannon", "archetype": "physical", "element": "", "foundation": "found_siege_t4", "weapon": "weap_siege_t4"},
	{"label": "Railgun laser", "archetype": "ranged", "element": "", "foundation": "found_railgun_t4", "weapon": "weap_railgun_t4"},
	{"label": "Arcane lance", "archetype": "elemental", "element": "arcane", "foundation": "found_arcane_t3", "weapon": "weap_arcane_t3"},
	{"label": "Storm emitter", "archetype": "elemental", "element": "lightning", "foundation": "found_storm_t2", "weapon": "weap_storm_t2"},
	{"label": "Firestorm emitter", "archetype": "elemental", "element": "fire", "foundation": "found_firestorm_t4", "weapon": "weap_firestorm_t4"},
	{"label": "Frost emitter", "archetype": "elemental", "element": "frost", "foundation": "found_frostbolt_t1", "weapon": "weap_frostbolt_t1"},
]


func _ready() -> void:
	await _warm_up_renderer()
	await _capture_sheet(SHAPE_CASES, 3, "tower-layer-shape-families.png", "Nine matched families — 64-unit runtime geometry at 2x inspection zoom")
	await _capture_sheet(WEAPON_CASES, 3, "tower-layer-weapon-tops.png", "Six weapon crowns — 64-unit runtime geometry at 2x inspection zoom")
	get_tree().quit()


func _warm_up_renderer() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(8, 8)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	var marker: ColorRect = ColorRect.new()
	marker.color = Color.WHITE
	marker.size = Vector2(8.0, 8.0)
	viewport.add_child(marker)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.queue_free()
	await get_tree().process_frame


func _capture_sheet(cases: Array[Dictionary], columns: int, file_name: String, title: String) -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	get_tree().root.add_child(viewport)

	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.size = Vector2(VIEWPORT_SIZE)
	background.z_index = -100
	viewport.add_child(background)

	var title_label: Label = _make_label(title, 22)
	title_label.position = Vector2(24.0, 14.0)
	title_label.size = Vector2(900.0, 34.0)
	title_label.z_index = 100
	viewport.add_child(title_label)
	var tower_canvas: CanvasLayer = CanvasLayer.new()
	tower_canvas.layer = 10
	viewport.add_child(tower_canvas)

	var rows: int = ceili(float(cases.size()) / float(columns))
	var cell_size: Vector2 = Vector2(300.0, 230.0 if rows >= 3 else 340.0)
	var origin: Vector2 = Vector2(25.0, 62.0)
	for index: int in cases.size():
		var column: int = index % columns
		var row: int = index / columns
		var cell_position: Vector2 = origin + Vector2(float(column) * cell_size.x, float(row) * cell_size.y)
		_add_case(viewport, tower_canvas, cases[index], cell_position, cell_size)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var error: Error = image.save_png(OUTPUT_DIR.path_join(file_name))
	if error != OK:
		push_error("Tower evidence capture failed for %s: %s" % [file_name, error_string(error)])
	viewport.queue_free()
	await get_tree().process_frame


func _add_case(viewport: SubViewport, tower_canvas: CanvasLayer, data: Dictionary,
		cell_position: Vector2, cell_size: Vector2) -> void:
	var panel: ColorRect = ColorRect.new()
	panel.color = PANEL_COLOR
	panel.position = cell_position
	panel.size = cell_size - Vector2(12.0, 12.0)
	panel.z_index = -10
	viewport.add_child(panel)

	var ground_line: ColorRect = ColorRect.new()
	ground_line.color = GRID_COLOR
	var ground_y: float = cell_size.y - 55.0
	ground_line.position = cell_position + Vector2(16.0, ground_y)
	ground_line.size = Vector2(cell_size.x - 44.0, 1.0)
	ground_line.z_index = 1
	viewport.add_child(ground_line)

	var label: Label = _make_label(data["label"] as String, 16)
	label.position = cell_position + Vector2(8.0, ground_y + 8.0)
	label.size = Vector2(cell_size.x - 28.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 20
	viewport.add_child(label)

	var tower: TowerInstance = TOWER_SCENE.instantiate() as TowerInstance
	tower.position = cell_position + Vector2((cell_size.x - 12.0) * 0.5,
			ground_y - TowerInstance.TARGET_DISPLAY_HEIGHT * 0.5 * CAPTURE_ZOOM)
	tower.z_index = 10
	tower_canvas.add_child(tower)
	tower.configure(data["archetype"] as String, data["element"] as String,
			data["foundation"] as String, data["weapon"] as String)
	_add_render_proxies(viewport, tower)
	tower.visible = false


## SubViewport capture does not consistently draw the nested production
## CanvasItem subtree on the pinned Windows headless/offscreen renderer. These
## proxies flatten the live TowerInstance's resolved textures and computed
## layer transforms solely for evidence capture. CAPTURE_ZOOM is applied after
## the production transform, so runtime geometry remains exactly 64 units.
func _add_render_proxies(viewport: SubViewport, tower: TowerInstance) -> void:
	var sprites: Array[Sprite2D] = [tower._base_sprite, tower._shaft_sprite, tower._top_sprite]
	for index: int in sprites.size():
		var source: Sprite2D = sprites[index]
		var proxy: TextureRect = TextureRect.new()
		proxy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		proxy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		proxy.texture = source.texture
		var rendered_size: Vector2 = source.texture.get_size() * tower._layer_root.scale * CAPTURE_ZOOM
		proxy.position = tower.position + source.position * tower._layer_root.scale * CAPTURE_ZOOM - rendered_size * 0.5
		proxy.size = rendered_size
		proxy.z_index = 10 + index
		viewport.add_child(proxy)


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", LABEL_COLOR)
	return label

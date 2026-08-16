class_name PlanningCluster
extends Control

## Planning Cluster scaffold (Story 002, TR-hud-000, ADR-0031).
##
## GDD source: design/gdd/mission-hud.md — Core Rules Group 2 (Rules 5-8).
## Instantiated fresh from PlanningCluster.tscn on every SCOUT/INTERMISSION
## mount, torn down (remove_child() then queue_free(), never queue_free()
## alone) on every WAVE_ACTIVE entry — owned by MissionHud (Story 002's own
## MissionHud extension).
##
## This story owns only the phase-gated interactivity toggle (Rule 6's
## PRE_WAVE partial-interactivity requirement, set_pre_wave_interactivity())
## and the empty scaffold structure. Stories 003-007 fill in the actual
## content of each element below (route-preview overlay, blocked-cell
## highlight, Tower Build Panel, boss-lane telegraph marker, wave-composition
## display) — none of that rendering logic belongs here.

## Story 003 (TR-hud-001, PC-1): fires whenever this instance recomputes its
## own route (in response to path_invalidated) — MissionHud (the outer root)
## listens so its "last-known route" cache (Rule 11) stays in sync for the
## NEXT Planning Cluster mount, without this node needing a reference back
## to its own parent.
signal route_updated(routes: Array)

@onready var _ready_button: Button = $ReadyButton
## Story 010: Sell has its own phase+selection-driven visibility (AC-52),
## decoupled from NonReadyControls' group-level disable — it must actually
## disappear during PRE_WAVE, not just become non-interactive, so it's a
## sibling of NonReadyControls rather than a child of it.
@onready var _sell_button: Button = $SellButton
## Everything except Ready/Sell — build list, cell overlay/cursor.
## During PRE_WAVE, every child of this container becomes non-interactive
## (Rule 6) without being destroyed or hidden.
@onready var _non_ready_controls: Control = $NonReadyControls
## Holds one Line2D per SPAWN cell's rendered route (Story 003, Rules 9-11).
@onready var _route_overlay_host: Node2D = $RouteOverlayHost
## Holds one marker per blocked cell from the most recent tower_placement_blocked (Story 004, Rule 12).
@onready var _blocked_cell_host: Node2D = $BlockedCellHost
## Holds the single boss-lane telegraph marker, if any (Story 006, Rule 11c).
## PC-1's own spec (mission-hud.md line 262): Scout Blue (Art Bible 2.2,
## #2D5F8A) at ~40-55% opacity, static, no glow/pulse. render_route() never
## applied this -- the Line2D was left at Godot's stock default_color (opaque
## white), which read fine against the old flat-color grid fill but stood out
## as an unstyled placeholder once real terrain art landed (2026-08-08's
## terrain pass). Fixed here; the GDD's other PC-1 requirements (dashed/
## painted stroke, directional chevrons at turn points) are still open --
## logged as TD-hud-002, a separate rendering-technique task, not bundled
## into this color/opacity fix.
const ROUTE_PREVIEW_COLOR: Color = Color(0x2D / 255.0, 0x5F / 255.0, 0x8A / 255.0, 0.48)
const ROUTE_PREVIEW_WIDTH: float = 3.0
@onready var _boss_telegraph_host: Node2D = $BossTelegraphHost
## Holds the wave-composition preview lines (Story 007, Rules 11f-11i).
@onready var _composition_preview_host: VBoxContainer = $CompositionPreviewHost

## Tower Build Panel (tower.md's Visual/Audio Requirements, mission-hud.md's
## Zone E) -- one tile per GGameDataRegistry.get_all_tower_blueprints() entry.
## Added 2026-08-10: this list was the one Planning Cluster element the GDD
## named but no prior story had implemented -- placement was previously a
## hardcoded single-blueprint debug click in mission_scene.gd/the_gap.gd.
## Redesigned 2026-08-11 from a vertical list of full-text rows to a row of
## square icon-only tiles (HBoxContainer) -- cost/footprint/DPS/perk details
## moved to each tile's tooltip_text, shown on hover, instead of always-on
## row text.
##
## Player-reported 2026-08-16: a single-row HBoxContainer ran off the right
## edge of the screen once the registry had more blueprints than fit in
## 1280px (the 6th tile was fully offscreen) -- redesigned to a 3-column
## GridContainer inside a fixed-size ScrollContainer (BuildListScroll),
## anchored top-left instead of bottom-right, so the list grows downward
## and scrolls instead of running off-screen sideways.
@onready var _build_list: GridContainer = $NonReadyControls/BuildListScroll/BuildList
const TILE_SIZE: Vector2 = Vector2(48, 48)
const TILE_ICON_MARGIN: float = 12.0
## Player-reported 2026-08-16: default theme buttons read as too translucent
## against the busy rock-textured mission backdrop -- explicit near-opaque
## styleboxes per button state make the tile face read clearly regardless
## of what's rendered behind it.
const TILE_BG_NORMAL: Color = Color(0.13, 0.14, 0.17, 0.96)
const TILE_BG_HOVER: Color = Color(0.20, 0.22, 0.27, 0.98)
const TILE_BG_PRESSED: Color = Color(0.09, 0.10, 0.12, 0.98)
const TILE_BG_DISABLED: Color = Color(0.13, 0.14, 0.17, 0.7)
## Grid Placement Cursor (design/ux/interaction-patterns.md's own pattern) --
## a single footprint-sized rect that follows the mouse while a blueprint is
## selected, colored by TowerSystem.get_placement_preview()'s own validity
## result. This node never calls TowerSystem itself (Mission HUD holds no
## direct gameplay-system reference anywhere else in this file either) --
## the mission scene computes the preview and forwards it via
## tower_placement_preview_updated, the same decoupling
## _on_tower_placement_blocked() already uses for the blocked-cell markers.
@onready var _placement_cursor: ColorRect = $NonReadyControls/PlacementCursor
const PLACEMENT_VALID_COLOR: Color = Color(0.2, 0.85, 0.3, 0.35)
const PLACEMENT_INVALID_COLOR: Color = Color(0.9, 0.2, 0.2, 0.35)

## Translucent drag-preview of the tower actually being placed (2026-08-10,
## player-requested addition) — layered on top of PlacementCursor's own
## valid/invalid tint so the cursor communicates both "which tower" and
## "would this placement succeed" at once. Uses the exact same per-archetype
## art and uniform-scale-by-height logic as TowerInstance.configure() so the
## preview matches what the tower will actually look like once placed.
@onready var _placement_preview_icon: TextureRect = $NonReadyControls/PlacementPreviewIcon
## Tracked locally (not read from mission_scene.gd/the_gap.gd) so this stays
## a pure EventBus-driven listener like every other host in this file —
## set the instant this cluster's own tile is pressed, cleared whenever the
## cursor hides (deselected or placement completes).
var _preview_blueprint_id: StringName = &""

var _build_buttons: Dictionary[StringName, Button] = {}
var _build_button_group := ButtonGroup.new()

## MonsterResource.tier index -> display bucket name (matches MissionHud's
## BOSS_TIER=2 comment: 0=STANDARD 1=ELITE 2=BOSS). Fixed engine-side vocabulary,
## not game-balance data — not a gameplay-code-rules violation to keep local.
const TIER_NAMES: Array[String] = ["STANDARD", "ELITE", "BOSS"]

## cell_size is a fixed project-wide constant (mission-select.md's OQ-4
## resolution, registered in design/registry/entities.yaml) — not a local
## guess. Used only to size the blocked-cell highlight markers.
const CELL_SIZE_PX: float = 64.0

## Shared world->screen conversion for this file's 3 screen-space overlays
## (route-preview Line2D, blocked-cell markers, boss-lane telegraph marker).
## See render_route()'s own comment for the real timing bug found 2026-08-09
## in how this gets called on the very first render.
func _world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos

## Test hook (AC-9/AC-12): true once _exit_tree() has actually run, proving
## the synchronous remove_child()-then-queue_free() teardown sequence
## disconnected this instance before a replacement could connect.
var _exit_tree_fired: bool = false

## Story 008 (ADR-0011): handed down by MissionHud right after instantiate()
## via set_input_mode_tracker() — not available yet inside this node's own
## _ready() (add_child() fires _ready() before the caller's next line runs),
## so the focus-ring's initial state/connection is established there instead.
var _input_mode_tracker: InputModeTracker = null
var _ready_focus_ring: Panel = null

const READY_LABEL: String = "Ready"
const SKIP_LABEL: String = "Skip Countdown"  ## AC-42 — exact copy is a UX Spec concern, this is a placeholder

## Story 010: -1 = no tower currently inspected (sentinel, matches this
## story's own Implementation Notes). Tower Info Panel selection mechanics
## themselves are out of scope — this cluster only reads/holds the id.
var _inspected_tower_id: int = -1
var _is_pre_wave: bool = false
var _sell_focus_ring: Panel = null


func _ready() -> void:
	GEventBus.path_invalidated.connect(_on_path_invalidated)
	GEventBus.tower_placement_blocked.connect(_on_tower_placement_blocked)
	_ready_button.pressed.connect(_on_ready_pressed)
	_build_ready_focus_ring()
	_ready_button.focus_entered.connect(_update_ready_focus_ring)
	_ready_button.focus_exited.connect(_update_ready_focus_ring)
	_sell_button.pressed.connect(_on_sell_pressed)
	_build_sell_focus_ring()
	_sell_button.focus_entered.connect(_update_sell_focus_ring)
	_sell_button.focus_exited.connect(_update_sell_focus_ring)
	_update_sell_button_existence()
	GEventBus.resources_changed.connect(_on_resources_changed)
	GEventBus.tower_placement_preview_updated.connect(_on_tower_placement_preview_updated)
	_build_tower_list()
	# TextureRect's default expand_mode (EXPAND_KEEP_SIZE) makes its minimum
	# size equal the texture's native resolution, and Control.set_size()
	# clamps up to minimum size -- without this, _update_placement_preview_
	# icon()'s manually-computed small preview size gets silently overridden
	# back to the tower art's full native resolution (found live via MCP:
	# a 36x64 target rendered as 858x1003, covering most of the grid).
	_placement_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_placement_preview_icon.stretch_mode = TextureRect.STRETCH_SCALE


func _exit_tree() -> void:
	if GEventBus.path_invalidated.is_connected(_on_path_invalidated):
		GEventBus.path_invalidated.disconnect(_on_path_invalidated)
	if GEventBus.tower_placement_blocked.is_connected(_on_tower_placement_blocked):
		GEventBus.tower_placement_blocked.disconnect(_on_tower_placement_blocked)
	if _input_mode_tracker != null and _input_mode_tracker.input_mode_changed.is_connected(_update_ready_focus_ring):
		_input_mode_tracker.input_mode_changed.disconnect(_update_ready_focus_ring)
	if _input_mode_tracker != null and _input_mode_tracker.input_mode_changed.is_connected(_update_sell_focus_ring):
		_input_mode_tracker.input_mode_changed.disconnect(_update_sell_focus_ring)
	if GEventBus.resources_changed.is_connected(_on_resources_changed):
		GEventBus.resources_changed.disconnect(_on_resources_changed)
	if GEventBus.tower_placement_preview_updated.is_connected(_on_tower_placement_preview_updated):
		GEventBus.tower_placement_preview_updated.disconnect(_on_tower_placement_preview_updated)
	_exit_tree_fired = true


# ---------------------------------------------------------------------------
# Story 008 (Rules 16-18, Rules 23-24): Ready Button + InputModeTracker wiring.
# ---------------------------------------------------------------------------

## AC-41: fires synchronously, no HUD-side phase guard — Wave Manager is the
## sole authority (defense in depth pattern, same as Sell/Ultimate). AC-44:
## a stray press in the one-frame lag before this instance's own teardown is
## a non-issue by design (Wave Manager already silently ignores player_ready
## during WAVE_ACTIVE) — no debounce needed here.
func _on_ready_pressed() -> void:
	GEventBus.player_ready.emit()


## AC-43: instanced once at MissionHud's root, shared across this epic's
## focusable controls — this cluster only holds a reference, connects to its
## input_mode_changed signal, and disconnects on its own teardown (_exit_tree()).
func set_input_mode_tracker(tracker: InputModeTracker) -> void:
	_input_mode_tracker = tracker
	_input_mode_tracker.input_mode_changed.connect(_update_ready_focus_ring)
	_input_mode_tracker.input_mode_changed.connect(_update_sell_focus_ring)
	_update_ready_focus_ring()
	_update_sell_focus_ring()


## Overlay child of ReadyButton, gated on has_focus() AND
## tracker.is_focus_ring_visible() — never merged into one boolean (ADR-0011),
## matching inventory_screen.gd's established FocusRing pattern.
func _build_ready_focus_ring() -> void:
	_ready_focus_ring = FocusRingFactory.build(_ready_button)


func _update_ready_focus_ring(_arg: Variant = null) -> void:
	if _input_mode_tracker == null:
		return
	_ready_focus_ring.visible = _ready_button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


## Story 004 (Rule 12, PC-2): highlights blocked_cells to indicate the
## rejected footprint. AC-20/AC-21: primary_blocking_cell's sentinel
## (Vector2i(-1,-1)) branches between "one cell anchors attention" and
## "uniform, no single load-bearing cell" — both driven by the same event,
## a single function, never two independently-drifting code paths. No phase
## guard (AC-22) — tower_placement_blocked can only fire during SCOUT/
## INTERMISSION, enforced upstream by Tower/Pathfinding.
func _on_tower_placement_blocked(blocked_cells: Array, primary_blocking_cell: Vector2i) -> void:
	for child: Node in _blocked_cell_host.get_children():
		_blocked_cell_host.remove_child(child)
		child.queue_free()
	for cell: Vector2i in blocked_cells:
		var marker := ColorRect.new()
		var is_primary: bool = primary_blocking_cell != Vector2i(-1, -1) and cell == primary_blocking_cell
		marker.color = Color(1.0, 0.85, 0.0, 0.9) if is_primary else Color(1.0, 0.2, 0.2, 0.5)
		marker.size = Vector2(CELL_SIZE_PX, CELL_SIZE_PX)
		var world_pos: Vector2 = GGrid.cell_to_world(cell) - Vector2(CELL_SIZE_PX, CELL_SIZE_PX) * 0.5
		marker.position = _world_to_screen(world_pos)
		marker.set_meta("cell", cell)
		marker.set_meta("is_primary", is_primary)
		_blocked_cell_host.add_child(marker)


## Story 006 (Rule 11c, AC-30): renders the boss-lane telegraph marker at
## cell, or clears it if cell is the sentinel. Called by MissionHud (the
## outer root) whenever it caches a new value from wave_preview_available
## (Story 006's own AC-28) or hands off to a freshly-spawned instance.
func set_boss_telegraph_cell(cell: Vector2i) -> void:
	for child: Node in _boss_telegraph_host.get_children():
		_boss_telegraph_host.remove_child(child)
		child.queue_free()
	if cell == Vector2i(-1, -1):
		return
	var marker := ColorRect.new()
	marker.color = Color(0.494, 0.180, 0.722, 0.7)  # Boss Purple (#7E2EB8), art-bible reference
	marker.size = Vector2(CELL_SIZE_PX, CELL_SIZE_PX)
	var world_pos: Vector2 = GGrid.cell_to_world(cell)
	marker.position = _world_to_screen(world_pos) - marker.size * 0.5
	marker.set_meta("cell", cell)
	_boss_telegraph_host.add_child(marker)


## AC-14: re-derives the route via find_path() — NEVER renders affected_cells
## (the union of changed-walkability cells, a tower's footprint) directly as
## a route line. AC-17/AC-18: no phase guard here by construction — this
## instance does not exist during WAVE_ACTIVE (Story 002's teardown), so it
## structurally cannot receive path_invalidated in that phase; PRE_WAVE is
## treated identically to INTERMISSION simply by having no special case for it.
func _on_path_invalidated(_affected_cells: Array) -> void:
	var routes: Array = []
	for spawn_cell: Vector2i in GGrid.get_spawn_cells():
		routes.append(GPathfindingSystem.find_path(spawn_cell, 0))
	render_route(routes)
	route_updated.emit(routes)


## Renders one Line2D per route, screen-space via Grid.cell_to_world()
## composed with the viewport's canvas transform (matching ADR-0031's own
## established cell-to-screen conversion for this CanvasLayer-hosted HUD).
##
## Clears prior children via synchronous remove_child() before queue_free()
## — the same double-connected/stale-state bug class ADR-0031's own
## engine-specialist review caught in the Planning Cluster's swap sequence:
## queue_free() alone defers removal to end-of-frame, so a second
## render_route() call within the same frame (e.g. templates_ready
## immediately followed by a path_invalidated) would see the old, not-yet-
## freed children still present.
func render_route(routes: Array) -> void:
	for child: Node in _route_overlay_host.get_children():
		_route_overlay_host.remove_child(child)
		child.queue_free()
	for route: Array in routes:
		var line := Line2D.new()
		line.default_color = ROUTE_PREVIEW_COLOR
		line.width = ROUTE_PREVIEW_WIDTH
		for cell: Vector2i in route:
			var world_pos: Vector2 = GGrid.cell_to_world(cell)
			line.add_point(_world_to_screen(world_pos))
		_route_overlay_host.add_child(line)


## Story 007 (Rules 11f-11i, PC-5 composition half): dispatches to the full
## per-monster breakdown (SCOUT, AC-36) or the tier-bucketed summary
## (INTERMISSION, AC-35). current_planning_phase is the phase this specific
## instance was (re)instantiated into (MissionHud's _current_phase at mount
## time, handed down synchronously) — never re-derived from composition's own
## shape (AC-37). AC-38: this instance's host starts empty by construction
## every mount, so no explicit clear-before-first-render is needed here; the
## clear inside each render helper only guards a second wave_preview_available
## arriving within the same mount (should not happen per Rule 11h, but keeps
## this symmetric with render_route()/_on_tower_placement_blocked()'s own
## clear-then-repopulate pattern).
func render_composition_preview(composition: Array, current_planning_phase: String) -> void:
	if current_planning_phase == "SCOUT":
		_render_full_breakdown(composition)  # AC-36
	else:  # INTERMISSION
		_render_tier_bucketed(composition)  # AC-35


## AC-35: one line per non-zero tier bucket (never a bucket with count 0),
## e.g. 2 lines for "10 STANDARD, 2 ELITE" when no BOSS entry is present.
func _render_tier_bucketed(composition: Array) -> void:
	_clear_composition_preview_host()
	var totals: Dictionary[String, int] = {"STANDARD": 0, "ELITE": 0, "BOSS": 0}
	for entry: Dictionary in composition:
		var resource: MonsterResource = GGameDataRegistry.get_monster_resource(entry["monster_id"])
		if resource == null:
			continue
		totals[TIER_NAMES[resource.tier]] += entry["count"] as int
	for tier_name: String in TIER_NAMES:
		if totals[tier_name] > 0:
			var label := Label.new()
			label.text = "%d %s" % [totals[tier_name], tier_name]
			_composition_preview_host.add_child(label)


## AC-36: one line per WaveSpawnEntry-aggregated composition entry, resolved
## to display_name — NO tier aggregation, full information per tower.md
## Rule 8's "complete information" mandate for SCOUT's Wave 1 preview.
func _render_full_breakdown(composition: Array) -> void:
	_clear_composition_preview_host()
	for entry: Dictionary in composition:
		var resource: MonsterResource = GGameDataRegistry.get_monster_resource(entry["monster_id"])
		if resource == null:
			continue
		var label := Label.new()
		label.text = "%s x%d" % [resource.display_name, entry["count"] as int]
		_composition_preview_host.add_child(label)


func _clear_composition_preview_host() -> void:
	for child: Node in _composition_preview_host.get_children():
		_composition_preview_host.remove_child(child)
		child.queue_free()


## AC-10: Ready remains interactive; every other child in this cluster
## becomes non-interactive. Reversed automatically on the next SCOUT/
## INTERMISSION mount, since a fresh instance always starts fully
## interactive by construction (never called with is_pre_wave=false
## explicitly — a new instance simply never enters this state).
func set_pre_wave_interactivity(is_pre_wave: bool) -> void:
	_ready_button.text = SKIP_LABEL if is_pre_wave else READY_LABEL  # AC-42
	_is_pre_wave = is_pre_wave
	_update_sell_button_existence()  # AC-52 — Sell disappears during PRE_WAVE regardless of selection
	for child: Node in _non_ready_controls.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = is_pre_wave
		elif child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE if is_pre_wave else Control.MOUSE_FILTER_STOP
	# Build list buttons are nested one level under NonReadyControls (inside
	# BuildList), so the direct-children loop above never reaches them --
	# without this, PRE_WAVE's "every child becomes non-interactive" (Rule 6)
	# would leave tower entries clickable during the one phase placement must
	# be blocked in. can_afford()'s own disabled state (_refresh_affordability())
	# is restored automatically on the next resources_changed/mount, so this
	# only needs to force `true` here, never force `false`.
	if is_pre_wave:
		for button: Button in _build_buttons.values():
			button.disabled = true
	else:
		_refresh_affordability()


# ---------------------------------------------------------------------------
# Story 010 (Rules 21-22): Sell Button.
# ---------------------------------------------------------------------------

## AC-52: exists (visible) only outside PRE_WAVE AND while a tower is
## inspected. Called by set_pre_wave_interactivity() and set_inspected_tower()
## — the two independent axes this AC gates on.
func _update_sell_button_existence() -> void:
	_sell_button.visible = not _is_pre_wave and _inspected_tower_id != -1


## Public setter for the (out-of-scope, assumed-external) Tower Info Panel
## selection state — this story only reads/holds the id, per its own scope note.
func set_inspected_tower(tower_id: int) -> void:
	_inspected_tower_id = tower_id
	_update_sell_button_existence()


## AC-53: synchronous, current tower_id. AC-54: clears the Info Panel
## selection optimistically (i.e. this cluster's own knowledge of it) — does
## NOT remove the tower visually or touch any counter; that only happens on
## the separate, later tower_removed confirmation (Tower System's job, not
## this story's). AC-55: no HUD-side "one sell at a time" guard — a second,
## different tower_id can be inspected and sold immediately after, both
## tower_sell_requested calls independently in flight.
func _on_sell_pressed() -> void:
	GEventBus.tower_sell_requested.emit(_inspected_tower_id)
	set_inspected_tower(-1)


func _build_sell_focus_ring() -> void:
	_sell_focus_ring = FocusRingFactory.build(_sell_button)


func _update_sell_focus_ring(_arg: Variant = null) -> void:
	if _input_mode_tracker == null:
		return
	_sell_focus_ring.visible = _sell_button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


# ---------------------------------------------------------------------------
# Tower Build Panel (tower.md Visual/Audio Requirements, mission-hud.md Zone E)
# ---------------------------------------------------------------------------

## Sorted by placement_cost (matches Defense Building's/Inventory's own
## established "cheapest/earliest first" list-ordering precedent) — populated
## once per mount, same as every other Planning Cluster host in this file.
func _build_tower_list() -> void:
	var blueprints: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	var blueprint_ids: Array = blueprints.keys()
	blueprint_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return (blueprints[a] as TowerBlueprintData).placement_cost < (blueprints[b] as TowerBlueprintData).placement_cost
	)
	for blueprint_id: StringName in blueprint_ids:
		var data: TowerBlueprintData = blueprints[blueprint_id] as TowerBlueprintData
		var button := Button.new()
		button.name = "Tower_%s" % String(blueprint_id)
		# Icon-only tile (2026-08-11, replacing the original full-text row) —
		# details (cost/footprint/DPS/perk) move to tooltip_text, shown on
		# hover via Godot's own built-in Control tooltip, rather than always
		# rendering as a wide text row.
		button.custom_minimum_size = TILE_SIZE
		button.tooltip_text = _blueprint_entry_text(data)
		_apply_tile_style(button)
		# GDD ("archetype icon...") — reuses the same real per-archetype art
		# tower_instance.gd already displays on the placed tower itself
		# (assets/art/towers/), added 2026-08-11. This list was originally
		# shipped text-only on the (incorrect) assumption that no tower art
		# existed at all in the project yet — it did, just not wired here.
		var icon: Texture2D = TowerInstance.ARCHETYPE_TEXTURES.get(data.foundation.archetype)
		if icon != null:
			button.icon = icon
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", int(TILE_SIZE.x - TILE_ICON_MARGIN))
		# Player-reported 2026-08-16: icons were reading off-center inside the
		# tile face. Button's default alignment is LEFT (a leftover from the
		# now-removed text-row layout, see this loop's own icon-only-redesign
		# comment above) -- with an empty button.text, that pushes the icon
		# toward the tile's left edge instead of centering it in the square
		# face. Explicit center alignment on all 3 axes Button exposes.
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.button_group = _build_button_group
		button.pressed.connect(_on_tower_button_pressed.bind(blueprint_id))
		_build_list.add_child(button)
		_build_buttons[blueprint_id] = button
	_refresh_affordability()


## Near-opaque per-state styleboxes (see TILE_BG_* constants' own doc
## comment) so each tile reads clearly against the busy rock-textured
## mission backdrop instead of blending into it under the default theme.
func _apply_tile_style(button: Button) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var style := StyleBoxFlat.new()
		match state:
			&"hover":
				style.bg_color = TILE_BG_HOVER
			&"pressed":
				style.bg_color = TILE_BG_PRESSED
			&"disabled":
				style.bg_color = TILE_BG_DISABLED
			_:
				style.bg_color = TILE_BG_NORMAL
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		button.add_theme_stylebox_override(state, style)


## GDD ("archetype icon, estimated DPS, placement cost, footprint size,
## pre-placement perk indicator") — the icon is the tile's face
## (_build_tower_list() above); this text is the tile's tooltip_text
## instead of always-visible row text, per the tile-icon-plus-hover-detail
## redesign (2026-08-11). AURA weapons (Rally Banner) show their buff
## instead of a DPS number, since "8 DPS" would misdescribe a support aura
## that deals no damage.
func _blueprint_entry_text(data: TowerBlueprintData) -> String:
	var footprint: Vector2i = data.foundation.footprint
	var effect_tag: String
	if data.weapon.projectile_type == "AURA":
		effect_tag = "Aura: %s +%d%%" % [data.weapon.aura_effect_type, int(data.weapon.aura_effect_value * 100.0)]
	else:
		effect_tag = "DPS: %.1f" % (data.weapon.weapon_damage * data.weapon.attack_speed)
	var perk_tag: String = " · Perk" if data.foundation.pre_placement_perk != "" else ""
	return "%s — %dg — %dx%d — %s%s" % [data.display_name, data.placement_cost, footprint.x, footprint.y, effect_tag, perk_tag]


## Selecting an entry is the only way to arm the Grid Placement Cursor
## (design/ux/mission-hud.md line 267: "Entry highlights; placement cursor
## activates") — the mission scene (owner of the real TowerSystem) is the
## sole consumer of this signal; this cluster never calls TowerSystem itself.
func _on_tower_button_pressed(blueprint_id: StringName) -> void:
	_preview_blueprint_id = blueprint_id
	GEventBus.tower_blueprint_selected.emit(blueprint_id)


## Re-checks every row's affordability whenever gold changes (SCOUT/
## INTERMISSION only — this instance doesn't exist during WAVE_ACTIVE).
## GMissionEconomy is called directly here (not derived from resources_
## changed's own payload) since that payload's delta-vs-absolute semantics
## are inconsistent between emitters (TowerSystem's own class doc claims
## "signed deltas," Mission HUD's _on_resources_changed() instead treats it
## as absolute — a pre-existing discrepancy, not something this addition
## should build new behavior on top of). can_afford() is GMissionEconomy's
## own public read API, already called directly by TowerSystem's Gate 2 —
## calling it here too matches this codebase's established precedent of UI
## screens reading their own domain Autoload directly (e.g. Defense Building
## screen's is_tech_unlocked()/can_unlock_tech() calls).
func _on_resources_changed(_gold: int, _source: StringName) -> void:
	_refresh_affordability()


func _refresh_affordability() -> void:
	var blueprints: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	for blueprint_id: StringName in _build_buttons:
		var data: TowerBlueprintData = blueprints[blueprint_id] as TowerBlueprintData
		_build_buttons[blueprint_id].disabled = not GMissionEconomy.can_afford(data.placement_cost)


## Grid Placement Cursor (design/ux/interaction-patterns.md) — repositions/
## recolors the single footprint-sized rect to the hovered cell. cell ==
## Vector2i(-1, -1) (no blueprint selected, mirrors set_boss_telegraph_cell's
## identical sentinel convention) hides the cursor entirely.
func _on_tower_placement_preview_updated(cell: Vector2i, footprint: Vector2i, valid: bool) -> void:
	if cell == Vector2i(-1, -1):
		_placement_cursor.visible = false
		_placement_preview_icon.visible = false
		_preview_blueprint_id = &""
		return
	_placement_cursor.visible = true
	_placement_cursor.color = PLACEMENT_VALID_COLOR if valid else PLACEMENT_INVALID_COLOR
	_placement_cursor.size = Vector2(footprint.x, footprint.y) * CELL_SIZE_PX
	var world_pos: Vector2 = GGrid.cell_to_world(cell) - Vector2(CELL_SIZE_PX, CELL_SIZE_PX) * 0.5
	_placement_cursor.position = _world_to_screen(world_pos)
	_update_placement_preview_icon()


## Looks up the selected blueprint's archetype art and sizes/centers it
## within the cursor's footprint box, mirroring TowerInstance.configure()'s
## uniform-scale-by-height so the preview matches the placed tower's look.
func _update_placement_preview_icon() -> void:
	var blueprints: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	var data: TowerBlueprintData = blueprints.get(_preview_blueprint_id) as TowerBlueprintData
	if data == null:
		_placement_preview_icon.visible = false
		return
	var texture: Texture2D = TowerInstance.ARCHETYPE_TEXTURES.get(data.foundation.archetype)
	if texture == null:
		_placement_preview_icon.visible = false
		return
	_placement_preview_icon.texture = texture
	var uniform_scale: float = TowerInstance.TARGET_DISPLAY_HEIGHT / float(texture.get_height())
	var icon_size: Vector2 = Vector2(texture.get_width(), texture.get_height()) * uniform_scale
	_placement_preview_icon.size = icon_size
	var cursor_center: Vector2 = _placement_cursor.position + _placement_cursor.size * 0.5
	_placement_preview_icon.position = cursor_center - icon_size * 0.5
	_placement_preview_icon.visible = true

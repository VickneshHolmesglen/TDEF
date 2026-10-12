class_name ShellChromeStyle
extends RefCounted

## Shared visual constants for the game's UI chrome (Story 013 originally;
## restyled 2026-10-12 for the HD-2D UI skin, ADR-0042).
##
## Two layers:
##   * StyleBoxFlat builders (chrome_panel_stylebox, chrome_button_stylebox,
##     ...) -- kept because many screens take the box and mutate it (border
##     colour on selection, background tint). Restyled HD-2D: deep navy, thin
##     gold/bronze rule, square pixel corners, hard drop shadow.
##   * Textured 9-slice frames (skin_panel, skin_button, skin_focus) from
##     assets/ui/skin/ (tools/asset-pipeline/hd2d/generate_ui_skin.py): the
##     full ornamented look, used wherever a box is applied unmodified, and by
##     the project theme (Hd2dTheme).

const UI_CHROME: Color = Color(0x18 / 255.0, 0x1B / 255.0, 0x28 / 255.0)      # #181B28 deep navy
const UI_PARCHMENT: Color = Color(0xEA / 255.0, 0xE0 / 255.0, 0xC8 / 255.0)   # #EAE0C8
## Navigation / selection accent. Gold since the HD-2D skin (was cyan #23A8D4).
const UI_ACCENT: Color = Color(0xD8 / 255.0, 0xB0 / 255.0, 0x64 / 255.0)     # #D8B064
## Secondary highlight that must stay distinct from the gold accent and the
## gold keyboard-focus ring (e.g. the crafting "would consume" slot preview).
const UI_HIGHLIGHT: Color = Color(0x23 / 255.0, 0xA8 / 255.0, 0xD4 / 255.0)  # #23A8D4
const UI_WARNING_ORANGE: Color = Color(0xF5 / 255.0, 0x92 / 255.0, 0x1A / 255.0) # #F5921A
## Rules and borders: bronze at rest, gold when lit.
const UI_RULE: Color = Color(0x84 / 255.0, 0x68 / 255.0, 0x3C / 255.0)       # #84683C
const UI_RULE_LIT: Color = Color(0xCE / 255.0, 0xA8 / 255.0, 0x60 / 255.0)   # #CEA860

## Square pixel corners: the skin is pixel art, so no rounded radius.
const CHAMFER_PX: int = 0
## Border thickness of the flat boxes, in screen px (the skin's 2x pixel).
const RULE_PX: int = 2

## Motion contract: snappy-in <=120ms / eased-out settle 150-200ms, no
## overshoot (GDD Visual/Audio Requirements, reused from Mission HUD).
const MOTION_SNAPPY_IN_SEC: float = 0.12
const MOTION_SETTLE_SEC: float = 0.18

const SKIN_DIR: String = "res://assets/ui/skin/"
## 9-slice margins of the generated skin, in texture px.
const PANEL_SLICE: int = 12
const BUTTON_SLICE: int = 8


static func _base_flat(bg: Color, border: Color, border_px: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.anti_aliasing = false
	box.set_corner_radius_all(CHAMFER_PX)
	if border_px > 0:
		box.set_border_width_all(border_px)
		box.border_color = border
	return box


static func chrome_panel_stylebox() -> StyleBoxFlat:
	var box := _base_flat(Color(UI_CHROME, 0.94), UI_RULE, RULE_PX)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 1
	box.shadow_offset = Vector2(3, 3)
	return box


## Resource header background (Story 004, updated 2026-08-04): the gold-
## trimmed header art (design/art/asset-UI-prompt.md), 9-sliced so the
## corner flourish stays fixed-size while the flat middle stretches to fill
## whatever width the header spans. Texture margins are in the *processed*
## asset's own pixel space (assets/art/ui/sanctuary_header_gold.png was
## downscaled to 350x80 specifically for this use -- see that file's history
## -- not the original 1386x317 generation output, which is far too
## high-resolution for a 9-slice margin to stay under HEADER_HEIGHT).
static func resource_header_stylebox() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = preload("res://assets/art/ui/sanctuary_header_gold.png")
	box.texture_margin_left = 30
	box.texture_margin_right = 30
	box.texture_margin_top = 26
	box.texture_margin_bottom = 26
	return box


static func chrome_button_stylebox(active: bool) -> StyleBoxFlat:
	# Active state keeps the filled-vs-outline convention (never colour-only):
	# warm amber fill with a lit gold rule when active, navy with a bronze rule
	# otherwise.
	if active:
		return _base_flat(Color(0x8C / 255.0, 0x5E / 255.0, 0x24 / 255.0), UI_RULE_LIT, RULE_PX)
	return _base_flat(Color(0x24 / 255.0, 0x27 / 255.0, 0x36 / 255.0), UI_RULE, RULE_PX)


static func focus_ring_stylebox() -> StyleBoxFlat:
	var box := _base_flat(Color(0, 0, 0, 0), UI_ACCENT, 3)
	box.draw_center = false
	return box


static func badge_stylebox() -> StyleBoxFlat:
	return _base_flat(UI_WARNING_ORANGE, Color(0.1, 0.06, 0.02), RULE_PX)


## Launch/Depart button (design/ux/sanctuary-ui.md's Component Inventory:
## "Primary action button"). Sanctum Amber (#C8801A) -- the art bible's own
## warm-action color, reserved for each screen's single most consequential
## action.
const LAUNCH_AMBER: Color = Color(0xC8 / 255.0, 0x80 / 255.0, 0x1A / 255.0)  # #C8801A


static func launch_button_stylebox() -> StyleBoxFlat:
	var box := _base_flat(LAUNCH_AMBER, Color(0xF6 / 255.0, 0xD8 / 255.0, 0x8C / 255.0), RULE_PX)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


# --- Textured skin (9-slice) ---------------------------------------------------

static func _skin(file: String, slice: int, content: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(SKIN_DIR + file) as Texture2D
	box.texture_margin_left = slice
	box.texture_margin_right = slice
	box.texture_margin_top = slice
	box.texture_margin_bottom = slice
	box.content_margin_left = content
	box.content_margin_right = content
	box.content_margin_top = content
	box.content_margin_bottom = content
	return box


## Ornamented panel: navy, double gold rule, corner studs. Slightly
## translucent by default (menus); `solid` for always-on HUD panels that sit
## over live scenery, where see-through would hurt legibility.
static func skin_panel(solid: bool = false) -> StyleBoxTexture:
	return _skin("panel_solid.png" if solid else "panel.png", PANEL_SLICE, 12)


## Recessed well for lists, bags and text areas.
static func skin_inset() -> StyleBoxTexture:
	return _skin("inset.png", BUTTON_SLICE, 8)


## Button frame for a state: &"normal", &"hover", &"pressed", &"disabled",
## or &"active" (selected tab / primary choice).
static func skin_button(state: StringName = &"normal") -> StyleBoxTexture:
	var box := _skin("button_%s.png" % state, BUTTON_SLICE, 8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box


## skin_button() for the old boolean "active" convention.
static func skin_button_for(active: bool) -> StyleBoxTexture:
	return skin_button(&"active" if active else &"normal")


static func skin_focus() -> StyleBoxTexture:
	var box := _skin("focus.png", BUTTON_SLICE, 0)
	box.draw_center = false
	return box


## Textured primary-action button (Launch / Depart): the amber "active" frame
## with launch_button_stylebox()'s generous padding.
static func skin_launch(state: StringName = &"active") -> StyleBoxTexture:
	var box := skin_button(state)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

class_name ShellChromeStyle
extends RefCounted

## Shared visual constants for Sanctuary UI's shell chrome (Story 013, GDD
## Visual/Audio Requirements). Colors are the project's own real, already-
## committed UI Chrome/Parchment/Accent palette (design/art/art-bible.md
## Section on UI colors) -- not invented for this story. Reused wholesale
## from Mission HUD's own established screen-space language per the GDD's
## own explicit instruction ("chrome is a frame, not a painting").

const UI_CHROME: Color = Color(0x25 / 255.0, 0x2D / 255.0, 0x3D / 255.0)      # #252D3D
const UI_PARCHMENT: Color = Color(0xDD / 255.0, 0xD4 / 255.0, 0xB0 / 255.0)   # #DDD4B0
const UI_ACCENT_CYAN: Color = Color(0x23 / 255.0, 0xA8 / 255.0, 0xD4 / 255.0) # #23A8D4
const UI_WARNING_ORANGE: Color = Color(0xF5 / 255.0, 0x92 / 255.0, 0x1A / 255.0) # #F5921A

## GDD Visual/Audio Requirements: "chamfered-rectangle shape grammar" --
## corner_radius on a StyleBoxFlat is Godot's closest built-in primitive to a
## chamfer without a custom shader; kept small and uniform, never a full
## pill/rounded-rect look.
const CHAMFER_PX: int = 4

## Motion contract: snappy-in <=120ms / eased-out settle 150-200ms, no
## overshoot (GDD Visual/Audio Requirements, reused from Mission HUD).
const MOTION_SNAPPY_IN_SEC: float = 0.12
const MOTION_SETTLE_SEC: float = 0.18


static func chrome_panel_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UI_CHROME
	box.set_corner_radius_all(CHAMFER_PX)
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
	var box := StyleBoxFlat.new()
	# Active-tab state reuses the filled-vs-outline actionable convention
	# (never color-only) -- filled Accent Cyan when active, outlined Chrome
	# otherwise.
	if active:
		box.bg_color = UI_ACCENT_CYAN
	else:
		box.bg_color = UI_CHROME
		box.border_width_left = 2
		box.border_width_right = 2
		box.border_width_top = 2
		box.border_width_bottom = 2
		box.border_color = UI_PARCHMENT
	box.set_corner_radius_all(CHAMFER_PX)
	return box


static func focus_ring_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_width_left = 3
	box.border_width_right = 3
	box.border_width_top = 3
	box.border_width_bottom = 3
	box.border_color = UI_ACCENT_CYAN
	box.set_corner_radius_all(CHAMFER_PX)
	return box


static func badge_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UI_WARNING_ORANGE
	box.set_corner_radius_all(CHAMFER_PX)
	return box


## Launch/Depart button (design/ux/sanctuary-ui.md's Component Inventory:
## "Primary action button... Fully-chamfered primary-action button per art
## bible's UI shape family"). Sanctum Amber (#C8801A) -- the art bible's own
## warm-action color, distinct from the tab strip's Accent Cyan (navigation)
## and the badge's Warning Orange (notification) -- reserved here for this
## screen's single most consequential action.
const LAUNCH_AMBER: Color = Color(0xC8 / 255.0, 0x80 / 255.0, 0x1A / 255.0)  # #C8801A


static func launch_button_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = LAUNCH_AMBER
	box.set_corner_radius_all(CHAMFER_PX)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

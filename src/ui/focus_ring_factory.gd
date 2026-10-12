class_name FocusRingFactory
extends RefCounted

## Shared builder for the ADR-0011 focus-ring overlay pattern (InventoryScreen,
## Mission HUD's Ready/Sell/Ultimate/Retry buttons). Extracted during Mission
## HUD's deferred batch code review (2026-07-20) — the same ~15-line
## StyleBoxFlat construction was duplicated 4 times across mission_hud.gd and
## planning_cluster.gd.

## Matches the HD-2D skin's focus frame (assets/ui/skin/focus.png, bright gold).
const FOCUS_RING_COLOR: Color = Color(0.96, 0.85, 0.55, 1.0)


## Builds a full-rect bordered Panel, adds it as owner's child, and returns it.
## Caller is responsible for wiring visibility (has_focus() AND
## InputModeTracker.is_focus_ring_visible()) — this factory only builds and
## parents the Control, matching every existing call site's own responsibility
## split.
static func build(owner: Control) -> Panel:
	var ring := Panel.new()
	ring.name = "FocusRing"
	# HD-2D skin (2026-10-12): the textured gold double-rule focus frame.
	var ring_style: StyleBoxTexture = ShellChromeStyle.skin_focus()
	ring.add_theme_stylebox_override("panel", ring_style)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(ring)
	return ring

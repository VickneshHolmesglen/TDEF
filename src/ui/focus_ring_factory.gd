class_name FocusRingFactory
extends RefCounted

## Shared builder for the ADR-0011 focus-ring overlay pattern (InventoryScreen,
## Mission HUD's Ready/Sell/Ultimate/Retry buttons). Extracted during Mission
## HUD's deferred batch code review (2026-07-20) — the same ~15-line
## StyleBoxFlat construction was duplicated 4 times across mission_hud.gd and
## planning_cluster.gd.

const FOCUS_RING_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)  ## placeholder — art-director TBD


## Builds a full-rect bordered Panel, adds it as owner's child, and returns it.
## Caller is responsible for wiring visibility (has_focus() AND
## InputModeTracker.is_focus_ring_visible()) — this factory only builds and
## parents the Control, matching every existing call site's own responsibility
## split.
static func build(owner: Control) -> Panel:
	var ring := Panel.new()
	ring.name = "FocusRing"
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	ring_style.border_width_left = 3
	ring_style.border_width_right = 3
	ring_style.border_width_top = 3
	ring_style.border_width_bottom = 3
	ring_style.border_color = FOCUS_RING_COLOR
	ring.add_theme_stylebox_override("panel", ring_style)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(ring)
	return ring

class_name ButtonFeedbackBinder
extends Node

## Auto-hooks every button in the tree (`Button` and `TextureButton` alike, e.g. the Main Menu's
## art plates; checkboxes and toggle switches are skipped) with tactile feedback: a small scale-up while hovered or
## focused (mouse and gamepad alike) and a quick press punch. The visual sibling of
## `UiAudioBinder`, which gives the same buttons their click sounds.
##
## Opt out per button (e.g. a button that already runs its own scale tween) with
## `button.set_meta(ButtonFeedbackBinder.META_KEY, ButtonFeedbackBinder.KIND_NONE)`.
## Honors `ReduceMotion`: with reduced motion on, no scale changes are applied.
##
## Usage: `var binder := ButtonFeedbackBinder.new(); add_child(binder); binder.setup(get_tree())`

const META_KEY: StringName = &"ui_feedback"
const KIND_NONE: StringName = &"none"

const HOVER_SCALE: float = 1.04
const PRESS_SCALE: float = 0.94
## Pixel caps on how far a button may grow/shrink along its longer side, so a full-width list row
## gets a subtle nudge instead of spilling ~40 px past the screen edges (seen live on Mission
## Select). Small buttons are unaffected: the percentage limit is the binding one for them.
const MAX_HOVER_GROWTH_PX: float = 12.0
const MAX_PRESS_SHRINK_PX: float = 18.0
const HOVER_DURATION: float = 0.08
const PRESS_DURATION: float = 0.06
const RELEASE_DURATION: float = 0.18

const _HOOKED_META: StringName = &"_ui_feedback_hooked"
const _TWEEN_META: StringName = &"_ui_feedback_tween"

var _tree: SceneTree
## Focus only counts as "hovered" while the player is driving the UI with keyboard/gamepad. With
## the mouse in use the focus ring is hidden, and an enlarged-but-unpointed button reads as a bug.
var _using_mouse: bool = false


## Hooks every button already under `tree.root` and every one added later.
func setup(tree: SceneTree) -> void:
	_tree = tree
	if not _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.connect(_on_node_added)
	_hook_existing(_tree.root)


## The scale a button of `size` should rest at for its current hover/focus state.
static func rest_scale(hovered: bool, size: Vector2 = Vector2.ZERO) -> Vector2:
	if not hovered:
		return Vector2.ONE
	var longest: float = maxf(size.x, size.y)
	var factor: float = HOVER_SCALE if longest <= 0.0 else minf(HOVER_SCALE, 1.0 + MAX_HOVER_GROWTH_PX / longest)
	return Vector2.ONE * factor


## The momentary press scale for a button of `size`.
static func press_scale(size: Vector2) -> Vector2:
	var longest: float = maxf(size.x, size.y)
	var factor: float = PRESS_SCALE if longest <= 0.0 else maxf(PRESS_SCALE, 1.0 - MAX_PRESS_SHRINK_PX / longest)
	return Vector2.ONE * factor


## True for the button kinds that get feedback: everything but checkbox/toggle-switch controls,
## where scaling the whole row reads as noise rather than a press.
static func is_eligible(node: Node) -> bool:
	return node is BaseButton and not (node is CheckBox or node is CheckButton)


func _hook_existing(node: Node) -> void:
	if is_eligible(node):
		_hook(node as BaseButton)
	for child: Node in node.get_children(true):
		_hook_existing(child)


func _hook(button: BaseButton) -> void:
	if button.has_meta(_HOOKED_META):
		return
	button.set_meta(_HOOKED_META, true)
	# Bound callables keep a reference to the button only through the button's own signals, so
	# they die with it: no registry to prune, nothing to disconnect on the button's side.
	button.mouse_entered.connect(_on_hover.bind(button, true))
	button.mouse_exited.connect(_on_hover.bind(button, false))
	button.focus_entered.connect(_on_hover.bind(button, true))
	button.focus_exited.connect(_on_hover.bind(button, false))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func _wants_feedback(button: BaseButton) -> bool:
	if ReduceMotion.enabled() or not button.is_inside_tree() or button.disabled:
		return false
	return not (button.has_meta(META_KEY) and StringName(button.get_meta(META_KEY)) == KIND_NONE)


func _is_hovered(button: BaseButton) -> bool:
	return button.is_hovered() or (button.has_focus() and not _using_mouse)


## Tracks the active input device; on a switch, re-settles the focused button so it grows or
## shrinks to match whether its focus is now meaningful.
func _input(event: InputEvent) -> void:
	var mouse: bool
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		mouse = false
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		mouse = false  # ignore stick drift below a deliberate push
	else:
		return
	if mouse == _using_mouse:
		return
	_using_mouse = mouse
	var viewport: Viewport = get_viewport()
	var focused: Control = viewport.gui_get_focus_owner() if viewport != null else null
	if focused != null and focused.has_meta(_HOOKED_META):
		_on_hover(focused as BaseButton, false)


func _on_hover(button: BaseButton, _entered: bool) -> void:
	if _wants_feedback(button):
		_tween_to(button, rest_scale(_is_hovered(button), button.size), HOVER_DURATION, Tween.TRANS_SINE)
	elif button.is_inside_tree() and button.has_meta(_TWEEN_META):
		# Became disabled/opted-out mid-hover: settle back rather than stay enlarged.
		_tween_to(button, Vector2.ONE, HOVER_DURATION, Tween.TRANS_SINE)


func _on_button_down(button: BaseButton) -> void:
	if _wants_feedback(button):
		_tween_to(button, press_scale(button.size), PRESS_DURATION, Tween.TRANS_SINE)


func _on_button_up(button: BaseButton) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	if _wants_feedback(button) or button.has_meta(_TWEEN_META):
		_tween_to(button, rest_scale(_is_hovered(button), button.size), RELEASE_DURATION, Tween.TRANS_BACK)


func _tween_to(button: BaseButton, target: Vector2, duration: float, trans: Tween.TransitionType) -> void:
	var previous: Variant = button.get_meta(_TWEEN_META) if button.has_meta(_TWEEN_META) else null
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", target, duration).set_trans(trans).set_ease(Tween.EASE_OUT)
	button.set_meta(_TWEEN_META, tween)


func _on_node_added(node: Node) -> void:
	if is_eligible(node):
		_hook(node as BaseButton)


func _exit_tree() -> void:
	if _tree != null and _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)

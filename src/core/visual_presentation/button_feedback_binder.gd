class_name ButtonFeedbackBinder
extends Node

## Auto-hooks every `Button` in the tree with tactile feedback: a small scale-up while hovered or
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
const HOVER_DURATION: float = 0.08
const PRESS_DURATION: float = 0.06
const RELEASE_DURATION: float = 0.18

const _HOOKED_META: StringName = &"_ui_feedback_hooked"
const _TWEEN_META: StringName = &"_ui_feedback_tween"

var _tree: SceneTree


## Hooks every button already under `tree.root` and every one added later.
func setup(tree: SceneTree) -> void:
	_tree = tree
	if not _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.connect(_on_node_added)
	_hook_existing(_tree.root)


## The scale a button should rest at for its current hover/focus state.
static func rest_scale(hovered: bool) -> Vector2:
	return Vector2.ONE * (HOVER_SCALE if hovered else 1.0)


func _hook_existing(node: Node) -> void:
	if node is Button:
		_hook(node as Button)
	for child: Node in node.get_children(true):
		_hook_existing(child)


func _hook(button: Button) -> void:
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


func _wants_feedback(button: Button) -> bool:
	if ReduceMotion.enabled() or not button.is_inside_tree() or button.disabled:
		return false
	return not (button.has_meta(META_KEY) and StringName(button.get_meta(META_KEY)) == KIND_NONE)


func _is_hovered(button: Button) -> bool:
	return button.is_hovered() or button.has_focus()


func _on_hover(button: Button, _entered: bool) -> void:
	if _wants_feedback(button):
		_tween_to(button, rest_scale(_is_hovered(button)), HOVER_DURATION, Tween.TRANS_SINE)
	elif button.is_inside_tree() and button.has_meta(_TWEEN_META):
		# Became disabled/opted-out mid-hover: settle back rather than stay enlarged.
		_tween_to(button, Vector2.ONE, HOVER_DURATION, Tween.TRANS_SINE)


func _on_button_down(button: Button) -> void:
	if _wants_feedback(button):
		_tween_to(button, Vector2.ONE * PRESS_SCALE, PRESS_DURATION, Tween.TRANS_SINE)


func _on_button_up(button: Button) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	if _wants_feedback(button) or button.has_meta(_TWEEN_META):
		_tween_to(button, rest_scale(_is_hovered(button)), RELEASE_DURATION, Tween.TRANS_BACK)


func _tween_to(button: Button, target: Vector2, duration: float, trans: Tween.TransitionType) -> void:
	var previous: Variant = button.get_meta(_TWEEN_META) if button.has_meta(_TWEEN_META) else null
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", target, duration).set_trans(trans).set_ease(Tween.EASE_OUT)
	button.set_meta(_TWEEN_META, tween)


func _on_node_added(node: Node) -> void:
	if node is Button:
		_hook(node as Button)


func _exit_tree() -> void:
	if _tree != null and _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)

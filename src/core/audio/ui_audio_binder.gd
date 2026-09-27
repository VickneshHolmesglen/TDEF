class_name UiAudioBinder
extends Node

## Auto-hooks every `BaseButton` in the tree and dispatches UI audio cues
## (click / confirm / cancel / denial) through an injected dispatch callable.
##
## Spec: docs/superpowers/specs/2026-09-27-ui-audio-cues-design.md §3-§4.
##
## Per-button override: set node meta `ui_audio` to `KIND_CONFIRM`,
## `KIND_CANCEL` or `KIND_NONE`; absent means an ordinary click. Example:
## `button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CONFIRM)`.
##
## A disabled `BaseButton` emits no `pressed`, so denial is detected from
## `gui_input` and `button.disabled` is read at press time, never cached.

const META_KEY: StringName = &"ui_audio"
const KIND_CONFIRM: StringName = &"confirm"
const KIND_CANCEL: StringName = &"cancel"
const KIND_NONE: StringName = &"none"
const CUE_CLICK: StringName = &"ui_click"
const CUE_CONFIRM: StringName = &"ui_confirm"
const CUE_CANCEL: StringName = &"ui_cancel"
const CUE_DENIED: StringName = &"ui_denied"

## Lazy prune: sweep entries of destroyed buttons once `_hooks` has grown by
## this many since the last sweep (buttons leaving the tree keep their hook,
## so pruning is keyed on real destruction, not tree exit).
const PRUNE_INTERVAL: int = 64

const _HOOKED_META: StringName = &"_ui_audio_hooked"

var _dispatch: Callable
var _tree: SceneTree
## button instance id -> [pressed Callable, gui_input Callable], kept so
## `_exit_tree()` disconnects exactly what was connected (EventBus Rule 6).
var _hooks: Dictionary[int, Array] = {}
var _last_pruned_size: int = 0


## Maps a button's `ui_audio` meta value to a cue name. `none` -> `&""`
## (no cue); null or any unknown value -> `CUE_CLICK`.
static func cue_for(kind: Variant) -> StringName:
	if kind is StringName or kind is String:
		match StringName(kind):
			KIND_CONFIRM:
				return CUE_CONFIRM
			KIND_CANCEL:
				return CUE_CANCEL
			KIND_NONE:
				return &""
	return CUE_CLICK


## `dispatch` has signature `(cue: StringName)`. Hooks every button already in
## `tree.root` and every one that enters later.
func setup(dispatch: Callable, tree: SceneTree) -> void:
	_dispatch = dispatch
	_tree = tree
	if not _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.connect(_on_node_added)
	_hook_existing(_tree.root)


func hooked_count() -> int:
	return _hooks.size()


func _hook_existing(node: Node) -> void:
	if node is BaseButton:
		_hook(node as BaseButton)
	for child: Node in node.get_children(true):
		_hook_existing(child)


func _hook(button: BaseButton) -> void:
	if button.has_meta(_HOOKED_META):
		return
	button.set_meta(_HOOKED_META, true)
	var on_pressed: Callable = _on_pressed.bind(button)
	var on_input: Callable = _on_gui_input.bind(button)
	button.pressed.connect(on_pressed)
	button.gui_input.connect(on_input)
	_hooks[button.get_instance_id()] = [on_pressed, on_input]
	if _hooks.size() > _last_pruned_size + PRUNE_INTERVAL:
		_prune()


## Erases entries whose button has been freed.
func _prune() -> void:
	for id: int in _hooks.keys():
		if not is_instance_valid(instance_from_id(id)):
			_hooks.erase(id)
	_last_pruned_size = _hooks.size()


func _on_pressed(button: BaseButton) -> void:
	# get_meta() with a null default still logs an engine error for a missing key, so test has_meta first.
	var kind: Variant = button.get_meta(META_KEY) if button.has_meta(META_KEY) else null
	var cue: StringName = cue_for(kind)
	if cue != &"" and _dispatch.is_valid():
		_dispatch.call(cue)


func _on_gui_input(event: InputEvent, button: BaseButton) -> void:
	if not button.disabled:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _dispatch.is_valid():
		_dispatch.call(CUE_DENIED)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_hook(node as BaseButton)


func _exit_tree() -> void:
	_cleanup()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup()


func _cleanup() -> void:
	if _tree != null and _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)
	for id: int in _hooks:
		var obj: Object = instance_from_id(id)
		if obj == null or not is_instance_valid(obj):
			continue
		var button: BaseButton = obj as BaseButton
		if button == null:
			continue
		var pair: Array = _hooks[id]
		if button.pressed.is_connected(pair[0]):
			button.pressed.disconnect(pair[0])
		if button.gui_input.is_connected(pair[1]):
			button.gui_input.disconnect(pair[1])
		button.remove_meta(_HOOKED_META)
	_hooks.clear()
	_last_pruned_size = 0

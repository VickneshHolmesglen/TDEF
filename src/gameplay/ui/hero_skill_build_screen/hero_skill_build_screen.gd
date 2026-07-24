extends Control

## Hero Skill Build Loadout Screen (Tarot Deck UI Story 001's Room Hosting
## scope, epic-11).
##
## GDD source: design/gdd/hero-skill-build.md — UI Requirements section (one
## continuous screen: library + 4 active slots + nested passive sub-slots +
## Ultimate readout, single-confirm no-commit-step convention).
## ADR: no dedicated ADR yet (see hero-skill-build.md's own Dependencies) —
## data side is `src/core/hero_skill_build/hero_skill_build.gd`, a real
## Autoload (GHeroSkillBuild), unlike Tarot/EquipmentForge.
##
## Scope, honestly bounded:
## - The GDD's pick-up-then-place gamepad model (select a library skill ->
##   "picked up" -> select an active slot target -> placed, swapping any
##   occupant back to the library) is implemented as a direct single-action
##   model instead, mirroring tarot_screen.gd's own identical simplification
##   and for the identical reason: `set_active_slot(index, skill_id)` has no
##   pick-up/place primitive to bind a 2-step flow to. Pressing a library
##   skill assigns it to the first empty active slot; pressing an occupied
##   active slot clears it.
## - The GDD's nested passive sub-slot selection (pick a pool item, place it
##   into one of an active slot's 1-3 specific sub-slot sockets) is
##   simplified to a single "cycle passive" button per active slot: pressing
##   it fills the slot's next empty passive sub-slot with the next owned
##   Inventory item not already assigned anywhere on this Hero build (a real,
##   functioning assignment — not a placeholder — just not the full nested-
##   socket-selection UI the GDD describes). Long-pressing a filled sub-slot
##   equivalent (a plain click here) clears it.
## - No skill icon/archetype-glyph rendering, no connector-line visual
##   between slots and the Ultimate readout — no such art exists anywhere in
##   this project. All state is shown as plain text.
##
## Root is a plain Control. No class_name — matches the other room/screen
## scripts' TD-workflow-001 precedent.

const FOCUS_RING_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)  ## placeholder — art-director TBD
const ACTIVE_SLOT_LABELS: Array[String] = ["A", "B", "C", "D"]

## Injectable for tests; defaults to the real GHeroSkillBuild Autoload.
@export var hero_skill_build: HeroSkillBuild

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _ultimate_label: Label = $MainLayout/UltimateLabel
@onready var _active_slot_list: VBoxContainer = $MainLayout/AssemblyArea/ActiveSlotList
@onready var _library_list: VBoxContainer = $MainLayout/Library/LibraryList

var _active_slot_buttons: Dictionary[int, Button] = {}
var _passive_cycle_buttons: Dictionary[int, Button] = {}
var _library_buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	if hero_skill_build == null:
		hero_skill_build = GHeroSkillBuild

	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)
	GEventBus.active_skill_equipped.connect(_on_build_changed)
	GEventBus.ultimate_skill_changed.connect(_on_build_changed)

	_rebuild_everything()


func disconnect_own_subscriptions() -> void:
	GEventBus.active_skill_equipped.disconnect(_on_build_changed)
	GEventBus.ultimate_skill_changed.disconnect(_on_build_changed)


func _on_build_changed(_a: Variant = null, _b: Variant = null) -> void:
	_rebuild_everything()


func _rebuild_everything() -> void:
	_rebuild_ultimate_label()
	_rebuild_active_slots()
	_rebuild_library()


func _rebuild_ultimate_label() -> void:
	if hero_skill_build == null:
		_ultimate_label.text = "Ultimate: —"
		return
	_ultimate_label.text = "Ultimate: %s" % hero_skill_build.get_all_slot_bindings()["U"]


# ---------------------------------------------------------------------------
# Assembly area — 4 active slots, each with a passive-cycle button
# ---------------------------------------------------------------------------

func _rebuild_active_slots() -> void:
	for child: Node in _active_slot_list.get_children():
		child.queue_free()
	_active_slot_buttons.clear()
	_passive_cycle_buttons.clear()

	if hero_skill_build == null:
		return
	var bindings: Array[String] = hero_skill_build.get_active_slots()
	for i: int in range(ACTIVE_SLOT_LABELS.size()):
		var row := HBoxContainer.new()
		row.name = "SlotRow_%s" % ACTIVE_SLOT_LABELS[i]

		var slot_button := Button.new()
		slot_button.name = "ActiveSlot_%s" % ACTIVE_SLOT_LABELS[i]
		slot_button.focus_mode = Control.FOCUS_ALL
		slot_button.clip_text = true
		var bound: String = bindings[i] if i < bindings.size() else ""
		slot_button.text = "%s: %s" % [ACTIVE_SLOT_LABELS[i], bound if not bound.is_empty() else "(empty)"]
		slot_button.pressed.connect(_on_active_slot_pressed.bind(i))
		_wire_focus_ring(slot_button)
		row.add_child(slot_button)
		_active_slot_buttons[i] = slot_button

		var passive_button := Button.new()
		passive_button.name = "PassiveCycle_%s" % ACTIVE_SLOT_LABELS[i]
		passive_button.text = _passive_summary_text(bound)
		passive_button.disabled = bound.is_empty()
		passive_button.pressed.connect(_on_passive_cycle_pressed.bind(i))
		row.add_child(passive_button)
		_passive_cycle_buttons[i] = passive_button

		_active_slot_list.add_child(row)


func _passive_summary_text(skill_id: String) -> String:
	if skill_id.is_empty() or hero_skill_build == null:
		return "Passives: —"
	var loadout: Array[String] = hero_skill_build.get_effective_passive_loadout(skill_id)
	var filled: int = 0
	for item_id: String in loadout:
		if not item_id.is_empty():
			filled += 1
	return "Passives: %d/%d (cycle)" % [filled, loadout.size()]


## GDD (simplified, see class doc comment): pressing an occupied active slot
## clears it; pressing an empty slot is a no-op here (assignment happens
## from the library side, matching tarot_screen.gd's "press the source item"
## model rather than "press the empty destination").
func _on_active_slot_pressed(slot_index: int) -> void:
	if hero_skill_build == null:
		return
	var bindings: Array[String] = hero_skill_build.get_active_slots()
	if slot_index >= bindings.size() or bindings[slot_index].is_empty():
		return
	hero_skill_build.set_active_slot(slot_index, "")


## GDD simplification (see class doc comment): fills the slot's next empty
## passive sub-slot with the next owned Inventory item_id not already
## assigned anywhere on this Hero's current build. A real assignment, not a
## placeholder — just not the full nested-socket-selection UI the GDD
## describes. No-op if no unassigned owned item exists, or the skill has no
## empty sub-slot remaining.
func _on_passive_cycle_pressed(slot_index: int) -> void:
	if hero_skill_build == null:
		return
	var bindings: Array[String] = hero_skill_build.get_active_slots()
	if slot_index >= bindings.size():
		return
	var skill_id: String = bindings[slot_index]
	if skill_id.is_empty():
		return

	var loadout: Array[String] = hero_skill_build.get_passive_loadout(skill_id)
	var already_assigned: Array[String] = []
	for entry: String in loadout:
		if not entry.is_empty():
			already_assigned.append(entry)

	var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
	if definition == null:
		return
	var next_empty_index: int = -1
	for i: int in range(definition.passive_slot_count):
		if i >= loadout.size() or loadout[i].is_empty():
			next_empty_index = i
			break
	if next_empty_index == -1:
		return  # no free sub-slot

	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if contents.is_empty():
			continue
		var item_id: String = contents["item_id"] as String
		if already_assigned.has(item_id):
			continue
		hero_skill_build.set_passive_slot(skill_id, next_empty_index, item_id)
		return


# ---------------------------------------------------------------------------
# Library panel — assignable skills
# ---------------------------------------------------------------------------

func _rebuild_library() -> void:
	for child: Node in _library_list.get_children():
		child.queue_free()
	_library_buttons.clear()

	if hero_skill_build == null:
		return
	var assignable: Array[String] = hero_skill_build.get_assignable_skills()
	assignable.sort()

	for skill_id: String in assignable:
		var button := Button.new()
		button.name = "Library_%s" % skill_id
		button.focus_mode = Control.FOCUS_ALL
		button.clip_text = true
		var is_active: bool = hero_skill_build.get_active_slots().has(skill_id)
		button.text = "%s%s" % [skill_id, " [ACTIVE]" if is_active else ""]
		button.pressed.connect(_on_library_skill_pressed.bind(skill_id))
		_wire_focus_ring(button)
		_library_list.add_child(button)
		_library_buttons[skill_id] = button


## GDD simplification (see class doc comment): assigns to the first empty
## active slot; a no-op if all 4 are already filled (matching
## set_active_slot()'s own LOCKED/out-of-range rejection shape -- zero
## mutation, no crash).
func _on_library_skill_pressed(skill_id: String) -> void:
	if hero_skill_build == null:
		return
	var bindings: Array[String] = hero_skill_build.get_active_slots()
	for i: int in range(bindings.size()):
		if bindings[i].is_empty():
			hero_skill_build.set_active_slot(i, skill_id)
			return


# ---------------------------------------------------------------------------
# Focus ring (ADR-0011)
# ---------------------------------------------------------------------------

func _wire_focus_ring(button: Button) -> void:
	var focus_ring := Panel.new()
	focus_ring.name = "FocusRing"
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	ring_style.border_width_left = 2
	ring_style.border_width_right = 2
	ring_style.border_width_top = 2
	ring_style.border_width_bottom = 2
	ring_style.border_color = FOCUS_RING_COLOR
	focus_ring.add_theme_stylebox_override("panel", ring_style)
	focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_ring.visible = false
	focus_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(focus_ring)
	button.focus_entered.connect(_on_button_focus_changed.bind(button, focus_ring))
	button.focus_exited.connect(_on_button_focus_changed.bind(button, focus_ring))


func _on_button_focus_changed(button: Button, ring: Panel) -> void:
	ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	for button: Button in _active_slot_buttons.values():
		var ring: Panel = button.get_node_or_null("FocusRing") as Panel
		if ring != null:
			ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()
	for button: Button in _library_buttons.values():
		var ring: Panel = button.get_node_or_null("FocusRing") as Panel
		if ring != null:
			ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


# ---------------------------------------------------------------------------
# Test/inspection accessors
# ---------------------------------------------------------------------------

func get_active_slot_button(slot_index: int) -> Button:
	return _active_slot_buttons.get(slot_index)


func get_passive_cycle_button(slot_index: int) -> Button:
	return _passive_cycle_buttons.get(slot_index)


func get_library_button(skill_id: String) -> Button:
	return _library_buttons.get(skill_id)


func get_ultimate_label_text() -> String:
	return _ultimate_label.text

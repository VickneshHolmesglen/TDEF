extends Control

## Menagerie Screen (Sanctuary UI Story 005's Room Hosting scope, epic-10).
##
## GDD source: design/gdd/menagerie.md — UI Requirements section (roster
## strip, tend interaction, breeding-pen multi-select-then-confirm, sacrifice
## two-step confirmation).
## ADR: docs/architecture/adr-0011-ui-dual-focus-handling.md (focus/hover),
##      docs/architecture/adr-0026-menagerie-creature-lifecycle.md (data side)
##
## Scope, honestly bounded: the GDD's own "habitat diorama as primary view"
## layout requires real creature/diorama art that doesn't exist anywhere in
## this project (matches Sanctuary UI's own diorama gap, Story 013). This
## screen implements every INTERACTION the GDD specifies (roster review,
## tend, breeding multi-select, sacrifice confirmation) against a roster-list
## primary view instead of a habitat-diorama primary view — a real, honest
## simplification, not a placeholder. Re-skin around real art once it exists;
## no interaction logic here should need to change.
##
## Root is a plain Control, matching inventory_screen.gd's precedent (no
## pause-while-open requirement). No class_name — matches inventory_screen.gd/
## pause_menu.gd's TD-workflow-001 precedent (headless class-cache fragility).
##
## Gamepad model deviation, flagged: the GDD specifies one context-sensitive
## confirm button (tend / add-to-breeding-selection / open sacrifice) whose
## meaning depends on current mode. This screen instead exposes 3 explicit
## per-creature actions (Tend, Select for Breeding, Sacrifice) as separate
## buttons — functionally equivalent and fully gamepad-navigable (each is a
## normal focusable Button), but not literally "single confirm, mode-
## dependent." Simpler to implement and test correctly; revisit if a UX
## pass specifically requires the single-button variant.
##
## Tend-cooldown, flagged: the GDD's UI Requirements section describes a
## "ready-to-tend vs. on-cooldown" indicator, but menagerie.gd's own
## tend_creature() (Formula 2) explicitly has no cooldown — "no cooldown, no
## limit on repeat use." Implemented against the real, current core logic:
## the Tend button is enabled for any HABITAT creature (the only real gate
## tend_creature() enforces), with a secondary "no benefit" note shown at
## happiness == 100 rather than a fabricated cooldown timer that doesn't
## exist in the data layer.

const FOCUS_RING_COLOR: Color = FocusRingFactory.FOCUS_RING_COLOR  ## HD-2D skin gold

## species_id -> art lookup. All 5 species generated this session have art.
## Closes this screen's own flagged "no real creature art" simplification —
## surfaced as each roster button's built-in Button.icon (Godot's own
## text+icon layout) rather than a bespoke child Control, since Menagerie's
## CreatureInstance (unlike MonsterEntity) is a plain RefCounted with no
## scene-tree presence of its own to hang a dedicated presentation node off.
const ROSTER_ICON_MAX_WIDTH: int = 32

const SPECIES_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"glimmer_hare": preload("res://assets/art/species/glimmer_hare.png"),
	&"mossback_toad": preload("res://assets/art/species/mossback_toad.png"),
	&"emberwing_moth": preload("res://assets/art/species/emberwing_moth.png"),
	&"duskfang_fox": preload("res://assets/art/species/duskfang_fox.png"),
	&"aurora_stag": preload("res://assets/art/species/aurora_stag.png"),
}

## Injectable for tests; defaults to the real GMenagerie Autoload in normal use.
@export var menagerie: Menagerie

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _roster_panel: PanelContainer = $MainLayout/RosterPanel
@onready var _roster_list: GridContainer = $MainLayout/RosterPanel/RosterList

## 2026-10-10 UI pass: the roster was one thin text row per creature with a
## 32 px icon, leaving most of the room empty. It is now a 4-column grid of
## portrait cards (species art + name + state/happiness), padded with
## placeholders up to Menagerie.HABITAT_MAX_CAPACITY: "empty" for open
## habitat slots, "locked" past the player's current capacity -- a full 4x3
## grid that shows both free room and room still to unlock.
const CARD_MIN_SIZE: Vector2 = Vector2(0, 110)
const CARD_FONT_SIZE: int = 14
@onready var _detail_species_label: Label = $MainLayout/DetailPanel/SpeciesLabel
@onready var _detail_state_label: Label = $MainLayout/DetailPanel/StateLabel
@onready var _detail_happiness_label: Label = $MainLayout/DetailPanel/HappinessLabel
@onready var _tend_button: Button = $MainLayout/DetailPanel/ActionRow/TendButton
@onready var _breed_select_button: Button = $MainLayout/DetailPanel/ActionRow/BreedSelectButton
@onready var _sacrifice_button: Button = $MainLayout/DetailPanel/ActionRow/SacrificeButton
@onready var _confirm_breeding_button: Button = $MainLayout/DetailPanel/BreedRow/ConfirmBreedingButton
@onready var _cancel_selection_button: Button = $MainLayout/DetailPanel/BreedRow/CancelSelectionButton
@onready var _sacrifice_confirm_dialog: ConfirmationDialog = $SacrificeConfirmDialog

var _roster_buttons: Dictionary[int, Button] = {}
var _roster_focus_rings: Dictionary[int, Panel] = {}
var _focused_creature_id: int = -1
## GDD UI Requirements: selection (queued for breeding) is visually and
## semantically distinct from mere focus/highlight.
var _breeding_selection: Array[int] = []
var _pending_sacrifice_id: int = -1
## Lure panel + roster empty state (2026-10-04 smoke check): the Lure action
## (menagerie.md Core Rule 2) had a tested backend but no UI caller anywhere,
## so a player could never acquire a creature. Built in code, not the .tscn.
var _lure_count_label: Label
var _lure_buttons: Dictionary[StringName, Button] = {}
var _roster_empty_label: Label


func _ready() -> void:
	if menagerie == null:
		menagerie = GMenagerie

	_tend_button.pressed.connect(_on_tend_pressed)
	_breed_select_button.pressed.connect(_on_breed_select_pressed)
	_sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	_confirm_breeding_button.pressed.connect(_on_confirm_breeding_pressed)
	_cancel_selection_button.pressed.connect(_on_cancel_selection_pressed)
	_cancel_selection_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CANCEL)
	_sacrifice_confirm_dialog.confirmed.connect(_on_sacrifice_confirmed)
	_sacrifice_confirm_dialog.get_cancel_button().set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CANCEL)
	_sacrifice_confirm_dialog.get_ok_button().set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CONFIRM)
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)
	_apply_room_styles()

	GEventBus.creature_acquired.connect(_on_roster_changed)
	GEventBus.creature_happiness_changed.connect(_on_roster_changed)
	GEventBus.creature_bred.connect(_on_roster_changed)
	GEventBus.creature_sacrificed.connect(_on_roster_changed)
	GEventBus.creature_moved_to_breeding_pen.connect(_on_roster_changed)
	GEventBus.creature_returned_from_breeding_pen.connect(_on_roster_changed)

	_build_lure_panel()
	_rebuild_roster()
	_refresh_detail_panel()


func disconnect_own_subscriptions() -> void:
	GEventBus.creature_acquired.disconnect(_on_roster_changed)
	GEventBus.creature_happiness_changed.disconnect(_on_roster_changed)
	GEventBus.creature_bred.disconnect(_on_roster_changed)
	GEventBus.creature_sacrificed.disconnect(_on_roster_changed)
	GEventBus.creature_moved_to_breeding_pen.disconnect(_on_roster_changed)
	GEventBus.creature_returned_from_breeding_pen.disconnect(_on_roster_changed)


# ---------------------------------------------------------------------------
# Roster strip
# ---------------------------------------------------------------------------

## Rebuilds the whole roster strip from Menagerie's current live state.
## Simple full-rebuild rather than incremental diffing — the roster is small
## (HABITAT_MAX_CAPACITY=12 plus RESERVE/BREEDING_PEN/SACRIFICED history),
## matching this project's own precedent (structural_model rebuilds are cheap
## at this scale, and this only runs on real EventBus-driven state changes,
## never per-frame).
func _rebuild_roster() -> void:
	for child: Node in _roster_list.get_children():
		_roster_list.remove_child(child)
		child.queue_free()
	_roster_buttons.clear()
	_roster_focus_rings.clear()

	var creatures: Array[CreatureInstance] = menagerie.get_all_creatures()
	for creature: CreatureInstance in creatures:
		if creature.state == CreatureInstance.CreatureState.SACRIFICED:
			continue  # terminal state — no longer a roster entry to act on
		var button: Button = _create_roster_button(creature)
		_roster_list.add_child(button)
		_roster_buttons[creature.creature_id] = button

	if _focused_creature_id != -1 and not _roster_buttons.has(_focused_creature_id):
		_focused_creature_id = -1
	_breeding_selection = _breeding_selection.filter(
		func(id: int) -> bool: return _roster_buttons.has(id)
	)

	# Empty roster: say why and what to do instead of a silent blank panel.
	if _roster_buttons.is_empty():
		_roster_empty_label = Label.new()
		_roster_empty_label.name = "RosterEmptyLabel"
		_roster_empty_label.text = tr("MENAGERIE_ROSTER_EMPTY")
		_roster_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_roster_empty_label.custom_minimum_size = Vector2(240, 0)
		_roster_list.add_child(_roster_empty_label)
	else:
		for i: int in range(_roster_buttons.size(), maxi(Menagerie.HABITAT_MAX_CAPACITY, _roster_buttons.size())):
			_roster_list.add_child(_create_empty_slot_card(i >= menagerie.get_habitat_capacity()))
	# Breeding needs a pair -- entering select mode with fewer than two
	# roster creatures could never be confirmed.
	_breed_select_button.disabled = _roster_buttons.size() < 2
	_refresh_lure_panel()


func _create_roster_button(creature: CreatureInstance) -> Button:
	var button := Button.new()
	button.name = "Creature%d" % creature.creature_id
	button.focus_mode = Control.FOCUS_ALL
	button.text = _roster_entry_text(creature)
	button.toggle_mode = false
	button.icon = _species_texture(creature.species)
	# Source art is native ChatGPT-generation resolution (~900-1200px) --
	# found live via Godot MCP that an unconstrained Button.icon balloons the
	# whole button to the icon's native size. expand_icon=true scales the
	# portrait into whatever the card leaves after its text (aspect kept).
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = CARD_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", CARD_FONT_SIZE)
	var selected: bool = _breeding_selection.has(creature.creature_id)
	var card_box: StyleBoxFlat = ShellChromeStyle.chrome_button_stylebox(false)
	card_box.bg_color = ShellChromeStyle.UI_CHROME
	card_box.set_border_width_all(4 if selected else 1)
	card_box.border_color = ShellChromeStyle.UI_ACCENT if selected else Color(ShellChromeStyle.UI_PARCHMENT, 0.35)
	card_box.set_content_margin_all(8.0)
	button.add_theme_stylebox_override("normal", card_box)
	button.add_theme_stylebox_override("hover", card_box)
	button.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)

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
	_roster_focus_rings[creature.creature_id] = focus_ring

	button.pressed.connect(_on_roster_entry_pressed.bind(creature.creature_id))
	button.focus_entered.connect(_on_roster_entry_focus_changed.bind(creature.creature_id, button, focus_ring))
	button.focus_exited.connect(_on_roster_entry_focus_changed.bind(creature.creature_id, button, focus_ring))

	return button


## GDD UI Requirements: species icon/name, happiness-state, tend-actionable
## indicator (filled-vs-outline convention, applied here via a bracketed
## "[ready]"/"[HABITAT]" text tag pending real iconography). Selection state
## (breeding queue) also surfaces here since this is the only visible surface
## a roster entry has today.
## Logs a warning and returns null (Button.icon accepts null -- no icon
## shown) for a species with no authored art yet, mirroring MonsterInstance's
## identical fallback.
func _species_texture(species_id: StringName) -> Texture2D:
	var texture: Texture2D = SPECIES_TEXTURES.get(species_id, null)
	if texture == null:
		push_warning("[MenagerieScreen] no art authored for species_id '%s'" % species_id)
	return texture


func _roster_entry_text(creature: CreatureInstance) -> String:
	var state_tag: String = String(CreatureInstance.CreatureState.keys()[creature.state]).capitalize()
	var selected_tag: String = " [selected]" if _breeding_selection.has(creature.creature_id) else ""
	return "%s\n%s  ·  H:%d%s" % [_species_display_name(creature.species), state_tag, int(creature.happiness), selected_tag]


## Dimmed outline placeholder for one unused habitat slot; `locked` marks a
## slot past the current capacity (needs a Habitat Expansion).
func _create_empty_slot_card(locked: bool) -> Control:
	var card := PanelContainer.new()
	card.name = "LockedSlot" if locked else "EmptySlot"
	card.custom_minimum_size = CARD_MIN_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = ShellChromeStyle.chrome_panel_stylebox()
	box.bg_color = Color(ShellChromeStyle.UI_CHROME, 0.5)
	box.set_border_width_all(1)
	box.border_color = Color(ShellChromeStyle.UI_PARCHMENT, 0.15)
	card.add_theme_stylebox_override("panel", box)
	if locked:
		# 2026-10-25 AAA UI pass: a padlock instead of the same sentence repeated in
		# every locked cell (ten times over on a fresh save); the explanation moves
		# to the tooltip.
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.tooltip_text = tr("MENAGERIE_LOCKED_SLOT")
		var lock := PixelLockGlyph.new()
		lock.custom_minimum_size = Vector2(30, 36)
		lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock.color = Color(ShellChromeStyle.UI_PARCHMENT, 0.18)
		card.add_child(lock)
		return card
	var label := Label.new()
	label.text = tr("MENAGERIE_EMPTY_SLOT")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # keeps every grid column the same width
	label.custom_minimum_size = Vector2(40, 0)
	label.add_theme_color_override("font_color", Color(ShellChromeStyle.UI_PARCHMENT, 0.2 if locked else 0.35))
	card.add_child(label)
	return card


func _apply_room_styles() -> void:
	var box: StyleBoxFlat = ShellChromeStyle.chrome_panel_stylebox()
	box.bg_color = ShellChromeStyle.UI_CHROME.darkened(0.25)
	box.set_content_margin_all(16.0)
	_roster_panel.add_theme_stylebox_override("panel", box)
	for button: Button in [_tend_button, _breed_select_button, _sacrifice_button, _confirm_breeding_button, _cancel_selection_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 36)
		button.add_theme_stylebox_override("normal", ShellChromeStyle.skin_button_for(false))


## SpeciesResource carries no display name (menagerie.md Rule 1 names are
## placeholders), so derive one rather than showing the raw id.
static func _species_display_name(species_id: StringName) -> String:
	return String(species_id).capitalize()


# ---------------------------------------------------------------------------
# Lure panel -- menagerie.md Core Rule 2 / Formula 4
# ---------------------------------------------------------------------------

func _build_lure_panel() -> void:
	var detail_panel: VBoxContainer = $MainLayout/DetailPanel
	var header := Label.new()
	header.name = "LureHeader"
	header.text = tr("MENAGERIE_LURE_HEADER")
	header.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	detail_panel.add_child(header)

	_lure_count_label = Label.new()
	_lure_count_label.name = "LureCountLabel"
	detail_panel.add_child(_lure_count_label)

	var registry_species: Dictionary[StringName, SpeciesResource] = GGameDataRegistry.get_all_species()
	var species_ids: Array[StringName] = registry_species.keys()
	# Cheapest first: tier, then id for a stable order within a tier.
	species_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ta: int = registry_species[a].species_tier
		var tb: int = registry_species[b].species_tier
		return ta < tb if ta != tb else String(a) < String(b))
	for species_id: StringName in species_ids:
		var button := Button.new()
		button.name = "Lure_%s" % species_id
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = _species_texture(species_id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", ROSTER_ICON_MAX_WIDTH)
		button.text = tr("MENAGERIE_LURE_BUTTON") % [
			_species_display_name(species_id),
			Menagerie.lure_cost(registry_species[species_id].species_tier)]
		button.pressed.connect(_on_lure_pressed.bind(species_id))
		detail_panel.add_child(button)
		_lure_buttons[species_id] = button
	_refresh_lure_panel()


func _refresh_lure_panel() -> void:
	if _lure_count_label == null:
		return  # _rebuild_roster() runs once before the panel exists
	var owned: int = _owned_lure_count()
	_lure_count_label.text = tr("MENAGERIE_LURE_OWNED") % owned
	for species_id: StringName in _lure_buttons.keys():
		var species: SpeciesResource = GGameDataRegistry.get_species(species_id)
		_lure_buttons[species_id].disabled = species == null \
			or owned < Menagerie.lure_cost(species.species_tier)


func _owned_lure_count() -> int:
	var total: int = 0
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if contents.get("item_id", &"") == &"menagerie_lure":
			total += int(contents.get("quantity", 0))
	return total


func _on_lure_pressed(species_id: StringName) -> void:
	var creature_id: int = menagerie.lure_creature(species_id)
	if creature_id != -1:
		_focused_creature_id = creature_id
	# creature_acquired already rebuilt the roster; the lure count changed
	# even if the press was rejected, so refresh explicitly either way.
	_refresh_lure_panel()
	_refresh_detail_panel()


func _on_roster_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_rebuild_roster()
	_refresh_detail_panel()


# ---------------------------------------------------------------------------
# Selection / focus
# ---------------------------------------------------------------------------

## GDD UI Requirements: a roster entry press is context-dependent — while a
## breeding selection is in progress (_breed_select_button was pressed and at
## least a mode is active), pressing toggles that creature's queued-for-
## breeding membership; otherwise it sets the single detail-panel focus.
func _on_roster_entry_pressed(creature_id: int) -> void:
	if _breeding_select_mode_active():
		_toggle_breeding_selection(creature_id)
	else:
		_focused_creature_id = creature_id
		_refresh_detail_panel()


func _breeding_select_mode_active() -> bool:
	return _confirm_breeding_button.visible


func _toggle_breeding_selection(creature_id: int) -> void:
	if _breeding_selection.has(creature_id):
		_breeding_selection.erase(creature_id)
	else:
		_breeding_selection.append(creature_id)
	_rebuild_roster()
	_refresh_detail_panel()


func _on_roster_entry_focus_changed(creature_id: int, button: Button, ring: Panel) -> void:
	ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()
	if button.has_focus() and not _breeding_select_mode_active():
		_focused_creature_id = creature_id
		_refresh_detail_panel()


func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	for creature_id: int in _roster_buttons.keys():
		var button: Button = _roster_buttons[creature_id]
		var ring: Panel = _roster_focus_rings[creature_id]
		ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


# ---------------------------------------------------------------------------
# Detail panel — tend / breed-select / sacrifice
# ---------------------------------------------------------------------------

func _refresh_detail_panel() -> void:
	var creature: CreatureInstance = menagerie.get_creature(_focused_creature_id) if _focused_creature_id != -1 else null

	if creature == null:
		_detail_species_label.text = tr("MENAGERIE_NO_SELECTION")
		_detail_state_label.text = ""
		_detail_happiness_label.text = ""
		_tend_button.disabled = true
		_sacrifice_button.disabled = true
		return

	_detail_species_label.text = _species_display_name(creature.species)
	_detail_state_label.text = CreatureInstance.CreatureState.keys()[creature.state]
	_detail_happiness_label.text = tr("MENAGERIE_HAPPINESS_SHORT") % int(creature.happiness)
	_tend_button.disabled = creature.state != CreatureInstance.CreatureState.HABITAT
	_sacrifice_button.disabled = creature.state == CreatureInstance.CreatureState.BREEDING_PEN \
		or creature.state == CreatureInstance.CreatureState.SACRIFICED


## GDD: "confirm on a non-actionable target opens explanatory context" rather
## than a silent no-op — tend_creature() itself already returns false/no-op
## for a non-HABITAT creature, but the button is also disabled in that case
## (see _refresh_detail_panel()) so this handler only ever fires for a
## legitimately actionable creature.
func _on_tend_pressed() -> void:
	if _focused_creature_id == -1:
		return
	menagerie.tend_creature(_focused_creature_id)
	_refresh_detail_panel()


## Enters breeding-selection mode: the confirm/cancel row becomes visible,
## and subsequent roster presses toggle membership instead of changing focus
## (see _on_roster_entry_pressed()).
func _on_breed_select_pressed() -> void:
	_breeding_selection.clear()
	if _focused_creature_id != -1:
		_breeding_selection.append(_focused_creature_id)
	_confirm_breeding_button.visible = true
	_cancel_selection_button.visible = true
	_confirm_breeding_button.disabled = _breeding_selection.size() != 2
	_rebuild_roster()


func _on_confirm_breeding_pressed() -> void:
	if _breeding_selection.size() == 2:
		menagerie.pair_for_breeding(_breeding_selection[0], _breeding_selection[1])
	_exit_breeding_select_mode()


func _on_cancel_selection_pressed() -> void:
	_exit_breeding_select_mode()


func _exit_breeding_select_mode() -> void:
	_breeding_selection.clear()
	_confirm_breeding_button.visible = false
	_cancel_selection_button.visible = false
	_rebuild_roster()
	_refresh_detail_panel()


## GDD Sacrifice interaction: two-step confirmation, never single-confirm.
## target_item_id resolution (which Equipment Forge item results) is out of
## this screen's scope — Equipment Forge owns that mapping (OQ-5, no
## Equipment Forge screen exists yet to select a target item from). Passes
## -1 as a placeholder target_item_id, matching this project's own "flag the
## gap, don't fabricate a resolved value" precedent.
func _on_sacrifice_pressed() -> void:
	if _focused_creature_id == -1:
		return
	_pending_sacrifice_id = _focused_creature_id
	_sacrifice_confirm_dialog.dialog_text = tr("MENAGERIE_SACRIFICE_CONFIRM_TEXT")
	_sacrifice_confirm_dialog.popup_centered()


func _on_sacrifice_confirmed() -> void:
	if _pending_sacrifice_id == -1:
		return
	menagerie.request_sacrifice(_pending_sacrifice_id, -1)
	_pending_sacrifice_id = -1
	_focused_creature_id = -1
	_refresh_detail_panel()


# ---------------------------------------------------------------------------
# Test/inspection accessors
# ---------------------------------------------------------------------------

func get_focused_creature_id() -> int:
	return _focused_creature_id


func get_breeding_selection() -> Array[int]:
	return _breeding_selection.duplicate()


func is_breed_select_mode_active() -> bool:
	return _breeding_select_mode_active()

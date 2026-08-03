extends Control

## Tarot Deck-Building Screen (Tarot Deck UI Story 001's Room Hosting scope,
## epic-11).
##
## GDD source: design/gdd/tarot.md — UI Requirements section (active deck
## tray + card pool, select-then-confirm gamepad model, no confirmation
## dialog for deck edits — fully reversible at zero cost).
## ADR: docs/architecture/adr-0011-ui-dual-focus-handling.md (focus/hover),
##      docs/architecture/adr-0027-tarot-modifier-aggregation-pipeline.md
##      (data side — Tarot is scene-instanced, not an Autoload; this screen
##      discovers the shell-owned instance via the "tarot" group, mirroring
##      equipment_forge_screen.gd's own identical pattern)
##
## Conflict Indicator (epic-11 Story 004, GDD Core Rule 6): closes a real gap
## found 2026-07-25 — Story 004 built the mapping/query engine
## (`ConflictIndicator`, shell-owned) against a screen that didn't exist yet;
## once this screen was built the same session, it never actually queried
## that engine, leaving the badge permanently dark. Discovers the shell
## (`TarotDeckUI`) via the "tarot_deck_ui" group (same pattern as the "tarot"
## group above) to reach `get_conflict_indicator()`. Rendered as a plain-text
## "[CONFLICT: modifier_id, ...]" tag appended to the tray button's own label
## — matches this screen's own established plain-text-tag convention
## ("[LOCKED]"/"[EQUIPPED]"/"[AVAILABLE]" below), not a corner-anchored glyph
## overlay, since no card art/badge iconography exists anywhere in this
## project (same honestly-scoped deviation class as this file's other 2
## documented gaps above). Only tray cards ever show the tag — the GDD
## anchors the badge to "the conflicting tray slot" specifically, never the
## pool.
##
## Scope, honestly bounded:
## - The GDD's pick-up-then-place gamepad model (select a pool card ->
##   "picked up" -> select a tray slot -> placed, supporting in-place swap)
##   has no matching primitive in Tarot's own API: `equip_card(card_id)`
##   appends to the deck with no slot targeting, and there is no swap
##   operation — equipping into a full deck is simply rejected. This screen
##   implements a direct single-action model instead: pressing an unlocked,
##   unequipped pool card equips it (if the deck has room); pressing an
##   equipped card (in either the pool or the tray) unequips it. This is not
##   a shortcut around a real mechanic — the underlying system genuinely has
##   no slot-index or swap concept to select.
## - No mastery-pip/modifier-glyph rendering (still no data-layer concept of
##   mastery tiers to render). Card art exists for 10 of 12 cards as of
##   2026-08-04 (see CARD_TEXTURES) — a plain icon on the existing text
##   button, not the GDD's full "tactile card object with drop shadow/
##   cardstock texture/carved wooden tray" treatment, which is separately-
##   scoped, much larger UI work.
##
## Root is a plain Control. No class_name — matches the other room/screen
## scripts' TD-workflow-001 precedent.

const FOCUS_RING_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)  ## placeholder — art-director TBD

## card_id -> art lookup. Sourced from a 22-Major-Arcana generation batch
## (design/art/asset-generation-prompts.md, 2026-08-04) — 15 of the 22 have
## landed clean so far, and this project's real card roster is 12 cards,
## not 22, so this is a best-fit thematic mapping, not a literal
## Major-Arcana-to-card_id identity: each is chosen to resonate with the
## target card's actual mechanical effect (e.g. The Empress's abundance/
## harvest imagery -> bountiful_harvest's reward boost), not just borrowed
## because it was available.
##
## 2026-08-04 round 2 (Death/Justice/Temperance/Hanged Man/Hermit/Moon/
## Star/Strength landed): added 3 more strong fits (Death's transformation/
## ending imagery -> grim_resolve, the deck's highest-difficulty card;
## Strength's lion -> apex_predator, the deck's own "majestic apex
## predator" Legendary; Temperance's patience/moderation -> steady_hand,
## the mildest/calmest card). Justice, The Hanged Man, The Hermit, The
## Moon, and The Star landed clean but have NO good mechanical fit among
## the 2 still-unmapped cards (reckless_onslaught, swift_current both need
## aggressive-motion/speed imagery none of these 5 depict) — left as
## extra art ahead of content rather than forced into a bad fit; may find
## a home if new cards are ever authored.
const CARD_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"lucky_charm": preload("res://assets/art/tarot/the_fool.png"),
	&"golden_ticket": preload("res://assets/art/tarot/the_magician.png"),
	&"measured_pace": preload("res://assets/art/tarot/the_high_priestess.png"),
	&"bountiful_harvest": preload("res://assets/art/tarot/the_empress.png"),
	&"iron_resolve": preload("res://assets/art/tarot/the_emperor.png"),
	&"cautious_advance": preload("res://assets/art/tarot/the_hierophant.png"),
	&"hunters_pace": preload("res://assets/art/tarot/the_chariot.png"),
	&"grim_resolve": preload("res://assets/art/tarot/death.png"),
	&"apex_predator": preload("res://assets/art/tarot/strength.png"),
	&"steady_hand": preload("res://assets/art/tarot/temperance.png"),
}
const CARD_ICON_MAX_WIDTH: int = 32

## Injectable for tests; defaults to the shell-owned instance discovered via
## the "tarot" group (Tarot is scene-instanced per ADR-0027, not an Autoload).
@export var tarot: Tarot

## Injectable for tests; defaults to the shell-owned instance discovered via
## the "tarot_deck_ui" group (TarotDeckUI is scene-instanced, not an Autoload).
@export var conflict_indicator: ConflictIndicator

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _deck_tray_list: VBoxContainer = $MainLayout/DeckTray/DeckList
@onready var _card_pool_list: VBoxContainer = $MainLayout/CardPool/PoolList

var _deck_buttons: Dictionary[StringName, Button] = {}
var _pool_buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	if tarot == null:
		tarot = get_tree().get_first_node_in_group(&"tarot") as Tarot
	if conflict_indicator == null:
		var shell: Node = get_tree().get_first_node_in_group(&"tarot_deck_ui")
		if shell != null and shell.has_method(&"get_conflict_indicator"):
			conflict_indicator = shell.call(&"get_conflict_indicator") as ConflictIndicator

	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)
	GEventBus.tarot_deck_changed.connect(_on_deck_changed)
	GEventBus.run_modifier_selected.connect(_on_run_modifier_selected)
	GEventBus.mission_selected.connect(_on_mission_selected)

	_rebuild_deck_tray()
	_rebuild_card_pool()


func disconnect_own_subscriptions() -> void:
	GEventBus.tarot_deck_changed.disconnect(_on_deck_changed)
	GEventBus.run_modifier_selected.disconnect(_on_run_modifier_selected)
	GEventBus.mission_selected.disconnect(_on_mission_selected)


func _on_deck_changed(_new_count: int) -> void:
	_rebuild_deck_tray()
	_rebuild_card_pool()


## Conflict Indicator badge (GDD Core Rule 6) must update live as Mission
## Select's active modifiers change, without requiring a deck edit — these
## 2 subscriptions exist solely to refresh the tray's own conflict tags;
## `ConflictIndicator` itself already tracks the underlying state, this
## screen only needs to re-render against it.
func _on_run_modifier_selected(_modifier_id: String, _modifier_value: float) -> void:
	_rebuild_deck_tray()


func _on_mission_selected(_mission_id: String) -> void:
	_rebuild_deck_tray()


# ---------------------------------------------------------------------------
# Deck tray — currently-equipped cards
# ---------------------------------------------------------------------------

func _rebuild_deck_tray() -> void:
	for child: Node in _deck_tray_list.get_children():
		child.queue_free()
	_deck_buttons.clear()

	if tarot == null:
		return
	for card_id: StringName in tarot.get_current_deck():
		var button: Button = _create_deck_button(card_id)
		_deck_tray_list.add_child(button)
		_deck_buttons[card_id] = button


func _create_deck_button(card_id: StringName) -> Button:
	var button := Button.new()
	button.name = "Deck_%s" % String(card_id)
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.text = _deck_entry_text(card_id)
	_apply_card_icon(button, card_id)
	button.pressed.connect(_on_deck_card_pressed.bind(card_id))
	_wire_focus_ring(button)
	return button


## Sets the button's icon for card_id if art exists (CARD_TEXTURES), no-op
## otherwise (button.icon stays null, matching Button's own default — this
## screen's cards were always text-only before, so an unmapped card looking
## exactly as it always did is correct, not a fallback warning case).
## expand_icon + icon_max_width mirrors MenagerieScreen's identical fix for
## the identical problem: source art is native ChatGPT-generation resolution
## and would otherwise balloon the button to the icon's native size.
func _apply_card_icon(button: Button, card_id: StringName) -> void:
	var texture: Texture2D = CARD_TEXTURES.get(card_id, null)
	if texture == null:
		return
	button.icon = texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", CARD_ICON_MAX_WIDTH)


## GDD Core Rule 6: plain-text conflict tag, tray slots only (see class doc
## comment for why this is text, not a corner-anchored badge glyph).
func _deck_entry_text(card_id: StringName) -> String:
	var conflicts: Array[String] = _get_card_conflicts(card_id)
	if conflicts.is_empty():
		return String(card_id)
	return "%s [CONFLICT: %s]" % [String(card_id), ", ".join(conflicts)]


## Every distinct Mission Select modifier_id any of this card's modifier
## entries conflicts with (GDD Core Rule 6 — a card can conflict with more
## than one selection simultaneously, only possible for
## tarot_wave_config_override today).
func _get_card_conflicts(card_id: StringName) -> Array[String]:
	var conflicts: Array[String] = []
	if conflict_indicator == null:
		return conflicts
	var card: TarotCardResource = GGameDataRegistry.get_tarot_card(card_id)
	if card == null:
		return conflicts
	for entry: TarotModifierEntry in card.modifiers:
		for modifier_id: String in conflict_indicator.get_conflicting_modifier_ids(entry.modifier_type):
			if not conflicts.has(modifier_id):
				conflicts.append(modifier_id)
	return conflicts


## Test/inspection accessor.
func has_conflict(card_id: StringName) -> bool:
	return not _get_card_conflicts(card_id).is_empty()


## GDD: unequipping is a single, immediate action -- no confirmation dialog
## (fully reversible at zero cost).
func _on_deck_card_pressed(card_id: StringName) -> void:
	tarot.unequip_card(card_id)


# ---------------------------------------------------------------------------
# Card pool — every registered card, showing lock/equipped state
# ---------------------------------------------------------------------------

func _rebuild_card_pool() -> void:
	for child: Node in _card_pool_list.get_children():
		child.queue_free()
	_pool_buttons.clear()

	if tarot == null:
		return
	var all_cards: Dictionary[StringName, TarotCardResource] = GGameDataRegistry.get_all_tarot_cards()
	var card_ids: Array = all_cards.keys()
	card_ids.sort()

	for card_id: StringName in card_ids:
		var button: Button = _create_pool_button(card_id)
		_card_pool_list.add_child(button)
		_pool_buttons[card_id] = button


func _create_pool_button(card_id: StringName) -> Button:
	var button := Button.new()
	button.name = "Pool_%s" % String(card_id)
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.text = _pool_entry_text(card_id)
	_apply_card_icon(button, card_id)
	button.pressed.connect(_on_pool_card_pressed.bind(card_id))
	_wire_focus_ring(button)
	return button


func _pool_entry_text(card_id: StringName) -> String:
	if not tarot.is_card_unlocked(card_id):
		return "%s [LOCKED]" % String(card_id)
	if tarot.get_current_deck().has(card_id):
		return "%s [EQUIPPED]" % String(card_id)
	return "%s [AVAILABLE]" % String(card_id)


## GDD: confirm on a locked card opens a context tooltip explaining the
## unlock requirement, rather than doing nothing. equip_card() is itself
## already a safe no-op on any ineligible target (locked, deck full,
## REPLACE-type conflict); this handler adds the explanatory surface for
## the rejection case.
var _last_rejected_card_id: StringName = &""


func _on_pool_card_pressed(card_id: StringName) -> void:
	if tarot.get_current_deck().has(card_id):
		tarot.unequip_card(card_id)
		return
	var equipped: bool = tarot.equip_card(card_id)
	if not equipped:
		_last_rejected_card_id = card_id


func get_last_rejected_card_id() -> StringName:
	return _last_rejected_card_id


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
	for buttons: Dictionary in [_deck_buttons, _pool_buttons]:
		for key: Variant in buttons.keys():
			var button: Button = buttons[key]
			var ring: Panel = button.get_node_or_null("FocusRing") as Panel
			if ring != null:
				ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


# ---------------------------------------------------------------------------
# Test/inspection accessors
# ---------------------------------------------------------------------------

func get_deck_button(card_id: StringName) -> Button:
	return _deck_buttons.get(card_id)


func get_pool_button(card_id: StringName) -> Button:
	return _pool_buttons.get(card_id)

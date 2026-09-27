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
## - Skill icon rendering closed 2026-09-01 (Claude Code): all 32 catalogued
##   skills now have real, processed icon art (SkillDefinitionResource.icon —
##   see that session's art-processing/content-authoring commits). Active-
##   slot and library buttons show that icon plus each skill's
##   `display_name` instead of the raw `skill_id`. **Revised same day, live
##   Godot MCP verification**: initially used Godot's native `Button.icon`
##   (theme constant `icon_max_width`), but that only caps rendered WIDTH,
##   scaling height proportionally uncapped — confirmed via
##   get_ui_elements() that library row heights varied 31px-97px across the
##   32 skills' differing icon aspect ratios. Switched to
##   _build_button_content()'s manually-composed fixed-size TextureRect +
##   Label, matching inventory_screen.gd's own established icon-sizing
##   convention — every row is now a consistent height regardless of
##   source art.
## - Archetype color/glyph treatment closed 2026-09-01 (Claude Code), per
##   hero-skill-build.md UI Requirements' "Archetype identity per slot" and
##   "shape/glyph is the primary identifier, color is confirmatory only"
##   colorblind-safety rule. **Real gap found while implementing this**: that
##   GDD text claims this screen is "the fourth consumer... of the same
##   [glyph] visual vocabulary" established by Tower Info Panel/tower
##   base/projectile trails — false on inspection. Only a COLOR table exists
##   in code (`ProjectileVisual.ARCHETYPE_COLORS`, extended here with a new
##   "support" entry the GDD's own "Support warm gold" language calls for
##   but the table never had, since Support towers never fire a projectile);
##   no actual glyph/shape asset or convention exists anywhere in this
##   project for any of the 4 archetypes. Rather than block on that or
##   silently invent full bespoke iconography (against this project's own
##   discipline), the "shape" identifier here is a plain bold letter badge
##   (P/R/E/S) — colorblind-safe by construction (distinct letterforms, not
##   just distinct hues of the same shape) and consistent with this same
##   GDD's own "NEW-skill badge... text/glyph in addition to color" fallback
##   pattern elsewhere. A real illustrated glyph set remains open,
##   unscoped art-direction work if/when this project wants one.
## - Category-count pip tally (UI Requirements: "a deliberate pedagogical
##   surface... learn to read '3 Elemental + 1 Support -> Ultimate X' as a
##   pattern") added beneath the Ultimate readout, built from
##   HeroSkillBuild.get_category_count() (already existed, unused by any UI
##   until now) using the same letter-badge glyphs, one per occupied slot.
## - Not-yet-learned skills roadmap closed 2026-09-01 (Claude Code, player
##   decision via AskUserQuestion — see _rebuild_library()'s own doc
##   comment): the library now always lists the full 32-skill catalogue,
##   not just unlocked skills. A locked entry is disabled, dimmed, and
##   tagged "[LOCKED]" — matching tarot_screen.gd's REAL established
##   plain-text-tag convention, correcting the GDD's own inaccurate
##   "lock icon" description of it.
## - Connector-line visual closed 2026-09-01 (Claude Code, player-requested
##   after the earlier "genuinely unscoped art-direction work" assessment).
##   Implemented as plain geometric lines (Control.draw_line(), via the
##   `draw` signal on a dedicated ConnectorLines overlay Control — see that
##   node's own onready doc comment), not illustrated art: one line per
##   occupied active slot, from that slot's center to the Ultimate label's
##   center, tinted with the slot's own archetype accent. This is the "no
##   bespoke art invented" treatment, same discipline as the letter-badge
##   glyphs above — a real connector-art pass remains open, separate,
##   unscoped work if this project ever wants one.
##
## Root is a plain Control. No class_name — matches the other room/screen
## scripts' TD-workflow-001 precedent.

const FOCUS_RING_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)  ## placeholder — art-director TBD
const ACTIVE_SLOT_LABELS: Array[String] = ["A", "B", "C", "D"]
## Caps a skill icon's rendered box (both dimensions — see
## _build_button_content()'s own doc comment for why a fixed box, not
## Button's native icon_max_width, is required here) regardless of source
## resolution (the processed art in assets/art/items/ is a tight content
## crop, not a pre-sized icon sheet — sizes and aspect ratios vary widely
## across the 32 skills). Matches the project's existing "always verify/cap
## scale explicitly, never trust default sizing" lesson
## (design/art/codex-art-overhaul.md §5.5).
const ICON_MAX_WIDTH: int = 32

## Single-letter "shape" glyph per archetype — see class doc comment for why
## this is a plain letter badge rather than illustrated iconography. Keys
## match HeroSkillBuild.CATEGORIES exactly (reused directly for iteration
## order below, not re-declared here).
const ARCHETYPE_GLYPHS: Dictionary[String, String] = {
	"physical": "P", "ranged": "R", "elemental": "E", "support": "S",
}

## Injectable for tests; defaults to the real GHeroSkillBuild Autoload.
@export var hero_skill_build: HeroSkillBuild

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _ultimate_label: Label = $MainLayout/UltimateLabel
@onready var _pip_tally_row: HBoxContainer = $MainLayout/PipTallyRow
@onready var _active_slot_list: VBoxContainer = $MainLayout/AssemblyArea/ActiveSlotList
## Real gap found via live Godot MCP verification (2026-09-01): this list
## had no ScrollContainer, fine when only a handful of skills existed but
## broken once the not-yet-learned-skills roadmap (same-day change) made it
## always list all 32 -- content height (~1300px+) exceeded the window,
## and MainLayout's own grow_vertical=2 shifted the ENTIRE screen (Ultimate
## label, pip tally, active slots, connector lines, everything) symmetrically
## off-screen to accommodate it (confirmed via get_ui_elements: UltimateLabel
## at y=-535 instead of y=0). Fixed by wrapping this list in a
## LibraryScroll ScrollContainer, matching inventory_screen.gd's own
## RecipeScroll precedent -- Library's PanelContainer now scrolls its own
## overflow instead of pushing MainLayout's total height past the viewport.
@onready var _library_list: VBoxContainer = $MainLayout/Library/LibraryScroll/LibraryList
## Connector-line visual (new 2026-09-01, player-requested — see this class's
## own doc comment for the earlier "genuinely unscoped art-direction work"
## assessment this supersedes). A plain Control drawn on via its own `draw`
## signal (Godot 4 — no dedicated subclass/script needed for a single
## _draw()-shaped need), full-rect over the whole screen, last sibling under
## root so lines render on top of the buttons/labels they connect —
## mirrors a tech-tree-style connector overlay, appropriate given this
## project's own "Path of Exile in complexity" framing for this system.
@onready var _connector_lines: Control = $ConnectorLines

var _active_slot_buttons: Dictionary[int, Button] = {}
var _passive_cycle_buttons: Dictionary[int, Button] = {}
var _library_buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	if hero_skill_build == null:
		hero_skill_build = GHeroSkillBuild

	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)
	GEventBus.active_skill_equipped.connect(_on_build_changed)
	GEventBus.ultimate_skill_changed.connect(_on_build_changed)
	_connector_lines.draw.connect(_on_connector_lines_draw)
	resized.connect(_queue_connector_redraw)

	_rebuild_everything()


func disconnect_own_subscriptions() -> void:
	GEventBus.active_skill_equipped.disconnect(_on_build_changed)
	GEventBus.ultimate_skill_changed.disconnect(_on_build_changed)


func _on_build_changed(_a: Variant = null, _b: Variant = null) -> void:
	_rebuild_everything()


func _rebuild_everything() -> void:
	_rebuild_ultimate_label()
	_rebuild_pip_tally()
	_rebuild_active_slots()
	_rebuild_library()
	_queue_connector_redraw()


## Deferred, not immediate: connector positions depend on the just-rebuilt
## buttons' final laid-out rects, which Godot's Container sort pass computes
## during this same frame's idle processing — calling queue_redraw()
## synchronously here would read stale (pre-layout) positions on the very
## first rebuild. call_deferred() runs after that sort pass completes.
func _queue_connector_redraw() -> void:
	_connector_lines.call_deferred("queue_redraw")


func _rebuild_ultimate_label() -> void:
	if hero_skill_build == null:
		_ultimate_label.text = tr("SKILL_BUILD_ULTIMATE_NONE")
		return
	_ultimate_label.text = tr("SKILL_BUILD_ULTIMATE") % hero_skill_build.get_all_slot_bindings()["U"]


## UI Requirements' "deliberate pedagogical surface": one letter-glyph badge
## per occupied active slot, grouped by category and repeated per occupant
## (e.g. 3 Elemental + 1 Support glyphs) — never colored dots alone, per the
## GDD's own colorblind-safety line. Built from get_category_count()
## (Story-001-scoped occupied-slot tally — deliberately the same looser tally
## the GDD's own pip-tally description uses, not Formula 1's stricter
## all-4-filled Ultimate-derivation precondition; a 2-of-4-filled build still
## gets a legible partial tally here).
func _rebuild_pip_tally() -> void:
	for child: Node in _pip_tally_row.get_children():
		child.queue_free()
	if hero_skill_build == null:
		return
	var counts: Dictionary[String, int] = hero_skill_build.get_category_count()
	for category: String in HeroSkillBuild.CATEGORIES:
		var count: int = counts.get(category, 0)
		for _i: int in count:
			_pip_tally_row.add_child(_make_glyph_badge(category, 18))


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
		# Real bug found via live Godot MCP verification (2026-09-01): neither
		# button in this row had a size_flags_horizontal set, so HBoxContainer
		# gave each only its own tiny minimum content size instead of sharing
		# the row's full width -- with clip_text=true, slot_button collapsed to
		# ~42px (icon-only), and its "A: Cleave [ACTIVE]" text was entirely
		# invisible, clipped away. EXPAND_FILL with a 3:1 stretch ratio against
		# passive_button below gives the skill name the majority of the row
		# while still leaving room for the shorter "Passives: N/M (cycle)" text.
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.size_flags_stretch_ratio = 3.0
		var bound: String = bindings[i] if i < bindings.size() else ""
		var slot_text: String = "%s: %s" % [ACTIVE_SLOT_LABELS[i], _skill_label(bound) if not bound.is_empty() else "(empty)"]
		_build_button_content(slot_button, _skill_icon(bound), slot_text)
		_apply_archetype_style(slot_button, bound)
		slot_button.pressed.connect(_on_active_slot_pressed.bind(i))
		_wire_focus_ring(slot_button)
		row.add_child(slot_button)
		_active_slot_buttons[i] = slot_button

		var passive_button := Button.new()
		passive_button.name = "PassiveCycle_%s" % ACTIVE_SLOT_LABELS[i]
		passive_button.clip_text = true
		passive_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		passive_button.size_flags_stretch_ratio = 1.0
		passive_button.text = _passive_summary_text(bound)
		passive_button.disabled = bound.is_empty()
		passive_button.pressed.connect(_on_passive_cycle_pressed.bind(i))
		row.add_child(passive_button)
		_passive_cycle_buttons[i] = passive_button

		_active_slot_list.add_child(row)


## Builds this button's icon+text content as manually-composed children
## (a fixed-size TextureRect + a Label) instead of Godot's native
## `Button.icon`/`Button.text`. Real bug found via live Godot MCP
## verification (2026-09-01): `Button`'s `icon_max_width` theme constant
## caps the icon's rendered WIDTH only — it scales the icon down preserving
## aspect ratio, with no independent height cap. The processed skill icons
## (assets/art/items/) are tight content crops with wildly varying aspect
## ratios (confirmed via get_ui_elements: library row heights ranged
## 31px-97px, "Ranger Totem" being the worst offender, a tall/narrow totem
## crop scaled to 32px wide but left to grow proportionally tall). This
## builder gives the icon a genuinely fixed 32x32 box (EXPAND_IGNORE_SIZE +
## STRETCH_KEEP_ASPECT_CENTERED, matching inventory_screen.gd's own
## established icon-sizing convention) so every row is a consistent height
## regardless of source art. `mouse_filter = MOUSE_FILTER_IGNORE` on every
## added child (and the wrapping HBoxContainer) so clicks still reach the
## Button underneath rather than being intercepted by its children.
func _build_button_content(button: Button, texture: Texture2D, label_text: String) -> void:
	button.text = ""
	button.icon = null
	# Real bug found via live Godot MCP verification (2026-09-01), same
	# session as the icon-aspect-ratio fix this function itself exists for:
	# with text/icon both cleared, Button's own computed minimum size
	# collapses to near-zero -- a plain Control (Button is not a Container)
	# never feeds an anchored child's size back into its own minimum-size
	# calculation, unlike a real Container. Every library/slot row
	# collapsed to a sliver and visibly overlapped its neighbors (confirmed
	# via screenshot) until this explicit minimum height was added.
	button.custom_minimum_size.y = ICON_MAX_WIDTH + 8.0

	var content := HBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 6)

	if texture != null:
		var icon_rect := TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.custom_minimum_size = Vector2(ICON_MAX_WIDTH, ICON_MAX_WIDTH)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = texture
		content.add_child(icon_rect)

	var label := Label.new()
	label.name = "Text"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	content.add_child(label)

	button.add_child(content)


## Display-name lookup for a skill_id, falling back to the raw skill_id
## itself if no SkillDefinitionResource resolves (an orphaned/unrecognized
## skill_id — see hero-skill-build.md's own AC-21/AC-22 orphan handling;
## this screen still needs to show SOMETHING for it, not a blank button).
func _skill_label(skill_id: String) -> String:
	if skill_id.is_empty():
		return skill_id
	var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
	if definition == null or definition.display_name.is_empty():
		return skill_id
	return definition.display_name


## Icon lookup for a skill_id — null for an empty/orphaned skill_id or a
## skill whose content-authoring pass hasn't set an icon (renders as
## Button's own no-icon layout, same as before this feature landed).
func _skill_icon(skill_id: String) -> Texture2D:
	if skill_id.is_empty():
		return null
	var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
	if definition == null:
		return null
	return definition.icon


## Category lookup for a skill_id — "" for an empty/orphaned skill_id.
func _skill_category(skill_id: String) -> String:
	if skill_id.is_empty():
		return ""
	var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
	if definition == null:
		return ""
	return definition.category


## Applies UI Requirements' "slot frame's border takes the archetype's
## accent" (border only — the button's own bg/hover/pressed states are left
## at their Godot-default look, not fully re-skinned) plus a corner glyph
## badge (top-right, matching inventory_screen.gd's own corner-badge
## precedent for its quantity label). A no-op for an empty/orphaned
## skill_id — an empty active slot keeps its plain default look.
func _apply_archetype_style(button: Button, skill_id: String) -> void:
	var category: String = _skill_category(skill_id)
	if category.is_empty():
		return
	var accent: Color = ProjectileVisual.ARCHETYPE_COLORS.get(category, Color(0.5, 0.5, 0.5))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.6)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = accent
	button.add_theme_stylebox_override("normal", style)

	var badge: Label = _make_glyph_badge(category, 16)
	badge.name = "ArchetypeBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -18.0
	badge.offset_top = 2.0
	badge.offset_right = -2.0
	badge.offset_bottom = 18.0
	button.add_child(badge)


## Builds one letter-glyph badge (see class doc comment for why a plain
## letter, not illustrated iconography) — a small square Label, background-
## tinted with ProjectileVisual.ARCHETYPE_COLORS, text set to
## ARCHETYPE_GLYPHS. Falls back to a neutral grey "?" for an unrecognized
## category rather than omitting the badge entirely (shape/glyph presence
## itself, not just its specific letter, is what colorblind-safety needs).
func _make_glyph_badge(category: String, size: int) -> Label:
	var badge := Label.new()
	badge.text = ARCHETYPE_GLYPHS.get(category, "?")
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(size, size)
	badge.add_theme_font_size_override("font_size", int(size * 0.65))
	var accent: Color = ProjectileVisual.ARCHETYPE_COLORS.get(category, Color(0.5, 0.5, 0.5))
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(int(size * 0.2))
	badge.add_theme_color_override("font_color", Color.BLACK if accent.get_luminance() > 0.5 else Color.WHITE)
	badge.add_theme_stylebox_override("normal", style)
	return badge


## Draws one line per occupied active slot, from that slot button's center
## to the Ultimate label's center, tinted with the slot's own archetype
## accent (ProjectileVisual.ARCHETYPE_COLORS) — a plain geometric line, not
## illustrated art, matching this project's existing "no bespoke art
## invented, compose from StyleBoxFlat/draw primitives" precedent elsewhere
## in this screen (the archetype border/badge treatment) and across the
## codebase (e.g. FocusRingFactory). An empty slot draws nothing.
func _on_connector_lines_draw() -> void:
	if hero_skill_build == null:
		return
	var ultimate_center: Vector2 = _global_center_in_local(_ultimate_label)
	var bindings: Array[String] = hero_skill_build.get_active_slots()
	for i: int in range(ACTIVE_SLOT_LABELS.size()):
		if i >= bindings.size() or bindings[i].is_empty():
			continue
		var button: Button = _active_slot_buttons.get(i)
		if button == null:
			continue
		var category: String = _skill_category(bindings[i])
		var accent: Color = ProjectileVisual.ARCHETYPE_COLORS.get(category, Color(0.7, 0.7, 0.7))
		var slot_center: Vector2 = _global_center_in_local(button)
		_connector_lines.draw_line(slot_center, ultimate_center, accent, 2.0, true)


## Converts `control`'s global-space rect center into _connector_lines' own
## local coordinate space — the two Controls don't share a common ancestor
## transform assumption otherwise (this screen applies no scale/rotation
## anywhere today, but this stays correct even if that ever changes).
func _global_center_in_local(control: Control) -> Vector2:
	var global_center: Vector2 = control.get_global_rect().get_center()
	return _connector_lines.get_global_transform().affine_inverse() * global_center


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

	# Real bug found and fixed 2026-09-02 (closing hero-skill-build.md's
	# flagged skill_modifier item_type gap): this loop previously cycled
	# through ANY owned Inventory item regardless of item_type — a stub
	# predating Rule 13's 2026-09-01 typed-slot revision, never updated once
	# HeroSkillBuild.set_passive_slot() actually started enforcing
	# requires_tag compatibility. Now filters to item_type == "skill_modifier"
	# candidates only, and keeps scanning past a type-eligible-but-
	# tag-incompatible item (set_passive_slot() returning false) instead of
	# stopping on the first owned item found.
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if contents.is_empty():
			continue
		var item_id: String = contents["item_id"] as String
		if already_assigned.has(item_id):
			continue
		var item_definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
		if item_definition == null or item_definition.item_type != &"skill_modifier":
			continue
		if hero_skill_build.set_passive_slot(skill_id, next_empty_index, item_id):
			return


# ---------------------------------------------------------------------------
# Library panel — assignable skills
# ---------------------------------------------------------------------------

## Roadmap treatment resolved 2026-09-01 (player decision, AskUserQuestion —
## hero-skill-build.md's own Open Question: "does the library panel intend to
## show not-yet-learned (locked) skills... needs a decision before UI
## implementation"): yes — the FULL catalogue (GameDataRegistry.
## get_all_skill_definitions(), not just get_assignable_skills()) is always
## listed. A not-yet-learned skill is disabled, dimmed, and tagged
## "[LOCKED]". **Correction to that GDD's own wording, same category as this
## file's archetype-glyph finding**: it calls for "the existing grey-out-
## plus-lock-icon convention (same lock glyph as Inventory/Crafting/Tarot)"
## — false on inspection. tarot_screen.gd's own doc comment states its
## established convention is a plain-text bracketed tag
## ("[LOCKED]"/"[EQUIPPED]"/"[AVAILABLE]"/"[CONFLICT: ...]"), explicitly
## NOT a corner-anchored glyph, "since no card art/badge iconography exists
## anywhere in this project." This screen now matches that REAL convention
## (a "[LOCKED]" text tag + dimming), not the GDD's inaccurate "lock icon"
## description of it.
func _rebuild_library() -> void:
	for child: Node in _library_list.get_children():
		child.queue_free()
	_library_buttons.clear()

	if hero_skill_build == null:
		return
	var assignable: Array[String] = hero_skill_build.get_assignable_skills()
	var assignable_set: Dictionary[String, bool] = {}
	for id: String in assignable:
		assignable_set[id] = true

	var all_ids: Array[String] = []
	for id: StringName in GGameDataRegistry.get_all_skill_definitions():
		all_ids.append(String(id))
	all_ids.sort()

	for skill_id: String in all_ids:
		var is_locked: bool = not assignable_set.has(skill_id)
		var button := Button.new()
		button.name = "Library_%s" % skill_id
		button.focus_mode = Control.FOCUS_ALL
		button.clip_text = true
		var is_active: bool = hero_skill_build.get_active_slots().has(skill_id)
		var suffix: String = "[LOCKED]" if is_locked else ("[ACTIVE]" if is_active else "")
		var library_text: String = "%s %s" % [_skill_label(skill_id), suffix] if not suffix.is_empty() else _skill_label(skill_id)
		_build_button_content(button, _skill_icon(skill_id), library_text)
		_apply_archetype_style(button, skill_id)
		if is_locked:
			button.disabled = true
			button.modulate = Color(1.0, 1.0, 1.0, 0.45)
		button.pressed.connect(_on_library_skill_pressed.bind(skill_id))
		_wire_focus_ring(button)
		_library_list.add_child(button)
		_library_buttons[skill_id] = button


## GDD simplification (see class doc comment): assigns to the first empty
## active slot; a no-op if all 4 are already filled (matching
## set_active_slot()'s own LOCKED/out-of-range rejection shape -- zero
## mutation, no crash). Also rejects a not-yet-learned skill_id even if
## called directly (not through the UI's own `button.disabled` gate, which
## only blocks a real player click) -- defense in depth, matching this
## project's general "never trust a UI-only reject" discipline (e.g.
## HeroSkillBuild.is_locked()'s own data-layer gate, not just a disabled
## button elsewhere in this codebase).
func _on_library_skill_pressed(skill_id: String) -> void:
	if hero_skill_build == null:
		return
	if not hero_skill_build.get_assignable_skills().has(skill_id):
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

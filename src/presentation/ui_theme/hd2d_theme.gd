class_name Hd2dTheme
extends RefCounted

## Project-wide HD-2D UI theme (ADR-0042 UI skin, 2026-10-12).
##
## Built in code from ShellChromeStyle's palette and textured skin, then saved
## to THEME_PATH by tools/ui/build_hd2d_theme.gd and set as the project theme
## (project.godot [gui] theme/custom), so every Control without its own
## override gets the look: Cinzel headings, Alegreya Sans body text, studded
## navy panels with a gold rule, bronze/gold/amber button states.
##
## Type variations for headings (set Control.theme_type_variation):
##   &"HeaderLabel"  -- Cinzel 20, gold
##   &"TitleLabel"   -- Cinzel 30, gold, outlined

const THEME_PATH: String = "res://assets/ui/hd2d_theme.tres"
const FONT_BODY: String = "res://assets/ui/fonts/AlegreyaSans-Regular.ttf"
const FONT_BOLD: String = "res://assets/ui/fonts/AlegreyaSans-Bold.ttf"
const FONT_TITLE: String = "res://assets/ui/fonts/Cinzel-Variable.ttf"

const BODY_SIZE: int = 17
const TEXT: Color = ShellChromeStyle.UI_PARCHMENT
const TEXT_DIM: Color = Color(0.62, 0.58, 0.5)
const TEXT_LIT: Color = Color(0.98, 0.9, 0.66)
const GOLD: Color = ShellChromeStyle.UI_RULE_LIT
const SHADOW: Color = Color(0, 0, 0, 0.7)


static func build() -> Theme:
	var t := Theme.new()
	var body: Font = load(FONT_BODY) as Font
	var bold: Font = load(FONT_BOLD) as Font
	var title: Font = load(FONT_TITLE) as Font
	t.default_font = body
	t.default_font_size = BODY_SIZE

	# Text: parchment with a hard 1 px drop shadow (reads over busy scenery).
	for type: StringName in [&"Label", &"RichTextLabel"]:
		t.set_color(&"font_color" if type == &"Label" else &"default_color", type, TEXT)
		t.set_color(&"font_shadow_color", type, SHADOW)
		t.set_constant(&"shadow_offset_x", type, 1)
		t.set_constant(&"shadow_offset_y", type, 1)
	t.set_font(&"bold_font", &"RichTextLabel", bold)

	# Panels.
	for type: StringName in [&"Panel", &"PanelContainer", &"PopupPanel"]:
		t.set_stylebox(&"panel", type, ShellChromeStyle.skin_panel())
	t.set_stylebox(&"panel", &"TooltipPanel", ShellChromeStyle.skin_panel())
	t.set_color(&"font_color", &"TooltipLabel", TEXT)
	for type: StringName in [&"ItemList", &"Tree", &"ScrollContainer"]:
		t.set_stylebox(&"panel", type, ShellChromeStyle.skin_inset())

	# Buttons (and everything that inherits Button's look).
	for type: StringName in [&"Button", &"OptionButton", &"MenuButton", &"CheckButton", &"CheckBox"]:
		t.set_stylebox(&"normal", type, ShellChromeStyle.skin_button(&"normal"))
		t.set_stylebox(&"hover", type, ShellChromeStyle.skin_button(&"hover"))
		t.set_stylebox(&"pressed", type, ShellChromeStyle.skin_button(&"pressed"))
		t.set_stylebox(&"hover_pressed", type, ShellChromeStyle.skin_button(&"active"))
		t.set_stylebox(&"disabled", type, ShellChromeStyle.skin_button(&"disabled"))
		t.set_stylebox(&"focus", type, ShellChromeStyle.skin_focus())
		t.set_font(&"font", type, bold)
		t.set_color(&"font_color", type, TEXT)
		t.set_color(&"font_hover_color", type, TEXT_LIT)
		t.set_color(&"font_pressed_color", type, TEXT_LIT)
		t.set_color(&"font_hover_pressed_color", type, TEXT_LIT)
		t.set_color(&"font_focus_color", type, TEXT_LIT)
		t.set_color(&"font_disabled_color", type, TEXT_DIM)
		t.set_color(&"font_outline_color", type, SHADOW)
		t.set_constant(&"outline_size", type, 2)

	# Tabs.
	t.set_stylebox(&"tab_selected", &"TabBar", ShellChromeStyle.skin_button(&"active"))
	t.set_stylebox(&"tab_unselected", &"TabBar", ShellChromeStyle.skin_button(&"normal"))
	t.set_stylebox(&"tab_hovered", &"TabBar", ShellChromeStyle.skin_button(&"hover"))
	t.set_stylebox(&"tab_disabled", &"TabBar", ShellChromeStyle.skin_button(&"disabled"))
	t.set_stylebox(&"tab_selected", &"TabContainer", ShellChromeStyle.skin_button(&"active"))
	t.set_stylebox(&"tab_unselected", &"TabContainer", ShellChromeStyle.skin_button(&"normal"))
	t.set_stylebox(&"tab_hovered", &"TabContainer", ShellChromeStyle.skin_button(&"hover"))
	t.set_stylebox(&"panel", &"TabContainer", ShellChromeStyle.skin_panel())
	for type: StringName in [&"TabBar", &"TabContainer"]:
		t.set_font(&"font", type, bold)
		t.set_color(&"font_selected_color", type, TEXT_LIT)
		t.set_color(&"font_unselected_color", type, TEXT_DIM)
		t.set_color(&"font_hovered_color", type, TEXT)

	# Text entry.
	t.set_stylebox(&"normal", &"LineEdit", ShellChromeStyle.skin_inset())
	t.set_stylebox(&"focus", &"LineEdit", ShellChromeStyle.skin_focus())
	t.set_color(&"font_color", &"LineEdit", TEXT)

	# Bars: inset trough; light fill that callers tint via self_modulate or a
	# fill override (the HUD's HP bar keeps its own green).
	var trough := StyleBoxTexture.new()
	trough.texture = load(ShellChromeStyle.SKIN_DIR + "bar_back.png") as Texture2D
	trough.set_texture_margin_all(4)
	var fill := StyleBoxTexture.new()
	fill.texture = load(ShellChromeStyle.SKIN_DIR + "bar_fill.png") as Texture2D
	fill.set_texture_margin_all(4)
	fill.modulate_color = GOLD
	t.set_stylebox(&"background", &"ProgressBar", trough)
	t.set_stylebox(&"fill", &"ProgressBar", fill)

	# Menus.
	t.set_stylebox(&"panel", &"PopupMenu", ShellChromeStyle.skin_panel())
	t.set_stylebox(&"hover", &"PopupMenu", ShellChromeStyle.skin_button(&"hover"))
	t.set_color(&"font_color", &"PopupMenu", TEXT)
	t.set_color(&"font_hover_color", &"PopupMenu", TEXT_LIT)

	# Separators: gold rule with a centre stud.
	var rule := StyleBoxTexture.new()
	rule.texture = load(ShellChromeStyle.SKIN_DIR + "divider.png") as Texture2D
	rule.texture_margin_left = 20
	rule.texture_margin_right = 20
	t.set_stylebox(&"separator", &"HSeparator", rule)
	t.set_constant(&"separation", &"HSeparator", 10)

	# Heading variations.
	t.set_type_variation(&"HeaderLabel", &"Label")
	t.set_font(&"font", &"HeaderLabel", title)
	t.set_font_size(&"font_size", &"HeaderLabel", 20)
	t.set_color(&"font_color", &"HeaderLabel", GOLD)
	t.set_type_variation(&"TitleLabel", &"Label")
	t.set_font(&"font", &"TitleLabel", title)
	t.set_font_size(&"font_size", &"TitleLabel", 30)
	t.set_color(&"font_color", &"TitleLabel", TEXT_LIT)
	t.set_color(&"font_outline_color", &"TitleLabel", Color(0.08, 0.06, 0.04))
	t.set_constant(&"outline_size", &"TitleLabel", 4)
	return t

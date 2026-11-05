class_name TechNodeLabel
extends RefCounted
## Player-facing name of a Defense Building tech node ("Production II"),
## shared by the Defense Building screen and the Forge's locked-recipe hints.
## TechNodeResource stays data-only (ADR-0009), so the label lives here.
##
## Usage: TechNodeLabel.display_name(GGameDataRegistry.get_tech_node(&"tech_production_2"))

const CATEGORY_LABEL_KEYS: Dictionary[String, String] = {
	"production_tech": "DEFENSE_CATEGORY_PRODUCTION",
	"structural_tech": "DEFENSE_CATEGORY_STRUCTURAL",
	"economy_tech": "DEFENSE_CATEGORY_ECONOMY",
}
const ROMAN_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V"]


## Localized category label, or the raw category capitalized if unknown.
static func category_label(category: String) -> String:
	return TranslationServer.translate(CATEGORY_LABEL_KEYS[category]) if CATEGORY_LABEL_KEYS.has(category) \
			else category.capitalize()


## "<Category> <Roman tier>", e.g. "Production II".
static func display_name(node: TechNodeResource) -> String:
	var tier: String = ROMAN_NUMERALS[node.branch_tier] if node.branch_tier < ROMAN_NUMERALS.size() else str(node.branch_tier)
	return "%s %s" % [category_label(node.tech_category), tier]

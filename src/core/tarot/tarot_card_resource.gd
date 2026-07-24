class_name TarotCardResource
extends Resource

## Story 001 (TR-tarot-001, ADR-0027): static, immutable, GameDataRegistry-backed
## card data (assets/data/tarot/*.tres).
##
## Deliberately diverges from `design/gdd/tarot.md`'s own Rule 1 field table,
## which lists `unlocked`, `mastery_tier`, and `mastery_missions_played` as
## TarotCardResource fields — ADR-0027's own Decision Summary identifies this
## as the GDD's inconsistency to resolve: those 3 fields are exactly the
## "mutable per-playthrough state" this project's ADR-0003
## resource_object_in_save_data forbidden pattern bars from living on a
## shared boot-loaded Resource instance. They live on `TarotProgressLedger`
## (`tarot.gd`) instead, keyed by `card_id` — this Resource carries only the
## fixed, authored-once content. Matches this ADR's own Implementation Notes
## code sketch exactly (which likewise omits all 3 fields).

@export var card_id: StringName = &""
@export var rarity: String = "Common"  # Common | Rare | Legendary
@export var modifiers: Array[TarotModifierEntry] = []
@export var linked_rune_id: StringName = &""

## Story 005 (Formula F5): fixed value baked into this card's linked rune
## definition — "roughly half of its linked card's Tier-0 base_modifier_value's
## marginal effect, a design guideline, not a formula" per tarot.md's own
## F5 variable table. Only meaningful when linked_rune_id is non-empty.
@export_range(0.02, 0.10, 0.001) var rune_bonus_flat: float = 0.05

const VALID_RARITIES: Array[String] = ["Common", "Rare", "Legendary"]
const RUNE_BONUS_FLAT_RANGE: Vector2 = Vector2(0.02, 0.10)

## Confirms modifier_type membership (Rule 7's 4 registered types), rarity,
## the 1-2 entry count (Rule 2), and rune_bonus_flat's safe range when a
## rune is linked. Logs its own push_error() per invalid field and returns a
## bool — matches TowerBlueprintData's own validate() convention, which is
## what GameDataRegistry's loader loop expects.
func validate() -> bool:
	var ok := true
	if not VALID_RARITIES.has(rarity):
		push_error("[TarotCardResource '%s'] rarity '%s' not one of %s" % [card_id, rarity, VALID_RARITIES])
		ok = false
	if modifiers.is_empty() or modifiers.size() > 2:
		push_error("[TarotCardResource '%s'] modifiers must have 1-2 entries, has %d" % [card_id, modifiers.size()])
		ok = false
	for entry: TarotModifierEntry in modifiers:
		if not TarotModifierEntry.REGISTERED_MODIFIER_TYPES.has(entry.modifier_type):
			push_error("[TarotCardResource '%s'] modifier_type '%s' is not one of the 4 registered types" % [card_id, entry.modifier_type])
			ok = false
	if linked_rune_id != &"" and (rune_bonus_flat < RUNE_BONUS_FLAT_RANGE.x or rune_bonus_flat > RUNE_BONUS_FLAT_RANGE.y):
		push_error("[TarotCardResource '%s'] rune_bonus_flat %s outside [%s, %s]" % [card_id, rune_bonus_flat, RUNE_BONUS_FLAT_RANGE.x, RUNE_BONUS_FLAT_RANGE.y])
		ok = false
	return ok

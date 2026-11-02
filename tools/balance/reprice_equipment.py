"""Re-price equipment recipes from one table (2026-11-02 shop-spread pass).

The progression baseline showed the starter gear (3-8 "Material") bought out by
mission 1-4, so the Sanctuary shop emptied long before the campaign's ~mission
60 target (production/balance/progression-targets.md). This rewrites the
`inputs` of every recipe listed in PRICES; anything not listed is untouched.

Bands (cost keys follow Inventory's three axes: item_type, rarity, material id):
  starter  q1 gear      Material, rising 20 -> 100 so the first returns still buy something
  early    q2 gear      Common + Uncommon, needs tech_production_2
  mid      Steelwrought Common + Uncommon + iron_ore, above every q2 piece
  monster  q3/q4 sets   scaled by how fast their own material drops (ABUNDANCE),
                        so goblin/brute gear no longer undercuts the q2 band;
                        a price is never lowered (the rare boss sets already sit late)

Run, then re-run tools/balance/progression_sim.py to check the spread:
  python tools/balance/reprice_equipment.py
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
RECIPES = ROOT / "assets/data/equipment_recipes"

PRICES: dict[str, dict[str, int]] = {
    # starter (quality_tier 1): ~1 piece per return over missions 1-6
    "iron_sword": {"Material": 20},
    "leather_jerkin": {"Material": 30},
    "traveler_boots": {"Material": 45},
    "leather_gloves": {"Material": 55},
    "iron_helm": {"Material": 65},
    "leather_leggings": {"Material": 75},
    "wooden_buckler": {"Material": 85},
    "lucky_charm_trinket": {"Material": 95},
    "warding_band": {"Common": 100},
    # early (quality_tier 2): missions ~5-16
    "reinforced_helm": {"Common": 90, "Uncommon": 8},
    "reinforced_boots": {"Common": 100, "Uncommon": 9},
    "reinforced_gauntlets": {"Common": 110, "Uncommon": 10},
    "iron_greaves": {"Common": 120, "Uncommon": 11},
    "iron_buckler": {"Common": 130, "Uncommon": 12},
    "reinforced_plate": {"Common": 140, "Uncommon": 13},
    "iron_band": {"Common": 150, "Uncommon": 14},
    "silver_pendant": {"Common": 160, "Uncommon": 15},
    "steel_greatsword": {"Common": 175, "Uncommon": 16},
    # mid (Steelwrought): missions ~15-30
    "steelwrought_sabatons": {"Common": 190, "Uncommon": 18, "iron_ore": 10},
    "steelwrought_signet": {"Common": 200, "Uncommon": 19},
    "steelwrought_torc": {"Common": 210, "Uncommon": 20},
    "steelwrought_gauntlets": {"Common": 220, "Uncommon": 21, "iron_ore": 12},
    "steelwrought_helm": {"Common": 230, "Uncommon": 22, "iron_ore": 12},
    "steelwrought_kite_shield": {"Common": 240, "Uncommon": 23, "iron_ore": 14},
    "steelwrought_legplates": {"Common": 250, "Uncommon": 24, "iron_ore": 14},
    "steelwrought_cuirass": {"Common": 265, "Uncommon": 26, "iron_ore": 16},
    "steelwrought_longsword": {"Common": 280, "Uncommon": 28, "iron_ore": 18},
}


## Expected drops per mission (progression_sim, 8-map campaign, 2026-11-02).
ABUNDANCE: dict[str, float] = {
    "iron_plating": 29.2, "goblin_hide": 34.0, "troll_hide": 16.8, "lurker_ichor": 7.8,
    "warlord_iron": 4.6, "rift_shard": 4.0, "brute_core": 8.4, "goblin_fang": 16.4,
    "troll_marrow": 5.6, "bog_pearl": 3.6, "warlord_emblem": 1.3, "sentinel_core": 1.3,
}
## Missions-worth of the family material per piece, by quality tier, plus the
## flat Uncommon price and the missions-worth of the q4 trophy material.
MONSTER_TIERS: dict[int, dict[str, float]] = {
    3: {"family_missions": 5.0, "uncommon": 18},
    4: {"family_missions": 9.0, "uncommon": 26, "trophy_missions": 3.0},
}


def monster_price(current: dict[str, int], tier: int) -> dict[str, int]:
    """Scales a q3/q4 recipe's inputs; never returns a lower amount than today."""
    rule = MONSTER_TIERS[tier]
    out: dict[str, int] = {}
    keys = list(current)
    for i, (key, qty) in enumerate(current.items()):
        if key == "Uncommon":
            target = rule["uncommon"]
        elif key in ABUNDANCE and i == 0:
            target = ABUNDANCE[key] * rule["family_missions"]
        elif key in ABUNDANCE:
            target = ABUNDANCE[key] * rule.get("trophy_missions", rule["family_missions"])
        else:
            target = qty * 2  # e.g. lurker_fang_blade's iron_ore
        out[key] = max(qty, round(target))
    assert list(out) == keys
    return out


def read_inputs(text: str) -> dict[str, int]:
    block = re.search(r"inputs = \{(.*?)\}", text, re.S).group(1)
    return {k: int(v) for k, v in re.findall(r'&"(\w+)":\s*(\d+)', block)}


def format_inputs(cost: dict[str, int]) -> str:
    body = ",\n".join(f'&"{k}": {v}' for k, v in cost.items())
    return "inputs = {\n" + body + "\n}"


def main() -> None:
    for item_id, cost in PRICES.items():
        path = RECIPES / f"recipe_{item_id}.tres"
        text = path.read_text(encoding="utf-8")
        new, n = re.subn(r"inputs = \{.*?\}", format_inputs(cost), text, count=1, flags=re.S)
        if n != 1:
            raise SystemExit(f"{path.name}: no inputs block")
        path.write_text(new, encoding="utf-8", newline="\n")
    scaled = 0
    for path in sorted(RECIPES.glob("recipe_*.tres")):
        text = path.read_text(encoding="utf-8")
        tier = int(re.search(r"quality_tier = (\d)", text).group(1))
        if tier not in MONSTER_TIERS or path.stem.removeprefix("recipe_") in PRICES:
            continue
        cost = monster_price(read_inputs(text), tier)
        path.write_text(re.sub(r"inputs = \{.*?\}", format_inputs(cost), text, count=1, flags=re.S),
                        encoding="utf-8", newline="\n")
        scaled += 1
    print(f"re-priced {len(PRICES)} recipes, scaled {scaled} monster-set recipes")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Progression simulator for Sanctuary Defenders.

Answers "after N missions, where is the player?" -- hero level, skill tree
points, materials by rarity, and the mission each sanctuary purchase first
becomes affordable -- so progression changes can be compared as numbers.

It reads the game's own data, so it stays in sync with every edit:
  assets/data/missions/entries/*.tres   mission -> wave config
  assets/data/waves/*.tres              monsters per wave, difficulty_growth_rate
  assets/data/monsters/*.tres           tier, drop table, menagerie lure chance
  assets/data/drop_tables/*.tres        drop rate, entries, quantities
  assets/data/items/*.tres              material rarity
  assets/data/defense_building/**, recipes/, equipment_recipes/,
  building_upgrades/                    sanctuary costs (the sinks)
  src/core/hero/hero.gd                 XP constants and the level curve
  src/core/resource_economy/resource_economy.gd   surplus constants
  src/core/difficulty_rewards.gd        tier reward multipliers, Ascension growth
  src/core/ascension_rewards.gd         Ascendant Shard income
  src/core/inventory/inventory.gd, slot_expansion_cost_table.gd   bag size
  src/core/resource_economy/sanctuary_gold.gd, resource_economy.gd,
  src/gameplay/wave_manager.gd, assets/data/towers/blueprints/
                                        Sanctuary gold (mission gold in,
                                        conversion rate, Forge prices)

Endgame (--ascend-after N): from mission N+1 each visit to a map climbs one
Ascension rank on it, as far as the hero's modelled power supports (the
"Rank to match" column), earning Ascendant Shards and the higher reward
multiplier. Bag: income that doesn't fit the bag is lost (shards are held,
as in the game); bag expansions are bought like any other purchase.

The model is expected value (no RNG): a 45% drop of 2 hide counts as 0.9
hide. That's right for averages across many missions; single runs vary.

Assumptions the game data can't supply are flags (see --help) and are
printed at the top of every report. What-if flags (--xp-growth,
--level-cap, --tier-reward ...) override the real values without
touching the game.

Sanctuary gold: each mission's gold income (scout grant + wave grants,
optionally early-call gold) minus tower placements is the gold held at the
end; it banks at the conversion rate (Treasury techs raise it, bought like
any other purchase), and Forge crafts need that gold as well as materials.
--no-sanctuary-gold restores the old materials-only shopping.

Usage (repo root):
  python tools/balance/progression_sim.py
  python tools/balance/progression_sim.py --missions 60 --xp-growth 1.08 --level-cap 30
  python tools/balance/progression_sim.py --difficulty 3 --tier-reward 1,1.3,1.7
  python tools/balance/progression_sim.py --missions 120 --ascend-after 40
  python tools/balance/progression_sim.py --out production/balance/progression-baseline.md
"""
from __future__ import annotations

import argparse
import math
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "assets" / "data"
TIER_NAMES = {0: "standard", 1: "elite", 2: "boss"}
RARITIES = ("Common", "Uncommon", "Rare")


# --- .tres parsing ------------------------------------------------------------

_SECTION = re.compile(r'^\[(\w+)(.*)\]\s*$')
_ID = re.compile(r'\bid="([^"]+)"')


def parse_tres(path: Path) -> tuple[dict, dict]:
    """Returns (resource_props, {sub_resource_id: props}). Values stay raw
    strings except multi-line {...} blocks, which are joined into one."""
    subs: dict[str, dict] = {}
    res: dict = {}
    cur: dict | None = None
    pending_key, pending = None, []
    for line in path.read_text(encoding="utf-8").splitlines():
        if pending_key is not None:
            pending.append(line)
            if line.strip() == "}" or line.strip().endswith("})"):
                cur[pending_key] = "\n".join(pending)
                pending_key = None
            continue
        m = _SECTION.match(line)
        if m:
            kind, rest = m.groups()
            if kind == "sub_resource":
                cur = subs.setdefault(_ID.search(rest).group(1), {})
            elif kind == "resource":
                cur = res
            else:
                cur = None
            continue
        if cur is None or " = " not in line:
            continue
        key, val = line.split(" = ", 1)
        if val.rstrip().endswith("{") or (val.count("{") > val.count("}")):
            pending_key, pending = key.strip(), [val]
            continue
        cur[key.strip()] = val.strip()
    return res, subs


def s_val(raw: str | None, default: str = "") -> str:
    if raw is None:
        return default
    m = re.search(r'"([^"]*)"', raw)
    return m.group(1) if m else raw


def n_val(raw: str | None, default: float = 0.0) -> float:
    return float(raw) if raw is not None else default


def dict_val(raw: str | None) -> dict[str, float]:
    """{&"Common": 15, "iron_plating": 2} -> {"Common": 15.0, ...}. Non-numeric
    values (StringName requirements) come back as strings."""
    out: dict = {}
    if not raw:
        return out
    for k, v in re.findall(r'&?"([^"]+)"\s*:\s*([^,\n}]+)', raw):
        v = v.strip()
        try:
            out[k] = float(v)
        except ValueError:
            out[k] = s_val(v)
    return out


def sub_refs(raw: str | None) -> list[str]:
    return re.findall(r'SubResource\("([^"]+)"\)', raw or "")


# --- Constants pulled from the GDScript -----------------------------------------

def gd_const(src: str, name: str, default):
    m = re.search(rf'^const {name}\s*(?::[^=]*)?=\s*([^\n#]+)', src, re.M)  # ":=" (inferred) too
    if not m:
        print(f"warning: const {name} not found, using {default}", file=sys.stderr)
        return default
    raw = m.group(1).strip()
    try:
        return type(default)(float(raw)) if not isinstance(default, int) else int(float(raw))
    except ValueError:
        return raw


@dataclass
class Rules:
    xp_base: float = 100.0
    xp_growth: float = 1.15
    level_cap: int = 50
    kill_xp: dict = field(default_factory=lambda: {0: 5, 1: 15, 2: 100})
    outer_band_mult: float = 0.5
    wave_xp: int = 25
    mission_xp: int = 150
    skill_point_interval: int = 5
    surplus_per_slot: int = 1
    archetype_bonus_qty: int = 2
    archetype_map: dict = field(default_factory=dict)


def load_rules() -> Rules:
    hero = (ROOT / "src/core/hero/hero.gd").read_text(encoding="utf-8")
    eco = (ROOT / "src/core/resource_economy/resource_economy.gd").read_text(encoding="utf-8")
    r = Rules()
    m = re.search(r'floor\(([\d.]+)\s*\*\s*pow\(([\d.]+),', hero)
    m_const = re.search(r'floor\(([\d.]+)\s*\*\s*pow\(XP_CURVE_GROWTH,', hero)
    if m:
        r.xp_base, r.xp_growth = float(m.group(1)), float(m.group(2))
    elif m_const:
        r.xp_base, r.xp_growth = float(m_const.group(1)), gd_const(hero, "XP_CURVE_GROWTH", 1.15)
    else:
        print("warning: level curve not found in hero.gd, using 100 x 1.15^(L-1)", file=sys.stderr)
    r.level_cap = gd_const(hero, "LEVEL_CAP", 50)
    m = re.search(r'KILL_XP_BY_TIER[^{]*\{([^}]*)\}', hero)
    if m:
        r.kill_xp = {int(k): int(v) for k, v in re.findall(r'(\d+)\s*:\s*(\d+)', m.group(1))}
    r.outer_band_mult = gd_const(hero, "KILL_XP_OUTER_BAND_MULTIPLIER", 0.5)
    r.wave_xp = gd_const(hero, "WAVE_COMPLETION_XP", 25)
    r.mission_xp = gd_const(hero, "MISSION_COMPLETION_XP", 150)
    r.skill_point_interval = gd_const(hero, "SKILL_POINT_LEVEL_INTERVAL", 5)
    r.surplus_per_slot = gd_const(eco, "BASE_SURPLUS_PER_SLOT", 1)
    r.archetype_bonus_qty = gd_const(eco, "ARCHETYPE_BONUS_QUANTITY", 2)
    m = re.search(r'ARCHETYPE_BONUS_MATERIAL_MAP[^{]*\{([^}]*)\}', eco)
    if m:
        r.archetype_map = dict(re.findall(r'"(\w+)"\s*:\s*&"(\w+)"', m.group(1)))
    return r


def load_tier_multipliers() -> list[float]:
    src = (ROOT / "src/core/difficulty_rewards.gd").read_text(encoding="utf-8")
    m = re.search(r'TIER_MULTIPLIERS[^=]*=\s*\[([^\]]*)\]', src)
    if not m:
        print("warning: TIER_MULTIPLIERS not found, using 1,1,1", file=sys.stderr)
        return [1.0, 1.0, 1.0]
    return [float(x) for x in m.group(1).split(",")]


# --- Game data --------------------------------------------------------------

@dataclass
class Mission:
    mission_id: str
    name: str
    growth: float
    waves: list[list[str]]  # monster ids per wave


@dataclass
class Purchase:
    name: str
    category: str
    cost: dict[str, float]          # rarity name or item id -> qty
    prereq: str = ""                # another Purchase.name
    also_needs: str = ""            # non-material requirements, shown only
    gold: int = 0


def load_missions() -> dict[str, Mission]:
    out = {}
    for f in sorted((DATA / "missions/entries").glob("*.tres")):
        res, _ = parse_tres(f)
        wave_path = ROOT / s_val(res.get("wave_config_path")).replace("res://", "")
        wres, wsubs = parse_tres(wave_path)
        waves = []
        for script_id in sub_refs(wres.get("wave_scripts")):
            waves.append([s_val(wsubs[e].get("monster_id")) for e in sub_refs(wsubs[script_id].get("entries"))])
        mid = s_val(res.get("mission_id"))
        out[mid] = Mission(mid, s_val(res.get("display_name")), n_val(wres.get("difficulty_growth_rate"), 0.2), waves)
    return out


def load_monsters() -> dict[str, dict]:
    out = {}
    for f in (DATA / "monsters").glob("*.tres"):
        res, _ = parse_tres(f)
        out[s_val(res.get("monster_id"))] = {
            "tier": int(n_val(res.get("tier"))),
            "drops": s_val(res.get("drop_table_id")),
            "lure": n_val(res.get("menagerie_attraction_drop_chance")),
        }
    return out


def load_drop_tables() -> dict[str, dict]:
    out = {}
    for f in (DATA / "drop_tables").glob("*.tres"):
        res, subs = parse_tres(f)
        out[s_val(res.get("drop_table_id"))] = {
            "rate": n_val(res.get("base_drop_rate"), 0.45),
            "min": int(n_val(res.get("guaranteed_min_quantity"), 1)),
            "entries": [(s_val(subs[e].get("material_id")), int(n_val(subs[e].get("base_quantity"), 1)))
                        for e in sub_refs(res.get("entries"))],
        }
    return out


def load_items() -> tuple[dict[str, str], dict[str, str]]:
    """(item_id -> rarity, item_id -> item_type)."""
    rarity, kind = {}, {}
    for f in (DATA / "items").glob("*.tres"):
        res, _ = parse_tres(f)
        iid = s_val(res.get("item_id"))
        if res.get("rarity"):
            rarity[iid] = s_val(res.get("rarity"))
        kind[iid] = s_val(res.get("item_type"))
    return rarity, kind


def load_item_flags() -> tuple[set[str], dict[str, int]]:
    """(items kept out of item_type costs, item_id -> own stack cap)."""
    excluded, caps = set(), {}
    for f in (DATA / "items").glob("*.tres"):
        res, _ = parse_tres(f)
        iid = s_val(res.get("item_id"))
        if s_val(res.get("excluded_from_type_costs")) == "true":
            excluded.add(iid)
        cap = int(n_val(res.get("stack_cap")))
        if cap > 0:
            caps[iid] = cap
    return excluded, caps


@dataclass
class BagRules:
    start_slots: int = 18
    stack_cap: int = 99
    expansions: list = field(default_factory=list)  # [(slots_after, {rarity: qty})]


def load_bag_rules() -> BagRules:
    inv = (ROOT / "src/core/inventory/inventory.gd").read_text(encoding="utf-8")
    table = (ROOT / "src/core/inventory/slot_expansion_cost_table.gd").read_text(encoding="utf-8")
    # The hero's equip slots live in the same slot array (EQUIPMENT_SLOT_INDEX),
    # so the bag is the slot count minus them: 18 - 10 = 8 at the start.
    m = re.search(r'EQUIPMENT_SLOT_NAMES[^=]*=\s*\[([^\]]*)\]', inv)
    equip = len(re.findall(r'"\w+"', m.group(1))) if m else 10
    b = BagRules(gd_const(inv, "STARTING_SLOT_COUNT", 18) - equip, gd_const(inv, "STACK_CAP_STACKABLE", 99))
    for m in re.finditer(r'(\d+):\s*\{KEY_SLOTS_AFTER:\s*(\d+),\s*KEY_COMMON:\s*(\d+),\s*'
                         r'KEY_UNCOMMON:\s*(\d+),\s*KEY_RARE:\s*(\d+)\}', table):
        cost = {k: float(v) for k, v in zip(RARITIES, m.group(3, 4, 5)) if int(v) > 0}
        b.expansions.append((int(m.group(2)) - equip, cost))
    if not b.expansions:
        print("warning: SlotExpansionCostTable rows not found, bag never grows", file=sys.stderr)
    return b


class Bag:
    """Slot-limited stacks. add() returns what didn't fit."""

    def __init__(self, slots: int, default_cap: int, caps: dict[str, int]):
        self.slots = slots
        self.default_cap = default_cap
        self.caps = caps

    def cap(self, item: str) -> int:
        return self.caps.get(item, self.default_cap)

    def used(self, inv: dict[str, float]) -> int:
        return sum(math.ceil(q / self.cap(i) - 1e-9) for i, q in inv.items() if q > 1e-9)

    def add(self, inv: dict[str, float], item: str, qty: float) -> float:
        cap = self.cap(item)
        have = inv.get(item, 0.0)
        open_in_stacks = math.ceil(have / cap - 1e-9) * cap - have if have > 1e-9 else 0.0
        room = open_in_stacks + max(0, self.slots - self.used(inv)) * cap
        put = min(qty, room)
        inv[item] = have + put
        return qty - put


def load_gear_stats() -> dict[str, tuple[str, float]]:
    """Equipment item_id -> (equipment_category, physical_attack)."""
    out = {}
    for f in (DATA / "items").glob("*.tres"):
        res, _ = parse_tres(f)
        cat = s_val(res.get("equipment_category"))
        if not cat:
            continue
        m = re.search(r'physical_attack"\s*:\s*([\d.]+)', res.get("base_stats") or "")
        out[s_val(res.get("item_id"))] = (cat, float(m.group(1)) if m else 0.0)
    return out


@dataclass
class PowerRules:
    """Hero attack growth and enemy HP scaling, read from the game code."""
    base_attack: float = 25.0
    attack_per_level: float = 2.0
    hp_tier_rate: float = 0.35
    brutal_tier: int = 3
    max_ascension: int = 10
    asc_hp_growth: float = 1.15
    asc_reward_growth: float = 1.12


def load_salvage_rules() -> tuple[int, dict[str, str]]:
    """(inputs per output, input rarity -> output item) from SalvageRules."""
    src = (ROOT / "src/core/inventory/salvage_rules.gd").read_text(encoding="utf-8")
    ratio = gd_const(src, "RATIO", 20)
    out = dict(re.findall(r'"(\w+)":\s*&"(\w+)"', src[src.find("OUTPUT_BY_RARITY"):]))
    return ratio, out


def load_shard_rules() -> tuple[int, int]:
    """(first-clear shards per rank, every-win shards per rank) from AscensionRewards."""
    src = (ROOT / "src/core/ascension_rewards.gd").read_text(encoding="utf-8")
    return gd_const(src, "FIRST_CLEAR_SHARDS_PER_RANK", 10), gd_const(src, "RUN_SHARDS_PER_RANK", 2)


def supported_rank(attack: float, start_attack: float, pr: "PowerRules") -> int:
    """Highest Ascension rank whose enemy HP growth the hero's attack growth covers."""
    ratio = attack / start_attack
    brutal_hp = 1.0 + pr.hp_tier_rate * (pr.brutal_tier - 1)
    if ratio <= brutal_hp:
        return 0
    return min(pr.max_ascension, int(math.floor(math.log(ratio / brutal_hp) / math.log(pr.asc_hp_growth))))


def load_power_rules() -> PowerRules:
    hero = (ROOT / "src/core/hero/hero.gd").read_text(encoding="utf-8")
    mm = (ROOT / "src/core/monster/monster_manager.gd").read_text(encoding="utf-8")
    dr = (ROOT / "src/core/difficulty_rewards.gd").read_text(encoding="utf-8")
    r = PowerRules()
    m = re.search(r'&"physical_attack":\s*([\d.]+)', hero[hero.find("PLACEHOLDER_BASE_STATS"):])
    if m:
        r.base_attack = float(m.group(1))
    m = re.search(r'_base_stats\[&"physical_attack"\][^\n]*\+\s*([\d.]+)\s*$', hero, re.M)
    if m:
        r.attack_per_level = float(m.group(1))
    r.hp_tier_rate = gd_const(mm, "HP_DIFFICULTY_GROWTH_RATE", 0.35)
    r.brutal_tier = gd_const(dr, "BRUTAL_TIER", 3)
    r.max_ascension = gd_const(dr, "MAX_ASCENSION", 10)
    r.asc_hp_growth = gd_const(dr, "ASCENSION_HP_GROWTH", 1.15)
    r.asc_reward_growth = gd_const(dr, "ASCENSION_REWARD_GROWTH", 1.12)
    return r


@dataclass
class GoldRules:
    """Mission gold income and Sanctuary gold, read from the game code."""
    scout_gold: int = 50
    base_wave_gold: int = 20
    early_call_per_second: float = 0.2
    intermission_seconds: float = 30.0
    scalar_cap: float = 4.768
    base_rate: float = 0.25
    rate_per_tech: float = 0.10
    treasury_ids: tuple = ()
    craft_cost_base: int = 80
    avg_tower_cost: float = 20.0


def load_gold_rules() -> GoldRules:
    re_src = (ROOT / "src/core/resource_economy/resource_economy.gd").read_text(encoding="utf-8")
    sg = (ROOT / "src/core/resource_economy/sanctuary_gold.gd").read_text(encoding="utf-8")
    wm = (ROOT / "src/gameplay/wave_manager.gd").read_text(encoding="utf-8")
    g = GoldRules()
    g.scout_gold = gd_const(re_src, "SCOUT_STARTING_GOLD", g.scout_gold)
    g.base_wave_gold = gd_const(re_src, "BASE_WAVE_GOLD", g.base_wave_gold)
    g.early_call_per_second = gd_const(re_src, "EARLY_CALL_GOLD_PER_SECOND", g.early_call_per_second)
    m = re.search(r'@export var intermission_duration_sec: float = ([\d.]+)', wm)
    if m:
        g.intermission_seconds = float(m.group(1))
    m = re.search(r'1\.00, ([\d.]+)\)', wm)
    if m:
        g.scalar_cap = float(m.group(1))
    g.base_rate = gd_const(sg, "BASE_CONVERSION_RATE", g.base_rate)
    g.rate_per_tech = gd_const(sg, "CONVERSION_RATE_PER_TECH", g.rate_per_tech)
    g.craft_cost_base = gd_const(sg, "CRAFT_COST_BASE", g.craft_cost_base)
    m = re.search(r'const TREASURY_TECH_IDS[^=]*=\s*\[([^\]]*)\]', sg)
    g.treasury_ids = tuple(re.findall(r'&"([^"]+)"', m.group(1))) if m else ()
    costs = []
    for f in sorted((DATA / "towers/blueprints").glob("*.tres")):
        r, _ = parse_tres(f)
        if r.get("placement_cost"):
            costs.append(n_val(r.get("placement_cost")))
    if costs:
        g.avg_tower_cost = sum(costs) / len(costs)
    return g


def craft_gold_cost(quality_tier: int, g: GoldRules) -> int:
    """SanctuaryGold.craft_cost: base x tier, tier clamped 1-4."""
    return g.craft_cost_base * max(1, min(4, quality_tier))


def mission_gold_income(m: "Mission", g: GoldRules, early_call_share: float) -> float:
    """Scout grant + Formula 5 wave grants, + Formula 5b early-call gold for
    `early_call_share` of each intermission skipped (after every wave but the last)."""
    total = float(g.scout_gold)
    for w in range(len(m.waves)):
        scalar = min(g.scalar_cap, max(1.0, (1.0 + m.growth) ** w))
        total += round(g.base_wave_gold * scalar)
        if w < len(m.waves) - 1 and early_call_share > 0.0:
            total += round(g.intermission_seconds * early_call_share * g.early_call_per_second * scalar)
    return total


TREE_PURCHASES = 46  # 4 archetypes x 11 + 2 bridges (HeroSkillTree terminal state)


def load_tree_attack(stat: str = "physical_attack") -> float:
    """Best permanent additive `stat` a completed Hero Skill Tree can give.

    Per archetype: the better fork side of each fork (all 3 depths) and the
    better keystone; plus the best 2 bridges. Stat nodes only: conditional
    notables (stack buffs, on-cast, wave-start) are left out, so this is a floor.
    """
    raw = (DATA / "hero_tree/hero_tree_catalog.tres").read_text(encoding="utf-8")
    nodes = []
    for block in raw.split("[sub_resource")[1:]:
        g = lambda k: (re.search(rf'^{k} = (.*)$', block, re.M) or [None, ""])[1]
        add = re.search(rf'&"{stat}":\s*(-?[\d.]+)', g("additive_stats"))
        nodes.append((g("archetype").strip('&"'), g("slot").strip('&"'), g("side").strip('&"'),
                      float(add.group(1)) if add else 0.0))
    total = 0.0
    sides: dict[tuple[str, str, str], float] = defaultdict(float)
    bridges = []
    for arch, slot, side, v in nodes:
        if slot == "bridge":
            bridges.append(v)
        elif slot == "root":
            total += v
        else:
            sides[(arch, slot, side)] += v
    best: dict[tuple[str, str], float] = {}
    for (arch, slot, _side), v in sides.items():
        best[(arch, slot)] = max(best.get((arch, slot), v), v)
    return total + sum(max(0.0, v) for v in best.values()) + sum(sorted(bridges, reverse=True)[:2])


def load_purchases(gold_rules: "GoldRules | None" = None) -> list[Purchase]:
    out: list[Purchase] = []
    for f in sorted((DATA / "defense_building/tech_nodes").glob("*.tres")):
        r, _ = parse_tres(f)
        out.append(Purchase(s_val(r.get("tech_id")), "tech", dict_val(r.get("material_costs")),
                            s_val(r.get("prerequisite_tech_id")), gold=int(n_val(r.get("gold_cost")))))
    for f in sorted((DATA / "defense_building/structures").glob("*.tres")):
        r, _ = parse_tres(f)
        pre = s_val(r.get("prerequisite_structure_id")) or s_val(r.get("tech_gate"))
        out.append(Purchase(s_val(r.get("structure_id")), "structure", dict_val(r.get("material_costs")), pre,
                            gold=int(n_val(r.get("gold_cost")))))
    for f in sorted((DATA / "recipes").glob("*.tres")):
        r, _ = parse_tres(f)
        kind = s_val(r.get("recipe_category"), "recipe").replace("_", " ")
        out.append(Purchase(s_val(r.get("output_item_id")), kind, dict_val(r.get("inputs")),
                            s_val(r.get("tech_prerequisite"))))
    for f in sorted((DATA / "equipment_recipes").glob("*.tres")):
        r, _ = parse_tres(f)
        gold = craft_gold_cost(int(n_val(r.get("quality_tier"), 1)), gold_rules) if gold_rules else 0
        out.append(Purchase(s_val(r.get("output_item_id")), "equipment", dict_val(r.get("inputs")),
                            s_val(r.get("tech_prerequisite")), gold=gold))
    for f in sorted((DATA / "building_upgrades").glob("*.tres")):
        r, _ = parse_tres(f)
        req = dict_val(r.get("requirements"))
        out.append(Purchase(s_val(r.get("upgrade_id")), "upgrade", dict_val(r.get("material_cost")),
                            s_val(r.get("prerequisite_upgrade_id")),
                            also_needs=", ".join(f"{k}:{v}" for k, v in req.items()),
                            gold=int(n_val(r.get("gold_cost")))))
    return out


# --- Model ------------------------------------------------------------------

@dataclass
class Assumptions:
    hero_inner: float
    hero_outer: float
    towers: int
    foundation_tier: int
    archetype: str
    difficulty: int
    tier_reward: list[float]
    menagerie_bonus: float
    win_rate: float
    drop_mult: float = 1.0
    asc_reward_growth: float = 1.12


def tier_multiplier(tier: int, a: Assumptions) -> float:
    """DifficultyRewards.multiplier_for_tier: base for tiers 1-3, x growth per Ascension rank."""
    base = a.tier_reward[min(tier, 3) - 1]
    return base * a.asc_reward_growth ** max(0, tier - 3)


def mission_yield(m: Mission, a: Assumptions, rules: Rules, monsters: dict, tables: dict,
                  tier: int | None = None) -> dict:
    """Expected XP and materials for one attempt at mission `m` (at `tier`, default a.difficulty)."""
    mult = tier_multiplier(tier or a.difficulty, a)
    mats: dict[str, float] = defaultdict(float)
    kills = defaultdict(int)
    xp = 0.0
    for w, wave in enumerate(m.waves):
        scalar = (1.0 + m.growth) ** w
        for mid in wave:
            mon = monsters.get(mid)
            if mon is None:
                print(f"warning: {m.mission_id} wave {w + 1}: unknown monster {mid}", file=sys.stderr)
                continue
            kills[mon["tier"]] += 1
            base = rules.kill_xp.get(mon["tier"], 0)
            xp += a.hero_inner * base + a.hero_outer * math.floor(base * rules.outer_band_mult)
            mats["menagerie_lure"] += mon["lure"]
            table = tables.get(mon["drops"])
            if table is None:
                continue
            for mat, qty in table["entries"]:
                q = max(round(qty * scalar * a.menagerie_bonus), table["min"])
                mats[mat] += table["rate"] * q * a.drop_mult
        xp += rules.wave_xp
    # A defeat keeps kill XP/drops so far; this treats a loss as a full run
    # without the completion XP and surplus (an upper bound on loss income).
    xp += rules.mission_xp * a.win_rate
    surplus = rules.surplus_per_slot * a.foundation_tier * a.towers * a.win_rate
    for part in ("foundation", "weapon", "focus", "power"):
        mats[f"{part}_surplus"] += surplus
    arch_mat = rules.archetype_map.get(a.archetype)
    if arch_mat:
        mats[arch_mat] += rules.archetype_bonus_qty * a.towers * a.win_rate
    return {"xp": xp * mult, "mats": {k: v * mult for k, v in mats.items()}, "kills": dict(kills),
            "waves": len(m.waves)}


def xp_required(level: int, rules: Rules) -> int:
    return int(math.floor(rules.xp_base * rules.xp_growth ** (level - 1)))


def level_for_xp(total: float, rules: Rules) -> int:
    level = 1
    while level < rules.level_cap and total >= xp_required(level, rules):
        total -= xp_required(level, rules)
        level += 1
    return level


def by_rarity(mats: dict[str, float], rarity: dict[str, str]) -> dict[str, float]:
    out = defaultdict(float)
    for k, v in mats.items():
        out[rarity.get(k, "?")] += v
    return out


class Pools:
    """A cost key is a rarity ("Common"), an item_type ("Material") or a
    specific item id -- the three axes Inventory checks (has_items_by_rarity,
    has_items, has_items_by_material_id)."""

    def __init__(self, rarity: dict[str, str], item_type: dict[str, str], excluded: set[str] | None = None):
        self.rarity = rarity
        self.item_type = item_type
        self.types = set(item_type.values())
        self.excluded = excluded or set()  # excluded_from_type_costs (lures, shards)

    def members(self, key: str, inv: dict[str, float]) -> list[str] | None:
        if key in RARITIES:
            return [i for i in inv if self.rarity.get(i) == key]
        if key in self.types:
            return [i for i in inv if self.item_type.get(i) == key and i not in self.excluded]
        return None

    def can_afford(self, cost: dict, inv: dict[str, float]) -> bool:
        left = dict(inv)
        return self._take(cost, left)

    def spend(self, cost: dict, inv: dict[str, float]) -> None:
        self._take(cost, inv)

    def _take(self, cost: dict, inv: dict[str, float]) -> bool:
        # Specific items first, then pooled keys from the largest stacks.
        for k, v in sorted(cost.items(), key=lambda kv: self.members(kv[0], inv) is not None):
            group = self.members(k, inv)
            if group is None:
                if inv.get(k, 0.0) + 1e-9 < v:
                    return False
                inv[k] -= v
                continue
            for item in sorted(group, key=lambda i: -inv[i]):
                take = min(inv[item], v)
                inv[item] -= take
                v -= take
                if v <= 1e-9:
                    break
            if v > 1e-9:
                return False
        return True


# --- Report -----------------------------------------------------------------

def fmt(x: float) -> str:
    return f"{x:,.0f}" if abs(x) >= 10 else f"{x:.1f}"


def run(args) -> str:
    rules = load_rules()
    if args.xp_growth:
        rules.xp_growth = args.xp_growth
    if args.level_cap:
        rules.level_cap = args.level_cap
    if args.mission_xp is not None:
        rules.mission_xp = args.mission_xp
    if args.wave_xp is not None:
        rules.wave_xp = args.wave_xp
    missions = load_missions()
    monsters = load_monsters()
    tables = load_drop_tables()
    rarity, item_type = load_items()
    excluded, stack_caps = load_item_flags()
    pools = Pools(rarity, item_type, excluded)
    gold_rules = load_gold_rules()
    if args.craft_gold is not None:
        gold_rules.craft_cost_base = args.craft_gold
    if args.gold_rate is not None:
        gold_rules.base_rate = args.gold_rate
    use_gold = not args.no_sanctuary_gold
    purchases = load_purchases(gold_rules if use_gold else None)
    if not use_gold:
        for p in purchases:
            p.gold = 0
    tower_gold = args.tower_gold if args.tower_gold is not None else args.towers * gold_rules.avg_tower_cost
    bag_rules = load_bag_rules()
    if not args.no_bag:
        prev = ""
        for i, (slots_after, cost) in enumerate(bag_rules.expansions, 1):
            purchases.append(Purchase(f"bag_expansion_{i}", "bag", cost, prev, also_needs=f"-> {slots_after} slots"))
            prev = f"bag_expansion_{i}"
    pr = load_power_rules()
    first_clear_per_rank, run_per_rank = load_shard_rules()
    tier_reward = ([float(x) for x in args.tier_reward.split(",")] if args.tier_reward
                   else load_tier_multipliers())
    a = Assumptions(args.hero_inner, args.hero_outer, args.towers, args.foundation_tier, args.archetype,
                    args.difficulty, tier_reward, args.menagerie_bonus, args.win_rate, args.drop_mult,
                    pr.asc_reward_growth)
    plan = [p.strip() for p in args.plan.split(",")] if args.plan else list(missions)
    for p in plan:
        if p not in missions:
            sys.exit(f"unknown mission in --plan: {p} (have {', '.join(missions)})")
    yields = {mid: mission_yield(missions[mid], a, rules, monsters, tables) for mid in missions}

    L: list[str] = []
    L.append("# Progression simulation\n")
    L.append("Expected values (no RNG), from the live game data. Re-run after any data or formula edit.\n")
    L.append("## Assumptions\n")
    L.append(f"- Level curve: `{rules.xp_base:g} x {rules.xp_growth:g}^(L-1)`, cap {rules.level_cap}; "
             f"skill point every {rules.skill_point_interval} levels")
    L.append(f"- XP: kill {rules.kill_xp} (standard/elite/boss), wave {rules.wave_xp}, mission {rules.mission_xp}")
    L.append(f"- Hero kill share: {a.hero_inner:.0%} full XP, {a.hero_outer:.0%} half XP, rest none (`--hero-inner/--hero-outer`)")
    L.append(f"- {a.towers} towers placed, foundation tier {a.foundation_tier}, archetype `{a.archetype}` (surplus)")
    L.append(f"- Difficulty {a.difficulty}; reward multiplier per tier {tier_reward} "
             f"({'game values' if not args.tier_reward else 'WHAT-IF'})")
    L.append(f"- Menagerie quality bonus x{a.menagerie_bonus}, win rate {a.win_rate:.0%}, no tarot"
             + (f", kill drops x{a.drop_mult} (WHAT-IF)" if a.drop_mult != 1.0 else ""))
    L.append(f"- Plan (cycled): {' -> '.join(plan)}")
    if args.ascend_after:
        L.append(f"- Endgame from mission {args.ascend_after + 1}: each map visit climbs one Ascension rank, up to "
                 f"the rank the hero's power supports (max {pr.max_ascension}); shards {first_clear_per_rank} x rank "
                 f"first clear + {run_per_rank} x rank every win (`--ascend-after`)")
    else:
        L.append("- No Ascension climb (`--ascend-after N` to model the endgame)")
    L.append(f"- Bag: {bag_rules.start_slots} slots (Inventory slots minus the hero's equip slots), stacks of {bag_rules.stack_cap}"
             + (f" ({', '.join(f'{k} {v}' for k, v in sorted(stack_caps.items()))})" if stack_caps else "")
             + "; overflow lost, shards held; equipment assumed worn, crafted goods used"
             + ("; salvages when nearly full" if args.salvage else "")
             + ("; discards stacks nothing still uses" if args.discard else "; no discard")
             if not args.no_bag else "- Bag: unlimited (`--no-bag`)")
    if use_gold:
        L.append(f"- Sanctuary gold: mission income = scout {gold_rules.scout_gold} + wave grants "
                 f"`round({gold_rules.base_wave_gold} x min({gold_rules.scalar_cap:g}, (1+growth)^(w-1)))`"
                 + (f" + early calls skipping {args.early_call:.0%} of each {gold_rules.intermission_seconds:g} s intermission"
                    if args.early_call > 0 else "; no early calls (`--early-call`)")
                 + f"; towers cost {fmt(tower_gold)} a mission (`--tower-gold`; {args.towers} x avg blueprint "
                 f"{gold_rules.avg_tower_cost:.1f}); held gold banks at {gold_rules.base_rate:.0%} "
                 f"+ {gold_rules.rate_per_tech:.0%} per Treasury tech owned; crafting costs "
                 f"{gold_rules.craft_cost_base} x tier (tier 4+ = {craft_gold_cost(4, gold_rules)}); "
                 "imbues and rune slots not modelled")
    else:
        L.append("- Sanctuary gold: ignored (`--no-sanctuary-gold`)")
    L.append("")

    L.append("## One run of each mission\n")
    L.append("| Mission | Waves | Kills S/E/B | XP | Common | Uncommon | Rare | Surplus each | Lures |")
    L.append("|---|---|---|---|---|---|---|---|---|")
    for mid, y in yields.items():
        r = by_rarity({k: v for k, v in y["mats"].items() if not k.endswith("_surplus") and k != "menagerie_lure"}, rarity)
        k = y["kills"]
        L.append(f"| {missions[mid].name} | {y['waves']} | {k.get(0, 0)}/{k.get(1, 0)}/{k.get(2, 0)} | {fmt(y['xp'])} | "
                 f"{fmt(r.get('Common', 0))} | {fmt(r.get('Uncommon', 0))} | {fmt(r.get('Rare', 0))} | "
                 f"{fmt(y['mats'].get('foundation_surplus', 0))} | {y['mats'].get('menagerie_lure', 0):.2f} |")
    unknown = sorted({m for y in yields.values() for m in y["mats"] if m not in rarity and not m.endswith("_surplus")
                      and m != "menagerie_lure"})
    if unknown:
        L.append(f"\nMaterials with no rarity in assets/data/items (can't pay rarity costs): {', '.join(unknown)}")

    # Campaign timeline + greedy purchases (one shopping trip per return).
    xp_total = 0.0
    inv: dict[str, float] = defaultdict(float)
    earned: dict[str, float] = defaultdict(float)
    owned: set[str] = set()
    first_affordable: dict[str, int] = {}
    bought_at: dict[str, int] = {}
    timeline = []
    gear_stats = load_gear_stats()
    gear_attack_at: dict[int, float] = {}
    bag = Bag(bag_rules.start_slots, bag_rules.stack_cap, stack_caps)
    lost: dict[str, float] = defaultdict(float)
    discarded: dict[str, float] = defaultdict(float)
    salvaged: dict[str, float] = defaultdict(float)
    salvage_ratio, salvage_out = load_salvage_rules()
    lost_at: dict[int, float] = {}
    bag_at: dict[int, tuple[int, int]] = {}
    held_shards = 0.0
    sgold = 0.0
    sgold_spent = 0.0
    gold_at: dict[int, tuple[float, float, float, float, int]] = {}  # banked, rate, balance, spent, waiting
    gold_waits: dict[str, int] = {}  # purchase -> missions its materials sat ready while gold was short
    best_rank: dict[str, int] = defaultdict(int)
    rank_at: dict[int, int] = {}
    shards_at: dict[int, float] = {}
    yield_cache: dict[tuple[str, int], dict] = {}
    tree_attack = 0.0 if args.no_tree else load_tree_attack()
    # One tree purchase per Sanctuary visit (= per mission), ramping linearly to
    # the completed tree's best permanent attack at visit TREE_PURCHASES.
    tree_mult = lambda n: 1.0 + tree_attack * min(1.0, n / TREE_PURCHASES)
    start_attack = pr.base_attack  # set after mission 1, as the power table defines it
    attack_now = start_attack
    for n in range(1, args.missions + 1):
        mid = plan[(n - 1) % len(plan)]
        tier = args.difficulty
        shards = 0.0
        if args.ascend_after and n > args.ascend_after:
            rank = min(best_rank[mid] + 1, supported_rank(attack_now, start_attack, pr))
            if rank >= 1:
                tier = pr.brutal_tier + rank
                shards = run_per_rank * rank + (first_clear_per_rank * rank if rank > best_rank[mid] else 0)
                best_rank[mid] = max(best_rank[mid], rank)
        if (mid, tier) not in yield_cache:
            yield_cache[(mid, tier)] = mission_yield(missions[mid], a, rules, monsters, tables, tier)
        y = yield_cache[(mid, tier)]
        xp_total += y["xp"]
        lost_now = 0.0
        for k, v in sorted(y["mats"].items(), key=lambda kv: -kv[1]):
            earned[k] += v
            if args.no_bag:
                inv[k] += v
            else:
                left = bag.add(inv, k, v)
                lost[k] += left
                lost_now += left
        held_shards += shards
        earned["ascendant_shard"] += shards
        if args.no_bag:
            inv["ascendant_shard"] += held_shards
            held_shards = 0.0
        else:
            held_shards = bag.add(inv, "ascendant_shard", held_shards)
        lost_at[n] = lost_now
        banked = 0.0
        rate = 0.0
        if use_gold:
            held_gold = max(0.0, mission_gold_income(missions[mid], gold_rules, args.early_call) - tower_gold)
            rate = gold_rules.base_rate + gold_rules.rate_per_tech * sum(1 for t in gold_rules.treasury_ids if t in owned)
            banked = float(math.floor(held_gold * rate))
            sgold += banked
            earned["__sanctuary_gold__"] += banked
        rank_at[n] = max(best_rank.values(), default=0)
        shards_at[n] = earned["ascendant_shard"]
        for p in purchases:
            if p.name not in first_affordable and pools.can_afford(p.cost, earned) \
                    and earned["__sanctuary_gold__"] + 1e-9 >= p.gold:
                first_affordable[p.name] = n
        # Cheapest affordable first, prerequisites respected.
        waiting_now = 0
        for p in sorted(purchases, key=lambda p: sum(p.cost.values())):
            if p.name in owned or (p.prereq and p.prereq not in owned and any(q.name == p.prereq for q in purchases)):
                continue
            if pools.can_afford(p.cost, inv):
                if sgold + 1e-9 < p.gold:
                    gold_waits[p.name] = gold_waits.get(p.name, 0) + 1
                    waiting_now += 1
                    continue
                pools.spend(p.cost, inv)
                sgold -= p.gold
                sgold_spent += p.gold
                owned.add(p.name)
                bought_at[p.name] = n
                if p.category == "bag":
                    bag.slots = bag_rules.expansions[int(p.name.rsplit("_", 1)[1]) - 1][0]
        gold_at[n] = (banked, rate, sgold, sgold_spent, waiting_now)
        if args.salvage and not args.no_bag and bag.used(inv) >= bag.slots - 2:
            # Bag nearly full: refine Common/Uncommon stacks no remaining recipe names
            # by id (SalvageRules: RATIO inputs -> 1 output one rarity up).
            named = {k for p in purchases if p.name not in owned for k in p.cost}
            for rar in ("Common", "Uncommon"):
                out = salvage_out.get(rar)
                for item in [i for i, q in inv.items() if q >= salvage_ratio and rarity.get(i) == rar and i not in named]:
                    made = math.floor(inv[item] / salvage_ratio)
                    inv[item] -= made * salvage_ratio
                    salvaged[item] += made * salvage_ratio
                    left = bag.add(inv, out, made)
                    inv[item] += left * salvage_ratio  # didn't fit: not salvaged
                    salvaged[item] -= left * salvage_ratio
        if args.discard and not args.no_bag:
            # A tidy player throws away stacks no remaining purchase can use.
            wanted = [p.cost for p in purchases if p.name not in owned]
            for item in [i for i, q in inv.items() if q > 1e-9]:
                if not any(k == item or item in (pools.members(k, {item: 1.0}) or []) for c in wanted for k in c):
                    discarded[item] += inv[item]
                    inv[item] = 0.0
        if not args.no_bag:
            held_shards = bag.add(inv, "ascendant_shard", held_shards)  # bought space frees room
            bag_at[n] = (bag.used(inv), bag.slots)
        lvl = level_for_xp(xp_total, rules)
        gear = sum(1 for q in purchases if q.category == "equipment" and q.name in owned)
        best: dict[str, float] = {}
        for name in owned:
            if name in gear_stats:
                cat, atk = gear_stats[name]
                best[cat] = max(best.get(cat, 0.0), atk)
        gear_attack_at[n] = sum(best.values())
        attack_now = (pr.base_attack + pr.attack_per_level * (lvl - 1) + gear_attack_at[n]) * tree_mult(n)
        if n == 1:
            start_attack = attack_now
        timeline.append((n, lvl, lvl // rules.skill_point_interval, xp_total, len(owned), gear))

    L.append(f"\n## Campaign timeline ({args.missions} missions)\n")
    gear_total = sum(1 for q in purchases if q.category == "equipment")
    L.append("| Missions | Hero level | Skill pts (levels) | Total XP | Purchases owned | Gear owned |")
    L.append("|---|---|---|---|---|---|")
    marks = sorted({1, 2, 4, 8, 12, 20, 30, 40, 60, 80, 100, args.missions} & set(range(1, args.missions + 1)))
    for n, lvl, pts, xp, owned_n, gear_n in timeline:
        if n in marks:
            L.append(f"| {n} | {lvl} | {pts} | {fmt(xp)} | {owned_n}/{len(purchases)} | {gear_n}/{gear_total} |")

    # Power vs enemy HP: does enemy HP keep pace with the hero?
    brutal_hp = 1.0 + pr.hp_tier_rate * (pr.brutal_tier - 1)
    start_attack = (pr.base_attack + gear_attack_at.get(1, 0.0)) * tree_mult(1)
    L.append("\n## Hero power vs enemy HP\n")
    L.append(f"Hero attack = {pr.base_attack:g} base + {pr.attack_per_level:g}/level + best owned gear per slot "
             f"(physical_attack), x (1 + skill tree: +{tree_attack:.0%} at {TREE_PURCHASES} purchases, 1 per mission; "
             f"permanent stat nodes only, best side per fork). Enemy HP: Brutal x{brutal_hp:g}, each Ascension rank x{pr.asc_hp_growth:g} "
             f"(max {pr.max_ascension}). `Rank to match` = the Ascension rank whose HP has grown as much as "
             "the hero has since mission 1 on Normal, i.e. the rank that should feel like the first mission. "
             "Towers, skills, tree notables and tarot are NOT modelled; they push the real number higher.\n")
    L.append("| Missions | Hero level | Gear attack | Tree | Hero attack | Power vs mission 1 | Rank to match |")
    L.append("|---|---|---|---|---|---|---|")
    for n, lvl, pts, xp, owned_n, gear_n in timeline:
        if n in marks:
            attack = (pr.base_attack + pr.attack_per_level * (lvl - 1) + gear_attack_at[n]) * tree_mult(n)
            ratio = attack / start_attack
            if ratio <= brutal_hp:
                rank_text = "Brutal or lower"
            else:
                rank = math.ceil(math.log(ratio / brutal_hp) / math.log(pr.asc_hp_growth))
                rank_text = f"{rank}" if rank <= pr.max_ascension else f"{rank} (above max {pr.max_ascension})"
            L.append(f"| {n} | {lvl} | {fmt(gear_attack_at[n])} | +{tree_mult(n) - 1:.0%} | {fmt(attack)} | x{ratio:.2f} | {rank_text} |")

    if args.ascend_after:
        L.append("\n## Ascension endgame\n")
        L.append("Best rank = highest Ascension rank cleared on any map. Shards = total earned so far. "
                 "The Ascendant set needs "
                 f"{fmt(sum(p.cost.get('ascendant_shard', 0) for p in purchases))} shards in all.\n")
        L.append("| Missions | Best rank | Shards earned | Ascendant pieces owned |")
        L.append("|---|---|---|---|")
        asc_total = sum(1 for p in purchases if "ascendant_shard" in p.cost)
        asc_marks = sorted(set(marks) | {m for m in range(args.ascend_after, args.missions + 1, 10)} - {0})
        for m in asc_marks:
            if m >= args.ascend_after:
                pieces = sum(1 for p in purchases if "ascendant_shard" in p.cost and bought_at.get(p.name, 10 ** 6) <= m)
                L.append(f"| {m} | {rank_at[m]} | {fmt(shards_at[m])} | {pieces}/{asc_total} |")
        L.append("\nRanks reached per map: " + ", ".join(f"{missions[k].name} {v}" for k, v in best_rank.items()))

    if not args.no_bag:
        L.append("\n## Bag\n")
        L.append("Slots used at the end of each shopping trip, and income lost because the bag was full "
                 "during that mission.\n")
        L.append("| Missions | Slots used | Lost that mission |")
        L.append("|---|---|---|")
        for m in marks:
            L.append(f"| {m} | {bag_at[m][0]}/{bag_at[m][1]} | {fmt(lost_at[m])} |")
        worst = sorted(((v, k) for k, v in lost.items() if v > 0.05), reverse=True)[:8]
        total_lost = sum(lost.values())
        total_earned = sum(v for k, v in earned.items() if k != "ascendant_shard")
        L.append(f"\nLost to a full bag over {args.missions} missions: {fmt(total_lost)} of {fmt(total_earned)} "
                 f"({total_lost / max(total_earned, 1e-9):.0%})"
                 + (": " + ", ".join(f"{k} {fmt(v)}" for v, k in worst) if worst else ""))
        if args.salvage:
            L.append(f"Salvaged (`--salvage`, bag nearly full): {fmt(sum(salvaged.values()))} materials "
                     f"at {salvage_ratio}:1 into {', '.join(sorted(set(salvage_out.values())))}")
        if args.discard:
            L.append(f"Discarded (no remaining purchase uses them; `--discard`): {fmt(sum(discarded.values()))}")
        if held_shards > 0.5:
            L.append(f"Shards still held for lack of room at the end: {fmt(held_shards)}")

    L.append("\n## Missions to reach each level\n")
    L.append("| Level | XP to next | Cumulative XP | Missions (avg yield) |")
    L.append("|---|---|---|---|")
    avg_xp = sum(yields[p]["xp"] for p in plan) / len(plan)
    cum = 0
    for lvl in range(1, rules.level_cap + 1):
        if lvl in (2, 5, 10, 15, 20, 25, 30, 40, 50) or lvl == rules.level_cap:
            L.append(f"| {lvl} | {fmt(xp_required(lvl, rules))} | {fmt(cum)} | {cum / avg_xp:.1f} |")
        cum += xp_required(lvl, rules)

    if use_gold:
        L.append("\n## Sanctuary gold\n")
        L.append("Banked = Sanctuary gold from that mission's held gold. Balance = after that visit's shopping. "
                 "Waiting = purchases whose materials were ready that visit but the gold was short.\n")
        L.append("| Missions | Treasury | Rate | Banked | Balance | Spent so far | Waiting on gold |")
        L.append("|---|---|---|---|---|---|---|")
        for n in marks:
            banked_n, rate_n, bal_n, spent_n, wait_n = gold_at[n]
            owned_t = sum(1 for t in gold_rules.treasury_ids if t in bought_at and bought_at[t] < n)
            L.append(f"| {n} | {owned_t}/{len(gold_rules.treasury_ids)} | {rate_n:.0%} | {fmt(banked_n)} | "
                     f"{fmt(bal_n)} | {fmt(spent_n)} | {wait_n} |")
        treasury_when = ", ".join(f"{t} @ {bought_at.get(t, '-')}" for t in gold_rules.treasury_ids)
        L.append(f"\nTreasury bought: {treasury_when}. "
                 f"Gold banked over {args.missions} missions: {fmt(earned['__sanctuary_gold__'])}; "
                 f"spent {fmt(sgold_spent)}.")
        slowest = sorted(gold_waits.items(), key=lambda kv: -kv[1])[:8]
        if slowest:
            L.append("Longest gold waits (visits with materials ready, gold short): "
                     + ", ".join(f"{k} {v}" for k, v in slowest))
        else:
            L.append("No purchase ever waited on gold.")

    L.append("\n## Sanctuary purchases\n")
    L.append("`Affordable` = the first mission whose cumulative income covers this item alone. "
             "`Bought` = when a greedy cheapest-first shopper actually gets it, respecting prerequisites. "
             "`-` = not within the simulated missions.\n")
    L.append("| Item | Kind | Cost | Needs | Affordable | Bought |")
    L.append("|---|---|---|---|---|---|")
    for p in sorted(purchases, key=lambda p: (first_affordable.get(p.name, 10 ** 6), p.category, p.name)):
        cost = ", ".join(f"{fmt(v)} {k}" for k, v in p.cost.items()) + (f", {p.gold} gold" if p.gold else "")
        needs = " ".join(x for x in (p.prereq, p.also_needs) if x)
        L.append(f"| {p.name} | {p.category} | {cost} | {needs} | {first_affordable.get(p.name, '-')} | "
                 f"{bought_at.get(p.name, '-')} |")
    return "\n".join(L) + "\n"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--missions", type=int, default=40, help="missions to simulate (default 40)")
    ap.add_argument("--plan", default="", help="comma-separated mission ids, cycled (default: all, data order)")
    ap.add_argument("--difficulty", type=int, default=1, choices=(1, 2, 3))
    ap.add_argument("--tier-reward", default="", help="WHAT-IF reward multiplier per tier, e.g. 1,1.3,1.7 "
                    "(default: DifficultyRewards.TIER_MULTIPLIERS)")
    ap.add_argument("--hero-inner", type=float, default=0.35, help="share of kills inside hero attack range")
    ap.add_argument("--hero-outer", type=float, default=0.15, help="share of kills in the half-XP band")
    ap.add_argument("--towers", type=int, default=6, help="towers placed at mission end (surplus)")
    ap.add_argument("--foundation-tier", type=int, default=1)
    ap.add_argument("--archetype", default="physical", help="dominant tower archetype for the surplus bonus")
    ap.add_argument("--menagerie-bonus", type=float, default=1.0)
    ap.add_argument("--win-rate", type=float, default=1.0)
    ap.add_argument("--drop-mult", type=float, default=1.0, help="WHAT-IF multiplier on kill drops (not surplus)")
    ap.add_argument("--xp-growth", type=float, help="WHAT-IF level curve growth (game: 1.15)")
    ap.add_argument("--level-cap", type=int, help="WHAT-IF level cap (game: 50)")
    ap.add_argument("--mission-xp", type=int, help="WHAT-IF mission completion XP")
    ap.add_argument("--wave-xp", type=int, help="WHAT-IF wave completion XP")
    ap.add_argument("--ascend-after", type=int, default=0,
                    help="endgame: from mission N+1 climb Ascension one rank per map visit (default off)")
    ap.add_argument("--no-tree", action="store_true", help="WHAT-IF ignore the Hero Skill Tree's attack bonus")
    ap.add_argument("--no-sanctuary-gold", action="store_true",
                    help="WHAT-IF ignore Sanctuary gold (materials-only shopping, as before 2026-11-05)")
    ap.add_argument("--craft-gold", type=int, help="WHAT-IF craft price per quality tier (game: SanctuaryGold.CRAFT_COST_BASE)")
    ap.add_argument("--gold-rate", type=float, help="WHAT-IF base conversion rate (game: SanctuaryGold.BASE_CONVERSION_RATE)")
    ap.add_argument("--early-call", type=float, default=0.0,
                    help="share of each intermission skipped with an early call (0-1, default 0)")
    ap.add_argument("--tower-gold", type=float,
                    help="mission gold spent on towers per mission (default: --towers x avg blueprint placement_cost)")
    ap.add_argument("--no-bag", action="store_true", help="WHAT-IF unlimited bag")
    ap.add_argument("--salvage", action="store_true",
                    help="player salvages Common/Uncommon stacks no remaining recipe names when the bag is nearly full")
    ap.add_argument("--discard", action="store_true",
                    help="WHAT-IF the player can discard stacks no remaining purchase uses (the game has no discard)")
    ap.add_argument("--out", help="also write the report to this file")
    args = ap.parse_args()
    report = run(args)
    sys.stdout.reconfigure(encoding="utf-8")
    print(report)
    if args.out:
        out = ROOT / args.out
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(report, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()

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

The model is expected value (no RNG): a 45% drop of 2 hide counts as 0.9
hide. That's right for averages across many missions; single runs vary.

Assumptions the game data can't supply are flags (see --help) and are
printed at the top of every report. What-if flags (--xp-growth,
--level-cap, --tier-reward ...) override the real values without
touching the game.

Usage (repo root):
  python tools/balance/progression_sim.py
  python tools/balance/progression_sim.py --missions 60 --xp-growth 1.08 --level-cap 30
  python tools/balance/progression_sim.py --difficulty 3 --tier-reward 1,1.3,1.7
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
    m = re.search(rf'^const {name}\s*(?::[^=]+)?=\s*([^\n#]+)', src, re.M)
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
    if m:
        r.xp_base, r.xp_growth = float(m.group(1)), float(m.group(2))
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


def load_purchases() -> list[Purchase]:
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
        out.append(Purchase(s_val(r.get("output_item_id")), "equipment", dict_val(r.get("inputs")),
                            s_val(r.get("tech_prerequisite"))))
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


def mission_yield(m: Mission, a: Assumptions, rules: Rules, monsters: dict, tables: dict) -> dict:
    """Expected XP and materials for one attempt at mission `m`."""
    mult = a.tier_reward[a.difficulty - 1]
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
                mats[mat] += table["rate"] * q
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

    def __init__(self, rarity: dict[str, str], item_type: dict[str, str]):
        self.rarity = rarity
        self.item_type = item_type
        self.types = set(item_type.values())

    def members(self, key: str, inv: dict[str, float]) -> list[str] | None:
        if key in RARITIES:
            return [i for i in inv if self.rarity.get(i) == key]
        if key in self.types:
            return [i for i in inv if self.item_type.get(i) == key]
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
    pools = Pools(rarity, item_type)
    purchases = load_purchases()
    tier_reward = [float(x) for x in args.tier_reward.split(",")]
    a = Assumptions(args.hero_inner, args.hero_outer, args.towers, args.foundation_tier, args.archetype,
                    args.difficulty, tier_reward, args.menagerie_bonus, args.win_rate)
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
             f"({'game has none' if tier_reward == [1.0, 1.0, 1.0] else 'WHAT-IF'})")
    L.append(f"- Menagerie quality bonus x{a.menagerie_bonus}, win rate {a.win_rate:.0%}, no tarot")
    L.append(f"- Plan (cycled): {' -> '.join(plan)}\n")

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
    for n in range(1, args.missions + 1):
        y = yields[plan[(n - 1) % len(plan)]]
        xp_total += y["xp"]
        for k, v in y["mats"].items():
            inv[k] += v
            earned[k] += v
        for p in purchases:
            if p.name not in first_affordable and pools.can_afford(p.cost, earned):
                first_affordable[p.name] = n
        # Cheapest affordable first, prerequisites respected.
        for p in sorted(purchases, key=lambda p: sum(p.cost.values())):
            if p.name in owned or (p.prereq and p.prereq not in owned and any(q.name == p.prereq for q in purchases)):
                continue
            if pools.can_afford(p.cost, inv):
                pools.spend(p.cost, inv)
                owned.add(p.name)
                bought_at[p.name] = n
        lvl = level_for_xp(xp_total, rules)
        timeline.append((n, lvl, lvl // rules.skill_point_interval, xp_total, len(owned)))

    L.append(f"\n## Campaign timeline ({args.missions} missions)\n")
    L.append("| Missions | Hero level | Skill pts (levels) | Total XP | Purchases owned |")
    L.append("|---|---|---|---|---|")
    marks = sorted({1, 2, 4, 8, 12, 20, 30, 40, 60, 80, 100, args.missions} & set(range(1, args.missions + 1)))
    for n, lvl, pts, xp, owned_n in timeline:
        if n in marks:
            L.append(f"| {n} | {lvl} | {pts} | {fmt(xp)} | {owned_n}/{len(purchases)} |")

    L.append("\n## Missions to reach each level\n")
    L.append("| Level | XP to next | Cumulative XP | Missions (avg yield) |")
    L.append("|---|---|---|---|")
    avg_xp = sum(yields[p]["xp"] for p in plan) / len(plan)
    cum = 0
    for lvl in range(1, rules.level_cap + 1):
        if lvl in (2, 5, 10, 15, 20, 25, 30, 40, 50) or lvl == rules.level_cap:
            L.append(f"| {lvl} | {fmt(xp_required(lvl, rules))} | {fmt(cum)} | {cum / avg_xp:.1f} |")
        cum += xp_required(lvl, rules)

    L.append("\n## Sanctuary purchases\n")
    L.append("`Affordable` = the first mission whose cumulative income covers this item alone. "
             "`Bought` = when a greedy cheapest-first shopper actually gets it, respecting prerequisites. "
             "`-` = not within the simulated missions.\n")
    L.append("| Item | Kind | Cost | Needs | Affordable | Bought |")
    L.append("|---|---|---|---|---|---|")
    for p in sorted(purchases, key=lambda p: (first_affordable.get(p.name, 10 ** 6), p.category, p.name)):
        cost = ", ".join(f"{fmt(v)} {k}" for k, v in p.cost.items())
        needs = " ".join(x for x in (p.prereq, p.also_needs) if x)
        L.append(f"| {p.name} | {p.category} | {cost} | {needs} | {first_affordable.get(p.name, '-')} | "
                 f"{bought_at.get(p.name, '-')} |")
    gold_items = [p for p in purchases if p.gold]
    if gold_items:
        L.append(f"\nNote: {len(gold_items)} purchases list a gold cost (total {sum(p.gold for p in gold_items):,}), "
                 "but gold resets every mission (MissionEconomy) and there is no persistent Sanctuary gold, "
                 "so gold is ignored here.")
    return "\n".join(L) + "\n"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--missions", type=int, default=40, help="missions to simulate (default 40)")
    ap.add_argument("--plan", default="", help="comma-separated mission ids, cycled (default: all, data order)")
    ap.add_argument("--difficulty", type=int, default=1, choices=(1, 2, 3))
    ap.add_argument("--tier-reward", default="1,1,1", help="WHAT-IF reward multiplier per tier, e.g. 1,1.3,1.7")
    ap.add_argument("--hero-inner", type=float, default=0.35, help="share of kills inside hero attack range")
    ap.add_argument("--hero-outer", type=float, default=0.15, help="share of kills in the half-XP band")
    ap.add_argument("--towers", type=int, default=6, help="towers placed at mission end (surplus)")
    ap.add_argument("--foundation-tier", type=int, default=1)
    ap.add_argument("--archetype", default="physical", help="dominant tower archetype for the surplus bonus")
    ap.add_argument("--menagerie-bonus", type=float, default=1.0)
    ap.add_argument("--win-rate", type=float, default=1.0)
    ap.add_argument("--xp-growth", type=float, help="WHAT-IF level curve growth (game: 1.15)")
    ap.add_argument("--level-cap", type=int, help="WHAT-IF level cap (game: 50)")
    ap.add_argument("--mission-xp", type=int, help="WHAT-IF mission completion XP")
    ap.add_argument("--wave-xp", type=int, help="WHAT-IF wave completion XP")
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

# Tower Content Catalogue

> **Type**: Content Catalogue (not a System GDD — see `tower.md` OQ-4: "The full catalogue is a separate design deliverable"). Documents the tower variants that already exist as real, shipped `.tres` data under `assets/data/towers/blueprints/`; does not duplicate mechanics already defined in `tower.md`.
> **Governing GDD**: `tower.md` (Rule 1 — 4-slot component structure; Rule 5a — Support Weapon-slot AURA semantics; Formula 4 — cost/tier scaling)
> **Status**: Draft — catalogues real shipped content and identifies real coverage gaps against `tower.md` OQ-4/OQ-6. Does not invent new tower variants; where a gap exists, it is named, not filled.
> **Author**: Game Designer (this session)
> **Last Updated**: 2026-08-27

---

## Scope

All data below is read directly from the 13 `.tres` files under `assets/data/towers/blueprints/` (source of truth — this catalogue is documentation of what already ships, cross-checked against `tower.md`'s own rules, not new content). `tower.md` OQ-4 ("which specific tower variants exist... is a separate design deliverable") is **partially resolved** by this document — the catalogue now exists — but full grid coverage (§Coverage Gaps below) is a genuine content gap, not a documentation gap, and is not closed here.

## The 13 Towers

| `tower_id` | Display Name | Archetype | Tier | Cost | HP | Weapon DMG | Atk Speed | Range (cells) | Projectile | AoE (cells) | Targeting | Status Effect | Pre-Placement Perk |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `archer` | Archer Tower | physical | 1 | 10 | 100 | 20 | 1.0 | 3 | BALLISTIC | 0 | CLOSEST_TO_GOAL | — | RANGE_BOOST |
| `firebolt_turret` | Firebolt Turret | elemental | 1 | 10 | 90 | 14 | 0.7 | 4 | BALLISTIC | 2 | LOWEST_HP | burn (0.10) | — |
| `frostbolt_turret` | Frostbolt Turret | elemental | 1 | 10 | 90 | 16 | 0.8 | 4 | BALLISTIC | 2 | LOWEST_HP | slow (0.15) | — |
| `venomdart_turret` | Venom Dart Turret | elemental | 1 | 10 | 90 | 12 | 0.9 | 4 | HOMING | 0 | LOWEST_HP | poison (0.08) | — |
| `longshot_sniper` | Longshot Sniper | ranged | 1 | 12 | 85 | 32 | 0.6 | 6 | HOMING | 0 | HIGHEST_HP | — | DAMAGE_BOOST |
| `rally_banner` | Rally Banner | support | 1 | 12 | 100 | 8 | 1.0 | 1 | AURA (damage_buff +0.15) | 0 | CLOSEST_TO_GOAL | — | — |
| `bulwark` | Bulwark | physical | 2 | 21 | 160 | 22 | 0.8 | 4 | BALLISTIC | 0 | SPAWN_ORDER | — | — |
| `storm_turret` | Storm Turret | elemental | 2 | 20 | 100 | 15 | 0.75 | 4 | BALLISTIC | 2 | LOWEST_HP | — | SPEED_BOOST |
| `barrier_ward` | Barrier Ward | support | 2 | 24 | 120 | 8 | 0.8 | 1 | AURA (damage_buff +0.20) | 0 | CLOSEST_TO_GOAL | — | AURA_EXTEND |
| `volley_crossbow` | Volley Crossbow | ranged | 2 | 23 | 90 | 18 | 1.2 | 5 | HOMING | 0 | SCATTER | — | — |
| `arcane_lance` | Arcane Lance | elemental | 3 | 24 | 110 | 30 | 1.0 | 5 | BALLISTIC | 1 | LOWEST_HP | — | — |
| `siege_cannon` | Siege Cannon | physical | 4 | 28 | 140 | 100 | 0.5 | 5 | HOMING | 0 | LOWEST_HP | — | — |
| `firestorm_spire` | Firestorm Spire | elemental | 4 | 30 | 130 | 45 | 0.6 | 4 | BALLISTIC | 3 | CLOSEST_TO_GOAL | burn (0.15) | — |

*(All 13 have `footprint = Vector2i(1, 1)` — see Coverage Gaps §3.)*

## Coverage Grid (Archetype × Tier)

| Archetype | T1 | T2 | T3 | T4 | Total |
|---|---|---|---|---|---|
| physical | 1 (archer) | 1 (bulwark) | 0 | 1 (siege_cannon) | 3 |
| ranged | 1 (longshot_sniper) | 1 (volley_crossbow) | 0 | 0 | 2 |
| elemental | 3 (firebolt/frostbolt/venomdart) | 1 (storm_turret) | 1 (arcane_lance) | 1 (firestorm_spire) | 6 |
| support | 1 (rally_banner) | 1 (barrier_ward) | 0 | 0 | 2 |
| **Total** | **6** | **4** | **1** | **2** | **13** |

## Coverage Gaps (real, not filled by this pass)

1. **No T3 physical, ranged, or support tower exists** — every archetype except elemental skips Tier 3 entirely. `tower.md` Formula 4's T3 cost/DPS math is fully specified (max cost 120 MVP / 240 post-MVP), so this is authorable against the existing formula whenever a Game Designer picks up the work — flagged, not designed here (inventing a specific T3 physical/ranged/support tower's exact damage/range/cost numbers without a balance pass would be guessing, not designing, matching this project's own established standard for OQ-9/base-stat deferrals).
2. **No T4 ranged or support tower exists** — same shape of gap; T4's `base_cost ≤ 30` cap (Revision 20/OQ-11) is already defined, only the specific archetype content is missing.
3. **`tower.md` OQ-6 ("2×2 footprint towers — which archetypes use them?") is confirmed still open, now with hard evidence**: all 13 shipped blueprints use `footprint = Vector2i(1, 1)`. Zero precedent exists for a 2×2 tower anywhere in the current catalogue. This remains a Level Designer / Game Designer decision (per `tower.md`'s own OQ-6 ownership), not something this catalogue can resolve — a 2×2 footprint has real grid-occupancy and placement-cost implications (`tower.md` doesn't currently define a footprint-based cost multiplier) that need a deliberate design pass, not a retrofit onto an existing 1×1 blueprint.
4. **Support archetype's `aura_effect_type` vocabulary has exactly one value in use** (`"damage_buff"`, both existing support towers). `tower.md` Rule 5a doesn't enumerate a closed set of valid `aura_effect_type` strings — worth a follow-up note to that GDD if a second aura type (e.g. a slow/utility aura) is ever authored, so `FocusComponent`/`WeaponComponent` validation has something to check against; not a blocker today since only one value has ever been needed.

## Pre-Placement Perk Coverage

`tower.md`'s Pre-Placement Perk mechanism (fixed via `TD-tower-004`) requires `perk_power` validated against a per-type range. Only 4 of 13 blueprints currently use it (`archer`: RANGE_BOOST, `longshot_sniper`: DAMAGE_BOOST, `storm_turret`: SPEED_BOOST, `barrier_ward`: AURA_EXTEND) — one worked example per perk type, matching `TD-tower-004`'s own resolution note ("Authored real perk values onto one blueprint per eligible archetype"). The remaining 9 blueprints have `pre_placement_perk = ""` (perk mechanism opted out, not broken) — this is intentional per that fix's scope, not a gap this catalogue needs to close.

## Cross-Reference

- `tower.md` OQ-4: update to point at this document as the now-existing catalogue, with the coverage gaps above named explicitly (not "still fully unspecified").
- `tower.md` OQ-6: remains open; this document adds the concrete evidence (0/13 towers use 2×2) that OQ-6's resolution will need to account for.

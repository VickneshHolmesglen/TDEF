# Tower Content Catalogue

> **Type**: Content Catalogue (not a System GDD — see `tower.md` OQ-4: "The full catalogue is a separate design deliverable"). Documents the tower variants that already exist as real, shipped `.tres` data under `assets/data/towers/blueprints/`; does not duplicate mechanics already defined in `tower.md`.
> **Governing GDD**: `tower.md` (Rule 1 — 4-slot component structure; Rule 5a — Support Weapon-slot AURA semantics; Formula 4 — cost/tier scaling)
> **Status**: Draft — catalogues real shipped content. First pass (2026-08-27) identified the T3/T4 archetype coverage gaps against `tower.md` OQ-4; a same-day follow-up authored the 5 missing towers those gaps named. OQ-6 (2×2 footprint) remains genuinely open — not addressed by the follow-up.
> **Author**: Game Designer (this session)
> **Last Updated**: 2026-08-27 (follow-up pass — 5 new towers authored)

---

## Scope

All data below is read directly from the 18 `.tres` files under `assets/data/towers/blueprints/` (source of truth — this catalogue is documentation of what ships, cross-checked against `tower.md`'s own rules). `tower.md` OQ-4 ("which specific tower variants exist... is a separate design deliverable") is now **substantially resolved**: the original 13-tower pass found every archetype had at least one T1/T2 tower but 3 of 4 archetypes skipped T3 and 3 of 4 skipped T4; this follow-up pass closed every one of those gaps (5 new towers: `warbreaker` [physical T3], `piercing_ballista` [ranged T3], `sanctified_standard` [support T3], `railgun_emplacement` [ranged T4], `grand_rally_spire` [support T4]) — every archetype now has exactly one tower at every tier, T1 through T4. Load-verified via a headless Godot script: all 18 blueprints (13 original + 5 new) load and pass `TowerBlueprintData.validate()` with zero errors, and the 5 new towers are automatically reachable through the Planning Cluster UI (`planning_cluster.gd` pulls dynamically from `GameDataRegistry.get_all_tower_blueprints()` — no UI code change was needed).

## The 18 Towers

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
| `warbreaker` | Warbreaker | physical | 3 | 25 | 150 | 28 | 0.9 | 4 | BALLISTIC | 0 | HIGHEST_HP | — | — |
| `piercing_ballista` | Piercing Ballista | ranged | 3 | 26 | 90 | 26 | 1.0 | 6 | HOMING | 0 | HIGHEST_HP | — | — |
| `sanctified_standard` | Sanctified Standard | support | 3 | 28 | 140 | 9 | 0.9 | 1 | AURA (damage_buff +0.25) | 0 | CLOSEST_TO_GOAL | — | AURA_EXTEND |
| `siege_cannon` | Siege Cannon | physical | 4 | 28 | 140 | 100 | 0.5 | 5 | HOMING | 0 | LOWEST_HP | — | — |
| `firestorm_spire` | Firestorm Spire | elemental | 4 | 30 | 130 | 45 | 0.6 | 4 | BALLISTIC | 3 | CLOSEST_TO_GOAL | burn (0.15) | — |
| `railgun_emplacement` | Railgun Emplacement | ranged | 4 | 30 | 90 | 95 | 0.5 | 7 | HOMING | 0 | HIGHEST_HP | — | — |
| `grand_rally_spire` | Grand Rally Spire | support | 4 | 30 | 150 | 10 | 1.0 | 1 | AURA (damage_buff +0.30) | 0 | CLOSEST_TO_GOAL | — | AURA_EXTEND |

*(All 18 have `footprint = Vector2i(1, 1)` — see Coverage Gaps §3, still open.)*

## Coverage Grid (Archetype × Tier)

| Archetype | T1 | T2 | T3 | T4 | Total |
|---|---|---|---|---|---|
| physical | 1 (archer) | 1 (bulwark) | 1 (warbreaker) | 1 (siege_cannon) | 4 |
| ranged | 1 (longshot_sniper) | 1 (volley_crossbow) | 1 (piercing_ballista) | 1 (railgun_emplacement) | 4 |
| elemental | 3 (firebolt/frostbolt/venomdart) | 1 (storm_turret) | 1 (arcane_lance) | 1 (firestorm_spire) | 6 |
| support | 1 (rally_banner) | 1 (barrier_ward) | 1 (sanctified_standard) | 1 (grand_rally_spire) | 4 |
| **Total** | **6** | **4** | **4** | **4** | **18** |

**Full T1–T4 coverage now exists for every archetype** — the two real gaps this catalogue's first pass named (no T3 physical/ranged/support, no T4 ranged/support) were closed same-day (2026-08-27). Design notes on the 5 additions, to explain the choices rather than just the numbers:

- **`warbreaker`** (physical T3): fills the "efficient mid-game" niche Formula 1 assigns to T3 (best DPS/cost ratio) — `HIGHEST_HP` targeting gives it a distinct tank-breaker role vs. `bulwark`'s `SPAWN_ORDER` and `archer`'s `CLOSEST_TO_GOAL`.
- **`piercing_ballista`** (ranged T3): keeps the archetype's sniper identity (`HOMING`, long range) but with a moderate cone (45°, +1 range bonus) rather than `longshot_sniper`'s narrow 30° — a mid-tier step, not a re-skin.
- **`sanctified_standard`** (support T3): escalates the aura linearly from `rally_banner`'s +0.15 → `barrier_ward`'s +0.20 → +0.25 here, with a wider `aura_radius_cells = 5`.
- **`railgun_emplacement`** (ranged T4): the archetype's own specialist-ceiling tower, mirroring `siege_cannon`'s role for physical — near-max `weapon_damage` (95/120), min `attack_speed` (0.5), and `attack_range_cells = 7` with a narrow 30° cone (effective range exactly hits Formula 2's 9-cell cap, deliberately avoiding the documented "range=8 + narrow cone wastes a stat point" trap).
- **`grand_rally_spire`** (support T4): completes the aura escalation to +0.30 at `aura_radius_cells = 6` (the schema's own documented radius ceiling) and takes `AURA_EXTEND` at its max `perk_power = 0.25`.
- All 5 costed within the precedent bands observed in the original 13 (T3 ≈ 24–28, T4 = 30, the T4 `base_cost ≤ 30` figure from `tower.md` Revision 20/OQ-11 — note: not currently enforced in code, `tower_blueprint_data.gd` has no `base_cost` field or T4 cap check at all, only the doc-level convention every existing T4 blueprint already follows). None use a pre-existing perk type beyond `AURA_EXTEND` on the two support towers (matching the established "≤1 perk type demo per family" pattern) or introduce a new `aura_effect_type`, `targeting_mode`, `projectile_type`, or footprint value — every field uses vocabulary the schema and its `validate()` already recognize.
- Verified via a headless load-and-validate pass (not just written and assumed correct): all 18 blueprints load as `TowerBlueprintData` and pass `validate()` with zero errors.

## Coverage Gaps (still real, not filled by this pass)

1. **`tower.md` OQ-6 ("2×2 footprint towers — which archetypes use them?") remains open, now with even stronger evidence**: all 18 shipped blueprints (13 original + the 5 just added) use `footprint = Vector2i(1, 1)`. Zero precedent exists for a 2×2 tower anywhere in the catalogue. This remains a Level Designer / Game Designer decision (per `tower.md`'s own OQ-6 ownership) — a 2×2 footprint has real grid-occupancy and placement-cost implications (`tower.md` doesn't currently define a footprint-based cost multiplier) that need a deliberate design pass, not a retrofit onto an existing 1×1 blueprint. Deliberately not addressed by this pass — inventing a 2×2 tower's cost/balance implications without that design pass would be guessing, not designing.
2. **Support archetype's `aura_effect_type` vocabulary has exactly one value in use** (`"damage_buff"`, all 4 support towers now, including the 2 new ones — kept consistent deliberately rather than inventing a second aura type as part of this content-filling pass). `tower.md` Rule 5a doesn't enumerate a closed set of valid `aura_effect_type` strings — worth a follow-up note to that GDD if a second aura type (e.g. a slow/utility aura) is ever authored.
3. **`tower_blueprint_data.gd` has no `base_cost` field or T4-cost-cap validation at all** — logged as `TD-tower-006` (`docs/tech-debt-register.md`). `tower.md` Formula 4 describes `placement_cost = round(base_cost × archetype_cost_factor × tier_cost_factor)` with a T4 `base_cost ≤ 30` load-time-error rule, but the shipped schema stores `placement_cost` as a single directly-authored int with no such field or check. Every existing and new T4 blueprint happens to comply (28–30), by author discipline, not code enforcement.

## Pre-Placement Perk Coverage

`tower.md`'s Pre-Placement Perk mechanism (fixed via `TD-tower-004`) requires `perk_power` validated against a per-type range. 6 of 18 blueprints now use it: `archer` (RANGE_BOOST), `longshot_sniper` (DAMAGE_BOOST), `storm_turret` (SPEED_BOOST), `barrier_ward` (AURA_EXTEND) from the original 13, plus `sanctified_standard` and `grand_rally_spire` (both AURA_EXTEND, from this pass — a deliberate reuse of an existing perk type on the newly-filled support tier, not a new perk type). The remaining 12 blueprints have `pre_placement_perk = ""` (perk mechanism opted out, not broken) — intentional, matching `TD-tower-004`'s original scope.

## Cross-Reference

- `tower.md` OQ-4: updated (2026-08-27) to point at this document; the T3/T4 coverage gaps it originally named are now closed.
- `tower.md` OQ-6: remains open; this document's evidence base grew from 0/13 to 0/18 towers using a 2×2 footprint.

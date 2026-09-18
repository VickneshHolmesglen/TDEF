# Hero Leveling System

**Date**: 2026-09-19
**Status**: Approved by user, pending implementation plan
**Scope**: New Hero Level/XP system. Closes the `HERO_LEVEL_PLACEHOLDER = 1` gap left open by the Hero Combat & Stats Redesign (`docs/superpowers/specs/2026-09-18-hero-combat-stats-redesign-design.md`). Does not design the real Hero "class catalogue" (perks/full class list) — that remains its own separate deliverable per `design/gdd/hero.md` Rule 23; this spec only adds a provisional, clearly-flagged placeholder stat mapping for the 4 existing example archetypes.

## 1. Overview

Hero Level is a new, persistent (cross-mission) progression axis, earned via monster kills near the Hero, wave completions, and mission completions. Leveling grants flat stat growth every level, and — every 5th level — a Skill Tree point (credited to whichever archetype pool matches the Hero's current Primary class) plus a small class-specific stat bonus. This closes the real, previously-hardcoded gap in the Hero Combat & Stats Redesign's monster-Armor mitigation formula, which has been waiting on a real Hero Level value since it shipped.

## 2. Player Fantasy

The Hero visibly grows stronger across a whole playthrough, not just within one mission — every kill near the action, every wave survived, and every mission finished all measurably move the Hero toward the next level, and leveling up is a moment (HUD/VFX hook via `hero_leveled_up`) distinct from and additive to gear/class progression. Committing to a Primary class pays off doubly: it already gates Tower Affinity's counting rule, and now it also determines which Skill Tree pool and which stat benefit from every 5th level.

## 3. Detailed Rules

### 3.1 Persistence

- `current_level: int` (starts at 1) and `current_xp: int` (starts at 0, XP accumulated toward the next level) are new fields on `Hero`, persisted via the same `SavePersistence` mechanism Hero's existing fields already use (`get_save_data()`/`restore_save_data()`/`reset_to_defaults()`).
- Resets to `current_level = 1`, `current_xp = 0` only on a full new-game/new-adventure reset — the same "new adventure" trigger that already resets the Skill Tree's pools and Tower Mastery's `points_granted_count` (`hero-skill-build.md` Group 4 Rule 14's "share the same 'new game' trigger by design" precedent).
- Surviving a DEFEAT (mission failure) does **not** reset level/XP — consistent with `game-concept.md`'s "Defeated missions do not strip base progress" rule.

### 3.2 XP sources

| Source | Trigger | Amount |
|---|---|---|
| Monster kill, inner band | `monster_died`/`monsters_died_batch`, death position within `get_effective_stat(&"attack_range")` of Hero | STANDARD 5, ELITE 15, BOSS 100 |
| Monster kill, outer band | Death position within `2 × attack_range` but outside the inner band | Same tier amounts × 0.5 (STANDARD 2.5→floor 2, ELITE 7.5→floor 7, BOSS 50) |
| Monster kill, outside both bands | — | 0 XP |
| Wave completion | `wave_completed` | Flat 25 XP |
| Mission completion | `mission_phase_changed(new_phase == "MISSION_COMPLETE")` | Flat 150 XP |

No separate "did the Hero land the kill" check exists — the inner band's radius equals Hero's own Attack Range, so a kill the Hero's own auto-attack/skill actually lands is definitionally within the inner band. This unifies "direct kill" and "proximity assist" into one distance check, matching the player's own stated request that both grant equal XP.

### 3.3 Level curve

```
xp_required(level) = floor(100 × 1.15^(level - 1))
```

Level cap: 50. `xp_required(50)` is the last meaningful threshold — no XP is gained or tracked past level 50 (excess XP at the cap is simply discarded, not banked for a future cap raise).

**Correction (2026-09-19, found while writing the implementation plan)**: the table below was originally hand-approximated and got level 2 wrong (had it at 100, an arithmetic slip — `floor(100 × 1.15^1)` is not 100). Values below are computed with double-precision `pow()`/`floor()` (Node.js, matching the IEEE 754 double-precision semantics GDScript's own `pow()`/`floor()` use) rather than by hand, since this formula is exactly the kind of floating-point-boundary calculation where hand arithmetic and a real runtime's `pow()` can disagree by 1 at the floor boundary (e.g. `1.15^1` may compute as `1.1499999999999999` rather than exactly `1.15`). The implementation's own test assertions (Task 1 of the plan) use these same computed values, not hand-derived ones.

| Level | XP required for this level | Cumulative XP from 1 |
|---|---|---|
| 2 | 114 | 114 |
| 3 | 132 | 246 |
| 10 | 351 | 1,926 |

Levels 25/50's cumulative totals are large enough that minor floor-boundary drift doesn't matter for balance purposes — omitted here rather than presenting more hand-approximated figures; the implementation computes them from the formula, never a hardcoded table, per this section's own opening sentence.

(Exact cumulative values are illustrative — the implementation computes them from the formula, never a hardcoded table.)

### 3.4 Level-up rewards

Every level (2 through 50):
- **+10 Max HP, +2 Physical Attack, +2 Magic Attack**, added directly into `Hero._base_stats` (the same dictionary Formula 1 already reads — no new stat-resolution path).

Every 5th level (5, 10, 15, ..., 50 — 10 grants total across a full climb to 50), **in addition to** the flat growth above:
- **1 Skill Tree point**, credited to the archetype pool matching Hero's current `_primary_class` at the moment of level-up, via the existing `skill_tree_point_earned(archetype: String, source_tower_id: int)` EventBus signal (`hero-skill-tree.md` Formula 1). **Correction (2026-09-19, found while writing the implementation plan)**: `source_tower_id` is a real `int` parameter (identifying which tower's mastery crossing earned the point), not a string label as originally drafted here. `HeroSkillTree._on_skill_tree_point_earned()` only forwards this value through to `skill_tree_overflow_point_earned` for traceability when the archetype's pool is already terminal (`hero-skill-tree.md` Rule 18) — it is never used for gating/branching logic. A level-derived point emits with a reserved sentinel, `source_tower_id = -1` (never a real tower id, since those are always >= 0), so a level-derived point is distinguishable from a tower-derived one in that same traceability path without any schema change to the signal or its subscriber.
- **+1 (or +0.5%, see table) to a class-specific placeholder stat**, per this provisional mapping — **explicitly a placeholder**, superseded whenever the real class catalogue (`hero.md` Rule 23) ships.

**Correction (2026-09-19, found while writing the implementation plan)**: `Hero._primary_class` does NOT hold the display-name class values from `hero.md`'s Rule 22 table ("Warrior"/"Archer"/"Mage / Elemental"/"Support / Engineer") — no code anywhere maps those display names to anything. `_primary_class` is set directly from a placed tower's own `archetype` field (`hero.gd:_update_class_proximity()`: `_primary_class = arch` where `arch` comes straight off `TowerPlacedEvent.archetype`), and the real, currently-shipped archetype values (grepped from every `assets/data/towers/blueprints/*.tres`) are the lowercase strings `"physical"`, `"ranged"`, `"elemental"`, `"support"` — there is no separate "class name" layer in code today, despite Rule 22's table implying one. The mapping below is keyed by these real runtime strings instead of the aspirational display names, so it actually matches what `_primary_class` can equal in the shipped game:

| `_primary_class` value | Display equivalent (hero.md Rule 22) | Bonus stat | Amount per qualifying level |
|---|---|---|---|
| `"physical"` | Warrior | Physical Attack (flat) | +1 |
| `"ranged"` | Archer | Crit Chance (raw, pre-curve) | +0.005 (0.5%) |
| `"elemental"` | Mage / Elemental | Magic Attack (flat) | +1 |
| `"support"` | Support / Engineer | CDR (raw, pre-curve) | +0.01 (1%) |

This same real string is passed as-is to `skill_tree_point_earned(archetype: String, ...)`'s `archetype` parameter above — `hero-skill-tree.md`'s own archetype pools are keyed by this identical vocabulary (confirmed: Tower Mastery, which is `skill_tree_point_earned`'s other real emitter, is itself archetype-keyed off the same tower-blueprint `archetype` field), so no translation layer is needed there either.

If no Primary class is designated at the moment a qualifying (every-5th) level-up occurs, **both** the Skill Tree point and the class-bonus stat are skipped for that level-up — not banked, not retroactively granted later. The flat universal stat growth (Section 3.4's first bullet) is never skipped; it applies unconditionally every level regardless of class designation.

### 3.5 Integration with the Hero Combat & Stats Redesign's Armor formula

`damage_status.gd`'s `HERO_LEVEL_PLACEHOLDER = 1` constant is replaced: Hero resolves its own real `current_level` at the same emission sites that already resolve `target_armor`/`target_evasion` (`_on_attack_timer_timeout()`/`_resolve_skill_hit()`), and both `HeroAutoAttackEvent`/`HeroSkillAttackEvent` gain a `hero_level: int` field carrying it through to `_resolve_target_mitigation()`'s existing formula (`Armor / (Armor + 50 × hero_level)`) — a straightforward plumbing swap, no formula change.

## 4. Formulas

### Formula L1 — XP required per level
```
xp_required(level) = floor(100 × 1.15^(level - 1))
```
| Variable | Range | Description |
|---|---|---|
| `level` | 2–50 | The level being leveled up TO |
| Result | int ≥ 100 | XP needed, accumulated from 0, to complete this level |

### Formula L2 — Kill XP band resolution
```
distance = hero.global_position.distance_to(death_position)
if distance <= attack_range:      kill_xp = tier_base_xp[tier]
elif distance <= 2 * attack_range: kill_xp = floor(tier_base_xp[tier] * 0.5)
else:                              kill_xp = 0
```
Where `tier_base_xp = {STANDARD: 5, ELITE: 15, BOSS: 100}`, `attack_range = hero.get_effective_stat(&"attack_range")`.

### Formula L3 — Level-up loop (per XP grant)
```
current_xp += granted_xp
while current_level < 50 and current_xp >= xp_required(current_level + 1):
    current_xp -= xp_required(current_level + 1)
    current_level += 1
    apply_flat_growth()
    if current_level % 5 == 0:
        apply_skill_point_and_class_bonus()
    emit hero_leveled_up(current_level)
if current_level == 50:
    current_xp = 0  # excess discarded at cap, per 3.3
```
A single large XP grant (e.g. a BOSS kill at low level) can cross multiple level thresholds in one resolution — the `while` loop, not a single `if`, ensures every crossed level's rewards apply, matching this project's own established "no shared/accumulated rounding state, every threshold crossing gets its own grant" convention (see `hero-skill-tree.md` Formula 1's identical multi-crossing handling).

## 5. Edge Cases

- **Multiple monsters die in the same frame at different distances from Hero** (e.g. `monsters_died_batch`): each death is resolved independently via Formula L2 — no shared/batched distance check, matching `ResourceEconomy`'s own established "resolve each entry independently" precedent for batched death events.
- **Hero already at level 50**: no further `current_level` increments; incoming XP is discarded (Formula L3's terminal branch). `hero_leveled_up` never fires again once at the cap.
- **A qualifying (every-5th) level-up occurs with no Primary class designated**: flat growth still applies; the Skill Tree point and class bonus are silently skipped for that one level-up (3.4). This is not an error state — a player who never designates a Primary class simply never receives these two rewards, ever, at any level.
- **Hero's Primary class changes between two qualifying level-ups**: each qualifying level-up uses whatever Primary class is active AT THE MOMENT it resolves — no retroactive reassignment of already-granted points/bonuses if the player later changes their Primary designation (Primary designations only change at Sanctuary between missions per `hero.md` Rule 18, so this can only ever affect level-ups occurring in different missions, never mid-mission).
- **A mission ends in DEFEAT partway through**: any XP/levels already gained from kills/waves before the DEFEAT are kept (3.1) — DEFEAT only withholds the 150 XP mission-completion bonus, since that trigger never fires.
- **BOSS kill's outer-band XP (50) vs. STANDARD's inner-band XP (5)**: intentional — a distant assist on a BOSS is still worth 10x more than a close STANDARD kill, matching each tier's already-established relative value elsewhere (HP, gold, drop rarity all scale similarly by tier).

## 6. Dependencies

- **Hero System** (`hero.gd`): owns `current_level`/`current_xp`, the XP-grant/level-up resolution loop, and the two new emission-site reads (real `hero_level` replacing the placeholder).
- **Damage & Status System** (`damage_status.gd`): `_resolve_target_mitigation()`'s existing formula gains a real `hero_level` input instead of the hardcoded constant — no formula change, just where the value comes from.
- **Monster System**: `MonsterDiedEvent` already carries `tier` and `world_position` (both already-shipped fields) — no schema change needed on that event at all; Hero resolves kill-XP band directly from `payload.world_position` vs. its own `global_position`, with no dependency on `_monster_cache` (simpler than originally drafted here, since `world_position` was already on the payload).
- **Wave Manager**: `wave_completed` already exists and fires exactly once per wave clear — Hero subscribes to it for wave-completion XP, no changes needed to Wave Manager itself.
- **Event Bus**: `mission_phase_changed(new_phase == "MISSION_COMPLETE")` already exists for mission-completion XP.
- **Hero Skill Tree System** (`hero-skill-tree.md`): receives a new `source` value on the existing `skill_tree_point_earned` event — no schema change to that system, only a new literal value flowing through an existing parameter.
- **Save & Persistence**: Hero's existing `get_save_data()`/`restore_save_data()`/`reset_to_defaults()` gain 2 new fields (`current_level`, `current_xp`) — same pattern as every other persisted Hero field.
- **Hero Combat & Stats Redesign** (already shipped): this spec's entire reason for existing is closing that redesign's `HERO_LEVEL_PLACEHOLDER` gap (3.5).

## 7. Tuning Knobs

| Knob | Safe range | Affects |
|---|---|---|
| Kill XP per tier (STANDARD/ELITE/BOSS) | 1–20 / 5–50 / 20–500 | Pace of leveling from combat |
| Outer-band XP fraction | 0.0–1.0 (currently 0.5) | How much "assist" kills are worth relative to direct kills |
| Outer band radius multiplier | 1.5×–4× attack_range (currently 2×) | How far from the Hero a kill still counts for any XP |
| Wave completion XP | 10–100 | Pace of leveling from surviving waves |
| Mission completion XP | 50–500 | Pace of leveling from finishing missions |
| Level curve base (100) / growth rate (1.15) | base 50–200, growth 1.05–1.25 | Overall steepness of the leveling curve |
| Level cap (50) | 20–100 | Ceiling for stat growth and content balance |
| Flat stat growth per level (+10 HP/+2 PA/+2 MA) | HP 5–25, attack stats 1–5 | How much raw power each level provides |
| Skill-point/class-bonus level interval (5) | 3–10 | How often leveling feeds the Skill Tree / class bonus, vs. Tower Mastery's own primary point source |

## 8. Acceptance Criteria

- AC-1: A monster kill within Hero's current Attack Range grants the correct tier-based XP amount (5/15/100).
- AC-2: A monster kill beyond Attack Range but within 2× Attack Range grants half that amount, floored; beyond 2× grants 0.
- AC-3: Wave completion grants exactly 25 XP; mission completion grants exactly 150 XP; both are independent of and additive with kill XP earned during that wave/mission.
- AC-4: `xp_required(level)` matches Formula L1 exactly for any level 2–50; a single large XP grant correctly crosses multiple level thresholds in one resolution (Formula L3's `while` loop), applying every crossed level's rewards.
- AC-5: Every level grants the flat +10 HP/+2 Physical Attack/+2 Magic Attack; every 5th level additionally grants exactly 1 Skill Tree point (to the correct archetype pool) and the correct class-specific bonus, gated on a Primary class being designated at that moment.
- AC-6: At level 50, further XP is discarded and no further `hero_leveled_up` emissions occur.
- AC-7: Level/XP persist through a save/reload and through a mission DEFEAT; both reset to 1/0 only on a full new-game reset, in lockstep with the Skill Tree's own reset trigger.
- AC-8: `damage_status.gd`'s Armor mitigation formula uses the Hero's real current level (verified via a monster Armor test at a level other than 1), closing the `HERO_LEVEL_PLACEHOLDER` gap from the Hero Combat & Stats Redesign.

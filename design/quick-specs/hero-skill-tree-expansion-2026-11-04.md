# Hero Skill Tree expansion: forks, passives, keystones (design pass)

Date: 2026-11-04. Status: **design pass, not built**. First-pass numbers, unplaytested.
Amends (when built): `design/gdd/hero-skill-tree.md` (Rules 3b/3c, 6-10, 13, 14), ADR-0041 save shape.
Request: "do the design pass for the expanded tree" (after "would a hero skill tree be a suitable addition").

## 1. Problem

The current tree (4 archetype chains of `[Minor_1, Choice_1, Choice_2, Choice_3]`, 16 nodes) has four gaps:

1. **Lines, not a tree.** The only decision is which skill a Choice node gives. Two heroes with the same skills are identical.
2. **Minor_1 does nothing.** Its effect was deferred (GDD Rule 14) and never authored: 4 of 16 purchases are empty.
3. **Done too early.** 1 purchase per Sanctuary visit fills all 16 nodes by about mission 16. The campaign runs to about mission 65 (level 50), so the tree is dead for three quarters of it.
4. Points are not the bottleneck: one point per 45 s of mastery per build, plus one every 5 hero levels. The visit cap is the real pacing gate.

## 2. Goals and non-goals

Goals: real build identity per archetype; every purchase has an effect; tree completes around mission 45-55; keep what is distinctive (towers train the hero: points still come from Tower Mastery per archetype).

Non-goals: a second tree; changing the skill roster, Choice-node candidates or the Ultimate combo table; a new currency; mid-mission spending.

## 3. Shape (decision: branches hang off the existing spine)

Each archetype keeps its 4-node **spine** exactly as today (same indices, same skill tiers, same pacing of skills). Three **branch slots** hang off it:

```
 Root (Minor_1) ─ Skill I ─────────── Skill II ─────────── Skill III
                     │                    │                    │
                 Fork I               Fork II              Keystone
               L: m─m─N              L: m─m─N            pick 1 of 2
               R: m─m─N              R: m─m─N
```

- **Fork I** opens once Skill I (spine node 1) is bought; **Fork II** once Skill II is bought; **Keystone** once Skill III is bought.
- A fork has two **sides** (L/R), each a 3-node line: Minor, Minor, Notable, bought in order. Buying the first node of a side **locks the other side** of that fork (until retrained, §6).
- The keystone slot offers 2 keystones; buying one locks the other.
- Spine and branches are independent once open: each visit the player chooses between advancing the spine (next skill) or deepening a branch. This is the new core decision, alongside "which archetype".

Per archetype: 4 spine + 3 + 3 + 1 = **11 purchases** out of 18 visible nodes. Whole tree: **44 purchases**, 72 visible nodes.

Alternatives rejected:
- Forks *on* the spine (between skills): delays Skill II to purchase 6 and Skill III to purchase 10 per archetype, which slows the skill roster and Ultimate combos that are already tuned.
- One shared cross-archetype passive web (PoE style): breaks the per-archetype point pools, which are what tie the tree to Tower Mastery.

## 4. Economy and pacing

| Rule | Value | Change |
|---|---|---|
| Point sources | Tower Mastery per archetype + 1 per 5 hero levels to primary class | unchanged |
| Cost per node | 1 point of that archetype (or 1 overflow) | unchanged, branches included |
| Visit cap | 1 purchase per Sanctuary visit | unchanged; now also covers branch nodes and retrains |
| Overflow (Rule 3b) | credited when the earning archetype has all 11 purchases done | was: 4 nodes done |
| Terminal no-op (Rule 3c) | when all 44 purchases are done | was: 16 |

Pacing: 44 purchases at 1/visit = tree complete at about visit 44-50 (some visits have no point in the archetype the player wants). That lands inside the mission 45-55 target and before level 50 (~mission 65). If playtests show players run dry of things to buy before then, the tuning knob is the visit cap (keep at 1); if they never finish, raise it to 2 from mission 30 onward. Do not add cost per node: points are plentiful, so cost would only shift who is starved, not pacing.

## 5. Effects

### 5.1 Effect vocabulary (reuse, no new systems)

- **Minor nodes and Root**: permanent stat bonuses, the same `{stat: value}` fold as gear (`EquipmentBonuses.fold_stat_entry`). Rule: stats whose base is 0 (`armor`, `lifesteal`, `crit_multiplier`, `cdr`, resists) take **flat** values; other stats take **additive fractions** (an additive % of 0 is 0).
- **Notables**: one effect each, from the 8 types SetEffectController already runs (`on_kill_stack_buff`, `on_crit_status`, `on_wave_start_buff`, `on_skill_cast_buff`, `phase_state`, `on_kill_heal`, `on_hurt_shield`, `low_hp_state`), same param schema as `design/balance/equipment-set-effects.md`. Stats inside effects are additive fractions (existing rule).
- **Keystones**: a large stat bonus paired with a stat penalty (negative additive fraction, within the existing −0.75 floor). Trade-offs, not pure upgrades.

All bonuses fold inside the existing `clamp(1 + additive, −0.75, 3.0)` and per-stat caps; no cap changes.

### 5.2 Catalogue (first pass)

"×2" = both Minor nodes of that side give the listed bonus (so a full side gives it twice).

**Physical** (Warden: armor, HP, attack)

| Slot | Name | Effect |
|---|---|---|
| Root | Hardened | armor +4 (flat) |
| Fork I L | Bulwark | max_hp +6% ×2; Notable **Iron Resolve**: `on_hurt_shield` shield 0.06, dur 4, cd 10 |
| Fork I R | Onslaught | physical_attack +5% ×2; Notable **Bloodrush**: `on_kill_stack_buff` {physical_attack 0.02}, max 8, dur 6 |
| Fork II L | Bastion | armor +5 ×2; Notable **Unbroken**: `low_hp_state` hp 0.35, {armor 0.40, max_hp 0.10} |
| Fork II R | Cleaver | physical_attack +6% ×2; Notable **Executioner's Rhythm**: `on_skill_cast_buff` {physical_attack 0.15}, dur 5 |
| Keystone A | Mountain's Oath | max_hp +25%, armor +10, move_speed −15% |
| Keystone B | Berserker's Pact | physical_attack +30%, max_hp −20% |

**Ranged** (Marksman: range, crit, speed)

| Slot | Name | Effect |
|---|---|---|
| Root | Keen Eye | attack_range +4% |
| Fork I L | Marksman | crit_chance +0.02 ×2 (flat); Notable **Steady Aim**: `on_wave_start_buff` {attack_range 0.15, crit_chance 0.50}, dur 12 |
| Fork I R | Skirmisher | move_speed +5% ×2; Notable **Hit and Run**: `on_kill_stack_buff` {move_speed 0.03, physical_attack 0.02}, max 6, dur 5 |
| Fork II L | Sniper | attack_range +5% ×2; Notable **Long Watch**: `phase_state` WAVE_ACTIVE {attack_range 0.10, physical_attack 0.10} |
| Fork II R | Volley | crit_multiplier +0.10 ×2 (flat); Notable **Barbed Shots**: `on_crit_status` poison 0.05, 4 s |
| Keystone A | Eagle's Perch | attack_range +30%, move_speed −20% |
| Keystone B | Wind Runner | move_speed +25%, physical_attack +10%, attack_range −15% |

**Elemental** (Arcanist: magic, cooldowns, resists)

| Slot | Name | Effect |
|---|---|---|
| Root | Attuned | magic_attack +6% |
| Fork I L | Pyromancy | magic_attack +6% ×2; Notable **Kindling**: `on_crit_status` burn 0.08, 3 s |
| Fork I R | Cryomancy | elemental_resist_fire +0.05 and elemental_resist_frost +0.05 ×2 (flat); Notable **Glacial Focus**: `on_skill_cast_buff` {magic_attack 0.20}, dur 5 |
| Fork II L | Storm | cdr +0.03 ×2 (flat); Notable **Surge**: `on_kill_stack_buff` {magic_attack 0.03}, max 8, dur 6 |
| Fork II R | Conduit | magic_attack +4% ×2; Notable **Flux**: `on_wave_start_buff` {magic_attack 0.30}, dur 10 |
| Keystone A | Unbound Power | magic_attack +35%, max_hp −20% |
| Keystone B | Elemental Mastery | cdr +0.08, both resists +0.10 (flat), magic_attack −10% |

**Support** (Steward: sustain, tower synergy)

| Slot | Name | Effect |
|---|---|---|
| Root | Field Kit | lifesteal +0.02 (flat) |
| Fork I L | Medic | lifesteal +0.02 ×2; Notable **Second Breath**: `on_kill_heal` heal_fraction 0.01 |
| Fork I R | Tactician | tower_affinity +5% ×2; Notable **Rally Point**: `phase_state` WAVE_ACTIVE {tower_affinity 0.10} |
| Fork II L | Quartermaster | cdr +0.02 ×2 (flat); Notable **Inspire**: `on_skill_cast_buff` {tower_affinity 0.15}, dur 6 |
| Fork II R | Warden's Bond | max_hp +5% ×2; Notable **Aegis Link**: `on_hurt_shield` shield 0.06, dur 4, cd 10 |
| Keystone A | Commander's Vow | tower_affinity +20%, physical_attack −15%, magic_attack −15% |
| Keystone B | Lifebinder | lifesteal +0.06 (flat), max_hp −10% |

Support's Tactician/Commander lines are the "towers train the hero, the hero trains the towers" loop: they raise `tower_affinity`, which buffs towers near the Hero (capped by `TOWER_AFFINITY_BONUS_CAP` 2.0).

Scale check against gear: a full Physical L/L build is +12% max_hp, +14 armor, a shield and a low-HP state. Comparable to one 4-piece set plus its second-tier effect, spread over ~11 visits. Balance this in playtest, not on paper.

## 6. Retraining (decision: swap a side, costs the visit)

- At Sanctuary, the player may **retrain** one fork or the keystone slot: the bought nodes move to the other side at the **same depth** (2 nodes bought on L become the first 2 on R), or the keystone swaps.
- Costs the visit's one purchase (`visit_spend_count += 1`). No points, gold or materials. Points are never refunded.
- Spine Choice nodes stay permanent (unchanged LOCKED_OUT rule): skill choices feed the Ultimate combos and the Skill Build loadout, and reversing them is out of scope.
- Why not a gold cost: the previous gold-conversion design was reverted for interacting badly with `resource-economy.md`. A visit-cost keeps retraining inside the one economy the tree already has.

## 7. Data and code plan

1. **Data**: `HeroTreeNodeResource` (`id`, `archetype`, `slot` = `root|fork_1|fork_2|keystone`, `side` = `L|R|A|B|""`, `depth` 0-2, `stats: Dictionary`, `effect: Dictionary`). 60 `.tres` files in `assets/data/hero_tree/`, loaded by GameDataRegistry. Root nodes give `Minor_1` its effect (closes GDD Rule 14).
2. **HeroSkillTree** (`src/core/hero_skill_tree/hero_skill_tree.gd`): spine (`_chain_nodes`) untouched. Add `_branches[archetype] = {fork_1: {side, depth}, fork_2: {side, depth}, keystone: ""}`. New API: `is_branch_purchasable(archetype, slot, side)`, `purchase_branch_node(archetype, slot, side)`, `retrain(archetype, slot)`, `get_branch_state(archetype, slot)`, `active_tree_nodes() -> Array[HeroTreeNodeResource]`. Shared pools, overflow and visit cap. `is_archetype_fully_unlocked` = 11 purchases. New signal `skill_tree_branch_changed(archetype, slot)` (EventBus).
3. **Save** (ADR-0041 amendment): add `branches` key, schema v2. `restore_save_data` accepts v1 (no `branches`, all branches locked, existing spine kept). No migration of points: v1 saves keep their banked points and simply have new things to buy.
4. **Hero stats**: new bucket `_tree_flat/_tree_additive` in `hero.gd`, rebuilt from `GHeroSkillTree.active_tree_nodes()` on `skill_tree_node_unlocked`, `skill_tree_branch_changed` and restore. Kept apart from the equipment bucket, which `_recompute_equipment_bonuses` replaces wholesale.
5. **Notables/keystones' effects**: `SetEffectController._rebuild()` concatenates tree effects (keys `tree:<node_id>`) with set effects. No new effect types.
6. **UI** (`hero_skill_tree_screen.gd`): per archetype column, spine on the left, branches to the right of the skill that opens them; locked-out side greyed with its effect text still readable; Retrain button per fork; tooltip per node. Plain layout, same honesty bound as the current screen (bespoke connector art stays separate art work).
7. **Strings**: 60 node names + descriptions in `strings.csv` (editor pass after).

## 8. Acceptance criteria

- AC-X1: a fork side cannot be bought until its spine skill is bought; buying L depth 0 makes R unpurchasable.
- AC-X2: nodes within a side unlock strictly in order; the visit cap blocks a second purchase (spine or branch) in one visit.
- AC-X3: retrain moves depth to the other side, spends the visit, refunds nothing; Hero stats and active effects update the same visit.
- AC-X4: overflow credits only when the earning archetype has all 11 purchases; terminal no-op only at 44.
- AC-X5: a v1 save restores with spine intact, branches locked, points unchanged.
- AC-X6: Hero effective stats include tree bonuses; zero-base stats only get flat values (data validation rejects an additive % on a zero-base stat).
- AC-X7: tree effects run through SetEffectController alongside set effects without key collisions.
- Live: buy Root + Fork I L, start a mission, confirm the stat and the notable fire.

## 9. Open questions (defaults chosen; change before build if wanted)

1. Visit cap stays 1 (default) vs 2 late-game — decide after a playtest.
2. Retrain costs the visit (default) vs free vs gold.
3. Keystones as trade-offs (default) vs pure upgrades.
4. Whether Notables should show in the Mission HUD effect list (default: yes, same list as set effects).

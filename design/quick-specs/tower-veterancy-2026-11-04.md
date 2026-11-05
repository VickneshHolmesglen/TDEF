# Tower veterancy (ranks from kills)

Date: 2026-11-04. Status: **built** (overnight autonomy pass). Source idea: towers that level up from kills (Rogue Tower and classic WC3 tower defense maps), adapted as a light per-mission layer on top of crafted towers.

## Rules

- A placed tower is credited with a kill when it landed the **last direct hit** on the monster. DoT ticks keep that credit (a burn/poison kill still counts for the tower that applied the last hit). Hero kills credit no tower.
- Ranks: **1 at 5 kills, 2 at 15, 3 at 30** (was 10/30/60 until the 2026-11-05 balance check) (`TowerSystem.VETERANCY_KILL_THRESHOLDS`).
- Each rank multiplies the tower's hit damage by `1 + 0.08 x rank` (rank 3 = +24%), alongside the aura buff in the damage formula. Splash inherits it (splash damage derives from the hit).
- Mission runtime only: never saved; a sold tower's rank is gone. Support/aura towers never kill, so they never rank (their value is the buff).
- Presentation: gold chevrons over the tower's base, one per rank, and a gold attack-punch flash on rank-up (`TowerInstance.set_rank`).

## Plumbing

`tower_attacked(tower_id, ...)` -> DamageStatus sets `MonsterDamageTaken.source_tower_id` -> MonsterManager stores `MonsterEntity.last_hit_tower_id` -> `MonsterDiedEvent.killer_tower_id` (tower kills only) -> TowerSystem `_credit_kill` -> `tower_ranked_up(tower_id, rank)` -> MissionScene -> `TowerInstance.set_rank`.

Fixed on the way: TowerSystem did not subscribe to `monsters_died_batch` (ADR-0033), so monsters killed on a heavy frame stayed in its target cache until `wave_completed`. It now handles the batch the same as single deaths.

## Why these numbers

Retuned 2026-11-05 (`design/balance/balance-check-2026-11-05.md`): a whole mission averages ~58 kills (Rift Gate, the largest, 100), so the original 60 for rank 3 was out of reach and 30 for rank 2 only happened on the biggest maps. At 5/15/30 the tower that carries a defence reaches rank 2 on most maps and rank 3 on the big ones; the rest of the line-up gets rank 1. +8% per rank is visible but smaller than an aura buff (+20%), so placement and crafting still matter more than veterancy.

## Verification

`tests/unit/tower/tower_veterancy_test.gd` (thresholds, multiplier, single/batch credit, non-tower kills, batch cache erase), `tests/unit/monster/kill_attribution_test.gd` (last tower credited, hero kill, DoT kill), `damage_status_test.gd` (source_tower_id). Live on the_gap: 14 tower kills attributed, ranks 1 and 2 emitted, chevrons visible on the ranked towers.

## Also fixed

The pre-placement perk badge was drawn in TowerInstance's own `_draw()`, which renders under the tower sprite (a Node2D's own drawing is beneath its children), so it was hidden. It now draws on the same `BadgeOverlay` child as the chevrons. Live-checked: perk dots and chevrons both visible.

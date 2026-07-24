# Cross-GDD Review Report
Date: 2026-07-14
GDDs Reviewed: 12 (+ game-concept.md, game-pillars.md, systems-index.md)
Systems Covered: EventBus, Grid, Save & Persistence, Hero, Tower, Monster, Damage & Status, Pathfinding, Wave Manager, Inventory, Resource Economy, Mission HUD

---

### Consistency Issues

#### Blocking (must resolve before architecture begins)

🔴 **`monster_spawn_requested` payload field count disagrees across three GDDs**
Wave Manager emits and AC-12 requires 6 fields including `is_penultimate_wave: bool` (Rule 15c) — Monster Formula 4 reads that exact field. But `event-bus.md`'s catalogued `MonsterSpawnRequest` Resource has only 5 fields, and `monster.md` Rule 6 independently lists only 5 — both missing `is_penultimate_wave`. Wave Manager's own Bidirectionality note already flags this as needing an update that was never made. → Add `is_penultimate_wave: bool` to `event-bus.md`'s catalogue and `monster.md` Rule 6.

🔴 **`boss_tower_attack_attempted` — emitter omits the `wave_id` field the consumer requires**
`event-bus.md` and `tower.md` define this as 4 fields including `wave_id`, which Tower's wave-boundary staleness guard depends on. But `monster.md` (the actual emitter, Rule 17d.1) emits only 3 fields — no `wave_id` anywhere in the document. Tower's documented guard cannot function. → Add `wave_id` to `monster.md`'s emission (Rules 17d.1, 18, Interactions table).

🔴 **`monster_cell_entered` is catalogued as Monster-owned and load-bearing for Tower targeting, but Monster never emits it**
`event-bus.md` lists it under Monster System; `tower.md` Rule 14a's `_monster_cache` position data is "Updated by `monster_cell_entered`," driving CLOSEST_TO_GOAL/SPAWN_ORDER targeting. `monster.md` contains zero occurrences of this event — its movement rule (Rule 11) never emits it. → Add the emission to `monster.md` Rule 11 and its emitted-events list.

🔴 **`base_quality` is defined incompatibly — global constant (Wave Manager) vs. per-entry data (Resource Economy)**
Wave Manager's frozen semantic contract mandates `base_quality` as a single global constant with a CI validator (`MAX_BASE_QUALITY_PROBABILITY = 0.2097`) checked "for every WaveConfig." Resource Economy instead makes `base_quality_probability` a per-`DropEntry` authored value with a different runtime clamp (0.80). The CI check references a field that doesn't live where Wave Manager says it does — unimplementable as written (not a gameplay break; Resource Economy's clamp happens to be stricter). → Reconcile ownership and relocate/rewrite the validator.

🔴 **`tower_destroyed` payload is missing `footprint` in `tower.md`'s own Rule 24, contradicting `event-bus.md`/`mission-hud.md`**
Rule 24 lists `(tower_id, grid_position, archetype)`; the catalogue and Mission HUD's PC-3 both require a 4th `footprint` field. *(Surfaced incidentally by the scenario-walkthrough pass.)* → Add `footprint` to Rule 24's payload list.

#### Warnings (should resolve, but won't block)

⚠️ `monsters_died_batch` has no formal catalogue entry or payload definition despite being used by Wave Manager, Monster, and Mission HUD — EventBus's own OQ-3 calls this unresolved while Wave Manager's mirrored OQ-1 is marked "RESOLVED" without ever delivering the payload.

⚠️ `player_ready` and `tower_sell_requested` are asserted as Mission HUD emissions by `event-bus.md`, but `wave-manager.md` and `tower.md` respectively never mention them in their own subscription tables — one-sided dependency.

⚠️ Resource Economy's Dependencies table claims a hard Save & Persistence dependency that contradicts its own statelessness (Rule 1) and the now-resolved fact that `MissionEconomy`, not Resource Economy, owns gold state — stale row.

⚠️ `hero_skill_activated` payload mismatch (`skill_id/target_position` shipped vs. `skill_slot: int` needed) — already tracked as an open question in both `hero.md` and `mission-hud.md`, but remains an unresolved blocker for Mission HUD's skill buttons specifically.

⚠️ `wave-manager.md`'s Overview states "20s Intermission," contradicting its own Rule 7/11/Tuning Knobs and `game-concept.md`'s canonical 30s — stale prose.

⚠️ `boss_died` cause `"breached"` is catalogued in `event-bus.md` but never actually emitted — Monster's breach path only emits `monster_breached`; the cause value is orphaned.

⚠️ `monster.md`'s Overview describes ELITE packs as fixed to "Wave 4," contradicting the system's own correctly-implemented penultimate-wave-relative model elsewhere in the same document.

⚠️ Tower requires the `damaged` component flag to survive save/restore, but neither `inventory.md` nor `save-persistence.md` explicitly confirms persisting it (low risk — primitive bool — but unconfirmed).

#### Verified Consistent (checked during this pass, no longer stale)

Several previously-flagged "must update" cross-references turned out to already be resolved: Hero already subscribes to `tower_removed`; `game-concept.md` already reflects Tower's mid-wave placement block; `hero_class_unlocked` is already catalogued. All of this session's earlier same-day revisions (Tower ↔ Inventory's `tower_component_returned`, Mission HUD's `_boss_state`/tower-HP-bar fixes, Resource Economy's Formula 4 rebuild) were independently re-verified and confirmed genuinely consistent — not just asserted.

---

### Game Design Issues

#### Blocking

🔴 **In-mission gold economy has a sink but no faucet — and mechanistically, nothing ever wires the spend**
Two independent passes converged on the same root problem from different angles:
- **Design theory**: The only gold source anywhere is a flat one-time `scout_starting_gold` (150) at SCOUT entry. No per-kill or per-wave gold exists — kills only drop materials. The one refund path (Sell, 40%) is a net loss, not a faucet. This contradicts `game-concept.md` Rule 7 and the INTERMISSION state row, both of which assume the player can "place additional towers" between waves — only possible today by deliberately under-spending Scout. Resource Economy's own Open Questions half-acknowledge this gap (150 calibrated against a 350–400 target that implies a missing ~200–250 gold from somewhere).
- **Scenario walkthrough**: Confirmed mechanistically — Tower owns 10 EventBus events, none of them `resources_changed`; Resource Economy is stateless and does not subscribe to `tower_placed`. **No system anywhere emits the placement-cost debit.** Gold only ever increases after the Scout grant.
→ Either define an in-mission gold faucet (per-kill/per-wave-clear grant, scaled to the 350–400 target) and wire the placement-cost debit, or explicitly re-scope the loop to "one Scout budget, intermissions are reposition-only" and correct `game-concept.md` Rule 7 and Wave Manager's intermission language to match. This determines whether player DPS can grow within a mission at all (feeds directly into the difficulty-curve warning below).

#### Warnings

⚠️ Enemy stats (HP, speed, boss damage) all escalate across 8 waves, but hero and tower power are both flat for the whole mission — the only in-mission player-power lever (placing more towers) is exactly what the blocking gold gap starves. Monster's own "stable TTK" design note is only true if this is resolved.

⚠️ Mission HUD's route-overlay withdrawal at wave start sits in genuine tension with Pillar 1's diagnosability anti-pattern — already self-flagged in mission-hud.md as an unvalidated design hypothesis with an experiential AC gating it; no new action needed beyond what's already tracked.

⚠️ Hero's "messy, improvisational win" register sits near Pillar 1's "wins that feel lucky" anti-pattern, in tension with Tower/Wave Manager's "read it correctly" register — judged compatible-by-design (planner + tactician), not a contradiction, but worth a named playtest criterion.

⚠️ The material economy (drop rates, quantities) cannot be balance-validated yet — every sink (Crafting, Menagerie, Defense Building, Equipment Forge) is an undesigned system. Intentional at this stage; defer final calibration sign-off until at least one sink exists.

⚠️ The hero's manual-control layer (movement + 4 skills + Ultimate + auto-attack + survival management + body-blocking) is dense enough that it deserves an explicit vertical-slice playtest question, especially on gamepad — attention budget passes at the system level (~3 concurrent active systems) but the hero bucket itself is heavy.

#### Checks that passed cleanly

No dominant strategy detected (tower tier tradeoffs, Tower Affinity's sqrt-scaling clamp, and hero sustain caps all hold up). All 12 systems' Player Fantasy sections map to at least one canonical pillar — no orphaned systems. The 12 fantasies read as one coherent "Architect-General + Endless Theorist" identity.

---

### Cross-System Scenario Issues

Scenarios walked: 4
1. Tower destroyed by boss mid-wave + Sell context open + PC-3 banner
2. Boss kill in the same frame `wave_completed` latches
3. DEFEAT while a tower is mid-destruction
4. Rapid Scout-Phase placement spend racing a Ready-to-PRE_WAVE skip

#### Blockers

🔴 **Scenario 2 — Boss-kill/wave-clear cascade violates EventBus's own depth-1 cascade rule**
`boss_died → wave_completed → monster_died` (for force-removed survivors) is a synchronous depth-2 cascade. EventBus Core Rule 5/EC-1 explicitly caps cascade depth at 1 and requires deferred dispatch beyond Level-1 — this chain violates its own project-wide rule, and it's the *normal* case (a BOSS is always the last wave entry, so earlier monsters are routinely still alive when it dies). This also contradicts Wave Manager's own AC-29 same-tick requirement. → Specify which link in the chain defers, and reconcile against AC-29/EC-3.

🔴 **Scenario 3 — Undefined ordering between the DEFEAT save and damaged-component return**
Both Save & Persistence (post-mission save on DEFEAT) and Tower's mission-end `tower_component_returned`→Inventory `item_added` path subscribe to the same `mission_phase_changed(→DEFEAT)` event with no specified ordering. If S&P's handler runs first, it captures Inventory's save data *before* destroyed components are re-added — silently violating tower.md's own "DEFEAT does not forfeit components" guarantee. This is also the same depth-2 cascade problem as Scenario 2, and recurs on every voluntary Sell too. → Define deterministic ordering (e.g., defer the DEFEAT save one frame, matching S&P's existing 1-frame-defer precedent elsewhere).

🔴 **Scenario 4 — mechanistic confirmation of the gold-faucet gap** (merged into the Design Issues blocking item above)

#### Warnings

⚠️ **Scenario 4 — Three separately-sourced, non-reconciled gold numbers**: Tower's Gate 2 affordability check, `MissionEconomy`'s authoritative balance, and Mission HUD's live counter have no coherence contract between them — Tower doesn't document a `resources_changed` subscription for its cached balance, and ADR-0008 deliberately doesn't call `MissionEconomy.can_afford()` yet. Under rapid placement, the gate could approve against a stale cache with no reconciliation step.

#### Info

ℹ️ Scenario 1 (Tower destroyed + Sell + PC-3) — verified **no actual race exists**: Sell doesn't exist during WAVE_ACTIVE, and component return is deferred to mission-end, not the destruction frame — the simultaneity in the hypothesis doesn't occur in practice.

ℹ️ Where does a destroyed tower's pending component-return data live between destruction (entity freed) and mission-end processing? Not explicitly stated — must be retained at the Tower System singleton level, worth stating outright in `tower.md`.

---

### GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `monster.md` | Missing `is_penultimate_wave`, `wave_id`, `monster_cell_entered` emissions; stale "Wave 4" Overview prose | Consistency | Blocking |
| `event-bus.md` | Missing `is_penultimate_wave` field, `monsters_died_batch` catalogue entry, orphaned `boss_died("breached")` cause | Consistency | Blocking + Warning |
| `wave-manager.md` | `base_quality` ownership conflict with Resource Economy; stale "20s Intermission" Overview | Consistency | Blocking + Warning |
| `resource-economy.md` | `base_quality` ownership conflict; stale Save & Persistence dependency row; no in-mission gold faucet defined | Consistency + Design | Blocking |
| `tower.md` | Missing `footprint` in `tower_destroyed` Rule 24; no gold-spend emission; undocumented `resources_changed` subscription for Gate 2; unspecified component-custody storage location | Consistency + Scenario | Blocking |
| `save-persistence.md` | Undefined ordering vs. Tower's DEFEAT-time component return | Scenario | Blocking |
| `game-concept.md` | Assumes an in-mission gold faucet (Rule 7, INTERMISSION row) that doesn't exist | Design | Blocking |

---

### Verdict: FAIL

### Required actions before re-running `/review-all-gdds`:
1. Reconcile the three payload-mismatch pairs (`monster_spawn_requested`, `boss_tower_attack_attempted`, `monster_cell_entered`, `tower_destroyed`) between emitter and catalogue/consumer GDDs.
2. Resolve the `base_quality` ownership conflict between `wave-manager.md` and `resource-economy.md`.
3. Design and wire an in-mission gold faucet (or formally re-scope the loop), including the missing placement-cost debit event.
4. Resolve the two synchronous depth-2 EventBus cascade violations (boss-kill/wave-clear; DEFEAT save vs. component return).

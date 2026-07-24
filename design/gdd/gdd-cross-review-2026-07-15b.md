# Cross-GDD Review Report (Re-run)
Date: 2026-07-15
GDDs Reviewed: 15 (game-concept.md, game-pillars.md, systems-index.md + 12 system GDDs)
Registry baseline: design/registry/entities.yaml (0 entities, 0 items, 4 formulas, 26 constants — unchanged structurally since the last pass)

This is a re-run of the same-day review at `gdd-cross-review-2026-07-15.md`. Since that pass, six documents (tower.md, wave-manager.md, mission-hud.md, event-bus.md, resource-economy.md, monster.md) each went through a fresh `/design-review` pass fixing their specific flagged issues. This re-run verifies those fixes actually landed correctly (not assumed) and finds anything new or still-remaining.

**Headline result:** every fix targeted by this session's individual `/design-review` passes is confirmed genuinely correct at its source, not just mechanically patched. What remains is mostly propagation debt — a fix landed in the owning document but wasn't carried through to 2-3 sibling documents that also state the same fact — plus one real doc-internal table/prose contradiction and one substantive new design gap.

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **`tower.md`'s `mission_resource_budget` Tuning Knob still cites 375 as the "default"**
Line 717: `"6-wave missions (default): ~375..."`. This is exactly the figure `resource-economy.md`'s re-review #2 (2026-07-15) proved was never the default — 375 is the `r=0.25` safe-range-ceiling case; the actual default (`r=0.20`) total is 349. `resource-economy.md` and `entities.yaml`'s `tower_placement_budget_target` entry both correctly state both cases now. `tower.md` is the one place still asserting 375 as "(default)" — the exact error the fix was meant to close everywhere.

🔴 **`entities.yaml`'s `boss_attack_damage` formula and `tower_hp_boss_damage_provisional_range` constant weren't updated** when `monster.md`'s Formula 3 floor changed 40→55 this session. Both registry entries still say "final-wave BOSSes use base_damage 40-80." Any future content authoring that reads the registry rather than monster.md directly will author against the already-disproven floor.

🔴 **`wave-manager.md` still specifies `wave_preview_available.composition` as `Array[Dictionary]` in 4 places** (Rule 8 line 95, Rule 11 line 108, UI Requirements Phase Display Data Contract table line 480, AC-27 line 606) — contradicts `event-bus.md`'s now-fixed `WaveCompositionEntry` Resource subclass, promoted specifically to close a Core Rule 4 violation. `event-bus.md`'s own AC-03 ("zero signals use Dictionary") would fail against wave-manager.md's description if implemented as documented there.

### Warnings (should resolve, but won't block)

⚠️ `event-bus.md` Formula 2's variable table still cites the stale `T_chain ≈ 0.208ms` (line 330) — Formula 1 was corrected to ~0.093ms this session and Formula 2's own worked example three lines below already uses the corrected number; the variable table row wasn't updated to match.

⚠️ `tower.md`'s Overview still says "the five registered tower events" (line 17) — the document (and event-bus.md's catalogue) actually shows Tower emitting 11+ events (tower_removed, tower_damaged, tower_aura_pulse, tower_wave_summary, tower_component_returned, resources_changed, etc.). Predates this session, not touched by it.

⚠️ `inventory.md`'s Open Question about `tower_component_returned` is stale (line 134 and Open Questions table) — states event-bus.md's catalogue "still needs `tower_component_returned` added," but that event was added 2026-07-14. inventory.md predates that fix.

### Confirmed Fixed (from the prior pass)

✅ `event-bus.md` catalogue — `boss_spawn_cell`, `is_penultimate_wave`, `monsters_died_batch`, `tower_placed`/`tower_attacked` Resource promotions all verified present and correct.
✅ `resource-economy.md` Formula 5/AC-18/AC-19 r=0.20-vs-r=0.25 split — verified correct, matches entities.yaml.
✅ `monster.md` "Wave 4" Overview text and Formula 4 escalation invariant reframe — verified correct.
✅ `monster.md` Formula 3 final-wave base_damage floor 40→55 — verified correct in variable table, calibration table, Tuning Knobs, and AC-44.
✅ `mission-hud.md`'s boss-telegraph confirmation pulse trigger — Rule 11e and PC-5 contract both correctly bound to `wave_completed`.
✅ `wave-manager.md` `boss_spawn_cell: Vector2i` consistency — no `has_boss`/`boss_entry_lane` references remain anywhere.

### Confirmed Still Open (from the prior pass, not yet addressed)

⏳ save-persistence.md's DEFEAT-save ordering hazard vs. Tower's `tower_component_returned`.
⏳ game-concept.md vs. save-persistence.md DEFEAT-transition model conflict (direct DEFEAT→SCOUT vs. DEFEAT→Sanctuary-reload).
⏳ hero.md's Formula 4 double-multiplication risk vs. D&S, and stale Formula 6 lifesteal basis.
⏳ damage-status.md's stale Dependencies table (still lists Wave Manager/Mission HUD as "Not yet designed").

---

## Game Design Issues

### Blocking

🔴 **Tower's T4 "Siege" mechanic (half of T4's boss-lane justification) references a Monster System boss-shield-phase concept that doesn't exist anywhere in monster.md.** BOSS entities have a single flat `current_hp` pool — no shield/phase-armor mechanic. `is_siege` doesn't appear in Monster's `boss_tower_attack_attempted` payload or in event-bus.md's catalogue beyond the bare field name in tower.md. A programmer building Monster System has nothing to build against for "shield penetration." Recommend either authoring a minimal boss-shield-phase mechanic in monster.md, or striking the Siege clause from tower.md Formula 1(b) and re-justifying T4 on its 2.0× boss DPS multiplier alone (still a substantial, self-contained differentiator).

🔴 `damaged_component_repair_cost` still debits a resource that doesn't structurally exist — unchanged from the prior pass, not touched this session (Crafting/Menagerie/Defense Building/Equipment Forge, the only plausible owners, are all still Not Started).

### Warnings

⚠️ Formula 3's base_damage floor correction (40→55) wasn't propagated to tower.md's own "Boss damage calibration" note (line 504, still says 40-80) or the `boss_tower_attack_damage` Tuning Knob citing "40-136."

⚠️ WAVE_ACTIVE's Combat Cluster "recede" guardrail now has 2 self-flagged deliberate exceptions (PC-3's banner, PC-5's pulse) with no stated ceiling — worth a dedicated attention-budget audit before Alpha.

⚠️ Monster's reframed invariant creates an emergent, unauthored "spike then respite" pacing shape — the penultimate ELITE now legitimately outweighs the following wave's opening entries. Coherent with Wave Manager's own Player Fantasy but no document names this pattern as intentional; recommend a one-line addition so it reads as designed pacing during playtesting rather than a perceived inconsistency.

⚠️ The material economy's sink side (Crafting/Menagerie/Defense Building/Equipment Forge) is still 100% unbuilt while the faucet side (Resource Economy) is now fully specified. Expected at this design-order stage — flagged so it isn't mistaken for a complete system.

### Confirmed Fixed

✅ Tower's OQ-11 — traced end-to-end, genuinely resolved (a real information channel was built, not just a numeric clamp).
✅ Monster's Formula 4 reframe — holds up; no other GDD assumes the old invariant (confirmed via grep across all design/gdd/*.md).
✅ Resource Economy's "Yield You Predicted" reframe — not a rationalization; the fantasy's actual mechanism (predictable formula) is unchanged by which number it lands on.

### Confirmed Still Open

⏳ game-pillars.md's Naming Reconciliation Note — no GDD header touched this session.
⏳ Save & Persistence's DEFEAT-save ordering (same item as Consistency section).

---

## Cross-System Scenario Issues

Scenarios walked: 4 — boss-lane telegraph re-verification; DEFEAT/mission-end chain; Resource Economy faucet vs. Tower costs; Monster Formula 4 vs. Wave Manager's is_penultimate_wave guard

### Blockers

🔴 **The pulse fix's underlying logic is correct — a full 7-step trace confirms it — but mission-hud.md's own States and Transitions summary table still shows the OLD reset trigger** on the WAVE_ACTIVE row ("`_boss_telegraph_cell` reset to sentinel (Rule 11e)" against the WAVE_ACTIVE phase-entry trigger), contradicting the corrected Rule 11e prose (lines 40, 67, 165, all now correctly say `wave_completed`). This table exists specifically as "the contract a programmer needs" (Rule 8) — an implementer working from it alone would silently reintroduce the original dead-code bug. Must fix: strike the reset from the WAVE_ACTIVE row's side-effects column.

🔴 DEFEAT/mission-end ordering hazard (Tower → Inventory → Save & Persistence) — confirmed still open via direct re-read of current text, not a stale carryover. Compounded by the still-unresolved DEFEAT-transition model conflict between game-concept.md and save-persistence.md.

### Warnings

⚠️ Resource Economy's per-wave gold grant (max 72-95) can't cover a full T4 repair (up to 160 gold) or possibly a fresh T4 placement in a single wave — likely intentional (gold accumulates across waves) but neither document states this explicitly.

### Info

ℹ️ Monster's `is_penultimate_wave` contract with Wave Manager (including the sub-5-wave guard) checked and confirmed fully consistent — no issue found.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `mission-hud.md` | States/Transitions table contradicts its own corrected Rule 11e | Scenario | Blocking |
| `wave-manager.md` | Still specifies `Array[Dictionary]` for `wave_preview_available`, contradicting event-bus.md's fix | Consistency | Blocking |
| `tower.md` | Stale 375-as-default budget figure; stale Formula 3 calibration note; T4 Siege mechanic has no Monster-side implementation | Consistency / Design Theory | Blocking |
| `entities.yaml` (registry) | `boss_attack_damage`/`tower_hp_boss_damage_provisional_range` still cite the old 40-80 range | Consistency | Blocking |
| `monster.md` | Siege gap's missing half lives in this document's scope (shared with tower.md) | Design Theory | Blocking (shared) |
| `event-bus.md` | Stale Formula 2 T_chain value | Consistency | Warning |
| `inventory.md` | Stale Open Question about tower_component_returned | Consistency | Warning |
| `save-persistence.md` | DEFEAT-save ordering + DEFEAT-transition model conflict (carried over) | Consistency / Scenario | Blocking (pre-existing) |
| `hero.md` | Formula 4/6 issues (carried over) | Consistency | Warning (pre-existing) |
| `damage-status.md` | Stale Dependencies table (carried over) | Consistency | Warning (pre-existing) |

---

## Verdict: FAIL

Real progress since the last pass: every fix targeted by this session's individual reviews is confirmed genuinely correct at the source. What remains is mostly propagation debt plus one real doc-internal contradiction (cheap fix) and one substantive new design gap (T4's Siege mechanic).

### Required actions before re-running

1. Fix mission-hud.md's States/Transitions table (cheapest, highest-confidence — same class of fix as the pulse bug itself).
2. Propagate wave-manager.md's composition payload type to match event-bus.md.
3. Propagate monster.md's 55-80 base_damage floor to tower.md and entities.yaml.
4. Propagate resource-economy.md's 349-default figure to tower.md.
5. Resolve the T4 Siege mechanic gap (author it in monster.md, or strike the clause from tower.md).

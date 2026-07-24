# Cross-GDD Review Report
Date: 2026-07-15
GDDs Reviewed: 15 (game-concept.md, game-pillars.md, systems-index.md + 12 system GDDs: grid-system, save-persistence, monster, damage-status, pathfinding, hero, inventory, event-bus, resource-economy, wave-manager, mission-hud, tower)
Registry baseline: design/registry/entities.yaml (0 entities, 0 items, 4 formulas, 26 constants — freshly corrected by a `/consistency-check` pass earlier the same session)

Note on process: no GDD in this project uses the `## Summary` header convention the skill's fast-scan step looks for (only `game-concept.md` matched, and its own Summary section reads "[To be designed]"), so this review proceeded directly to full parallel reads of all 15 documents rather than a summary-scan triage.

**Post-review fix applied (2026-07-15, same session):** The Scenario Blocker "Boss-Lane Telegraph confirmation pulse can never fire" (Mission HUD Rules 11d/11e) was fixed immediately after this report was written — Rule 11e's defensive reset was moved from `mission_phase_changed → WAVE_ACTIVE` to `wave_completed`, and the regression AC was rewritten to prove the fix. See `design/gdd/mission-hud.md`'s header and `design/gdd/reviews/mission-hud-review-log.md` for details. The finding below is left as originally written since it's an accurate record of what was found and why it mattered — treat it as resolved, not as an open item.

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **EventBus canonical catalogue missing `boss_spawn_cell`**
`event-bus.md`'s `wave_preview_available` entry lists only `next_wave_number: int`, `composition: Array[WaveCompositionEntry]` — no `boss_spawn_cell` field. But `wave-manager.md` (Rule 11), `mission-hud.md` (Group 3b / PC-5), and `tower.md` (Dependencies table) all treat `boss_spawn_cell: Vector2i` as an already-live, agreed part of this event's payload — this is the entire mechanism Tower GDD's OQ-11 was closed with, spanning three GDDs, added 2026-07-15. `systems-index.md`'s own risk table calls EventBus the "CRITICAL" bottleneck and states event payloads are to be treated as public API. Must add `boss_spawn_cell: Vector2i` to the `wave_preview_available` catalogue row before implementation, and confirm whether the 3-field payload needs a typed Resource subclass per EventBus's own Core Rule 4 (mirroring the precedent set for `monster_spawn_requested`).

🔴 **EventBus canonical catalogue missing `is_penultimate_wave`**
`event-bus.md` catalogues `monster_spawn_requested` as a 5-field `MonsterSpawnRequest` Resource. `wave-manager.md`'s own Bidirectionality Notes explicitly state this is now a 6-field payload (added 2026-05-20) and that "EventBus GDD `monster_spawn_requested` entry must be updated to show 6 fields before implementation" — a self-flagged, still-open action item never carried through. Monster System's Formula 4 (penultimate-wave ELITE HP amplification) has no valid trigger without this field.

🔴 **Resource Economy's "default mission" gold calibration silently uses r=0.25, not Wave Manager's documented default r=0.20**
`resource-economy.md`'s Formula 5 computes 6-wave per-wave gold grants (20+25+31+39+49+61=225, +150 scout=375) and AC-18 asserts wave 4's `wave_reward_scalar=1.953` — reachable only at r=0.25 (`1.25^3`). `wave-manager.md` repeatedly and explicitly states the canonical default is r=0.20 (safe range 0.15–0.25), and its own "Wave count and total mission economy" tuning note uses r=0.20 consistently. At the actual default r=0.20, wave 4's scalar is 1.728, and the real 6-wave total is 199+150=**349** — just *below* the registry's `tower_placement_budget_target` floor of 350, not comfortably inside it as both docs currently claim. Either `resource-economy.md`'s Formula 5 must be re-derived at r=0.20, or the doc must explicitly state it calibrates against the top of the safe range rather than "default." This feeds directly into the registry value both GDDs claim to satisfy.

🔴 **`monster.md`'s Overview still describes ELITE sub-boss packs as appearing on "Wave 4"**
This directly contradicts the document's own Formula 4 (penultimate-wave-relative, driven by `is_penultimate_wave`, not a hardcoded index) and `game-concept.md`'s own explicit correction note (Core Rule 3: "The ELITE HP amplifier in Monster System GDD F4 applies on the penultimate wave, not a fixed wave 4"). Stale sentence left over from before the wave-4→penultimate-wave generalization; could mislead a content author working on a variable-length (5–8 wave) mission.

### Warnings (should resolve, but won't block)

⚠️ **Final-wave BOSS calibration's "8–15 hits" design target isn't guaranteed at the documented minimum.** `monster.md` Formula 3 only checks `wave=8, base_damage=50` (12 hits ✓). At the earliest legal final-wave point (`wave_index=5, base_damage=40`, both within documented valid ranges), a Tier 4 tower survives 18 hits — well above the stated target. No per-wave `base_damage` sub-range constrains this within the legal authoring space.

⚠️ **`tower.md` Formula 4's prose still cites the stale "~350–400" budget figure** without the wave-count qualifier the Tuning Knobs table (mission_resource_budget row) now carries. A reader hitting Formula 4 before Tuning Knobs gets the pre-revision range.

⚠️ **`resource-economy.md`'s Open Questions table still marks the 7–8-wave budget follow-up "Open,"** though `tower.md`'s Tuning Knobs table already states the ~500–550 figure. Stale to-do.

⚠️ **`damage-status.md`'s Dependencies table still lists Wave Manager and Mission HUD as "Not yet designed."** Both now exist and both independently confirm the `monster_damage_taken` link D&S's own doc asks for. Purely a staleness issue (D&S last touched 2026-05-14, before either GDD existed).

⚠️ **Resource Economy's Save & Persistence dependency isn't reciprocated** in `save-persistence.md`'s Downstream Dependents table (10 systems, `restore_order` 10–33). May be intentional (Resource Economy/`MissionEconomy` is stateless per ADR-0018 and resets every `mission_launched`), but `save-persistence.md` should state this exclusion explicitly rather than leaving the asymmetry unaddressed.

⚠️ **Registry entry `tower_placement_budget_target`'s notes reproduce the same disputed r=0.25 figures** flagged above — will need a matching update once the Formula 5 issue is resolved in `resource-economy.md`, or the fix stops at two GDDs and leaves the registry stale again.

---

## Game Design Issues

### Blocking

🔴 **`damaged_component_repair_cost` (Tower Rule 24) has no defined resource pool to draw from — a sink pointing at nothing.** In-mission gold is explicitly non-persistent (`MissionEconomy` resets every `mission_launched`); `save-persistence.md`'s save-data table lists exactly 10 persisted systems and gold/currency appears in none of them. There is no "Sanctuary gold" concept anywhere in the 15 documents. That leaves materials (persisted via Inventory) as the only plausible currency, but no document confirms materials are what this knob spends, at what quantity, or from which tier. This is the game's only tower-destruction consequence, and it currently debits from a resource category that doesn't structurally exist yet. **Resolve in `resource-economy.md` or a future Crafting GDD**: either declare materials as the repair currency with a concrete formula, or introduce a real persistent Sanctuary currency and add it to `save-persistence.md`'s save-data table.

🔴 **The "difficulty must be opaque" anti-pattern (game-pillars.md, Mastery-as-Vindication) is handled inconsistently across systems that face the identical problem.** Mission HUD's route-preview withdrawal at WAVE_ACTIVE and Tower's partial-info Intermission preview both risk this anti-pattern, and both are self-aware of the risk (Mission HUD flags it explicitly as an unvalidated hypothesis pending playtest). But when the designers hit the *same* category of problem for T4 boss-lane placement (Tower OQ-11), they built a real, shipped fix: the boss-spawn-cell telegraph plus a WAVE_ACTIVE confirmation pulse giving the player an explicit "I was right" moment mid-combat. That pattern was applied narrowly to one case and never generalized to, or reconciled against, the two broader cases it's arguably a solution for. **Resolve before Vertical Slice**: either apply the confirmation-pulse pattern more generally (e.g., a brief "your plan held" signal on a zero-breach wave-clear), or explicitly document why the boss-lane case warranted a fix and the others don't, tying the reasoning back to the pillar's own anti-pattern language.

### Warnings

⚠️ **Tower T3 is DPS/cost- and HP/cost-optimal simultaneously, with no compensating tradeoff.** T1/T2 are explicitly non-viable against bosses specifically (per Tower's own boss-calibration table), making them forced-by-budget rather than strategic past early game. Consider whether T1/T2 need a standalone niche (footprint efficiency, speed/cost tradeoff) or whether the 4-tier model should be accepted as pure budget-gating and potentially simplified.

⚠️ **Crit Chance + Crit Multiplier + Lifesteal form an unchecked mutually-reinforcing stat cluster.** Investing in both buys more damage *and* more healing from the same points, compounding hardest against the hero's highest-value ELITE/BOSS targets — with no diminishing-returns safeguard, unlike Tower Affinity's deliberate sqrt-scaling (explicitly justified there as an anti-degenerate-strategy measure). A pure defensive (Armor+HP) build has no equivalent double-duty payoff. Model this explicitly once Equipment Forge stat-budget tuning begins.

⚠️ **`hero.md` Formula 6 (Lifesteal) is stale relative to `damage-status.md`'s authoritative overkill-cap correction** — uses pre-correction `damage_dealt` instead of D&S's `absorbed` (HP actually removed, capped at target's remaining HP). Update Hero's Formula 6 to reference D&S's Formula D3 as authoritative.

⚠️ **WAVE_ACTIVE's Combat Cluster likely exceeds the 3–4-element attention comfort threshold** — simultaneously: Hero HP bar, 5 cooldown timers, breach counter, boss HP bar plus spawn-confirmation pulse, floating damage numbers, `wave_stalled` warning, PC-3 banner, and an uncapped per-tower HP bar for every tower under boss attack (no hard cap on tower count; boards of 40–60+ towers possible). Consider bounding tower-HP-bar display to towers within the boss's current attack range during boss engagements specifically.

⚠️ **Hero's Tower-Synced Class proximity and the not-yet-designed Tower Mastery proximity track the same player behavior (standing near a tower) with no mechanical or narrative differentiation.** Already self-flagged in Hero's own OQ-7 as an implementation risk ("confirm these are two separate accumulators"), but at the holistic level it's two parallel progression loops competing for the identical player action to unlock two different reward tracks. Differentiate explicitly when Tower Mastery is authored, or merge into one proximity tracker with two unlock outputs.

⚠️ **Pillar-tag reconciliation (flagged 2026-07-10 in game-pillars.md's own Naming Reconciliation Note) is still incomplete 5 days later**, and inconsistent — `damage-status.md`/`hero.md` already use canonical pillar names in their headers; `resource-economy.md`'s header omits Mastery-as-Vindication despite its own Player Fantasy prose invoking it directly ("This is Mastery-as-Vindication in miniature"). Worth batching into one reconciliation pass now that two docs demonstrate the target end-state.

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. Boss-Lane Telegraph Chain (Wave Manager → Mission HUD → Tower, WAVE_ACTIVE spawn-confirmation)
2. Tower Destruction Mid-Wave → Inventory → Save & Persistence (DEFEAT-save ordering)
3. Combat + Economy: Hero Auto-Attack Damage Resolution (Hero → Damage & Status)
4. Progression + Difficulty: Wave-Clear → Next-Wave Spawn Timing (Wave Manager ↔ Tower's cache-clear contract)
5. Mission Restart/Retry (DEFEAT → SCOUT): does it pass through SANCTUARY?

### Blockers

🔴 **Boss-Lane Telegraph confirmation pulse (Mission HUD Rules 11d/11e) can never fire under Wave Manager's own content constraints — Wave Manager, Mission HUD**
Wave Manager Rule 6 requires the final wave's BOSS entry to be the *last* `WaveSpawnEntry`, preceded by one or more standard/elite monsters — guaranteeing the BOSS's `monster_spawned` event fires seconds *after* `mission_phase_changed → WAVE_ACTIVE`, never in the same frame. But Mission HUD's Rule 11e resets `_boss_telegraph_cell` to sentinel at that same phase-transition event, "regardless of cause," and Rule 11d's confirmation pulse is gated on `_boss_telegraph_cell` being non-sentinel at the moment the BOSS actually spawns. By the time that spawn arrives, the cell has already been reset. **This is not a rare race — the confirmation pulse mechanic is structurally dead code as written.** Confirmed by direct trace against this session's own text (both rules added 2026-07-15, in the same session as this review). Must fix before implementation: defer the defensive reset off `mission_phase_changed → WAVE_ACTIVE` — likely to `wave_completed` instead, so it still clears before the next Intermission's preview arrives but doesn't wipe the pending pulse before it can fire during the current wave.

🔴 **Tower destruction → Inventory → Save & Persistence: DEFEAT-save ordering hazard is still unresolved — Tower System, Inventory, Save & Persistence**
`tower.md`'s own Edge Cases (DEFEAT section) explicitly document this gap and state it requires a `save-persistence.md` update Tower "cannot enforce unilaterally." Confirmed via full read of `save-persistence.md`: it has not been updated — Rule 4's trigger table still fires the post-mission save on `mission_phase_changed(DEFEAT)` with no mention of `tower_component_returned`, and grep confirms zero matches for that event name anywhere in the document. Since EventBus dispatch ordering among same-event subscribers isn't otherwise specified, a save handler that fires before Tower's DEFEAT-triggered component-return flow will serialize Inventory state missing the pending components from destroyed towers — violating both Core Rule 11 ("Sanctuary progress always persists") and Tower's own "DEFEAT does not forfeit components" guarantee. This is a confirmed, previously-flagged, still-open gap — not a hypothetical.

🔴 **`game-concept.md` and `save-persistence.md` disagree on what DEFEAT transitions into — Game Concept, Save & Persistence, Wave Manager**
`game-concept.md`'s canonical States/Transitions table gives DEFEAT's exit as a direct "Restart mission from SCOUT" with no Sanctuary hop named; Wave Manager's EC-9 matches this (resets straight to IDLE awaiting a fresh `mission_launched`). But `save-persistence.md` Rule 9 ("Load and restore sequence") is scoped and titled as "on game start or **on DEFEAT returning to Sanctuary**," assuming a full disk-read + 10-system `restore_save_data()` reload sequence. These are incompatible models of the same transition: an in-place retry that never revisits Sanctuary, or a return-to-hub-then-reload flow neither `game-concept.md`'s state table nor Wave Manager's EC-9 account for. Neither document's rules cover the combined state as currently written — needs explicit reconciliation.

### Warnings

⚠️ **Hero's Formula 4 duplicates D&S's Formula D2 — a real double-multiplication risk, not flagged as superseded — Hero System, Damage & Status**
`damage-status.md` Rule III is explicit: Hero emits only raw `base_damage`/`is_crit`/`crit_multiplier_effective`/`hero_bonus_tier`; D&S alone applies tier-bonus and crit multipliers. But `hero.md`'s own Formula 4 independently computes a fully-resolved `final_damage` that already includes both multipliers, with a full worked example, and is never marked deprecated or superseded (unlike other legacy fields correctly flagged elsewhere in the project). An implementer building directly from `hero.md` risks applying both multipliers twice. Recommend retitling/annotating Formula 4 as superseded by D&S's D2, retaining only the sub-formulas Hero still genuinely owns.

⚠️ **Wave Manager's frame-yield contract (which Tower depends on) is undocumented in `wave-manager.md` itself — Wave Manager, Tower System**
`tower.md` states a binding cross-system mandate ("Wave Manager must yield at least one frame between `wave_completed` and the next `wave_started`") and says explicitly this must be documented in Wave Manager's GDD. Grep confirms no such statement exists in `wave-manager.md`. The current state machine likely satisfies this incidentally (INTERMISSION + PRE_WAVE both require at least one timer/input event between the two emissions), but this is emergent, not contractual — a future phase-skip change could silently violate it with nothing to catch the regression.

⚠️ ~~**"Tower placement has no gold debit event"**~~ — **Corrected during synthesis**: this was already resolved earlier in this session — `tower.md` Rule 9 emits `resources_changed(-placement_cost, "tower_placement")` before `tower_placed`, closing OQ-10 (Revision 12, 2026-07-14). The scenario-walkthrough finding was based on stale text in `resource-economy.md`'s own Open Questions section that was never updated to match Tower's fix. Downgraded to a documentation-sync note — see the matching Consistency-section warning about `resource-economy.md`'s stale OQs.

### Info

ℹ️ **Boss death/breach chain (Monster, Wave Manager, Tower, Mission HUD, Resource Economy)** — no new issues found beyond the telegraph bug above. The `boss_died`/`monster_breached(tier==2)` fast-paths, Monster's force-removal-forfeits-drops rule, and Mission HUD's `_boss_state` null-guards compose correctly across all four documents — clearly the most cross-reviewed chain in the project already.

ℹ️ **Resource Economy's 8-wave gold-budget overshoot** — already tracked as an open follow-up in both `resource-economy.md` and `systems-index.md`; a known tuning gap, not a new structural issue.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `event-bus.md` | Missing `boss_spawn_cell` and `is_penultimate_wave` in canonical catalogue | Consistency | Blocking |
| `resource-economy.md` | r=0.20/r=0.25 calibration mismatch; 2 stale Open Questions | Consistency | Blocking |
| `monster.md` | Stale "Wave 4" ELITE reference | Consistency | Blocking |
| `mission-hud.md` | Boss-telegraph confirmation pulse structurally dead (Rules 11d/11e) | Scenario | Blocking |
| `save-persistence.md` | DEFEAT-save ordering vs. Tower unresolved; DEFEAT-transition model conflicts with game-concept.md | Scenario | Blocking |
| `game-concept.md` | DEFEAT-transition model conflicts with save-persistence.md | Scenario | Blocking |
| `tower.md` | Repair-cost sink points at no resource pool; stale Formula 4 budget prose | Design Theory / Consistency | Blocking + Warning |
| `hero.md` | Formula 4 double-multiplication risk vs. D&S; Formula 6 stale lifesteal basis; undifferentiated proximity vs. Tower Mastery | Design Theory / Scenario | Warning |
| `damage-status.md` | Stale Dependencies table | Consistency | Warning |
| `wave-manager.md` | Undocumented frame-yield contract Tower depends on | Scenario | Warning |

---

## Verdict: FAIL

Blocking issues span all three review lenses. The most urgent is the Mission HUD boss-telegraph bug (dead code shipped this same session); the DEFEAT/Sanctuary state-model conflict and the repair-cost economic gap are the most structurally significant for downstream architecture planning.

### Required actions before re-running

1. Fix `mission-hud.md` Rules 11d/11e — defer the defensive `_boss_telegraph_cell` reset off `WAVE_ACTIVE` entry, likely to `wave_completed` instead.
2. Add `boss_spawn_cell` and `is_penultimate_wave` to `event-bus.md`'s catalogue.
3. Reconcile `resource-economy.md`'s Formula 5 against Wave Manager's actual r=0.20 default (or explicitly document it as calibrating against the r=0.25 ceiling).
4. Fix `monster.md`'s stale "Wave 4" Overview text.
5. Reconcile `game-concept.md` and `save-persistence.md` on the DEFEAT transition model.
6. Resolve the DEFEAT-save ordering hazard in `save-persistence.md` per Tower's own flagged requirement.
7. Define what resource `damaged_component_repair_cost` actually spends.

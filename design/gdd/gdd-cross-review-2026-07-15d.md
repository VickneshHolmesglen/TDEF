# Cross-GDD Review Report

Date: 2026-07-15
GDDs Reviewed: 15 (game-concept.md, game-pillars.md, systems-index.md + 12 system GDDs)
Systems Covered: EventBus, Grid, Save & Persistence, Hero, Tower, Monster, Damage & Status, Pathfinding, Inventory, Resource Economy, Wave Manager, Mission HUD

This is the 4th consecutive `/review-all-gdds` pass this session, run to verify the fix
chain from passes 1-3 (`gdd-cross-review-2026-07-15.md`, `-15b.md`, `-15c.md`) plus the
"final open-item sweep" session-state entry. All prior fixes were spot-checked and hold.
Three parallel specialist passes (Consistency, Game Design Holism, Cross-System Scenario
Walkthrough) each found genuinely new items — diminishing but non-zero returns, as
expected after three prior clean-verification passes.

---

### Consistency Issues

#### Blocking (must resolve before architecture begins)

🔴 **monster.md Rule 6 spawn payload is self-contradicting (propagation debt)**
`design/gdd/monster.md` Group 2 "Spawn Behavior," Rule 6 still declares the
`monster_spawn_requested` payload as 5 fields (`monster_id`, `spawn_cell`, `wave_index`,
`difficulty_tier`, `wave_reward_scalar`), omitting `is_penultimate_wave: bool` — but this
same document's own Formula 4 reads `is_penultimate_wave` from that exact payload two
paragraphs later, and both `wave-manager.md` (Rule 15c, AC-12) and `event-bus.md`'s
catalogue (fixed in pass 2 of this session) agree it's 6 fields. When the EventBus fix
propagated to `wave-manager.md`, `monster.md`'s own Rule 6 text was missed.

🔴 **pathfinding.md Formula F2 prose contradicts grid-system.md and wave-manager.md's own test fixtures**
`design/gdd/pathfinding.md` Formula F2 states: *"at MVP (N=1) ties never occur"* and
*"At MVP, N = 1, so all assignments equal the single SPAWN cell coordinate."* This
contradicts `grid-system.md` EC-8 (maps may have multiple entry points, no MVP
qualifier) and `wave-manager.md`, which builds round-robin spawn distribution
(Rule 15b), modulo-wrap logic (EC-7), and AC-10 (explicitly tests a 3-spawn-cell map
`[A, B, C]` as ordinary content, not an edge case). The F2 algorithm itself is
N-agnostic and correct — only the prose commentary is wrong — but as written it could
mislead an implementer into skipping multi-spawn-cell path-template testing that Wave
Manager's own acceptance suite assumes is standard MVP content.

#### Warnings

None new this pass beyond the design-theory and scenario items below.

---

### Game Design Issues

#### Blocking

🔴 **Intermission wave preview's "archetype bucketing" has no data source anywhere in the GDD set**
`tower.md` Rule 8 mandates Mission HUD aggregate the Intermission `wave_preview_available`
payload into monster archetype category buckets (its own example: *"12 monsters: 4
Physical, 8 Ranged"*), explicitly forbidding exact `monster_id` display for waves 2-8 —
this partial-information model is load-bearing design intent, serving the "difficulty
must not be opaque" anti-pattern test from game-pillars.md. It cannot be built as
specified: (1) `monster.md`'s `MonsterResource` schema has no Physical/Ranged/
Elemental/Support archetype field — its only classification fields are `tier`
(STANDARD/ELITE/BOSS) and a single-value `archetype_tag` (`&"armored"` or empty);
(2) the `WaveCompositionEntry` Resource (`event-bus.md`'s `wave_preview_available`
payload, `wave-manager.md` Rule 11) carries only `monster_id` and `count` — no
archetype field of any kind; (3) `mission-hud.md`'s Group 3b (added this session)
implements only the boss-lane marker half of Rule 8 — grep finds zero references to
"archetype" or bucketing logic anywhere in the document. Three GDDs each independently
reference this mechanism (Tower mandates it, Wave Manager emits the event it depends
on, Mission HUD was told to consume it) but none defines the archetype-per-monster
data that would make it renderable. Invisible to any single-document review since the
gap is the *absence* of a field in a fourth location none of the three cross-checked.

#### Warnings

⚠️ **Difficulty curve consistency (monster/tower/hero) is currently unverifiable**
Monster HP/speed/boss-damage scaling and Tower cost/DPS scaling are both fully
numeric across waves 1-8. Hero base stats (HP, damage, movement speed, attack range)
are explicitly `(TBD at production)` in `hero.md`'s Tuning Knobs. Since the hero is
structurally mandatory for elite/boss kills (`game-concept.md` Core Rule 1) and boss
tower-survival math implicitly assumes some hero DPS contribution, a full three-way
scaling-compatibility check cannot be performed until hero base stats exist. Not a
defect — recorded as a gate item before Vertical Slice balance passes begin.

---

### Cross-System Scenario Issues

Scenarios walked: 4 — (1) Hero killing-blow lifesteal healing racing the hero's own
death; (2) DEFEAT → Tower destruction → Inventory → Save (re-verification);
(3) Boss-lane telegraph chain (re-verification); (4) Tower destruction mid-wave →
component repair-flag → Inventory → HUD surfacing.

#### Warnings

⚠️ **Hero's own lifesteal heal can arrive after `hero_died`, with no guard anywhere — same bug class as the previously-fixed monster.md Rule 21f issue**
Chain: Hero lands a lifesteal hit → D&S registers `_lifesteal_pending[target_id]`
(Rule III.6) → defers `monster_damage_taken` one frame → Monster System flushes
`monster_hp_absorbed` synchronously → D&S Rule VI fires `hero_healed` synchronously,
1-2 frames after the original attack — with no check anywhere on whether the hero is
still alive. A boss hit can kill the hero in the same or an intervening frame via a
parallel, independently-deferred chain (`hero_incoming_damage` → D&S Rule V, deferred
1 frame → `hero_damage_taken` → Hero Rule 24 triggers `hero_died`/DEFEAT immediately).
D&S's only cleanup for `_lifesteal_pending` is on `wave_completed` (Rule VII) — and
Wave Manager's DEFEAT transition never emits `wave_completed`. So a `hero_healed`
event tied to a hit landed just before death can arrive after `hero_died` has already
fired; neither `hero.md` nor `damage-status.md` specifies what happens to a heal
received on a `DEAD` hero. Per hero.md's own Visual/Audio table, a healing tick plays
a green flash and may fade the low-HP vignette — directly contradicting the death
sequence's "screen desaturates, vignette freezes at max opacity" if both fire in
overlapping frames. Recommend: D&S clears `_lifesteal_pending` (or Hero no-ops
`hero_healed` receipt) on `hero_died`.

#### Info

ℹ️ **DEFEAT → Tower destruction → Inventory → Save ordering: confirmed clean** (re-verification, not a new finding — prior fix holds)

ℹ️ **Boss-lane telegraph chain: confirmed clean** (re-verification, not a new finding — prior fix holds)

ℹ️ **tower.md OQ-2 is stale and can be closed** — it asks Hero to "also subscribe to
`tower_removed`" for Tower Affinity, but hero.md's Interactions table already lists
`tower_removed` as subscribed. Cheap propagation-debt cleanup, not a defect.

---

### GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| monster.md | Rule 6 spawn payload missing `is_penultimate_wave` field | Consistency | Blocking |
| pathfinding.md | Formula F2 prose contradicts multi-spawn-cell MVP content in grid-system.md/wave-manager.md | Consistency | Blocking |
| tower.md | Rule 8 archetype-bucketing requirement has no supporting data model anywhere; OQ-2 stale | Design Theory | Blocking / Info |
| mission-hud.md | Group 3b never implements Rule 8's composition-bucketing half | Design Theory | Blocking (dependent on tower.md/monster.md resolution) |
| hero.md | No cleanup hook for `_lifesteal_pending` on `hero_died` | Scenario | Warning |
| damage-status.md | Same — Rule VII cleanup scoped only to `wave_completed`, not `hero_died` | Scenario | Warning |
| hero.md | Base stats still TBD — blocks full difficulty-curve verification | Design Theory | Warning (gate item) |

---

### Verdict: FAIL

Two new blocking consistency items (both narrow, single-paragraph propagation-debt
fixes) plus one new blocking design-theory item (a genuine data-model gap spanning
three documents, needs a real design decision — not a text fix). Diminishing but
non-zero returns continue: this is the 4th pass to find genuine defects, though the
defect count per pass has been shrinking (7 blockers → 6 → 6 → 3 new this pass).

### If FAIL — required actions before re-running:
1. Add `is_penultimate_wave: bool` to monster.md Rule 6's payload field list (6th field, matching Formula 4/wave-manager.md/event-bus.md). **DONE 2026-07-15d.**
2. Correct pathfinding.md Formula F2's prose to acknowledge multi-SPAWN-cell maps are ordinary MVP content, not a future-only case. **DONE 2026-07-15d, then REVERTED as incorrect — see Pass 2 addendum below.**
3. Resolve the archetype-bucketing data gap: either add an archetype/category field to `MonsterResource` and `WaveCompositionEntry`, or redefine tower.md Rule 8's aggregation dimension to something the game actually has data for (e.g., tier-only bucketing). **DONE 2026-07-15d** — rescoped to tier bucketing via `GameDataRegistry.get_monster().tier`.
4. Close tower.md's stale OQ-2. **DONE 2026-07-15d.**
5. Decide and apply a fix for the hero-death/lifesteal-heal race (D&S clears `_lifesteal_pending` on `hero_died`, or Hero no-ops a `hero_healed` receipt while `DEAD`). **DONE 2026-07-15d** — D&S Rule VIII, per user decision.

---

## Addendum — 5th `/review-all-gdds` pass (2026-07-15d, same day)

Ran to verify the 5 fixes above landed correctly. 3 parallel specialist passes (Consistency, Design Theory, Cross-System Scenario Walkthrough).

### Consistency — verification results
- Fix 1 (monster.md Rule 6): ✅ landed correctly, no contradiction remains.
- Fix 2 (pathfinding.md Formula F2): 🔴 **landed incompletely, and in the wrong direction.** The prose fix was correct in isolation, but pathfinding.md's own `Tuning Knobs → Mandatory constraints` section contains a **deliberate, CI-enforced gate (`AC-13d`)** blocking any mission map with 2+ SPAWN cells from shipping at MVP — the nearest-SPAWN Chebyshev algorithm is documented (code-spec TODO, Rule 1) as producing incorrect assignment near walls between SPAWNs, with a reverse-Dijkstra fix deferred to post-MVP. The Formula F2 fix (allowing multi-SPAWN) directly contradicted this pre-existing gate. **Root cause**: wave-manager.md's AC-10 test fixture (a 3-spawn-cell map) was the actually-wrong document — it conflated "Wave Manager's round-robin spawn-selection code is written correctly for arbitrary N" (true, and a legitimate unit test) with "multi-SPAWN maps are MVP-shippable content" (false, blocked by AC-13d).
- No other new consistency issues found.

**User decision**: reverted pathfinding.md's Formula F2 prose to the original single-SPAWN-at-MVP framing (with a clearer explanation this time); added a scope note to wave-manager.md's AC-10 distinguishing code-correctness-for-arbitrary-N from content-shippability; added an informational cross-reference to grid-system.md's EC-8 (no contract change — Grid's own API is genuinely spawn-count-agnostic, only Pathfinding's current implementation restricts N=1).

### Design Theory — verification results
- tower.md Rule 8 tier-bucketing rescope: ✅ mechanically correct and consistent across tower.md/wave-manager.md/mission-hud.md. Sanity-checked as a legitimate design substitution (tier maps onto Tower's own DPS-tradeoff system), though narrower than the original intent — it silently drops two other real tactical axes (`archetype_tag="armored"` mitigation, `base_speed` variance) that don't appear in a tier-only bucket. **Not blocking**, flagged as a scope-narrowing tradeoff worth a deliberate look before Vertical Slice, not re-opened this pass.
- 🔴 **New blocking finding**: mission-hud.md's new Group 3c (added this session, not present at the time of the original -15d report) silently reinterpreted tower.md Rule 8's explicit text — Rule 8 states SCOUT's Wave 1 preview delivers "full composition... complete information," contrasted deliberately against Intermission's partial tier-only read, but Group 3c's original draft rendered the identical tier-bucketed view at both phases, collapsing the asymmetry the Player Fantasy section is built around.

**User decision**: implement tower.md's actual stated intent. mission-hud.md's Group 3c split into Rule 11f (INTERMISSION, tier-bucketed) and Rule 11g (SCOUT, full per-`monster_id` list via `display_name` — no new schema needed, `composition` already carries `monster_id`); new AC added.

### Cross-System Scenario Walkthrough — verification results
Re-traced the Rule VIII fix (D&S clears `_lifesteal_pending` synchronously on `hero_died`) against the actual engine-loop timing model (event-bus.md Core Rules, monster.md's physics-tied absorbed-flush, D&S's idle-tied `process_frame` defer). **Confirmed the fix is structurally sound** — Monster's flush is pinned to `_physics_process`, D&S's dispatch defer is idle/process-tied, and Godot always runs pending physics ticks before the idle step in a frame, so there is no interleaving where a pending `monster_hp_absorbed` can reach D&S's Rule VI handler between `hero_died` firing and Rule VIII's synchronous clear.

Two **non-blocking** items surfaced, not yet acted on (deferred — see session-state for the pending decision):
- ⚠️ This correctness guarantee is emergent from an undocumented dependency (physics-before-idle ordering, plus D&S's specific choice of `await get_tree().process_frame` over `call_deferred`) — no GDD states *why* Rule VIII wins the race. A future refactor of either mechanism could silently break it.
- ⚠️ No downstream defense-in-depth exists — Hero System's `hero_healed` handler and Mission HUD both apply/display the heal unconditionally, relying entirely on D&S never emitting a stale event.

No other new scenario issues found; DEFEAT→save→Sanctuary reload and monster-death→drop→HUD chains re-verified clean.

### Verdict: FAIL → all findings resolved same-day (2 blocking: pathfinding/wave-manager correction, mission-hud SCOUT fix)
Diminishing-but-real returns continuing (blocker count: 7 → 6 → 6 → 3 → 2 new this pass, though pass 2's finding was itself a correction of pass 1's own overcorrection — a reminder that speed without re-verification compounds errors). The 2 non-blocking scenario items (undocumented timing dependency, no downstream guard) remain open pending a user decision on whether to act on them.

---

## Addendum 2 — 6th `/review-all-gdds` pass (2026-07-15d, same day)

Ran to verify the 2 non-blocking scenario items were fixed (Rule VIII.6 timing-dependency note, hero.md defensive guard + AC-15) and to check for any remaining defects. 3 parallel specialist passes.

### Consistency — verification + 1 new finding
All 5 items carried over from the 5th pass verified correct: pathfinding.md's F2 revert, wave-manager.md's AC-10 scope note, grid-system.md's EC-8 cross-reference, damage-status.md's Rule VIII.6, hero.md's DEAD guard + AC-15.

⚠️ **New warning**: tower.md's OQ-2 (closed 2026-07-15d) left two sibling stale duplicates of the same claim untouched — the Dependencies table's Hero System row (line 681) and the Bidirectional-flags list (line 695) both still asserted "Hero GDD must add subscription to `tower_removed`" after OQ-2 itself had already been resolved to say the opposite. Cosmetic self-contradiction within tower.md only — hero.md was never wrong. **Fixed same-day**: both instances corrected to reference OQ-2's resolution.

### Design Theory — verification + 1 new finding
mission-hud.md's Rule 11f/11g SCOUT/Intermission split confirmed correctly matches tower.md Rule 8's asymmetry intent.

🔴 **New blocking finding**: wave-manager.md's own Rule 8 (SCOUT Wave-1-preview emission), never touched by the 5th-pass fix, still asserted Mission HUD shows "the same composition display" at SCOUT as at INTERMISSION — directly contradicting the asymmetry the 5th-pass fix just implemented (mission-hud.md's Rule 11g renders a deliberately *different*, fuller view at SCOUT). Same propagation-debt class as prior passes: a downstream doc's connective text not updated when an upstream rule changed. **Fixed same-day**: reworded to state the two phases share UI placement but not content, with a cross-reference to the actual asymmetry rules.

### Cross-System Scenario Walkthrough — verification, no new findings
Rule VIII.6 and hero.md's DEAD guard both confirmed present, correct, and cross-referenced consistently across damage-status.md, hero.md, and event-bus.md — this fix is fully closed. Walked 2 fresh scenarios (SCOUT composition display vs. tower-placement invalidation; DEFEAT→retry→new-mission gold/inventory interaction) — both clean, no gap exists structurally in either case (composition renders once per phase entry with no mid-phase re-fire to race against; gold and inventory persistence are already fully decoupled from the DEFEAT-save ordering fix closed in earlier passes). **First pass this session with zero findings across all three lenses on the material actually reviewed** (its two findings were in the Consistency and Design Theory passes, not here).

### Verdict: CONCERNS → both findings resolved same-day
Both new items were narrow, single-location propagation-debt fixes (not new design decisions) — continues the shrinking trend (7 → 6 → 6 → 3 → 2 → 2 this pass, but this pass's scenario lens alone came back clean for the first time). Recommend closing the review cycle here per the scenario pass's own assessment: "the well is dry... consistent with genuine convergence rather than under-scoping."

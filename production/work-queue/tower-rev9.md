# Tower System GDD — Rev 9 Work Queue
> Source: Review 8 (2026-05-10). Verdict: MAJOR REVISION NEEDED. 18 blockers.
> Files to edit: `design/gdd/tower.md`, `design/gdd/event-bus.md`

---

## STEP 0 — Design Decisions (resolve BEFORE editing files)

Three decisions that the user must make. All others are mechanical fixes.

### D1 — SCATTER targeting fix path
**Problem:** SCATTER selects a random new target each attack cycle — "the tower does not improvise" but SCATTER improvises by definition. Player has no validation surface.
**Options:**
- **D1-A:** Make SCATTER deterministic on a player-legible rule (e.g., "cycles through targets in spawn order, advancing one target per attack cycle"). Preserves variety; restores authorship.
- **D1-B:** Keep random SCATTER but expose per-target hit counts in `tower_wave_summary` (e.g., add `scatter_target_hits: Dictionary` mapping entity_id → hit count). Player can see DoT distribution post-wave.
- **D1-C:** Cut SCATTER from MVP. Reduce Focus targeting modes to 4.

### D2 — Intermission wave preview scope
**Problem:** Full wave composition preview each Intermission converts placement to reactive optimization ("see threat, place counter"), undermining authorship after Wave 1.
**Options:**
- **D2-A:** Keep full preview (current spec). Accept that authorship applies to Scout Phase; Intermissions are informed reaction. Simplest.
- **D2-B:** Partial preview — show archetype mix and total count, NOT individual monster types or spawn order. Player still reads the meta; game doesn't hand them the answer.
- **D2-C:** No Intermission preview. Blind building after Wave 1. (Not recommended — this was the problem the preview was added to solve.)

### D3 — T1/T2 tier differentiation
**Problem:** T3 has best DPS/cost ratio (1.20) with no efficiency advantage for T1 (1.00) or T2 (1.07) at any budget. T1/T2 are pure budget fallbacks with no strategic identity.
**Options:**
- **D3-A:** Accept T1/T2 as intentional budget-gating with no strategic differentiation. Document explicitly in GDD. No changes to balance.
- **D3-B:** Give T1 a mechanical niche (e.g., lowest stagger offset → fires first in any wave, useful for kill-steal wave openers). Give T2 a niche (e.g., cheapest per-cell footprint for dense grid coverage).
- **D3-C:** Add a "count bonus" rule: builds with 6+ T1 towers gain a small global efficiency bonus. Rewards flooding low-tier towers.

---

## STEP 1 — Correctness Bugs (5 items, no design decisions needed)

### B1 — `design/gdd/tower.md` Rule 14a — DEFEAT→SCOUT cache not cleared
**Location:** Rule 14a, "Mission-start cache clear" paragraph.
**Bug:** Current condition: `previous_phase ∉ {SCOUT, WAVE_ACTIVE, INTERMISSION, OUTCOME, DEFEAT}`. DEFEAT is in the exclusion set → DEFEAT→SCOUT restart does NOT clear the cache.
**Fix:** Change the clear trigger to: "Clear `_monster_cache` when `mission_phase_changed` fires with `new_phase = SCOUT` AND (`previous_phase ∉ {SCOUT, WAVE_ACTIVE, INTERMISSION, OUTCOME}` OR `previous_phase = DEFEAT`)". In other words: SCOUT entry from DEFEAT must also clear. Update the note text accordingly.
**Also update:** The subscription mode table note for `mission_phase_changed` to mention DEFEAT→SCOUT explicitly.

### B2 — `design/gdd/tower.md` Rule 14a — HOMING ghost-flight (one-frame stale position)
**Location:** Rule 14a, `monster_died` subscription row + Rule 19 HOMING re-acquisition.
**Bug:** `monster_died` is CONNECT_DEFERRED (evicts cache at end-of-frame). HOMING projectile polling mid-frame sees dead target as alive for one frame.
**Fix:** Add to Rule 19 HOMING re-acquisition spec: "On each polling frame, before reading the target's position from `_monster_cache`, HOMING checks a frame-synchronous `_died_this_frame: Dictionary[int, bool]` set maintained by the Tower System. This set is populated synchronously on `monster_died` (separate synchronous handler, distinct from the DEFERRED cache-eviction handler), and cleared at the start of each frame. If `_died_this_frame.has(target_id)`, the projectile treats the target as dead and triggers re-acquisition immediately, even though the cache entry still exists mid-frame." If this complexity is unacceptable, alternatively: add a note accepting this as a one-frame approximation and marking it as a known limitation in Rule 19.

### B3 — `design/gdd/tower.md` Rule 14a — SPAWN_ORDER cold-frame miss
**Location:** Rule 14a subscription table, `monster_spawned` row.
**Bug:** `monster_spawned` is CONNECT_DEFERRED → cache entry doesn't exist until end-of-frame. On spawn frame, SPAWN_ORDER targeting misses new monster if it has the lowest entity_id.
**Fix (Option A — preferred):** Change `monster_spawned` subscription to Synchronous (add rationale: "Cache write must be visible to targeting within the same frame as the spawn event to prevent SPAWN_ORDER blindspot on first spawn of each wave."). Update the rationale column in the table from "Cache write must trail other handlers" to "Synchronous to prevent SPAWN_ORDER targeting blindspot on wave's first spawn frame."
**Fix (Option B — accept gap):** Keep DEFERRED and add a note: "SPAWN_ORDER has a one-frame blindspot for newly-spawned monsters: if wave's first monster has entity_id=0, SPAWN_ORDER targeting will not see it until the frame after spawn. The tower will target the next-lowest entity_id that wave. This is an accepted approximation — document in Edge Cases."

### B4 — Pool undersizing — input anchor wrong
**Location:** Rule 19, Projectile pooling note.
**Bug:** Pool formula uses `max_active_towers × max_attack_speed × flight_time × 3.0` but anchors `max_active_towers = 20`. Grid allows 40–60+ towers. At 50 towers, formula demands 300 slots vs. 128 specified.
**Fix:** Either (a) add a hard tower cap per mission (e.g., 32) and recalculate: `ceil(32 × 4.0 × 0.5 × 3.0) = 192` — update pool size to 192; OR (b) state explicitly: "Pool size must be recalculated when the maximum active tower count is finalized. Formula: `ceil(max_active_towers × max_attack_speed × base_flight_time_sec × 3.0)`. Current default of 128 assumes max_active_towers ≤ 21. Content designers must not allow more than 21 simultaneous HOMING towers without updating this pool size." In either case, register `max_active_towers_homing` as a tuning knob in the Tuning Knobs table.

### B5 — HOMING re-acquisition unbounded
**Location:** Rule 19, HOMING re-acquisition architecture note.
**Bug:** No frame budget for re-acquisition callbacks. At 128 concurrent HOMING projectiles losing the same target: 128 × O(M) cache lookups in one frame.
**Fix:** Add to Rule 19: "Re-acquisition is rate-limited to `max_reacquisitions_per_frame = 8` callbacks processed per frame. Projectiles that did not re-acquire this frame retry on the next frame. Order: oldest in-flight projectiles get priority. This constant is a Tuning Knob (see Tuning Knobs table)." Add `max_reacquisitions_per_frame` to Tuning Knobs table with value=8, safe range [4, 32].

---

## STEP 2 — EventBus Cross-Doc Updates (3 items, edit both files)

### E1 — `boss_tower_attack_attempted` missing `is_siege: bool`
**Files:** `design/gdd/event-bus.md` Monster System section.
**Fix:** Update EventBus entry for `boss_tower_attack_attempted`:
- Old payload: `boss_entity_id: int`, `target_tower_id: int`, `base_damage: float`, `wave_id: int`
- New payload: `boss_entity_id: int`, `target_tower_id: int`, `base_damage: float`, `wave_id: int`, `is_siege: bool`
- Note: 5 fields → per Core Rule 4, this must be promoted to a Resource subclass. Either (a) promote to `BossTowerAttackEvent` Resource or (b) verify that 4 were already typed params and add the 5th as named single param using a Resource.
- **In tower.md:** Rule 14a subscription table, `boss_tower_attack_attempted` row already says Synchronous. The Interactions table and OQ-1 already reference `is_siege` as resolved. No change needed in tower.md beyond confirming EventBus updated.

### E2 — `tower_wave_summary` payload mismatch
**Files:** `design/gdd/event-bus.md` Tower System section + `design/gdd/tower.md` Rule 23.
**Canonical payload (Tower GDD Rule 23 is authoritative):**
`TowerWaveSummary` Resource fields:
- `tower_id: int`
- `max_hp: float`
- `shots_fired: int`
- `damage_dealt: float`
- `idle_ticks: int`
- `aura_applications_this_wave: int`
**Fix EventBus:** Replace current EventBus entry (which has `wave_id` and `hp_remaining` instead of `idle_ticks` and `aura_applications_this_wave`) with the canonical 6-field list above.
**Fix tower.md Rule 23:** Confirm the payload table matches. If `wave_id` and `hp_remaining` were intentional, add them back to Rule 23 with justification. Decision: tower.md Rule 23 is authoritative. Drop `wave_id` and `hp_remaining` from EventBus.

### E3 — `monster_spawned` needs `hp_max: float` (5th field)
**Files:** `design/gdd/event-bus.md` Monster System section.
**Current:** `entity_id: int`, `monster_id: StringName`, `wave_index: int`, `grid_position: Vector2i` (4 fields = typed params OK)
**Required:** add `hp_max: float` → 5 fields → **must promote to Resource subclass** per Core Rule 4.
**Fix:** Create `MonsterSpawnedEvent` Resource with fields: `{entity_id, monster_id, wave_index, grid_position, hp_max}`. Update EventBus catalogue entry. Note impact: any subscriber that currently reads `monster_spawned` with typed-param destructuring (Pathfinding, Wave Manager, Mission HUD per EventBus GDD) must be updated to read from the Resource. Document in the EventBus entry's Key Subscribers column.

---

## STEP 3 — Spec/Formula Issues (3 items)

### S1 — Rule 12 / Formula 2: attack_range_cells=8 narrow-cone dead zone
**Location:** Formula 2 notes + Edge Cases (Formula Boundary section).
**Fix:** Add to Formula 2 output range note: "**Cap interaction at maximum range:** A tower with `attack_range_cells=8` and `cone_half_angle < 45°` receives `cone_range_bonus=+2` for a theoretical `effective_range=10`, which is immediately capped at 9. This is identical to `attack_range_cells=7` with the same cone. The 8th range cell is effectively a wasted stat point in narrow-cone configurations. RANGE_BOOST perk (+1 or +2 cells) would similarly be nullified by this cap at `attack_range_cells=8`. Content designers: do not pair `attack_range_cells=8` with narrow cones (`cone_half_angle < 45°`) — use 7 instead."
**Also add** to Edge Cases (Formula Boundary): "If a RANGE_BOOST perk would push effective_range above 9: the cap applies. A tower at attack_range_cells=8 with RANGE_BOOST perk_power=0.25 (+2 cells) still fires at effective_range=9. The perk benefit is partially wasted."

### S2 — Rule 13: Sell refund minimum floor wrong post-MVP
**Location:** Rule 13, "Sell refund formula" paragraph.
**Fix:** Change: "Minimum refund: `round(10 × 0.4) = 4` build points."
To: "Minimum refund at MVP (all archetypes cost_factor=1.0): `round(10 × 1.0 × 0.4) = 4` build points. Post-MVP minimum (if `archetype_cost_factor` reaches 0.5): `round(10 × 0.5 × 0.4) = round(2.0) = 2` build points. No floor clamp is applied — the formula output is the refund."

### S3 — AC (SCATTER chi-squared): correct sigma label
**Location:** Acceptance Criteria, SCATTER distribution AC.
**Fix:** Change "a 2-sigma window at n=1000" to "a ~3.35-sigma permissive window at n=1000 (true 2-sigma would be [303, 363] at σ=14.9; the ±15% bounds are intentionally loose for content-validation purposes to avoid false failures in automated runs)."

---

## STEP 4 — AC Test Design Rewrites (4 items)

### A1 — AC #12: Rewrite grep AC as behavioral test
**Location:** Acceptance Criteria, AC about `is_instance_valid` prohibition.
**Fix — replace with:** "**[Logic — BLOCKING]** GIVEN a HOMING projectile is in flight at the moment its originating tower's HP reaches 0, AND the target also dies simultaneously, WHEN both events resolve, THEN the projectile dissipates without dealing damage and without calling any method on the freed tower node — verified by confirming no `tower_attacked` event fires after destruction and no GUT null-access error is raised."
**Additionally add to Rule 19:** "The `_is_destroyed` flag provides a frame-synchronous alternative to `is_instance_valid()` for tower-death detection. `is_instance_valid()` is not prohibited outright — it is superseded by `_is_destroyed` for this specific case. Implementation should use `_is_destroyed` for tower-death detection in the re-acquisition callback."

### A2 — AC #5: Fix conditional HP-reset test
**Location:** Acceptance Criteria, HP reset AC.
**Fix:** Replace "AND the next `tower_damaged` event for that tower (if a boss attacks in the next wave) shows current_hp consistent with starting from full HP" with: "AND WHEN a synthetic `boss_tower_attack_attempted` event is injected in wave N+1 with `target_tower_id` matching this tower and `base_damage = 1.0`, THEN the resulting `tower_damaged` event shows `current_hp = max_hp - 1.0`, confirming the HP reset occurred before the injected attack."

### A3 — AC #14: Add test instrument prerequisite
**Location:** Acceptance Criteria, EventBus batch threshold AC.
**Fix:** Add prerequisite note at the start of this AC: "**Prerequisite:** (a) `eventbus_batch_threshold` must be registered as a constant in `entities.yaml` before this AC is sprint-assignable. (b) GUT test must use injected fixed delta (`_process(1.0 / 60.0)`) to simulate one frame, and a GUT EventBusSpy must count emissions between `_process()` calls. Do not assign to a sprint until EventBusSpy and the constant are confirmed in the codebase."

### A4 — AC #15: Rewrite illegal-state fixture
**Location:** Acceptance Criteria, SCATTER RNG seed determinism AC.
**Fix:** Replace current AC (duplicate tower_id=42) with: "**[Logic — BLOCKING]** GIVEN `RandomNumberGenerator` is constructed and seeded with `hash(42)`, WHEN 10 consecutive `randi_range(0, 4)` calls are made, THEN the sequence is identical on every test run — confirming that `hash()` on a fixed integer produces a deterministic seed. AND GIVEN a `TowerInstance` constructed via injectable RNG (Rule 25b) with a fixed-seed `RandomNumberGenerator`, WHEN the tower evaluates SCATTER targeting 10 consecutive cycles against the same 5-target pool, THEN the target selection sequence is identical on every test run."

---

## STEP 5 — Minor Doc Fixes (no design decisions, low effort)

| # | Location | Fix |
|---|----------|-----|
| M1 | Rule 14a table heading | Change "all 7 cache subscriptions" → "all 8 signal subscriptions (cache + phase/boss events)" |
| M2 | Open Questions table | Mark OQ-9 as **Resolved** — game-concept.md updated in Rev 7 |
| M3 | Rule 14a table | Add `wave_started` row: Mode = CONNECT_DEFERRED, Rationale = "Stagger and state transition can safely trail one frame from wave-start; synchronous would add N-tower update spike" |
| M4 | Rule 15 (targeting modes) | Add canonical tiebreaker footnote: "**Universal tiebreaker (all modes):** When primary sort is tied, apply: 1st tiebreaker = highest `path_step_index` (CLOSEST_TO_GOAL); 2nd = lowest `current_hp`; 3rd = lowest `entity_id`. Modes that use HP as primary sort skip tiebreaker 2 and go directly to entity_id." |
| M5 | Formula 1 output range | Add: "Boss DPS ceiling: 120.0 × 4.0 × 4.0 × 2.0 = **3840.0** (T4 + boss multiplier at max Weapon)" |
| M6 | Tuning Knobs table | Add row: `max_active_towers` \| TBD (register as constant when map design finalizes PLACEABLE cell count) \| Used to calculate projectile pool size |

---

## STEP 6 — Post-Revision EventBus Session

After tower.md is revised, a separate short session should:
1. Apply E1, E2, E3 changes to `event-bus.md`
2. Verify all Tower System event entries match tower.md exactly
3. Run `/consistency-check` to catch any remaining payload drift

---

## Decisions Summary Card

| Decision | Options | Impact |
|----------|---------|--------|
| D1 — SCATTER | A=Deterministic rule / B=Expose distribution / C=Cut | Rule 15, AC rewrite |
| D2 — Preview scope | A=Full / B=Partial info / C=None | Rule 8, Wave Manager dep |
| D3 — T1/T2 | A=Accept budget-gating / B=Mechanical niche / C=Count bonus | Formula 1, Tuning Knobs |

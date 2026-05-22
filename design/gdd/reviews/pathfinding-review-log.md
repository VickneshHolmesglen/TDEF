# Review Log: Pathfinding System GDD

`design/gdd/pathfinding.md`

---

## Review — 2026-05-22 (eleventh review) — Verdict: APPROVED
Scope signal: L
Specialists: None (lean mode — targeted re-review)
Blocking items: 1 (resolved in-session) | Recommended: 2 (applied)
Summary: Targeted lean re-review of review #10 revisions confirmed all 16 blockers correctly resolved. One remaining gap: B5 fix (Array[T].slice() type stripping) was applied to F3 formula pseudocode but not to Rule 15d, the actual implementation rule. Rule 15d still showed `return template.path.slice(...)` which would produce an untyped Array in GDScript 4. Fixed in-session by updating Rule 15d to show the typed `result.assign()` pattern with an explicit prohibition on direct `.slice()` returns. Two recommended revisions also applied: Mission HUD dependency reference updated to the now-existing file path, fallback cap check order made binding (check-before-increment explicitly stated). After these fixes, no open blockers remain. GDD is internally consistent, fully specified, and implementable.
Prior verdict resolved: Yes — all 16 review #10 blockers confirmed resolved; 1 final blocker found and resolved in this session.

---

## Review — 2026-05-22 (tenth review) — Verdict: MAJOR REVISION NEEDED → REVISED (same session)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, level-designer, performance-analyst, qa-lead, creative-director (full mode)
Blocking items: 16 | Recommended: 3 (applied)
Summary: Tenth full specialist pass on a re-review of review #9 revisions. Two critical defect classes dominated: (1) False quality gate — the CI validation tool was specified with `@tool` annotation instead of `extends SceneTree`, making the acceptance criterion describe a script that never executes and always silently passes. (2) Converging spec gaps at API boundaries — `get_path()` return type `Variant` contradicted ADR-0004's `Array[Vector2i]` declaration; `_compute_cost`'s coordinate space was unspecified despite being required to implement the formula; `would_block_all_paths()` missing explicit `goal_cells` population step (without which the function always returns true, blocking all placement). Fallback cap arithmetic (default=5 × 5ms/call = 25ms worst-case) exceeded the 16.67ms frame budget; corrected to default=1. Level Design Authoring Guidelines section was entirely absent — no min distances, no critical lane width requirements, no CI validator usage instructions. `_spawn_assignment` lifecycle was undocumented (when populated, whether rebuilt on dirty-template rebuild, pre-init guard interaction). `_rebuild_dirty_templates()` missing WAVE_ACTIVE entry guard — policy note was present but not an enforced code invariant. AC-25 tested private field `_templates_built` directly; AC-9a permitted manually triggering the deferred rebuild (bypassing the deduplication mechanism under test). All 16 blockers resolved in-session. Design decisions: partial GOAL block = allowed/no notification; `get_path()` → `Array[Vector2i]` (collapse to two-value contract); fallback cap default=1; `super_goal_id` always recomputed in `would_block_all_paths()`; `mission-hud.md` stub created. CD verdict: "The CI gate defect (B3) is the most dangerous single finding — a quality gate that always passes is worse than no gate. The return-type contradiction (B4) and fallback cap arithmetic (B7) are architectural correctness failures. Recommend targeted re-review scoped to these 16 items after revision — not another full adversarial sweep."
Prior verdict resolved: All 16 blockers from review #9 were confirmed resolved before this review. This review opened 16 new blockers; all 16 resolved in-session. Pending targeted re-review for APPROVED.

---

## Review — 2026-05-22 (ninth review) — Verdict: MAJOR REVISION NEEDED → REVISED (cross-session)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, performance-analyst, qa-lead, godot-specialist, level-designer, creative-director (full mode)
Blocking items: 16 | Recommended: 4 (all applied)
Summary: Ninth full specialist pass surfaced a critical new cluster of super-goal implementation failures that review #8 had missed. Three independent specialists converged on the same root cause: the GDD specified `_estimate_cost()` override but not `_compute_cost()` override — without it, Godot's default uses euclidean distance × weight averaging, producing nonzero GOAL→super-goal edge costs that silently bias routing toward GOAL cells near pixel origin. Two additional silent failures: (1) Rule 13's rebuild procedure (steps a–d) never re-added the super-goal node after `AStar2D.clear()` — after any dirty rebuild, A* found no path, templates stored `[]`, and monsters stopped silently with no error; (2) `super_goal_id` was not re-computed per build — stale value from G1=16×12 collides with valid G2 cell (col=0, row=8) on resize, silently corrupting the graph for the new mission. Also surfaced: AC-9b contradicted Rule 11 (doc said "no internal guard" but Rule 11 mandates one — all 6 specialists flagged independently); WAVE_ACTIVE guard omitted `_tower_destroyed_during_wave = true` causing permanent template divergence on Grid-lock failure; EC-1 description incorrect (said "full path returned" but slice(1) excludes SPAWN cell); EC-12 added (phantom GOAL arrival from empty goal_cells in Rule 15e fallback); AC-24b rewritten as testable GIVEN/WHEN/THEN; AC-22b gained virtual factory method test seam. CD synthesis: "The super-goal cluster is the most dangerous finding in this GDD's review history — three independent implementation defects that each individually cause silent routing failures. The fixes are clear but the pattern is concerning: each defect is a case where the GDD specified what the override should return but not why it was needed. Future GDD authors should front-load the 'why' for any override mandate."
Prior verdict resolved: Yes — all 16 blockers resolved in cross-session revision; pending re-review for APPROVED.

---

## Review — 2026-05-21 (eighth review) — Verdict: MAJOR REVISION NEEDED → REVISED (same session)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, performance-analyst, qa-lead, godot-specialist, level-designer, creative-director (full mode)
Blocking items: 12 | Recommended: 8
Summary: Eighth full specialist pass confirmed all 7 review-#7 blockers were still unresolved (GDD header read "review #6" — document not revised after review #7) and surfaced 5 new blockers. Most critical new finding: Godot's AStar2D uses a weight_scale averaging formula making PATH→PLACEABLE edge cost 5.5 (not 10) — all F4 crossover thresholds were wrong; F4 rewritten with corrected `W×P + 1` cost formula and Tuning Knobs safe range raised to 6–20. B4 (path_invalidated consumption contract) resolved by adding explicit "Mission HUD must call get_path(), never render affected_cells as route" binding note. AC-13b extended to simulate 2×2 footprint blocks (not just 1-cell). AC-13c added (initial PATH layout CI connectivity check). AC-24 split into measurement (AC-24a) and configuration gate (AC-24b) with corrected formula max(1, floor(5.67ms / baseline)). call_deferred timing corrected for physics-step callers. All 12 blockers resolved in-session. CD verdict: MAJOR REVISION NEEDED — escalated from prior NEEDS REVISION due to 7 unresolved prior-review blockers plus new weight_scale finding.
Prior verdict resolved: All 7 review-#7 blockers resolved + 5 new blockers resolved; pending re-review for APPROVED.

---

## Review — 2026-05-21 (seventh review) — Verdict: NEEDS REVISION
Scope signal: M
Specialists: game-designer, systems-designer, ai-programmer, performance-analyst, qa-lead, godot-specialist, level-designer, creative-director (full mode)
Blocking items: 8 | Recommended: 6
Summary: Seventh full specialist pass confirmed all 10 review-#6 blockers resolved and surfaced 8 new late-stage findings — consumption contract gaps and silent-failure paths rather than structural design issues. Most critical: (1) _estimate_cost else-branch calls cell_at(from_id) unconditionally — if Godot's A* internals call _estimate_cost(super_goal_id, real_id), cell_at(super_goal_id) returns Vector2i(0,0) silently breaking admissibility for maps where GOALs are not near grid origin; (2) fallback cap derivation can produce 0, leaving monsters frozen permanently with no error; (3) no CI validation that initial PATH layout actually routes SPAWN→GOAL (malformed mission silently stops all monsters at spawn); (4) path_invalidated consumption contract unspecified — Mission HUD must call get_path() after the event, not render affected_cells as the route; (5) pathfinding_placeable_cost safe range minimum=3 is internally contradicted by the GDD's own prose. CD ruled get_point_path() simplification deferred (stable architecture, late-stage pivot unjustified). 6 recommended revisions cover combined frame budget, 150-monster burst stagger design, call_deferred flush timing under decoupled physics, 3 AC coverage gaps, and explicit Variant return type mandate for get_path(). Two stale ⚠ markers in Bidirectionality notes confirmed resolved — remove in next revision.
Prior verdict resolved: Yes — all 10 blockers from review #6 confirmed resolved; 8 new blockers surfaced; pending revision.

---

## Review — 2026-05-21 (sixth review) — Verdict: NEEDS REVISION → REVISED (same session)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, performance-analyst, creative-director (full mode)
Blocking items: 10 | Recommended: 15+
Summary: Sixth full specialist pass against the review-#5 revision surfaced a new tier of adversarial findings — silent-failure implementation traps rather than structural issues. Most critical: (1) `_estimate_cost` override returns `null` (coercing to `0.0`) when `goal_cells` is empty in the temporary AStar2D built by `would_block_all_paths()`, silently destroying A* optimality; (2) threading note was factually wrong, conflating `_physics_process` (always main-thread) with `WorkerThreadPool` (the real risk); (3) no defensive WAVE_ACTIVE phase guard in Pathfinding's `tower_placed`/`tower_removed` handlers — Grid lock failure would cause silent mid-wave template corruption; (4) fallback A* per-call cost entirely unspecified despite being the same operation as `would_block_all_paths()`; (5) `primary_blocking_cell` iteration cost unbounded — max MVP footprint (2×2 = 4 cells) was unspecified. All 10 blockers resolved in-session. CD ruled game-designer blockers #1 (route-preview "may"→"must") and #2 (PLACEABLE terrain legibility) as correctly deferred to Mission HUD GDD and Art Bible with mandatory cascade commitments. Section B rewritten to scope Pathfinding's isolated delivery vs. companion-system co-dependencies.
Prior verdict resolved: Yes — all 8 blockers from review #5 confirmed resolved; 10 new blockers surfaced; all resolved in-session.

---

## Review — 2026-05-21 (fifth review) — Verdict: MAJOR REVISION NEEDED → REVISED (same session)
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, performance-analyst, qa-lead, godot-specialist, creative-director (full mode)
Blocking items: 8 | Recommended: 6
Summary: Fifth full specialist pass confirmed all 13 review-#4 blockers resolved and surfaced 8 new structural issues. Core failure mode: GDD specified cross-system promises in terms of internal state (`_rebuild_queued`, `FALLBACK_DEFERRED` identity) that consuming systems cannot observe. Key fixes: (1) `FALLBACK_DEFERRED` sentinel replaced with `null` — GDScript 4.x typed Array constants do not guarantee singleton identity across Autoload boundaries, making `is_same()` unreliable; (2) `is_rebuild_pending() -> bool` public API added to expose `_rebuild_queued` as an observable, used by WaveManager at INTERMISSION→PRE_WAVE gate; (3) `_templates_built: bool` flag added to prevent pre-init race where unbuilt templates cause silent `[]` returns indistinguishable from GOAL arrival; (4) `last_fallback_warning: String` public field replaces `push_warning()` for AC-11 testability; (5) EC-11 redesigned — PathfindingSystem now subscribes to `tower_destroyed` during WAVE_ACTIVE and auto-rebuilds at INTERMISSION entry, eliminating indefinite stale routing; (6) `primary_blocking_cell` sentinel changed to `Vector2i(-1, -1)` for multi-cell interaction blocks; (7) OQ-6 written — hot-path `Array[Vector2i]` slice copy cost. Cross-GDD: `tower_destroyed` updated with `footprint: Array[Vector2i]` payload; `tower_placement_blocked` added to EventBus; WaveManager Rule 22 updated with `is_rebuild_pending()` API reference.
Prior verdict resolved: Yes — all 13 blockers from review #4 confirmed resolved; 8 new blockers surfaced; all resolved in-session.

---

## Review — 2026-05-20 (fourth review) — Verdict: MAJOR REVISION NEEDED
Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, performance-analyst, qa-lead, creative-director (full mode)
Blocking items: 13 | Recommended: 8
Summary: Fourth full specialist pass surfaced 13 blockers across four structural failure modes: (1) internal type contradiction — `_dirty_templates` review log recorded as `Dictionary[int, bool]` vs. GDD's `Dictionary[Vector2i, bool]` (Vector2i is canonical — log entry was an in-session draft); (2) Godot engine behavior gap — `call_deferred` does not deduplicate, requiring explicit `_rebuild_queued: bool` flag to prevent spurious `path_invalidated` double-emission (breaks AC-8 and AC-9a); (3) undefined behavior contracts — `would_block_all_paths()` missing `.duplicate(true)` risking live Grid state corruption; fallback "hold last-known direction" replaced with freeze-in-place + FALLBACK_DEFERRED sentinel; `_spawn_assignment` scope undefined for SPAWN/GOAL cells; INTERMISSION→WAVE_ACTIVE rebuild race requires WaveManager `path_invalidated` secondary gate; (4) design/pillar gaps — EC-11 stale templates may persist indefinitely (not just "rest of wave"); `tower_placement_blocked` added `primary_blocking_cell: Vector2i` hint for "Placement is the Puzzle" legibility; Mission HUD must subscribe to `tower_destroyed` to communicate ghost-routing to player. Also: ADR-0004 had `slice(idx)` (wrong) → corrected to `slice(idx+1)`, and `_ready()` references corrected to `mission_phase_changed`. All 13 blockers resolved in-session. `production/qa/reference-hardware.md` created (unblocks AC-4, AC-17, OQ-3). AC-8 deleted (subsumed by AC-9a). AC-18–AC-21 added for new contracts.
Prior verdict resolved: Yes — all 7 blockers from third review confirmed resolved; 13 new blockers surfaced by full specialist review; all resolved in-session.

## Revision — 2026-05-20 — 13 blockers resolved (post review #4)

| Blocker | Fix |
|---------|-----|
| B1 `_dirty_templates` type contradiction | Added canonical type note to Rule 11: `Dictionary[Vector2i, bool]` is correct; review log R7 entry was an in-session draft superseded in the same review |
| B2 `call_deferred` dedup bug | Rule 12 rewritten with `_rebuild_queued: bool` flag pattern — ensures exactly one deferred call and one `path_invalidated` per frame batch |
| B3 INTERMISSION→WAVE_ACTIVE rebuild race | Rule 12 extended: WaveManager must subscribe to `path_invalidated` as secondary gate for waves 2+; cross-GDD dependency added to Dependencies |
| B4 `would_block_all_paths()` aliasing | Rule 9 specifies `.duplicate(true)` on `Grid.get_walkable_cell_map()`. Post-condition added. AC-18 added to validate Grid state unchanged after call |
| B5 `_spawn_assignment` scope undefined | F2 Population scope note added: includes SPAWN and GOAL cells explicitly. Rule 15b: `push_error` guard on missing-key lookup |
| B6 Fallback queue unimplementable | Rule 15d rewritten: freeze-in-place with `FALLBACK_DEFERRED` sentinel + `is_same()` detection pattern. No persistent queue. AC-20 added |
| B7 EC-11 stale scope incorrect | EC-11 rewritten: stale templates may persist multiple waves. "Remainder of wave" claim removed. Stale duration now explicitly "until next tower event during INTERMISSION" |
| B8 EC-11 player legibility gap | Mission HUD must subscribe to `tower_destroyed` during WAVE_ACTIVE and display communication. Cross-GDD dependency added |
| B9 `tower_placement_blocked` payload fails pillar | Rule 10 updated: payload now includes `primary_blocking_cell: Vector2i` hint. Computation specified (iterate footprint, first individually-blocking cell). AC-21 added |
| B10 AC-1 internal state assertion | AC-1 rewritten: uses `get_path(spawn_cell, 0)` observable + `templates_ready.spawn_count` |
| B11 AC-4/AC-17 TBD thresholds | `production/qa/reference-hardware.md` created (2026-05-20). AC-4 provisional target 1ms, AC-17 5ms p99 — both with measurement gate |
| B12 AC-14 integration boundary absent | AC-14 marked [INTEGRATION]; WaveManager stub fixture specified |
| B13 AC-16 private field clause | Private `_dirty_templates` assertion removed. Frame count reduced from 3 to 1 (one deferred cycle). |

---

## Review — 2026-05-19 (third review) — Verdict: NEEDS REVISION → REVISED (same session)

## Review — 2026-05-19 (third review) — Verdict: NEEDS REVISION → REVISED (same session)
Scope signal: L
Specialists: ai-programmer, performance-analyst, qa-lead, game-designer, systems-designer, creative-director (full mode)
Blocking items: 7 resolved | Recommended: 7 (open, not blocking)
Summary: Two ADRs written after the prior APPROVED verdict (ADR-0004, ADR-0008) introduced new contradictions and the full specialist review surfaced real defects. Most critical: F3 formula had two independent bugs (off-by-one `slice(idx)` at GOAL returns `[goal_cell]` not `[]`; missing -1 guard via implicit dict access) and template initialization trigger was contradicted between Rule 5 (`mission_phase_changed` SCOUT event) and ADR-0004 diagram (`_ready()`) with Rule 21 proving neither could be `_ready()`. Creative-director verdict: NEEDS REVISION — architecture sound, pillar alive, but F3 compiles to broken monster behavior and OQ-5 deferral was pillar failure (Placement is the Puzzle requires feedback contract). All 7 blockers resolved in-session: R5 F3 slice fixed to `slice(idx+1)` with guard; R6 Rule 5 names `mission_phase_changed` as sole trigger; R7 `_dirty_templates` defined as `Dictionary[int, bool]`; R8 AC-1/AC-2 contradiction reconciled; R9 `tower_placement_blocked(blocked_cells)` event added to Rule 10 (OQ-5 resolved); R10 SUPER_GOAL_ID row-major encoding documented as binding constraint; R11 AC-16 added for EC-11 BOSS no-rebuild intentional behavior. **Cross-GDD action required:** `tower_placement_blocked` must be added to EventBus GDD catalogue before implementation. ADR-0004 architecture diagram must be corrected to reference `mission_phase_changed`.
Prior verdict resolved: Yes — all 0 blockers from second review remain resolved; 7 new blockers surfaced by ADR changes and full specialist review; all resolved in-session.

---

## Review — 2026-05-14 (re-review pass) — Verdict: APPROVED
Scope signal: L
Specialists: None (lean mode)
Blocking items: 0 | Recommended: 4 (all applied in-session)
Summary: Re-review confirmed all 12 first-review blockers resolved in the 2026-04-26 revision. Zero new blockers. Four recommended revisions applied in-session: R1 — F2 pseudocode replaced with explicit index loop (prior `reduce()` formulation subscripted an Array with a Vector2i key, which is incorrect GDScript); R2 — EC-11 added to document intended stale-template behaviour when a BOSS destroys a tower during WAVE_ACTIVE (templates remain stable until next Intermission event — intentional); R3 — AC-7 labelled Post-MVP only (requires multi-SPAWN mission which MVP restricts); R4 — stale EventBus bidirectionality note updated to confirmed status (both events were added in the first review session). Document is implementation-ready for all MVP-tier content.
Prior verdict resolved: Yes — all 12 blockers from first review confirmed resolved; 4 recommended items applied.

---

## Review — 2026-04-26 — Verdict: NEEDS REVISION → REVISED (same session)

Scope signal: L
Specialists: game-designer, systems-designer, ai-programmer, performance-analyst, qa-lead, godot-specialist, level-designer, creative-director
Blocking items: 12 | Recommended: 8
Summary: The GDD had a sound architectural backbone (route templates, super-goal trick, deferred invalidation, Voronoi partition) but 12 blocking issues prevented implementation. The most important finding was that the design did not yet deliver its own stated pillar ("Placement is the Puzzle"): the Voronoi partition created invisible routing zones players cannot discover through play. Key technical gaps: `super_goal_id` unspecified (collision risk), Voronoi storage structure undeclared (O(1) claim unverifiable), OQ-2 resolution was architecturally incorrect (Autoload order does not guarantee async EventBus-triggered template build), fallback A* used an undefined AStar2D instance, and `would_block_all_paths()` trigger frequency was unspecified (hover = frame-budget risk). EventBus catalogue was missing `tower_removed` (Pathfinding subscribes to a non-existent event) and `templates_ready` (OQ-2 resolution). Five ACs tested Tower System behaviour or internal state rather than Pathfinding outputs. All 12 blockers resolved in-session. Document revised: rules 3, 5, 8, 9, 10, 13c, 15b/c/d updated; F2 storage spec added; new `templates_ready` event; Voronoi MVP constraint (single-SPAWN); 5 AC rewrites + 3 new ACs (now 15 ACs); 5 OQs (OQ-2 resolved, OQ-5 added). Cross-GDD edits: tower.md Rule 9 updated (path guard in placement workflow), Pathfinding added to tower.md Dependencies, event-bus.md `tower_removed` + `templates_ready` added (catalogue 59 → 61).
Prior verdict resolved: N/A — First review; all revisions applied same session.

### Blocking Items Resolved

| # | Item | Resolution |
|---|------|------------|
| B1 | Multi-SPAWN Voronoi creates invisible routing zones — undermines "Placement is the Puzzle" pillar | Path A chosen: MVP missions use exactly one SPAWN cell. Voronoi code present for forward-compatibility but no-op at MVP. Rule 3 updated with constraint. |
| B2 | `spawn_cells.reduce()` crashes on empty array (zero-SPAWN mission) | Rule 5 precondition added: `push_error` if `get_spawn_cells()` or `get_goal_cells()` is empty. AC-13 CI validator mandate added. |
| B3 | Super-goal node underspecified: point_id collision risk, heuristic admissibility gap, GOAL cell inclusion ambiguity | Rule 8 updated: `super_goal_id = grid_cols * grid_rows`; `_estimate_cost` override spec (min Manhattan to any GOAL when to_id == super_goal); "stored path includes GOAL cell as final entry, super-goal node stripped." Rule 13c reinforced. |
| B4 | OQ-2 false resolution (Autoload order ≠ async template build readiness) | OQ-2 resolved to Option (a): Pathfinding emits `templates_ready(spawn_count, build_duration_ms)` after all templates built. Rule 5 updated. event-bus.md `templates_ready` added. Wave Manager Rule 22 flagged for re-review update. |
| B5 | Fallback A* (Rule 15d) uses undefined AStar2D instance | Rule 15d specifies: standalone temporary AStar2D from `Grid.get_walkable_cell_map()` with same super-goal trick. |
| B6 | `would_block_all_paths()` trigger frequency unspecified — hover = frame-budget risk | Rules 9–10 updated: fires only on placement confirmation, explicitly not on hover. AC-15 added. |
| B7 | `tower_removed` absent from EventBus catalogue — Pathfinding subscribes to non-existent event | event-bus.md Tower System section: `tower_removed(tower_id, grid_position, archetype)` added with Pathfinding + Hero + Constellation as key subscribers. |
| B8 | Tower GDD bidirectionality failure: `would_block_all_paths()` missing from Rule 9; Pathfinding not in Dependencies | tower.md Rule 9 rewritten as 3-step sequence (resource → footprint → path guard). Pathfinding System row added to tower.md Dependencies. |
| B9 | Voronoi partition storage structure unspecified — O(1) claim unverifiable | F2 updated: results stored in `_spawn_assignment: Dictionary[Vector2i, int]`. Rule 15b updated to reference `_spawn_assignment`. |
| B10 | AC-5, AC-6, AC-7, AC-8, AC-11 test Tower System behaviour or internal state | All 5 ACs rewritten as observable-output tests scoped to Pathfinding's own outputs. |
| B11 | Missing ACs: CI validator, `templates_ready` timing, confirm-only trigger frequency | AC-13 (CI validator for malformed maps), AC-14 (`templates_ready` timing), AC-15 (`would_block_all_paths()` confirm-only) added. |
| B12 | AC-4 not independently testable — no reference machine spec | AC-4 rewritten with reference-hardware clause; marked `[BLOCKED on reference-hardware.md]`. |

### Deferred (RECOMMENDED — not blocking)

- Wave Manager GDD Rule 22 still claims Autoload order resolves template readiness — must be updated to subscribe to `templates_ready`; flagged for Wave Manager re-review session
- OQ-5 added: Player-facing routing feedback when `path_invalidated` fires — delegate to UI/VFX teams when Mission HUD GDD is authored
- AC-4 reference-hardware.md: producer task to define minimum-spec machine before QA can test pathfinding performance
- production/qa/reference-hardware.md: does not yet exist; needed for AC-4 and EventBus AC-09/AC-12
- Array.slice() O(k) copy cost noted as hotspot — verify empirically against 1ms budget during prototyping before committing to this hot path

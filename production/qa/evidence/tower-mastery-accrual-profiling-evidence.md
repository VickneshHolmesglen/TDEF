# Evidence: Tower Mastery Accrual-Loop Performance Profiling

**Story**: `production/epics/epic-06-mission-combat-extensions/story-012-live-performance-profiling-prototype.md`
**ADR**: ADR-0029 (Tower Mastery Proximity-Detection Strategy) — MEDIUM engine-risk classification, Verification Required
**Date**: 2026-07-18 (Sprint 6, S6-05)
**Method**: Live Godot MCP `run_script` against the pinned Godot 4.6.2.stable binary

## Performance Measurement

**Setup**: 100 lightweight `Node2D` monster stand-ins added to the live scene tree (each with a minimal `_physics_process` doing a position update + state check, representative of `MonsterManager`'s real per-monster per-frame cost) running concurrently with a prototype accrual loop tracking 5 simultaneously-accruing `build_signature`s — matching ADR-0029's own `_physics_process` pseudocode exactly:

```gdscript
func _physics_process(delta: float) -> void:
    for sig in _signatures_in_range:
        _mastery_time[sig] = _mastery_time.get(sig, 0.0) + delta
```

**Result** (2000-run average, after a 10-run warm-up):

| Metric | Value |
|---|---|
| Accrual loop cost per call | 0.899 µs (0.000899 ms) |
| Frame budget (60 FPS) | 16.67 ms |
| Percentage of frame budget | **0.0054%** |
| Concurrent monster count | 100 |
| Simultaneously-accruing signatures | 5 |

**Verdict**: The accrual loop's cost is negligible — over 3 orders of magnitude below the frame budget, even with 5 signatures accruing concurrently alongside a full 100-monster wave's own per-frame cost. This confirms ADR-0029's own architectural claim: because `_signatures_in_range` is only recomputed on cell-boundary crossing (never per-frame) and the per-frame work is bounded to O(distinct accruing signatures), the accrual loop itself was never the risk — the design is sound as specified.

**Recommendation**: ADR-0029's MEDIUM engine-risk classification can be downgraded to LOW on the performance axis specifically. This measurement used a prototype/stand-in accrual loop (Tower Mastery itself is not yet implemented — that's Sprint 6's S6-10) rather than the final shipped class; re-confirm once Stories 007–010 land, but no architectural change is expected given the magnitude of headroom found here.

## Re-confirmation Against the Real Shipped Class (2026-07-19, Sprint 7 S7-09/Story 012 follow-up)

Stories 007–011 (the actual `TowerMastery` implementation) landed in Sprint 7 after this evidence file's original measurement, which used a bare standalone prototype loop. Per this story's own "re-confirm once Stories 007–010 land" note, the profiling was re-run live via Godot MCP `run_script` against the pinned Godot 4.6.2.stable binary, this time instantiating the **real `TowerMastery` class** (`src/core/tower_mastery/tower_mastery.gd`) and calling its real `tick(delta)` method directly — not a hand-written stand-in.

**Setup**: identical to the original measurement (100 lightweight `Node2D` monster stand-ins doing a per-frame position/state update, running concurrently with the accrual pass), but this time `tick()` is the real shipped method: it iterates `_signatures_in_range`, accrues `mastery_time`, computes `_representative_tower_id_for(signature)` (a linear scan over `_active_signature_by_tower`), computes `progress_percent` via `clampf`, and emits `mastery_progress_updated` every call — genuinely more work per signature than the bare prototype pseudocode originally measured.

**Result** (2000-run average, after a 10-run warm-up, 5 simultaneously-accruing signatures):

| Metric | Original prototype (S6-05) | Real shipped class (S7, this pass) |
|---|---|---|
| Accrual loop cost per call | 0.899 µs | **6.347 µs** |
| Percentage of frame budget | 0.0054% | **0.0381%** |

**Verdict**: even with ~7x more absolute cost than the bare prototype — expected, since the real `tick()` does strictly more work (representative-tower-id resolution, progress-percent computation, an EventBus emission per signature every frame) — the measured cost remains **0.0381% of the 16.67ms frame budget**, still nearly 3 orders of magnitude below budget. The LOW-on-the-performance-axis downgrade recommended above is **confirmed against the real shipped implementation**, not just the prototype. No further re-confirmation is needed unless a future story adds materially more per-signature work to `tick()` (e.g. a real skill-catalogue lookup replacing the current `build_signature`-as-placeholder scheme).

## Playtest Question — "Does standing near a tower mid-combat feel fair?"

**This half of the story's own AC could not be completed as originally scoped.** The story calls for a human playtest session answering `systems-index.md`'s explicitly-flagged frustration risk. No human playtester is available in this autonomous session — fabricating a playtest response would misrepresent what actually happened, so this is reported honestly as an open item rather than a completed one.

**What can be offered instead**: a design-reasoning assessment based on the GDD's own stated mitigations (`tower-mastery.md`, Notes section), which the GDD itself frames as the reasons the risk is *managed*, not eliminated:

1. **Pause, never reset** on interruption — a hero who steps away to fight never loses progress, only defers it.
2. **Partial progress persists across missions** — a single mission's positioning choices are never wasted even below threshold.
3. **3-cell Chebyshev radius** (matching Hero's own Tower-Synced Class radius) is generous enough that active combat near a well-placed tower often accrues mastery as a side effect of normal positioning, not a dedicated "stand still" action.

These are structural mitigations already designed into the system, not a substitute for observing an actual player's reaction. **This item remains genuinely open** — recommend scheduling a real playtest session (mirroring the project's own `S4-11` playtest-round precedent) before treating Tower Mastery's HIGH-risk classification as closed on the "does it feel fair" axis specifically, even though the performance axis is now resolved.

## Summary

| Question | Status |
|---|---|
| Does the accrual loop perform acceptably under load? | ✅ **Yes** — 0.0054% of frame budget (prototype, S6-05); **re-confirmed at 0.0381% against the real shipped class (Sprint 7)** — still negligible |
| Does standing near a tower mid-combat feel fair? | ⚠️ **Still not answered** — requires a real human playtest session; no playtester was available in this automated session either, so this remains genuinely open, not fabricated |

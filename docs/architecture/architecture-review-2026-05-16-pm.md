# Architecture Review Report

**Date**: 2026-05-16 (PM re-run)
**Engine**: Godot 4.6.2 / GDScript
**Mode**: `/architecture-review` (full)
**GDDs Reviewed**: 10 (game-concept + 9 MVP system GDDs)
**ADRs Reviewed**: 5 (ADR-0001 to ADR-0005 — all Accepted)
**TR Registry**: v3 (57 active entries)
**Source of TR truth**: `docs/architecture/tr-registry.yaml`
**Prior review**: `docs/architecture/architecture-review-2026-05-16.md` (verdict: CONCERNS)

---

## What changed since the prior review

| Item | Status |
|------|--------|
| ADR-0005 (Grid System) authored & Accepted — covers 4 Foundation TRs | ✅ Resolved |
| ADR-0004 footer `TR-wave-003` → `TR-wave-004` fix | ✅ Resolved (line 268) |
| Roadmap renumbering after Grid insertion | ⚠ Required this run |

Coverage: **22 → 26 ✅** / 3 ⚠ / **32 → 28 ❌** out of 57 TRs.

---

## Traceability Summary

| Status | Count | % |
|--------|-------|---|
| ✅ Covered | 26 | 46% |
| ⚠ Partial | 3 | 5% |
| ❌ Gap | 28 | 49% |
| **Total TRs** | **57** | 100% |

Foundation layer is now **100% covered**. All remaining gaps are Core / Feature / Presentation layer, gated on the pending ADR roadmap.

Full matrix in `docs/architecture/architecture-traceability.md`.

---

## Cross-ADR Conflicts — NEW finding this run

### CONFLICT-1 — Roadmap numbering collision triggered by ADR-0005 insertion

Inserting ADR-0005 = Grid System displaced the original roadmap, where the integers 0005–0008 were reserved for Monster movement / Damage pipeline / Tower placement / Resource model. Four existing ADRs continued to reference the *old* numbering, and ADR-0005 itself referenced two *different* numberings in the same file.

Concrete inconsistencies found and resolved this run:

| File | Old text | New text | Source of truth |
|------|----------|----------|-----------------|
| ADR-0001 line 25 | "ADR-0005 through ADR-0008 (all Core layer ADRs)" | "ADR-0005 (Grid); ADR-0006 through ADR-0009 (all Core layer ADRs)" | Roadmap shift +1 |
| ADR-0001 line 206 | "ADR-0006 — Damage pipeline" | "ADR-0007 — Damage pipeline" | Damage now ADR-0007 |
| ADR-0002 line 25 | "ADR-0005 (Monster movement — confirms Area2D scene root)" | "ADR-0005 (Grid system — Autoload #3); ADR-0006 (Monster movement — confirms Area2D scene root)" | Both refs added |
| ADR-0002 line 228 | "ADR-0005 — Monster movement (Area2D root confirmed here)" | "ADR-0005 — Grid system (Autoload #3 …)" + "ADR-0006 — Monster movement (Area2D root confirmed here)" | Both refs added |
| ADR-0003 lines 25, 304 | "ADR-0008 (Resource data model …)" | "ADR-0009 (Resource data model …)" | Resource model now ADR-0009 |
| ADR-0004 line 25 | "ADR-0005 (Monster movement …); ADR-0007 (Tower placement gate …)" | "ADR-0006 (Monster movement …); ADR-0008 (Tower placement gate …)" | Roadmap shift +1 |
| ADR-0004 line 265 | "ADR-0005 (Monster movement) is enabled by this ADR" | "ADR-0006 (Monster movement) is enabled by this ADR" | Renumber |
| ADR-0004 lines 295–296 | "ADR-0005 — Monster movement / ADR-0007 — Tower placement gate" | "ADR-0005 — Grid system / ADR-0006 — Monster movement / ADR-0008 — Tower placement gate" | Renumber + add Grid ref |
| ADR-0005 line 25 (Enables) | "ADR-0006 (Monster movement); ADR-0007 (Tower placement gate); ADR-0008 (Resource data model)" — **Damage pipeline silently omitted** | "ADR-0006 (Monster movement); ADR-0007 (Damage pipeline); ADR-0008 (Tower placement gate); ADR-0009 (Resource data model)" | Damage pipeline restored |
| ADR-0005 line 303 (Related Decisions) | "ADR-0006 — Tower placement gate" — **contradicts its own Enables field** | "ADR-0008 — Tower placement gate" | Self-consistent with new roadmap |

**Resolution**: User selected "Shift all +1". All edits applied this run. Verified: no remaining stale references to "ADR-0005 — Monster movement" or "ADR-0008 — Resource data model" in any Accepted ADR.

### Authoritative roadmap (post-fix)

| ADR | System | Status |
|-----|--------|--------|
| ADR-0001 | EventBus | Accepted |
| ADR-0002 | Scene/Autoload structure | Accepted |
| ADR-0003 | Save file format | Accepted |
| ADR-0004 | Pathfinding strategy | Accepted |
| ADR-0005 | **Grid system data model** | Accepted |
| ADR-0006 | Monster movement | Pending |
| ADR-0007 | Damage pipeline | Pending |
| ADR-0008 | Tower placement gate | Pending |
| ADR-0009 | Resource data model | Pending |
| ADR-0010 | Hero Tower-Synced Class | Deferred |
| ADR-0011 | UI dual-focus | Deferred |
| ADR-0012 | Wave Manager FSM | **Recommended — not yet in roadmap (carries forward from prior review)** |

### Dependency DAG — no cycles after renumber

```
ADR-0001 (root, no deps)
  ▲
  ├── ADR-0002 ──┬── ADR-0003
  │              ├── ADR-0004 ──┐
  │              └── ADR-0005   │  (Grid)
  │                  ▲          │
  │                  └──────────┘
```

ADR-0005 depends on ADR-0001 + ADR-0002. ADR-0004 (Pathfinding) reads `Grid.get_walkable_cell_map()` in `_ready()` — Grid must boot first (Autoload #3 before #4). This ordering is asserted in both ADR-0004 line 27 ("This order was fixed by ADR-0002") and ADR-0005's "Ordering Note". Consistent.

### Recommended ADR Implementation Order

1. ADR-0001 — EventBus *(Accepted)*
2. ADR-0002 — Scene/Autoload *(Accepted)*
3. ADR-0003 — Save format *(Accepted, parallel with ADR-0004 + ADR-0005)*
4. ADR-0005 — Grid system *(Accepted; required before ADR-0004 can run)*
5. ADR-0004 — Pathfinding *(Accepted)*
6. ADR-0006 — Monster movement *(next — Foundation+Core gate)*
7. ADR-0007 — Damage pipeline
8. ADR-0008 — Tower placement gate
9. ADR-0009 — Resource data model

---

## Engine Compatibility Audit

| Check | Result |
|-------|--------|
| All ADRs reference engine 4.6.2 | ✅ 5/5 consistent |
| Engine Compatibility section present | ✅ 5/5 |
| Post-cutoff APIs Used field populated | ✅ 5/5 (none / 4.4 `FileAccess` bools / none / none / none) |
| Deprecated API grep against `deprecated-apis.md` | ✅ No matches |
| HIGH RISK domain coverage | ⚠ UI dual-focus (HIGH) deferred to ADR-0011 — required before Pre-Production if any Presentation GDD lands |

**ADR-0005 engine verification items still open** (per its own Engine Compatibility section, Verification Required field):
1. Verify `Dictionary[Vector2i, CellType]` static typing compiles with a user-defined enum value type in Godot 4.6.2. If not, fallback is `Dictionary[Vector2i, int]` with boundary cast helpers.
2. Verify `ERR_UNAVAILABLE` semantics vs `ERR_LOCKED` / `FAILED` for "operation rejected by state machine".

Both are verification tasks for the Grid scaffold story, not architecture-level blockers.

No engine specialist consultation in this run — the only new ADR (0005) uses pre-4.x stable APIs (Dictionary, Vector2i, floor, Error enum), low knowledge-risk surface. Recommend specialist consult before authoring **ADR-0011 (UI dual-focus)** — that domain has the highest unverified surface area (AccessKit in 4.5, glow rework in 4.6).

---

## GDD Revision Flags

**None.** Same conclusion as prior review — all 9 MVP GDDs make engine assumptions consistent with verified ADR decisions. The renumbering does not affect any GDD content.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` still references the **pre-Grid** roadmap in two places:

1. **ADR Audit section**: claims "No ADRs exist yet" — stale since prior review; should be updated to list ADR-0001 to ADR-0005 Accepted.
2. **Required ADRs section**: lists 8 pending ADRs using old numbering (ADR-0005 = Monster movement, etc.). Needs to be regenerated against the new roadmap.

Neither is gate-blocking. Both should be refreshed when `architecture.md` is next revised — recommend folding into the next ADR's review pass.

---

## Verdict: **PASS WITH NOTES**

All 5 Accepted ADRs are internally consistent, free of conflicts after this run's roadmap renumber, engine-compatible, and the Foundation layer is fully covered (10/10 TRs across EventBus, Save, Grid, Pathfinding, plus the Autoload-confirmed scene roots).

**Why not clean PASS**:
- ADR-0005's own Verification Required items (typed-Dictionary-with-enum, `ERR_UNAVAILABLE` semantics) are open — addressed during scaffold work, not blocking for the gate.
- `architecture.md` master doc is stale w.r.t. the 5 Accepted ADRs and the new numbering — non-blocking, but should be refreshed before Pre-Production gate-check.
- Wave Manager FSM has no ADR in the roadmap (carries forward from prior review as ADR-0012 recommendation). Feature layer, not Foundation — does not block Technical Setup → Pre-Production gate, but should be on the Pre-Production sprint backlog.

### No blocking issues for Pre-Production gate
The prior review's two blockers (Grid ADR, ADR-0004 TR fix) are both resolved. This run's roadmap-collision conflict was a documentation issue, all 9 fixes applied in-session.

### Recommended (non-blocking)

1. Refresh `architecture.md` ADR Audit and Required ADRs sections against the new authoritative roadmap.
2. Add ADR-0012 (Wave Manager FSM) to the formal roadmap before sprint planning — covers TR-wave-001, 003, 005, 006, 007.
3. When ADR-0006 (Monster movement) is authored, verify it does not silently re-introduce a numbering drift — anchor cross-refs by *purpose* not just integer.

---

## Chain-of-Verification

5 challenge questions checked:

- "Did I catch all stale 'ADR-0005 = Monster movement' references?" — Yes: grep across ADR-0001…0004 plus ADR-0005 itself; all 10 stale references identified, edited, verified post-edit.
- "Did ADR-0005's own Enables field silently drop the Damage pipeline?" — Yes; restored as ADR-0007. The omission would have made Damage an orphan in the dependency DAG.
- "Did the renumber break any Depends On / Enables chain in the dependency DAG?" — Re-walked the DAG: ADR-0005 depends on 0001+0002; ADR-0004's `Enables` now lists ADR-0005 explicitly (was missing); no cycles.
- "Did I downgrade FAIL into PASS WITH NOTES unjustifiably?" — No. The roadmap collision is a documentation conflict, not a structural one; the dependency DAG is sound; Foundation coverage is 100%.
- "Is the Wave Manager FSM gap a hidden Foundation blocker?" — No; Wave Manager is Feature layer. Confirmed in prior review CoV and unchanged.

**Result**: verdict unchanged.

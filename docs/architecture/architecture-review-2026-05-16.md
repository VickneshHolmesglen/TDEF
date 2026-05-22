# Architecture Review Report

**Date**: 2026-05-16
**Engine**: Godot 4.6.2 / GDScript
**Mode**: `/architecture-review` (full)
**GDDs Reviewed**: 10 (game-concept + 9 MVP system GDDs)
**ADRs Reviewed**: 4 (ADR-0001 to ADR-0004 — all Accepted)
**Source of TR truth**: `docs/architecture/architecture.md` (57 TRs enumerated 2026-05-15)

---

## Traceability Summary

| Status | Count | % of total |
|--------|-------|-----------|
| ✅ Covered | 22 | 39% |
| ⚠ Partial | 3 | 5% |
| ❌ Gap | 32 | 56% |
| **Total TRs** | **57** | 100% |

**Gap composition (32 total)**:
- 28 are **expected** — ADR-0005 to ADR-0010 in the roadmap have not yet been written
- 4 are **unscoped** — Grid System has no ADR in the roadmap (foundation layer gap)
- 1 entry (TR-gc-004) is **not a gap** — it is a design tuning value, not architecture

---

## Coverage Gaps (Foundation Layer — BLOCKING for Pre-Production)

### Grid System (4 TRs uncovered — no ADR in roadmap)

| TR-ID | Requirement | Domain | Engine Risk |
|-------|-------------|--------|-------------|
| TR-grid-001 | 16×12 default grid; 5 cell types (EMPTY, SPAWN, GOAL, PATH, BLOCKED) | Data model | LOW |
| TR-grid-002 | Direct read API (Autoload); write restricted to Tower System | Access pattern | LOW |
| TR-grid-003 | `world_to_cell()` uses `floor()` semantics | Math/coords | LOW |
| TR-grid-004 | Returns copies, not references — callers cannot mutate Grid state | API contract | LOW |

**Suggested ADR**: `/architecture-decision Grid System data model and access pattern`

The architecture.md API Boundaries section *does* specify the Grid contract, but a section in a master architecture document is not an Accepted ADR — programmers cannot reference it from stories the same way. The Grid system warrants its own ADR for the same reason EventBus, Save, and Pathfinding did.

---

## Coverage Gaps (Core + Feature Layers — EXPECTED, not blocking)

These gaps are documented in architecture.md as pending ADRs. They are blockers for **system implementation**, not for the Pre-Production gate.

| Block | Pending ADR | TRs uncovered |
|-------|-------------|--------------|
| Monster movement | ADR-0005 | TR-monster-002, 003, 005, 006 |
| Damage pipeline | ADR-0006 | TR-ds-001 to 005 |
| Tower placement | ADR-0007 | TR-tower-001 to 006 |
| Resource data model | ADR-0008 | (shared across Monster/Tower/Wave) |
| Hero Tower-Synced Class | ADR-0009 (deferred) | TR-hero-002 to 006 |
| UI dual-focus | ADR-0010 (deferred) | HIGH RISK domain |
| Wave Manager FSM | **NOT in roadmap** | TR-wave-001, 002, 005, 006, 007 |

The Wave Manager FSM gap is a **second roadmap oversight** (alongside Grid). Architecture.md treats Wave Manager TRs as a side-effect of ADR-0004 (templates_ready) and ADR-0008 (Resources), but TR-wave-001 (7-state phase FSM) and TR-wave-005 (wave-stuck watchdog) are decisions that deserve their own ADR.

---

## Cross-ADR Conflicts

**None detected.** Dependency graph is a clean linear DAG with no cycles:

```
ADR-0001 (root, no deps)
  ▲
  ├── ADR-0002 ──┬── ADR-0003
  │              └── ADR-0004
```

No data-ownership conflicts. No integration contract mismatches. No performance budget collisions (only ADR-0001 sets a frame budget — 1.667 ms EventBus processing). No pattern conflicts — all ADRs use EventBus signals consistently.

### Recommended ADR Implementation Order (topological)

1. **ADR-0001** (no deps) — EventBus
2. **ADR-0002** (needs ADR-0001) — Scene/Autoload
3. **ADR-0003** (needs 0001, 0002) — Save format — parallel-eligible with ADR-0004
4. **ADR-0004** (needs 0001, 0002) — Pathfinding — parallel-eligible with ADR-0003

All 4 are Accepted. No `Proposed`-blocks-`Accepted` issues.

---

## TR Mapping Errors (BLOCKING — must fix before gate-check re-run)

**ADR-0004** — `Technical Requirements covered:` line claims **TR-wave-003** but actually covers **TR-wave-004**:

- TR-wave-003 (per architecture.md): "BOSS breach = wave-clear"
- TR-wave-004 (per architecture.md): "templates_ready gate before first spawn"
- ADR-0004 actual content: documents the `_routes_ready` flag and `templates_ready` event gate — this is TR-wave-004.

**Action**: edit `docs/architecture/adr-0004-pathfinding-strategy.md`, change `TR-wave-003` → `TR-wave-004` in the Technical Requirements covered footer.

---

## GDD Revision Flags

**None.** All 9 MVP GDDs make engine assumptions consistent with the verified ADR decisions. The architecture deliberately chose conservative, verified APIs (AStar2D, Area2D for monsters, explicit dual-focus testing for UI) that match what the GDDs assume.

---

## Engine Compatibility Audit

| Check | Result |
|-------|--------|
| All ADRs reference engine 4.6.2 | ✅ Consistent |
| ADRs with Engine Compatibility section | ✅ 4/4 |
| Post-cutoff APIs Used field populated | ✅ 4/4 (none / 4.4 `FileAccess` bools / none / none) |
| Deprecated API check (grep against `deprecated-apis.md`) | ✅ No matches |
| HIGH RISK domain coverage | ⚠ UI dual-focus (HIGH) deferred to ADR-0010 (acceptable for Technical Setup; required before Pre-Production if any Presentation GDD lands) |

No engine specialist consultation in this run (the audit covers 4 well-scoped ADRs with no surprises). Recommend consulting `godot-specialist` before writing ADR-0010 (UI dual-focus) — that domain has the highest unverified surface area.

---

## Architecture Document Coverage

`architecture.md` covers all 25 systems from `systems-index.md`. No orphaned architecture. Two minor freshness issues:

1. Architecture.md still says "No ADRs exist yet" in the ADR Audit section — should be updated to reflect ADR-0001 to ADR-0004 are Accepted.
2. The Traceability Matrix in architecture.md still shows all 57 TRs as ❌ GAP — should be updated to reflect current coverage (22 covered).

Neither blocks the gate — but both should be cleaned up when architecture.md is next revised (recommend a `Last Updated: 2026-05-16` bump with the ADR coverage rolled in).

---

## Verdict: **CONCERNS**

The 4 Accepted ADRs are well-formed, internally consistent, free of conflicts, and engine-compatible. The roadmap from architecture.md is sound. Two specific issues prevent a clean PASS:

1. **Grid System has no ADR** — 4 Foundation-layer TRs uncovered. The Pre-Production gate-check rule "zero Foundation layer gaps" is violated.
2. **TR-wave-003/004 mismapping** in ADR-0004 — a one-line fix.

Both are mechanical fixes, not design rethinks. Re-run `/architecture-review` after resolving them and the verdict should clear to PASS.

### Blocking Issues for Pre-Production Gate

1. Write ADR-0005 for Grid System (or insert before existing ADR-0005 Monster movement and renumber the roadmap).
2. Edit ADR-0004 `Technical Requirements covered:` footer: `TR-wave-003` → `TR-wave-004`.

### Recommended (non-blocking, do during Pre-Production sprint planning)

- Add a Wave Manager FSM ADR to the roadmap (covers TR-wave-001, 002, 005, 006, 007).
- Refresh architecture.md TR coverage table to reflect ADR-0001 to ADR-0004 Accepted status.
- Plan ADR-0010 (UI dual-focus) for whenever the first Presentation GDD is authored.

---

## Chain-of-Verification

5 challenge questions checked:
- "Did I verify ADR coverage by reading each ADR's footer claim AND its decision content?" — Yes. The TR-wave-003 mismatch was caught precisely because I cross-checked the claim against the body.
- "Did I treat documented-but-not-yet-written ADRs as gaps?" — Yes; those 28 are reported as expected gaps, not failures.
- "Is the Grid 'gap' actually covered somewhere I missed?" — Re-checked. Architecture.md API Boundaries documents the contract, but that is not an Accepted ADR. The gap is real.
- "Did I downgrade FAIL into CONCERNS unjustifiably?" — No. The 4 issues are all mechanical and resolvable in <1 session. A real FAIL would be a structural conflict or cycle.
- "Could the Wave Manager FSM gap be a hidden blocker?" — Not for the Pre-Production gate (Wave Manager is Feature layer, not Foundation). But it should be on the Pre-Production sprint backlog.

**Result**: verdict unchanged.

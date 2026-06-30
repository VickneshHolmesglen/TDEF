# Architecture Review Report — 2026-05-24

**Date**: 2026-05-24
**Engine**: Godot 4.6.2 / GDScript
**GDDs Reviewed**: 13 (9 MVP approved + game-concept + mission-hud skeleton + cross-review notes)
**ADRs Reviewed**: 10 (ADR-0001 … ADR-0009, ADR-0012; ADR-0010/0011 deliberately deferred)
**Mode**: full
**Verdict**: **CONCERNS**

---

## ADR Status Snapshot

| ADR | Title | Status |
|-----|-------|--------|
| 0001 | EventBus architecture | ✅ Accepted |
| 0002 | Scene & Autoload structure | ✅ Accepted (revised 2026-05-23, 2026-05-24) |
| 0003 | Save file format | ✅ Accepted |
| 0004 | Pathfinding strategy | ✅ Accepted |
| 0005 | Grid data model | ✅ Accepted |
| 0006 | Monster movement | 🟡 **Proposed** |
| 0007 | Damage pipeline | 🟡 **Proposed** |
| 0008 | Tower placement gate | ✅ Accepted |
| 0009 | Resource data model | 🟡 **Proposed** |
| 0012 | Wave Manager FSM | 🟡 **Proposed** |

---

## Traceability Summary

| Status | Count | % |
|--------|-------|---|
| ✅ Covered | 49 | 86% |
| ⚠️ Partial | 2 | 4% |
| ❌ Gap | 6 | 11% |
| **Total** | **57** | 100% |

Foundation layer: **100% covered**. No Foundation or Core requirement is *uncovered*; however, 19 covered TRs depend on **Proposed** ADRs (0006/0007/0009/0012) and are therefore designed-but-not-yet-implementable.

### Per-System Coverage

| System | TRs | Covered | Governing ADR(s) | Notes |
|--------|-----|---------|------------------|-------|
| EventBus | 6 | 6/6 | 0001 | Fully Accepted |
| Grid | 4 | 4/4 | 0005 | Fully Accepted |
| Save | 6 | 6/6 | 0003 | Fully Accepted |
| Hero | 6 | 2/6 | 0002, 0007🟡 | 4 gaps (ADR-0010 deferred + Alpha skills) |
| Tower | 6 | 5/6 | 0008, 0009🟡, 0007🟡 | 1 partial (perk activation rule) |
| Monster | 6 | 6/6 | 0002, 0004, 0006🟡, 0009🟡 | 4 TRs rely on Proposed 0006 |
| Damage & Status | 5 | 4/5 | 0007🟡 | 1 gap (status effects, post-MVP) |
| Pathfinding | 7 | 6/7 | 0004, 0002 | 1 partial (100-agent perf unverified) |
| Wave Manager | 7 | 7/7 | 0012🟡, 0009🟡, 0004 | All rely on Proposed 0012/0009 |
| Game Concept | 4 | 3/4 | 0001, 0002 | 1 gap (session-length = design tuning) |

🟡 = coverage depends on a Proposed ADR.

---

## Coverage Gaps (no ADR)

| TR | Requirement | Disposition |
|----|-------------|-------------|
| ❌ TR-hero-002 | 12 stats; Tower-Synced Class (Chebyshev 3-cell) | Deferred → ADR-0010 (intentional) |
| ❌ TR-hero-003 | Tower Affinity sqrt scaling | Deferred → ADR-0010 |
| ❌ TR-hero-006 | 6 stat formulas | Deferred → ADR-0010 |
| ❌ TR-hero-005 | 4 active skills + Ultimate | Alpha-tier (Hero Skill Build) — not MVP |
| ❌ TR-ds-004 | 5 status effect types + stack/duration | Out-of-scope in ADR-0007; needs own ADR when status system is designed |
| ❌ TR-gc-004 | 15–25 min session-length formula | Design tuning, not architecture — no ADR required |

### Partial Coverage

| TR | Requirement | Why partial |
|----|-------------|-------------|
| ⚠️ TR-tower-005 | Pre-placement perk (Scout-only) | Perk **data schema** in ADR-0009 (TowerPerkRegistry), but the Scout-phase-only **activation rule** has no architectural decision |
| ⚠️ TR-path-007 | 100+ agents @ 60 FPS | Architecturally addressed (O(1) `get_path` templates + Area2D + centralized 4-pass) but HIGH-RISK perf AC with **no profiling evidence**; early 100-agent prototype still recommended |

---

## Cross-ADR Conflicts / Inconsistencies

No blocking contradictions. Four issues to reconcile:

### 1. ADR-0002 internal inconsistency — MEDIUM
The 2026-05-24 revision reclassified WaveManager as Autoload #7 (boundary table + boot-order table updated), but the **Mission Scene hierarchy diagram still lists `WaveManager (Node)` as a child of `MissionScene`**. An Autoload cannot simultaneously be a scene-instanced child.
**Resolution**: Remove `WaveManager` from the MissionScene hierarchy code block in ADR-0002.

### 2. Status inversion — Accepted ADR depends on Proposed ADRs — MEDIUM/HIGH
ADR-0002 (Accepted) now encodes `GameDataRegistry@5` (defined by ADR-0009, Proposed) and `WaveManager@7` (defined by ADR-0012, Proposed). An Accepted decision is only correct if both Proposed ADRs hold as written.
**Resolution**: Promote ADR-0009 and ADR-0012 to Accepted, OR mark those two boot-order rows in ADR-0002 as provisional until they are.

### 3. Deferral-primitive divergence (ADR-0001 vs ADR-0007) — MEDIUM
ADR-0001 Rule 2 mandates `call_deferred("emit_signal", …)` for physics/Level-1-cascade emitters. ADR-0007 explicitly rejects `call_deferred` for damage events in favor of `await get_tree().process_frame`, arguing call_deferred fires end-of-current-frame (ambiguous relative to `_physics_process` Pass 1 drain). Both are valid; ADR-0001 does not sanction the second primitive.
**Resolution**: Amend ADR-0001 Rule 2 to acknowledge `await get_tree().process_frame` as the approved mechanism when *next-frame* (not end-of-frame) delivery is required.

### 4. Proposed-ADR implementation chain — BLOCKING for Core stories
`0006 → 0007 → 0009 → 0012` is entirely Proposed. Per `docs/CLAUDE.md`, stories referencing a Proposed ADR are auto-blocked, so **no Monster, Damage, Resource, or Wave Manager story can be authored** until these reach Accepted. ADR-0007 cannot be Accepted before ADR-0006 (explicit ordering note).

---

## ADR Dependency Order (topologically sorted)

```
Foundation (no deps):
  ADR-0001  EventBus
Depends on Foundation:
  ADR-0002  Scene/Autoload (← 0001)
  ADR-0003  Save format (← 0001, 0002)
  ADR-0005  Grid (← 0001, 0002)
  ADR-0004  Pathfinding (← 0001, 0002; boot-coupled to 0005)
Core gameplay:
  ADR-0006🟡 Monster (← 0001, 0004, 0005)
  ADR-0008   Tower gate (← 0001, 0004, 0005)
  ADR-0007🟡 Damage (← 0001, 0006)
  ADR-0009🟡 Resource model (← 0002, 0006, 0008)
Feature:
  ADR-0012🟡 Wave Manager FSM (← 0001, 0002, 0004, 0009)
```

**No dependency cycles.** Critical unblock: **Accept ADR-0006 first** — it cascades to unblock 0007 and 0009, then 0012.

**Unresolved dependencies (Proposed blocking):**
- 🟡 ADR-0007 depends on ADR-0006 (Proposed) — cannot be Accepted until 0006 is.
- 🟡 ADR-0009 depends on ADR-0006 (Proposed).
- 🟡 ADR-0012 depends on ADR-0009 (Proposed).

---

## GDD Revision Flags (Architecture → Design Feedback)

None — all GDD assumptions are consistent with verified engine behaviour. Jolt-default (Godot 4.6) is correctly scoped by ADR-0006 as 3D-only; the game is 2D.

---

## Engine Compatibility Issues — PASS

- All 10 ADRs declare Godot 4.6.2; all include an Engine Compatibility section (no blind spots).
- Post-cutoff APIs correctly flagged & guarded: `FileAccess.store_*` bool returns (ADR-0003, MEDIUM); `Resource.duplicate_deep()` 4.5+ (ADR-0008, MEDIUM).
- **No deprecated-API usage**: ADR-0008 uses `duplicate_deep()` (not deprecated `duplicate()`); ADR-0005 rejects deprecated `TileMap` in favor of data Dictionaries; ADR-0001 uses `signal.connect(callable)`. ADR-0004 deliberately avoids the high-risk NavigationServer2D 4.0/4.2 API changes by choosing AStar2D.
- **Minor engine note**: ADR-0006 specifies verifying BOSS overlay alpha-compositing on the "Godot 4.6.2 Vulkan renderer," but **D3D12 is the Windows default since 4.6**. Add D3D12 to that verification criterion.

*(Engine specialist sub-agent consultation skipped per user direction; inline audit performed against the loaded engine reference docs.)*

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (v1, 2026-05-15) is structurally consistent with the systems index, but its **ADR Audit section is stale** ("57 TRs, 0 covered" — actual 49/57). `architecture-traceability.md` predated ADR-0012 and the 0009 coverage. Both are refreshed alongside this report.

---

## Blocking Issues

None that warrant FAIL. The Proposed-ADR chain blocks *story authoring* for Core gameplay but is expected at this pre-production stage.

---

## Required ADRs (prioritised)

1. **Accept ADR-0006** (Monster movement) — unblocks 0007/0009/0012.
2. **ADR for TR-tower-005** Scout-only perk activation rule (or fold into the Tower implementation ADR) — currently partial.
3. **Status-effects ADR** for TR-ds-004 — post-MVP, when the status system GDD is authored.
4. **ADR-0010** (Hero Tower-Synced Class + Tower Affinity) — covers TR-hero-002/003/006; deferred but needed before Hero implementation.

---

## Handoff

**Immediate actions (highest-impact first):**
1. Accept ADR-0006 in a fresh session, then ADR-0007 and ADR-0009, then ADR-0012.
2. Fix ADR-0002's scene hierarchy diagram (remove WaveManager from MissionScene tree) and resolve the Accepted-depends-on-Proposed inversion.
3. Reconcile ADR-0001 vs ADR-0007 deferral primitive (one-line amendment to ADR-0001 Rule 2).

**Gate guidance**: When the Proposed-ADR chain is Accepted and issues 1–2 above are resolved, run `/gate-check pre-production` to advance.

**Rerun trigger**: Re-run `/architecture-review` after each ADR is promoted to Accepted to confirm the dependency chain clears.

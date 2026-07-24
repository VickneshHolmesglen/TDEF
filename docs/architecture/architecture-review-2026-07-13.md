# Architecture Review Report — 2026-07-13

> **Addendum (2026-07-13, same day)**: Conflicts 1, 2, and Finding 4 below have been resolved. ADR-0016's `restore_order` was corrected from 20 to 10 and ADR-0016 was Accepted. ADR-0017's Wave Manager precedent citation was corrected (the underlying scene-instanced decision was unaffected) and ADR-0017 was Accepted. This retroactively legitimizes the 13 Epic 03 stories that were already `Status: Ready` against these ADRs while they were still Proposed. TR-econ-003 (gold-balance ownership) remains genuinely open per ADR-0017's own Open Questions — that is a separate, unresolved item, not something this fix addresses. The findings below are left as originally written for the historical record; see `architecture-traceability.md` for the current, corrected state.

**Date**: 2026-07-13
**Engine**: Godot 4.6.2 / GDScript
**GDDs Reviewed**: 16 (`game-concept`, `game-pillars`, `event-bus`, `grid-system`, `save-persistence`, `hero`, `tower`, `monster`, `damage-status`, `pathfinding`, `wave-manager`, `inventory`, `resource-economy`, `mission-hud` [skeleton], `systems-index`, `gdd-cross-review-2026-05-15`)
**ADRs Reviewed**: 15 present — `ADR-0001`–`ADR-0010`, `ADR-0012`–`ADR-0017`. **`ADR-0011` is missing** (referenced by ADR-0010 as "UI dual-focus"; listed as "Deferred" in `architecture-traceability.md` but never authored).
**Mode**: full

---

## ADR Status Snapshot

| ADR | Title | Status |
|-----|-------|--------|
| 0001 | EventBus architecture | ✅ Accepted |
| 0002 | Scene & Autoload structure | ✅ Accepted (revised 2026-05-23, 2026-05-24) |
| 0003 | Save file format | ✅ Accepted |
| 0004 | Pathfinding strategy | ✅ Accepted |
| 0005 | Grid data model | ✅ Accepted |
| 0006 | Monster movement | ✅ Accepted |
| 0007 | Damage pipeline | ✅ Accepted |
| 0008 | Tower placement gate | ✅ Accepted |
| 0009 | Resource data model | ✅ Accepted |
| 0010 | Hero Tower-Synced Class + Tower Affinity | ✅ Accepted |
| 0011 | UI dual-focus | ❌ Missing — referenced, never authored |
| 0012 | Wave Manager FSM | ✅ Accepted |
| 0013 | Sprite atlas / draw-call batching | ✅ Accepted |
| 0014 | Pause system | ✅ Accepted |
| 0015 | Collision layer convention | ✅ Accepted |
| 0016 | Inventory storage model | 🟡 Proposed |
| 0017 | Resource Economy drop resolution | 🟡 Proposed |

All four issues raised by the prior review (`architecture-review-2026-05-24.md`) are confirmed **resolved** in the current text: ADR-0002's scene hierarchy no longer lists WaveManager as a scene child; the Accepted→Proposed dependency inversion is gone now that 0006/0007/0009/0012 are Accepted; ADR-0001 Rule 2 now explicitly sanctions `await get_tree().process_frame` alongside `call_deferred`; and ADR-0006's engine-verification note now covers both D3D12 and Vulkan.

---

## Traceability Summary

| Status | Count | % |
|--------|-------|---|
| ✅ Covered | 58 | 92% |
| ⚠️ Partial | 2 | 3% |
| ❌ Gap | 3 | 5% |
| **Total** | **63** | 100% |

The base 57 TRs are unchanged from `tr-registry.yaml` v3 (2026-05-24) and remain accurate against the current ADR text. Six new candidate TRs were identified for `inventory.md` and `resource-economy.md`, which were authored (2026-07-10/11) after the registry was last updated and had never been registered.

### Coverage Gaps (no ADR — pre-existing, unchanged)

| TR | Requirement | Disposition |
|----|-------------|-------------|
| ❌ TR-hero-005 | 4 active skills + Ultimate | Alpha-tier (Hero Skill Build) — not MVP, expected |
| ❌ TR-ds-004 | 5 status effect types + stack/duration | Out of scope in ADR-0007; needs its own ADR when the status system is designed |
| ❌ TR-gc-004 | 15–25 min session-length formula | Design tuning, not architecture — no ADR required |

### Partial Coverage (pre-existing, unchanged)

| TR | Requirement | Why partial |
|----|-------------|-------------|
| ⚠️ TR-tower-005 | Pre-placement perk (Scout-only) | Perk data schema is in ADR-0009; the Scout-phase-only *activation rule* has no ADR |
| ⚠️ TR-path-007 | 100+ agents @ 60 FPS | Architecturally sound (O(1) templates + Area2D + 4-pass); S4-10 profiling evidence already cited in `pathfinding.md` OQ-6, but no fresh evidence reviewed this pass |

### New Requirements Found — Newly Registered This Pass

| TR | GDD | Requirement | ADR Coverage | Status |
|---|---|---|---|---|
| TR-inv-001 | inventory.md | 10-slot start; type-driven stack caps (1 vs 99) | ADR-0016 | ✅ (Proposed) |
| TR-inv-002 | inventory.md | `instance_id`-keyed unique-item identity — stat-rolled duplicates never merge (AC-18) | ADR-0016 | ✅ (Proposed) |
| TR-inv-003 | inventory.md | `SaveRestorer` interface + `restore_order` ordering constraint (below Hero's 30) | ADR-0016 | ⚠️ Partial — conflicts with `save-persistence.md`'s own Formula 4 table (see Conflict 1) |
| TR-econ-001 | resource-economy.md | Stateless calculator pattern (Core Rule 1) | ADR-0017 | ✅ (Proposed) |
| TR-econ-002 | resource-economy.md | `DropTableResource`/`DropEntry` schema + Formulas 1–4 | ADR-0017 | ✅ (Proposed) |
| TR-econ-003 | resource-economy.md | Gold track via `resources_changed`, separate from materials | ADR-0017 | ⚠️ Partial — gold-balance ownership explicitly unresolved (ADR-0017 Open Questions) |

Both ADR-0016 and ADR-0017 are `Proposed`. Per `docs/CLAUDE.md`'s status lifecycle rule ("Never skip `Accepted` — stories referencing a `Proposed` ADR are auto-blocked"), every Epic 03 story governed by them should currently be blocked. **Checked against the actual story files — this is not the case**: 13 of Epic 03's 15 stories (all Inventory stories except 007, all Resource Economy stories except 013) are marked `Status: Ready`, unblocked the moment each ADR was written, while still `Proposed`. Only story-007 (blocked on the still-missing ADR-0011) and story-013 (blocked on the unresolved gold-balance-ownership question) remain `Blocked`. This is a real process-gate violation, not a documentation gap — see Finding 4 below.

---

## Cross-ADR Conflicts

### 🔴 Conflict 1 — ADR-0016 vs `save-persistence.md`: `restore_order` collision
**Type**: Integration contract conflict
**ADR-0016 claims**: Inventory registers at `restore_order = 20` ("below Hero's 30").
**`save-persistence.md` claims** (Formula 4, the canonical Approved assignment table): Inventory = **10**, Menagerie = **20**.
**Impact**: If implemented as written, Inventory and Menagerie collide at restore priority 20, and Inventory would restore *after* Mission Select (11) instead of before it — reversing the GDD's own stated rationale ("Crafting, Menagerie, Equipment Forge all depend on Inventory state").
**Resolution options**:
1. Change ADR-0016's assigned value from 20 to 10 (matches the GDD; no other system currently claims 10). **Recommended.**
2. Re-derive `save-persistence.md`'s table if 10 is unsuitable for some undocumented reason.

### 🟡 Conflict 2 — ADR-0017 misstates ADR-0012/ADR-0002 as precedent
**Type**: Architecture pattern conflict (factual misattribution, not a functional break)
**ADR-0017 claims**: Resource Economy is scene-instanced, "mirroring Wave Manager's own non-Autoload, per-mission lifecycle (ADR-0012)."
**Reality**: ADR-0002 (Accepted, revised 2026-05-24) and ADR-0012 (Accepted) both establish **WaveManager as Autoload #7** — its per-mission behavior comes from an IDLE-state reset (EC-9), not from being scene-instanced.
**Impact**: The actual decision (Resource Economy = scene-instanced) is independently correct and already matches ADR-0002's own Autoload/Scene-Instanced boundary table, so nothing is architecturally broken today — but the false precedent could mislead a future ADR author copying the pattern for a Wave-Manager-adjacent system.
**Resolution**: Strike the Wave Manager comparison from ADR-0017's Decision section, or replace it with the correct citation (ADR-0002's boundary table already classifies Resource Economy as scene-instanced directly).

### 🟡 Finding 3 — ADR-0009's illustrative `MonsterResource` schema has drifted from `monster.md`
**Type**: Documentation drift
ADR-0009's Key Interfaces snippet for `MonsterResource` omits `drop_table_id`, `base_attack_interval`, and `boss_attack_range_cells` (all load-bearing per `monster.md` Rule 2 — the first is exactly the field ADR-0017 depends on: *"`MonsterResource.drop_table_id` (already an existing field per `monster.md`)"*), and includes two fields `monster.md` doesn't define (`drop_chance`, `wave_scale_factor`).
**Impact**: Low today — both ADR-0017 and the shipped Monster code correctly use the real schema — but an implementer coding strictly from ADR-0009's snippet would build an incomplete Resource.
**Resolution**: Update ADR-0009's example to match `monster.md` Rule 2 exactly, or drop the field list entirely and reference `monster.md` as the sole schema source of truth.

### 🔴 Finding 4 — 13 Epic 03 stories are `Ready` against `Proposed` ADRs (process-gate violation)
**Type**: Process / gate conflict, not a design or engine issue.
`docs/CLAUDE.md` states: *"Status lifecycle: `Proposed` → `Accepted` → `Superseded` — Never skip `Accepted` — stories referencing a `Proposed` ADR are auto-blocked."* ADR-0016 and ADR-0017 are both still `Proposed`. Grepping the actual story files in `production/epics/epic-03-core-economy/` shows 13 of 15 stories already carry `Status: Ready` (only story-007 and story-013 are `Blocked`, and for unrelated reasons — missing ADR-0011 and the unresolved gold-balance question, respectively). The session log confirms this was intentional in the moment ("6 of 7 Inventory stories unblocked → Status: Ready" / "7 of 8 Resource Economy stories unblocked → Status: Ready", both logged immediately after writing each Proposed ADR) — but it contradicts the project's own documented gate.
**Impact**: If implementation on any of those 13 stories starts now, it would be built against ADR-0016/0017 exactly as currently written — including the `restore_order` collision (Conflict 1) and the incorrect precedent (Conflict 2) — before those are fixed or the ADRs are formally Accepted.
**Resolution options**:
1. Accept ADR-0016 and ADR-0017 now (after fixing Conflicts 1–2) — this retroactively legitimizes the 13 `Ready` stories and is the lowest-friction path since the design content itself is sound.
2. Revert the 13 stories to `Blocked` until the ADRs are formally Accepted, strictly following the documented gate.
Recommend option 1 — the conflicts are small, cheap fixes, not a sign the ADRs need re-design.

No blocking (Foundation/Core) conflicts were found. Foundation-layer ADRs (0001–0005) remain internally consistent.

---

## ADR Dependency Order (topologically sorted)

```
Foundation (no deps):
  ADR-0001  EventBus
  ADR-0015  Collision layer convention (documentation-only promotion, no deps)
Depends on Foundation:
  ADR-0002  Scene/Autoload   ADR-0003  Save format   ADR-0005  Grid   ADR-0004  Pathfinding
Core gameplay:
  ADR-0006  Monster  →  ADR-0007  Damage  →  ADR-0009  Resource model  →  ADR-0010  Hero Tower-Synced Class
  ADR-0008  Tower placement gate
Feature:
  ADR-0012  Wave Manager FSM (← 0001, 0002, 0004, 0009)
  ADR-0013  Draw-call batching (← 0002)
  ADR-0014  Pause system (← 0001, 0012)
  ADR-0016  Inventory storage model (← 0003, 0009)  — Proposed
  ADR-0017  Resource Economy drop resolution (← 0001, 0009)  — Proposed
```

No dependency cycles. No unresolved Accepted-depends-on-Proposed inversions remain — the two Proposed ADRs (0016, 0017) are leaves that nothing else currently depends on.

---

## GDD Revision Flags

None — no verified engine behavior or Accepted ADR contradicts a GDD assumption this pass.

---

## Engine Compatibility Issues

- All 15 ADRs declare Godot 4.6.2 and include a complete Engine Compatibility section — no blind spots.
- Post-cutoff APIs are consistently flagged and guarded: `FileAccess.store_*` bool returns (ADR-0003), `Resource.duplicate_deep()` 4.5+ (ADR-0008, correctly reused by ADR-0016's reasoning), typed `Dictionary[K,V]` (ADR-0009/0010/0016/0017 — already verified working per `VERSION.md`'s Project-Specific API Tracking table).
- ADR-0006's BOSS-overlay verification note now correctly covers both D3D12 (Windows 4.6 default) and Vulkan — the gap flagged in the prior review is fixed.
- No deprecated-API usage found (`TileMap`→`TileMapLayer`, `duplicate()`→`duplicate_deep()` are all handled correctly).
- Minor cosmetic drift: ADR-0001 and `TR-eb-001` still say "70-event catalogue"; `event-bus.md`'s own running total is now **72** (Pause System events added 2026-07-08). Not functionally significant — update the count next time either file is touched.

*(Engine-specialist sub-agent consultation was not run this pass, consistent with the precedent set in the 2026-05-24 review; findings above are from inline audit against the loaded engine reference docs.)*

---

## Architecture Document Coverage

- `docs/architecture/architecture.md` already self-flags that its Traceability Matrix predates `inventory.md`/`resource-economy.md` and ADR-0016/0017 (header note dated 2026-07-13) — confirmed accurate; needs a refresh pass.
- `docs/architecture/architecture-traceability.md` was current through ADR-0012 (2026-05-24) but did not include the 6 new candidate TRs above — refreshed as part of this review.
- `docs/architecture/control-manifest.md` is **stale**: `Last Updated: 2026-05-16`, `ADRs Covered: 0001–0004` only. Thirteen more ADRs have been Accepted since (0005–0010, 0012–0015) with binding Required/Forbidden rules (Grid write gate, Tower placement gate, Monster 4-pass architecture, Pause `SceneTree.paused` convention, collision layer table) that are currently invisible to it. This is the most actionable gap from this review.

---

## Blocking Issues

None (no FAIL-level items). Foundation and Core layers are 100% covered by Accepted ADRs with no unresolved contradictions.

---

## Required ADRs / Actions (priority order)

1. **Fix ADR-0016's `restore_order`** (20 → 10) before Accepting — Conflict 1.
2. **Correct ADR-0017's Wave Manager precedent citation** before Accepting — Conflict 2.
3. **Accept ADR-0016 and ADR-0017** — this is the fastest path to close Finding 4 (13 stories already `Ready` against Proposed ADRs) without reverting any story status.
4. **Regenerate `control-manifest.md`** via `/create-control-manifest` — 13 Accepted ADRs are currently invisible to it.
5. Author **`ADR-0011` (UI dual-focus)** or formally retire the placeholder — it's referenced by ADR-0010 and listed as "Deferred" in `architecture-traceability.md` but no file exists. Story-007 stays `Blocked` on this regardless.
6. (Low priority, pre-existing) An ADR for the Scout-only perk-activation rule (`TR-tower-005`) and a future status-effects ADR (`TR-ds-004`) when that system is designed.

---

## Verdict: **CONCERNS**

No Foundation or Core requirement is uncovered, and no blocking cross-ADR contradiction exists in the Accepted set. The CONCERNS come from: the two newest ADRs (0016, 0017) still being `Proposed` while 13 stories are already `Ready` against them in violation of the project's own status-lifecycle gate (Finding 4); two real-but-cheap-to-fix inconsistencies inside those ADRs (Conflicts 1–2); a documentation-drift item (Finding 3); and the control manifest lagging 13 Accepted ADRs.

---

## Handoff

**Immediate actions (highest-impact first):**
1. Fix ADR-0016 (`restore_order`) and ADR-0017 (Wave Manager citation), then Accept both.
2. Regenerate `control-manifest.md`.
3. Decide the fate of `ADR-0011` (author or retire the reference).

**Gate guidance**: When ADR-0016/0017 are Accepted and the control manifest is refreshed, run `/gate-check pre-production` to advance for Epic 03.

**Rerun trigger**: Re-run `/architecture-review` after ADR-0016/0017 are Accepted to confirm Epic 03 stories fully unblock.

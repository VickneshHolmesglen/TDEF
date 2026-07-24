# Architecture Review Report — 2026-07-13 (Pass 2, full run)

> **Note**: An earlier `/architecture-review` pass ran earlier today and was written to
> `architecture-review-2026-07-13.md`. That pass predates ADR-0011 (UI Dual-Focus) and
> ADR-0018 (Mission Economy) being written, and predates ADR-0016/0017 moving from
> Proposed to Accepted — its own addendum confirms those items resolved. This is a
> fresh full pass run against the current state (all 18 ADRs Accepted) and supersedes
> the earlier pass's findings. Where this pass's findings differ, this document is current.

**Date:** 2026-07-13
**Engine:** Godot 4.6.2
**GDDs Reviewed:** 12 (event-bus, grid-system, save-persistence, hero, tower, monster, damage-status, pathfinding, inventory, resource-economy, wave-manager, mission-hud [skeleton]) + game-concept.md TRs carried from registry
**ADRs Reviewed:** 18 (ADR-0001–0018, all Accepted)
**Mode:** `/architecture-review` (full)

---

## Summary

This review found the project's ADR set to be dense and largely well-covered (60/65 requirements ✅, 1 ⚠️, 4 ❌ — mostly deliberate MVP deferrals). However, **Phase 4 cross-ADR conflict detection surfaced two genuine, implementation-breaking contradictions** that `docs/architecture/architecture.md`'s own self-audit (last updated today, same date as this review) does not catch, because that document validates "does an ADR exist per requirement" but does not diff contracts between ADRs that touch the same signal or interface. This review's verdict differs from `architecture.md`'s implicit PASS as a result. These are new findings not raised by the earlier same-day pass, which focused on ADR-0016/0017/0011 (now all resolved and Accepted).

---

## Traceability Summary

Total requirements traced: 65 (64 existing in `tr-registry.yaml` v4 + 1 newly assigned: TR-tower-007)

| Status | Count |
|---|---|
| ✅ Covered | 60 |
| ⚠️ Partial | 1 |
| ❌ Gap | 4 |

## Coverage Gaps

- ❌ **TR-tower-007** (NEW): Projectile pooling + re-acquisition rate limit. `tower.md` Rules 18/19 firmly mandate a fixed-size pool (`projectile_pool_size=192`) and `max_reacquisitions_per_frame=8`. No ADR or prior registry entry existed.
  Suggested ADR: `/architecture-decision projectile-pooling-strategy` · Domain: Performance · Engine Risk: LOW
- ❌ **TR-hero-005**: 4 active skills + Ultimate combination system — no ADR. Non-blocking: Alpha-tier / post-MVP per `systems-index.md`. Defer until Hero Skill Build GDD exists.
- ❌ **TR-ds-004**: 5 status effect types — deliberately deferred out of MVP scope (damage-status.md Rule 3; ADR-0007 explicitly scopes it out). Expected, non-blocking.
- ❌ **TR-gc-004**: 15–25 min session length — a design/balance target, not an architectural requirement. Recommend reclassifying out of the TR registry (flagged for user decision, not auto-changed).
- ⚠️ **TR-tower-005** (Partial): Pre-placement perk data schema is covered by ADR-0009, but the Scout-phase-only *activation timing* rule has no dedicated architectural decision.

---

## Cross-ADR Conflicts

### 🔴 BLOCKING — ADR-0005 vs ADR-0008 vs ADR-0010 — `tower_id` type & signal arity
**Type:** Integration contract + Data type · **Layer:** Foundation (Grid) / Core (Tower, Hero)

Three ADRs, each internally consistent, mutually incompatible:
- **ADR-0005 (Grid)**: `tower_id: int`. `place_tower(tower_id: int, top_left: Vector2i, size: Vector2i) -> Error`; `_occupancy: Dictionary[Vector2i, int]`; `get_occupant(cell) -> int`.
- **ADR-0008 (Tower placement gate)**: `tower_id: String`. `place_tower(tower_id: String, top_left) -> bool` — calls `Grid.place_tower(tower_id, ...)`, passing a **String into Grid's int-typed parameter**. Emits `EventBus.tower_placed.emit(tower_id, top_left, tower_data.archetype)` and `EventBus.tower_removed.emit(tower_id, archetype)` (2-arg).
- **ADR-0010 (Hero)**: expects `int` id, **different argument order**: `_on_tower_placed(tower_id: int, archetype: StringName, cell: Vector2i)`; `_on_tower_removed(tower_id: int)` (**1-arg**). `_tower_cache` keyed by `int`.

**Impact:** With static typing this fails at connect-time or silently misbinds (`archetype` read from the `top_left`/`cell` slot); `tower_removed` arity differs (2 vs 1); ADR-0008 passes a String into Grid's int-typed API, which either fails typing or corrupts `_occupancy`. ADR-0010 defers to "ADR-0008 as authoritative," but ADR-0008's own contract already contradicts ADR-0005 — deferring relocates the mismatch rather than resolving it.

**Resolution options:**
1. Freeze one canonical `tower_placed(tower_id: int, archetype: StringName, cell: Vector2i)` / `tower_removed(tower_id: int, archetype: StringName)` contract in `event-bus.md`. Give Tower a separate `String blueprint_id` for data/UI lookup, distinct from the `int` runtime entity id passed to Grid and the bus. Revise ADR-0008 and ADR-0010 to match.
2. Convert Grid's occupancy map to String-keyed — larger blast radius (Constellation and Tower Mastery both consume `Array[int]` from Grid today).

### 🔴 BLOCKING — ADR-0003 vs ADR-0016 / ADR-0017 / ADR-0010 — SaveRestorer interface drift
**Type:** Integration contract + State management · **Layer:** Foundation (Save & Persistence)

ADR-0003, the authoritative save-format ADR, specifies `get_save_data() -> Dictionary` + **`apply_save_data(data[key])`**, assembled into a static hardcoded master Dictionary of fixed top-level keys. It has **no** `get_save_key()`, `register()`, `restore_order`, or `reset_to_defaults()`.

ADR-0016 (Inventory) and ADR-0017 (Resource Economy) instead specify a **`SaveRestorer` registration pattern**: `get_save_key()` / `get_save_data() -> Dictionary` / **`restore_save_data(data) -> bool`** / `reset_to_defaults()`, registered via `SavePersistence.register(self, restore_order)`. ADR-0016 explicitly (and incorrectly) cites this as "the already-Accepted SaveRestorer pattern (ADR-0003)" — ADR-0003 as written contains none of it. ADR-0010 (Hero) likewise depends on ordered restore (`restore_order = 30`), a concept ADR-0003 doesn't define.

**Impact:** Implementing literally to ADR-0003 produces a system Inventory/Resource-Economy/Hero cannot register with — different restore method name, different registration model, no ordering mechanism. Per the git history, `S2-02 SavePersistence autoload` already shipped with the `SaveRestorer` pattern, so **the code is right but ADR-0003 doesn't describe what was actually built** — any future implementer reading ADR-0003 in isolation will get it wrong.

**Resolution options:**
1. Revise ADR-0003 to formally adopt the `SaveRestorer` interface (`get_save_key`/`get_save_data`/`restore_save_data`/`reset_to_defaults`/`register(self, restore_order)`) as canonical — recommended, matches shipped code.
2. Mark ADR-0003's interface section as superseded by a new dedicated ADR and repoint 0010/0016/0017's dependencies to it.

### 🟡 Non-blocking — ADR-0010 vs ADR-0008 — dangling `tower_destroyed` subscriber
Hero (ADR-0010) subscribes to `EventBus.tower_destroyed` to prune `_tower_cache` on mid-wave tower death. No ADR — including ADR-0008, the tower-lifecycle owner — ever emits it. ADR-0010 itself lists it as a "catalogue addition needed" with no assigned emitter.
**Resolution:** Assign `tower_destroyed(tower_id, archetype)` emission to Tower/D&S in a future combat ADR, or drop the subscription if mid-wave tower destruction is out of MVP scope.

### 🟡 Non-blocking — ADR-0010 vs ADR-0006 — frame-budget rule scoping
ADR-0010 states a blanket "`_physics_process` budget for all non-physics systems ≤ 0.3 ms/frame." ADR-0006's MonsterManager (deliberately non-physics per its own text — Area2D, no solver interaction) is budgeted 2–4 ms, 7–13× over that blanket rule. No actual frame-budget overrun (≈4ms of 16.67ms total), just an inconsistently-scoped *rule* that would flag an already-Accepted decision as a violation if enforced literally.
**Resolution:** Reword ADR-0010's constraint to scope to Hero specifically, or add a per-system budget table to the control manifest.

### ⚪ Cosmetic — ADR-0010's "restore_order = 30, after Grid = 25"
Grid has no save state at all (ADR-0005 and ADR-0016's own restore-order table both confirm this — no Grid=25 entry exists). Phantom anchor; strike it and anchor Hero=30 against the real registry (Tower=23 is the nearest lower entry).

### ⚪ Confirmed by godot-specialist — ADR-0006 vs ADR-0013 — BOSS overlay atlas sharing
ADR-0006's BOSS uses a second stacked `AnimatedSprite2D` with a distinct overlay `SpriteFrames`. ADR-0013 (shared per-class atlas for draw-call batching) doesn't state whether the overlay draws from the shared monster atlas. Not a contradiction — an unclosed integration point. If unresolved, adds ≤1 draw call per BOSS instance (low severity at MVP BOSS counts, worth a one-line clarification before art production locks in).

### ⚪ Confirmed by godot-specialist — ADR-0005 self-contradiction on typed Dictionary declaration
ADR-0005 uses `Dictionary[Vector2i, CellType]` (a 4.4+ typed-Dictionary feature) but its own "Post-Cutoff APIs Used" field says "None." Documentation bug, not a functional one — fix the field.

### ⚪ Confirmed by godot-specialist — ADR-0010 cites nonexistent reference doc
ADR-0010 lists `docs/engine-reference/godot/modules/core.md` under References Consulted — that file does not exist (`modules/` contains only animation, audio, input, navigation, networking, physics, rendering, ui). ADR-0016/0017/0018 correctly state no such file exists. Fix ADR-0010 to cite `VERSION.md` like its siblings.

**Areas checked and found clean:** EventBus dispatch timing consistency (ADR-0001/0007); Grid/GameDataRegistry/MissionEconomy direct-call read exceptions to EventBus-only (consistently documented across ADR-0005/0009/0018); collision-layer monster exemption (ADR-0002/0006/0015 agree); pause via `SceneTree.paused` (ADR-0014 resolves, not contradicts, ADR-0012's flagged `create_timer` risk); drop-table two-tier Resource model (ADR-0009/0016/0017 consistent); `duplicate_deep()` semantics (ADR-0008/0016 agree).

---

## ADR Dependency Order

All 18 ADRs Accepted. No dependency points at a Proposed or nonexistent ADR. No dependency cycles.

```
Foundation (no dependencies):
  1. ADR-0001: EventBus Architecture
  2. ADR-0011: UI Dual-Focus Handling
  3. ADR-0015: Collision Layer Convention

Depends on Foundation:
  4. ADR-0002: Scene and Autoload Structure (requires ADR-0001)

Depends on ADR-0002 layer:
  5. ADR-0003: Save File Format (requires ADR-0001, 0002)
  6. ADR-0004: Pathfinding Strategy (requires ADR-0001, 0002)
  7. ADR-0005: Grid System Data Model (requires ADR-0001, 0002)
  8. ADR-0013: Sprite Atlas / Draw-Call Batching (requires ADR-0002)

Depends on Grid + Pathfinding:
  9. ADR-0006: Monster Movement (requires ADR-0001, 0004, 0005)

Depends on Monster / Grid / Pathfinding:
 10. ADR-0007: Damage Pipeline (requires ADR-0001, 0006)
 11. ADR-0008: Tower Placement Gate (requires ADR-0001, 0004, 0005)

Depends on Monster + Tower:
 12. ADR-0009: Resource Data Model (requires ADR-0002, 0006, 0008)

Depends on Resource Data Model:
 13. ADR-0012: Wave Manager FSM (requires ADR-0001, 0002, 0004, 0009)
 14. ADR-0016: Inventory Storage Model (requires ADR-0003, 0009)
 15. ADR-0017: Resource Economy Drop Resolution (requires ADR-0001, 0009)
 16. ADR-0010: Hero Tower-Synced Class (requires ADR-0001, 0002, 0005, 0007, 0008, 0009)

Depends on Wave Manager / Resource Economy:
 17. ADR-0014: Pause System (requires ADR-0001, 0012)
 18. ADR-0018: Mission Economy Gold Balance (requires ADR-0001, 0002, 0012, 0017)
```

**Observations:**
- ADR-0002's boot-order table is a moving target — revised by ADR-0009 (added GameDataRegistry #5, SceneManager #6), ADR-0012 (WaveManager #7), ADR-0018 (MissionEconomy #8). Not a cycle, but shouldn't be treated as final until implementation reaches ADR-0018.
- ADR-0011 and ADR-0015 are true orphans (no deps, nothing critical depends on them) — implementable at any time. ADR-0011 is loosely (and per its own text, incorrectly) referenced by ADR-0010's "Enables" line.

---

## GDD Revision Flags

None. The two open engine-verification items (`FileAccess.open()` for Save & Persistence; glow rework / emissive-to-bloom for hero.md/tower.md VFX) are already correctly tracked as ⚠️ Verification Required in `VERSION.md` and are not contradicted by any *Accepted* ADR — no shader/VFX ADR exists yet to conflict with them. No new revision flags from this pass.

---

## Engine Compatibility Issues

```
Engine: Godot 4.6.2
ADRs with Engine Compatibility section: 18 / 18 total — no blind spots
Stale Version References: NONE
Deprecated API references selected for implementation: NONE
Post-Cutoff API contradictions between ADRs: NONE
```

Benign mentions of deprecated APIs (Navigation2D, TileMap, Resource.duplicate() for nested resources) all appear only as explicitly rejected alternatives in ADR-0004/0005/0008 — none selects a deprecated API for implementation.

**Minor documentation issues found:**
- ADR-0005 declares "Post-Cutoff APIs Used: None" while its own code uses `Dictionary[Vector2i, CellType]` (4.4+ typed Dictionary). Self-contradictory field — confirmed by godot-specialist as the one real instance of this pattern (ADR-0010/0016/0017 are correctly declared/non-applicable as written).
- ADR-0010 cites a nonexistent `docs/engine-reference/godot/modules/core.md`.

### Engine Specialist Findings (godot-specialist consultation)

- **Confirmed, endorsed:** ADR-0006's Area2D + direct `global_position` movement over `move_and_slide()`/Jolt is well-reasoned — `move_and_slide()` would violate the co-occupancy requirement (EC-1.3), and Jolt-solver determinism at 100+ interacting bodies is a real concern.
- **Confirmed:** No 2D system makes a Jolt-3D-default assumption; every ADR touching physics scene roots correctly scopes Jolt as 3D-only.
- **Confirmed, standout quality:** ADR-0011 (UI dual-focus) correctly models Godot 4.6's mouse/keyboard-gamepad focus split, and deliberately uses `_input()` over `_unhandled_input()` for a documented reason (stops mouse-filter consumption). Self-corrects a stale claim in ADR-0010.
- **Confirmed:** BOSS overlay atlas sharing (see conflicts section) is a genuine unresolved risk, low severity.
- **New finding:** No IK-touching ADR exists — correctly, since the game is 2D top-down and IK restoration in 4.6 is 3D-only. Confirmed as a non-issue rather than an oversight.
- **New finding:** No autoload/threading misassumptions found — `dispatch_deferred` from `_physics_process` is correctly framed as same-thread deferred-call semantics, not multithreading.

**Open, non-blocking, already-tracked items (carried from VERSION.md, not resolved by this review):**
- `FileAccess.open()` behavior for Save & Persistence — recommend the targeted smoke test VERSION.md calls for before the next Save code change.
- Glow rework / emissive-to-bloom mapping (4.6) — no VFX/shader ADR exists yet; remains an open Presentation-layer risk.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (v3, last updated 2026-07-13) covers all 25 systems from `systems-index.md` in its Layer Diagram; its Data Flow section covers all cross-system EventBus scenarios (frame update, event/signal, save/load, initialization order); its API Boundaries section specifies contracts for every Foundation/Core system. No orphaned architecture — nothing in `architecture.md` lacks a corresponding GDD.

**However:** `architecture.md`'s "ADR Audit" section claims 58/63 coverage with zero cross-ADR conflicts. This review's Phase 4 pass found two blocking contradictions (`tower_id` type/arity; SaveRestorer interface drift) that `architecture.md` does not surface anywhere. That section should be corrected once the two blocking conflicts are resolved, and its "ADR Audit" methodology should incorporate contract-diffing (not just requirement-to-ADR existence checks) in future revisions.

---

## Verdict: FAIL

Two conflicts are genuinely blocking, not documentation debt — both sit in Foundation/Core (Grid, Tower, Hero, Save & Persistence) and would produce broken signal connections or silent data corruption if implemented exactly as the current ADRs read.

### Blocking Issues (must resolve before PASS)

1. **`tower_id` type/arity conflict** across ADR-0005 (Grid, Foundation) / ADR-0008 (Tower, Core) / ADR-0010 (Hero, Core). Freeze one canonical `tower_id: int` contract and one frozen `tower_placed`/`tower_removed` signal signature in `event-bus.md`, then revise the non-canonical ADRs to match.
2. **SaveRestorer interface drift** — ADR-0003 (Foundation) does not describe the interface ADR-0010/0016/0017 (and the already-shipped S2-02 code) actually use. Revise ADR-0003 to formally adopt the `SaveRestorer` pattern as canonical.

### Required ADRs

1. **Revise ADR-0003** — adopt `SaveRestorer` interface as canonical (matches shipped code). Highest priority: Foundation layer, blocks correct understanding of the already-shipped Save system.
2. **Revise ADR-0005 and/or ADR-0008/ADR-0010** — resolve the `tower_id` contract. Second priority: Foundation/Core, affects Tower and Hero implementation directly.
3. **New ADR: `projectile-pooling-strategy`** — closes the TR-tower-007 gap (Tower GDD firmly mandates pooling; no decision exists).
4. **Minor fix-ups** (non-blocking, low effort): ADR-0010's dangling `tower_destroyed` publisher; ADR-0010/ADR-0006 frame-budget rule scoping; ADR-0010's phantom "Grid=25" restore_order reference; ADR-0005's Dictionary[K,V] self-declaration; ADR-0010's broken `modules/core.md` citation; BOSS overlay atlas-sharing clarification (ADR-0006/ADR-0013).

---

## Handoff

**Immediate actions (top 3, highest-impact first):**
1. Revise ADR-0003 to adopt the SaveRestorer interface as canonical.
2. Resolve the `tower_id` contract across ADR-0005/0008/0010.
3. Write `/architecture-decision projectile-pooling-strategy` to close TR-tower-007.

**Gate guidance:** Once the two blocking conflicts are resolved (and the two ADR revisions are Accepted), re-run `/architecture-review` to confirm the FAIL clears before running `/gate-check pre-production`.

**Rerun trigger:** Re-run `/architecture-review` after each ADR revision/addition to verify the blocking conflicts are closed and coverage remains intact.

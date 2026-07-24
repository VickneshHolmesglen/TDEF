# Architecture Review Report — 2026-07-13 (Pass 3, confirmation run)

> **Context**: Pass 2 (`architecture-review-2026-07-13b.md`) found the project at **FAIL**
> due to two blocking cross-ADR conflicts. Both were resolved same-day via targeted ADR
> revisions: ADR-0003 (SaveRestorer interface), and ADR-0008/ADR-0010 (`tower_id` type/arity).
> This pass re-verifies both fixes against the shipped code and the canonical GDD catalogue,
> and re-confirms the rest of Pass 2's findings still hold (nothing else changed — no new
> GDDs or ADRs were added between Pass 2 and this pass, only text corrections to 3 existing
> Accepted ADRs).

**Date:** 2026-07-13
**Engine:** Godot 4.6.2
**ADRs Reviewed:** 18 (ADR-0001–0018, all Accepted; ADR-0003/0008/0010 re-verified post-revision)
**Mode:** `/architecture-review` (confirmation re-run)

---

## Re-Verification of Pass 2's Blocking Conflicts

### 1. `tower_id` type/arity conflict — CONFIRMED RESOLVED

Re-read ADR-0005 (unchanged — already correct), and the revised ADR-0008/ADR-0010. Cross-checked all three against:
- Shipped `src/foundation/grid/grid.gd`: `place_tower(tower_id: int, top_left: Vector2i, size: Vector2i) -> Error` — matches ADR-0005 exactly (never needed revision).
- Shipped `src/core/tower/tower_system.gd`: `place_tower(blueprint_id: StringName, top_left: Vector2i) -> bool` mints its own runtime `int tower_id` via `_tower_id_counter`, passes that `int` to `Grid.place_tower()` — matches ADR-0008's revised Decision exactly.
- Shipped `src/foundation/event_bus/event_bus.gd`: `tower_placed(tower_id: int, grid_position: Vector2i, archetype: String, footprint: Vector2i, placed_in_scout: bool)` (5 args), `tower_removed(tower_id: int, grid_position: Vector2i, archetype: String)` (3 args), `tower_destroyed(tower_id: int, grid_position: Vector2i, archetype: String, footprint: Array)` (4 args) — matches both revised ADRs' signal listings exactly.
- **Canonical GDD source** `design/gdd/event-bus.md`'s signal catalogue table (lines 100–102): same 5/3/4-arg signatures, same types — confirms the ADRs are now consistent not just with shipped code but with the design source of truth.
- Shipped `src/core/hero/hero.gd`: `_on_tower_placed`/`_on_tower_removed`/`_on_tower_destroyed` handler signatures match the emitted signals exactly, including the `String → StringName` conversion for the cache entry.

Grepped `docs/architecture/` for any remaining `tower_id: String` or `place_tower(tower_id: String` references — only match is inside ADR-0008's own revision-note quoting the *old, superseded* text for context. No stragglers found in ADR-0005, ADR-0009, ADR-0013, or `architecture.md`.

**Verdict: RESOLVED, no new issues found.**

### 2. SaveRestorer interface drift — CONFIRMED RESOLVED

Re-read the revised ADR-0003. Its Decision section now documents `get_save_key()` / `get_save_data()` / `restore_save_data()` / `reset_to_defaults()` / `register(self, restore_order)` — matching shipped `src/foundation/save_persistence/save_persistence.gd` exactly (re-confirmed by direct read during the revision), and matching what ADR-0010/0016/0017 already depended on. The `restore_order` band table (Foundation 0–9 / Core 10–49 / Feature 50+) is now the single source of truth ADR-0010 references for its own `restore_order = 30` justification (its earlier phantom "after Grid = 25" anchor was also removed in the same pass).

**Verdict: RESOLVED, no new issues found.**

---

## Traceability Summary (unchanged from Pass 2 — no GDDs or new ADRs since)

| Status | Count |
|---|---|
| ✅ Covered | 60 |
| ⚠️ Partial | 1 |
| ❌ Gap | 4 |

Gaps unchanged and all non-blocking: **TR-tower-007** (projectile pooling — new ADR still needed, not written yet), **TR-hero-005** (Alpha-tier, post-MVP), **TR-ds-004** (deliberately deferred), **TR-gc-004** (design tuning, not architecture — still flagged for reclassification, not yet actioned). Partial: **TR-tower-005** (Scout-only perk activation timing rule — data schema covered, activation rule still lacks its own decision).

None of these block a PASS verdict — none are Foundation/Core requirements left uncovered, and none represent a cross-ADR contradiction.

---

## Cross-ADR Conflicts — none found (re-swept)

Both Pass 2 blocking conflicts are resolved (see above). Re-checked the areas Pass 2 flagged as "clean" to confirm the ADR-0008/0010 edits didn't introduce anything new:
- EventBus dispatch timing, Grid/GameDataRegistry/MissionEconomy direct-call exceptions, collision-layer exemptions, pause/timer interaction, drop-table Resource model, `duplicate_deep()` semantics — all still consistent, untouched by this pass's edits.
- New informational item surfaced during the ADR-0008 revision (not a conflict, just newly documented): Gate 2 (resource check) uses `TowerSystem`'s own locally-cached `_player_gold`, not `MissionEconomy.can_afford()`. `MissionEconomy` (ADR-0018, Accepted 2026-07-13) has not yet been implemented (no `mission_economy.gd` exists). This is a pending follow-up once that Autoload is built, not a contradiction — ADR-0008's text now says so explicitly rather than asserting a false resolution.
- Minor, still-open cosmetic items from Pass 2 that were out of today's scope and remain as-is: ADR-0006↔ADR-0013 BOSS overlay atlas-sharing clarification, ADR-0005's self-contradicting typed-Dictionary post-cutoff declaration, ADR-0010↔ADR-0006 frame-budget rule scoping. None are blocking.

---

## Engine Compatibility Issues — unchanged, still clean

```
Engine: Godot 4.6.2
ADRs with Engine Compatibility section: 18 / 18
Stale Version References: NONE
Deprecated API usage: NONE
Post-Cutoff API contradictions: NONE
```

ADR-0010's revision removed its citation of the nonexistent `modules/core.md` (now cites `VERSION.md` like its siblings) — one fewer engine-reference inconsistency than Pass 2 found.

---

## GDD Revision Flags

None — unchanged from Pass 2.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` was not touched by today's revisions and still contains the stale "ADR Audit" claim of zero cross-ADR conflicts from before Pass 2 ran. Recommend refreshing it to reference this pass's confirmed-clean state, but this is a documentation freshness item, not a blocker — `architecture-traceability.md` (the file this review actually maintains) is current.

---

## Verdict: **PASS**

Both blocking conflicts from Pass 2 are confirmed resolved against shipped code and the canonical GDD signal catalogue. No new conflicts were introduced by the fixes. Remaining items (TR-tower-007 gap, TR-tower-005 partial, deliberately-deferred TR-ds-004/TR-hero-005, non-architectural TR-gc-004, and a handful of low-severity cosmetic/documentation notes) are all non-blocking — none touch Foundation or Core layer coverage, and none represent unresolved cross-ADR contradictions.

### Non-blocking follow-ups (for the backlog, not gating)
1. Write `/architecture-decision projectile-pooling-strategy` to close TR-tower-007 (tower.md Rules 18/19 firmly mandate pooling; no ADR exists yet).
2. Decide whether Tower's Gate 2 should call `MissionEconomy.can_afford()` once that Autoload is implemented, or whether the local `_player_gold` cache is the intended final pattern.
3. Refresh `architecture.md`'s "ADR Audit" section to reflect the now-confirmed-clean state (currently still shows its pre-Pass-2 claims).
4. Small cosmetic items carried from Pass 2: BOSS overlay atlas-sharing clarification (ADR-0006/ADR-0013), ADR-0005's typed-Dictionary self-declaration, ADR-0010/ADR-0006 frame-budget rule scoping.

---

## Handoff

**Immediate actions:** None blocking. Epic 03's stories and any Tower/Hero/Save implementation work can proceed against the current ADR set with confidence — the contracts are internally consistent and verified against shipped code.

**Gate guidance:** Run `/gate-check pre-production` — the architecture blocker that would have gated it is now cleared.

**Rerun trigger:** Re-run `/architecture-review` after the projectile-pooling ADR is written, or after any future ADR touching Tower/Hero/Save/Grid, to keep this clean state verified.

# Architecture Review Report — Pass 4

**Date:** 2026-07-13
**Mode:** `/architecture-review full`
**Engine:** Godot 4.6.2
**GDDs Reviewed:** 14 (`design/gdd/*.md`, excluding `systems-index.md` and the past `gdd-cross-review-2026-05-15.md`)
**ADRs Reviewed:** 19 (ADR-0001 … ADR-0019)

This is the fourth review pass on 2026-07-13 (see `architecture-review-2026-07-13.md`,
`-b`, `-c`). Passes 2–3 found and closed two blocking cross-ADR conflicts
(`tower_id` type/arity, SaveRestorer interface drift). This pass re-validates
those closures, re-runs the full traceability/conflict/engine sweep against the
current state of the repo, and adds an engine-specialist second opinion on
Phase 5 findings (not previously done in this project's review history).

---

### Traceability Summary

Baseline unchanged from `architecture-traceability.md` (Pass 3): **65 registered
TR-IDs — 60 ✅ Covered, 1 ⚠ Partial (TR-tower-005, Scout-only perk activation
has no ADR), 2 additional ⚠ Partial not previously called out in the summary
table (TR-path-007, profiling evidence still required), 4 ❌ Gap** (TR-hero-005
Alpha-tier skill build, TR-tower-007 projectile pooling, TR-ds-004 status
effects deferred post-MVP, TR-gc-004 misfiled design/balance target).

**Note:** `architecture-traceability.md`'s own summary table (line 21: "60 ✅ /
2%") and its Full Matrix disagree slightly on partial-count bookkeeping —
this is a pre-existing documentation-hygiene issue, not a new finding, and is
folded into the Architecture Document Coverage section below.

**New this pass — a GDD with zero registered requirements and zero ADR
coverage:** `mission-hud.md` is still a design skeleton
("[TO BE DESIGNED]" throughout most sections) and has never been registered
in `tr-registry.yaml`. It is lower architectural risk than a Foundation gap
(it's a leaf/presentation consumer, not a dependency for other systems), but
it has three signal contracts (PC-1/PC-2/PC-3) that are already locked and
independently testable. These are added to the TR registry this pass (see
Phase 8) as `TR-hud-001..003` so they're trackable even though the rest of
the GDD is unfinished.

### Coverage Gaps (no ADR exists)

- ❌ **TR-tower-007** (Projectile pooling) — ADR-0019 exists but is
  **Proposed, not Accepted**. Per `docs/CLAUDE.md`'s ADR status lifecycle
  rule, stories referencing a Proposed ADR are auto-blocked. This is
  functionally a still-open gap despite an ADR existing in draft.
  Suggested action: `/architecture-decision` review cycle to Accept or
  revise ADR-0019.
  Domain: Data/Performance. Engine Risk: LOW.
- ❌ **TR-ds-004** (5 status effect types) — no ADR, **by design**
  (damage-status.md explicitly defers this post-MVP). Not a real gap.
- ❌ **TR-hero-005** (4 active skills + Ultimate) — Alpha-tier, no ADR yet
  per existing traceability index; unchanged this pass.
- ⚠ **TR-gc-004** (15–25 min session length) — registry itself already
  flags this as a design/balance target misfiled as a TR-ID, not an
  architecture requirement. Registry-hygiene item, not a blocker.

### Cross-ADR Conflicts

| # | Conflict | Type | Status |
|---|----------|------|--------|
| 1 | `tower_id` type/arity mismatch (ADR-0005 vs ADR-0008 vs ADR-0010) | Integration contract | ✅ Resolved 2026-07-13 (Pass 2→3). **Recommend re-verifying against current code** — this session's git status shows extensive uncommitted changes across `addons/godot_ai/` and other files; the resolution was checked against a prior commit. |
| 2 | SaveRestorer interface drift (ADR-0003 vs ADR-0010/0016/0017 vs shipped code) | Integration contract | ✅ Resolved 2026-07-13 (Pass 2→3) |
| 3 | **ADR-0005 self-contradicts its own Engine Compatibility section**: states "Post-Cutoff APIs Used: None" while its Decision text specifies `Dictionary[Vector2i, CellType]` (a Godot 4.4+ typed-Dictionary feature) | Documentation/Engine | 🔴 **Open, new this pass.** Confirmed as a genuine contradiction by godot-specialist consultation (not a defensible reading gap). Functionally low-risk — the feature itself is independently verified working elsewhere (`grid-system.md`'s own Engine Risk Notes table correctly lists it as verified) — but the ADR's own compatibility table is factually wrong. **Fix:** one-line correction to ADR-0005's Post-Cutoff APIs row. |
| 4 | Per-system frame-budget figures are scattered across 6 separate ADRs with no document summing them against the 16.67ms/frame target | Performance (informational) | 🟡 No numeric conflict found — see table below — but the sum has never been assembled in one place. |
| 5 | BOSS overlay atlas-sharing vs draw-call batching (ADR-0006 dual-layer AnimatedSprite2D vs ADR-0013 shared-atlas batching) | Pattern (unresolved integration point) | 🟡 Open, non-blocking, low risk (≤1 boss active per mission) |
| 6 | **ADR-0019 (Projectile Pooling) is Proposed, not Accepted** — but `control-manifest.md`, `tr-registry.yaml`, and `architecture.md`'s "ADR Audit" section all still describe the project as having "18 ADRs, all Accepted" | Status lifecycle / documentation staleness | 🔴 **Open, new this pass.** This is a live, currently-unresolved discrepancy across three downstream documents. |
| 7 | Gate 2 of Tower placement (ADR-0008) reads a locally-cached `_player_gold` rather than `MissionEconomy.can_afford()` established by ADR-0018 | Data ownership (implementation lag) | 🟡 Tracked, non-blocking — both ADRs agree on the eventual design, `MissionEconomy` (ADR-0018) simply postdates ADR-0008 and hasn't been wired in yet. |

**Consolidated frame-budget table** (assembled this pass — recommend adding
to `architecture.md` or `control-manifest.md` directly, since it currently
only exists implicitly across 6 ADRs):

| System | Budget claimed | Source |
|---|---|---|
| EventBus | ≤1.667ms (10% of frame) | ADR-0001 |
| Monster (150 entities, steady-state) | ≤2ms | ADR-0006 |
| Monster (peak burst: 22-entity lethal AoE / 150-entity wave-end) | ≤4ms | ADR-0006 |
| Hero | ≤0.3ms | ADR-0010 |
| Damage & Status (~20 events/frame) | <0.1ms | ADR-0007 |
| Pathfinding (100 `get_path()` calls) | ≤1ms p99.9 (measured 0.164ms) | ADR-0004 |
| Pathfinding (`would_block_all_paths()`, placement-frame only) | ≤10ms p99.9 (not steady-state) | pathfinding.md |
| Projectile pooling (Proposed) | <0.1ms | ADR-0019 |

Steady-state sum (peak Monster case, excluding the placement-frame-only
spike): **≈7.17ms of 16.67ms** — comfortably under budget. **No overrun
conflict found**; this is a documentation-completeness recommendation only.

### ADR Dependency Order

No cycles detected. Topological order (8 layers, Foundation → Feature →
leaf):

```
Layer 0 (root):   ADR-0001 (EventBus), ADR-0011 (UI Dual-Focus), ADR-0015 (Collision Layers)
Layer 1:          ADR-0002 (Scene/Autoload)
Layer 2:          ADR-0003 (Save), ADR-0004 (Pathfinding), ADR-0005 (Grid)
Layer 3:          ADR-0006 (Monster Movement), ADR-0008 (Tower Placement Gate)
Layer 4:          ADR-0007 (Damage Pipeline), ADR-0009 (Resource Data Model)
Layer 5:          ADR-0010 (Hero), ADR-0012 (Wave Manager FSM), ADR-0016 (Inventory)
Layer 6:          ADR-0013 (Sprite Atlas), ADR-0014 (Pause), ADR-0017 (Resource Economy Drop)
Layer 7:          ADR-0018 (Mission Economy Gold)
Layer 8 (leaf):   ADR-0019 (Projectile Pooling — PROPOSED)
```

Nothing currently depends on ADR-0019, so its Proposed status is not
blocking any other ADR today — but it will block the first tower-weapon
story that needs HOMING/BALLISTIC projectile behavior. This exact
Accepted-depends-on-Proposed anti-pattern occurred once before in this
project's history (resolved same-day 2026-05-24); worth treating as a
recurring risk to watch at ADR-authoring time, not just at review time.

### GDD Revision Flags (Architecture → Design Feedback)

| GDD | Assumption | Reality (from ADR/engine-reference) | Action |
|-----|-----------|--------------------------------------|--------|
| `save-persistence.md` | Flags `FileAccess.open()`/`store_*` semantics as "Verification Required" since 2026-05-15 — never executed | Godot 4.4 changed several `FileAccess.store_*` methods from `void` to `bool` return. The shipped `save_persistence.gd` (S2-02, just implemented per recent commits) already checks every return value correctly — engine specialist confirmed the code is right, only live verification is missing. | **Escalate to a live MCP smoke test now** rather than leaving it a paper item — cheap to verify since the code already exists and just shipped. |
| `grid-system.md` vs ADR-0005 | GDD's own Engine Risk Notes table correctly says typed Dictionaries are "Verified working" | ADR-0005 (which implements this GDD) simultaneously claims "Post-Cutoff APIs Used: None" | One-line fix to ADR-0005 (see Conflict #3 above). |
| `hero.md` / `tower.md` | Both assume glow/pulse VFX (aura, weapon-lock, beam, constellation border, low-HP vignette) will render as designed | Godot 4.6's glow rework moved glow processing to *before* tonemapping with a screen-blend mode change — confirmed real behavioral change by both `breaking-changes.md` and godot-specialist consultation. Practical severity: visual recalibration, not a functional/crash risk — but it is the single most-repeated open "Verification Required" item across the whole document set (flagged independently in `hero.md`, `tower.md`, and `VERSION.md`). | Live `WorldEnvironment` smoke test (representative emissive material + glow enabled, screenshot comparison) before locking VFX/texture import presets. |

Ask: no GDD status changes to `systems-index.md` recommended this pass —
none of the above rise to "the GDD is wrong," only "the GDD's own flagged
risk hasn't been executed yet." Recommend leaving `hero.md`/`tower.md`/
`save-persistence.md` status as-is and tracking the three smoke tests as
follow-up tasks instead.

### Engine Compatibility Issues

**Version consistency:** All 19 ADRs that state an engine version agree on
Godot 4.6.2. No stale version references found.

**Post-Cutoff APIs Used — cross-check:** No two ADRs make contradictory
assumptions about the same post-cutoff API. The only issue is ADR-0005's
internal self-contradiction (Conflict #3), not a cross-ADR disagreement.
`ADR-0008`/`ADR-0016`'s use of `Resource.duplicate_deep()` (4.5+) was
specifically checked by the engine specialist and confirmed correct — the
real gotcha (raw `RefCounted`/`Node` refs inside a component are *not*
deep-copied, only `Resource` subclasses) is already correctly documented and
enforced as a code-review gate in ADR-0008.

**Deprecated API check:** No ADR references any API listed in
`deprecated-apis.md` (`TileMap`, string-based `connect()`, `yield()`,
`instance()`, `get_world()`, etc. are all correctly avoided).

**Missing Engine Compatibility sections:** None — all 19 ADRs have the
section present (ADR-0005's is present but factually wrong, per Conflict
#3 — a "wrong" section, not a missing one).

#### Engine Specialist Findings (godot-specialist consultation, new this pass)

1. **ADR-0011 (UI Dual-Focus)'s `_input()` vs `_unhandled_input()` choice
   confirmed correct** and non-obvious — a click on a `mouse_filter=STOP`
   Button would be consumed before reaching `_unhandled_input`, so the ADR's
   choice is right for the reason it needed to be right.
2. **New finding — SDL3 gamepad driver (Godot 4.5):** ADR-0011's gamepad
   verification plan doesn't separate D-pad (`InputEventJoypadButton`) from
   analog-stick (`InputEventJoypadMotion`) testing. Godot 4.5 moved gamepad
   handling to SDL3, which changed deadzone/axis-to-button mapping
   internals — these two input paths should be smoke-tested separately, not
   as one `KEYBOARD_GAMEPAD` mode.
3. **New finding — `focus_mode` defaults:** ADR-0011 doesn't verify that
   custom `Control`-derived widgets (e.g. a custom inventory slot) default
   to `FOCUS_ALL` the way `Button`/`TextureButton` do. A widget defaulting
   to `FOCUS_NONE` would silently break gamepad traversal with no error.
   Worth adding to ADR-0011's Verification Required list.
4. **New finding — D3D12-on-Windows default (Godot 4.6):** Called out in
   ADR-0006 (BOSS compositing) but never cross-referenced against ADR-0013
   (draw-call batching) or the glow-rework item, even though 2D batching
   behavior and glow blend intensity could plausibly differ between D3D12
   and Vulkan. Recommend one combined renderer-parity smoke test instead of
   three separate unverified line items.

### Architecture Document Coverage

`architecture.md` (v3) covers all 25 systems from `systems-index.md` across
its 6 layers — no missing systems, no orphaned architecture (systems present
in `architecture.md` with no corresponding GDD).

**Staleness found:**
- `architecture.md`'s "ADR Audit" section states "All 18 ADRs are Accepted"
  — now stale; there are 19 ADRs and ADR-0019 is Proposed (same issue as
  Conflict #6).
- `architecture.md`'s own Traceability Matrix summary shows two different
  coverage numbers in different places (58/63 in one spot, 92% in another)
  and explicitly defers to `architecture-traceability.md` as the source of
  truth on conflict. Recommend removing the duplicate inline summary from
  `architecture.md` and linking to `architecture-traceability.md` instead,
  rather than maintaining two numbers that can drift.
- Two Open Questions from `architecture.md` remain unresolved: **OQ-5**
  (grid-dimensions-per-mission) and **OQ-8** (event-bus.md catalogue
  housekeeping). Unchanged this pass — not newly found, just still open.

**Process observation:** `technical-preferences.md`'s Forbidden Patterns and
Allowed Libraries/Addons sections are both still placeholder-only
("[None configured yet]"), despite `addons/godot_ai/` being real,
substantially-modified editor/MCP tooling infrastructure (per this
session's git status). Not an engine-compatibility risk — it's editor
tooling, not a gameplay runtime dependency — but exactly the kind of thing
those sections exist to track. Flagged as a documentation-hygiene item, not
blocking.

---

### Verdict: **CONCERNS**

No blocking Foundation-layer gaps, no dependency cycles, and both prior
blocking conflicts remain confirmed resolved. This project has an unusually
mature self-review cadence (four passes in one day, with a genuine
find→fix→confirm cycle on Passes 2–3). The issues this pass surfaces are
real but narrow and none are Foundation-layer blockers:

1. ADR-0019 sitting in Proposed with three downstream documents
   (`control-manifest.md`, `tr-registry.yaml`, `architecture.md`) still
   describing the project as "18 ADRs, all Accepted."
2. ADR-0005 self-contradicts its own Engine Compatibility table (one-line
   fix).
3. Two long-open "Verification Required" engine risks (FileAccess
   semantics, glow rework) have paper flags but no live smoke-test evidence
   on record, despite the underlying code (SavePersistence) already having
   shipped.
4. `mission-hud.md` remains an unregistered, ADR-less skeleton GDD — low
   risk (leaf/presentation, no dependents), but the gap wasn't trackable
   until this pass registered its three locked signal contracts.

### Blocking Issues
None — verdict is CONCERNS, not FAIL. Nothing here blocks continued Sprint
5 work; the above should be scheduled as follow-up, not treated as a gate
failure.

### Required ADRs / Follow-ups (priority order)

1. Accept or revise **ADR-0019** (Projectile Pooling) — unblocks
   TR-tower-007 and any HOMING/BALLISTIC tower-weapon stories; then update
   `control-manifest.md`, `tr-registry.yaml`'s header note, and
   `architecture.md`'s ADR Audit section to reflect 19 ADRs / 1 Proposed.
2. One-line fix to **ADR-0005**'s Engine Compatibility table.
3. Live MCP smoke test of `save_persistence.gd` save/load round-trip
   (cheap — code already shipped).
4. Live `WorldEnvironment` glow/emissive smoke test before locking VFX
   import presets (highest-repeated open risk in the corpus).
5. Re-verify Conflict #1 (`tower_id`) against current uncommitted code
   state before continuing to trust its "Resolved" status.

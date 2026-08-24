# Independent Review: ADR-0038 (Hybrid Creature Swarm Rendering)

**Date**: 2026-08-24
**Reviewer**: Claude Code, independent of Codex's authoring context
**Scope**: `docs/architecture/adr-0038-hybrid-creature-swarm-rendering.md`,
`docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md`, and
the ADR-0037 scope amendment both depend on. Cross-checked against the actual
live codebase (`monster_manager.gd`, `monster_instance.gd`, `MissionScene.tscn`,
`the_gap.tscn`, ADR-0013, existing tests), not just the documents' own
internal claims.
**Method**: documentation-only review. No production code, ADRs, or the
blueprint were modified by this review. Findings below are things *to*
change, not changes made.
**Purpose**: determine whether ADR-0038 is ready to move from Proposed to
Accepted.

---

## Verdict

**ADR-0038 cannot move to Accepted yet — and that is correct, not a defect.**

The ADR's own `Verification Required` field states: *"The cross-medium pilot
defined below must pass before this ADR becomes Accepted or creature art
enters mass production."* No pilot has been built or run (Migration Plan step
1 / Story 1 in the blueprint are both still `backlog` per
`production/art-overhaul-status.md`). A documentation review cannot satisfy an
empirical gate the ADR itself correctly insists on. **This review's job is
narrower**: is the document *itself* sound enough to guide that pilot without
sending Qwen down a wrong path? Overall: **yes, with 5 concrete corrections**
(§1-§5 below) that should land before implementation starts, not after — one
of them (§2) is a real, already-true discrepancy in the codebase today, not a
hypothetical the ADR treats it as.

None of the 5 findings below are about whether the *approach* is sound — the
approach (dense-slot `MultiMeshInstance3D` batches, fixed 4-channel
custom-data contract, post-Pass-3 presentation sync, capped exceptional
presenters for Boss/elite) is a well-reasoned, correctly-scoped response to
the investigation report and the locked art direction. The findings are about
factual accuracy against the current codebase and a few precision gaps.

---

## §1. Correctly incorporates the investigation report — verified point by point

Cross-checked every claim in `investigation-2026-08-24-hybrid-swarm-rendering.md`
against ADR-0038/the blueprint:

| Investigation finding | ADR-0038 / blueprint treatment | Verdict |
|---|---|---|
| `INSTANCE_CUSTOM` is vertex-stage-only, needs a varying passthrough | Blueprint §"Shader contract": "`INSTANCE_CUSTOM` is accessed only in `vertex()`... `fragment()` reads `instance_state`; direct fragment access... is prohibited on the pinned engine." | Correctly and precisely incorporated |
| 4 custom-data channels is a hard budget, decide allocation up front | ADR-0038 fixes `x/y/z/w` = frame/flash/status-mask/facing explicitly, blueprint: "Do not opportunistically reuse a channel... stop and revise ADR-0038 rather than silently pack" | Correctly incorporated, stronger than my own recommendation (I only said "decide before writing shader code"; this adds an explicit stop-condition) |
| Sprite3D only viable at Boss-tier scale (1-2 concurrent) | ADR-0038 §"Bosses, elites, and Menagerie": dedicated `Sprite3D`/`AnimatedSprite3D` for Boss and *elites* with a proven concurrency cap | Correctly incorporated, reasonably extended to capped elites (not a contradiction — still bounded) |
| Transparency depth-sort is the top unverified risk | ADR-0038 goes further than my "test both" recommendation: rules out alpha-blend as the default outright ("Godot does not provide order-independent transparency and cannot guarantee per-instance transparent sorting"), keeps alpha scissor as baseline, allows alpha hash only with pilot evidence | This is a *stronger*, decisive call rather than a deferred one — defensible, since the underlying fact (no OIT, no per-instance MultiMesh sort) is general, well-established rasterizer/Godot behavvior, not something that needed a fresh live check to state |
| Recommend flat shadow-decals over real billboard shadow-casting | ADR-0038 §"Body and shadow submissions": separate shadow stream, "do not cast real-time silhouette shadows" | Correctly incorporated |
| Hit-flash needs a real spatial-shader port, not a direct reuse of `hit_flash.gdshader` | Blueprint Migration step 5: "Replace the per-monster `ShaderMaterial`/Tween mutation path... with manager/renderer-owned decay state" | Correctly incorporated |
| Existing prototype scenes don't cover swarm/2D-in-3D questions, recommend a new sibling prototype dir | Blueprint Story 1: new `prototypes/hybrid-swarm-pilot/` with its own README | Correctly incorporated, matches this project's own `prototype-code.md` convention |

No misrepresentation or dropped finding found.

---

## §2. Real, already-true discrepancy — not a hypothetical (blocking, fix before implementation)

**File**: `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md`,
§"MonsterManager frame ordering", the conditional sentence: *"If current code
filters/removes entities before the sync can identify resolved IDs, Qwen must
capture a compact resolved-ID list during Pass 3."*

**This is not an "if" — it is already true today.** Read `monster_manager.gd`
lines 380-397 (`_pass3_movement()`): the swap-buffer rebuild at the end of
Pass 3 already filters `active_monsters` down to only
`lifecycle_state == ACTIVE` entities, **discarding DEAD and BREACHED entities
from the array before any subsequent pass (including the existing Pass 3c
visual sync, and by extension wherever `PRESENTATION SYNC` would be inserted)
ever sees them.** The existing Pass 3c doc comment (lines 441-447) confirms
this is deliberate current behavior: *"a monster that breached or was set DEAD
earlier this frame is skipped for free... no extra lifecycle_state check
needed here."* That "skipped for free" relies on Godot's normal node-tree
teardown eventually freeing the old `VisualCompanion3D` child — a mechanism
that has **no equivalent for a dense `MultiMesh` array slot**, which requires
an explicit unregister call carrying the resolved entity's ID, since there is
no node to free.

**Concrete, already-available fix path** (found in the same file, not
invented): `_pending_deaths` (line 86, doc comment: *"ADR-0033 — frame-scoped,
flushed each frame in Pass 4"*) is an existing, working example of exactly
this pattern — capturing resolved entity data *before* the swap-buffer rebuild
discards it, for consumption later in the same frame. The renderer's
unregister-on-death path should very likely reuse or directly mirror this
existing pattern rather than the blueprint's vaguer "Qwen must capture a
compact resolved-ID list" phrasing, which reads as an open design question
when the codebase already has a working precedent for it.

**Separately, for BREACHED specifically**: `_advance_entity()` (line 419)
already emits `GEventBus.monster_breached.emit(entity.entity_id, ...)` at the
exact moment of breach, before the swap-buffer rebuild. This carries the
resolved ID at exactly the right moment — but ADR-0038/the blueprint's
explicit "no EventBus event for recurring presentation synchronization"
constraint would forbid consuming it directly. That constraint is clearly
correct for *per-frame position* traffic (the actual recurring hot path), but
death/breach is a *per-entity, once-per-lifetime* event, not a recurring one
— worth an explicit note in the ADR that the "no EventBus" rule targets the
recurring position-sync path specifically, not incidentally banning the
already-emitted, already-correct-timing `monster_died`/`monster_breached`
signals as a *data source* for capturing resolved IDs (whether the renderer
subscribes to them directly or `MonsterManager` captures them into its own
pending list first is an implementation choice either way satisfies "no new
recurring EventBus traffic").

**Recommended exact change**: reword the conditional sentence in
"MonsterManager frame ordering" to state this as a confirmed current-codebase
fact with the `_pending_deaths` precedent named explicitly, so Qwen isn't
re-deriving something already verifiable by reading the file the blueprint
itself names as a change target.

**Status: Applied 2026-08-24** — Codex was unavailable when this became
actionable; applied directly to
`hybrid-swarm-rendering-implementation-blueprint.md`'s "MonsterManager frame
ordering" section per the exact change recommended above, since this
correction was already fully verified against the live code during this
review (no new judgment call was needed to apply it).

---

## §3. Scene-tree structure claim doesn't match the actual files (blocking, fix before implementation)

**Files**: `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md`
§"Required scene tree" and its File Ownership table row for
`src/scenes/MissionScene.tscn` / `src/gameplay/missions/the_gap/the_gap.tscn`.

The blueprint's diagram shows `PresentationRoot3D (Node3D)` as an existing
container node holding `Camera3D` and the new `MonsterSwarmRenderer3D`. The
File Ownership table instructs: *"Add one renderer instance beneath the
existing 3D presentation root and wire its reference. Do not restructure the
simulation root or HUD."*

**Checked both actual scene files — neither has a `PresentationRoot3D` node at
all**:
- `src/scenes/MissionScene.tscn:59` — `[node name="Camera3D" type="Camera3D"
  parent="GameplayRoot"]` — `Camera3D` is a **direct child of `GameplayRoot`**
  (the `Node2D` simulation root), not of any `Node3D` wrapper.
- `src/gameplay/missions/the_gap/the_gap.tscn:38` — `[node name="Camera3D"
  type="Camera3D" parent="."]` — `Camera3D` is a **direct child of the scene
  root**, same situation.

There is no "existing 3D presentation root" to add the renderer beneath —
the blueprint's own phrasing implies one exists when it doesn't. This is
exactly the situation the blueprint's own "Purpose and authority" section
already anticipates and has a rule for ("If a named path differs in the live
tree, Qwen must report the discrepancy before substituting an architecture")
— but the File Ownership table's wording doesn't surface that this specific
node is one of the differences, so an implementer skimming that table instead
of independently grepping the .tscn files (as this review did) could
reasonably act on the false assumption. Introducing `PresentationRoot3D` as
new is very likely fine mechanically — per ADR-0037's own clarification that
a `Node3D` anywhere under a `Node2D` ancestor doesn't inherit that ancestor's
2D transform regardless of nesting depth, moving `Camera3D` one level deeper
under a new `Node3D` wrapper shouldn't change its behavior — but it **is**
still a scene-structure change (a new node didn't exist before), which sits
in tension with "Do not restructure the simulation root" if `GameplayRoot`
is read as covering `Camera3D`'s current placement.

**Recommended exact change**: either (a) correct the File Ownership table to
state plainly that `PresentationRoot3D` does not yet exist in either scene
and must be created, reparenting the existing `Camera3D` node under it, or
(b) revise the Decision to not require a `PresentationRoot3D` wrapper at all
and instead have `MonsterSwarmRenderer3D` sit as a sibling to the existing
directly-parented `Camera3D` — whichever the actual implementer prefers, but
the current wording should not describe a node as "existing" when it isn't.

**Status: Applied 2026-08-24** — went with option (a) (keeps ADR-0038's own
Architecture Diagram accurate as the target end-state rather than revising
the Decision itself, which would need Codex's sign-off, not a documentation
correction). Applied directly to
`hybrid-swarm-rendering-implementation-blueprint.md`'s File Ownership table
rows for both `.tscn` files, citing the exact current line numbers.

---

## §4. Minor precision gap — "supersedes Menagerie's 3D-mesh end state" overstates what's shipped

**File**: `docs/architecture/adr-0038-hybrid-creature-swarm-rendering.md`,
§"Bosses, elites, and Menagerie": *"This ADR supersedes the Menagerie's 3D-mesh
end state, not its scene ownership."*

Checked: `src/core/menagerie/` (`creature_instance.gd`, `menagerie.gd`,
`breeding_pen.gd`, `species_resource.gd`) has **zero** references to
`VisualCompanion3D`, `visual_mesh_mapping`, or `MeshInstance3D` anywhere.
Menagerie creatures have no 3D visual companion today — unlike monsters
(§2 above), where real shipped code is being superseded. What's actually
being superseded here is ADR-0037's original *roadmap intent* (its old
"Enables" field named a Phase 6 "content re-authoring" that implicitly
would have eventually extended 3D mesh companions to Menagerie too) — not
already-built code.

This is a low-severity finding (doesn't block anything, doesn't cause
Qwen to do the wrong thing), but the phrasing "supersedes... end state"
reads as parallel in weight to the monster case, when the actual migration
cost is completely different (zero code removal vs. a real 6-file removal
list). Worth a one-clause distinction for anyone reading this ADR later to
scope a Menagerie-specific follow-up correctly.

**Recommended exact change**: add a short clause distinguishing "supersedes
already-shipped monster mesh companions (real code removal, see Migration
Plan)" from "supersedes Menagerie's previously-*planned*, never-implemented
3D-mesh direction (no code exists to remove)".

---

## §5. Terminology drift from the existing codebase's own naming

**File**: `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md`,
§"MonsterManager frame ordering" — names the new step `PRESENTATION SYNC`.

The current codebase already has a name for precisely this slot in the frame:
**"Pass 3c — Visual Companion Sync"** (`monster_manager.gd` line 429, with its
own doc-commented rationale for exactly *why* it runs immediately after Pass 3
rather than after Pass 4). ADR-0038's new step occupies the identical
position in the frame for the identical reason (syncing presentation
immediately after the only pass that writes `entity.global_position`) — it is
very likely a direct evolution of Pass 3c, not a new insertion point being
independently re-derived. Calling it something else in the blueprint risks an
implementer treating it as a new decision to justify from scratch rather than
recognizing it as continuing an already-justified one.

**Recommended exact change**: rename the blueprint's `PRESENTATION SYNC` step
to `Pass 3c` (or explicitly say "supersedes/extends the existing Pass 3c")
to preserve the paper trail back to the original ADR-0037/Epic 15 Story 004
reasoning already recorded in the codebase.

---

## §6. Things checked and found accurate (no action needed)

- `ADR-0013` (draw-call batching) status/decision matches the "partially
  superseded, shared-atlas principle stays binding" characterization — its
  actual mechanism (2D `CanvasItem` automatic batching via shared per-class
  texture atlases) is a genuinely different, inapplicable mechanism once
  monsters render via 3D `MultiMesh`, while the underlying atlas-sharing
  *principle* does carry over conceptually. Accurate.
- `tests/integration/visual_presentation/monster_visual_companion_test.gd`
  exists exactly where cited, alongside the sibling
  `hero_visual_companion_test.gd`/`projectile_visual_companion_test.gd`/
  `grid_terrain_visual_companion_test.gd` the ADR says must remain untouched
  — the file-level scoping in Migration Plan step 8/Blueprint step 6 is
  correct.
- `monster_instance.gd`'s actual field/method names
  (`_build_visual_companion()`, `_visual_companion`, `MONSTER_LAYER_HEIGHT`,
  `sync_visual_companion_position()`) match what the blueprint's File
  Ownership table names as removal/change targets exactly — no naming drift.
- The ADR-0037 scope amendment itself (already committed, `docs/architecture/
  adr-0037-visual-presentation-3d-companion-layer.md` lines 6-15) is precise
  and correctly scoped — it doesn't overclaim, correctly lists which parts of
  ADR-0037 remain authoritative (Hero/tower/terrain/building/props/
  projectiles/camera/coordinate-mapping), and doesn't touch Status (stays
  Accepted, correctly — this is a scope narrowing, not a reversal).
- The 4-pass frame ordering ADR-0038/the blueprint assume (Pass 1 → 1b → 2 →
  3 → [sync] → 4) matches the real, currently-shipped pass structure in
  `monster_manager.gd` exactly.

---

## Summary for whoever accepts/rejects ADR-0038

- **Do not accept yet** — correctly gated on the pilot per the ADR's own
  stated criterion, which has not run.
- **§2 and §3 applied 2026-08-24** — Codex was unavailable; both corrections
  were already fully verified against the live code during this review, so
  they were applied directly to the blueprint rather than left pending. No
  new judgment calls were made beyond what's documented in each section above.
- **Nice-to-have, non-blocking**: §4 (Menagerie phrasing precision), §5
  (rename `PRESENTATION SYNC` to `Pass 3c` for continuity).
- Everything else in both documents checked out accurate against the live
  codebase and faithfully incorporates the prior investigation report.

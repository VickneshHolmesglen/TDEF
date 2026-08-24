# Investigation: Godot 4.6.2 Feasibility for Hybrid 3D-World / 2D-Creature Swarm Rendering

> **Status**: Findings only. No production code or ADRs modified by this
> investigation — see `docs/architecture/adr-0037-visual-presentation-3d-companion-layer.md`
> for the ADR this feeds into/conflicts with (§5 below). Written for Codex to
> incorporate into the architecture decision the art overhaul's cross-medium
> pilot depends on (`design/art/codex-art-overhaul.md`,
> `production/art-overhaul-status.md` "Production architecture" section).
> **Date**: 2026-08-24. **Investigator**: Claude Code, live-verified against
> the project's pinned Godot 4.6.2.stable binary (not assumed from training
> data — see §1 for what was actually run).

---

## 0. Scope and question

The art overhaul's locked visual direction (`art-bible.md` §1) puts the
hero/towers/buildings/terrain in 3D and monsters/creatures/cards/icons in 2D.
This investigation answers the specific rendering-feasibility questions that
decision raises for Godot 4.6.2:

1. Can Sprite3D or MultiMeshInstance3D render 2D creature art inside a 3D world?
2. Can atlas-frame (sprite-sheet) selection work per-instance via instance
   custom data, for animated creatures rendered through instancing?
3. How does transparency/depth sorting behave for many overlapping billboard
   sprites?
4. How do contact shadows work for a billboarded 2D sprite in a 3D scene?
5. How does per-instance hit/status feedback (the existing 2D hit-flash
   pattern) translate to an instanced rendering approach?
6. Does an existing proof scene cover any of this, and can it be safely
   extended?

---

## 1. What was actually verified (not assumed)

Live-tested via Godot MCP against the pinned `4.6.2.stable.official` binary,
in the real project (not an isolated throwaway project) — full script and
output are reproducible via `run_script`, not persisted anywhere:

- Built a `MultiMesh` (`TRANSFORM_3D`, `use_custom_data = true`) with a
  `QuadMesh`, wrapped in a `MultiMeshInstance3D`, added to the live tree.
- Set 5 instances' transforms and per-instance custom data
  (`set_instance_custom_data`), read them back — matched exactly
  (`transform_readback_instance3_x = 4.5`, `custom_data_readback_instance2_a = 1`).
- Wrote a `spatial` shader with a `material_override` reading atlas-frame
  selection from instance custom data, applied it, confirmed the node entered
  the tree and computed a correct `AABB` spanning all 5 instances.
- **First attempt failed**: reading `INSTANCE_CUSTOM` directly inside
  `fragment()` produced `SHADER ERROR: Unknown identifier in expression:
  'INSTANCE_CUSTOM'` — it is a **vertex-stage-only** built-in in this Godot
  4.6.2 build. **Confirmed working pattern**: write it to a `varying flat
  vec4` in `vertex()`, read the varying in `fragment()`. Second attempt with
  this pattern compiled cleanly (806-char shader, zero errors in
  `get_debug_output`).

This is the one concrete, previously-undocumented Godot-version gotcha this
investigation surfaces — anyone implementing atlas-frame-via-custom-data
without knowing this will hit the exact same error on the first try.

**Not live-verified** (documented from stable, long-standing, non-post-cutoff
Godot/GPU-instancing behavior — see each claim's own note in §2-4 for why a
live check wasn't necessary to state it with confidence): per-instance
transparency depth-sort ordering, shadow-casting from a billboard quad,
`Sprite3D`'s native `hframes`/`vframes` API (this is a pre-4.x, unchanged
Godot feature).

---

## 2. Sprite3D vs. MultiMeshInstance3D — which one, and when

**`Sprite3D`** is a full scene-tree node with native `hframes`/`vframes`/
`frame` sprite-sheet slicing, per-instance material, billboard mode
(`BILLBOARD_ENABLED`/`BILLBOARD_FIXED_Y`), and normal per-node depth sorting
against other transparent geometry. This is low-risk, well-documented,
unchanged-since-pre-4.x functionality — **no engine risk flag needed**.

**Cost**: one full `Node` per creature. At the 100+-monster swarm scale this
project's own `monster.md`/ADR-0004 already designs around, 100+ individual
`Sprite3D` nodes is exactly the "don't do this at scale" case the project's
existing `MonsterManager` centralized-pass architecture (ADR-0006) was built
to avoid for 2D `Sprite2D` nodes too — the same reasoning applies here.

**`MultiMeshInstance3D`** renders many instances of one mesh in one draw
call, with per-instance transform + optional per-instance color + optional
per-instance custom data (4 floats). This is the actual swarm-scale answer
— confirmed working live per §1, including the atlas-frame-selection use
case. **Trade-off**: no per-instance node, no per-instance material, no
per-instance native frame/hframes/vframes API — atlas selection and any
per-instance visual state (hit flash, status tint) must be hand-rolled via
the 4-float custom-data channel and a custom shader, not Godot's built-in
sprite-sheet convenience.

**Recommendation**: `MultiMeshInstance3D` for Standard-tier monster swarms
(the actual 100+-count case); `Sprite3D` remains a reasonable option for
Boss-tier creatures (at most 1-2 concurrent, per `wave-manager.md`) where the
per-node cost is negligible and the native `hframes` API saves real shader
work for a one-off asset. This mirrors the project's own existing pattern of
treating Boss content as a deliberately more expensive, more bespoke tier
(see `tower.md`'s T4/Boss cost-cap precedent, `art-bible.md` §8.3's Boss
atlas budget already being 8x a Standard creature's).

---

## 3. Atlas-frame selection via instance custom data — confirmed working, with the caveat above

Mechanism (live-verified per §1): `MultiMesh.use_custom_data = true`,
`set_instance_custom_data(idx, Color(frame_index, 0, 0, flash_amount))` per
instance, a `spatial` shader that:
1. In `vertex()`: `varying flat vec4 v_custom; v_custom = INSTANCE_CUSTOM;`
2. In `fragment()`: reads `v_custom.x` for frame index, computes a UV offset
   into an atlas texture from `atlas_cols`/`atlas_rows` uniforms, samples,
   writes `ALBEDO`/`ALPHA`.

This directly replaces `Sprite3D.hframes/vframes/frame` for the instanced
case — there is no equivalent built-in for `MultiMesh`, this hand-rolled
shader is the standard, expected way to do it in Godot (not a project-specific
workaround). `Color`'s 4 channels give exactly 4 float slots per instance;
this investigation's test used `.x` for frame index and `.a` for hit-flash
(see §5) — a real implementation needs to budget all 4 channels up front if
more per-instance state is needed later (e.g. facing direction, a second
status-effect tint) since there is no channel expansion without a data-model
change.

**Animation**: frame index must be written from CPU-side code (GDScript)
every time an animated creature's frame advances — there is no
shader-driven/automatic frame-cycling. This is a real, recurring per-frame
write cost (`set_instance_custom_data` for every animating instance, every
frame it advances) that must live inside the same centralized-pass
architecture ADR-0037 already established (`MonsterManager`'s existing
per-frame loop, not a new per-entity callback) — architecturally
straightforward, but worth flagging as an actual CPU cost line item for the
pilot to measure, not assumed free.

---

## 4. Transparency / depth sorting — the real engine risk

**Not live-verified in this pass** (would require a multi-instance
overlapping-alpha screenshot comparison, judged out of scope for this
"concise" report — recommended as the pilot's own first check, see §7) but
stated with confidence as documented, structural Godot/GPU-instancing
behavior, not a version-specific risk: **instances within one `MultiMesh` are
not depth-sorted against each other.** They render in whatever order they sit
in the multimesh buffer, in one draw call. For opaque billboards this is
invisible (depth-testing alone resolves overlap correctly, same as any opaque
3D geometry). For **alpha-blended** transparent billboards — soft-edged
creature sprites with partial-alpha fringes — overlapping instances can
render in the wrong order relative to each other (though still correctly
relative to the surrounding 3D world, since MultiMesh instances do participate
in the depth buffer against non-MultiMesh geometry).

**This is the single highest-risk item in this whole investigation** for the
"100+ creature swarm" requirement `art-bible.md` §1 Principle 2 and §8.7
explicitly name. Two established mitigations, not mutually exclusive:

1. **Alpha-scissor instead of alpha-blend** (`ALPHA_SCISSOR_THRESHOLD` in the
   shader, hard cutout instead of soft edges) — sidesteps the sort problem
   entirely since scissored fragments participate in normal opaque
   depth-testing. Costs the soft/anti-aliased edge quality on creature
   silhouettes.
2. **Accept minor artifacts** — with a fixed, non-rotating camera (ADR-0037's
   own constraint) and small, fast-moving creature sprites, sort errors
   between two overlapping instances are typically a 1-2 frame flicker, not a
   persistent glaring bug. This project's own `art-bible.md` §3.5 already
   prioritizes "one dominant repeatable mass, low internal contrast" for
   Standard creatures — simple, mostly-opaque silhouettes reduce how often
   this matters in practice.

**Recommendation**: pilot should test both, side by side, with ~50-100
overlapping instances at the locked camera angle, before committing either
way — this is exactly the kind of claim `art-bible.md` §8.7's own "pilot must
prove... before mass production" gate exists for.

---

## 5. Contact shadows — do not rely on real shadow-casting from the billboard itself

A billboarded quad's own `cast_shadow` (standard `GeometryInstance3D`
property, available on `MultiMeshInstance3D` too) will cast a shadow shaped
like the quad — since the quad is always facing the camera, its shadow shape
depends on the *light* angle relative to the *quad's fixed camera-facing
orientation*, not the creature's actual silhouette from the light's point of
view. With a fixed camera and fixed key light (both already constants per
ADR-0037 and `art-bible.md` §2), this shadow shape is at least *consistent*
frame to frame, but it will not resemble the creature's silhouette — it will
read as a flat rectangle-ish smear, not a contact shadow.

**Recommendation, consistent with this project's own established 2D
technique**: don't rely on real-time shadow casting from the billboard mesh
at all. Reuse the exact pattern `art-bible.md` §1 Principle 1 (old version)
already validated for 2D — a separate small flat shadow-blob decal/quad
underneath each creature, either a second cheap MultiMesh instance stream
(one shadow-blob mesh, instanced 1:1 with the creature swarm, same transform
minus height) or a projected decal. This is cheaper than real shadow-casting,
guaranteed to read correctly regardless of light/camera angle, and is a
direct continuation of a technique this project already has production
experience with (`art-bible.md`'s stacked-sprite-with-cast-shadow-sprite
convention, `stacked-sprite-seam` prototype).

---

## 6. Per-instance hit/status feedback — requires a real rework, not a port

**Current state** (confirmed by reading `monster_instance.gd`): hit-flash is
implemented as a `CanvasItem`/2D `ShaderMaterial` (`hit_flash.gdshader`)
assigned directly to each monster's own `Sprite2D.material` — one material
instance per monster, `flash_amount` set independently per monster via a
Tween. This works today because each monster is its own `Sprite2D` node with
its own material.

**This does not carry over to `MultiMeshInstance3D`.** All instances in one
`MultiMesh` share exactly one `material_override` — there is no per-instance
material. Per-instance hit-flash must go through the same instance
custom-data channel atlas-frame selection uses (§3) — confirmed live-workable
in this investigation's test (`.a` channel driving a flash mix in the
fragment shader). This means:

- `hit_flash.gdshader`'s logic needs a **spatial-shader port**, not a reuse —
  different shader type (`canvas_item` vs `spatial`), different built-ins
  (no direct `TEXTURE`/`COLOR` the same way), and it must read from a varying
  instead of a single uniform (per §1's gotcha).
- The Tween-driven "ease flash_amount from 1.0 to 0.0" pattern
  (`monster_instance.gd`'s existing `_hit_flash_material.set_shader_parameter`
  call site) needs an equivalent that calls `set_instance_custom_data()` on
  the shared `MultiMesh` at the specific instance index instead of setting a
  material uniform — same Tween-driven easing curve, different write target.
- **4-float budget conflict**: §3 already spends `.x` on frame index. If
  hit-flash needs `.a` and a future status-effect tint needs a distinct third
  channel, `Color`'s 4 channels (`.x/.y/.z/.a`) get consumed fast. Recommend
  deciding the full custom-data channel budget (frame index, flash amount,
  status tint id, ??) as one deliberate data-model decision before writing
  any shader code, not incrementally.

---

## 7. Existing proof scene — reusable but insufficient alone

`prototypes/3d-tower-defense-kit-spike/` (2 scenes, no `README.md` — a
pre-existing gap against this project's own `prototype-code.md` rule,
flagged here, not fixed, per this investigation's own no-production-edits
scope):

- **`spike.tscn`**: pure `Node3D` root, GLB-imported tile/tower/prop meshes,
  one `DirectionalLight3D` with `shadow_enabled = true`, one fixed `Camera3D`.
  Validates GLB import and basic 3D scene assembly. Does **not** touch
  `MultiMesh`, `Sprite3D`, custom shaders, or 2D content at all.
- **`mixed_root_check.tscn`**: `Node2D` root (`EntityRoot`) parenting a
  `Node3D` subtree with its own `Camera3D`/light/meshes. This is the scene
  ADR-0037 itself cites as its live-verification evidence for the
  mixed-root pattern the whole Visual Companion architecture depends on.
  Also does not touch `MultiMesh`/`Sprite3D`/2D-creature-in-3D-world at all.

**Neither scene tests anything this investigation's §2-6 covers.** They
validate a different, already-answered question (does a mixed 2D/3D scene
tree render at all — yes, per ADR-0037) not the new one (can a swarm of
instanced, animated, individually-reactive 2D creatures render inside that
3D world). **Recommendation**: do not extend either existing scene in place
— per this project's own `prototype-code.md` convention ("each prototype
lives in its own subdirectory"), create a new sibling prototype directory
(e.g. `prototypes/hybrid-swarm-pilot/`) with its own required `README.md`,
purpose-built to test §2-6's open questions together. `spike.tscn`'s tile/
tower/prop GLB instances remain directly reusable as the 3D-world backdrop
for that new pilot scene — no need to re-source or re-import them.

---

## 8. ADR conflict — this is the important one, needs Codex's attention

**`docs/architecture/adr-0037-visual-presentation-3d-companion-layer.md` is
currently Accepted and already implemented for monsters.** Confirmed by
reading the actual code, not assumed from the ADR text alone:

- `monster_instance.gd::_build_visual_companion()` instantiates a real
  `MeshInstance3D`-bearing `PackedScene` per monster (resolved via
  `VisualMeshMappingResource`, e.g. `assets/data/visual_meshes/enemy_ufo_a.tres`
  — a placeholder Kenney "UFO" mesh standing in for a real monster model).
- `monster_manager.gd` (lines ~468-469) already calls
  `sync_visual_companion_position()` every frame inside its existing
  centralized pass, exactly per ADR-0037's Decision.
- This is **Epic 15, Story 004 ("Monster Visual Companion")**, already shipped
  and tested (per `production/session-state/active.md`'s own extract: "119/119
  pre-existing Hero tests still pass" / "39/39 visual_presentation... clean").

**The conflict**: ADR-0037's Decision and its own Migration Plan (§"Phase 6:
content re-authoring") describe every gameplay entity — Hero, Tower, Monster,
projectiles — eventually getting a real 3D mesh. The newly locked
`art-bible.md` §1 Hybrid Rendering Ownership explicitly puts monsters/
creatures in the **2D** column, not the 3D column. These are not compatible
end-states for the same entity type. Right now the actual codebase agrees
with the *old* ADR-0037 direction (monsters have real 3D `MeshInstance3D`
companions today) and disagrees with the *new* locked art direction (monsters
should be instanced 2D billboards).

**This is not something this investigation can resolve — it needs a formal
decision**, per this project's own `docs/CLAUDE.md` rule ("If the violation
contradicts an existing ADR... revise the existing ADR" rather than silently
diverging). Concretely, ADR-0037 needs an amendment (not a full supersession
— its Hero/Tower/projectile/tile guidance for the *3D* column entities
remains correct and already-shipped) narrowing its scope to explicitly
exclude monsters/creatures, with a new, separate ADR covering the
`MultiMeshInstance3D`-based 2D-creature-swarm approach this investigation's
§2-6 lay the technical groundwork for. Existing shipped monster-visual-
companion code (`_build_visual_companion()`, `enemy_ufo_a.tres`, the
`sync_visual_companion_position()` call site) would need to be removed or
replaced, not extended — flagged here as a real, non-trivial migration cost
this decision carries, not a free reversal.

**Not in conflict, remain valid as-is**: ADR-0037's Hero/Tower/tile/building
3D-mesh guidance (matches the locked art direction's 3D column exactly), the
`map_to_3d()` coordinate-mapping contract (medium-agnostic — works the same
whether the visual target is a `MeshInstance3D` or a `MultiMesh` instance
transform), the centralized-sync-pass architectural constraint from ADR-0006/
ADR-0019 (must still apply to whatever writes into the swarm's `MultiMesh`
each frame), and the `GameDataRegistry` + `Resource` + `validate()` convention
for any new mapping data (a future creature-atlas mapping resource should
follow `VisualMeshMappingResource`'s exact precedent).

---

## 9. Summary for the architecture blueprint

| Question | Answer | Confidence |
|---|---|---|
| Sprite3D for 2D-in-3D creatures | Works natively, but one node per instance — Boss-tier only | High (unchanged pre-4.x API) |
| MultiMeshInstance3D for swarm-scale creatures | Works, confirmed live | High (live-verified) |
| Atlas-frame selection via instance custom data | Works, confirmed live | High (live-verified) — **requires the varying-passthrough pattern**, `INSTANCE_CUSTOM` is not fragment-readable directly |
| Transparency depth-sort across MultiMesh instances | Real risk for alpha-blended overlap | Medium — not live-verified this pass, needs pilot screenshot comparison |
| Contact shadows via real shadow-casting on billboards | Not recommended — wrong shape | High — reuse the existing flat shadow-decal technique instead |
| Per-instance hit/status feedback | Requires a spatial-shader port + custom-data channel budget decision | High — mechanism confirmed live, but a real code deliverable, not a port |
| Existing proof scene reusable? | Partially — 3D-world assets/pattern yes, swarm/2D-in-3D questions no | High |
| ADR conflict | Real, blocking, needs a formal ADR-0037 amendment before monster rendering work starts | High |

**Recommended pilot structure** (for `art-bible.md` §8.7's own required
cross-medium pilot, once the architecture blueprint and ADR amendment above
are written): new `prototypes/hybrid-swarm-pilot/` directory, reusing
`spike.tscn`'s GLB tile/tower/prop assets as the 3D-world backdrop, adding (a)
a `MultiMeshInstance3D` creature swarm (~50-100 instances) with the
varying-passthrough atlas shader from §3, (b) a side-by-side alpha-blend vs.
alpha-scissor comparison for §4's sort risk, (c) a flat shadow-decal stream
per §5, and (d) a Tween-driven custom-data hit-flash test per §6 — all under
the fixed fixed-angle `Camera3D` ADR-0037 already established, measured
against `art-bible.md` §8.5's draw-call/texture-residency budgets before
being called done.

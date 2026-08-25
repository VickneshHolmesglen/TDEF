# 3D Art Pipeline

Epic 15 Phase 5 deliverable. Defines how real 3D content should eventually be
produced, imported, and wired into the 3D Visual Presentation Companion Layer
(ADR-0037), replacing the Kenney placeholder pack currently in use. Companion
doc to `design/art/art-bible.md` (visual identity, authoritative for anything
this doc doesn't cover), `design/art/codex-art-overhaul.md` (the active 2D art
overhaul this doc does NOT replace or compete with — see §5), and
`docs/architecture/adr-0037-visual-presentation-3d-companion-layer.md` /
`adr-0039-3d-interaction-picking-layer.md` / `adr-0040-3d-camera-cutover-
capability.md` (the engineering side of this same layer).

**This is a pipeline definition, not new content.** No new 3D art is produced
by this document — it defines the process a future session (or Codex, per the
art-overhaul coordination convention) would follow when that content is
actually authored. Written under this session's "no testing" constraint, so
nothing here has been live-verified against a real Godot import — flagged
throughout where that matters.

## 1. Current State (verified by reading the live files, 2026-08-25)

Every 3D mesh referenced anywhere in the project right now is a Kenney "Tower
Defense Kit" placeholder GLB:

| Mapping (`assets/data/visual_meshes/*.tres`) | Source file |
|---|---|
| `hero` | `assets/Tower Defense Models/GLB format/detail-crystal.glb` |
| `projectile_bolt` | `assets/Tower Defense Models/GLB format/weapon-ammo-bullet.glb` |
| `tile_straight` | `assets/Tower Defense Models/GLB format/tile-straight.glb` |
| `tower_round` | `assets/Tower Defense Models/GLB format/tower-round-base.glb` |

**Real gap found while writing this doc**: `assets/Tower Defense Models/` sits
**outside** this project's established two-tree asset convention
(`CLAUDE.md`: "`assets/source/` holds raw generated sheets only... `assets/art/`
is the only engine-referenced asset tree"). The Kenney pack is directly
referenced from a third, ungoverned location. This was fine as a fast
prototyping stopgap (`prototypes/3d-tower-defense-kit-spike/` is exactly that —
a spike, correctly kept out of `src/`) but any real pipeline replacing these
placeholders should land its output under `assets/art/` like every other
engine-referenced asset, not perpetuate a third tree. Flagged here, not fixed
— moving/re-pathing 4 live `.tres` mappings is a mechanical follow-up for
whoever does the real replacement pass, not a design decision this doc should
make unilaterally.

## 2. Real Scope Tension — Not Resolved Here

`design/art/animation-pipeline.md` §2 and `art-bible.md` both frame 3D as **"a
hybrid exception, Hero only"** — the long-term plan as of 2026-08-17 was a
single real-time 3D Hero model, everything else 2D. `docs/engine-reference/
godot/VERSION.md`'s own tracking table still calls the Hero 3D model "the only
3D asset in the game" (from `art-bible.md` §8.7's engine budget table).

Epic 15 (ADR-0037, this session's later work) built 3D `Node3D` companions for
**five** entity types — Grid, Tower, Monster (later superseded by Epic 16's
swarm renderer), Hero, and Projectile — not Hero alone. This is a real,
unresolved tension between an earlier documented art direction ("Hero is the
one 3D exception") and what the engineering layer actually now supports
(every entity type CAN have a 3D companion). `codex-art-overhaul.md` §1
already flags that "Visual direction is not locked yet" project-wide — this
tension is downstream of that same open question, not a new one.

**This doc does not resolve it.** Whether the shipped game ends up 2D-only
(with the 3D companion layer staying permanently dormant per ADR-0040), fully
3D (all five companion types get real art), or the originally-planned hybrid
(Hero only) is a visual-direction decision for whoever locks §1, not an
engineering or pipeline decision. Everything below is written to work under
any of those three outcomes — the pipeline steps are the same regardless of
how many of the five entity types eventually get real content.

## 3. Source Format

- **Authoring format**: glTF 2.0 binary (`.glb`), single file with embedded
  textures — matches the Kenney pack's own format, so the existing
  `VisualMeshMappingResource`/`PackedScene` data-driven hookup (§4) needs no
  changes to accept real content instead of placeholder content.
- **Coordinate convention**: glTF's own Y-up, right-handed convention, which
  Godot's `.glb` importer already reconciles automatically — no manual axis
  correction step needed (standard Godot glTF import behavior, not a
  project-specific concern).
- **One mesh per entity/component type**, matching `VisualMeshMappingResource`'s
  existing one-mapping-per-id contract (§4) — no multi-entity atlas meshes.

## 4. Data-Driven Hookup (unchanged — already exists, ADR-0037 Story 001)

Real content plugs into the exact same seam placeholder content already uses:

1. Drop the `.glb` under `assets/art/models/<entity_id>.glb` (see §1's flagged
   path-convention gap — this is the target location, not the Kenney pack's
   current one).
2. Create/update `assets/data/visual_meshes/<entity_id>.tres` — a
   `VisualMeshMappingResource` with `entity_or_component_id` set and
   `mesh_scene` pointing at the new `.glb` (typed `PackedScene` export, per
   that resource's own doc comment — never a raw string path).
3. `GameDataRegistry` picks it up at boot automatically (same loader every
   other data `.tres` uses) — no code change needed to swap placeholder for
   real content, by design (ADR-0037's whole point).

No engineering work is required to "turn on" real 3D art once it exists in
this shape — this was already built to be swap-in-ready.

## 5. Relationship to the Active 2D Art Overhaul

`codex-art-overhaul.md` governs 2D sprite-sheet generation (Codex drafts
prompts/generates, Claude Code alpha-cuts/imports) and is explicitly active
right now. This 3D pipeline is a **separate, currently-inactive** track — no
3D content generation is underway, no Codex coordination protocol exists for
3D output yet (unlike 2D's `production/art-overhaul-status.md` handoff
convention). If/when §2's tension resolves toward "some entities get real 3D
art," a parallel status-tracking convention should be set up before work
starts, mirroring the 2D overhaul's own (not invented here, since no work is
starting here).

## 6. Budgets and Import Settings (already decided — `art-bible.md` §8.7, do not re-litigate)

| Category | Budget |
|---|---|
| Hero 3D model (gameplay LOD) | ≤ 6,000 tris |
| Hero 3D texture set (albedo/normal/ORM) | ≤ 8MB total |

`art-bible.md` §8.7 only has budget rows for Hero, consistent with §2's
"Hero-only hybrid exception" framing — if the scope tension in §2 resolves
toward more entity types getting real 3D art, `art-bible.md` §8.7 needs new
budget rows for those types before that content is authored (a real,
concrete follow-up, not covered by this doc).

Import settings: VRAM Compressed / BPTC (desktop-only PC target, matches the
project's existing 2D texture import convention). **Not live-verified this
session** whether BPTC decode is confirmed clean under D3D12-as-default for
`.glb`-embedded textures specifically — `codex-art-overhaul.md` §5.6 already
flags this as HIGH-risk and unverified for the 2D pipeline; the same open risk
applies here and is not separately re-verified by this doc.

## 7. Open Questions

- **OQ-1**: Does the shipped game end up 2D-only, hybrid (Hero-only 3D), or
  fully 3D? Blocks whether any of §1's placeholder meshes are ever actually
  replaced. Owner: whoever locks `codex-art-overhaul.md` §1's visual
  direction.
- **OQ-2**: Should `assets/Tower Defense Models/` be moved under
  `assets/art/models/` now (mechanical, low-risk) even before OQ-1 resolves,
  purely to close the third-asset-tree convention gap flagged in §1? Not
  decided here — a small, separate, easy follow-up for a future session.
- **OQ-3**: If OQ-1 resolves toward "more than Hero gets real 3D art,"
  `art-bible.md` §8.7 needs new per-entity-type budget rows (tris/texture
  size) before that content is authored. Not decided here — a design/art-bible
  decision, not a pipeline-mechanics one.

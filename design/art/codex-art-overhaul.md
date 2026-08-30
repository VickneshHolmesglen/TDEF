# Art Overhaul — Codex + Claude Code Collaboration Brief

> **Audience**: this document is written for Codex to read directly. Claude Code
> also treats it as authoritative for this initiative. If the two disagree on
> process, this file wins; if it's silent, fall back to `AGENTS.md` (Codex) /
> `CLAUDE.md` (Claude Code) and `design/art/art-bible.md`.
>
> **Status**: Process/coordination doc — written 2026-08-23, updated 2026-08-29.
> The hybrid medium split and category-level Art Bible specifications are
> locked. The cross-medium Godot pilot **passed** (2026-08-24/25 — see
> `production/art-overhaul-status.md`'s Production Architecture section) —
> mass generation is now unblocked. **The backlog was empty until 2026-08-29**;
> it is now populated with a real first batch. **Read §0.5 below before
> picking up anything — it names Codex's current priority explicitly.**

## 0.5. Current priority for Codex (as of 2026-08-29)

**Generate the first backlog batch — 8 monster movement spritesheets.** See
`production/art-overhaul-status.md`'s Backlog table: every real, already-shipped
monster type currently has only a single static idle frame (confirmed by
inspecting the shipped `CreatureAtlasMappingResource` `.tres` files directly —
`atlas_columns=1, atlas_rows=1, frame_count=1`, one `"idle"` clip, nothing
else). `MonsterSwarmRenderer3D`'s atlas-frame-selection machinery has been
live-verified working (Epic 16) and has been sitting idle waiting for exactly
this content since 2026-08-24/25. Closing this gap is now the priority over
any other art category (towers, environment, UI, etc.) — those all already
have at least a first pass of real static art; monsters are the one category
that's still 100% static/idle-only with zero movement.

**Each backlog row has a standalone, upload-ready prompt file already
written** (`assets/art-generation-requests-2026-08-29-*.md`, plus one
pre-existing 2026-08-17 request for Goblin Runner) — no further scoping is
needed. Claim a row in the Backlog table, generate, drop the raw output where
the request file says, mark it `generated, awaiting processing`, and hand off
to Claude Code per the normal §3 workflow below. Once this batch is through
the pipeline, the next priority (idle/attack/death frames, or the remaining
static-art categories) will be scoped the same way — don't self-expand scope
mid-batch.

---

## 0. What this overhaul is

The user wants to **completely overhaul the game's art and visual assets** —
towers, monsters, hero, environment, UI, VFX, everything. This is not an
incremental "add more content in the existing style" pass (that's the normal,
ongoing workflow documented in `design/art/asset-generation-prompts.md`) — it's
a from-scratch re-evaluation of the whole visual language, executed across two
AI agents working in the same repo at the same time:

- **Codex** generates art: writes/runs image-generation prompts, produces raw
  output files.
- **Claude Code** processes art: alpha-cuts/slices raw output, imports it into
  Godot, wires it into scenes/resources, and handles any engine-side code
  changes the new art requires.

Both agents read and update `production/art-overhaul-status.md` (§4) so
neither duplicates or overwrites the other's in-flight work.

---

## 1. Locked visual foundation — 3D world, 2D creatures

The user locked the replacement foundation on 2026-08-23:

> **Sanctuary Defenders presents a tactile, dimensional world built and
> commanded by the player, while its invading creatures appear as expressive
> 2D illustrations brought to life within that world.**

Asset ownership is explicit:

- **3D:** hero, towers, major buildings, terrain, paths, Sanctuary architecture,
  large props, world lighting, and world shadows.
- **2D:** monsters and creatures, card illustrations, inventory/equipment and
  skill icons, portraits, UI ornamentation, and selected VFX.
- **Mixed effects:** 3D projectiles and world lighting may combine with 2D
  particles, decals, and impact frames.

This split follows player ownership: the player builds and commands a persistent
physical world; illustrated creatures enter it as threats. Shared silhouettes,
values, grounding shadows, outlines, and semantic accent colours must make the
two media feel intentionally composed.

The Diablo IV screenshots (`production/Hero Unequipped.PNG` and
`production/Hero 2H equipped.PNG`) are references for **Player Inventory UI
structure and presentation only**. Do not use them to infer world art, realism,
palette, lighting, environmental treatment, or character/creature style.

`design/art/art-bible.md` Sections 1–9 now carry the approved hybrid direction,
state lighting, shape and colour systems, character/environment/UI direction,
technical asset standards, and bounded reference set. Do not mass-generate final
assets until the representative cross-medium pilot defined in
`design/art/art-bible.md` §8.7 proves the 3D/2D compositing and swarm-rendering
approach within the project budgets.

---

## 2. Known layout/UI gaps to fold into this pass

The user has flagged two annotated screenshots of the actual running game as
in-scope problems for this overhaul (not just new art — composition/layout
fixes too):

**`production/Issues.PNG`** (earlier build, SCOUT phase):
- Large dead gray space in the top-left and bottom-left of the window, outside
  the game viewport — the play area doesn't fill the window well.
- Skill-ready row text overlaps/overflows: `"Skill 1: Ready Skill 2: Ready
  Skill 3: Read[y] Skill 4: Ready"` runs together as one unbroken line and
  visibly clips.
- Empty/unused-looking placeable cells in the mid-field and near-hero areas
  (marked in blue) — may be a composition/decoration gap (bare terrain reading
  as "nothing here") rather than a functional bug.

**`production/UI Changes.PNG`** (later build, PRE_WAVE phase — more UI built
out: tower-select palette top-left, numbered skill buttons, Skip Countdown
button):
- Dead/empty stone-texture margin on the right edge of the frame (yellow box)
  and top-right corner (red box) — the rock-bezel background reads as unused
  space rather than intentional framing.
- Bottom-left corner (blue box) is bare rock with no HUD content, similar dead
  space concern.
- Bottom-right monster-composition label ("Spore Skitterling x5", green box)
  sits directly against the frame edge with no breathing room.

Treat these as **real, concrete gaps to design around** during the overhaul —
not necessarily "more art" fixes on their own (some may need layout/anchor
changes in `mission_hud.gd`/`mission_scene.gd`, which is Claude Code's side),
but any new background/frame art Codex generates should be sized and composed
with these dead-space complaints in mind rather than reproducing them.

---

## 3. Division of labor — exact workflow

Mirrors the project's existing manual pipeline (`AGENTS.md` / `CLAUDE.md`
"Asset Generation" section, being updated alongside this document) with Codex
now doing the generation step instead of the user manually running ChatGPT:

1. **Codex** picks up an item from `production/art-overhaul-status.md`,
   claims it (§4), and drafts a generation prompt. Log the prompt in
   `design/art/asset-generation-prompts.md` (the project's existing running
   log — reuse its format: date, target, prompt text, status) so prompts are
   reusable/regeneratable later, exactly like every prior asset in this
   project.
2. **Codex** runs the prompt through its image-generation capability and
   drops the raw output into `assets/source/<category>/` using a snake_case
   filename matching the target asset (see §5.3 naming convention). This
   mirrors where the user used to manually drop ChatGPT output — nothing else
   in the pipeline needs to know generation is now automated.
3. **Codex** updates `production/art-overhaul-status.md`: marks the item
   `generated, awaiting processing` and notes the source file path.
4. **Claude Code** picks up items marked `generated, awaiting processing`,
   alpha-cuts/slices the raw sheet (§5.2 technique + gotchas), writes the
   processed file(s) to `assets/art/<category>/`, wires them into the
   relevant scene/resource/script, runs the Godot editor import pass (§5.4),
   and live-verifies via Godot MCP if the asset is wired into a running scene.
5. **Claude Code** updates the status file: `processed + wired`, with the
   commit hash once pushed.
6. Either agent may flag an item `blocked` (bad generation, alpha-cut
   failure, wrong scale, needs a regen) with a note — the other agent should
   not silently retry without reading why it was blocked.

**Do not swap roles mid-item.** If Codex notices an asset needs engine-code
changes beyond simple wiring (e.g. a new animation state, a new shader), leave
it flagged for Claude Code rather than writing GDScript directly — matches
this project's existing engine-specialist routing conventions
(`.claude/docs/technical-preferences.md` → Engine Specialists).

---

## 4. Shared status file — `production/art-overhaul-status.md`

A living, git-tracked file both agents read before starting work and update
immediately after finishing a step (not batched at session end) — this is
what prevents both agents claiming the same asset. Unlike
`production/session-state/active.md` (gitignored, single-agent, general dev
session notes), this file is **committed** specifically so a fresh Codex or
Claude Code session in a different terminal picks up current state immediately.

See that file for its exact format. Rules for using it:

- **Claim before generating or processing.** Before starting any item, set its
  status to `claimed by Codex` / `claimed by Claude Code` and commit that
  change *before* doing the actual work, so a concurrent session sees the
  claim. If you see an item already claimed by the other agent, do not touch
  it — pick a different item or wait.
- **Update immediately on completion or blockage**, not at end of session —
  the other agent may be actively deciding what to pick up next.
- **Never delete history rows** — move completed items to the "Done" section
  rather than removing them, so the file also serves as a changelog of the
  overhaul (mirrors `asset-generation-prompts.md`'s own append-only,
  outcome-logging convention).
- **One row per asset or tightly-scoped batch**, not per category — matches
  the granularity `asset-generation-prompts.md` already uses (e.g. one entry
  per "12-tile terrain batch," not one giant "environment" entry).

---

## 5. Technical reference (style-independent — stays valid regardless of §1's outcome)

### 5.1 Folder structure

- `assets/source/<category>/` — raw generated sheets. Nothing in the engine
  loads from here directly. snake_case filenames.
- `assets/art/<category>/` — final, sliced/alpha-cut, engine-referenced
  assets. The **only** tree Godot resources point at.
- Categories in use today: `towers/`, `monsters/`, `species/` (Menagerie),
  `main_menu/`, `sanctuary/`, `tarot/`, `props/`. Add new categories as needed
  for this overhaul (e.g. `hero/`, `ui/`) rather than overloading an existing
  one — mirrors the project's existing per-system directory convention
  (`.claude/docs/directory-structure.md`).

### 5.2 Alpha-cut technique (Claude Code's side, documented here so Codex
knows why a raw generation's background choice matters)

Two methods, chosen per-sheet based on contrast:

- **Color-distance threshold** — for high-contrast sheets (flat background,
  opaque bright subject). Simple: cut any pixel within a distance threshold of
  the known background color.
- **Connected-component flood-fill from the canvas border** — for
  low-contrast sheets (dark/near-black subjects, sticker-style outlines, VFX
  fading toward the background color). Marks cuttable pixels by color
  distance, but only actually cuts the region topologically connected to the
  image edge — so interior dark detail that *looks* cuttable but isn't
  connected to the border survives.

**Hard-won lessons (apply to every new batch, don't assume last time's number
still works):**
- **The right threshold is never transferable between generations**, even
  same-concept regenerations of the same subject. Past examples ranged
  `dist<16` to `dist<32` across otherwise-similar tower sheets, because each
  render's ambient-occlusion/shadow gradient sits at a different distance from
  its own background color. Always spot-check the darkest/most-shadowed
  variant in a batch against a bright contrasting backdrop before trusting a
  slice.
- **Background color must be named literally** in prompts (`#000000`), not
  described loosely (`"dark background"`) — models sometimes render
  near-black chiaroscuro lighting that can't be cleanly thresholded from a
  true-black backdrop.
- **Tarot/card-style prompts specifically**: asking for "no text, no border,
  no frame" was not sufficient on its own — 3 of the first 10 generations came
  back as full bordered card mockups anyway. What worked: drop the word
  "tarot-card"/"playing card" from the prompt entirely (say "fantasy
  character/object illustration, NOT a tarot card, NOT a playing card"
  instead), and make the anti-frame instruction its own standalone sentence,
  not one clause among several.
- **Format consistency for any programmatic compositing** (e.g. blending
  props onto a base terrain image): source and destination images must share
  the exact same pixel format (`Image.FORMAT_RGBA8` vs `FORMAT_RGB8` mismatches
  fail silently in Godot's `blend_rect()` — no error, just nothing drawn).

### 5.3 Naming convention

`[category]_[name]_[variant]_[size].[ext]` — category-first, purpose-second,
matching this project's code naming logic (snake_case, test-file style). The
`[variant]` slot should carry **art-meaningful** state (e.g. `_tier1`–`_tier4`,
`_pristine/_used/_marked`, `_idle/_move/_attack`), not arbitrary numbering, so
the filename documents which content rule the asset instantiates.

### 5.4 Godot import gotcha

New PNGs added directly to the filesystem (not through the editor) have no
`.import` sidecar and fail to `preload()` at runtime ("Parse Error: ... has no
resource loaders") until an editor filesystem scan runs. Fix — run after every
asset drop, before attempting to run/screenshot a scene referencing new art:

```
"<Godot 4.6.2 executable path>" --headless --editor --path "G:/TDef" --quit
```

This is a **different** cache from the `global_script_class_cache.cfg` issue
documented in `.claude/docs/context-management.md` — same root cause category
(headless mode skips an editor-only scan), different cache file.

### 5.5 Scale — always verify explicitly, never trust default sizing

Source art from AI generation arrives at native generator resolution
(900–1200px+) with wildly inconsistent dimensions between assets, and Godot
has multiple independent auto-sizing mechanisms (`Sprite2D.scale`,
`Button.icon` sizing, `TextureRect.expand_mode`) that can each silently
override an explicit `.size`/`.scale` assignment depending on node type and
configuration. **Any time a new art asset from this pipeline gets bound to a
node, verify its actual on-screen scale via a live Godot MCP screenshot before
considering it done** — do not assume a `.size`/`.scale` line in code is
sufficient. This has broken 3 separate times in this project's history for 3
different node types; assume it will break a 4th time if unverified.

### 5.6 Engine budgets (Godot 4.6.2, from `art-bible.md` §8.7 — these stay
valid regardless of §1's style outcome, since they're perf/engine constraints
not aesthetic ones)

| Category | Budget |
|---|---|
| Hero 3D model (gameplay LOD, only 3D asset in the game) | ≤ 6,000 tris |
| Standard monster sprite sheet | ≤ 256KB compressed |
| Boss sprite sheet | ≤ 2MB compressed |
| Environment/tile atlases | ≤ 4MB/atlas, ≤ 6 atlases resident |
| Hero 3D texture set (albedo/normal/ORM) | ≤ 8MB total |
| VFX effect sheet | ≤ 1MB |
| Aggregate texture VRAM target | ≤ 400–500MB (project ceiling: 1GB total) |
| Draw calls | ≤ 200/frame (`technical-preferences.md`) — per-tier atlas/material sharing keeps 100-monster swarms to 1–3 draw calls; any per-instance shader override breaks batching |

Import settings: VRAM Compressed / BPTC (desktop-only PC target), mipmaps OFF
for 2D sprites (fixed-zoom oblique camera, no scale-down aliasing to correct),
Linear filtering (no mipmap filter) for sprites. **Verify BPTC decode under
D3D12-as-default before locking this** — flagged HIGH-risk in
`docs/engine-reference/godot/VERSION.md`.

### 5.7 Animation architecture — already decided, don't re-litigate

`design/art/animation-pipeline.md` (92 lines) already specifies: per-entity
animation technique selection (frame/cutout/procedural), Godot-native
`AnimatedSprite2D`/`AnimationPlayer`/`AnimationTree`/`Skeleton2D` usage rules,
and a plugin evaluation (Importality/AnimSheet/Anima/Pixels-Prof — all
evaluated 2026-08-17, all rejected; see `.claude/docs/technical-preferences.md`
Forbidden Patterns for the per-plugin reasoning). This overhaul can and should
regenerate the *art* extensively, but the animation *architecture* around it
is settled — read that document rather than re-deriving frame-count/rigging
decisions from scratch.

### 5.8 Reuse via runtime tint/overlay — don't always request a new asset per
element/variant

Not every visual variant needs its own generated asset. Where a game system
already differentiates variants by a defined **color** (element, archetype,
rarity tier), Claude Code can often express a new variant on TOP of existing
shared art via a cheap runtime technique — `Sprite2D.modulate`, or a
procedurally-drawn overlay (`Node2D._draw()` primitives, no texture at all) —
instead of Codex generating a full new sprite. This keeps the asset count from
growing multiplicatively (shapes × variants) instead of additively
(shapes + variants), which matters as this overhaul scales up combinatorial
content (e.g. the tower Base/Shaft/Top layer system in this same section).

**Real precedent, not theoretical**: `TowerInstance` (`src/core/tower/
tower_instance.gd`) ships 9 full elemental tower textures (`ELEMENT_TEXTURES`
— fire/frost/lightning/poison/earth/water/wind/shadow/holy), but a real
shipped tower (`blueprint_arcane_lance.tres`, `element="arcane"`) had no
bespoke texture and silently rendered as generic ice-themed art with zero
color identity. Rather than requesting a 10th full texture from Codex, Claude
Code added a persistent procedural ring drawn via `_draw()` (no new art asset,
2026-08-29/30) colored from the project's existing `ProjectileVisual.
ELEMENT_COLORS` table — the same color already used for that element's
projectiles/AoE rings/destroy-VFX elsewhere. Any future element that ships a
`ProjectileVisual.ELEMENT_COLORS` entry before it has bespoke tower art gets
this ring automatically, no generation request needed until/unless bespoke
art is later commissioned for it.

**What this means for Codex when scoping a new request:**
- **Before drafting a prompt for "one asset per element/tier/variant,"
  check whether the variants only need to differ by a defined color** the
  codebase already tracks (grep for `ARCHETYPE_COLORS`/`ELEMENT_COLORS` in
  `src/scenes/projectile_visual.gd`, this project's single source of truth for
  element colors) — if so, flag it to Claude Code as a tint/overlay candidate
  instead of generating N full variants.
- This does **not** replace genuine silhouette variety — a cannon and a
  crystal spike still need separate art (see the tower weapon-top batch,
  §0.5's Backlog). Reuse-via-tint is for variants that would otherwise be
  the *same shape, different color only*.
- Claude Code decides and implements the actual tint/overlay mechanism
  (it's engine-code work, per §3's role split) — Codex's job is just to
  recognize the pattern and avoid over-requesting art for a color-only
  distinction.

---

## 6. What NOT to do

- Don't mass-generate final, ship-bound art before the category-level 3D/2D
  architecture and remaining Art Bible sections are reconciled with §1.
- Don't apply the Diablo screenshots outside Player Inventory UI.
- Don't re-evaluate the animation plugin question (§5.7) without new evidence.
- Don't skip the status-file claim step "because it's just one small asset" —
  the coordination protocol only works if both agents follow it every time.
- Don't have Codex write GDScript/scene-wiring code directly (§3) — flag for
  Claude Code instead, per this project's existing engine-specialist routing.
- Don't treat `production/Issues.PNG`/`UI Changes.PNG` as stale just because
  newer builds exist — the user explicitly confirmed these gaps are in scope.

---

## 7. Recommended first steps

1. Treat `design/art/art-bible.md` Section 1 as locked and audit Sections 2–9
   for assumptions inherited from the former hero-only-3D diorama direction.
2. Read `design/art/asset-generation-prompts.md` for the project's prompt
   voice/patterns and full outcome history — reuse successful phrasing, don't
   reinvent it.
3. Define the Godot scene/rendering architecture and category-level production
   standards for the locked 3D-world/2D-creatures split.
4. After that specification is approved, initialize the backlog and run a small
   cross-medium pilot scene before full production begins.

# Amuse Local Generation — HD-2D Storybook Style Prompt Sheet

> **Created**: 2026-11-01
> **Tool**: Amuse v3.8.6 (https://github.com/saddam213/AmuseAI/releases), running
> locally on the RX 6800 XT (16 GB) via the Vulkan or ROCm backend.
> **Style target**: the bright storybook HD-2D look of *The Adventures of Elliot*
> (warm sunlit fairytale palette, chunky readable sprites standing in 3D
> dioramas), applied to Sanctuary Defenders' own designs.
> **Pipeline position**: this sheet produces *painted originals*. Pixel-art
> conversion is done afterwards by `tools/asset-pipeline/hd2d/pixelate_sprites.py`,
> not by the image model.

---

## 0. Ground rules (read once)

1. **Do not name the game, studio, or its characters in any prompt.** The
   sheet describes style *traits*. Naming the title pulls the model toward
   its real characters and settings, and most local models don't know a 2025
   release anyway.
2. **No img2img, ControlNet, or LoRA built from screenshots or ripped
   sprites** of that game. Style is fine; copied assets are a legal risk for
   a Steam release. Our own existing art (`assets/source/painted/`) is fine
   to use as img2img or ControlNet input.
3. **Ask for painted, not pixel art.** AI pixel art lands off-grid with
   inconsistent pixel sizes. `pixelate_sprites.py` does the conversion
   properly: palette reduction, hard alpha, 1 px outline, and the same
   palette shared across sheet frames.
4. **One subject per image, centred, on a flat solid background.** No
   ground plane, no cast shadow. The engine adds shadows (sprite shadow
   footprint, HD-2D sun).
5. **Raw output is never final** (art bible §8). Every image goes through
   alpha-cut, then pixelation, then a live in-engine check before it is wired
   in.
6. **Check each model's license** before shipping its output. FLUX, SDXL
   and other families have different commercial-use terms. Record the model
   name and seed for every keeper (see §7).

---

## 1. Style block (paste into every prompt)

The shared style description. Every asset prompt below is
`[SUBJECT] + [STYLE BLOCK] + [BACKGROUND LINE]`.

```
storybook fantasy game sprite, hand-painted illustration with clean simple
shapes, bold readable silhouette, soft cel shading with two or three value
steps, warm golden afternoon sunlight from the upper left, gentle pale rim
light, saturated but earthy colours, cosy fairytale mood, slightly chunky
heroic proportions, crisp edges, minimal fine texture, game asset concept art
```

**Why each phrase is there**

| Phrase | Purpose |
|---|---|
| clean simple shapes / minimal fine texture | Fine painterly noise turns into speckle after pixelation. Big shapes survive it. |
| two or three value steps | Matches the 2–3 tone bands a pixel sprite holds per material. |
| upper-left sunlight | Matches the HD-2D `Hd2dScenery` sun, so painted light agrees with real light. |
| pale rim light | Hero profile §3 requires a standing rim highlight. It also separates the sprite from the ground. |
| saturated but earthy | Storybook brightness without breaking the art bible's restrained material palette (§4.1). |
| slightly chunky heroic proportions | The storybook read. See §1.1 for the limit. |

### 1.1 Proportion guard: a decision you may need to make

The Elliot look leans **chibi** (about 3 heads tall). The art bible currently
says to avoid toy proportions (§9 reference notes), and the Hero profile
requires a **1.8:1 height:width idle silhouette** with a pointed or domed
crown. This sheet uses **about 4 heads tall, sturdy build**, which keeps the
storybook charm and still meets 1.8:1. If you want real chibi, the art bible
and hero profile have to change first. Don't let generations drift there on
their own.

### 1.2 Negative prompt (paste into every generation)

```
text, letters, watermark, signature, logo, frame, border, card, panel, UI,
multiple views, character sheet, turnaround, cropped, cut off, ground,
floor, cast shadow, drop shadow, scenery, background details, gradient
background, vignette, photorealistic, 3d render, plastic, pixel art,
pixelated, jpeg artifacts, blurry, noisy texture, extra limbs, extra fingers,
deformed hands, purple, violet
```

`purple, violet` is there because **purple is reserved for bosses**
(art bible §4.2). Remove it from the negative only when generating a boss.

### 1.3 Background line (alpha-cut contract)

Name the background colour as a literal hex value (codex-art-overhaul §5.2).
Loose wording like "dark background" fails.

| Subject | Background line | Why |
|---|---|---|
| **Default** (characters, monsters, towers, props, buildings) | `isolated on a flat solid pure magenta #FF00FF background` | No reserved palette colour is near magenta, and it works for dark and light subjects alike. |
| Foliage / grass / anything green | `isolated on a flat solid pure magenta #FF00FF background` | Same. Never use green-screen for plants. |
| Magenta/rose subjects (Arcane `#C96A91` items) | `isolated on a flat solid pure black #000000 background` | Rose is too close to magenta. Use the flood-fill-from-border cut. |

---

## 2. Palette anchors (words beat hex for image models)

Image models follow colour *words* far better than hex codes. Use these
words in the prompt and use the hex values to check the result.

| Role | Prompt words | Check against |
|---|---|---|
| Player warmth, crafted accents | honey amber, warm brass | Hearth Amber `#C88432` |
| Light surfaces | cream, warm parchment | Refuge Cream `#E8DEC3` |
| Stone, masonry | weathered grey fieldstone | Fieldstone `#888983` |
| Recesses | soft charcoal | Ash Charcoal `#292C32` (never pure black) |
| Cool shadow, distance | dusty slate blue | Watch Blue `#3F6982` |
| Vegetation | soft sage green, mossy green | Living Green `#4E8053` (duller than healing green) |
| Danger only | — never in prompts for neutral assets — | Threat Red `#C43B36` |

Storybook push: in the *subject* line, words like "sunlit", "warm",
"cheerful" and "freshly painted" lift saturation inside these families.
Don't introduce new hues to get brightness.

---

## 3. Recommended Amuse settings (starting point)

| Setting | Value | Note |
|---|---|---|
| Backend | Vulkan first. Try ROCm if offered (v3.8.3 added ROCm 10.1). | Compare speed on one fixed seed. |
| Model class | SDXL-class or FLUX Klein-class to start | Fits 16 GB comfortably. Move to bigger models (FLUX.2 GGUF) only if quality is lacking. |
| Resolution: characters/monsters | 832 × 1216 (portrait) | Matches existing painted sources (1024 × 1536 hero, ~2:3). |
| Resolution: towers/trees | 832 × 1216 or 1024 × 1024 | |
| Resolution: props/items | 1024 × 1024 | Existing items are ~700–1100 px square-ish. |
| Steps / CFG | Model defaults first, then ±20 % | Note what worked in §7. |
| Batch | 4 per prompt | Pick the best and lock its seed for variants. |
| Seed | **Lock it** once a keeper appears | Variants (tiers, damage states, palette swaps) reuse the seed and change one phrase. |

---

## 4. Starter prompts (pilot batch: generate these first)

Art bible §8 prohibits mass generation before a pilot. Run these **five**,
review them in-engine, then expand.

### 4.1 Hero: Warden-Smith (pilot P1)

```
full body sprite of a warden-smith hero standing in a wide planted idle
stance, three-quarter view facing right, a sturdy craftsperson-soldier about
four heads tall, close-wrap hardened leather hood finishing in a rounded
dome crown, dark warm brown tanned leather armour with visible stitching,
hammered grey iron shoulder cap, forearm bracer and shin guards, a smithing
hammer on the belt and a cord-wrapped warhammer held low, honey amber cord
wraps, calm determined expression, lean deliberate silhouette,
[STYLE BLOCK], [BACKGROUND LINE]
```

Check: crown is the highest point, height:width ≈ 1.8:1, no plume, no robe,
no full bucket helm (hero profile §2).

### 4.2 Monster: Goblin Runner (pilot P2)

```
full body sprite of a small wiry goblin scout mid-stride, three-quarter view
facing left, oversized pointed ears, mossy green-grey skin, patched brown
leather jerkin, a crude short blade, mischievous grin, light quick pose,
readable at small size, [STYLE BLOCK], [BACKGROUND LINE]
```

Check: still reads as goblin_runner next to the existing
`assets/source/painted/monsters/` art. It is a restyle, not a redesign.

### 4.3 Tower: Archer tower (pilot P3)

```
a single small defensive archer tower, three-quarter top-down view, round
weathered grey fieldstone base, warm timber upper platform with a honey
amber cloth awning, a mounted crossbow on top, brass fittings, sturdy and
hand-built, slightly chunky toy-diorama proportions but solid,
[STYLE BLOCK], [BACKGROUND LINE]
```

Check: compare against the existing archer components
(`assets/source/painted/items/archer_*`). Tower Assembly stacks
Foundation/Weapon/Focus/Power layers, so a single whole-tower image is a
**look test only**. Production towers still need per-component prompts.

### 4.4 Tree / foliage card (pilot P4)

```
a single round leafy storybook tree, front view, soft sage and mossy green
canopy built from a few large clumped leaf masses, sunlit warm highlights on
the upper left of each clump, short sturdy brown trunk, no ground, no roots
spreading, [STYLE BLOCK], [BACKGROUND LINE]
```

Output target: replaces a foliage card such as `assets/art/hd2d/card_leaves_0.png`.
These are billboards in the 3D scenery layer, so the image must be a
**flat-on front view** with no perspective tilt.

### 4.5 Prop: Mossy rock cluster (pilot P5)

```
a small cluster of three rounded mossy boulders, three-quarter top-down
view, weathered grey fieldstone with soft sage moss caps and a few tiny
cream wildflowers, [STYLE BLOCK], [BACKGROUND LINE]
```

---

## 5. Expansion templates (after the pilot passes)

Swap the bracketed part. Keep everything else, including the seed when
making variants of one asset.

| Category | Subject template |
|---|---|
| Monster | `full body sprite of a [creature + 3 defining features], three-quarter view facing left, [colour words from §2], [pose: idle / mid-stride / attack wind-up]` |
| Elite monster | add `slightly larger, heavier armour plates, a single honey amber trophy accent` |
| Boss | add `imposing, crowned silhouette, deep violet accents` and **remove `purple, violet` from the negative** |
| Tower component | `a single [foundation / weapon / focus / power] component for a modular defence tower, [material], three-quarter top-down view, designed to stack on other parts` |
| Item icon | `a single [item], three-quarter view, centred, bold readable icon silhouette` (+ `NOT a card, NOT a frame` as its own sentence, per §5.2's tarot lesson) |
| Building (Sanctuary) | `a single storybook [building type], three-quarter top-down view, timber frame and fieldstone, warm honey amber window glow, cream plaster, slate blue roof tiles` |
| Grass / flower card | `a small dense tuft of [grass / wildflowers], front view, flat-on, soft sage green blades with warm sunlit tips` |
| Ground texture | **Not recommended in Amuse yet.** Ground is procedural (`generate_hd2d_textures.py`) and must tile seamlessly. Only try it if Amuse exposes a tiling/seamless option, and verify by offset-wrapping the result. |

---

## 6. Handoff: from Amuse to the engine

1. **Save raw output** to `assets/source/amuse/<category>/` using the naming
   convention `[category]_[name]_[variant].png` (codex-art-overhaul §5.3),
   e.g. `assets/source/amuse/monsters/monster_goblin_runner_idle.png`.
2. **Tell Claude Code** which files are keepers. Claude then:
   - alpha-cuts the magenta (colour-distance) or black (flood-fill from the
     border) background, spot-checking the darkest area on a bright backdrop;
   - trims or pads to the target asset's **existing canvas size** so nothing
     reading texture sizes has to change;
   - writes the painted original into `assets/source/painted/<same relative path>`;
   - runs `python tools/asset-pipeline/hd2d/pixelate_sprites.py --batch`
     (or `--preview` first) to produce the pixel version in `assets/art/`;
   - checks it live in a mission scene before calling it done.
3. Update `production/art-overhaul-status.md` for each item.

---

## 7. Keeper log

Record every image that is wired in, so it can be regenerated later.

| Date | Asset | Model | Seed | Steps / CFG | Prompt delta vs template | Result notes |
|---|---|---|---|---|---|---|
| | P1 hero | | | | | |
| | P2 goblin runner | | | | | |
| | P3 archer tower | | | | | |
| | P4 tree card | | | | | |
| | P5 rock cluster | | | | | |

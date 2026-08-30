# Art Generation Request — BOSS Attack Animations (2026-08-30)

This file is meant to be uploaded directly into an image generator. Per
`design/gdd/monster.md`'s Visual/Audio Requirements table, **only BOSS-tier
monsters need attack animations** — STANDARD and ELITE never attack towers
(only BOSS does, per Rule 17), so this batch covers exactly the 2 shipped
BOSS creatures: **Goblin Warlord** and **Rift Sentinel**. `Iron Colossus`
is ELITE tier (confirmed: `tier = 1` in `assets/data/monsters/
iron_colossus_elite.tres`), not BOSS — it does **not** need attack frames,
only walk + death (death is handled by the existing procedural dissolve
VFX, not new art — see the closing note).

Two animation clips are needed per BOSS, per `design/gdd/monster.md`'s
BOSS Scene Structure (two-layer `AnimatedSprite2D` — these play on the
**overlay** layer, while `"walk"` keeps playing uninterrupted on the base
layer underneath):

- **`"attack_prepare"`** — the telegraph/wind-up. ~4 frames (matches
  `boss_attack_prepare_frames` default of 4). This is the player's ONLY
  warning before the attack fires — per the GDD, "must be visually
  distinct" from both walk and the attack itself.
- **`"attack"`** — the strike/release. 4–6 frames, 12 FPS (faster than
  walk's 8 FPS — the GDD's own Frame Count Guidance table).

## Critical process notes — read before generating (lessons from this
project's last processing pass)

**1. Leave real gaps between poses, wider than usual.** The last
walk-cycle batch shipped poses that visually touch or overlap in several
sheets (a raised weapon, a claw, or a limb bridging into the next frame's
space) — this made automated slicing fail on 5 of 8 sheets and required
scrapping that automation for manual work. For THIS batch: leave a clearly
visible solid-background gap of at least one character-width between each
pose, even if it means a wider overall canvas. Every pose must have its own
fully isolated silhouette with true background-color space on both sides —
no weapon tip, cape, banner, or limb crossing into a neighboring pose's
column.

**2. Match the reference art's in-canvas character scale exactly, not just
identity/style.** The last batch's walk poses rendered at a visibly smaller
scale within their own canvas than the shipped idle art — bottom-anchoring
them together made the creature appear to shrink when it started moving, a
real bug Claude Code had to fix by manually rescaling every frame after the
fact. For THIS batch: the character's height as a fraction of the canvas
must match the reference image's own proportions as closely as possible —
imagine the reference pasted directly onto your canvas as a size guide, not
just a style guide.

**3. Plain, named background color.** `#000000`, stated literally in the
prompt, not "dark background."

---

## 1. Goblin Warlord — Attack Prepare (`goblin_warlord_boss_attack_prepare.png`)

### Reference (must match — this monster already has shipped static art)

`goblin_warlord_boss.png` (idle) and `goblin_warlord_boss_walk.png` (walk,
already generated) exist in `assets/art/monsters/` / `assets/source/
monsters/`. Same creature, same materials, same silhouette rules, same
in-canvas scale as both — this is a new pose set for an existing asset,
not a redesign.

Original prompt (for reference, do not resend — describes the creature only):
> Isometric fantasy game monster asset, "Goblin Warlord" boss, single creature
> centered on a plain dark background for easy cutout. A massive goblin
> chieftain, deliberately oversized relative to a normal goblin — reads as
> "too large to be a standard enemy" instantly. Heavy ornate armor assembled
> from scavenged/mismatched plates, one dominant mass (a huge armored
> torso/gut) plus one secondary accent (a large banner or standard mounted on
> its back). One held ranged weapon (a crude thrown spear or hooked javelin).
> Dull green skin (approved exception, muted/desaturated), dark leather and
> scavenged bronze/iron armor. Painterly pixel-art, hand-painted miniature
> diorama style, fixed oblique isometric angle. Avoid pure blood-red, purple,
> or cyan anywhere.

### Prompt

```
Isometric fantasy game monster asset, a 4-frame attack wind-up/telegraph
animation sheet for the "Goblin Warlord" boss (reference art attached/
described above — same creature, same armor, same scale). Each of the 4
frames shows the warlord winding up to throw its held javelin/spear: frame
1 = weapon lowered, beginning to raise it; frame 2 = weapon drawn back
past shoulder height; frame 3 = weapon fully cocked overhead, torso
twisted back, maximum tension; frame 4 = a held beat at peak tension,
nearly identical to frame 3 but with a subtle glint/highlight on the
weapon tip signaling imminent release. This is a WIND-UP only — do not
show the weapon being thrown or released in any frame. Each of the 4
poses must be fully isolated with a clear solid-black (#000000) gap of at
least one character-width between it and its neighbors — no weapon, cape,
or banner crossing into a neighboring pose's space. All 4 poses must
match the reference art's exact in-canvas character scale and proportions
— do not render the character smaller or larger than the reference within
its own frame. Painterly pixel-art, hand-painted miniature diorama style,
fixed oblique isometric angle, dull muted-green skin, dark leather and
scavenged bronze/iron armor. Avoid pure blood-red, purple, or cyan
anywhere.
```

## 2. Goblin Warlord — Attack (`goblin_warlord_boss_attack.png`)

### Prompt

```
Isometric fantasy game monster asset, a 5-frame attack-release animation
sheet for the "Goblin Warlord" boss (same creature/reference as the
attack-prepare sheet above — same armor, same scale). Each of the 5
frames shows the warlord's javelin/spear throw following through from
the fully-cocked wind-up: frame 1 = weapon just released, arm snapping
forward, javelin leaving the hand; frame 2 = arm at full extension,
follow-through; frame 3 = torso rotating forward with the throw's
momentum; frame 4 = beginning to settle/recover; frame 5 = fully
recovered, weapon-hand back at a neutral ready position (a natural loop
point back toward the idle/walk pose). Each of the 5 poses must be fully
isolated with a clear solid-black (#000000) gap of at least one
character-width between it and its neighbors — no weapon, cape, or
banner crossing into a neighboring pose's space. All 5 poses must match
the reference art's exact in-canvas character scale and proportions.
Painterly pixel-art, hand-painted miniature diorama style, fixed oblique
isometric angle, dull muted-green skin, dark leather and scavenged
bronze/iron armor. Avoid pure blood-red, purple, or cyan anywhere.
```

---

## 3. Rift Sentinel — Attack Prepare (`rift_sentinel_boss_attack_prepare.png`)

### Reference (must match — this monster already has shipped static art)

`rift_sentinel_boss.png` (idle) and `rift_sentinel_boss_glide.png` (glide,
already generated) exist in `assets/art/monsters/` / `assets/source/
monsters/`. **Known alpha-cut gotcha carried over from the static art**:
this creature's obsidian body reads nearly identical to the background
color by design — expect the same when slicing this sheet; a tighter cut
threshold will likely be needed. Same creature, same materials, same
silhouette rules, same in-canvas scale as both existing pieces.

Original prompt (for reference, do not resend — describes the creature only):
> Isometric fantasy game monster asset, "Rift Sentinel" boss, single creature
> centered on a plain dark background for easy cutout. A tall, imposing
> construct/guardian entity, deliberately oversized. One dominant mass (a
> towering armored torso built from dark stone or obsidian-like material,
> fused with glowing cracked seams) plus one secondary accent (a floating or
> orbiting secondary element — a rune-etched ring or shard). Cracked-seam glow
> should be a cool blue-white or amber-gold — explicitly NOT purple, NOT cyan.
> Dark grey/black stone body, angular and "constructed" rather than organic.
> Painterly pixel-art, hand-painted miniature diorama style, fixed oblique
> isometric angle.

### Prompt

```
Isometric fantasy game monster asset, a 4-frame attack wind-up/telegraph
animation sheet for the "Rift Sentinel" boss (reference art attached/
described above — same creature, same obsidian-and-glowing-seam material,
same scale). This is a construct, not an organic creature — the telegraph
should read as a charging/gathering-energy buildup, not a physical wind-up:
frame 1 = the orbiting rune-ring/shard begins accelerating and glowing
brighter; frame 2 = cracked seams across the torso intensify their glow,
ring visibly faster; frame 3 = a bright energy core becomes visible at the
chest/core, ring at its fastest and tightest orbit; frame 4 = a held beat
at peak charge, maximum glow intensity, signaling imminent release. Do
not show any energy actually firing/releasing in any frame — wind-up
only. Each of the 4 poses must be fully isolated with a clear solid-black
(#000000) gap of at least one character-width between it and its
neighbors. All 4 poses must match the reference art's exact in-canvas
character scale and proportions. Cracked-seam and core glow must be cool
blue-white or amber-gold — explicitly NOT purple, NOT cyan. Painterly
pixel-art, hand-painted miniature diorama style, fixed oblique isometric
angle, dark grey/black stone body, angular and constructed rather than
organic.
```

## 4. Rift Sentinel — Attack (`rift_sentinel_boss_attack.png`)

### Prompt

```
Isometric fantasy game monster asset, a 5-frame attack-release animation
sheet for the "Rift Sentinel" boss (same creature/reference as the
attack-prepare sheet above — same material, same scale). Each of the 5
frames shows the charged energy releasing from the peak-charge wind-up:
frame 1 = a bright beam or bolt of energy just discharging from the
chest core, core flash at its brightest; frame 2 = the discharge
continuing, core dimming slightly as energy leaves; frame 3 = orbiting
ring slowing back toward its normal idle speed; frame 4 = seams and core
glow fading back toward idle brightness; frame 5 = fully settled back to
idle glow intensity and normal ring orbit speed (a natural loop point
back toward the idle/glide pose). Each of the 5 poses must be fully
isolated with a clear solid-black (#000000) gap of at least one
character-width between it and its neighbors. All 5 poses must match the
reference art's exact in-canvas character scale and proportions.
Cracked-seam and core glow must be cool blue-white or amber-gold —
explicitly NOT purple, NOT cyan. Painterly pixel-art, hand-painted
miniature diorama style, fixed oblique isometric angle, dark grey/black
stone body, angular and constructed rather than organic.
```

---

## Why no "death" animation request in this batch

`design/gdd/monster.md`'s Visual/Audio Requirements table lists `"death"`
as Required for all 3 tiers, but this project's actual shipped
implementation (`MonsterDeathVFX`, Epic 16 Story 8, already reviewed and
live-verified) satisfies it via a **procedural particle burst + sprite
dissolve** of whatever sprite is currently displayed, not a dedicated
hand-animated death frame sequence — a deliberate, already-accepted
decision, not a gap. Don't request death frames from Codex; there's
nothing to wire them into.

## Next steps once generated

1. Drop each of the 4 files into `assets/source/monsters/` using the
   filenames given above.
2. Claude isolates each pose (should be straightforward given the
   explicit gap requirement above), alpha-cuts, verifies in-canvas scale
   matches the idle/walk reference before compositing (the lesson from
   the walk-cycle batch), and composites into the BOSS's existing atlas
   alongside its `idle`/`walk` clips.
3. Claude adds `"attack_prepare"` and `"attack"` clips to the matching
   `CreatureAtlasMappingResource` `.tres`, and wires the overlay-layer
   `AnimatedSprite2D` structure `design/gdd/monster.md`'s BOSS Scene
   Structure section specifies — this is real engine-code work
   (`BossCreaturePresenter3D` already has the two-layer plumbing per its
   own doc comment, currently driven by placeholder visibility-toggle
   logic since "no distinct animated art exists for any monster yet") —
   flag for a dedicated pass rather than assuming it's a drop-in wire.
4. Live-verify via Godot MCP if testing is in scope that pass, commit.

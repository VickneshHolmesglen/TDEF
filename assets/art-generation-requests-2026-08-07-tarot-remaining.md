# Tarot Card Art — Remaining Batch, 2026-08-07 (7 of 22 Major Arcana)

Standalone, upload-ready prompt batch for ChatGPT (or another image generator) —
meant to be handed over directly. Pulled together from
`assets/art-generation-requests-2026-08-03-tarot.md`'s own still-open items
into one clean batch, same convention as the materials-icon batch. Outcome
notes get folded back into `design/art/asset-generation-prompts.md` and the
original tarot batch file once each piece lands.

## Progress — 0/7 generated

Closes the full classic 22-card Major Arcana set: 15/22 are already
processed and wired (`assets/art/tarot/`). These 7 are the only ones left —
6 never generated, plus **The Lovers**, whose only prior attempt came back
as a full tarot-card mockup (baked-in numeral, title banner, decorative
frame) and needs the revised prompt below instead.

**Only 12 of the eventual 22 cards have a real `TarotCardResource` entry
today** — this batch is deliberately art-ahead-of-content (see the original
batch file's own "Scope note" section). Generating these 7 does not create
new tarot content or change deck behavior; it only fills out the reference
art set. Whether/how to expand the card pool to use the extra art is a
separate design decision for later.

## Critical constraint — read before generating anything

**Do not use purple anywhere**, even though real-world tarot art leans
heavily mystical-purple. The art bible reserves purple exclusively for
boss/elite-enemy escalation. Use the warm cabinet-diorama palette instead
(amber, parchment, gold) — a deliberate reinterpretation of tarot iconography
into this project's own palette, not a faithful-to-tradition color pass.

**Shared palette for all 7** (art bible Section 4.1/4.4):
- Sanctum Amber `#C8801A` — warm backbone, frames/borders/glow
- Parchment Cream `#F5EDCB` — light values, highlights
- Fieldstone Grey `#7E8590` — neutral stone/shadow where needed
- Herald Gold `#F5C01A` — achievement-tier accent, used generously on the
  climactic cards (Wheel of Fortune's brass, The Sun, Judgement, The World)
- Threat Crimson `#BE2020` — sparingly, only as a controlled accent on the
  darker-concept cards (The Devil, The Tower) — never a wash
- Do NOT use: purple (reserved, boss-only), green (reserved, heal-only — any
  foliage renders warm olive/amber-brown instead), cyan (reserved, UI-only)

**Shared composition notes for all 7:**
- Portrait-orientation illustrated scene (roughly 2:3 aspect), single
  centered subject/scene, flat pure black (`#000000`) background for easy
  cutout.
- **No text, no roman numeral, no card border/frame baked in** — illustration
  only, the screen renders frame and text separately. This needs to be its
  own explicit, repeated sentence in the prompt, and the background color
  must be named literally as `#000000` — "dark" alone wasn't enough; 3 of
  the first 10 cards generated for this project came back as full mockups
  despite a softer instruction. All 7 prompts below already use the
  stronger template. Retry once or twice if a card still comes back framed.
- Reinterpret each classic Major Arcana concept through this game's own
  fantasy-tower-defense/wizard's-cabinet lens, not literal Rider-Waite
  costuming.
- Family-friendly tone throughout — the darker concepts (The Devil, The
  Tower) render as symbolic/atmospheric, not graphic or frightening.

---

## 1. The Lovers (retry — revised prompt)

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout. Two figures standing
close together beneath a low stone archway, hands joined, facing each
other — a quiet, intimate moment of choice and connection, not overtly
romantic imagery. Warm amber (#C8801A) archway carving, parchment cream
(#F5EDCB) clothing highlights, muted fieldstone grey (#7E8590) stone. No
purple, no green, no cyan. Remember: no text, no numerals, no border, no
frame — illustration only.
```

## 2. Wheel of Fortune

```
Fantasy object illustration, NOT a tarot card, NOT a playing card, no card
of any kind — just an object illustration on a plain black background,
the way a game concept-art prop render would look. Absolutely no roman
numerals, no title text, no name banner, no decorative border or frame of
any kind anywhere in the image. Single object centered on a flat pure
black (#000000) background for easy cutout. A large ornate carved wooden
wheel, mounted and turning, with brass fittings and worn carved symbols
around its rim — fate and change in motion, no figure needed, the wheel
itself is the subject. Warm amber (#C8801A) wood tones, Herald Gold
(#F5C01A) brass fittings and accent, parchment cream (#F5EDCB) highlights
on the rim. No purple, no green, no cyan. Remember: no text, no numerals,
no border, no frame — illustration only.
```

## 3. The Devil

```
Fantasy object illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just an object illustration on a plain black
background, the way a game concept-art prop render would look. Absolutely
no roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single object centered on a flat
pure black (#000000) background for easy cutout. A carved stone
gargoyle-like statue on a low pedestal, chains draped loosely (not
binding anyone) around its base — temptation and self-imposed limits,
rendered as an inert carved object rather than a living threatening
figure (family-friendly tone, no overt horror). Warm amber (#C8801A) rim
light, threat crimson (#BE2020) used sparingly as a faint ember glow in
the stone's carved eyes only, muted fieldstone grey (#7E8590) dominant
stone tone. No purple, no green, no cyan. Remember: no text, no numerals,
no border, no frame — illustration only.
```

## 4. The Tower

```
Fantasy object illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just an object illustration on a plain black
background, the way a game concept-art environment render would look.
Absolutely no roman numerals, no title text, no name banner, no
decorative border or frame of any kind anywhere in the image. Single
scene centered on a flat pure black (#000000) background for easy cutout.
A tall stone watchtower struck by a bolt of energy at its peak, cracking
and shedding loose stone/rubble mid-collapse but rendered as a dramatic
dynamic moment rather than a horror scene — this game is itself a
tower-defense game, so lean into a strong visual echo of the in-game
towers being struck, sudden upheaval and change. Warm amber (#C8801A)
light/energy at the strike point, threat crimson (#BE2020) used as a
controlled danger accent on falling embers/debris only, muted fieldstone
grey (#7E8590) dominant stone tone, parchment cream (#F5EDCB) highlights
on the energy bolt. No purple, no green, no cyan. Remember: no text, no
numerals, no border, no frame — illustration only.
```

## 5. The Sun

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout. A joyful child-like
figure standing in an open field with arms raised toward a large radiant
sun, simple and warm — this game's single most triumphant, golden-hour-
toned card in the batch. Warm amber (#C8801A) dominant, Herald Gold
(#F5C01A) used generously as the sun's core color and rays, parchment
cream (#F5EDCB) highlights throughout. No purple, no green (any
grass/field renders warm amber-gold, not naturalistic green), no cyan.
Remember: no text, no numerals, no border, no frame — illustration only.
```

## 6. Judgement

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout. A robed figure standing
with arms raised toward the sky as a great horn/trumpet sounds above
(rendered as the instrument itself, radiant, rather than a literal
angelic figure blowing it) — a moment of reckoning and renewal,
triumphant rather than somber. Warm amber (#C8801A) rim light, Herald
Gold (#F5C01A) generously on the horn and radiant light, parchment cream
(#F5EDCB) robe highlights. No purple, no green, no cyan. Remember: no
text, no numerals, no border, no frame — illustration only.
```

## 7. The World

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout. A dancing figure
suspended mid-motion inside a large wreath/laurel ring woven from wheat
and vine, arms and one leg extended gracefully — completion and
wholeness, the deck's final, most harmonious card. Warm amber (#C8801A)
wreath tones, Herald Gold (#F5C01A) generous accent throughout (this is
the deck's capstone card), parchment cream (#F5EDCB) highlights on the
dancer's clothing. Any foliage in the wreath renders warm amber-gold-
brown, not naturalistic green. No purple, no cyan. Remember: no text, no
numerals, no border, no frame — illustration only.
```

---

## Next steps once generated

1. Drop the resulting image(s) into `assets/source/tarot/` (create the
   folder if it doesn't exist — it likely already exists from the first 15).
   One file per card or a single sheet — either works. Name files after the
   card (e.g. `the_lovers.png`, `wheel_of_fortune.png`, ...) if generating
   one at a time, to keep the mapping unambiguous.
2. Claude alpha-cuts each (flood-fill technique, per `design/art/
   asset-generation-prompts.md`'s documented method), spot-checks against a
   bright backdrop before trusting the cut, and archives the processed
   result to `assets/art/tarot/`.
3. If any card still comes back as a full mockup (baked-in numeral/border),
   flag it — do not attempt to alpha-cut around a baked-in frame. Retry with
   the same prompt (generation is non-deterministic) before escalating.
4. These 7 complete the reference art set at 22/22, but do **not**
   automatically become playable cards — wiring any of them to a real
   `TarotCardResource` is a separate content decision, matching the "art
   ahead of content" scope note above. Confirm with the user before wiring
   any into `tarot_screen.gd`'s `CARD_TEXTURES` map.
5. Live-verify via Godot MCP, run the existing tarot test suite, full
   regression, commit.

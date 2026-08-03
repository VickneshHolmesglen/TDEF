# Tarot Card Art — Generation Batch, 2026-08-03 (22 Major Arcana)

## Progress — 15/22 processed, 0 need regeneration, 7 not yet generated

**Done, sliced, and wired** (`assets/art/tarot/`): The Fool, The
Magician, The High Priestess, The Empress, The Emperor, The Hierophant,
The Chariot (round 1, old template), and Death, Justice, Temperance, The
Hanged Man, The Hermit, The Moon, The Star, Strength (round 2, revised
anti-frame template — all 8 came back clean on the first try, confirming
the template fix). All alpha-cut clean (flood-fill technique, thresholds
8-15 depending on the image), verified against a magenta backdrop before
finalizing, sources archived to `assets/source/tarot/`.

**Wiring status**: 10 of 12 real `TarotCardResource` cards now have art
(see `CARD_TEXTURES`'s own doc comment in `tarot_screen.gd` for the full
mapping and reasoning). Round 2 added 3 strong fits: Death ->
`grim_resolve` (transformation/ending <-> the deck's highest-difficulty
card), Strength -> `apex_predator` (the lion <-> the deck's own "majestic
apex predator" Legendary), Temperance -> `steady_hand` (patience/
moderation <-> the mildest/calmest card). Justice, The Hanged Man, The
Hermit, and The Moon landed clean but have **no good mechanical fit**
among the 2 still-unmapped cards (`reckless_onslaught`, `swift_current` —
both need aggressive-motion/speed imagery none of these 4 depict) — left
as extra art ahead of content rather than forced into a bad fit.

**The Lovers** is the only card from the original 3-reject list not yet
regenerated (Strength and The Hermit both came back clean on retry using
the revised prompt in section VIII/IX below — the same revised prompt is
still there for The Lovers in section VI, just not run yet).

**Not yet generated** (still just prompts, no image dropped in): Wheel of
Fortune, The Devil, The Tower, The Sun, Judgement, The World, plus The
Lovers' retry above.

---

Standalone, upload-ready prompt batch for ChatGPT (or another image generator) —
meant to be handed over directly. Outcome notes get folded back into
`design/art/asset-generation-prompts.md` once each piece lands, matching the
project's established convention.

## Scope note — art ahead of content, on purpose

Only 12 `TarotCardResource` entries are authored today
(`assets/data/tarot/*.tres`), but the classic tarot deck this system is
named after has 22 Major Arcana. This batch generates art for the full
classic 22, not just the current 12 — the same "generate the full
reference set, wire what's authored, flag the rest as a content-ahead-of-art
gap closed early" approach already used for Habitat Expansion's 4th tier.
**This is a scope decision, not a silent content addition**: generating 10
extra pieces of art does not create 10 new `TarotCardResource` entries —
whether/how to expand the card pool to use them is a separate design call
for later, not something Claude will invent unprompted when wiring this
batch in.

## Critical constraint — read before generating anything

**Do not use purple anywhere**, even though real-world tarot art leans
heavily mystical-purple. The art bible reserves purple exclusively for
boss/elite-enemy escalation (`Section 4.2`, "Purple = elite enemy status
and boss escalation only... must never be used for UI chrome, decorative
elements, or generic 'magic'... its power comes from its scarcity"). Use
the warm cabinet-diorama palette instead (amber, parchment, gold), matching
the "wizard's cabinet" register every other Sanctuary-adjacent asset uses —
this is a deliberate reinterpretation of tarot iconography into this
project's own palette, not a faithful-to-tradition color pass.

**Shared palette for all 22** (art bible Section 4.1/4.4):
- Sanctum Amber `#C8801A` — warm backbone, frames/borders/glow
- Parchment Cream `#F5EDCB` — light values, card-stock highlights
- Fieldstone Grey `#7E8590` — neutral stone/shadow where needed
- Herald Gold `#F5C01A` — achievement-tier accent, use generously on the higher-numbered/climactic cards (Sun, World, Star)
- Threat Crimson `#BE2020` — sparingly, only as a controlled accent on the darker-concept cards (Death, The Tower, The Devil) — never a wash
- Do NOT use: purple (reserved, boss-only), green (reserved, heal-only — any foliage renders warm olive/amber-brown instead), cyan (reserved, UI-only)

**Shared composition notes for all 22:**
- Portrait-orientation illustrated scene (roughly 2:3 aspect), single
  centered subject/scene, plain dark background for easy cutout (matching
  every other asset generated this project).
- No text, no roman numeral, no card border/frame baked in — illustration
  only, the screen renders frame and text separately (per `tarot.md`'s
  Visual Requirements, frame/text is the UI's job, not the art's). **This
  instruction alone wasn't enough** — 3 of the first 10 generated (Lovers,
  Strength, Hermit) came back as full tarot-card mockups with the frame/
  numeral/title baked in anyway. Every prompt from Wheel of Fortune onward
  (X-XXI) and the 3 retries (VI/VIII/IX) now use a stronger template:
  avoid the word "tarot-card" entirely, state the anti-frame rule as its
  own repeated sentence, and name the background color literally
  (`#000000`). Not a guaranteed fix (generation is non-deterministic, and
  all 7 successes used the old wording too) — just the best available
  lever, so retry once or twice if a card still comes back framed.
- Reinterpret each classic Major Arcana concept through this game's own
  fantasy-tower-defense/wizard's-cabinet lens, not literal Rider-Waite
  costuming — keep it consistent with the Sanctuary's warm, carved-wood-
  and-lantern-light aesthetic rather than a generic mystical tarot look.
- Tone: this is a family-friendly fantasy game. Darker concepts (Death, The
  Devil, The Hanged Man) render as symbolic/atmospheric, not graphic or
  horrific — mirrors how "Grim Resolve"'s original 12-card batch handled
  its own darkest entry.

---

## 0. The Fool

```
Portrait tarot-card illustration, single subject centered on a plain dark
background for easy cutout. A young traveler in simple traveling clothes,
mid-step off a low cliff edge, looking upward rather than down — carefree,
unaware or unafraid of the drop, a small pack and walking staff over one
shoulder. Warm amber (#C8801A) sunrise-toned rim light, parchment cream
(#F5EDCB) highlights on the traveler's clothes, muted fieldstone grey
(#7E8590) cliff stone. No purple, no green, no cyan.
```

## I. The Magician

```
Portrait tarot-card illustration, single subject centered on a plain dark
background for easy cutout. A robed figure at a carved wooden table,
one hand raised, the other pointing down, with a lit candle, an open
book, and a small carved wand/rod arranged on the table before them —
mastery and deliberate will, not flashy spellcasting. Warm amber
(#C8801A) candlelight, parchment cream (#F5EDCB) book pages, muted
fieldstone grey (#7E8590) table and shadow, Herald Gold (#F5C01A) as a
subtle accent on the candle flame only. No purple, no green, no cyan.
```

## II. The High Priestess

```
Portrait tarot-card illustration, single subject centered on a plain dark
background for easy cutout. A seated robed figure between two tall carved
wooden pillars, holding a closed book against her chest, calm and
watchful — quiet knowledge held in reserve, not revealed. Warm amber
(#C8801A) pillar carving detail, parchment cream (#F5EDCB) robe
highlights, muted fieldstone grey (#7E8590) stone floor and shadow. No
purple, no green, no cyan.
```

## III. The Empress

```
Portrait tarot-card illustration, single subject centered on a plain dark
background for easy cutout. A crowned figure seated on a carved wooden
throne surrounded by abundant wheat sheaves and ripe fruit, relaxed and
generous posture — fertility and abundance. Warm amber (#C8801A) throne
wood, Herald Gold (#F5C01A) crown accent, parchment cream (#F5EDCB) wheat
highlights. Any foliage/fruit renders warm olive/amber-brown, not
naturalistic green. No purple, no cyan.
```

## IV. The Emperor

```
Portrait tarot-card illustration, single subject centered on a plain dark
background for easy cutout. An armored, crowned figure seated on a stone
throne carved with a ram's-head motif, one hand gripping a plain iron
scepter planted upright — authority and unshakable order. Warm amber
(#C8801A) armor rim light, Herald Gold (#F5C01A) crown accent, muted
fieldstone grey (#7E8590) stone throne. No purple, no green, no cyan.
```

## V. The Hierophant

```
Portrait tarot-card illustration, single subject centered on a plain dark
background for easy cutout. A robed elder figure seated between two
carved stone pillars, one hand raised in a blessing gesture, a tall
ceremonial staff resting against one shoulder — tradition and shared
teaching. Warm amber (#C8801A) robe trim, parchment cream (#F5EDCB)
highlights, muted fieldstone grey (#7E8590) pillar stone. No purple, no
green, no cyan.
```

## VI. The Lovers

**Retry 2026-08-04** — original came back as a full tarot-card mockup
(baked-in "VI" numeral, "THE LOVERS" title banner, decorative parchment
frame around the whole image) despite the "no text, no border" instruction.
Revised below: dropped the phrase "tarot-card" entirely (likely biasing
the generator toward its training-data idea of an actual bordered card)
and made the anti-frame instruction its own explicit, repeated sentence.

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

## VII. The Chariot

```
Portrait tarot-card illustration, single subject centered on a plain dark
background for easy cutout. An armored figure standing tall in a
simple two-wheeled wooden war chariot, reins held firm, mid-motion —
controlled forward momentum and willpower, not chaotic speed (contrast
with the "Reckless Onslaught"/"Swift Current" cards' more frantic energy).
Warm amber (#C8801A) chariot wood and metal, parchment cream (#F5EDCB)
highlights, muted fieldstone grey (#7E8590) shadow. No purple, no green,
no cyan.
```

## VIII. Strength

**Retry 2026-08-04** — original was the worst of the 3 rejects: full
tarot-card mockup (numeral, title banner, decorative border) AND a solid
grey card background instead of black, breaking the cutout technique
entirely. Same fix as The Lovers: dropped "tarot-card," made the
anti-frame instruction explicit and repeated, and named the required
background color literally instead of trusting "dark" to be interpreted
as black.

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout — not grey, not brown,
literally black. A calm robed figure gently but firmly closing a great
lion's jaw with both hands, the lion relaxed rather than fighting — quiet
inner strength and control over raw power, not physical combat. Warm
amber (#C8801A) lion's mane rim light, parchment cream (#F5EDCB) robe
highlights, muted fieldstone grey (#7E8590) used only on the figure/lion
themselves, never as the background fill. No purple, no green, no cyan.
Remember: no text, no numerals, no border, no frame, background must be
flat pure black — illustration only.
```

## IX. The Hermit

**Retry 2026-08-04** — had 2 problems, not just 1: same full-tarot-card-
mockup issue as the other 2 rejects, AND a second, separate issue even
after a crop-salvage attempt — the original's deliberate near-black
chiaroscuro (lantern as the *only* light source) meant the robe's own
shadow folds sat at almost the same color as the black background,
making them impossible to alpha-cut cleanly (the cutout tool erased large
chunks of the robe along with the real background, since it can't tell
the difference by color alone). Fixed below by keeping the lantern as the
*dominant* light but adding an explicit secondary rim light so the
figure's outline stays separable from the backdrop at every point around
its silhouette — same fix in spirit as the "always leave a bright rim
edge" note in `design/art/asset-generation-prompts.md`'s own established
lessons for dark-material assets (Shadow tower, Rift Sentinel, Bog
Lurker).

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout. A single hooded, cloaked
figure standing on a rocky outcrop, holding up a lit lantern into the
darkness ahead, alone but purposeful — introspection and guiding light.
The lantern is the dominant, warmest light source, but add a second,
subtle cool rim light tracing the full outer edge of the figure's cloak
and hood silhouette (dim, but never fully black) so the entire figure
reads as clearly separated from the black background at every point
around its outline, not just on the lantern-lit side. Warm amber
(#C8801A) lantern glow, parchment cream (#F5EDCB) cloak highlight where
the lantern catches it, muted fieldstone grey (#7E8590) rock and the
figure's own rim-lit shadow areas (never pure black on the figure
itself). No purple, no green, no cyan. Remember: no text, no numerals, no
border, no frame, and the whole figure outline must stay visibly distinct
from the black background, not blending into it anywhere.
```

**All 12 below use the revised anti-frame template** (2026-08-04, applied
pre-emptively — see the Lovers/Strength/Hermit retry entries above for why):
dropped "tarot-card" phrasing, explicit repeated no-frame/no-text
instruction, literal `#000000` background call-out.

## X. Wheel of Fortune

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

## XI. Justice

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout. A robed figure holding a
raised sword in one hand and a balanced set of scales in the other,
standing perfectly upright and still — fairness and clear-eyed judgment.
Warm amber (#C8801A) sword and scale metal, parchment cream (#F5EDCB)
robe highlights, muted fieldstone grey (#7E8590) used only on the figure
itself. No purple, no green, no cyan. Remember: no text, no numerals, no
border, no frame — illustration only.
```

## XII. The Hanged Man

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout. A figure hanging calmly
upside-down by one ankle from a sturdy wooden beam, arms loosely crossed,
expression serene rather than distressed — voluntary pause and a new
perspective, rendered peacefully, not as punishment or peril. Warm amber
(#C8801A) beam wood, parchment cream (#F5EDCB) clothing highlights, muted
fieldstone grey (#7E8590) used only on the figure/beam themselves. No
purple, no green, no cyan. Remember: no text, no numerals, no border, no
frame — illustration only.
```

## XIII. Death

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout. A hooded skeletal figure
in a simple worn traveling cloak, carrying a single dried wilted flower
rather than a scythe — transformation and a natural ending, rendered
symbolic and calm, not gory or frightening (family-friendly tone). Add a
subtle warm rim light tracing the full outline of the cloak so the figure
stays clearly separated from the black background at every edge, not just
one lit side. Warm amber (#C8801A) rim light on the bone and cloak edge,
threat crimson (#BE2020) used only as a faint ember accent in the
background, not on the figure itself, parchment cream (#F5EDCB)
highlights, fieldstone grey (#7E8590) cloak shadow (never pure black on
the figure itself). No purple, no green, no cyan. Remember: no text, no
numerals, no border, no frame — illustration only.
```

## XIV. Temperance

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout. A calm robed figure
carefully pouring liquid between two ornate cups held at chest height,
perfectly balanced posture — patience and careful moderation. Warm amber
(#C8801A) liquid glow, parchment cream (#F5EDCB) robe and cup highlights,
muted fieldstone grey (#7E8590) used only on the figure itself. No
purple, no green, no cyan. Remember: no text, no numerals, no border, no
frame — illustration only.
```

## XV. The Devil

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

## XVI. The Tower

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

## XVII. The Star

```
Fantasy character illustration, NOT a tarot card, NOT a playing card, no
card of any kind — just a character illustration on a plain black
background, the way a game concept-art portrait would look. Absolutely no
roman numerals, no title text, no name banner, no decorative border or
frame of any kind anywhere in the image. Single scene centered on a flat
pure black (#000000) background for easy cutout. A kneeling figure at the
edge of a still pool, pouring water from two vessels, one into the pool
and one onto the ground, beneath a sky with one large bright star
overhead — hope and quiet renewal. Warm amber (#C8801A) star glow, Herald
Gold (#F5C01A) as the star's dominant color (this is a climactic/hopeful
card), parchment cream (#F5EDCB) highlights on the figure and water. No
purple, no green, no cyan. Remember: no text, no numerals, no border, no
frame — illustration only.
```

## XVIII. The Moon

```
Fantasy scene illustration, NOT a tarot card, NOT a playing card, no card
of any kind — just an environment illustration on a plain black
background, the way a game concept-art environment render would look.
Absolutely no roman numerals, no title text, no name banner, no
decorative border or frame of any kind anywhere in the image. Single
scene centered on a flat pure black (#000000) background for easy cutout.
A winding stone path leading between two watchtower-like spires toward a
large glowing moon on the horizon, mist pooling low along the path —
uncertainty and imagination, an eerie but not frightening night scene.
Warm amber (#C8801A) used for the path's warm-lit torches lining the way
(avoid rendering the whole scene in cold blue-grey moonlight — keep the
palette anchored warm per the Sanctuary's never-cool-toned rule),
parchment cream (#F5EDCB) moon highlight, muted fieldstone grey (#7E8590)
spires and mist. No purple, no green, no cyan. Remember: no text, no
numerals, no border, no frame — illustration only.
```

## XIX. The Sun

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

## XX. Judgement

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

## XXI. The World

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
   folder if it doesn't exist), one file per card or a single sheet — either
   works, Claude will slice/process either way. Name files after the
   card concept (e.g. `the_fool.png`, `the_magician.png`, ...) if generating
   one at a time, to keep the mapping unambiguous.
2. Claude alpha-cuts each card (flood-fill technique, per
   `design/art/asset-generation-prompts.md`'s documented method), spot-checks
   against a bright backdrop before trusting the cut, and archives the
   processed result to `assets/art/tarot/`.
3. **Wiring decision needed before step 3 can complete**: only 12 of these
   22 have a matching `TarotCardResource` today. Claude will surface a
   best-fit mapping proposal (or flag where none fits) rather than silently
   assigning art to game cards or inventing new `TarotCardResource` entries
   to use the leftover 10 — that's a real content-scope decision, not an
   art-wiring one.
4. Live-verify via Godot MCP, run/extend the tarot-screen test suite, full
   regression, commit.

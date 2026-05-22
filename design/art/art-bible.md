# Sanctuary Defenders — Art Bible

> **Status**: Sections 1–6 Complete (Visual Identity Core + Production Guides)
> **Author**: Vicknesh + Art Director
> **Last Updated**: 2026-05-19
> **AD-ART-BIBLE Sign-Off**: Skipped — Lean mode (director gate deferred to Full review)

---

## Section Status

| Section | Status |
|---------|--------|
| 1. Visual Identity Statement | Complete |
| 2. Mood & Atmosphere | Complete |
| 3. Shape Language | Complete |
| 4. Color System | Complete |
| 5. Character Design Direction | Complete |
| 6. Environment Design Language | Complete |
| 7. UI/HUD Visual Direction | Placeholder |
| 8. Asset Standards | Placeholder |
| 9. Reference Direction | Placeholder |

---

## Section 1: Visual Identity Statement

### One-Line Visual Rule

> **If it could sit inside a wizard's cabinet as a hand-carved diorama, it belongs in this game. If it looks like a flat tilemap or a web browser game, it is wrong.**

---

### Supporting Visual Principles

#### Principle 1 — Everything Has Weight and Depth
*Pillar: The Living Sanctuary*

No object in this game exists as a flat decal on a surface. Every sprite —
whether a tower, a monster, a tree, or a wall tile — must read as a physical
object occupying space. Depth is achieved through stacked sprite layers with
cast shadow sprites between them, not through outline tricks or shading alone.
The viewer's eye must believe that objects sit *on* the ground plane, not *in
front of* it.

**Design test:** When an environment prop feels flat or ambiguous, choose stacked
layering with a shadow sprite beneath it over a single sprite with a drop-shadow
effect. If removing the shadow sprite makes the object look pasted onto the
ground, the layering is insufficient — add an intermediate layer.

---

#### Principle 2 — Scale Reads as Precious, Not Epic
*Pillar: Combinatorial Discovery*

This is a miniature world viewed from a slightly elevated oblique angle. The
correct aesthetic register is "hand-crafted cabinet diorama," not "heroic
fantasy panorama." Objects should feel small and knowable — the kind of world
a player wants to examine closely, not one that overwhelms. Rich surface detail
(wood grain, stone weathering, fabric texture) reinforces the sense that someone
*made* these objects by hand. Camera angles and field-of-view choices must always
reinforce miniature scale, never undermine it.

**Design test:** When choosing between a wide sweeping camera angle and a tighter
oblique angle, choose the tighter oblique angle. If an asset looks impressive from
a cinematic low angle but loses character at the standard play angle, it is wrong
— design for the play angle first and only the play angle.

---

#### Principle 3 — Color Carries Information Before It Carries Mood
*Pillar: Strategic Mastery*

Every color decision in this game is a communication decision first. The player
must be able to read the battlefield at a glance: which towers are active, which
enemies are dangerous, where the hero is, what resource state the player is in.
Color may also serve mood, but only after its informational role is fully
discharged. Purely decorative color choices that add visual noise without
communicating game state are rejected regardless of aesthetic quality.

**Design test:** When choosing between two color options for a VFX or UI element,
choose the option that is unambiguous in context over the option that is more
visually interesting in isolation. Test every color decision in a populated scene,
not on a white canvas.

---

### Note on the Hybrid Rendering Technique

Sanctuary Defenders uses a deliberate split: the hero is a real-time 3D model
composited into a scene built entirely from layered 2D sprites. This is not a
technical compromise — it is the correct expression of the game's identity. The
hero is the one thing in the world that is *not* a miniature. The hero is the
player's singular point of presence in an otherwise crafted, arranged world. A
3D model carries weight, casts light realistically, and reads differently from
every other object on screen; that difference is intentional. It communicates at
a glance that this is the entity the player *inhabits*, not the entities the
player *commands*.

The diorama metaphor holds: in a cabinet diorama, there is often one hand-painted
centrepiece figure surrounded by crafted scenery — the centrepiece reads as real
because everything around it reads as constructed. The hero functions as that
centrepiece. Every rendering choice in the 2D world (warm painterly textures,
depth-of-field softening at the edges, cast shadows between sprite layers) is
calibrated to make the diorama feel real enough that the 3D hero belongs inside
it rather than floating above it.

---

## Section 2: Mood & Atmosphere

> This section briefs the lighting artist and atmosphere lead. Every descriptor
> is prescriptive, not aspirational. Adjectives must be testable: if you cannot
> answer "does this screenshot have this quality?", the adjective is too vague.

### 2.1 State Hierarchy Overview

The six game states form an emotional arc from warmth to urgency and back. The
arc is deliberate: the player always knows where they are emotionally, and the
game always returns them to comfort.

```
SANCTUARY       — warmest, most grounded
SCOUT           — cool and focused; the calm before
WAVE_ACTIVE     — highest energy; warmth replaced by contrast
INTERMISSION    — rapid decompression; warmth reintroduces itself
MISSION_COMPLETE— exhale; warm and triumphant
DEFEAT          — quiet; warm embers, not cold dark
```

Each state must be identifiable from a thumbnail at 200×150 px. If two states
look identical at thumbnail scale, the lighting is wrong.

---

### 2.2 State Profiles

#### STATE 1 — SANCTUARY

**Primary emotional target:**
The player feels the satisfaction of a craftsperson returning to their workshop
— everything here is theirs, every object has a story, and the space rewards
looking closely.

**Lighting character:**
- Time-of-day: late afternoon interior — soft raking light from one high window
  or lantern source at 45°; no harsh overhead
- Color temperature: warm (2700–3200 K; amber-gold dominant)
- Contrast: low — no hard shadow edges; fill light present everywhere so the
  player can read every surface

**Atmospheric descriptors:** Amber-lit · Dust-moted · Cluttered-but-curated · Hushed · Tactile

**Energy level:** Contemplative

**Mood-bearing visual element:** The forge or workbench point-light — a single
warm point-light that casts soft long shadows from displayed trophies and crafted
objects, making them read as three-dimensional objects with history.

---

#### STATE 2 — SCOUT

**Primary emotional target:**
The player feels the focused clarity of a general surveying a battlefield before
the first move — present, unhurried, in full command of the space.

**Lighting character:**
- Time-of-day: dawn or dusk overcast — diffuse directional light, no strong
  shadows; soft blue-grey sky fill
- Color temperature: cool-neutral (5500–6500 K; pale blue-white)
- Contrast: medium — enough to read the grid and placement zones clearly,
  but no drama

**Atmospheric descriptors:** Still · Overcast-clear · Expectant · Surveyed · Precise

**Energy level:** Measured

**Mood-bearing visual element:** The placement grid's faint ground-plane glow
— a soft cool reticle marking valid cells with pale blue-white luminance that
reads as "the board is set out and waiting."

**Distinguishing difference from SANCTUARY:** SANCTUARY is amber and interior;
SCOUT is blue-white and exterior. Both are calm, but SANCTUARY feels enclosed
and personal while SCOUT feels open and tactical.

---

#### STATE 3 — WAVE_ACTIVE

**Primary emotional target:**
The player feels the controlled intensity of a commander who has prepared well
— urgent, but never panicked; the chaos around them is legible because they
understand its rules.

**Lighting character:**
- Time-of-day: full combat — primary source shifts to high slightly-warm
  overhead (imitating torchlight at a battle standard); secondary cool ambient
  fill prevents shadow crush
- Color temperature: split-lit (warm key 3000–3500 K / cool fill 6000–6500 K);
  the split creates depth without flatness
- Contrast: high — information-bearing elements (projectiles, hit flashes,
  damage numbers) must sit clearly above the environment read

**Atmospheric descriptors:** High-contrast · Charged · Kinetic-but-composed · Lantern-lit · Taut

**Energy level:** Urgent

**Mood-bearing visual element:** Monster approach shadows — each advancing enemy
casts a small sharp contact shadow on the ground plane beneath it. At distance,
these shadows read as a tide; up close, they individuate. This is the primary
depth cue that keeps the scene feeling like a diorama even at full combat pace.

**Addressing the readability-vs-diorama tension:**
The diorama atmosphere is maintained through lighting geometry (warm key / cool
fill split, contact shadows, no flat top-down illumination) while readability is
maintained through contrast discipline. Every VFX element that communicates
information (projectile trajectory, hit confirmation, status effect) must be
drawn in a color and contrast level that reads clearly against the scene's
warm-key ground plane. Effects that do not carry information (ambient smoke,
idle tower glow) must stay below 30% opacity to remain atmospheric rather than
signal-noise. The scene looks like a diorama of a battle in progress, not a
battle that has forgotten it is a diorama.

---

#### STATE 4 — INTERMISSION

**Primary emotional target:**
The player feels the brief relief of a held breath released — the immediate
danger has passed, there is work to do, but the worst of it is over for now.

**Lighting character:**
- Time-of-day: the warm key light returns, dimmer and slightly redder than
  SANCTUARY — as if the lanterns have been burning longer
- Color temperature: transitional warm (3200–3800 K); perceptibly warmer than
  WAVE_ACTIVE, not yet as comfortable as SANCTUARY
- Contrast: medium-low — contrast steps down from WAVE_ACTIVE noticeably;
  the scene breathes out

**Atmospheric descriptors:** Simmering · Smoke-tinged · Briefly-settled · Warm-but-watchful · Purposeful

**Energy level:** Measured-urgent (higher than SCOUT; lower than WAVE_ACTIVE)

**Mood-bearing visual element:** Lingering smoke wisps on damaged towers — thin,
slow-rising particle sprites on any tower that took damage this wave. They do not
obscure the tower but signal that the fight was real and the respite is temporary.

**Distinguishing difference from SCOUT:** SCOUT is pristine — no enemies have
touched the field yet. INTERMISSION shows the aftermath: residual smoke wisps,
scattered debris sprites at spawn edges, the ground-plane slightly warmer and
more textured from the wave that passed. Same calm energy level as SCOUT, but
earned and temporary rather than anticipatory.

---

#### STATE 5 — MISSION_COMPLETE

**Primary emotional target:**
The player feels the specific satisfaction of having seen a plan through to
completion — not relief, but vindication; the outcome was not a surprise,
it was earned.

**Lighting character:**
- Time-of-day: golden hour — warm directional light at a low angle, long
  shadows behind the hero and surviving towers
- Color temperature: deeply warm (2500–2800 K); the warmest exterior lighting
  in the game
- Contrast: medium — enough to sculpt the hero and surviving towers as
  triumphant silhouettes, but no harsh edges

**Atmospheric descriptors:** Golden-hour-saturated · Long-shadowed · Settled-dust · Still-triumphant · Breathing-out

**Energy level:** Contemplative

**Mood-bearing visual element:** The hero figure's rim light shifts from its
standard off-white combat tone to full warm-gold at this state only — the
character reads as literally gilded by success. Implement as a dedicated
state-triggered shader parameter, not a post-process effect, so it does not
bleed into surrounding sprites.

**Distinguishing difference from SANCTUARY:** Both are warm and contemplative.
MISSION_COMPLETE is exterior golden hour with low-angle long shadows; SANCTUARY
is interior amber lantern with raking 45° interior shadows. Same emotional
family, immediately distinguishable.

---

#### STATE 6 — DEFEAT

**Primary emotional target:**
The player feels the quiet of a setback that has not ended the story — like a
chess player tipping their king: acknowledgment, not despair; the pieces are
still on the board.

**Lighting character:**
- Time-of-day: scene desaturates partially (60–70% saturation retained, not
  full grayscale); directional light dims to its lowest level; ambient fill
  remains so no area goes fully dark
- Color temperature: cool-neutral shift toward 4500–5000 K; the warmth recedes
  but does not disappear entirely
- Contrast: low — everything softens; no hard edges; the scene retreats

**Atmospheric descriptors:** Dimmed · Ash-muted · Quiet · Unresolved-but-held · Embers-remaining

**Energy level:** Contemplative

**Mood-bearing visual element:** The Sanctuary background element — whatever
persistent home-base visual is visible in the scene (a tower silhouette, a
banner, an architectural fragment) remains at **full saturation** while the
battlefield desaturates around it. This single warm-colored anchor communicates
that the Sanctuary is intact and progress is preserved, without a single word of
UI text. Must be implemented at the scene composition level, not as a
post-process exclusion.

**Tone note for implementation:** DEFEAT desaturation must move toward muted
**warm-grey**, not blue-grey. The difference is approximately 10–15° of hue
rotation toward warmth on the saturation curve. Cold-grey reads as clinical
failure; warm-grey reads as a quiet pause.

---

### 2.3 Cross-State Lighting Rules

These rules apply across all six states and must not be violated:

1. **No state may use full-screen desaturation to grayscale** — reserved for
   hero death VFX only.
2. **Contact shadows are always present** regardless of state — the primary
   cue that objects sit on the ground plane. Removing them breaks Principle 1.
3. **The hero's rim highlight is always visible** — may shift color temperature
   by state (off-white in combat, warm-gold in MISSION_COMPLETE), but never
   disappears.
4. **Information-bearing VFX colors (damage red, heal green, crit yellow)** do
   not shift between states. They are fixed-language signals.
5. **WAVE_ACTIVE is the only state** where VFX opacity above 30% is permitted
   for non-information atmospheric effects.

---

## Section 3: Shape Language

> **Pillar anchor:** P1 (Everything Has Weight and Depth) governs environment
> geometry. P2 (Scale Reads as Precious, Not Epic) governs silhouette proportion.
> P3 (Color Carries Information Before It Carries Mood) is the backstop test
> whenever shape alone is ambiguous.

---

### 3.1 Character Silhouette Philosophy

#### 3.1.1 The Hero

The Hero is the only 3D model on the field. That distinction must be *felt*
before it is consciously noticed.

**The Hero Silhouette Rule:**
The Hero reads as a vertical axis. In a world of flat-topped, horizontally-oriented
structures and squat sprite stacks, the Hero's silhouette is the tallest narrow
shape at any zoom level. No other entity in the scene may share this proportion:
tall-and-narrow is reserved exclusively for the Hero.

- **Aspect ratio:** Target 1.8:1 (height:width) at default zoom, measured at idle stance.
- **Floor:** No idle animation frame may collapse below 1.4:1. Combat crouches
  permitted only in active-attack frames, not idle loops.
- **Apex:** The silhouette crown (helmet/head) must be a clean point or rounded
  dome — never flat. The Hero's crown is always the highest pixel in any entity cluster.
- **Ground contact:** Feet are wide-planted relative to torso. P1 demands objects
  sit *on* the ground plane; the Hero's stance must communicate weight at the
  contact point.

**Design test:** Flatten the scene to pure silhouettes. If the Hero cannot be
found within two seconds, the Hero's proportions are wrong. Fix by vertical
elongation — never by adding glow or color changes (those belong to Section 4).

**Hybrid rendering note:** The 3D model's natural rim lighting and cast shadow
assist readability but are additive. The silhouette must pass the flat-silhouette
test first.

---

#### 3.1.2 Monsters — Silhouette Vocabulary by Tier

Monster silhouettes communicate threat tier through *volume and mass*, not
complexity. Grammar is deliberately simple so it reads at game speed:

| Tier | Shape Grammar | Proportions | Negative Space |
|------|---------------|-------------|----------------|
| **Standard** | Compact, low-to-ground, simple outline | Wider than tall (below 1:1) | Clean open areas — readable outline |
| **Elite** | Mid-height, asymmetric accent shape | Approaching 1:1 | Broken silhouette: one protrusion (horn, blade, shoulder mass) |
| **Boss** | Tall or wide beyond grid-cell scale | Above 1.5:1 or wider than 1.5 standard cells | Complex but readable — one dominant mass + secondary accent |

**The three rules:**

1. **Standard monsters are shorter than they are wide.** No Standard monster
   silhouette may include a protrusion above the horizontal midline of its
   bounding box. They feel like swarm pressure, not individual menace.

2. **Elite monsters break their own bounding box.** One protrusion — asymmetric —
   must cross the silhouette border. Symmetry reads as Standard; asymmetry reads
   as Elite.

3. **Boss monsters violate the grid.** A Boss silhouette must read as "too large
   to be a normal enemy" without any other context, occupying multiple cells
   visually even if collision is one cell.

**Design test:** Paste three silhouettes side by side — one per tier. A playtester
who has never seen the game must correctly rank them by threat within five seconds.
If they cannot, the fix is always mass difference, never detail difference.

**Shape family:** All monster tiers draw from organic, irregular shapes — no
perfect circles, no hard right angles. Monsters feel *grown*, not built. This
distinguishes them from towers (constructed) and the Hero (deliberately crafted).

---

#### 3.1.3 Towers — Silhouette Vocabulary by Archetype

Towers are built objects. Their silhouettes must answer "What do I do?" before
the player reads a label. Shape grammar maps function to form using architectural
metaphor:

| Archetype | Function | Silhouette Grammar | Key Geometric Signature |
|-----------|----------|--------------------|------------------------|
| **Defensive / Wall** | Blocks or redirects paths | Horizontal and wide — a mass, not a spike | Flat or crenellated top; broad base occupying full cell width |
| **Damage Dealer** | Projectile or AoE attack | Vertical emphasis — points upward | Barrel, spire, or elevated firing platform; clear directional intent |
| **Support / Buff** | Enhances adjacent towers | Radiating or open geometry | Arches, open bays, or outstretched forms suggesting outward reach |
| **Specialist / Utility** | Status effects, slow, control | Irregular or compound shape | Mixed vertical/horizontal with a secondary element (disc, ring, reservoir) |

**The four archetype rules:**

1. **Defensive towers are the widest shape on any row.** If the silhouette could
   pass for a Damage Dealer, add horizontal mass until it cannot.

2. **Damage Dealers have the highest point on the board.** The barrel or spire
   tip is always the topmost element in its grid area. "Points up, shoots out."
   If it does not point, it does not read as a weapon.

3. **Support towers have open negative space.** At least 30% of the silhouette's
   bounding box must be empty. Closed, dense shapes suggest containment; open
   shapes suggest broadcast. Non-negotiable.

4. **Specialist towers are the most visually distinct element in any cluster.**
   Must not resemble any other archetype in silhouette. Use a compound or hybrid
   form with no single clear precedent in the other three.

**Design test:** Four tower silhouettes in a row, color layer hidden. A player
must categorize each by function in under three seconds per tower. If Defensive
and Damage Dealer swap, the mass and height grammar are not distinct enough. Fix
by proportion adjustment, not detail addition.

**Shape family:** All towers draw from *constructed, geometric* shapes — straight
edges, clear radii, intentional angles. This distinguishes them from monsters
(organic) and landscape (natural). Towers are the player's artifacts.

**Modular component note:** Components modify behavior but must not change the
base archetype silhouette enough to fail the four-archetype design test. Components
are additive details, not silhouette replacements. A Damage Dealer with all four
upgrade slots filled must still read as a Damage Dealer first.

---

### 3.2 Environment Geometry

**The dominant geometry is angular with soft interruption.**

- **Primary forms:** Clean rectangular masses with deliberate chamfering at top
  edges — shaped stone, not quarried raw. Right angles dominate the plan; corners
  are softened slightly at the top to read as hand-carved rather than CAD-extruded.
  The slight imperfection of corners carries the "hand-carved diorama" register of P2.

- **Secondary forms:** Organic interruption permitted only as ground-level detail
  — moss patches, root systems, irregular stone textures. These must never reach
  above 25% of any structure's height. Organic forms at height read as foliage or
  creature, not architecture.

- **Forbidden form:** Smooth, uninterrupted curves on large structures. Arches
  are permitted but must use a limited radius so they read as carved stone, not
  poured concrete. Perfect circles at scale break the hand-crafted register.

**The Sanctuary:** Most architecturally rich space. Must present at least three
distinct height levels viewed from the oblique play angle. Nothing in the Sanctuary
looks new — every structure has one visible organic interruption per build (vine,
root growth, worn edge) to signal age and permanence.

**The Mission Field (16×12 grid):**

1. **Path cells are flat.** Any terrain feature on a path cell must be below 8px
   height at the play angle — never obscure monster movement.

2. **Non-path cells** may have vertical elements up to 50% of a tower's base
   height. Above that, they compete with towers.

3. **No two adjacent non-path cells** may have vertical elements of the same
   height. Consistent heights across multiple cells create a visual wall that
   competes with tower silhouettes.

**Grid noise prevention — figure/ground discipline:**
- All non-interactive terrain renders at 70% of maximum saturation
- Terrain geometry stays low and wide
- Interactive objects (towers, monsters, hero) must occupy the upper half of the
  scene's visual weight

**Design test for noise:** Fill the 16×12 grid at maximum entity count. If the
Hero, a Boss monster, and a Damage Dealer tower cannot be immediately distinguished
as three separate things from the ground layer, the terrain is too tall. Fix by
terrain height reduction before prop removal.

---

### 3.3 UI Shape Grammar

**The UI is a frame, not a painting.** It must not compete with the game world.
Its shape grammar is derived from the world's aesthetic but simplified — world
shapes at one remove.

**The UI shape family: architectural stone, simplified.**

Panels and containers derive from the same chamfered-rectangle grammar as the
world's built structures, but with a consistent corner radius (recommended: 4–6px
at target resolution). This regularity signals "interface" vs. "world" without
abandoning the aesthetic lineage.

**Buttons:**
- Primary shape: rectangle with chamfered top two corners, squared bottom two
  corners — a slight trapezoidal read that sits rather than floats (grounded, P1).
- Primary action buttons only: fully chamfered (all four corners) to elevate them
  above secondary buttons without color change alone.
- Circular buttons: permitted only for the Hero class badge (diegetic, world-space)
  and the skill hotbar (screen-space HUD zone). No other circular UI elements.

**Icons:** All icons use the chamfered-rectangle frame with a 2px inset border.
Must read at 24×24px minimum. Any icon that cannot be read at 24×24 without a
label must not appear without a label.

**How the UI avoids competing with the game world:**
1. **UI panels live at screen edges.** The center third of the screen is reserved
   for the game world during gameplay. No persistent UI element occupies it.
2. **UI shape grammar is more regular than world geometry.** Consistent corner
   radius and alignment grid signal "different register."
3. **UI uses flat or very-low-relief geometry.** No UI element casts a world-space
   shadow. Drop shadows on panels are permitted with a purely vertical offset only.

**Design test:** During peak combat, toggle the UI layer visible/invisible. The
game world should feel equally dense both ways. If the world feels emptier with
the UI removed, the UI is carrying visual weight it should not own. Fix with shape
simplification or opacity reduction, not world density increase.

---

### 3.4 Hero vs. Supporting Shape Hierarchy

**Mandated read order for every in-game scene:**

1. **Hero** — vertical silhouette and 3D rendering set it apart immediately. No
   other element shares the first-read layer. Always found before anything else
   is consciously processed.

2. **Active Threat** — Boss (multi-cell mass) → Elite (asymmetric protrusion) →
   wave front (leading edge of Standard monsters, readable via movement contrast).

3. **Player's Towers** — static during a wave; yield the eye to moving entities.
   Archetype grammar allows rapid *identification* on the third read without
   demanding the first read.

**No read layer:** Environment props, ground texture, path lines, ambient details.
Registered peripherally. If a playtester ever reports noticing terrain before a
Boss, the terrain is too prominent — reduce it.

**Ensuring the 3D Hero reads without being jarring:**

1. **Fixed oblique angle only.** The 3D model is always rendered from the same
   fixed oblique angle as the play camera. No perspective distortion on the hero
   model. Depth cues come from the same visual grammar as 2D sprites (ambient
   occlusion and rim light ≈ sprite stacking and edge shading).

2. **Grid-compliant footprint.** The Hero's feet must fit within one grid cell.
   Upper body and weapon may extend above the cell boundary — that is the vertical
   elongation rule. Ground contact must be grid-compliant.

3. **No view-dependent effects.** No parallax on the model; no view-dependent
   specular that would shift if the camera moved. The camera is fixed; the 3D
   model must behave as if it, too, is a fixed-angle sprite.

4. **Shadow footprint is mandatory.** The Hero must cast a sprite-style shadow
   (flattened ellipse on the ground plane, consistent with cast shadow sprites on
   all other objects). If the shadow is absent, the Hero defies P1 regardless of
   model quality. This is the single most important rule for preventing the 3D
   model from reading as floating.

**Design test for hierarchy:** In a mid-wave scene, ask a first-time viewer to
identify: (1) the player character, (2) the most dangerous enemy, (3) the tower
currently shooting — under five seconds total. If they hesitate on step 1, increase
the Hero's vertical silhouette (height, not color). If step 2, increase the Elite's
asymmetric mass. If step 3, increase the Damage Dealer's firing point height.

**The 3D/2D seam test:** A player who notices the seam should describe the Hero
as "a figurine placed on the board" — which aligns with the diorama identity. If
they describe it as "copied from a different game," the Hero's material language
needs to be made warmer and more painterly to match the 2D sprite palette.

---

### 3.5 Quick Reference Card

| Rule | One-Line | Pillar |
|------|----------|--------|
| Hero silhouette | Tallest, narrowest, vertical axis — exclusive | P2 |
| Standard monster | Shorter than wide, clean outline | P3 |
| Elite monster | Asymmetric protrusion — one rule only | P3 |
| Boss monster | Multi-cell visual mass | P2 + P3 |
| Defensive tower | Widest shape on the row | P3 |
| Damage Dealer tower | Highest point on the board | P3 |
| Support tower | 30% negative space minimum | P3 |
| Specialist tower | Must not resemble any other archetype | P3 |
| Environment primary | Chamfered rectangles, angular dominant | P1 |
| Environment organic | Ground-level only, max 25% of structure height | P1 |
| UI shape | Chamfered rectangles, more regular than world | P2 |
| UI position | Screen edges only — center reserved for game world | P3 |
| Visual hierarchy | Hero → Boss/Elite → Towers → Everything else | P1 + P3 |
| 3D/2D seam | Hero shadow footprint mandatory | P1 |

---

## Section 4: Color System

> All color values are specified in both HSL (working space) and hex
> (implementation reference). Semantic rules in 4.2 are binding across all
> artists and systems. UI-only colors in 4.4 must never appear in world space.

---

### 4.1 Primary Palette

The palette is built around the cabinet-diorama register: warm lacquered wood,
aged parchment, polished stone, candlelight, and twilight sky.

---

#### Sanctum Amber
**HSL:** 38, 72%, 48% | **Hex:** `#C8801A`

**Role:** The warm backbone of the game world. Tower frames, sanctuary walls,
path-border stone edging, torch glow, and the Hero's standard rim highlight.

**World logic:** The sanctuary is lit by fire and lantern. Amber is the color
of that light. When the player sees amber, they are in a controlled, known space.

**Most prominent in:** SANCTUARY (dominant), INTERMISSION (fading), MISSION_COMPLETE
(enriched toward gold).

**Cross-state legibility:** WAVE_ACTIVE warm key reinforces amber on lit faces;
cool fill pushes amber elements to orange-brown on shadow faces. In DEFEAT,
amber loses ~35% saturation — constructed elements feel muted, not invisible.

---

#### Fieldstone Grey
**HSL:** 210, 8%, 52% | **Hex:** `#7E8590`

**Role:** The neutral ground tone. Mission-field path surfaces, rock formations,
neutral (unupgraded) tower body, and monster spawn platform.

**World logic:** Carved stone and compacted earth — permanent, patient, and
slightly cool against sanctuary warmth. The visual silence everything reads against.

**Most prominent in:** SCOUT (dominant), WAVE_ACTIVE (darkens under split
lighting, increasing contrast against active game objects).

---

#### Parchment Cream
**HSL:** 44, 60%, 88% | **Hex:** `#F5EDCB`

**Role:** The lightest world value. Tower placement indicators, grid cell
highlights, readable surface texture on neutral towers, Hero skin tone register.

**World logic:** Parchment is the material of maps, orders, and plans — the
commander-general's domain. Cream appears where the player acts and decides.

**Cross-state note:** Appears washed out in MISSION_COMPLETE's golden hour.
Use at 70–80% opacity or pair with a darker Sanctum Amber border in that state.
Never use as a standalone fill in MISSION_COMPLETE.

---

#### Scout Blue
**HSL:** 210, 55%, 38% | **Hex:** `#2D5F8A`

**Role:** Coolness, distance, and the pre-wave pause. Scout phase sky gradients,
shadow fills in SCOUT state, and tower build-radius indicator rings.

**World logic:** Blue is the color of the sky when the field is quiet and the
next wave has not arrived. Blue = "not yet decided."

**Most prominent in:** SCOUT (dominant sky and shadow values), SANCTUARY
(as distant-window light only — never as a warm-room surface).

**Cross-state note:** Tower radius rings must render at 50% opacity during
WAVE_ACTIVE to avoid competing with VFX.

---

#### Verdant Green
**HSL:** 128, 58%, 35% | **Hex:** `#25813A`

**Role:** Healing, life, and restoration. Heal VFX, regeneration status
indicators, sanctuary garden decoration, and HP-restoring skill orbs.

**World logic:** Green grows in the sanctuary because it is protected. On the
field, green is rare — which is why it communicates "this helps you" immediately.

**Critical constraint:** Green = heal. Fixed language. No decorative use of
green on monsters, towers, or terrain that could compete with healing VFX.

---

#### Threat Crimson
**HSL:** 4, 78%, 42% | **Hex:** `#BE2020`

**Role:** Danger, damage-taken, and enemy presence. Damage VFX, low-HP warnings,
monster health bars, and boss arrival color shifts.

**World logic:** Blood, fire, and urgency. The world does not use red decoratively.
If the player sees red in the environment, a threat is expressing itself.

**Critical constraint:** Red = damage. Never use for decorative fire, sunset
gradients, or UI chrome. The exception is low-HP vignette — a damage-adjacent
state and semantically consistent.

**Cross-state note:** In SCOUT's cool overcast, Crimson shifts cooler/more
purple-shifted. Pre-test damage VFX under SCOUT lighting. Add a thin warm-orange
rim to damage numbers if a maroon shift is confirmed in engine.

---

#### Herald Gold
**HSL:** 45, 95%, 55% | **Hex:** `#F5C01A`

**Role:** Critical hits, Tower Affinity aura, Hero class badge borders, and
achievement feedback. Gold marks "this hit mattered" or "this combination is active."

**World logic:** Gold is rare in the field and precious in the cabinet. It
appears when something exceptional happens, not as ambient decoration.

**Most prominent in:** WAVE_ACTIVE (crit flashes, Tower Affinity glows),
MISSION_COMPLETE (reward signal integrated with golden-hour palette).

**Cross-state note:** In DEFEAT's desaturated state, gold approaches pale yellow
and reads as hollow. This is intentional — crits during a losing fight should
feel muted.

---

### 4.2 Semantic Color Vocabulary

**Binding rules. Consult before placing any color in game.**

---

**Red = damage, threat, and danger.**
VFX: damage-taken by Hero or tower. HUD: HP below warning threshold.
Environment: never used decoratively. For "warm fire," use Sanctum Amber and
orange-shifted light gradients, not Threat Crimson. Fire is warm. Red is blood.

---

**Gold/Yellow = exceptional, critical, and affinity-active.**
Crit hits, Tower Affinity bonus states, Hero class badge border, mission-complete
star fills. A performance color — appears when the player does something better
than the baseline. Must not appear as ambient decoration. Use orange-amber
gradients for warm sky, not Herald Gold.

---

**Blue = distance, potential, and the pre-wave pause.**
Scout phase sky, tower placement radius rings, shadow fill in cool lighting.
Blue means "not yet decided" — the quiet field before the wave, the space where
a tower could go. Blue carries no danger signal.

---

**Green = restoration and life.**
Heal VFX, regeneration status, sanctuary vegetation. Green is a gift. Must not
appear on enemy elements. Monster poison or acid attacks must use yellow-green or
sickly olive (outside the primary palette) to avoid reading as "heal."

---

**White/Parchment = neutral selection and player agency.**
Grid highlights, placement indicators, ability range markers, and selection halos.
White = "this is a decision point, not a result." Bright pure white (`#FFFFFF`)
is reserved for critical hit sparkle accents only.

---

**Purple = elite enemy status and boss escalation only.**
Purple does not appear in the primary world palette. It is held in reserve as the
boss encounter escalation color. The moment purple appears on screen, the player
should register threat-above-red. Must never be used for UI chrome, decorative
elements, or generic "magic." Its power comes from its scarcity.

---

### 4.3 Per-Area Color Temperature Rules

#### Mission Field — Phase-by-Phase

| Phase | Color Temperature | Notes |
|-------|------------------|-------|
| SCOUT | 5500–6500 K cool blue-white | Field reads quiet and analytical. Player is planning. |
| WAVE_ACTIVE (standard) | Split: 3000–3500 K warm key / 6000–6500 K cool fill | Dramatic. Every object gains depth. |
| WAVE_ACTIVE (boss wave) | Split + purple ambient push | Purple enters through shadow fill only. |
| INTERMISSION | 3200–3800 K transitional warm | Scene "exhales." Split-lit drama dissolves. |
| MISSION_COMPLETE | 2500–2800 K golden hour | Maximum warm. Herald Gold VFX reads as naturally integrated. |
| DEFEAT | 4500–5000 K cool-neutral, 60–70% saturation | Warmth leaves. The field becomes a ruin. |

#### Boss Wave Ambient Push — Implementation Spec

The purple boss-warning is NOT a global color correction. Implement as:
1. A purple-tinted secondary shadow fill light at ~15–20% opacity, casting from
   a low angle opposite the warm key.
2. A subtle vignette at screen edges shifting from neutral dark to purple-dark
   over 8–12 seconds.

Field sky and ground texture do NOT change hue. Only shadowed volumes between
objects shift. This reads subliminally before the player consciously registers
"purple = boss." The goal is dread, not a flashing banner.

#### Boss Wave Early Warning System
- **8–12 seconds before spawn:** Purple ambient push begins + HUD boss indicator
  appears + distinct audio cue plays.
- The HUD indicator is the primary information channel. The ambient color shift
  and audio are reinforcement.

#### Wave Color Escalation

- **Standard wave:** No ambient shift. Split-lit dramatic lighting engages as
  first monster spawns.
- **Boss wave:** Purple ambient push begins 8–12 seconds before spawn.
- **Final wave:** Warm key intensifies 10–15% above standard WAVE_ACTIVE values,
  pushing toward MISSION_COMPLETE temperatures — a subconscious signal the end
  is near.

#### Sanctuary — Dominant Palette

Interior space, lantern and candlefire lit:
- **Walls and floors:** Sanctum Amber at 60–70% value
- **Carved detail:** Parchment Cream at 75–80% value with Sanctum Amber cast shadows
- **Accent elements:** Herald Gold at full saturation
- **Recessive spaces (doorways, alcoves):** Fieldstone Grey darkened 40%,
  shifted slightly cool for depth contrast

The Sanctuary must never read as outdoor or cool. Any new prop or character
bringing cool hues into the sanctuary space requires a warm-light pass before
approval.

---

### 4.4 UI Palette

**Three rules for UI/world separation:**
1. UI chrome is never a world palette color at full saturation — shift by 20% minimum.
2. UI interactive elements use blue-shifted cool base that does not appear anywhere
   in the world palette as a primary surface.
3. UI warning colors match semantic color vocabulary — no divergence.

---

#### UI Chrome (Primary Surface)
**HSL:** 220, 15%, 18% | **Hex:** `#252D3D`
Dark blue-grey. Base for panels, header bars, dialog backgrounds. Floats above
the world without blending. This color does not exist in the game world.

#### UI Parchment (Content Surface)
**HSL:** 44, 35%, 82% | **Hex:** `#DDD4B0`
Desaturated, cooler-toned sibling of Parchment Cream. Intentionally pulled 15%
toward cool-grey so world placement indicators never visually merge with tooltip
backgrounds. The player must always answer "is this screen or world?"

#### UI Accent (Interactive Highlight)
**HSL:** 200, 75%, 55% | **Hex:** `#23A8D4`
Bright cyan-blue. Focused buttons, selected elements, active skill borders, hover
states. Does not appear in world space. Cooler and more saturated than Scout Blue.

**UI-only rule:** Cyan (`#23A8D4` and close variants) must never appear in
world-space assets. A tower with a cyan glow would be read as a selected UI state.

#### UI Warning (Critical Alert)
**HSL:** 38, 95%, 55% | **Hex:** `#F5921A`
Saturated orange. Resource-not-enough states, time-pressure countdowns, final 10%
of HP bars in non-critical UI. Escalation: **orange (warning) → red (damage/danger)**.

#### UI Disabled State
**HSL:** 220, 8%, 45% | **Hex:** `#6B7280`
Flat blue-grey. Buttons the player cannot currently interact with. Must always
be paired with a visual treatment (reduced icon opacity, greyed label, lock icon)
— never the sole disabled signal (colorblind safety).

---

#### UI-Only Colors — Must Never Appear in World Space

| Color | Hex | Reason |
|-------|-----|--------|
| UI Chrome Dark | `#252D3D` | No world surface uses this dark blue-grey |
| UI Accent Cyan | `#23A8D4` | Reserved for interactivity — no world element should look selectable |
| UI Parchment | `#DDD4B0` | Intentionally desaturated from world Parchment Cream |
| UI Warning Orange | `#F5921A` | Sits between world fire (amber) and semantic red — world use risks misreading |

---

### 4.5 Colorblind Safety

Standard accessibility tier — all information-critical color pairs require a
non-color backup cue. See `design/accessibility-requirements.md`.

---

#### Pair 1: Verdant Green (heal) vs. Threat Crimson (damage) — BLOCKING

**Risk:** Deuteranopia and protanopia users cannot reliably distinguish green
from red.

**Primary backup:** Shape and prefix. Heal numbers carry `+` prefix; damage
numbers carry `-` prefix. Always present — never suppressed for visual cleanliness.

**Secondary backup:** Animation direction. Heal VFX rises (upward particles,
ascending numbers). Damage VFX falls or pulses outward (descending numbers,
outward shockwave).

**Tertiary backup:** Sound. Heal = soft ascending tone. Damage = percussive
impact. (Coordinate with audio-director for finalization.)

---

#### Pair 2: Herald Gold (crit) vs. UI Accent Cyan (interactive) — ADVISORY

**Risk:** Tritanopia users may not distinguish blue-yellow reliably.

**Primary backup:** Spatial separation. Crit numbers appear in world space on the
battlefield. Cyan appears on UI overlay panels. These contexts are always distinct.

**Secondary backup:** Animation. Crit numbers scale up (1.4× on spawn). UI accent
uses steady glow, no scale animation.

---

#### Pair 3: UI Disabled Grey vs. Fieldstone Grey (world surface) — BLOCKING

**Risk:** Any colorblind type. Both are low-saturation grey — a disabled button
could be misread as world texture.

**Primary backup:** UI Disabled Grey must always be paired with a visual treatment:
reduced icon opacity (40–50%), greyed-out label, or lock icon overlay. Grey tone
alone is never the sole disabled signal.

**Secondary backup:** Value contrast. UI chrome background (`#252D3D`) under all
panels ensures Disabled elements appear on dark backing; Fieldstone Grey appears
on lit world surfaces. Dark backing vs. lit world is the spatial separator.

---

#### Pair 4: Verdant Green (heal VFX) vs. World Vegetation (sanctuary garden) — BLOCKING

**Risk:** Players habituate to green as "scenery" rather than "heal event" if
the garden uses the same color liberally.

**Primary backup:** Animation. Decorative vegetation is static or slow idle sway
(no particles, no floating elements). Healing VFX is always animated: rising
particles, ascending number, bloom pulse.

**Rule for artists:** Decorative vegetation must use Verdant Green at maximum
70% saturation and must never animate with upward-floating particles. Still = décor.
Moving = event.

---

#### Pair 5: Purple (boss warning) vs. Scout Blue (pre-wave field) — ADVISORY

**Risk:** Tritanopia variants may not distinguish blue from purple.

**Primary backup:** HUD boss indicator (primary information channel). The ambient
color shift is reinforcement, not the primary signal.

**Secondary backup:** The ambient shift is a *transition* (the change itself is
the signal, not the endpoint color). Even if hues are indistinguishable, the
change-in-progress is detectable.

**Tertiary backup:** Distinct boss-warning audio cue plays on the same trigger.

---

#### Colorblind Safety Summary

| Pair | Risk | Primary Backup | Gate Level |
|------|------|----------------|------------|
| Green (heal) vs. Red (damage) | Deuteranopia/Protanopia | +/- prefix on all numbers | BLOCKING |
| Gold (crit) vs. Cyan (UI) | Tritanopia | Spatial separation (world vs. UI layer) | ADVISORY |
| UI Disabled Grey vs. World Grey | Any | Icon/opacity treatment on disabled state | BLOCKING |
| Green VFX vs. Green vegetation | Semantic clarity | Animation (static = décor, rising = heal) | BLOCKING |
| Purple (boss) vs. Blue (scout) | Tritanopia | HUD indicator is primary; transition is detectable | ADVISORY |

All BLOCKING pairs require implementation and QA sign-off before the mission HUD
is considered shippable.

---

## Section 5: Character Design Direction

> This section briefs any character artist, whether in-house or outsourced, executing
> character assets for Sanctuary Defenders. Every rule below is actionable and testable.
> Where a rule is derived from an upstream constraint (Section 3 shape language, Section 4
> color vocabulary, or a GDD pillar), the derivation is stated. Rules marked **binding**
> cannot be overridden at the asset level — escalate to Art Director.

---

### 5.1 Hero Visual Archetype

#### 5.1.1 The Cultural Register: Warden-Smith

The hero occupies the register of a **warden-smith** — a keeper of sacred and constructed
things, equal parts craftsperson and sentinel. This is not a warrior-hero in the classical
sense and not an arcane scholar. The warden-smith *made* the towers, *maintains* the
sanctuary, and *fights* when the work demands it. The archetype carries these three tensions:

| Tension | Visual Expression |
|---------|------------------|
| Maker vs. Fighter | Worn craft tools and fighting arms coexist on the same figure. No purely decorative elements. Every piece of kit has a function. |
| Precision vs. Endurance | The silhouette is lean and deliberate, not bulky. But the materials are heavy — layered leather, hammered plate, wrapped grips. Nothing is fragile. |
| Familiar vs. Strange | The hero reads as recognizably human and grounded, but the tower components and materials that accumulate on the figure through fusion states place the hero outside any single cultural reference. |

**Diorama justification:** In a cabinet diorama, the centrepiece figure is never generic.
It is *specific* — hand-painted details, a particular pose, a material language that places
it in a specific world. The warden-smith achieves this through specificity of craft: the
tools are real tools (a smelting ladle worn as a hip ornament, a calibration instrument
repurposed as a fastening device), not fantasy decoration. *See Section 1: Hybrid Rendering
Note — the hero is the centrepiece figure; the 2D world is the crafted scenery around it.*

**What this archetype is NOT:**
- Not a generic fantasy knight (no full-enclosure plate, no plumed helmet)
- Not a wizard or scholar (no robes, no scrolls, no floating magical instruments)
- Not a rogue or thief (no asymmetric hood-and-dagger silhouette)
- Not a war general from a historical reference (no epaulettes, no command staff)

The reference register is: specialist tradesperson meets field commander. The closest
real-world analogue is a master siege engineer who also fights — technical authority
expressed through the body, not through title.

---

#### 5.1.2 Silhouette Specification (Binding)

All rules from Section 3.1.1 are binding. Reproduced here for outsource clarity:

- **Aspect ratio:** Target 1.8:1 (height:width) at default zoom, measured at idle stance
- **Floor:** No idle animation frame may collapse below 1.4:1. Combat crouches permitted
  only in active-attack frames — never in idle loops
- **Apex:** Crown (helmet/head) must be a clean point or rounded dome — never flat. The
  hero's crown is always the highest pixel in any entity cluster
- **Ground contact:** Feet are wide-planted relative to torso. The stance communicates
  weight at the contact point

*Additional constraint for the warden-smith register:*

**The silhouette crown is a narrow utility helmet or close-fitting headgear with a
single upward accent.** Acceptable apex forms: a narrow visor-ridge that terminates in
a point, a close-wrap hood with a hardened crown finishing in a rounded dome, a low
profile helm with a centered crest-fin. Unacceptable apex forms: a full-face bucket
helm (loses the craftsperson register), a wide-brim hat (flattens the crown and violates
the point/dome rule), elaborate horned or winged helmet additions (silhouette reads as
monster-adjacent or fantasy-generic).

**Design test:** Render the hero at the oblique play angle and at game camera distance
(approximately 48 px tall on screen). The crown accent must still read as a single upward
form at that scale. If the crown detail requires zooming in to distinguish from a flat top,
redesign it as a larger single form.

---

#### 5.1.3 Material Language

The hero's surface materials must read as *made things* at game distance. Three material
categories are permitted on the base (non-fused) hero:

| Material Layer | Description | Color Register |
|---------------|-------------|----------------|
| **Hardened leather (primary)** | The dominant surface — shaped panels with visible stitching and edge-reinforcement. Tanned, not dyed. Wears naturally. | Dark warm brown, approximately HSL 30, 35%, 28%. Not black. Not bright. |
| **Hammered plate (secondary)** | Irregular plate pieces over the leather where impact is likely — shoulder cap, shin guard, forearm bracer. These are *smith-made*, not factory-uniform. Surfaces show hammer texture, mild weathering. | Fieldstone Grey `#7E8590` as the base tone. Lit faces shift toward Parchment Cream `#F5EDCB`. Shadow faces shift toward deep warm grey. |
| **Wrapped grip and cord (accent)** | Tool handles, weapon grips, and fastening cords. Tight-wrapped woven cord, worn but maintained. | Desaturated Sanctum Amber, approximately HSL 38, 40%, 38%. Warmer and darker than tower amber to distinguish hero from constructed world objects. |

**The hero skin register:** Hero skin reads at Parchment Cream `#F5EDCB` as its lightest
value. It must not be rendered as bright white or highly saturated warm tan — either
extreme pushes the hero toward fantasy-generic. Exposed skin area should be minimal
(wrist area, lower face if helmet is open-faced). The hero is protected, not displayed.

**Standard rim highlight:** Off-white or pale warm-grey. Activates on the hero's
dominant-facing edge (the edge facing the oblique light source). This rim is always
present regardless of game state. See Section 2 cross-state rules and Section 3.4.
In MISSION_COMPLETE, this rim shifts to full Sanctum Amber — this state change is
*shader-driven* and must be specced to the technical-artist before hero asset sign-off.

**Tower Affinity aura (when active):** Herald Gold `#F5C01A` radiates as a soft glow
from the hero's chest-plate area, not from the outline. Glow radius is contained to
approximately 1.5× the hero footprint. Must not read as a second rim highlight or
compete with the standard rim. See VFX spec (delegate to technical-artist).

---

#### 5.1.4 Expression Register

*Pillar: Strategic Mastery*

The hero's expression register is **composed stoicism with visible effort.** Not blank or
inexpressive — the warden-smith is deeply invested in the fight. But the expression
communicates control, not panic. The face reads as someone who has thought about this
before it started.

**At game distance:** The hero's face is largely read through pose and silhouette, not
facial features. Fine facial detail is a close-up asset feature only. In the 3D model,
the face shape must communicate the correct register from 48 px of on-screen height:
jaw-set, slight forward lean, grounded weight. Expressive smile or open-mouth distress
are wrong at any distance.

**Expression rules by animation state:**

| State | Expression Rule |
|-------|----------------|
| Idle | Weight resting but alert — slight forward tilt at the crown, eyes forward. Not slouched. Not rigid. The craftsperson at rest between tasks. |
| Combat auto-attack | Drive from the shoulder, not the whole body. The strike is controlled, not windmill. |
| Skill activation | The head drops slightly on cast then snaps back — commitment, then recovery. |
| Low HP | Posture drops 5–8°. Head tilts minimally forward. Shoulders narrow slightly. The body communicates strain; the face does not grimace. |
| MISSION_COMPLETE | Stance opens: weight shifts back, arms fractionally lower. Exhale. Not triumph — vindication. |

**Facial geometry note for the 3D model:** The hero's face needs no high-poly close-up
fidelity. Prioritize silhouette accuracy and clean surface read at game distance. Detailed
facial work is budget spent on something the player cannot reliably perceive during play.
Redirect face polygon budget to the silhouette crown, shoulder mass, and hand/grip detail —
the elements that register at game scale.

---

### 5.2 Monster Design Direction — Per Tier

#### 5.2.1 The Monster Aesthetic Register: Intrusions

*Pillar: The Living Sanctuary*

Monsters do not belong here. This is the core statement that must be legible in every
monster design: they are **intrusions** into a made space. They were not invited, they
do not fit the scale, and their presence is a violation. Their aesthetic register is
"organic growth that does not know it is unwelcome" — they are not evil per se, but
they are fundamentally incompatible with the crafted, tended world of the sanctuary.

This creates the critical distinction from generic fantasy enemies: Sanctuary Defenders
monsters feel like **natural-world pressures** — territory-claiming, swarming, scaling,
breaking. They are not soldiers, not cultists, not demons. They are the equivalent of
an infestation or an ecosystem asserting itself against a structure. The player's
emotional relationship with them is management and control, not hatred. This register
supports the "strategic mastery" pillar: you do not despise the threat, you understand
it and dismantle it.

**Shape family (binding, from Section 3.1.2):** All monster tiers draw from organic,
irregular shapes — no perfect circles, no hard right angles. Monsters feel grown, not
built. This distinguishes them from towers (constructed) and the hero (deliberately crafted).

---

#### 5.2.2 Standard Monsters — The Swarm Register

**Visual brief:** Something that belongs in quantity. The design must *invite* the player
to look at fifteen of them at once, not one. Standard monsters are legible as a *tide*
before they are legible as individuals.

**Silhouette (binding):** Compact, low-to-ground, wider than tall. No protrusion above
the horizontal midline of the bounding box.

**Material and surface register:**

Standard monsters are covered in **undifferentiated organic surface** — chitin, matted
fur, packed earth membrane, or tight-scaled hide. The key constraint: the surface must
read as *same material all the way through.* No secondary materials, no armor inlays,
no exposed mechanical structures. Standards feel simple because they *are* simple — one
material, one purpose, one direction of movement.

Surface color logic for Standard monsters:
- **Base tone:** Desaturated warm earths — dried clay, aged bark, dull amber-brown.
  These are Sanctum Amber-adjacent but de-saturated to approximately 30–40% of Sanctum
  Amber's HSL saturation. They must not match tower amber. The desaturation communicates
  *dullness* — Standards are not interesting individually.
- **Highlight:** A single specular catch on the highest point of the silhouette. Not
  a rim highlight (that register belongs to the hero). A simple wet-surface sheen that
  communicates living material.
- **No Herald Gold, no Threat Crimson, no Verdant Green** on Standard monster surfaces.
  These semantic colors are reserved for information events, not character design.

**Preventing generic-fantasy read:** Standard monsters must have one physical attribute
drawn from a mundane organism — insect body segment distribution, the packing density
of a mussel cluster, the ground-contact geometry of a crab. This is the detail that
makes them feel like a world ecology rather than a generated enemy palette. The attribute
should be embedded in the proportions (leg placement, body division), not added as a
texture detail.

**Complexity budget:** Maximum 3 distinct surface zones at game distance. One silhouette
form, one body color area, one specular accent. Nothing else reads at swarm scale.

---

#### 5.2.3 Elite Monsters — The Named Threat

**Visual brief:** One of these stops a mid-wave tactical scan. The player's eye
snaps to it. At game distance, an Elite announces itself without a health bar or label.

**Silhouette (binding):** Mid-height, approaching 1:1 aspect ratio. One asymmetric
protrusion that breaks the bounding box — horn, blade-arm, displaced shoulder mass,
single enlarged limb. The asymmetry is the tier signal. Symmetry reads as Standard.

**Material and surface register:**

Elites introduce a **secondary material** that does not appear on Standards. This
secondary material is the visual marker of "elevated threat." Three valid secondary
materials:

| Secondary Material | Read | Example Application |
|-------------------|------|---------------------|
| Hardened carapace | Armor-plating grown from within | Overlapping ridge-plates on the dorsal protrusion |
| Crystallised tissue | A biological process that produces gem-like density | Crystalline growth on the protrusion tip — not faceted like a gem, but compressed |
| Biological metal | Dense ferrous tissue, as if the creature processed iron | The protrusion's leading edge reads as dark metallic, but with organic grain |

Only one secondary material per Elite design. Using two secondary materials pushes
the design toward Boss register.

**Color escalation from Standard:**
- Elites shift the Standard base earths approximately 15° toward cooler, more blue-brown.
  This subtle hue shift communicates "older, harder, more dangerous" without
  introducing the full Threat Crimson signal, which is reserved for HP events.
- The secondary material carries the primary contrast: carapace reads as near-black
  against the earthy base; crystallised tissue catches one strong highlight; biological
  metal reads as dark Fieldstone Grey `#7E8590` with a high-contrast specular.
- No Herald Gold on Elite surfaces. Gold is performance color (crits, affinity). An
  Elite that incorporates gold reads as "player bonus trigger" rather than "threat."

**The one-protrusion rule (binding):** One protrusion, asymmetric, above the horizontal
midline. Additional secondary protrusions are prohibited. If the design requires two
protrusions for proportion reasons, the second must be visually subordinate to near-
invisibility (same color as base body, no secondary material application).

---

#### 5.2.4 Boss Monsters — The Encounter

**Visual brief:** The Boss does not move through the field. The Boss *occupies* it.
Its presence restructures how the player reads the entire screen.

**Silhouette (binding):** Multi-cell visual mass. Reads as too large to be a normal
enemy without any other context. Above 1.5:1 aspect ratio (any orientation) or wider
than 1.5 standard grid cells visually.

**Material and surface register:**

Bosses are permitted **three distinct material zones**. The three-zone structure
creates internal complexity without chaos — the player can parse "this part of the Boss
is different from that part" without the design becoming noise.

| Zone | Role | Treatment |
|------|------|-----------|
| **Core mass** | The dominant body zone. Establishes the baseline material register. | Heavy, dense organic material — thick hide, compressed growth, packed biological structure. Base color sits 10–20° cooler and 20% darker than Standard monster base tone. |
| **Secondary structure** | One region of distinct material — the protrusion system, limbs, or dorsal mass. Must be clearly read as a different layer, not a color variation of the core. | One of the three Elite secondary materials, applied at larger scale. Or a material exclusive to Boss tier: calcified bone-mass, fossilised shell, dried membrane stretched over a rigid skeleton. |
| **The tell** | A single exposed organic feature that communicates the Boss's elemental or mechanical identity — a heat vent, a membrane that pulses, a seam where impact effects should read. | Saturated but controlled. Permitted to use a color outside the standard earthy monster register, but must not use semantic palette colors (no Verdant Green, no Threat Crimson on the surface — those appear during combat events, not as base design). |

**Boss-exclusive color escalation:**
When a Boss wave activates, a purple ambient push occurs in the scene lighting (see Section
2 and Section 4). The Boss design must be calibrated so the ambient purple shift *enhances*
its threat read rather than clashing with it. Practically: Boss base tones should be
cool-dark, not warm-brown. They must sit in the cool shadow region of the color space so
the purple fill light enriches rather than fights the surface.

**Purple surface use on Bosses:** A trace of reserved purple in the Boss's deep shadow
areas is permitted — embedded inside cavities, under protrusions, in the seams between
material zones. Maximum saturation for embedded purple: HSL ×, 30%, ×. Never on
a lit or convex surface.

**Complexity budget:** Boss designs are permitted full detail investment, but must still
pass the silhouette-only legibility test. Fold the complexity *into* the three material
zones. Details that sit on top of the zones without belonging to them are removed — they
add noise without aiding threat readout.

**Design test:** Paste the Boss silhouette alongside three Standard silhouettes. A
playtester who has never seen the game must rank it as the biggest threat within two
seconds, without reading any labels or health bars. If they hesitate, the mass
differential is insufficient. Fix with scale increase before detail increase.

---

#### 5.2.5 Preventing Generic-Fantasy Read — The Diorama Standard

*This applies to all tiers.*

Generic fantasy enemies fail the diorama test: they look like they were pulled from a
different world and placed in this one. Sanctuary Defenders monsters must feel like
they belong in *this* world's ecology — which is a tended, crafted, miniature sanctuary
being claimed by an external pressure.

**Three binding rules that enforce diorama fidelity:**

1. **No monster may incorporate any constructed-geometry element.** No straight edges,
   no right angles, no clear radii in any silhouette zone. All monster shape-language
   is organic and irregular. If any part of a monster silhouette looks like it was built,
   it belongs to a tower, not a monster.

2. **Every monster design must have one identifiable real-world ecological analogue**
   embedded in its proportional structure — not as a texture reference, but as a
   proportional skeleton. The analogue informs the ground-contact geometry and body-
   segment distribution. It need not be visible to the player; it is the artist's
   structural reference that prevents the design from becoming generic. Document the
   analogue in the asset spec comment field.

3. **No monster may read as a humanoid warrior.** Two-armed, two-legged upright
   figures with weapons are human-or-humanoid archetypes — they belong to the hero or
   to an NPC register, not to the monster ecology. Acceptable limb configurations:
   quadruped or greater, radially distributed, vestigial arms with dominant locomotion
   structure, or fully limbless flow-motion. Bipedal monsters are permitted only if
   their proportions are clearly non-humanoid (width dominant, limbs proportionally
   wrong, movement logic that does not read as a walking person).

---

### 5.3 Expression and Pose Style

#### 5.3.1 Character Posture Philosophy

*Pillar: Scale Reads as Precious, Not Epic (P2)*

This is a **miniature world viewed from an oblique fixed camera.** The reference posture
register is not theatrical performance — it is a hand-painted figurine. Figurine poses
communicate clearly from one angle (the angle they were designed for) and carry weight
in every pose because weight and stillness are what make a figurine read as real.

**Hero posture:** Contained, weight-forward, functional. No dramatic cape-flare, no
windswept hair, no mid-air-leap idle. The hero stands like someone who expects something
to require their attention shortly. The weight is loaded into the legs, not floating.
This communicates the "strategic mastery" pillar at a glance: this figure is *ready*,
not *reacting*.

**Monster posture:** Low-mass urgency for Standards; dense threat-presence for Elites
and Bosses. Standards lean *forward*, toward the goal. This is their one legible intent:
keep moving. Elites are slightly more upright — the asymmetric protrusion rises. Bosses
have *arrival* weight: they do not lean toward the goal, they *impose toward* it.

---

#### 5.3.2 Idle Animation Philosophy

*Pillar: The Living Sanctuary*

The game spends the majority of its time outside wave phases. Between waves — in SCOUT,
INTERMISSION, and SANCTUARY states — idle animations carry the emotional register of
the game. They are not filler. They are the game's primary emotional communication tool
during the non-combat majority.

**Hero idle specification:**

- **Cycle duration:** 3.0–4.0 seconds. Long enough to be restful; short enough that
  the loop never becomes distracting.
- **Movement budget:** No idle frame may move the hero silhouette's bounding box center
  by more than 4px at the game-camera scale. The hero breathes and settles. It does not
  sway, bob, or bounce. Weight is always present at the feet.
- **The one idle action:** A single deliberate micro-movement is permitted per idle
  cycle — a fractional head-turn toward a nearby tower, a subtle grip-adjustment on the
  weapon, a weight shift from foot to foot. One. Not a sequence of movements. The still
  moments between the micro-action and the next cycle carry the register.
- **No floating elements in idle.** No capes, trailing cloth, or loose elements that
  introduce secondary motion. The hero in idle is a grounded object. Secondary motion
  belongs to WAVE_ACTIVE.

**Monster idle specification:**

- Standard monsters: **no idle.** In the SCOUT and INTERMISSION phases, no Standard
  monsters are present. In wave-entry moments before the first monster crosses the
  spawn threshold, they should not be visible as idle figures. If a pre-wave spawn-
  preview animation is required, use a simple emergence effect (rise from below the
  spawn cell plane), not an idle loop.
- Elite monsters: a minimal breathing-mass animation — the body expands and contracts
  slightly, the protrusion holds still. Cycle duration: 2.5–3.5 seconds.
- Boss monsters: a slow occupation animation — the Boss shifts weight, settles deeper
  into its ground contact, perhaps turns a fractional degree. The read is "this thing
  has presence even when it is not moving." Cycle duration: 4.0–6.0 seconds. Boss
  idle must have zero visual ambiguity at game distance: if a playtester cannot tell
  at a glance whether the Boss is idling or moving, the animation is too active.

---

#### 5.3.3 Combat Pose Readability from Fixed Oblique Camera

The play camera is fixed and oblique. Every combat pose must be designed for this
specific angle. There is no other angle that matters.

**The oblique camera contract for combat poses:**

1. **The attack direction must be readable in the first frame of the attack animation.**
   At game distance, the player cannot wait for mid-swing to understand what just
   happened. The wind-up must already indicate the direction and target.

2. **No pose may collapse the hero's silhouette below the 1.4:1 floor**, even at the
   deepest point of a combat crouch. Wind-up may compress slightly; the strike extension
   phase must recover to or above 1.4:1.

3. **Monster attack poses must read as "approach vector" not "fighting stance."**
   Standards attack by continuation of movement — they do not stop and pose. The
   damage event on the hero is communicated by VFX (hit spark at the hero contact point)
   and sound, not by a monster striking pose.

4. **Elite special attacks** are permitted one telegraphed wind-up pose: the protrusion
   raises or orients toward target before releasing. Duration: 0.4–0.6 seconds. The
   wind-up must be legible as "something large is about to happen" from game distance.

5. **Boss attack phases** require a full visible wind-up that communicates the attack
   type before it lands. Boss attack variety (area denial, charge, projectile launch)
   must each have a *different* wind-up silhouette so the player can learn to distinguish
   them. Wind-up durations: 0.8–1.5 seconds for Boss attacks.

---

### 5.4 LOD Philosophy

> "LOD" in this context means visual detail calibration for the game's fixed play
> angle. This is not a runtime LOD system. It is a design-time decision about
> where detail budget is spent given the actual viewing conditions.

---

#### 5.4.1 The Play-Angle Contract

*Pillar: Scale Reads as Precious, Not Epic (P2)*

The game is played at a fixed oblique view from above. Sprites render at approximately:

| Entity | Approximate on-screen height at standard play zoom |
|--------|---------------------------------------------------|
| Hero (3D model) | 48–56 px |
| Boss monster | 56–72 px (multi-cell) |
| Elite monster | 32–40 px |
| Standard monster | 24–32 px |
| Tower (standard cell) | 32–48 px |

**All detail decisions are made at these sizes, not at zoom-in size.** An asset that
looks richly detailed at 256 px preview but reads as muddy at 32 px is wrong. An asset
that reads crisply at 32 px but looks "simple" at 256 px is correct.

**Close-inspection detail is permitted** only for assets that the player views in the
Sanctuary UI, inventory panels, or character close-up screens — not for anything that
primarily exists on the mission field. Document which context each asset is designed for.

---

#### 5.4.2 Surface Details: Game Distance vs. Inspection Distance

| Detail Category | Visible at Game Distance | Visible at Inspection Distance | Notes |
|-----------------|------------------------|-------------------------------|-------|
| Silhouette shape | Yes — primary signal | Yes | Must work at all distances |
| Primary color zone separation | Yes | Yes | 2–3 zones max at game distance |
| Secondary material (Elite) | Readable as "different," not detailed | Yes, full detail | The *existence* of the material reads; the surface quality does not |
| Grip wrapping, cord detail | No — registers as texture band | Yes | Designed for inspection; do not waste game-distance pixels on it |
| Facial features | No | Partially | Hero face is read through pose at game distance |
| Weapon edge geometry | No | Yes | Silhouette of weapon reads; edge bevel does not |
| Ecological analogue structure (monsters) | Yes — proportional read | Yes — surface read | Structure must work at game distance; texture at inspection distance |
| Boss material zone seams | Yes — zone separations read | Yes — seam detail reads | Seam placement calibrated for game-distance zone separation |

**Rule:** Any surface detail that only becomes visible when an asset is viewed at
greater than 2× game zoom is an *inspection-distance detail.* These are permitted
but are never the design priority. Allocate them after all game-distance reads are confirmed.

---

#### 5.4.3 Standard Monster Detail Budget

Standard monsters appear in swarms. The game may render 20–30 simultaneously. This
creates two constraints:

1. **Individual complexity must be near-zero at game distance.** At swarm density, the
   goal is a readable *mass*, not a collection of readable *individuals.* Individual
   Standard monsters need only: one clear silhouette shape, one body color zone, one
   specular catch. Three elements. Anything additional merges into noise at swarm density.

2. **The swarm read must be designed intentionally.** When 20 Standard monsters are
   placed in a rough grid at game distance, the aggregate silhouette — the "wave shape"
   — must read as a tide advancing, not a texture patch. This is a composition test, not
   a single-asset test. The single-asset silhouette is only correct if it tiles into a
   readable mass. Test by placing 15 instances at game-distance and confirming the
   aggregate reads as movement pressure, not visual noise.

**File budget for Standard monster sprites:** Maximum 64×64 px canvas for Standard
monster idle + approach animation frames. Walk cycle: 4 frames minimum, 6 frames maximum.
The animation must be readable as forward-movement at 24 px on-screen height.

---

#### 5.4.4 Boss Monster Detail Budget

Boss monsters are singular. In any wave, at most one Boss is present. They are the
highest visual-complexity entities in the game and the player will visually study them
more than any other monster type.

**Budget allocation for Boss assets:**

- Silhouette refinement: highest priority — the Boss silhouette drives all tactical
  decisions (hitbox perception, attack direction reading, safe zones)
- Material zone definition: second priority — three zones, each clearly distinct
  at game distance; the seams between zones are designed-for-distance
- Combat animation fidelity: third priority — Boss attack wind-ups are the primary
  skill-communication tool; they must be unambiguous
- Surface detail and texture: fourth priority — visible at inspection distance, adds
  richness in close-up screens

**File budget for Boss monster sprites:** 128×128 px canvas minimum. Multi-cell Bosses
at up to 192×192 px. Frame count: idle 6 frames, approach 6 frames, attack wind-up
4 frames (per attack type), attack release 3 frames, death 8 frames.

---

### 5.5 Tower–Hero Fusion Visual Language

> This section addresses the Tower-Synced Class System (Hero GDD Rules 13–18).
> As the hero accumulates proximity time near a given tower archetype, they earn
> that archetype's class tier. The visual design must communicate active class tier
> at a glance, without the player reading a UI label during wave action.

---

#### 5.5.1 Fusion Design Principles (All Archetypes)

**The three non-negotiable rules for all fusion states:**

1. **Fusion additions are additive details, not silhouette replacements.** The base
   warden-smith silhouette must be recognizable through all fusion states. A player who
   sees the hero at any fusion tier must identify it as the same hero. *This is the same
   rule as tower component upgrades — additive details, not silhouette replacements
   (Section 3.1.3 modular component note).*

2. **The 1.4:1 silhouette floor is maintained in all fusion states.** No fusion
   addition may add horizontal mass at the expense of vertical height. Fusion
   additions must be *vertical* (crown extensions, shoulder heights, elevated
   equipment) or *contained* (chest-plate modifications, grip changes that do not
   widen the bounding box) — never wide horizontal additions.

3. **Each fusion state must be distinguishable from all other fusion states** at game
   distance (approximately 48 px hero height on screen). Test by placing all four fusion
   heroes side-by-side at game distance and confirming a playtester can correctly name
   each archetype in under five seconds per figure.

**Color language for fusion states:**

| Tower Archetype | Fusion Accent Color | Accent Source |
|----------------|---------------------|--------------|
| Defensive | Fieldstone Grey `#7E8590` with high-contrast rim at Parchment Cream | Mass of constructed stone; fortress material |
| Damage Dealer | Sanctum Amber `#C8801A` shifting toward orange at high tier | Weapon heat and kinetic energy; the forge |
| Support | Scout Blue `#2D5F8A` at the secondary element register | Broadcast and reach; the sky register |
| Specialist | Desaturated warm-grey to cool-grey gradient; no primary palette color | The Specialist has no clean palette entry; its visual register is *ambiguity itself* |

---

#### 5.5.2 Defensive Fusion

**Archetype identity:** The hero has been standing near wall-towers and fortifications.
They have absorbed the language of mass, cover, and patience.

**Visual manifestation:**

A **stone-panel bracer system** grows over the hero's arms and chest in tiers.
At Tier 1 (first unlock), a single forearm bracer plate — oversized relative to the
leather underneath, clearly stone-derived rather than smithed metal. At Tier 2,
the bracer extends to the shoulder and a chest-panel appears, chamfered at the corners
(the Defensive tower's flat/crenellated grammar, translated to wearable scale).
At Tier 3, the chest-panel deepens and a matching leg-guard appears. At Tier 4, the
full stone-panel system covers the hero's dominant side — the side facing the primary
monster approach lane.

**Silhouette note:** Stone panels add depth to the body profile but must not add width.
The shoulder panel is high-mounted (sits above the shoulder line, contributing to the
vertical axis). The chest-panel is flat to the body — no protruding volumes.

**Color register:** Fieldstone Grey base, lightest faces reading toward Parchment Cream.
Surfaces are cut-stone texture at inspection distance; smooth weight-bearing mass at
game distance. The hero with Defensive fusion reads as *more substantial*, not wider.

**Design test:** The Defensive fusion hero's silhouette at game distance must read as
"heavily armored version of the same warden-smith" — not as a different character or
a knight archetype.

---

#### 5.5.3 Damage Dealer Fusion

**Archetype identity:** The hero has been fighting alongside weapon-towers — siege
cannons, archers' platforms, the directed killing machinery of the arsenal.

**Visual manifestation:**

A **firing-rig modification** grows from the hero's dominant-hand weapon toward
the shoulder. At Tier 1, the weapon gains an articulated brace — a stabilization
rod running from the grip to the forearm, the visual language of a siege weapon
adapted to person-scale. At Tier 2, the brace extends over the shoulder, and the
weapon's business end gains a narrow barrel extension (directional emphasis — the
Damage Dealer tower's "points up, shoots out" grammar at hero scale). At Tier 3,
a heat-management element appears: a wrapped coolant coil or vented channel on the
weapon body — the mark of a weapon that is used constantly and runs hot. At Tier 4,
the shoulder extension carries a small secondary firing element — not a second
weapon, but a support mechanism (ammunition feed, targeting scope, ballistic assist)
that reads as unified with the primary weapon.

**Silhouette note:** The vertical axis is reinforced by the barrel extension — it
contributes to the hero's upward silhouette rather than widening it. The over-shoulder
element must stay within the hero's existing width bounding box (viewed from the
oblique play angle).

**Color register:** The Tier 4 firing rig reads in Sanctum Amber `#C8801A` at the
heated surfaces. Non-heated structural surfaces read in dark steel-grey (a darker
version of Fieldstone Grey `#7E8590`). At combat distance, crit events produce
Herald Gold `#F5C01A` flash at the barrel tip — this VFX is a runtime event, not
a static surface property.

**Design test:** The Damage Dealer fusion hero's dominant silhouette feature must be
the barrel extension rising above the shoulder crown. If the hero's helmet crown is
still the highest point in the figure, the barrel extension needs to be lengthened
or elevated. "Points up" is mandatory.

---

#### 5.5.4 Support Fusion

**Archetype identity:** The hero has been operating near buffer-towers — the outward-
reaching, broadcasting architecture of the Support archetype.

**Visual manifestation:**

A **resonance frame** extends from the hero's non-dominant arm and chest. At Tier 1,
a single extended forearm brace with an open-arc terminal — the same open-negative-space
grammar as the Support tower's arch silhouette, worn on the body. At Tier 2, the arc
becomes a full open-ring at shoulder height on the non-dominant side — a halo-ring
element extending above the shoulder, reading as a transmission form. At Tier 3, the
ring carries faint Scout Blue `#2D5F8A` luminance — not a glow effect, but a surface
that reacts to ambient light with a slight cool-blue cast. At Tier 4, a second partial
arc appears on the dominant side at hip height — the full frame reads as a structured
broadcast field, open in all directions.

**Silhouette note:** The shoulder-height ring at Tier 2 and above contributes to
the vertical silhouette. The ring must extend above the hero's existing crown height
and be narrow at its lateral extent — it is a ring, not a disc. The negative space
inside the ring is intentional (30% negative space minimum — the same rule as the
Support tower's open silhouette, applied here).

**Color register:** The resonance frame surface is smooth and slightly translucent at
inspection distance. At game distance, it reads as the lightest element on the hero's
silhouette, catching the rim light fully.

**Design test:** The Support fusion hero must have an immediately recognizable
"open, outward-reaching" visual signature that distinguishes it from the contained,
weighted Defensive fusion and the upward-pointing Damage Dealer fusion. If two out
of five playtesters confuse Support with any other fusion state, the open-arc element
needs to be more prominent.

---

#### 5.5.5 Specialist Fusion

**Archetype identity:** The hero has been working alongside the irregular, compound
machinery of Specialist towers — the status-effect mechanisms, the slowing fields,
the oddly-configured control architectures.

**Visual manifestation:**

A **compound auxiliary system** develops at the hero's back and shoulder, extending
partially into view from the oblique play angle. At Tier 1, a secondary carrying
frame appears — a backpack-architecture of angular and organic mixed forms, visible
over the shoulder silhouette. At Tier 2, a disc or ring element mounts on the
carrying frame at mid-height — rotating very slowly in idle, stationary during
combat. At Tier 3, a secondary extended arm emerges from the frame — an active
manipulation instrument (the equivalent of a control interface for the Specialist
tower's field effects). The arm is articulated with two joints. At Tier 4, the
system reads as fully developed: frame, disc, arm, and a small reservoir element
that pulses with muted warm light — suggesting fuel or a reagent, not magic.

**Silhouette note:** The Specialist fusion system extends behind and above the hero's
shoulder line. At the oblique play angle, it adds mass to the hero's upper-right
quadrant (or upper-left, depending on facing). The width of the system must fit within
the hero's bounding box when viewed from the primary facing direction.

**Color register:** Warm desaturated grey base — neither Fieldstone Grey nor the
hero's leather. No primary palette accent color. The Specialist fusion intentionally
has no clean color identity. The only color event is the Tier 4 reservoir pulse:
a muted warm amber glow, approximately 50% the saturation of Sanctum Amber,
pulsing at a 3-second cycle — slow enough to be ambient, not urgent.

**Design test:** The Specialist fusion hero must read as *more complex and less
categorizable* than all other fusion states. An immediately correct response from
any playtester should be "I don't know what that does, but it looks capable." If the
response is categorically confident ("that's a tank" or "that's a healer"), the
compound design is not sufficiently hybrid.

---

### 5.6 Quick Reference — Character Design Rules

| Rule | Constraint | Section | Pillar |
|------|-----------|---------|--------|
| Hero archetype | Warden-smith: maker + sentinel, specific craft materials | 5.1.1 | P2 |
| Hero aspect ratio | 1.8:1 target, 1.4:1 floor — no idle frame violates this | 5.1.2 | P2 |
| Hero crown | Point or rounded dome — never flat | 5.1.2 | P2 |
| Hero material | Hardened leather / hammered plate / wrapped grip | 5.1.3 | P2 |
| Hero skin | Parchment Cream lightest value — minimal exposed area | 5.1.3 | P3 |
| Hero expression | Composed stoicism — weight-forward, controlled effort | 5.1.4 | P1 |
| Monster aesthetic | Intrusions — organic, ecological, grown not built | 5.2.1 | P2 |
| Standard silhouette | Wider than tall, no protrusion above midline | 5.2.2 | P3 |
| Standard complexity | 3 surface zones maximum at game distance | 5.2.2 | P3 |
| Standard canvas | 64×64 px, 4–6 walk frames | 5.4.3 | P3 |
| Elite protrusion | One asymmetric protrusion — never two at equal weight | 5.2.3 | P3 |
| Elite secondary material | One of three specified secondary materials only | 5.2.3 | P3 |
| Boss material zones | Three zones, seams calibrated for game-distance separation | 5.2.4 | P3 |
| Boss canvas | 128×128 px minimum, up to 192×192 px | 5.4.4 | P3 |
| Monster constraint | No constructed geometry (straight edges, right angles) | 5.2.5 | P1 |
| Monster constraint | Every design has a real-world ecological analogue | 5.2.5 | P2 |
| Monster constraint | No humanoid warrior silhouettes | 5.2.5 | P2 |
| Hero idle budget | Bounding box center moves max 4 px per cycle | 5.3.2 | P2 |
| Fusion rule | Additive detail — base warden-smith always recognizable | 5.5.1 | P2 |
| Fusion floor | 1.4:1 silhouette maintained in all fusion states | 5.5.1 | P2 |
| Defensive fusion | Stone-panel bracer system — depth, not width | 5.5.2 | P1 |
| Damage Dealer fusion | Firing-rig over shoulder — barrel extension highest point | 5.5.3 | P3 |
| Support fusion | Open resonance ring above crown — 30% negative space | 5.5.4 | P3 |
| Specialist fusion | Compound auxiliary system — no clean color identity | 5.5.5 | P3 |

---

## Section 6: Environment Design Language

> This section briefs the environment and level artist. All rules are prescriptive
> constraints, not aspirational guidelines. An outsourcing artist should be able to
> produce a compliant asset or layout tile without additional direction beyond this
> section and Sections 3–4.
>
> **Binding dependencies:** Section 3 (Shape Language) defines all geometry proportions
> and height rules. Section 4 (Color System) defines all palette values and semantic
> restrictions. This section does not repeat those rules — it extends them with
> environment-specific application.

---

### 6.1 Architectural Style and World Culture

#### 6.1.1 The Sanctuary — Cultural Identity

*Pillar: The Living Sanctuary*

The Sanctuary does not belong to an empire or a civic authority. It belongs to one person.
Its architectural language is **accumulated personal practice**, not designed civic grandeur.
Think of a master craftsperson who has spent thirty years adding to, repairing, and
incrementally expanding a working space. The result is an architecture of *layered
decisions*, not a blueprint realized in full.

**Cultural identity rules:**

- **Material philosophy is honest and functional first.** Stone is chosen because it
  lasts and is locally available. Wood is chosen for workbenches, shelves, and doors
  because it is workable. Metal appears only as fixtures — hinges, torch brackets,
  window grilles — not as a primary structural material. No material has been applied
  decoratively if an honest material would serve.

- **The structure is older than the current occupant knows how to count.** There are
  at least two visible construction phases in any Sanctuary elevation — an older, heavier
  base course of rougher stone with larger block dimensions, and a later addition with
  more refined chamfering and tighter joinery. The older phase shows through in the
  foundations, the lower third of walls, and any embedded arch or lintel that pre-dates
  the room around it.

- **The Sanctuary has been maintained, not restored.** Maintenance is visible: repointed
  mortar joints in a different color than the original, a door frame that has been shimmed
  level with a wedge of wood, iron brackets that are newer and brighter against oxidized
  stone. Restoration implies wealth and institutional intent. Maintenance implies personal
  care over long time.

- **Scale communicates mastery, not power.** The space is not large. The correct cultural
  register is a *tower-workshop* or *fortified herbarium*: defensive enough to survive,
  domestic enough to live in, idiosyncratic enough to have grown organically.

#### 6.1.2 The Mission Field — Cultural Identity

The Mission Field shows signs of prior occupation, old boundary markers, stone pathways
worn smooth from use. The threat comes *through* a landscape that has history.

**Mission Field identity rules:**

- **The terrain has been traveled before.** Path cells are worn, not cleared. The stone
  or packed earth of the path shows the compression and smoothing of many footsteps —
  not a road surface deliberately laid, but a desire-line hardened over time.

- **There are remnants of prior defenses.** Broken stone posts, collapsed low walls,
  scorch marks on rock faces. These are environmental storytelling props, not interactive
  objects, and they are always behind the player — never between the spawn edge and the
  Sanctuary.

- **The spawn edge is not natural wilderness.** The far edge from which enemies emerge
  has a specific visual character: the terrain is rougher, the ground is disturbed, and
  the stone is unworn. This is not a well-traveled approach. This is where something is
  arriving from outside.

#### 6.1.3 Sanctuary vs. Mission Field — Distinguishing Rules

| Property | Sanctuary | Mission Field |
|---|---|---|
| Ground material | Flagstone, worked earth, tiled floor | Compacted earth, worn stone path, field grass |
| Wall/border presence | Walls on all sides with apertures (doors, windows) | Open edges, low remnant walls only |
| Construction intent | Deliberate, personal, accumulated | Incidental, weathered, contested |
| Prop intention | Every prop is placed by the inhabitant | Terrain features are placed by time and use |
| Color temperature | Interior amber lantern dominant | Exterior sky light dominant — shifts by game state |
| Ambient vertical elements | High — the Sanctuary reads tall from oblique angle | Deliberately low — towers must dominate verticals |

#### 6.1.4 Forbidden Architectural Features

The following forms break the diorama register and are explicitly prohibited regardless
of aesthetic justification:

- **Perfect, uniform coursing on large stone surfaces.** Real hand-laid stone has
  variation in joint width and block height. If a wall surface shows perfectly regular
  courses at 512px scale, re-introduce variation at minimum 20% size deviation across
  block courses.

- **Exposed, unworked concrete or poured-surface geometry.** No smooth featureless
  poured surfaces. Even where smooth plaster or render is appropriate (interior surfaces,
  fill between stones), it must show the evidence of being applied by hand — brush marks,
  slight thickness variation, hairline settling cracks.

- **Thin, planar walls without thickness.** Every wall element must show its depth at
  the oblique viewing angle. A wall that reads as a flat plane rather than a solid mass
  fails Principle 1. Minimum visible wall thickness: 12px at the standard play angle.

- **Industrial repetition in ornamental detail.** Decorative carved elements (capitals,
  corbels, carved edging) must not be tile-stamped identically. Each instance in a row
  must have at minimum one micro-variation: a chipped corner, a slightly different depth,
  a small staining difference.

- **Modernist or brutalist rectilinear shapes.** A featureless rectangular prism, a flat
  roof without a parapet, a building without chamfer or detailing.

- **Symmetrical facade elevations.** No building face should be mirror-perfect. The
  principal entrance may be centered, but flanking elements must differ by at least one
  detail on each side.

- **Glass or any material that reads as industrially processed.** Window apertures use
  iron grilles, wooden shutters, or oiled cloth — materials consistent with pre-industrial
  craft.

---

### 6.2 Texture Philosophy

#### 6.2.1 The Stylized-Painterly Approach

*Pillar: Scale Reads as Precious, Not Epic*

This game uses **stylized painterly textures**, not photorealistic PBR and not flat
cell-shading. The distinction is specific:

- **Not PBR:** PBR at small sprite scale produces muddy, over-detailed surfaces that read
  as miniatures photographed rather than miniatures painted. PBR roughness and metallic
  maps are replaced with painted highlight and shadow baked directly into the diffuse/albedo
  texture at a consistent light angle.

- **Not flat cell-shading:** Cell-shading lacks the granular surface noise that makes
  materials feel physical and old. The target is a surface that a viewer could plausibly
  have painted by hand with small brushes — visible texture at close inspection, reading
  as a clean material at game distance.

- **The painted-miniature register:** Reference mental model is hand-painted resin
  miniature work (15–28mm scale) where painted highlights, washes into recesses, and edge
  highlights are all explicit brush choices. Worn edges are lighter. Recesses are darker.
  Surfaces that catch ambient light are warmer than surfaces that face away.

**Design test:** Print a texture tile at 3× scale and look at it from arm's length. If
it reads as "painted by hand," it passes. If it reads as "photographed" or "procedurally
generated," revise toward painterly clarity.

#### 6.2.2 Light Direction in Textures

All environment textures use a **consistent baked light direction**: light arrives from
upper-left at approximately 45° from horizontal, consistent with the oblique play angle.
This direction matches the warm key light defined in Section 2.2.

- Surfaces facing upper-left: lightest value, warmest color temperature within material range
- Surfaces facing lower-right: darkest value, coolest color temperature within material range
- Top surfaces (visible horizontal faces at oblique angle): mid-value, slightly warm

**This direction is non-negotiable.** A texture with reversed baked lighting will visually
invert under the scene's directional light. Any asset submitted with light baked from the
wrong angle must be re-lit before integration.

#### 6.2.3 Core Material Library

---

##### Stone — Primary

**Type:** Worked and chamfered building stone; not quarried-raw and not polished-marble.

**Color range:** Primarily Fieldstone Grey (`#7E8590`) at mid-value, with warm Sanctum Amber
cast into shadowed joints and cool Scout Blue in deepest recesses. Block faces lighten to
near-Parchment Cream on their upper-left highlight face.

**Surface texture at play distance:** Reads as slightly rough, matte stone with visible block
joints. What must read: joint lines between blocks, slight height variation of block faces,
and the chamfered edge highlight.

**Aging indicators:** Mortar discoloration (slightly warmer than the stone, yellowed at
edges), chip marks at exposed corners (lighter than block face), occasional dark staining
from water runoff along vertical joints. Moss and lichen permitted at base course only.

---

##### Stone — Path Surface

**Type:** Worn compacted earth or flat flagstone worn smooth from foot traffic.

**Color range:** Fieldstone Grey at 80% of primary stone value, slightly warmer (pushed
toward Sanctum Amber family at 15% mix) — path stone is compressed and slightly
organic-tinted from soil contact.

**Surface at play distance:** Flat. The path must read as horizontal and unobstructed at
all times. Any surface variation is painted value-shift only — no 3D depth to texture
sprites on path surfaces.

**Forbidden:** Raised stone edges, texture bumps, or height-variation sprites on path
cells. Path cells are 0–8px sprite height maximum.

---

##### Stone — Sanctuary Interior Floor

**Type:** Flagstone laid floor, aged but maintained, with irregular joint widths.

**Color range:** Sanctum Amber at 50–60% value as the primary floor color, with Parchment
Cream highlight on flat-face centers, and deep Fieldstone Grey in joints. The floor reads
warmer than Mission Field stone because the Sanctuary interior is always amber-lit.

**Surface at play distance:** Mostly flat with clearly legible joint pattern. The joint
pattern is the primary readable detail — use irregular flagstone shapes (not a grid) to
reinforce the "old laid floor" read.

---

##### Wood

**Type:** Aged, worked wood — doors, shelves, workbenches, beam ends, window frames,
and furniture. Not raw timber and not lacquered finished wood.

**Color range:** Warm mid-brown, approximately Sanctum Amber at 40% saturation and 35–45%
value. Wood that has been well-used darkens at contact points and lightens at exposed
grain and split-end surfaces.

**Surface at play distance:** Grain direction must be visible as brushed directional value
variation running along the length of boards. The grain direction anchors the viewer's eye
to the material identity.

**Aging indicators:** End-grain darker than face-grain. Raised grain on older flat boards.
Darkened handle zones and worn edges. Iron fittings leave rust staining around bolt holes.

---

##### Metal — Fixtures Only

**Type:** Iron and beaten copper. Not bright polished steel; not gold plate. Functional
craft metal.

**Color range:** Iron: Fieldstone Grey at 40% value, with sharp Parchment Cream specular
highlights on any edge or surface catching the key light. Copper: warm orange-brown,
Sanctum Amber family shifted toward orange at 30–40% saturation, darkening to near-black
at recesses.

**Surface at play distance:** Most legible by sharp edge highlights and dark body tone.
Invest in the edge highlight; do not over-texture the body.

**Aging indicators:** Iron oxidizes toward dark red-brown in recesses. Copper develops
verdigris at joints and recesses — a desaturated blue-green note (below 20% saturation,
distinguishable from Verdant Green semantic color).

**Forbidden:** Bright, polished, mirror-reflective metal. No chrome, no mirror-finish iron.

---

##### Earth and Soil

**Type:** Compacted field earth at path margins, root-disturbed soil at base of Sanctuary
walls, bare ground in spawn area.

**Color range:** Dark warm brown, Sanctum Amber family shifted toward brown-grey at 20–25%
saturation. Drier surface earth lightens toward Fieldstone Grey mid-value.

**Surface at play distance:** Coarseness relative to stone is the primary read — earth has
no straight edges or clear joints, and its value variation is random and organic rather
than structured.

---

##### Fabric and Cloth

**Type:** Banners, covers over stored equipment, worn canvas bags, and hanging textile
props in the Sanctuary. Not decorative tournament fabrics — working fabric.

**Color range:** Sanctum Amber family for warm-toned cloth. Neutral undyed cloth uses
Parchment Cream at 60% saturation. No bright saturated fabric colors — cloth in this world
has aged and faded.

**Forbidden:** Bright-saturated, clean-new-looking fabric. No vivid reds, blues, or greens
on cloth props — these colors carry semantic meaning in the color vocabulary and fabric must
not compete.

---

#### 6.2.4 Material Reinforcement of the Hand-Crafted Register

All materials must pass this test before approval: **could this surface plausibly have
been created by one craftsperson working alone, with pre-industrial tools and materials
available to them?**

- Stone that reads as laser-cut: wrong register
- Wood that reads as machine-planed and finished: wrong register
- Metal that reads as cast and polished in a factory: wrong register

The correct register is always **functional, honest, and slightly imperfect.** Imperfection
must be visible as a feature, not hidden as a quality control failure.

---

### 6.3 Prop Density Rules

#### 6.3.1 Philosophy — Density Serves Readability First, Story Second

*Pillar: Strategic Mastery*

Every prop that appears in the scene is below all three visual hierarchy reads from
Section 3.4: Hero first, Active Threat second, Towers third. The density scale for
this game runs from "surveyed" to "accumulated" — it never reaches "cluttered."

- The Mission Field is always surveyed — tactical clarity is survival
- The Sanctuary is always accumulated — evidence of a lived practice

#### 6.3.2 Sanctuary Interior — Density Target: Accumulated

**Rules:**

- **Maximum one prop per 32×32px working area on non-functional surfaces.** Functional
  surfaces (workbenches, shelves) may be denser. Circulation paths and bare wall sections
  must remain at lower density so the space reads as livable.

- **Prop height variation is mandatory.** No two adjacent props in the same 64px zone
  may have the same visual height.

- **Every prop cluster must have a visual anchor** — the largest or most prominent prop
  that defines the cluster's purpose.

- **Three prop categories must be represented in any Sanctuary room view:**
  1. **Work props** — objects in active use or recently used (open books, tools laid out,
     material in progress)
  2. **Archive props** — completed work, trophies, or stored materials (filled shelves,
     sealed containers, hung trophies)
  3. **Maintenance props** — evidence of upkeep (candles, oil flasks, cleaning implements,
     a repair kit near a damaged item)

**Design test:** Remove all work props from the scene. If it still reads as a working
space, work prop density is too low. The space must feel actively occupied, not museumized.

#### 6.3.3 Mission Field — Path Cells — Density Target: Legible

- **Maximum sprite height 8px on path cells** — hard limit from Section 3.2
- **No prop interrupts the path silhouette.** Even below 8px, a prop that could visually
  merge with a low-tier monster sprite is wrong
- **Ground texture variation is the only permitted density tool on path cells**
- **Maximum one incidental detail prop per 3-cell path length** — not per cell

#### 6.3.4 Mission Field — Non-Path Cells — Density Target: Composed

- **Maximum prop height: 50% of the base tower height** for that archetype family in
  the cell — non-negotiable from Section 3.2
- **Alternate prop heights between all adjacent non-path cells.** The "no two adjacent
  cells at same height" rule from Section 3.2 applies to props as well as terrain geometry
- **Density progression from path edge to grid edge:** cells directly adjacent to path
  have the lowest density; cells at the grid boundary may have higher density
- **The non-path cell prop silhouette must always be narrower than a tower base**

#### 6.3.5 Spawn Area — Density Target: Exposed

- **3–5 props per spawn zone maximum** — raw and unwelcoming but not barren
- **Permitted spawn area props:** damaged stone markers or totems (leaning, cracked,
  partially toppled), ground disturbance (churned earth, displaced stones), dark staining
  on rock surfaces. No organic growth.
- **Props must be positioned at the spawn area's outer edge** — they frame the zone
  without sitting between the spawn point and the camera's first view of a spawning monster
- **No prop may cast a shadow onto the spawn trigger zone**

#### 6.3.6 Core Props vs. Accent Props

**Core props** repeat freely — players learn to read them as tactically neutral:

| Category | Core Props |
|---|---|
| Sanctuary | Stone shelves, wood crates, torch brackets, iron-banded barrels, open books, flagstone sections |
| Mission Field | Broken stone posts, compacted-earth ground tiles, field grass tufts (max 8px height), worn path marker stones |
| Spawn Area | Disrupted earth tiles, cracked stone boundary markers |

**Accent props** are placed once or twice per scene — must not repeat more than twice in
any single mission view:

| Category | Accent Props |
|---|---|
| Sanctuary | Trophy display (player history-specific), a specific crafted artifact on a pedestal, a map table with marked positions |
| Mission Field | A collapsed old defensive structure remnant, an unusually large embedded boulder, a scorched ground zone from a prior battle |
| Spawn Area | One distinctive damage-marked stone (landmark for "here the enemy came from") |

**Design test:** Count the accent props visible at once. If the total exceeds four, remove
the least narratively specific ones first.

---

### 6.4 Environmental Storytelling Guidelines

#### 6.4.1 Story Without Text — Specific Examples

*Pillar: The Living Sanctuary*

Environmental storytelling in this game communicates three narrative threads: the hero's
history and mastery, the escalating external threat, and the passage of waves within a
mission. No story is told through text labels on props — entirely through placement,
condition, and visual context.

**Sanctuary examples — the hero's history:**

1. **A trophy shelf with items of different ages.** The oldest items show more weathering,
   darker color value, and cruder craftsmanship. The trophy closest to the center of the
   shelf is the most recent and most refined. No label needed — the progression reads
   left-to-right by material quality alone.

2. **Repair evidence on the primary structure.** The outer Sanctuary wall closest to the
   mission field has one visible repair section — different-colored mortar, slightly
   different stone size, newer chamfering. This tells the player the Sanctuary has been
   attacked before and survived. Place it at the second height level, visible from the
   oblique play angle.

3. **An unfinished project.** One workbench surface has materials mid-assembly: components
   laid out, an unfilled mold, tools positioned around an incomplete object. The Sanctuary
   is not a trophy room — it is an active laboratory.

**Mission Field examples — the contested space:**

1. **Worn stone markers at grid boundaries.** At the mission field's side edges, old stone
   boundary posts lean at slight angles — not collapsed, but no longer upright. They were
   erected when this space was orderly. The lean communicates slow displacement without
   requiring a collapse.

2. **Ground disturbance at the spawn edge.** The path material in the final two cells before
   the spawn trigger zone shows compaction and disruption — darker, churned earth, displaced
   edge stones. The ground shows that many heavy things have passed through here recently.

#### 6.4.2 Wave-Passage Variant System

For each mission, define three visual states for key environmental props:

| State | Trigger | Visual Change |
|---|---|---|
| Pristine | Before Wave 1 | Full-value, upright, no disruption marks |
| Used | After Wave 1–3 | 10–15% darker on worn surfaces, one displacement per prop |
| Marked | After Wave 4+ | Scorch or impact marks, one structural shift per prop |

These are variant sprite states (`prop_post_upright.png` → `prop_post_lean.png` →
`prop_post_toppled.png`) triggered by wave count. The Sanctuary interior props do not
change state during combat — only exterior props respond to wave count. Interior props
respond only to MISSION_COMPLETE (trophy shelf gains new item) or DEFEAT (unfinished
project remains unfinished).

#### 6.4.3 Forbidden Environmental Storytelling

- **Props that cast shadows onto path cells** — narrative shadow never worth the
  readability cost of partially occluding monster ground contact
- **Props tinted with semantic colors (green, red, gold, purple) for non-semantic
  decorative purposes** — a flowering red vine on a Sanctuary wall introduces ambiguous
  threat-signal red; all decorative use of semantic colors requires explicit review against
  Section 4.2
- **Props that move or animate as ambient decoration on the Mission Field during
  WAVE_ACTIVE** — ambient prop animation must pause or hold during WAVE_ACTIVE
- **Text, signage, or symbols on environmental props that require reading** — all
  environmental storytelling must operate through shape, condition, position, and color
  value alone

---

### 6.5 Spatial Hierarchy — The Two Spaces

#### 6.5.1 The Sanctuary — "Mine"

*Pillar: The Living Sanctuary*

The Sanctuary communicates ownership through four visual qualities the Mission Field does
not share:

1. **Enclosure.** The Sanctuary has defined edges on all visible sides — walls, structures,
   clear architectural boundaries. Everything visible is inside the container of a built place.

2. **Vertical complexity.** The Sanctuary uses all three height levels defined in Section 3.2.
   This vertical layering is dense relative to the Mission Field's deliberately flattened terrain.

3. **Interior light character.** The Sanctuary is always amber-lit from within (Section 2.2).
   Even in SCOUT state (cool ambient light), interior lanterns and forge provide warm local
   light that distinguishes the interior as warm-colored against a cooler sky.

4. **Evidence of a single occupant's taste.** Prop placement is not symmetrical, not civic,
   and not institutional — the arrangement of someone who knows exactly what they need where.
   Achieved by: irregular prop spacing, trophy positions following personal meaning, one
   visible improvised solution per room.

#### 6.5.2 The Mission Field — "Contested"

The Mission Field communicates openness, exposure, and the absence of settled ownership
through four visual qualities:

1. **Open edges.** The grid boundary in the direction of the spawn reads as the edge of
   known space. Props at the grid edge frame the boundary but do not form a wall.

2. **Vertical suppression.** All non-path terrain is kept flat and low. The visual horizon
   of the Mission Field is the tower tops and the Hero, not terrain or props.

3. **Exterior light character.** The Mission Field is always sky-lit — no internal light
   sources exist except tower VFX effects during WAVE_ACTIVE. No lanterns, no forges.

4. **No personal accumulation.** Mission Field props are the result of time and use, not
   curation. They are not arranged for any occupant's convenience.

#### 6.5.3 Shared Visual Elements — Bridging the Two Spaces

- **Shared stone material.** The primary stone of the Sanctuary walls uses the same
  Fieldstone Grey color family as the Mission Field's path surface and terrain.
- **Shared chamfer grammar.** Built objects in both spaces use the chamfered-edge language
  from Section 3.2 — they were carved by the same material culture.
- **The path as connective tissue.** At the point where the path meets the Sanctuary
  boundary, material transitions from worn compacted earth to laid flagstone — a clear
  threshold that reads as "you are entering a maintained space." This threshold is always
  visible at the Sanctuary edge of the grid.
- **Verdant Green at low saturation in both spaces.** Sanctuary garden at max 70%
  saturation; path-margin vegetation on Mission Field at max 50% saturation.

#### 6.5.4 The Transition Between Spaces

When the player transitions from Sanctuary hub to Mission Field at SCOUT onset:

1. **Lighting state** (dominant signal): Amber interior → cool overcast exterior.
   Perceptible in a single frame comparison. Any gradual blend must complete within
   0.5 seconds of the transition event.

2. **Vertical density:** The Sanctuary's full vertical complexity is replaced by the
   Mission Field's flat, tower-dominated spatial register.

3. **Sound-environment alignment:** (Coordinate with audio-director.) The ambient audio
   moving from enclosed interior reverb to open exterior must land at the same moment
   the lighting completes its transition. The lighting transition is the pacing reference.

**The transition must not feel like a loading screen.** If the transition is a cut,
the first frame of the Mission Field must already be fully composed and correctly lit.

---

### 6.6 Game-State Environment Rules — Quick Reference

| State | Environment Character | Prop Behavior | Ground Read |
|---|---|---|---|
| **SANCTUARY** | Warm amber interior, enclosed, dense accumulated props | All props at full value and saturation | Flagstone flooring, warm interior cast shadows |
| **SCOUT** | Cool overcast exterior, open field, pristine condition | Props at Pristine variant | Path reads clean |
| **WAVE_ACTIVE** | Split-lit dramatic exterior, all ambient prop animation paused | Props locked — no variant changes during wave | Path occupied by moving enemies; ground texture subordinated to monster contact shadows |
| **INTERMISSION** | Transitional warm exterior, scattered disruption marks advancing | Wave-wear variant advances one increment | Scorch and displacement marks appear at forward zone |
| **MISSION_COMPLETE** | Golden-hour exterior, maximum accumulated wear for this mission | Trophy shelf gains new item in Sanctuary view | Path empty; ground reads settled under long warm shadows |
| **DEFEAT** | Cool-neutral exterior, 60–70% saturation | Sanctuary anchor prop remains full saturation; field props desaturate with scene | Path reads empty and still; disruption marks visible but muted |

---

### 6.7 Environment Rule Summary

| Rule | One-Line | Source |
|---|---|---|
| Sanctuary material philosophy | Honest, functional, hand-maintained — two visible construction phases | 6.1.1 |
| Mission Field material | Traveled, contested, pre-existing — not designed | 6.1.2 |
| Forbidden architecture | No perfect coursing, no thin walls, no industrial ornament, no symmetry | 6.1.4 |
| Texture approach | Stylized painterly — baked light, hand-crafted register | 6.2.1 |
| Light bake direction | Upper-left key, 45° — consistent across all assets | 6.2.2 |
| Material imperfection | Must be visible at arm's length — not a note, a feature | 6.2.4 |
| Sanctuary density | Purposeful accumulation — work, archive, and maintenance props all present | 6.3.2 |
| Path cell density | 8px max height — no obstructed monster movement | 6.3.3 |
| Non-path cell density | 50% tower height max — alternate heights between adjacent cells | 6.3.4 |
| Spawn area density | 3–5 props max — no shadows on spawn trigger zone | 6.3.5 |
| Storytelling via props | Three threads: hero history, threat escalation, wave passage | 6.4.1 |
| Wave variant system | Pristine → Used → Marked triggered by wave count | 6.4.2 |
| Forbidden storytelling | No semantic-color decoration, no WAVE_ACTIVE ambient animation, no text on props | 6.4.3 |
| Sanctuary = mine | Enclosure, vertical complexity, interior light, personal curation | 6.5.1 |
| Mission Field = contested | Open edges, vertical suppression, sky light, no personal accumulation | 6.5.2 |
| Bridge elements | Shared stone material + chamfer grammar + path threshold + Verdant Green family | 6.5.3 |
| Space transition | Lighting change is primary signal; must complete within 0.5 s | 6.5.4 |

---

## Section 7: UI/HUD Visual Direction

[To be designed]

---

## Section 8: Asset Standards

[To be designed]

---

## Section 9: Reference Direction

[To be designed]

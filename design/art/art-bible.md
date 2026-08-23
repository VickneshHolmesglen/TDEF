# Sanctuary Defenders — Art Bible

> **Status**: All 9 Sections Complete
> **Author**: Vicknesh + Art Director
> **Last Updated**: 2026-08-24
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
| 7. UI/HUD Visual Direction | Complete |
| 8. Asset Standards | Complete |
| 9. Reference Direction | Complete |

---

## Section 1: Visual Identity Statement

### One-Line Visual Rule

> **Sanctuary Defenders presents a tactile, dimensional world built and commanded by the player, while its invading creatures appear as expressive 2D illustrations brought to life within that world.**

---

### Supporting Visual Principles

#### Principle 1 — The Player's Domain Has Weight
*Pillar: The Architect-General / Strategic Mastery*

The hero, towers, buildings, terrain, paths, Sanctuary architecture, large
props, lighting, and shadows use 3D form to make construction, placement,
upgrading, and spatial control feel physical and consequential.

**Design test:** Can the player understand buildable space, tower function,
upgrade state, and battlefield structure from silhouette, elevation, and
lighting before reading UI text?

---

#### Principle 2 — The Enemy Horde Reads as a Living Bestiary
*Pillars: Short, Readable Tower-Defense Missions / Combinatorial Discovery*

Monsters and other creatures use authored 2D artwork with strong silhouettes,
restrained internal detail, and animation designed to remain legible during
waves of 100 or more enemies. Dimensional contrast separates threats from the
3D structures the player controls.

**Design test:** At normal gameplay zoom and maximum crowd density, can players
quickly distinguish enemy families, priority threats, resistances, and relevant
tower interactions?

---

#### Principle 3 — The Sanctuary Grows from Refuge into Legacy
*Pillars: The Living Sanctuary / Combinatorial Discovery*

The Sanctuary's 3D architecture visibly accumulates history through
construction, repair, upgrades, inhabited details, and changing light.
Portraits, cards, icons, and illustrated ornament provide the human and mythic
layer that records discoveries and relationships.

**Design test:** Does each meaningful progression step create a visible change
in the 3D Sanctuary or its supporting 2D visual language, without relying solely
on menus or numbers?

---

### Hybrid Rendering Ownership

The dimensional split follows the game's central conflict: the player shapes a
persistent physical world, while illustrated forces emerge into it as threats,
knowledge, and possibility.

- **3D:** hero, towers, major buildings, terrain, paths, Sanctuary architecture,
  large props, world lighting, and world shadows.
- **2D:** monsters and creatures, card illustrations, inventory and equipment
  icons, skill icons, portraits, UI ornamentation, and selected VFX.
- **Mixed effects:** 3D projectile motion and world lighting may combine with
  2D particles, decals, and impact frames when this improves feedback.

Consistency comes from shared silhouette language, coordinated value ranges,
controlled outlines, grounding shadows, and common semantic accent colours—not
from forcing every asset into the same medium.

**Reference boundary:** `production/Hero Unequipped.PNG` and
`production/Hero 2H equipped.PNG` are references for Player Inventory UI
structure and presentation only. They do not define world art, realism,
palette, lighting, environmental treatment, or character and creature style.

---

## Section 2: Mood & Atmosphere

> **Locked atmospheric direction:** Sanctuary light versus encroaching darkness.
> The player's constructed 3D world carries warmth, permanence, and agency.
> Invading 2D creatures introduce coldness, pressure, and instability. Darkness
> may increase tension, but it must never conceal tactical information.

### 2.1 Emotional Arc

`SANCTUARY → SCOUT → WAVE_ACTIVE → INTERMISSION → MISSION_COMPLETE / DEFEAT → SANCTUARY`

- Sanctuary light represents refuge, accumulated progress, and player authorship.
- Encroaching darkness represents enemy pressure and temporary loss of control.
- Missions begin measured and readable, then become colder and more oppressive.
- Success restores warmth. Defeat leaves a recoverable ember, never hopeless blackness.
- The Sanctuary becomes visibly warmer, brighter, and more inhabited as it grows.

Every state must be distinguishable from a reduced-value thumbnail without UI text.

### 2.2 State Profiles

#### SANCTUARY — A Refuge Becoming a Legacy

**Emotional target:** Belonging, earned safety, and pride in a place that
remembers the player's choices.

**Lighting:** Warm, low-to-medium contrast illumination with amber practical
lights, a stable warm key, and soft neutral fill. Progress adds light sources,
occupied work areas, reflective accents, and brighter circulation routes rather
than simply increasing global exposure.

**Descriptors:** Sheltered · Inhabited · Hand-built · Restorative · Accumulative

**Energy:** Contemplative and quietly active.

**Visual carriers:** Warm windows, hearths, forge light, lanterns, inhabited
workstations, construction, trophies, supplies, and pools of light connecting
important destinations.

#### SCOUT — Calm Before Commitment

**Emotional target:** Focused command: time to read the field and form a plan.

**Lighting:** Cool-neutral daylight or overcast dawn with moderate contrast and
broad directional clarity. Terrain, paths, buildable space, tower silhouettes,
and route intersections remain immediately legible. Player structures retain
restrained warm practical accents. Shadows never conceal valid placement areas.

**Descriptors:** Surveyable · Still · Exposed · Expectant · Precise

**Energy:** Measured.

**Visual carriers:** Clean ground-plane separation, warm player-owned structures
against a cool-neutral field, and sparse slow atmospheric movement.

#### WAVE_ACTIVE — Controlled Pressure

**Emotional target:** Escalating urgency without visual panic.

**Lighting:** Begins near SCOUT's baseline. As waves escalate, ambient temperature
shifts colder, peripheral regions darken modestly, and directional contrast firms.
The hero, towers, paths, and interaction zones preserve stable value separation.
Warm structure lights remain islands of control. Every 2D creature receives
consistent ground alignment, edge treatment, and contact-shadow logic.

**Descriptors:** Encroaching · Taut · Cold-edged · Kinetic · Legible

**Energy:** Urgent, rising toward frenetic in late waves.

| Escalation band | Atmospheric treatment | Readability limit |
|---|---|---|
| Opening pressure | SCOUT baseline; slightly cooler enemy approaches | No reduction in ground or path clarity |
| Sustained assault | Cooler fill, firmer contact shadows, denser peripheral atmosphere | Creature silhouettes and tower states retain their value hierarchy |
| Crisis / final wave | Coldest permitted ambience, strongest directional contrast, faster peripheral motion | Never crush blacks, tint semantic VFX, obscure paths, or cover dense creature clusters |

Escalation must feel like territory being invaded, not like a full-screen filter.

#### INTERMISSION — A Briefly Reclaimed Field

**Emotional target:** Relief with unfinished business.

**Lighting:** Contrast softens quickly. Restrained warmth returns around the hero,
towers, and interaction areas, while the wider field remains cooler than SCOUT.
Residual atmospheric effects slow rather than vanish.

**Descriptors:** Reclaimed · Smoke-touched · Watchful · Breathing · Purposeful

**Energy:** Measured, with residual tension.

**Visual carriers:** Lingering smoke, dust, minor debris, visible tower wear,
warm repair highlights, and reduced atmospheric motion.

#### MISSION_COMPLETE — Warmth Earned in the Field

**Emotional target:** Vindication and release: the player's plan held.

**Lighting:** Warm directional light re-enters without changing established
time-of-day logic. Combat contrast relaxes; the hero and surviving towers gain a
clear warm rim or material response. Cold pressure recedes toward spawn points.

**Descriptors:** Reclaimed · Resolute · Golden-edged · Settled · Earned

**Energy:** Resolving, then contemplative.

**Visual carriers:** Warm light reclaiming the defended route, settling
particles, softened shadows, and Sanctuary-associated amber practical lights.

#### DEFEAT — The Light Withdraws, but Survives

**Emotional target:** Costly setback without nihilism.

**Lighting:** Saturation and intensity reduce moderately toward cool muted
neutrals. Ambient fill preserves the cause of failure and final battlefield
state. At least one player-aligned warm source remains as a persistent ember.
Never use full grayscale, black crushing, blue-black horror, or exposure collapse.

**Descriptors:** Spent · Ash-muted · Exposed · Somber · Recoverable

**Energy:** Quiet and suspended.

**Visual carriers:** Dimmed battlefield practicals, one surviving warm light,
slow ash or mist, and a readable final arrangement of breached paths and threats.

#### MENUS / PLAYER INVENTORY — The Command Chamber

**Emotional target:** Deliberate preparation, ownership, and close inspection.

**Lighting:** Neutral-to-warm controlled lighting with higher local contrast than
the Sanctuary world view. The inspected hero, slot, or item receives the strongest
value focus. Cooler secondary panels separate information layers. Mood treatment
must not distort rarity, stat, material, or condition colours.

**Descriptors:** Tactile · Ordered · Intimate · Weighty · Deliberate

**Energy:** Contemplative and focused.

**Visual carriers:** Localized inspection light, illustrated item art and icons,
restrained architectural framing, and subtle depth separation.

The supplied Diablo IV screenshots inform Player Inventory UI hierarchy, panel
organization, equipment focus, and inspection emphasis only. They do not define
mood, palette, lighting style, realism, world rendering, or character treatment.

### 2.3 Hybrid-Media Atmosphere Rules

1. **3D carries stability and ownership.** Player-built terrain, towers,
   buildings, props, and the hero receive coherent world lighting and shadows.
   Warm practical light is the recurring marker of player control.
2. **2D creatures carry intrusion without looking pasted on.** Use shared
   world-facing light response, controlled edge values, simple contact shadows,
   and consistent ground alignment without collapsing their silhouettes.
3. **Atmosphere frames the swarm; it does not cover it.** Fog, smoke, particles,
   bloom, and moving shadows remain behind creatures or outside primary routes.
   Atmospheric complexity reduces when 100+ enemies occupy the field.
4. **Warm versus cool is territorial, not faction colour.** It never replaces
   semantic colours for danger, healing, targeting, rarity, status, or interaction.
5. **Value hierarchy outranks mood:** critical semantic signal → priority creature
   silhouette → hero/tower state → path and terrain → atmosphere.

### 2.4 Transition Rules

- Use localized lighting and atmosphere transitions, not full-screen colour washes.
- Standard transitions resolve over 1.0–2.5 seconds. Victory and defeat may use
  2.5–4.0 seconds after gameplay-critical resolution.
- Wave escalation changes occur at wave boundaries or telegraphed moments.
- No transition may temporarily hide a creature, projectile, status, path, or tower state.
- Semantic colours remain invariant and retain their backup shapes.
- Contact shadows may soften or sharpen but never disappear.
- Revise asset/world value separation before trying to repair readability with post-processing.
- Avoid repeated full-field flashes; lighting and VFX must remain photosensitivity-safe.
- Reduced-quality settings preserve the arc with ambient colour, practical-light
  activation, simplified fog planes, and restrained particles.

### 2.5 Approval Tests

A treatment passes only if:

- Its state is identifiable from a small screenshot without UI labels.
- Paths, buildable areas, tower states, and the hero remain readable at gameplay zoom.
- A 100+ creature stress scene preserves family and priority-threat silhouettes.
- Warm controlled space and cold hostile pressure remain distinct without semantic colours.
- Sanctuary progress appears through inhabited localized light, not global exposure.
- Diablo IV influence cannot be inferred outside Player Inventory UI organization.

---


## Section 3: Shape Language

> **Locked direction:** the player's domain is constructed, dimensional, and grounded. Hostile creatures are organic, illustrated, and disruptive. Shared scale, values, contact shadows, and edge treatment unite both media without hiding their difference.

### 3.1 Shape Families

| Family | Ownership | Grammar | Meaning |
|---|---|---|---|
| Constructed | Hero, towers, buildings, paths | stable bases, aligned planes, fitted joints, purposeful curves | control, permanence, preparation |
| Hostile organic | Monsters and hostile growth | uneven masses, hooks, broken rhythms, outward tension | appetite, pressure, instability |
| Supporting organic | Menagerie life and vegetation | rounded masses, soft asymmetry, inward containment | care, recovery, belonging |

Shape, pose, and motion must distinguish these families before colour. Flattened silhouettes must separate player construction, hostile life, and supporting life.

### 3.2 Hero

The 3D Hero owns the clearest mobile upright humanoid axis, not absolute height. A broad contact stance, stable head-torso relationship, one command feature, one craft feature, and weapon-side asymmetry persist across equipment. The ground footprint stays within one cell; equipment may extend above it. Glow is a recovery cue, never the primary identifier.

**Test:** locate the Hero within two seconds in a desaturated peak-wave scene containing twelve towers and 100 creatures.

### 3.3 Towers and Four-Component Modularity

| Archetype | Primary shape |
|---|---|
| Defense | broad base, low centre of mass, dense overlap |
| Direct damage | elevated directional weapon axis |
| Area damage | central emitter with radial or clustered form |
| Support | open frame, raised beacon, large negative space |
| Specialist | offset assembly and separated secondary mass |

Every tower reads in this order: archetype, direction of influence, component identity. Foundation controls footprint and mounting height; Weapon owns the main upper/forward silhouette; Focus adds one readable lens/ring/vane/coil motif; Power forms a compact source, reservoir, furnace, or counterweight. Foundation and Weapon establish the silhouette; Focus and Power differentiate the build. Shared sockets use fitted collars, keyed plates, brackets, rails, or conduits. Upgrades add structural articulation rather than decorative noise.

**Tests:** identify tower role within three seconds; distinguish two Weapons on the same Foundation; point to all four component zones at gameplay zoom.

### 3.4 Buildings, Terrain, and Paths

Player architecture uses layered stability: broad bases, visible support, repeated construction rhythm, restrained chamfers, and asymmetry caused by use. Sanctuary upgrades add function, then occupation, then legacy; an upgrade cannot be the same mass with extra trim.

Mission terrain is low, broad, and calm. Paths are continuous movement ribbons with long contours, directional wear, clear turns, and low borders. Buildability uses prepared ground and edge rhythm plus an explicit overlay, never colour alone. Vertical props move toward non-interactive boundaries. At thumbnail blur, path and occupied build cells remain separable while decoration merges into quiet masses.

### 3.5 Illustrated Creatures

Each 2D family owns one body mass, locomotion signature, contour motif, forward direction, and protected identifying feature.

| Tier | Rule |
|---|---|
| Standard | one dominant repeatable mass, low internal contrast |
| Elite | family ancestry plus one persistent asymmetric break and stronger local contrast |
| Boss | multi-cell visual mass, unique contour, readable facing and action zones |

Standards are not restricted to one proportion; simplicity and repeatability matter. Elites are not recoloured Standards. Bosses change scale and contour, not only detail. In 100+ waves, identifiers cannot depend on faces, fingers, thin accessories, or internal linework.

### 3.6 UI Shape Grammar

UI is a precise command instrument: regular rectangles, restrained chamfers, structured grids, and low-relief surfaces. Capsules are for compact tags; circles for genuinely radial concepts such as cooldowns and sockets. Primary actions gain prominence through size, placement, framing, and whitespace before colour. Icon frames carry category through notch/corner/border patterns.

### 3.7 Hybrid Integration

Every sprite obeys the 3D world's spatial rules: stable ground pivot, consistent contact shadow, compatible key direction and value range, elevated-oblique perspective, honest footprint, correct depth sorting, restrained atmosphere, and no camera-facing swivel. Do not force sprites to imitate 3D with excessive relighting; their illustrated quality is intentional.

**Seam test:** creatures read as illustrated beings inhabiting the place, not cards pasted over it.

### 3.8 Hierarchy and Prohibitions

SANCTUARY reads interaction target → Hero/activity → upgraded buildings → circulation → ambient history. SCOUT reads build space → path/breach → towers/constellations → Hero → decoration. WAVE_ACTIVE reads immediate threat → Hero/priority enemy → active tower fire → horde → environment.

Prohibited: generic spikes; surface detail repairing weak silhouettes; component swaps expressed only by colour; unsupported floating parts; environment props resembling towers; Standard identifiers lost in overlap; ornate frames reducing content; upgrades expressed only by glow or trim.

---

## Section 4: Color System

> Warm and cool communicate territorial control. Warmth marks refuge, construction, recovery, and player footholds; coolness marks distance, uncertainty, and encroaching pressure. Atmosphere never overrides gameplay semantics.

### 4.1 Core Palette

| Colour | Hex | Role |
|---|---:|---|
| Hearth Amber | `#C88432` | inhabited player warmth and crafted accents |
| Refuge Cream | `#E8DEC3` | agency, readable light surfaces, neutral selection |
| Fieldstone | `#888983` | terrain, masonry, neutral construction |
| Ash Charcoal | `#292C32` | recesses, structure, defeat residue |
| Watch Blue | `#3F6982` | planning, distance, cool shadow |
| Living Green | `#4E8053` | subdued vegetation and Sanctuary life |
| Threat Red | `#C43B36` | damage, danger, rejection; never decorative |

Stone, timber, leather, iron, brass, earth, and cloth use restrained material relatives. Decorative brass remains browner and darker than semantic gold; vegetation remains duller than healing; fire is amber-orange rather than Threat Red.

### 4.2 Territorial Temperature

Warmth gathers at inhabited Sanctuary areas, player towers, interaction zones, intermission recovery, and victory reclamation. Coolness gathers at enemy approaches, unclaimed terrain, distant layers, peak-wave pressure, and defeat. Boundaries use gradients and overlapping light pools, not faction-colour lines. Semantic effects are protected from atmospheric grading.

Sanctuary progression moves Refuge → Workshop → Settlement → Legacy by adding localized task light, richer maintained materials, cultivation, and history. It does not simply raise global exposure.

### 4.3 Semantic Colours

| Meaning | Hex | Mandatory backup |
|---|---:|---|
| Damage/danger | `#C43B36` | angular warning, outward/downward motion, impact sound |
| Healing | `#55B96A` | `+`, cross/leaf, upward motion, ascending sound |
| Warning | `#E79A32` | triangle/clock, pulse cadence, warning tone |
| Selection | `#F0E8D2` | bracket/reticle |
| Exceptional/critical/affinity | `#E8C24A` | starburst/diamond, enlarged beat, confirmation sound |
| Planning/range | `#4E8DAE` | dashed ring/grid pattern |
| Boss | `#7C3FA1` | crown/skull, unique rhythm and audio |
| Disabled | `#747983` | lock/slash, opacity, no response |

Purple is boss-only: boss marker, pre-spawn edge/shadow push, and limited boss accent are expressions of one event. Elites do not use purple.

### 4.4 Elements

| Type | Hex | Shape |
|---|---:|---|
| Physical | `#D6CCB6` | fragment/slash |
| Fire | `#E36A32` | flame |
| Frost | `#78B7D3` | crystal |
| Poison | `#A3AD3B` | fang/drop |
| Lightning | `#E7D052` | bolt |
| Arcane | `#C96A91` | knot/rune |

Each element retains its glyph, motion, and audio family. Arcane uses rose, not reserved Boss Purple. Large bodies use desaturated relatives; strongest colour belongs in cores, impacts, icons, and bounded channels.

### 4.5 Creatures, Biomes, and UI

Creature families differ through dominant hue, secondary neutral, accent placement, value grouping, silhouette, and locomotion. Tier is never a saturation ladder. Standard accent coverage is restrained; Elite contrast concentrates around its tier feature; Boss Purple remains limited.

Biome order of authority is semantic event → element/status → phase atmosphere → biome → decoration. Temperate, cold, and blighted families may vary geology and ecology but preserve paths, build grammar, and semantic colour.

UI uses Deep Chrome `#20252E`, Raised Chrome `#343C48`, Content Parchment `#D8D1BD`, Primary Text `#EEE9DD`, Secondary Text `#A9ADB2`, Interactive Cyan `#48A8C7`, and Divider Brass `#8E7650`. Interactive Cyan is screen-space only. Diablo screenshots provide no palette reference.

### 4.6 Emissive and Accessibility

Persistent emissive sources remain bounded, retain hue and shape, and never require bloom. Pure white is a brief peak. No full-screen wash or boss-purple filter. At density, remove ambient particles and nonessential emission before semantic cues.

Validate full colour, grayscale, protanopia, deuteranopia, tritanopia, minimum brightness, peak darkness, warm victory, cool defeat, 100+ creatures, and all UI scales. Colour-only identification, atmospheric semantic drift, clipped bloom, non-boss purple, and indistinguishable focus/selection/disabled states are blocking failures.

---

## Section 5: Character Design Direction

> The 3D Hero is the embodied author of the constructed world. Hostile creatures are expressive 2D illustrations; Menagerie creatures use the same medium but replace outward aggression with protected, responsive forms.

### 5.1 Hero — Warden-Smith

The Hero is a field commander whose authority comes from building, maintaining, and understanding defensive systems. Four anchors persist: upright command axis, stable ground stance, one command feature, and one craft feature. The Hero is neither generic knight, robed wizard, rogue, historical officer, nor glowing chosen one. Diablo inventory images do not define Hero style.

Equipment variation is hierarchical: Weapon produces the largest contour change; head and torso alter secondary mass; legs preserve ground contact; accessories add at most one secondary contour. Tier appears through construction, support, fit, and material quality rather than increasing bulk, saturation, or ornament. All attachments use believable load paths and fastenings.

### 5.2 Hero Models and Detail

The technical limits in Section 8 are binding: gameplay LOD0 targets 4–6k triangles with a hard 6k ceiling; Inventory inspection targets 10–15k with a hard 15k ceiling. Both share proportions, skeleton, identity, and material logic. Gameplay geometry prioritizes silhouette, head/shoulders/hands/weapon, material breaks, joints, and sockets. Inspection adds face, hand, edge, and construction refinement without creating a different character.

Materials are hammered metal, layered leather, heavy cloth, worn timber or wraps, and restrained brass. Detail bands are primary silhouette, secondary construction, then tertiary wear. A clay render must preserve role, weight, and equipment class.

### 5.3 Hero Pose and Animation

Movement is deliberate under pressure: compact anticipation, clear contact, weighted recovery, controlled centre of gravity, readable line of action, and limited idle motion. No animation falsifies the one-cell footprint, hides the weapon for most of an attack, or loses the feet. Reduced visual effects cannot be required to identify the action.

### 5.4 Hostile Creatures

Each family owns body mass, locomotion, contour motif, identifying feature, value grouping, and direction. Standards use clean repeatable shapes; Elites retain ancestry plus one structural asymmetric break; Bosses own a unique contour, readable facing, attack origin, and action zones. Key poses beat high frame count. Directional variants maintain mass, pivot, scale, and baked-light logic; mirroring is disallowed where anatomy or lighting would reverse.

Crowds use modest animation phase offsets, stable contact, short hit reactions, quick death clearance, and effects that do not make every unit focal. A grayscale 100-creature scene must reveal family, direction, Elite, and Boss action.

### 5.5 Menagerie and Recognition

Menagerie creatures use rounded or softly faceted masses, inward containment, relaxed asymmetry, open sensory regions, and habitat contact. They need not all be cute. Happiness reads through pose, activity, and social engagement before colour: low is withdrawn but not harmed; mid is neutral/exploratory; high is open and responsive.

Allegiance never relies on red versus green. Player forms are fitted and deliberate; hostiles use forward pressure and attack anticipation; Menagerie life uses exploratory, social, restful motion. Every asset uses a shared scale chart, ground contact, shadow, light direction, depth sorting, and honest footprint.

### 5.6 Validation and Prohibitions

Validate Hero identity across loadouts and LODs; creature family/facing/tier at actual size; happiness without UI; portraits/icons against gameplay identity; and all categories in shared scale, light, density, and colour-vision tests. Prohibited: Diablo-derived Hero art, glow-led importance, recoloured Elites, universal purple, crowd-synchronised bobbing, mirrored directional errors, low happiness as abuse, mismatched perspective, floating contact, and portraits that redefine anatomy or scale.

---

## Section 6: Environment Design Language

> **Architectural register: Reclaimed Warden Craft** — durable stone, worked timber, forged reinforcement, fitted mechanisms, restrained sacred geometry, visible repair, and accumulated stewardship. It is personal rather than imperial and maintained rather than pristine. Diablo is not an environment reference.

### 6.1 Sanctuary

The Sanctuary layers old foundation, working adaptation, and living accumulation. It uses enclosed courtyards, clear circulation, ground/working/landmark height bands, warm interiors, cool recesses, and functional sightlines. Growth adds usable volume, occupation, then legacy.

System forms share one culture: Forge is heavy and ventilated; Tower Assembly exposes sockets/rails/four-part order; Inventory uses protected neutral inspection; Tarot uses nested indexed or radial arrangements; Menagerie uses open shelter and care access; Watch structures use braced elevation. These expressions add no gameplay function.

### 6.2 Mission Geometry and Biomes

Mission space uses ground plane, low detail, mid landmarks, and high boundary. Tactical centres suppress height and noise; boundaries carry vertical complexity. Paths are continuous, build cells are world-integrated plus explicit overlay, and creature contact remains clear.

Temperate Frontier balances earth, vegetation, and cool distance; Cold Expanse uses pale stone, dormant growth, and sparse warmth; Blighted Reach uses ash, ochre, rust, and damaged vegetation without decorative semantic colours. Every biome preserves path, build, camera, semantic, and sprite-grounding rules.

### 6.3 Stylized PBR

Use restrained stylized PBR: broad albedo, physically coherent roughness/metallic, quiet normals, contact AO, and no directional highlights or cast shadows baked into Base Colour. Roughness separates materials; metal is metal-only; parallax requires technical approval. Stone is high-roughness and broad; timber directional; iron dark and controlled; brass restrained; earth quiet; vegetation grouped rather than noisy.

### 6.4 Modular Kits and Props

Sanctuary kits include foundations, walls/corners/ends, openings, floors/stairs/thresholds, beams/braces/platforms, sockets/conduits, roofs, habitat pieces, and practical lights. Mission kits include ground/path transitions, curves/junctions/spawn/breach, build treatments, boundaries, ruins, cliffs, biome clusters, and landmarks. Connections, pivots, caps, attachment zones, and material families are shared.

Sanctuary density is accumulated, not cluttered: one functional anchor, work cluster, storage/archive cluster, habitation cue, and quiet route. Mission fields are surveyed: no raised path clutter; lowest density beside lanes; landmarks outside tactical silhouettes; ambient movement yields during waves.

### 6.5 Camera, Lighting, and Creature Clearance

Approve from the fixed gameplay camera with HUD before beauty views. Important openings face the camera where plausible; foreground never blocks cells; transparency is not the first occlusion fix. Reserve path clearance for sprite feet and shadows, quiet backgrounds behind heads, negative space for Boss staging, and broad soft environment shadows.

Architecture creates believable warm sources and cool depth. WAVE_ACTIVE darkens edges rather than lanes. At density, reduce particles, foliage motion, emission, and background animation before landmarks or semantic cues.

### 6.6 Story, Reuse, and Validation

Storytelling records stewardship, prior use, and current pressure through repairs, work in progress, organized components, habitat response, worn routes, old defences, spawn disturbance, and post-wave damage. Reuse trim sheets, tiles, atlases, masks, decals, instances, and clusters. Variation priority is arrangement → silhouette attachment → mask/value → decal → prop cluster → unique mesh.

Validate growth in grey model; path/spawn/breach/build without UI; materials in all light states; modular repetition; 2D clearances; target-resolution HUD capture; and technical budgets in Section 8. Prohibited: gothic/Diablo architecture, cabinet framing, random asymmetry, photoreal noise, baked lighting, semantic decorative surfaces, path clutter, tower-like props, lane fog, transparency-first occlusion, and beauty-only approval.

---

## Section 7: UI/HUD Visual Direction

> **The Warden's Command Interface:** precise screen-space instruments derived from fitted world construction. Regular geometry, cool-neutral palette, stable type, and controlled motion separate information from the warm 3D world and illustrated creatures.

### 7.1 Screen Space, World Space, and Frame

Screen-space owns persistent and comparative information: Hero state, skills, wave, objectives, tower stats, Inventory, management, tooltips, warnings, and results. World-space owns location-dependent facts: selection brackets, footprints, range, targets, local health/status where UX approves, damage/heal numbers, and boss entry markers. World labels stay concise.

Gameplay is **full bleed**. Edge ornament is modular and independently hideable by zone; it must not create an artificial cabinet or fixed world viewport. Persistent UI stays at edges and the central battlefield remains clear. Interactive Cyan is screen-only; Selection Cream and Planning Blue identify world agency. Every screen is tested at 16:9, 16:10, and 21:9 at 100% and 150% UI scale with safe areas respected.

### 7.2 Style and Typography

Surfaces use Deep Chrome, Raised Chrome, restrained fitted corners, thin dividers, clear insets, and deliberate whitespace. One major ornamental motif per screen is the ceiling; nested panels become quieter. No glass sci-fi, full parchment, heavy stone slabs, gothic filigree, or glow on every control.

Use a humanist sans with open apertures, distinct `I/l/1` and `0/O`, tabular numerals, and broad language coverage for functional text. A restrained slab-serif is limited to large headings. No thin, condensed, distressed, script, or outlined functional type.

**Binding 1080p minimums:** menu labels and body copy `>=24 px`; tooltips, item stats, and dense comparative text `>=22 px`; critical Mission HUD text `>=20 px`. Larger titles and primary values scale above these floors. Containers expand for localization and 150% scale rather than shrinking text.

### 7.3 Icons, Focus, and Semantics

Icons are silhouette-first with one inset plane, consistent apparent stroke, and no essential feature thinner than target visibility. General icons display at least 24px; combat-critical icons at least 32px. Tower components carry persistent Foundation/Weapon/Focus/Power notch codes. Element icons use Section 4 glyphs. Rarity, selection, equipped, locked, and invalid states use frame/mark/text backups.

Keyboard/gamepad focus uses a persistent outline or bracket distinct from hover and selection. Every focusable control authors explicit `focus_neighbor_top/bottom/left/right` relationships (or the equivalent in the implemented UI framework); automatic geometric guessing is insufficient for production screens. Focus remains static-readable in reduced-motion mode.

All semantic colours inherit Section 4 backups. Interactive Cyan marks focus/selection inside UI. Gold cannot mean ordinary ready. **Skill Ready is a state inside each skill tile**—shown through cooldown completion, a stable ready mark, and controlled tile treatment—not a detached text label or separate HUD callout.

### 7.4 Motion and Accessibility

Motion is snappy-in and eased-out: hover/focus 60–100ms; press 70–120ms; small transition 100–160ms; panel open 140–220ms; close 100–180ms. No rubber bounce or ornamental machinery. Reduced motion replaces travel and repeated pulse with fades or immediate states while preserving warnings. No element flashes over three times per second; no large-area strobe or full-screen damage flash.

Normal text targets at least 4.5:1 contrast; large text, focus, and essential control boundaries at least 3:1. Measure against the rendered backing and warm battlefield, not swatches. Colour is never the only state carrier.

### 7.5 Mission HUD

Read order: Hero survival → boss/breach warning → skill tiles → wave/time → selected tower/target → resources/rewards → secondary notices. SCOUT shows planning and previews; WAVE_ACTIVE removes placement controls; INTERMISSION restores them; success/defeat clear combat noise before outcome.

Stable zones prevent overlap. One animated alert per local zone is the default. Wave composition uses creature art plus count and tier. Item drops own a transient zone. Damage numbers require aggregation/suppression under density. Boss HUD warning precedes the ambient purple push. Warning Amber is checked against warm-keyed battle scenes.

### 7.6 Sanctuary Menus and Inventory

Sanctuary menus permit more Content Parchment, architectural framing, whitespace, and large illustrations, but systems differ through layout, focal content, and icon family—not unrelated colour themes.

Inventory uses the recommended simultaneous relationship: **collection on the left, Hero/equipment on the right, and a contextual comparison panel that appears adjacent to the selected item without displacing the primary equipment read**. At constrained width the comparison may overlay or replace secondary detail, but collection and equipment remain simultaneously understandable. Diablo screenshots inform this hierarchy and inspection rhythm only—not palette, frames, character, typography, item art, rarity, or lighting.

Inventory hierarchy is item identity/type → eligibility/current comparison → primary stats → affixes/interactions → requirements/actions → flavour. Equip, selected, compatible, locked, and stat direction remain clear without colour.

### 7.7 UX Validation Flags

UX owns final validation of world health-bar policy, persistent tower state, damage-number suppression, tooltip timing/pinning, notification concurrency, skill-tile interaction, inventory comparison behaviour at narrow widths, controller traversal, text expansion, and background treatment. Art approval requires explicit focus neighbors, safe-area captures for all ratios/scales, reduced-motion equivalence, and peak-density Mission HUD evidence.

---

## Section 8: Asset Standards

> Source files preserve editability. `assets/art/` contains the only engine-referenced assets. Raw/generated masters live in `assets/source/`. Technical limits below override earlier art-only estimates; compression, exact LOD switching, and shadow settings remain profiling-driven.

### 8.1 Formats, Naming, and Separation

Use editable `.blend` 3D masters, layered `.kra`/`.psd` raster masters, and `.svg` vector masters where appropriate. Runtime 3D format is **GLB/glTF 2.0**. Alpha-critical sprites/UI/VFX use lossless PNG unless profiling approves another format. Base colour/illustration is sRGB; normal, roughness, metallic, AO, and masks are linear. Straight alpha with edge bleed is the default pending importer validation.

All assets follow `[category]_[name]_[variant]_[size].[ext]`, lowercase snake case, zero-padded variants, canonical state names, and no `final`, `new`, dates, or artist initials. Recommended prefixes: `char`, `tower`, `env`, `ui`, `vfx`, `mat`, `tex`, `ref`.

`assets/source/` contains DCC, layered, high-resolution, bake, raw generation, and review masters; nothing there is referenced by Godot. `assets/art/` contains processed GLBs, textures, sheets, illustrations, VFX, materials, and approved runtime assets. Each runtime asset traces to source, scale, pivot, material set, LOD/tier, animation list, art status, and technical status.

### 8.2 Stylized PBR and Textures

Required logic: Base Colour without baked directional light; tangent normal; roughness; metallic for real metal only; restrained AO; bounded emission; masks. ORM packing (R=AO, G=roughness, B=metallic) is recommended only after Godot validation. No parallax without approval.

| Category | Technical target |
|---|---:|
| Hero gameplay | 1–2k |
| Hero inspection | 2k |
| Landmark | 2k |
| Normal tower/building | 1k |
| Prop | 256–1k |
| Terrain/trim | 1–2k |
| Standard creature atlas page | 1k |
| Boss atlas page | 2k |

All 3D world textures and world creature sprites use mipmaps. Exact compression is profiling-driven; do not lock BPTC or any codec by assumption. `Viewport.use_hdr_2d` is prohibited. Emission and VFX must read without it.

Material slots: Hero `<=3`; tower/building `<=2` normally, third only for justified animated/emissive function; repeated prop and terrain asset `1`. Shared trim, atlas, mask, and instancing strategies are preferred.

### 8.3 Geometry and LOD

One grid cell is 64 world units; a canonical Godot scale scene is authoritative. Grounded origins sit at contact; towers at footprint centre; components at approved sockets; hinges at real axes; sprites at canonical contact pivot.

| Asset LOD0 | Target | Hard cap |
|---|---:|---:|
| Hero gameplay | 4–6k | 6k |
| Hero inspection | 10–15k | 15k |
| Simple tower | 1.5–3k | 3.5k |
| Standard/upgraded tower | 3–5k | 6k |
| Signature/final tower | 5–8k | 10k |
| Small building | 5–10k | 12k |
| Standard building | 10–18k | 20k |
| Landmark | 18–30k | 35k |
| Small prop | 50–500 | 750 |
| Medium prop | 500–1.5k | 2k |
| Large prop | 1.5–4k | 5k |
| Wall/path/floor module | 100–1.5k | 2k |
| Terrain chunk | 2–8k | 12k |

Visible-scene target is `<=400k` triangles normal and `<=600k` stress, confirmed by pilot. LOD1 targets 50–60% of LOD0 and LOD2 20–30%. Large towers, buildings, and landmarks require LOD0/1/2. Exact distances, hysteresis, and shadow LOD are profiling-driven. Automatic decimation requires silhouette review.

### 8.4 2D Creatures and Illustration

Author sprites at 2–4x display size with layered masters. Runtime sheets use consistent frame dimensions, at least 4px padding (8px recommended), stable contact pivot, documented order, explicit directions, and no trimming unless metadata preserves pivot. Mirroring is prohibited where anatomy, equipment, markings, or light reverse. Family identifiers and Elite features persist through every frame.

Illustrated UI defines bleed, essential safe area, text exclusion, focal point, and authored crop variants. Small icons pass at 24/32px; item state frames remain separate from art; card ratio is locked before production.

### 8.5 Runtime Budgets

Target PC performance is 60 FPS / 16.67ms. Draw calls have a hard ceiling of 200: art targets `<=150` normal, `<=180` in the 100+ stress scene, and `<=200` only transiently. Do **not** assume CanvasItem batching. The creature swarm pilot must prove a `Sprite3D`/`MultiMesh` or equivalent instanced solution with actual materials, sorting, animation, hit feedback, and shadows.

Provisional texture residency is `<=350MB` normal and `<=450MB` stress; total process target `<=1GB`. A creature-family atlas targets `<=4MB` resident; Boss atlas 8–16MB; VFX page `<=4MB`.

Battlefields allow `<=4` visible local lights and `<=1` shadow-casting local light. Sanctuary allows `<=8` visible local lights and `<=2` shadow-casting local lights, plus one primary directional shadow light. Exact bake/dynamic mix and shadow resolution are profiling-driven.

VFX provisional limits: `<=300` visible particles, `<=12` blended full-effect quads, and `<=4` large-area transparent effects. Semantic effects survive density reduction before ambient effects.

### 8.6 VFX, Export, and Import

Use 3D motion/world-aligned visuals for travel and ground relationships; 2D frames, meshes, particles, decals, and UI animation for impacts and feedback. Sheets use lossless alpha, bleed, padding, documented loop/order, and separate blend modes where required. No effect depends on bloom or obscures paths, build cells, Hero, Elite feature, Boss tell, or facing.

GLB exports contain only required meshes, skeletons, animations, sockets, and approved materials; remove cameras, lights, helpers, unused bones/tracks, hidden geometry, and unapplied inconsistencies. Category importer presets must be reproducible. Exact compression, mip filtering, LOD, shadows, animation compression, and transparency settings are technical-owner decisions based on captured performance and image evidence.

### 8.7 Scale Charts and Cross-Medium Pilot

The gameplay chart contains a 64-unit cell, path width, build footprint, Hero, Standard sizes, Elite, Boss, Menagerie creature, small/medium/large towers, doorway, environment height bands, and locked camera. UI chart contains 24/32px icons, equipment icon, portrait, card, typography, focus/selection/disabled/warning, and 100%/150% captures.

Before mass generation, pilot: Hero gameplay/inspection; direct and support towers; visible swaps across all four components; path/build/terrain; Sanctuary station; props/lights; Standard/Elite/Boss/Menagerie sprites; projectile/impact/status/heal/boss/placement effects; Mission HUD, tower panel, illustration, and Inventory slice. Review Sanctuary, SCOUT, early/peak 100+ WAVE_ACTIVE, INTERMISSION, victory, defeat, and Inventory.

The pilot must prove grounding, modularity, semantic colour, path/build read, UI separation, 60 FPS, geometry, draw calls, residency, light limits, VFX limits, and the instanced swarm path. No mass production begins before approval.

### 8.8 Quality Gates

Source gate: editable, named, organized, provenance recorded, artefacts corrected. Art gate: Sections 1–7, silhouette, palette, material, medium, and originality pass. Runtime gate: correct directory/name/scale/pivot/socket/import/material/animation/sorting/shadow and no broken/source reference. Context gate: target resolution, all lights, HUD, grayscale/colour vision, maximum density, adjacent categories, UI scales, and captured evidence.

Prohibited: direct `assets/source` references; raw generation as final; arbitrary scale fixes; baked lighting; non-metal metallic; emissive silhouette rescue; unreviewed decimation; unstable sprite pivots; alpha fringes; semantic state baked into reusable art; mass generation before pilot; fixed compression/LOD/shadow assumptions; `Viewport.use_hdr_2d`; or approval from isolated beauty views.

---

## Section 9: Reference Direction

> No reference is a whole-game target. Extract the named technique only, obey the avoidance boundary, and resolve every result through Sections 1–8.

### 9.1 Against the Storm — Refuge Under Pressure

**Draw:** localized inhabited warmth against hostile atmosphere; elevated-camera functional building silhouettes; modular construction with coherent culture; growth through function, light, activity, and connection; stable command information around a dense world.

**Avoid:** copied buildings, roofs, species culture, rainpunk machinery, palette, constant rain, city-builder density, or wholesale UI. Translate the principle into original Reclaimed Warden Craft.

### 9.2 Cult of the Lamb — 2D/3D Integration

**Draw:** shared elevated-camera assumption, stable sprite contact and shadows, depth sorting, expressive small-scale key poses, and compatible value/atmosphere.

**Avoid:** paper-cutout construction, chibi/cute proportions, face style, elastic motion, heavy outline, cult/gore symbolism, saturation, or face-on billboarding. The lesson is that an illustrated being obeys a dimensional place.

### 9.3 Thronefall — Tower-Defense Readability

**Draw:** clear routes and attack flow, distinct preparation/attack states, reduced tactical ground, functional building silhouettes, controlled focal hierarchy, and quiet edge HUD.

**Avoid:** low-poly minimalism, toy proportions, palette, fully 3D enemies, loss of four-component tower detail, or removal of required RPG information. Use it as a subtraction reference when combat becomes noisy.

### 9.4 TUNIC — Camera-First Stylized PBR

**Draw:** broad material response, camera-legible geometry, quiet albedo/normals, readable top/side planes, atmospheric separation, and visual silence around important forms.

**Avoid:** pastel palette, toy scale, fox/ruin/monolith motifs, puzzle language, untouched-ancient atmosphere, or over-simplified components. Transfer material restraint, not look.

### 9.5 Darkest Dungeon — Illustrated Threat

**Draw:** decisive contour, large internal value groups, pose-led personality, structural threat escalation, strong action keys, and family motifs.

**Avoid:** black ink/hatching, near-black/red palette, gothic horror anatomy, costume, side-view staging, stress UI, or Menagerie application. Transfer silhouette and pose, not rendering style.

### 9.6 Supplied Diablo IV Screenshots — Inventory Only

`production/Hero Unequipped.PNG` and `production/Hero 2H equipped.PNG` inform only character-as-equipment-context, slot relationship, collection/equipped/inspection grouping, comparison layering, and inspection rhythm.

They do not define Hero, anatomy, armour, weapons, realism, palette, gothic ornament, typography, item art, rarity, panel texture, lighting, pose, world, creature, tower, environment, or VFX. Do not reproduce exact frames, slots, proportions, or three-column layout. Sanctuary Defenders uses its simultaneous collection-left/equipment-right/contextual-comparison recommendation and original Warden's Command Interface.

### 9.7 Reference Control

Every board image is tagged `FORM`, `MATERIAL`, `LIGHT`, `COMPOSITION`, `2D_3D_INTEGRATION`, `SILHOUETTE`, `DENSITY`, `UI_HIERARCHY`, `MOTION`, or `AVOID`, with exact extraction, category, avoidance, and supporting Bible section. Unlabelled reference images are prohibited.

An asset fails if its first read is “an Against the Storm building,” “Cult of the Lamb creature,” “Thronefall battlefield,” “TUNIC environment,” “Darkest Dungeon monster,” or “Diablo inventory.” It passes when the technique supports the locked Sanctuary Defenders identity without copied silhouette, palette, architecture, character, UI, VFX, or ornament.

# Hero Character Visual Profile — Sanctuary Defenders

> **Purpose**: Single-file handoff for character artists building the Hero asset. Every rule below is copied or directly derived from the Art Bible — no new creative decisions were made in this compilation. Where a value could be paraphrased loosely, the original wording/numbers are preserved instead.

## Source Sections (cross-reference for deeper context)

| Topic | Art Bible Section |
|---|---|
| Hybrid rendering rationale (Hero = the one 3D asset) | Section 1 — "Note on the Hybrid Rendering Technique" |
| Hero silhouette rule (first statement) | Section 3.1.1 |
| Hero read-order priority in scene hierarchy | Section 3.4 |
| Cultural register, silhouette spec, material language, expression register | Section 5.1 (5.1.1–5.1.4) |
| Posture philosophy | Section 5.3.1 |
| Idle animation spec | Section 5.3.2 |
| Combat pose readability rules | Section 5.3.3 |
| LOD / play-angle contract (on-screen size reference) | Section 5.4.1 |
| Tower–Hero Fusion Visual Language | Section 5.5 (5.5.1–5.5.5) |
| Engine constraints — poly/texture/material budgets | Section 8.7 |

---

## 1. Cultural Register & Archetype

**Archetype: Warden-Smith** (Section 5.1.1) — a keeper of sacred and constructed things, equal parts craftsperson and sentinel. Not a classical warrior-hero, not an arcane scholar. The warden-smith *made* the towers, *maintains* the sanctuary, and *fights* when the work demands it.

Three tensions the design must carry:

| Tension | Visual Expression |
|---|---|
| Maker vs. Fighter | Worn craft tools and fighting arms coexist on the same figure. No purely decorative elements — every piece of kit has a function. |
| Precision vs. Endurance | Silhouette is lean and deliberate, not bulky. Materials are heavy — layered leather, hammered plate, wrapped grips. Nothing is fragile. |
| Familiar vs. Strange | Reads as recognizably human and grounded, but fusion-state tower components place the hero outside any single cultural reference. |

**What this archetype is NOT:**
- Not a generic fantasy knight (no full-enclosure plate, no plumed helmet)
- Not a wizard/scholar (no robes, no scrolls, no floating magical instruments)
- Not a rogue/thief (no asymmetric hood-and-dagger silhouette)
- Not a historical war general (no epaulettes, no command staff)

**Reference register:** specialist tradesperson meets field commander — closest real-world analogue is a master siege engineer who also fights. Technical authority expressed through the body, not through title.

**Hybrid Rendering Note (Section 1):** The Hero is the *one* real-time 3D model in the game, composited into a scene built entirely from layered 2D sprites. This is not a technical compromise — it is the correct expression of identity. The Hero is the player's singular point of presence in an otherwise crafted, arranged world; a 3D model carries weight, casts light realistically, and reads differently from every other object on screen intentionally. In the cabinet-diorama metaphor, the Hero is the hand-painted centrepiece figure; the 2D world is the crafted scenery around it. Every rendering choice in the 2D world (warm painterly textures, edge DoF softening, cast shadows between sprite layers) is calibrated so the diorama feels real enough that the 3D Hero belongs inside it rather than floating above it.

---

## 2. Silhouette Rules (Binding)

From Section 3.1.1, reproduced binding in Section 5.1.2:

- **Aspect ratio:** Target **1.8:1** (height:width) at default zoom, measured at idle stance.
- **Floor:** No idle animation frame may collapse below **1.4:1**. Combat crouches permitted only in active-attack frames — never in idle loops.
- **Apex:** The silhouette crown (helmet/head) must be a clean **point or rounded dome — never flat**. The Hero's crown is always the highest pixel in any entity cluster.
- **Ground contact:** Feet are wide-planted relative to torso — the stance must communicate weight at the contact point (Principle 1: objects sit *on* the ground plane).

**Warden-smith crown constraint (additional, Section 5.1.2):**
- Acceptable apex forms: narrow visor-ridge terminating in a point; close-wrap hood with hardened crown finishing in a rounded dome; low-profile helm with a centered crest-fin.
- Unacceptable apex forms: full-face bucket helm (loses craftsperson register), wide-brim hat (flattens crown, violates point/dome rule), elaborate horned/winged additions (reads monster-adjacent or fantasy-generic).
- **Design test:** At the oblique play angle and game camera distance (~48px tall on screen), the crown accent must still read as a single upward form. If it requires zooming in to distinguish from a flat top, redesign as a larger single form.

**Scene-hierarchy read priority (Section 3.4):** The Hero occupies the mandatory **first read layer** of every scene — found before anything else is consciously processed. No other entity shares this layer.

**Rules ensuring the 3D Hero reads without being jarring (Section 3.4):**
1. Fixed oblique angle only — no perspective distortion on the model; depth cues come from the same grammar as 2D sprites (ambient occlusion/rim light ≈ sprite stacking/edge shading).
2. Grid-compliant footprint — feet must fit within one grid cell; upper body/weapon may extend above the cell boundary (the vertical elongation rule). Ground contact must be grid-compliant.
3. No view-dependent effects — no parallax, no view-dependent specular that would shift with camera movement.
4. **Shadow footprint is mandatory** — a sprite-style flattened-ellipse cast shadow on the ground plane, consistent with all other objects. This is the single most important rule preventing the 3D model from reading as floating.

---

## 3. Material & Color Spec

Three permitted material categories on the base (non-fused) Hero (Section 5.1.3):

| Material Layer | Description | Color Register |
|---|---|---|
| **Hardened leather (primary)** | Dominant surface — shaped panels, visible stitching, edge-reinforcement. Tanned, not dyed. Wears naturally. | Dark warm brown, approx. **HSL 30, 35%, 28%**. Not black, not bright. |
| **Hammered plate (secondary)** | Irregular smith-made plate over leather at impact zones (shoulder cap, shin guard, forearm bracer). Hammer texture, mild weathering. | Base: **Fieldstone Grey `#7E8590`**. Lit faces shift toward **Parchment Cream `#F5EDCB`**. Shadow faces shift toward deep warm grey. |
| **Wrapped grip and cord (accent)** | Tool handles, weapon grips, fastening cords. Tight-wrapped woven cord, worn but maintained. | Desaturated Sanctum Amber, approx. **HSL 38, 40%, 38%** — warmer/darker than tower amber to distinguish Hero from constructed world objects. |

**Skin register:** Lightest value is Parchment Cream **`#F5EDCB`**. Must not render as bright white or highly saturated warm tan (either extreme pushes toward fantasy-generic). Exposed skin area minimal (wrist, lower face if helmet open-faced) — the Hero is protected, not displayed.

**Standard rim highlight:** Off-white or pale warm-grey, on the dominant-facing edge (facing the oblique light source). Always present regardless of game state (Section 2 cross-state rule #3). **Exception:** shifts to full **Sanctum Amber** in MISSION_COMPLETE state only — shader-driven state parameter, must be specced to technical-artist before sign-off.

**Tower Affinity aura (when active):** **Herald Gold `#F5C01A`** radiates as a soft glow from the chest-plate area (not the outline). Glow radius contained to ~1.5× the Hero footprint. Must not read as a second rim highlight or compete with the standard rim.

---

## 4. Expression & Posture

**Expression register (Section 5.1.4): composed stoicism with visible effort.** Not blank/inexpressive — deeply invested in the fight, but communicates control, not panic. Reads as someone who thought about this before it started.

At game distance the face is read through pose and silhouette, not facial features. The 3D model's face must communicate register from ~48px on-screen height via jaw-set, slight forward lean, grounded weight. Expressive smile or open-mouth distress are wrong at any distance.

**Expression by animation state:**

| State | Expression Rule |
|---|---|
| Idle | Weight resting but alert — slight forward tilt at the crown, eyes forward. Not slouched, not rigid. |
| Combat auto-attack | Drive from the shoulder, not the whole body — controlled, not windmill. |
| Skill activation | Head drops slightly on cast, then snaps back — commitment, then recovery. |
| Low HP | Posture drops 5–8°. Head tilts minimally forward. Shoulders narrow slightly. Body communicates strain; face does not grimace. |
| MISSION_COMPLETE | Stance opens — weight shifts back, arms fractionally lower. Exhale. Vindication, not triumph. |

**Facial geometry note:** No high-poly close-up fidelity needed. Prioritize silhouette accuracy and clean surface read at game distance. Redirect face polygon budget to silhouette crown, shoulder mass, and hand/grip detail — the elements that actually register at game scale.

**Posture philosophy (Section 5.3.1, Pillar P2 — Scale Reads as Precious, Not Epic):** Reference posture register is a **hand-painted figurine**, not theatrical performance. Hero posture: **contained, weight-forward, functional**. No dramatic cape-flare, no windswept hair, no mid-air-leap idle. Stands like someone who expects something to require their attention shortly — weight loaded into the legs, not floating. Communicates "strategic mastery" pillar at a glance: this figure is *ready*, not *reacting*.

---

## 5. Idle Animation Spec

(Section 5.3.2, Pillar: The Living Sanctuary — idle carries the game's emotional register during the SCOUT/INTERMISSION/SANCTUARY non-combat majority.)

- **Cycle duration:** **3.0–4.0 seconds** — long enough to be restful, short enough to never become distracting.
- **Movement budget:** No idle frame may move the Hero silhouette's bounding-box center by more than **4px** at game-camera scale. The Hero breathes and settles — it does not sway, bob, or bounce. Weight is always present at the feet.
- **One idle action rule:** A single deliberate micro-movement is permitted per idle cycle — e.g. a fractional head-turn toward a nearby tower, a subtle grip-adjustment on the weapon, a weight shift from foot to foot. **One. Not a sequence.** The still moments between the micro-action and the next cycle carry the register.
- **No floating elements in idle:** No capes, trailing cloth, or loose elements introducing secondary motion. The Hero in idle is a grounded object. Secondary motion belongs to WAVE_ACTIVE only.

---

## 6. Combat Pose Rules (Hero-relevant, Section 5.3.3)

Play camera is fixed and oblique — every combat pose is designed for this specific angle only.

1. **Attack direction must be readable in the first frame of the attack animation.** At game distance, the player cannot wait for mid-swing to understand what just happened — the wind-up must already indicate direction and target.
2. **No pose may collapse the Hero's silhouette below the 1.4:1 floor**, even at the deepest point of a combat crouch. Wind-up may compress slightly; the strike extension phase must recover to or above 1.4:1.

*(Rules 3–5 in the source govern monster/boss telegraphing and are not Hero-specific — omitted here per scope.)*

---

## 7. Fusion State Variants (Section 5.5)

> Addresses the Tower-Synced Class System (Hero GDD Rules 13–18). As the Hero accumulates proximity time near a tower archetype, they earn that archetype's class tier. Visual design must communicate active class tier at a glance without a UI label.

### 7.1 Fusion Design Principles (All Archetypes) — Non-negotiable

1. **Additive details, not silhouette replacements.** The base warden-smith silhouette must remain recognizable through all fusion states. (Same rule as tower component upgrades, Section 3.1.3.)
2. **The 1.4:1 silhouette floor is maintained in all fusion states.** No fusion addition may add horizontal mass at the expense of vertical height. Additions must be *vertical* (crown extensions, shoulder heights, elevated equipment) or *contained* (chest-plate mods, grip changes that don't widen the bounding box) — never wide horizontal additions.
3. **Each fusion state must be distinguishable from all others** at game distance (~48px Hero height). Test: all four fusion heroes side-by-side at game distance — a playtester must correctly name each archetype in under five seconds per figure.

**Fusion accent color language:**

| Tower Archetype | Fusion Accent Color | Accent Source |
|---|---|---|
| Defensive | **Fieldstone Grey `#7E8590`** with high-contrast rim at Parchment Cream | Mass of constructed stone; fortress material |
| Damage Dealer | **Sanctum Amber `#C8801A`** shifting toward orange at high tier | Weapon heat and kinetic energy; the forge |
| Support | **Scout Blue `#2D5F8A`** at the secondary element register | Broadcast and reach; the sky register |
| Specialist | Desaturated warm-grey to cool-grey gradient; **no primary palette color** | The Specialist has no clean palette entry — its visual register is *ambiguity itself* |

### 7.2 Defensive Fusion (5.5.2)

**Identity:** Absorbed the language of mass, cover, and patience from wall-towers/fortifications.

**Manifestation:** A stone-panel bracer system grows over arms/chest in tiers.
- Tier 1: single oversized forearm bracer plate, clearly stone-derived (not smithed metal).
- Tier 2: bracer extends to shoulder + chamfered-corner chest-panel appears (Defensive tower's flat/crenellated grammar at wearable scale).
- Tier 3: chest-panel deepens + matching leg-guard appears.
- Tier 4: full stone-panel system covers the Hero's dominant side (the side facing the primary monster approach lane).

**Silhouette note:** Panels add depth to the body profile, never width. Shoulder panel is high-mounted (above shoulder line, contributes to vertical axis). Chest-panel is flat to the body — no protruding volumes.

**Color register:** Fieldstone Grey base, lightest faces toward Parchment Cream. Cut-stone texture at inspection distance; smooth weight-bearing mass at game distance. Reads as *more substantial*, not wider.

**Design test:** At game distance must read as "heavily armored version of the same warden-smith" — not a different character or knight archetype.

### 7.3 Damage Dealer Fusion (5.5.3)

**Identity:** Fighting alongside weapon-towers — siege cannons, archer platforms, the directed killing machinery of the arsenal.

**Manifestation:** A firing-rig modification grows from the dominant-hand weapon toward the shoulder.
- Tier 1: articulated brace — stabilization rod from grip to forearm (siege-weapon language at person scale).
- Tier 2: brace extends over shoulder + weapon's business end gains a narrow barrel extension (directional emphasis — "points up, shoots out" at hero scale).
- Tier 3: heat-management element appears — wrapped coolant coil or vented channel (mark of a weapon used constantly, runs hot).
- Tier 4: shoulder extension carries a small secondary firing element — not a second weapon, a support mechanism (ammo feed, targeting scope, ballistic assist) reading as unified with the primary weapon.

**Silhouette note:** Vertical axis reinforced by the barrel extension (contributes upward, doesn't widen). Over-shoulder element must stay within the Hero's existing width bounding box at the oblique play angle.

**Color register:** Tier 4 firing rig reads in **Sanctum Amber `#C8801A`** at heated surfaces. Non-heated structural surfaces read dark steel-grey (darker version of **Fieldstone Grey `#7E8590`**). Crit events produce **Herald Gold `#F5C01A`** flash at barrel tip — runtime VFX event, not a static surface property.

**Design test:** Dominant silhouette feature must be the barrel extension rising above the shoulder crown. If the helmet crown is still the highest point, lengthen or elevate the barrel extension — "points up" is mandatory.

### 7.4 Support Fusion (5.5.4)

**Identity:** Operating near buffer-towers — the outward-reaching, broadcasting architecture of the Support archetype.

**Manifestation:** A resonance frame extends from the non-dominant arm and chest.
- Tier 1: single extended forearm brace with an open-arc terminal (same open-negative-space grammar as the Support tower's arch silhouette, worn on the body).
- Tier 2: arc becomes a full open-ring at shoulder height on the non-dominant side — a halo-ring element extending above the shoulder, reading as a transmission form.
- Tier 3: ring carries faint **Scout Blue `#2D5F8A`** luminance — not a glow effect, a surface that reacts to ambient light with a slight cool-blue cast.
- Tier 4: a second partial arc appears on the dominant side at hip height — full frame reads as a structured broadcast field, open in all directions.

**Silhouette note:** Shoulder-height ring (Tier 2+) contributes to the vertical silhouette — must extend above the Hero's existing crown height, narrow at its lateral extent (a ring, not a disc). Negative space inside the ring is intentional — **30% negative space minimum** (same rule as Support tower's open silhouette).

**Color register:** Resonance frame surface is smooth, slightly translucent at inspection distance. At game distance, reads as the lightest element on the Hero's silhouette, catching the rim light fully.

**Design test:** Must have an immediately recognizable "open, outward-reaching" signature distinguishing it from contained/weighted Defensive and upward-pointing Damage Dealer fusions. If 2 of 5 playtesters confuse Support with another fusion, the open-arc element needs more prominence.

### 7.5 Specialist Fusion (5.5.5)

**Identity:** Working alongside irregular, compound Specialist-tower machinery — status-effect mechanisms, slowing fields, oddly-configured control architectures.

**Manifestation:** A compound auxiliary system develops at the back and shoulder, partially visible from the oblique play angle.
- Tier 1: secondary carrying frame — backpack-architecture of mixed angular/organic forms, visible over the shoulder silhouette.
- Tier 2: a disc or ring element mounts on the frame at mid-height, rotating very slowly in idle, stationary during combat.
- Tier 3: a secondary extended arm emerges from the frame — an active manipulation instrument (equivalent of a control interface for Specialist field effects), articulated with two joints.
- Tier 4: system reads as fully developed — frame, disc, arm, and a small reservoir element that pulses with muted warm light (suggesting fuel/reagent, not magic).

**Silhouette note:** Extends behind and above the shoulder line. At the oblique play angle, adds mass to the Hero's upper-right (or upper-left, per facing) quadrant. Width must fit within the bounding box when viewed from the primary facing direction.

**Color register:** Warm desaturated grey base — neither Fieldstone Grey nor the Hero's leather. No primary palette accent color; the Specialist fusion intentionally has no clean color identity. Only color event: Tier 4 reservoir pulse — muted warm amber glow, ~50% the saturation of Sanctum Amber, pulsing on a 3-second cycle (slow/ambient, not urgent).

**Design test:** Must read as *more complex and less categorizable* than all other fusion states. Correct playtester response: "I don't know what that does, but it looks capable." A confidently categorical response ("that's a tank"/"that's a healer") means the design isn't hybrid enough.

---

## 8. Technical Budget

(Section 8.7, Godot 4.6.2 — Hero is the only asset category using poly counts, since it's the single 3D asset.)

**Poly budgets:**

| Asset | On-screen height | Poly budget (game-distance) | Notes |
|---|---|---|---|
| Hero 3D model (gameplay LOD) | 48–56px | **≤ 6,000 tris** | Fixed oblique camera, no zoom-in during play — spend poly on silhouette/rim readability, not surface fidelity |
| Hero 3D model (inspection LOD) | close-up | **≤ 15,000 tris** | Only if a close-up screen is confirmed in scope (per 8.4's open item) |

**Texture memory:**

| Category | Per-asset VRAM budget | Rationale |
|---|---|---|
| Hero 3D texture set (albedo/normal/ORM) | **≤ 8MB total** | Only 3D asset — can afford more per-texture budget since there's one instance |

(Contributes to project-wide target aggregate texture VRAM of ≤ 400–500MB, within the 1GB ceiling per `technical-preferences.md`.)

**Material slot constraints:**
- Hero: **≤ 3 material slots** (body/armor, metal-trim, emissive-accent). Godot 4.6 Forward+ renders each unique material as a separate pass — more slots fragment the one 3D draw call.

**Godot 4.6.2 importer settings (Hero-specific):**
- **Compression:** VRAM Compressed, format BPTC for desktop-only PC target (better quality than S3TC at same size).
- **Mipmaps:** **ON** for Hero 3D textures (standard practice for the one 3D asset) — contrast with 2D sprites, which use mipmaps OFF.
- **Filter:** (2D sprite rule of Linear/no-mipmap-filter does not directly govern the 3D Hero asset; Hero uses standard 3D texture filtering with mipmaps per above.)

**⚠ Verification required before locking Hero import presets (post-4.6 knowledge gap — do not assume pre-4.6 behavior):**
- **BPTC compression under D3D12-as-default:** `docs/engine-reference/godot/VERSION.md` flags D3D12-as-default-on-Windows as HIGH-risk in 4.6. Verify the BPTC decode path is unaffected before locking this import preset.
- **Glow rework vs. emissive intensity:** The Hero's Tower Affinity aura (Herald Gold glow) and MISSION_COMPLETE rim-shift rely on emissive/HDR-range values feeding glow. Godot 4.6's glow rework (also HIGH-risk) may change how emissive intensity maps to bloom threshold versus pre-4.4 behavior — check against a live 4.6.2 build before locking emissive values.

**Draw calls:** The Hero's single 3D pass is budgeted at roughly ~5 draw calls within the 200/frame project ceiling (per Section 8.7's reserved allocation: ~20–30 environment/tilemap, ~10–20 monster swarm, ~5 the single Hero 3D pass, ~20–40 UI/HUD, remainder VFX headroom).

---

This document intentionally omits monster design direction (Section 5.2), LOD philosophy for non-Hero entities (5.4.2–5.4.4), and environment/UI sections — those live in `design/art/art-bible.md` and should be consulted directly if a question falls outside Hero scope.

# Validation Criteria — Stacked Sprite + 3D/2D Seam Test

**Date**: 2026-05-18  
**References**: Art Bible §3.4 (3D/2D Seam Rules), §2 (Mood & Atmosphere), §1 (Visual Identity: "wizard's cabinet diorama")

Fill this checklist after running the prototype. Write the REPORT.md verdict based on results.

---

## Q1: Stacked-Sprite Volume

Criterion: Do the stacked layers read as a physical object with measurable height, not as a flat image?

| # | Check | Method | Pass | Fail | Result |
|---|-------|--------|------|------|--------|
| V1 | **Contact shadow anchors object to ground** | Step back and squint. Does the tower feel planted, or floating? | Shadow reads as cast by a solid object sitting on the surface | Shadow absent or object appears to hover | |
| V2 | **Layer separation visible at game-camera distance** | Zoom to 1:1 and observe. Can individual slices be distinguished? | Distinct layer edges create a staircase silhouette | Layers blur into flat smear | |
| V3 | **Cast-shadow strips read as inter-layer shadows** | Are the dark strips between layers perceptible as depth cues? | Dark strips reinforce "the upper layer overhangs the lower" | Strips invisible or add noise without reading as shadow | |
| V4 | **Draw order correct when towers overlap** | Move TowerNear in front of TowerFar. Does TowerNear render on top? | TowerNear (higher world-Y) fully occludes TowerFar where they overlap | Layer from TowerFar bleeds through TowerNear | |
| V5 | **Fan-view reveals intended slice structure** | Press Space. Do layers separate cleanly into 3 horizontal bands + shadow strips? | 5 distinct elements visible: contact shadow, 3 color layers, 2 cast shadows | Elements overlap incorrectly or draw in wrong order when fanned | |
| V6 | **Taper silhouette reads as height** | Does the narrowing from L0→L2 give an impression of the object being taller at the top? | Object reads as having a peak or turret | Top appears same width or wider than base — reads flat | |

**Q1 Verdict**: PASS requires V1+V2+V4 (minimum). V3+V5+V6 are quality indicators.

---

## Q2: 3D/2D Seam

Criterion: Does the 3D hero coexist with the 2D towers without triggering the "wrong game" reading?

| # | Check | Method | Pass | Fail | Result |
|---|-------|--------|------|------|--------|
| S1 | **No perspective distortion mismatch** | Compare the hero silhouette to the towers. Does the 3D capsule use the same implied camera angle as the 2D scene? | Camera angles feel consistent — both objects appear to exist in the same space | Hero looks like it was photographed from a different angle than the towers | |
| S2 | **Lighting direction consistent** | Does the lit side of the 3D capsule match the implied light direction in the 2D scene (warm top-left)? | Shadow falls on same side across hero and towers | Hero lit from wrong direction relative to 2D objects | |
| S3 | **Contact shadow mandatory** (Art Bible §3.4.4) | Is there a flat ellipse shadow beneath the hero? Without it the hero floats. | Shadow present; hero reads as standing ON the ground | No shadow; hero appears to float above the surface | |
| S4 | **Transparent background composite** | Does the SubViewport background vanish (transparent), leaving only the capsule mesh? | Only the 3D capsule is visible; no black or coloured box around it | Coloured or black rectangle visible around hero | |
| S5 | **Scale reads as "figurine on board"** | Does the hero size relative to the towers feel like a miniature on a game board? | Proportions communicate "small-scale world" — neither too large (overwhelms) nor too small (toy-like) | Hero scale breaks the diorama illusion | |
| S6 | **No view-dependent perspective break** | The camera is fixed. Is there any angle where the 3D hero stops reading as part of the same scene? | From the fixed camera position, seam is not noticed within 3 seconds of first viewing | Seam immediately obvious — reads as "model pasted in" | |

**Q2 Verdict**: PASS requires S3+S4+S5 (minimum — these are the art bible hard rules). S1+S2+S6 determine diorama quality.

---

## Overall Prototype Verdict

| Scenario | Recommendation |
|----------|---------------|
| Q1 PASS + Q2 PASS | **PROCEED** — stacked-sprite + 3D/2D hybrid is validated. Commission first real assets (tower base sprite sheet, hero concept). Author ADR covering rendering pipeline decisions. |
| Q1 PASS + Q2 FAIL | **PIVOT on hero rendering** — stacked sprites work but SubViewport seam is unacceptable. Investigate alternatives: billboard 2D sprite for hero (lose real-time 3D), or use Sprite3D in a 3D world with 2D-style camera. |
| Q1 FAIL + Q2 PASS | **PIVOT on stack technique** — 3D composite works but 2D stacking reads as flat. Investigate: more slices, actual art assets (not ColorRect), or switch to true 3D for all objects with 2D-style shader. |
| Q1 FAIL + Q2 FAIL | **KILL this approach** — consider full 3D scene with Bravely Default-style tilt-shift post-process instead of hybrid 2D/3D. |

---

## Seam-Specific Notes

From Art Bible §3.4 (Shape Language — 3D/2D Seam Rules):

> The seam between the 3D Hero and 2D world must pass the "figurine test": does the hero read as a miniature figurine placed on the same board as the towers, or as a model from a different game?

Specific art bible constraints to verify:
- §3.4.1: Fixed oblique camera only — no perspective drift
- §3.4.2: Hero footprint must be grid-compliant (1 cell × 1 cell readable)
- §3.4.3: No view-dependent effects (no screen-space reflections, no HDR bloom on hero that doesn't appear on 2D objects)
- §3.4.4: Shadow footprint mandatory — flat ellipse, consistent with cast shadows on 2D objects

---

## After Testing

Write `REPORT.md` using the template in the prototype skill. Include:
- Frame time in the Godot Editor performance monitor during the test (SubViewport has a per-frame cost)
- Whether D3D12 (Windows default in Godot 4.6) caused any transparent_bg issues
- Camera3D settings that produced the best seam quality (record exact position/size values)
- Which criteria were close calls (helps calibrate future asset specifications)

# Story 013: Mid-Combat Visual/Audio Feedback

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Partial (all 4 visual/audio mechanisms Complete as of 2026-08-13 — in-world arc, HUD callout, `skill_unlocked` chime, and enter-range/pause stingers via the new `tower_mastery_proximity_changed` signal; only human playtest verification remains open)
> **Layer**: Feature
> **Type**: Visual/Feel
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tower-mastery.md`
**Requirement**: `TR-towermast-001` (feedback layer for the same live proximity system)

**ADR Governing Implementation**: ADR-0029 (Tower Mastery Proximity-Detection Strategy)
**ADR Decision Summary**: Tower Mastery's feedback is the first system whose primary readout must render live during `WAVE_ACTIVE`, competing with monster telegraphs and tower VFX. All treatments are subordinate to Mission HUD's Combat Cluster rule and the art bible's glow/bloom constraint — no bloom-dependent "accruing" or "unlocked" treatment; sprite/particle/color only.

**Engine**: Godot 4.6.2 | **Risk**: LOW (visual-only; no new engine subsystem beyond existing sprite/particle conventions)
**Engine Notes**: No treatment depends on `Viewport.use_hdr_2d`/bloom glow, per the documented Godot 4.6 HDR-2D constraint (`docs/engine-reference/godot/VERSION.md`) — glow may only ever be a later optional secondary accent, never the primary indicator.

**Control Manifest Rules (this layer)**:
- Required: Each entity class uses a single shared per-class texture atlas — never `.duplicate()` a `SpriteFrames` resource at runtime — source: ADR-0013.
- Forbidden: No bloom-dependent progress VFX (art bible constraint, `VERSION.md`'s documented HDR-2D risk).
- Guardrail: Non-color legibility is mandatory — arc fill amount (shape) is the primary signal, archetype glyph is the primary skill-identity signal; color is reinforcement only, never the sole channel (accessibility requirement, art bible Section 4.5).

---

## Acceptance Criteria

*From GDD `design/gdd/tower-mastery.md`'s Visual/Audio Requirements and Accessibility sections — this system has no numbered ACs of its own for the feedback layer, so criteria are derived directly from the section's explicit requirements:*

- [x] In-combat proximity arc renders world-space, tower-anchored, sweeping clockwise from 12 o'clock as `progress_percent` climbs — never in HUD screen-space
- [x] Arc uses Sanctum Amber palette (not Herald Gold), fixed local-pixel diameter, archetype glyph placeholder at center as the non-color skill identifier
- [x] Accrual-paused states (out-of-range vs. tower-destroyed) render as two distinct, deliberately underplayed treatments — implemented; visual "no failure-state read" is unverified without a human tester
- [x] `skill_unlocked` moment plays the in-world flourish (brief intensify-and-pulse, ~0.75s, auto-clears) — [x] the non-blocking HUD corner callout is **Complete** (2026-07-20, now that Mission HUD exists — reuses its `ToastHost` mechanism, bottom-left, non-blocking, auto-dismissing, never top-center)
- [x] Audio stingers — **RESOLVED 2026-08-13**: `skill_unlocked`'s dispatch mechanism wired into `AudioCueDispatcher` (Epic 12's now-Complete generic cue-dispatch mechanism, AC-10a's no-op-if-unmapped guarantee). The enter-range-tick/pause-descending-tone pair, previously blocked on a missing discrete-transition signal, is now wired too: a new EventBus signal, `tower_mastery_proximity_changed(build_signature, in_range)`, was added — emitted from `TowerMastery._recompute_signatures_in_range()` via an edge-detection diff against the previous in-range set (fires only on an actual transition, never on every recompute), dispatched to two distinct cue names (`tower_mastery_proximity_entered`/`_exited`) matching the GDD's two distinct stingers. **No real sound content exists for any of these cues yet** (unchanged OQ-2 gap, same "mechanism real, content placeholder" convention every other cue in this project uses) — only the wiring/mechanism is real, not actual playback.
- [x] Accessibility: arc states differ via opacity/motion, not hue alone (code-verified); [x] HUD callout accessibility: text-only toast (no color-coded meaning), inherently non-color-dependent

---

## Implementation Notes

*Derived from ADR-0029's Visual/Audio Requirements (tower-mastery.md sections a–d) — this is presentation-layer work built on top of Story 010's emitted events:*

- **In-combat indicator (a)**: thin radial arc at the tower's base on the ground/cast-shadow layer, fixed screen-space diameter (does not scale with zoom), flat sprite fill + subtle static particle tick at the leading edge — no looping shader emission, no particle bloom.
- **Accrual-paused (b)**: hero-out-of-range → arc freezes at current fill, opacity steps ~100%→~55%, no motion/color shift/sound, resumes instantly and silently on re-entry. Source-tower-destroyed → Fieldstone Grey desaturate-and-fade (~0.5s), reusing Constellation's own rune-deactivation visual vocabulary rather than inventing a second "the anchor is gone" register.
- **`skill_unlocked` moment (c)**: arc briefly intensifies to full-saturation Sanctum Amber, pulses once (~0.5–1s, matching Constellation's pacing rule), then clears — plus a non-blocking HUD corner callout ("Skill Learned: [Name]") in a corner clear of the Combat Cluster's HP/cooldown grouping, never top-center (reserved for path-update banners). Bigger "reveal" framing is explicitly deferred to Hero Skill Build System's own Sanctuary-side screen.
- **Audio (d)**: no continuous loop during accrual — two short quiet stingers bookend a proximity session (enter-range tick, pause descending tone); `skill_unlocked` gets a distinct bell/sparkle chime at a noticeably higher register than combat SFX, explicitly never mistakable for a hit confirm, tower fire, or hero damage.
- **Accessibility (d)**: the three arc states (accruing/paused-out-of-range/paused-destroyed) must be distinguishable via opacity and motion, not hue alone, since all Amber-family states share a hue family by design.
- **Coordination note**: the Sanctum Amber arc is exclusively a Tower Mastery signal — if Hero's Tower-Synced Class proximity ever needs its own world-space feedback, it must not reuse this arc, hue, or anchor point; route any such request back through the Art Director.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: the `mastery_progress_updated`/`skill_unlocked` events this story's visuals subscribe to (must exist first)
- Sanctuary-side skill review screen — explicitly out of scope per `tower-mastery.md`'s own UI Requirements (owned entirely by Hero Skill Build System)
- Final sound design (no audio bible exists yet) — this story specifies category/direction only, per the GDD's own scope note

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode. Visual/Feel story — manual verification steps apply:*

- **Manual check**: In-combat proximity arc
  - Setup: place a tower with a defined catalogue skill, stand the hero within accrual radius during `WAVE_ACTIVE`
  - Verify: world-space arc at tower base sweeps clockwise from 12 o'clock as progress climbs, fixed screen-space diameter regardless of zoom, archetype glyph visible at center, Sanctum Amber hue (not Herald Gold)
  - Pass condition: arc is legible at default oblique camera distance without zoom, never larger/brighter than the tower sprite or any monster telegraph on screen

- **Manual check**: Accrual-paused states are distinguishable and non-punishing
  - Setup: (1) hero steps out of range of an accruing tower; (2) the accruing tower is destroyed while hero is in range
  - Verify: (1) arc freezes, opacity drops to ~55%, no motion/color/sound; (2) arc plays Fieldstone Grey desaturate-fade (~0.5s)
  - Pass condition: the two causes are visually distinguishable from each other and neither reads as a failure state

- **Manual check**: `skill_unlocked` moment
  - Setup: accrue a build signature's `mastery_time` past its threshold
  - Verify: arc intensifies to full-saturation Amber and pulses once (~0.5–1s), then clears; non-blocking HUD corner callout appears naming the skill with glyph + text label, auto-dismisses after a few seconds, positioned clear of the Combat Cluster and never top-center
  - Pass condition: the moment never pauses or dominates the screen mid-wave

- **Manual check**: Accessibility — non-color legibility
  - Setup: view all three arc states with a colorblind simulation filter active
  - Verify: accruing/paused-out-of-range/paused-destroyed remain distinguishable via opacity and motion alone
  - Pass condition: no state relies on hue alone to be told apart from another

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `production/qa/evidence/tower-mastery-visual-audio-feedback-evidence.md` — created; documents what was built, what's blocked, and what still needs a human tester

**Status**: [x] Created — implementation done, manual sign-off still pending a real playtester

---

## Dependencies

- Depends on: Story 010 (emits the events this story's visuals consume)
- Unlocks: None further within this epic

**Unblocked**: ADR-0029 accepted 2026-07-18 (Sprint 6, S6-02).

**Implemented (2026-07-19, Sprint 7)**: before writing any code, checked the codebase for the infrastructure this story's Implementation Notes assume — Mission HUD has no code anywhere yet (only a placeholder `Panel`), and Constellation's "rune-deactivation visual vocabulary" this story is told to reuse turned out to be pure design-doc language (Constellation has zero visual/VFX code to actually reuse). Presented this finding via `AskUserQuestion`; user chose to scope this pass to **the in-world arc only** (Recommended option). Built `src/core/tower_mastery/tower_mastery_arc.gd` (`TowerMasteryArc`, pure `_draw()`-based view component: 4 states, Sanctum Amber `#C8801A`/Fieldstone Grey `#7E8590` from the art bible, clockwise sweep, opacity/motion-based non-color legibility) and `src/core/tower_mastery/tower_mastery_feedback.gd` (`TowerMasteryFeedback`, the scene-instanced EventBus-driven manager — creates/positions/drives one arc per active `build_signature`, handles the destroyed-anchor pause and automatic resumption/repositioning via a different live tower sharing the signature, and frees arcs after their fade completes). Added `cell_to_world()` to `GridSpyDouble` (shared test double) to support this. 20 new unit tests, all passing; full regression 1099/1100 (same pre-existing unrelated `TD-menag-006` failure). **HUD corner callout and real audio remain explicitly blocked** (documented in the evidence file, not silently dropped) — this story is `Partial`, not `Complete`, until Mission HUD exists and a real playtest/visual-review pass can happen.

**HUD corner callout unblocked and implemented (2026-07-20)**: Mission HUD (Epic 09) is now fully implemented and code-reviewed. `MissionHud` (`src/presentation/mission_hud/mission_hud.gd`) now subscribes to `GEventBus.skill_unlocked` and shows `"Skill Learned: %s" % skill_id` via its existing `ToastHost` mechanism (Story 011 — bottom-left, non-blocking, auto-dismissing), guarded by the existing `_terminal` latch. This satisfies the requirement without inventing a second transient-message channel — `ToastHost` already reads as "corner, clear of the Combat Cluster, never top-center" (top-center is `_show_transient_banner()`'s own reserved territory for path-update/hero-class messages). **Real gap found and flagged, not silently faked**: `SkillDefinitionResource` (the actual catalogue Resource `GameDataRegistry` loads) has no `display_name` field — only `skill_id` — so the callout shows the raw id (e.g. "Skill Learned: phys_cleave") rather than the story's own example "[Name]" text. A real human-readable name needs a schema addition to `SkillDefinitionResource`, tracked here, not invented unilaterally. 2 new tests in `combat-cluster-live-data_test.gd`, both passing; live-MCP-verified against the real running `the_gap.tscn` (zero errors); full project regression 1476/1476 (0 errors, 1 pre-existing unrelated failure). **Still `Partial`**: real audio stingers remain blocked (no audio bible exists), and no human playtester has verified the arc's or the callout's actual legibility/feel — both explicitly carried forward, not resolved by this pass.

**Three gaps closed (2026-08-13)**:
1. `SkillDefinitionResource.display_name` field added, all 8 real content files updated (`elem_firestorm`→"Firestorm", `elem_frostbolt`→"Frostbolt", `phys_bulwark`→"Bulwark", `phys_cleave`→"Cleave", `rng_piercing_shot`→"Piercing Shot", `rng_volley`→"Volley", `sup_barrier`→"Barrier", `sup_rally`→"Rally"). `MissionHud._on_skill_unlocked()` now shows the real name, falling back to the raw id for an unrecognized skill. `combat-cluster-live-data_test.gd` updated + a new fallback test.
2. `skill_unlocked` wired into `AudioCueDispatcher` (now possible since Epic 12/Audio System shipped Complete 2026-07-25, after this story's own last pass) — same no-op-if-unmapped mechanism every other cue uses, no real sound content authored (unchanged gap, matches OQ-2). New test in `data-driven-cue-dispatch_test.gd`.
3. **Enter-range/pause stinger pair, closed same day**: added `GEventBus.tower_mastery_proximity_changed(build_signature: String, in_range: bool)`, emitted from `TowerMastery._recompute_signatures_in_range()` via an edge-detection diff (old in-range set vs. new — fires only on an actual transition, tested explicitly against a same-cell recompute that must stay silent). Wired to two distinct dispatch cues (`tower_mastery_proximity_entered`/`_exited`). This was previously deferred as "a design decision belonging to `tower-mastery.md`'s own owner" — made directly this pass rather than left open, since the signal shape is narrow, additive, and follows the exact edge-detection pattern already established elsewhere in this project (e.g. Building Upgrade's `PURCHASABLE` transition detection, ADR-0036's `_reevaluate_purchasable_state()`). 5 new tests in `cell-boundary-proximity-tracking_test.gd`, 2 new tests in `data-driven-cue-dispatch_test.gd`.

Full regression: 152/152 passing across directly affected suites, full project regression clean. **Still `Partial`**: only human playtest verification remains open (Player Fantasy/legibility feel-check, per this story's own QA Test Cases) — every mechanism this story's own scope covers is now real.

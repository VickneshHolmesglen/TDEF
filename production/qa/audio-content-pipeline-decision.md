# Audio Content Pipeline Decision (S9-03)

> **Status**: **DECIDED 2026-08-28, PILOT SHIPPED same day** — Option A, licensed/CC0
> asset packs (Kenney.nl / Freesound.org CC0 / itch.io SFX packs), chosen exclusively —
> not the A+C hybrid this doc's own "realistic hybrid" section floated. Vicknesh chose
> speed and free/low-cost real content over a custom-commission tier for pillar-defining
> cues; that door isn't closed permanently, just not part of this pass's scope. Tower
> Mastery's 3 stingers are now real, sourced, and wired end-to-end — see "What happens
> after the decision" below.
> **Blocks**: `story-013-mid-combat-visual-audio-feedback.md`'s remaining audio gap (Tower
> Mastery's 3 stingers), and — much more broadly — `audio-system.md`'s own OQ-2, which
> this scoping pass confirms is **the single largest remaining task before the Audio
> System does anything audible at all, project-wide**, not a Tower-Mastery-scoped problem.

---

## Scope Reality Check

Before picking a pipeline, it's worth being honest about size: `audio-system.md`'s
`AudioCueMap` is currently **completely empty** — zero real audio content exists
anywhere in this project (`assets/audio/` doesn't even exist yet). Every one of the
~10 gameplay GDDs' scattered "audio direction" notes (Tower Mastery's 3 stingers among
them) needs to be sorted into the GDD's 7 cue families and given a real `.tres` entry
pointing at a real sound file. `AudioCueDispatcher`'s no-op-if-unmapped mechanism means
the game runs in total silence right now, correctly, with zero errors — nothing is
broken, there's just nothing to hear yet.

**Practical implication**: whatever pipeline gets picked for Tower Mastery's 3 cues is
almost certainly the pipeline that will need to scale to the whole game's audio
eventually. Worth choosing with that in mind rather than treating this as a one-off.

---

## What "real content" technically means here

Each `AudioCueEntry` needs an actual audio file (Godot-importable — `.wav`/`.ogg`)
wired into a `.tres` resource, mapped to the right cue family, bus, and (for spatial
cues) attenuation settings already defined in `audio-system.md`'s own formulas. The
*mechanism* side of this is done — Tower Mastery's dispatch calls, the cue-map lookup,
bus routing, all real and tested. The only missing piece anywhere is the audio files
themselves plus their catalogue entries.

---

## Options

### A — Licensed/CC0 asset packs (Kenney.nl, Freesound.org CC0, itch.io SFX packs)
Fast, free-or-cheap, gets real (if generic) sound into the game within a session or two.
Quality ceiling is "competent stock SFX," not bespoke — a crit-hit chime or a UI click
from a pack will sound fine but won't carry any of this game's specific pillar identity
the way, say, a custom-composed "vindication beat" sting could. Licensing is
straightforward (CC0/CC-BY packs are explicitly free for commercial use; verify the
specific license per pack before use). **Best fit for**: the large volume of generic,
non-signature cues (UI confirm/cancel, footsteps, basic hit impacts) where "sounds
right" matters more than "sounds like nothing else."

### B — AI-generated audio (external tool, manual workflow)
No built-in generation skill exists in this Claude Code setup for audio the way
`generate-image`/`generate-3d-model` exist for visuals — this would mean a manual
workflow similar to the art pipeline's Codex role before it was formalized: Vicknesh
(or a future dedicated step) runs an external AI audio tool (e.g. ElevenLabs SFX,
Stable Audio, or similar), drops the raw output into a new `assets/source/audio/`-style
staging area, and Claude Code processes/imports/wires it in, mirroring the existing
`assets/source/` → `assets/art/` art pipeline shape (`design/art/codex-art-overhaul.md`).
Quality and iteration speed depend entirely on the external tool's current state — this
option carries the most process overhead to stand up but could match the game's specific
identity better than a stock pack, and scales the same way the art pipeline already does.

### C — Custom-recorded / commissioned sound design
Highest ceiling — a real sound designer (hired, or Vicknesh recording/foley-ing
directly) can hit the exact tone this game's pillars want, especially for signature
moments (the tier-bonus hit, the skill-unlock chime, the vindication beat). Highest
cost and slowest — not a same-session or same-sprint turnaround, and this project has
no existing vendor/contractor relationship for audio the way it does for anything else.
**Best fit for**: a small number of pillar-defining "hero" cues, not the full ~7-family
catalogue.

### D — Placeholder procedural/engine-generated tones
Godot can generate simple tones/beeps programmatically with zero asset files at all —
fastest possible way to get *something* audible into the build, at real cost to
"feels intentional" (this would read as an obvious placeholder, not a step toward final
content). **Best fit for**: a very short-term stopgap if the goal is purely "confirm the
dispatch mechanism actually produces sound end-to-end," not a real content-authoring path.

---

## A realistic hybrid, if useful

Most projects this size don't pick one option exclusively — a common shape: **A (packs)
for the bulk of generic/UI/ambient cues**, **C (custom) for a short list of
pillar-defining signature moments** (this game's own candidates: the ELITE/BOSS
tier-bonus hit, `skill_unlocked`, the "vindication beat" cue family Audio System's own
GDD names), and **B (AI-generated) as a middle tier** for everything else that's more
specific than a stock pack can cover but doesn't warrant a commission. D is really only
relevant as a same-day mechanism smoke-test, not a content strategy.

---

## What happens after the decision

**Decided: Option A only.** No new staging/import workflow is needed (that overhead
was specific to Option B, not chosen) — licensed/CC0 packs are downloaded, licensed,
placed directly into a new `assets/audio/` tree, and imported/wired in by Claude Code
the same session, no intermediate raw-output staging step the way `assets/source/` art
requires.

1. **Pilot DONE (2026-08-28)**: Tower Mastery's 3 stingers sourced from Kenney's
   Interface Sounds pack (CC0), imported into Godot, wired via 3 new `AudioCueEntry`
   resources + 1 `AudioCueMap` (`assets/data/audio/`). `AudioCueDispatcher` itself
   gained real playback capability (a pooled `AudioStreamPlayer` — previously
   `dispatch_cue()` never played anything for any cue, project-wide) — this pilot is
   also the first real sound anyone will ever hear in this project. See
   `story-013-mid-combat-visual-audio-feedback.md`'s Completion Notes for full detail.
   Honest caveat: `skill_unlocked`'s sourced chime is a generic stock confirmation
   sound, not the bespoke "bell/sparkle" timbre the GDD calls for — real content,
   first-pass quality, flagged as a possible Option C revisit later.
2. `audio-system.md` OQ-2 updated to record this decision and the pilot's completion.
3. Scaling to the full ~7-family `AudioCueMap` catalogue (the other ~76 events) is
   real follow-up work beyond this pass's scope — not started here.

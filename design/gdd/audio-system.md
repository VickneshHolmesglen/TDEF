# Audio System

> **Status**: Approved (2026-07-24 — full `/design-review` [game-designer, systems-designer, qa-lead, audio-director (2nd adversarial pass), godot-specialist, creative-director] found NEEDS REVISION on first pass: one untestable AC, an unearned second-pillar Player Fantasy claim [The Sanctuary Is Your Statement had no implementing mechanic], an oversold architectural headline claim, a Godot data-structure implementability risk, an ambiguous bus-routing description, an unhandled transition-timing drift case, 4 of 6 cue families with no specified voice cap, 2 compound ACs, and one "closes a gap" claim not yet backed by the referenced document's own edit. Fixed same-session: split/rewrote the untestable AC, narrowed the Player Fantasy to its mechanically-supported pillar [demoting the other to a tracked Open Question], precisely reworded the architectural claim, switched to an implementable data structure, clarified the bus-routing model explicitly, added a resync fallback, added placeholder voice caps for all families [honestly flagged as unvalidated], split the compound ACs, and softened the cross-doc claim. Independently re-verified same-day by a fresh-context pass, which confirmed all 9 problems structurally closed and fixed 3 further minor residual issues [a broken AC cross-reference, a duplicated edge case, a subtly-overstated claim]. See `design/gdd/reviews/audio-system-review-log.md` for full detail.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-24
> **Implements Pillar**: Everything Connects (primary, mechanically implemented via Core Rules 3–4); echoes Mastery-as-Vindication through payoff-cue restraint, does not lead with it; The Sanctuary Is Your Statement is an aspirational future extension, not currently implemented — see OQ-5 (corrected 2026-07-24 during `/design-review`, which found the original "genuinely both primary" claim unearned)

## Overview

The Audio System is the sonic-identity layer that gives every other system's already-fired EventBus events a voice — it subscribes to 16 already-frozen events spanning nearly the entire game (mission phase transitions, tower combat, hero skills, discoveries, crafting, sanctuary construction) and answers each with music, ambient atmosphere, or a one-shot cue, without any of those 16 emitting systems needing to know Audio exists. It is the sonic sibling of `art-bible.md`'s Section 2 (Mood & Atmosphere) — where that document defines 6 game-state contexts by lighting, color temperature, and "Energy level," this document defines the same 6 contexts sonically, state-for-state, so the two senses agree at all times. Roughly 8–10 other already-written GDDs each independently wrote their own placeholder "Audio direction (category only, no audio bible yet)" section, naming specific expected cues without a shared vocabulary or home to plug into — this document is that home: the mix architecture, the cue-family taxonomy, and the ducking/priority discipline those scattered notes assume exists. It does not author the audio bible's actual content (specific SFX assets, music tracks) — that remains Full Vision-tier future work, same as every other system's own content-authoring is separate from its mechanical design.

## Player Fantasy

**The Game's Emotional Register, Made Audible**

**Revision note (2026-07-24, post `/design-review`)**: The original draft of this section claimed both Everything Connects and The Sanctuary Is Your Statement as "genuinely both primary." The design review found the second claim unearned — no event this system subscribes to carries continuous sanctuary-investment data (`sanctuary_structure_built` is a one-shot construction fanfare trigger, not an ambient-density signal), and no Core Rule, Formula, Tuning Knob, or AC anywhere implements it. The original text even hedged with "informally," which was itself a signal the claim was aspiration, not spec. This section is narrowed below to the pillar the mechanics actually deliver; the sanctuary-density ambition is preserved as Open Question OQ-5, matching this document's own habit of flagging real future seams rather than silently dropping them.

Audio's native register is not "supporting the fantasy of some other system" — it is the game's emotional state, at any given moment, communicated without a single word of UI text, mirroring the art bible's own explicit ambition for DEFEAT's visual design. **Everything Connects is this system's primary pillar**: the cue-family taxonomy (Core Rule 3) functions as a *sonic EventBus* — every one of the 9 gameplay systems' own milestone, denial, and confirm moments fires through the same limited, learnable vocabulary, so a player learns "that sound means discovery" or "that sound means denied" independent of which system triggered it, the same way the visual language already teaches "gold means achievement" project-wide. A player who has heard the Discovery/Milestone Fanfare family once in Constellation recognizes it instantly in Tarot, without either system needing to teach it separately. **Precision note**: what Core Rules 3–4 build today is the *architecture that enforces this vocabulary* (the taxonomy and generic dispatch mechanism) — the actual audible recognizability depends on the `AudioCueMap` being populated with real content sorted correctly into these families, which is still Open Question OQ-2's largely-unstarted work. The claim is mechanically grounded, not yet mechanically demonstrated.

Mastery-as-Vindication is present but deliberately not led with: payoff stings (constellation ignition, wave-clear, mastery tier-ups) are built to land as *confirmation*, never spectacle — the sound tells the player their plan worked, the same restrained register the art bible itself insists on for every visual payoff moment ("a payoff beat, not a spectacle"). Audio earns this pillar by matching the other two systems' own established restraint, not by claiming a louder share of it. **The Sanctuary Is Your Statement is not currently implemented by this document** (see OQ-5) — a future revision could genuinely earn it (e.g. an ambient-density formula keyed to a continuous sanctuary-occupancy signal, if one is ever added to the EventBus catalogue), but claiming it today would be the same unearned-fantasy mistake this project's own `sanctuary-ui.md` and `tarot-deck-ui.md` reviews already caught and corrected earlier tonight.

## Detailed Design

### Core Rules

**Core Rule 1 — Mix Bus Architecture: 4 Player-Facing Buses (Frozen by `accessibility-requirements.md`), Internal Sub-Routing Beneath Them**
`design/accessibility-requirements.md` already commits, at Basic tier, to **exactly 4 independently-adjustable volume sliders**: Music, SFX, Voice, UI (0–100% each, default 80%) — this is a binding, pre-existing constraint this document did not originate and must not silently deviate from. Internally, Audio routes a richer bus graph beneath those 4 player-facing controls: `Master (internal, no player slider) → {Music, SFX, Voice, UI}`, with **Ambient** sub-mixed as a true child bus under **Music** (a real node in the bus graph, inheriting Music's volume automatically) and the two SFX sub-categories — world-diegetic combat/environmental one-shots and UI-triggered confirms/denials — routed to the peer **SFX** and **UI** top-level buses respectively. **Clarification, closing a real ambiguity the design review found**: "world SFX" and "UI SFX" are a *routing-time content category* baked into each `AudioCueEntry.bus` field, not a shared bus-graph parent the way Ambient/Music is — there is no single "mute all SFX including UI" node in the graph, by design, since the whole point of the split is that UI feedback must never be muted alongside combat chaos. Core Rule 5's cross-bus ducking (SFX ↔ Ambient, UI ↔ Music+SFX) operates on this peer-bus reality directly, not on a nested-category assumption. A player adjusting the "SFX" slider hears combat impacts and milestone fanfares change together; a player adjusting "UI" hears only menu/confirm/denial sounds change, independent of combat volume. **Voice** is reserved, unused today (no VO content exists or is planned at MVP/Alpha scope) but the slider must still exist and function per the accessibility commitment, even silently — see Open Question OQ-6 for the real player-facing risk this creates.

**Core Rule 2 — State-Driven Music and Ambient, Mapped 1:1 to `art-bible.md`'s 6 Game-State Energy Levels**
Music and Ambient behave differently on a state transition (`mission_phase_changed`), matching `art-bible.md` Section 2's own "no state may hard-cut" lighting discipline for Music, while Ambient earns a different treatment appropriate to atmosphere:
- **Music**: one continuous stem per distinct Energy level (`Contemplative` — SANCTUARY/MISSION_COMPLETE/DEFEAT; `Measured` — SCOUT; `Urgent` — WAVE_ACTIVE; `Measured-urgent` — INTERMISSION), **crossfaded** on state entry, never hard-cut, **except** the one deliberate exception below.
- **Ambient**: a continuous base environmental bed (sanctuary room tone, wind, distant footsteps) that never fully restarts across a state transition; state-specific **layers** (dust-mote hush, grid-hum, combat clash-bed, lingering smoke-crackle) fade in/out **additively** over that base. This mirrors `art-bible.md`'s own INTERMISSION note almost exactly ("same calm energy as SCOUT, but earned and temporary" — residual smoke is a residual *audio* layer here, not a fresh mix).
- **SCOUT → WAVE_ACTIVE (the anticipation transition)**: begins on `wave_countdown_warning`'s 10-second signal, not on `mission_phase_changed` itself — Music starts a 3–4 second crossfade from `Measured` to `Urgent` timed to resolve exactly as the countdown's final beat lands, so the first wave-spawn SFX becomes the hard downbeat the crossfade was building toward. This is a deliberate anticipation beat, not a surprise — matching Pillar 1's "preparation, not negation of it" discipline. **Resync fallback (added per the design review — the original text assumed perfect timing with no drift handling)**: if `mission_phase_changed` → WAVE_ACTIVE actually arrives before the anticipatory crossfade has finished (frame hitches, or a countdown that doesn't run the full assumed duration for a given mission), the crossfade completes immediately rather than continuing to play out — Urgent must be fully resolved by the time WAVE_ACTIVE content (monster spawns, combat) is actually on screen, never lagging behind the gameplay state it's supposed to be scoring. This is a placeholder tolerance rule (Open Question OQ-9), not validated against real countdown/spawn timing variance yet.
- **WAVE_ACTIVE → INTERMISSION (the relief transition, the one deliberate exception to "never hard-cut")**: a fast music duck/cut under 0.5 seconds on the wave-clear signal, not a slow crossfade — `art-bible.md`'s own words for this state, "a held breath released," cannot be honored by a slow fade; the relief has to land immediately. Ambient's combat layer fades out over ~2 seconds afterward (the lingering-smoke pacing), while the base ambient bed is never interrupted through any of this.

**Core Rule 3 — Seven SFX Cue Families (The Shared Vocabulary Every Other System's Own Scattered Audio Notes Plug Into)**
Roughly 8–10 other GDDs already wrote their own ad-hoc "audio direction, no bible yet" notes (Tarot's card-flip/denial/tier-up/rune-fanfare cues, Constellation's ignition sting, Crafting's unlock-cascade, Sanctuary UI's badge chime, etc.) — each independently inventing its own local vocabulary. This rule gives all of them one shared home:

| # | Family | Character | Example existing GDD notes this family absorbs |
|---|---|---|---|
| 1 | Discovery/Milestone Fanfare | Longest, most layered, rarest — a genuine spotlight moment | Tarot's rune-discovery reveal, Constellation's pattern-ignition sting, Crafting's unlock-cascade |
| 2 | Progress Blip | Same "achievement" register as #1 but shorter/smaller — explicitly must never reuse #1's layered patch | Tarot's mastery tier-up, Hero Skill Build's skill-unlock blip |
| 3 | Denial/Rejection | Short, low-register, negative-valence; sub-variants by register ("closer" vs. "not yet") | Crafting's tech-locked denial, Tarot's locked-card interaction tone |
| 4 | Activation/Deactivation Confirm | Bright-ascending on / dull-thud off pairing | Constellation's pattern on/off, Defense Building's tech-tree node confirm |
| 5 | UI Confirm/Cancel | Highest-frequency family; must be the least fatiguing (dry, short) | Tarot's SCOUT-resolution card-flip foley, Sanctuary UI's tab-switch/badge-arrival chimes |
| 6 | Combat Impact | The WAVE_ACTIVE-dominant family; strictest voice-limiting (Core Rule 5) | Tower fire/hit, hero attack, monster death, elite/boss telegraphs |
| 7 | Ambient Environmental | Continuous, not one-shot; lives outside the ducking/priority system entirely (Core Rule 5 doesn't apply) | State ambient beds/layers (Core Rule 2), sanctuary room tone |

**Core Rule 4 — Data-Driven Event-to-Cue Mapping: New Events on Already-Subscribed Systems Never Touch Audio's Own Code**
**Rewritten per the design review** — the original headline ("new systems never touch Audio's code") oversold the claim: any genuinely new *system* almost by definition introduces new *events*, and new events are exactly the one real code-level seam this rule always had. The accurate claim, stated precisely: **a new audio requirement for an event Audio already subscribes to** (the common case — most systems' own future audio needs will hook into events already in the 16-event inbound list, e.g. a new Tarot card wanting a cue on an event Tarot already emits) needs zero code changes to Audio System, only a data addition. A **genuinely new EventBus event** Audio doesn't yet subscribe to still needs a one-line addition to Audio's own subscription list (Godot signals aren't reflection-dispatchable without overhead this project shouldn't take on) — an acknowledged, real exception, not a loophole.

Audio maintains one `AudioCueMap` Resource (`.tres`) — **an `Array[AudioCueEntry]`, not a `Dictionary`** (corrected per the design review's Godot-implementability finding: a `Dictionary[StringName, AudioCueEntry]` inside a `.tres` has no usable inspector editor for dictionary-of-Resource values in Godot 4.6, a known editor-usability gap; an `Array[AudioCueEntry]` gets a proper resizable-array inspector for free, the idiomatic pattern for this shape). Each `AudioCueEntry` holds `event_name: StringName` (the EventBus event it maps to), `stream: AudioStream`, `bus: StringName`, `polyphony_group: StringName` (which Core Rule 3 family it belongs to, for voice-limiting), `volume_db_offset: float`, and `spatial: bool` (world-positioned vs. always-full-volume UI/HUD cues). Audio's own `_ready()` subscribes generically to its full 16-event inbound list (below), builds a runtime `Dictionary[StringName, AudioCueEntry]` from the array once at load for fast lookup, and dispatches each incoming event through that runtime map — it never hardcodes a per-event `match` statement.

**UI cues note (added 2026-09-27, UI audio cues spec `docs/superpowers/specs/2026-09-27-ui-audio-cues-design.md`)**: families #3 (Denial/Rejection), #4 (Activation Confirm) and #5 (UI Confirm/Cancel) receive their button-driven cues through the `UiAudioBinder` auto-hook (`src/core/audio/ui_audio_binder.gd`), not through a per-screen call. The dispatcher creates the binder, which hooks every `BaseButton` that enters the tree and dispatches through the same `dispatch_cue()` / `AudioCueMap` path as every other cue (Core Rule 4 is unchanged; no new EventBus signals). Four cue names on the `UI` bus: `ui_click` (default for any button), `ui_confirm`, `ui_cancel`, `ui_denied`. A button overrides its cue with node meta `ui_audio` = `confirm` / `cancel` / `none` (constants `UiAudioBinder.META_KEY` / `KIND_*`); `none` is used where the button's action already fires its own event cue (craft, repair, structure build, forge craft) so two sounds never stack. Denial sources: a press on a disabled button (detected from `gui_input`), `tower_placement_blocked` and `item_pickup_rejected` (rate-limited by `DENIED_EVENT_MIN_GAP_MSEC`). There are deliberately no hover sounds. UI-bus cues play through pool players that always process, so they are audible while the tree is paused (Core Rule 7). The current sounds are placeholders (Kenney CC0) chosen by measurement, not by listening.

**Core Rule 5 — Ducking and Priority: Per-Family Voice Caps, Not a Global Limiter**
Each Core Rule 3 family (except #7, Ambient, which is continuous and outside this system entirely) gets its own concurrent-voice cap (Tuning Knobs — **all 6 non-Ambient families now have an explicit cap, closing a gap the design review found where only 2 of 6 were specified**) rather than one global limit — Combat Impact needs the most headroom for many simultaneous towers firing; Discovery Fanfare is capped at 1 (a second discovery queues rather than overlaps, directly reusing Tarot's own existing "never stack two reveal cards simultaneously" rule, generalized to audio). Beyond a family's cap, the **oldest-started voice on that family is stolen**, never the newest trigger silently dropped — losing the newest event would mean the player's most recent action produces no feedback, the worse failure mode. **Scope clarification**: these caps are per-family, not per-bus — Formula F1's ducking model operates on total concurrent voices across the whole SFX bus (a coarser, bus-wide signal), while these caps independently limit each family's own voice count regardless of what else is playing on the bus; the two mechanisms compose (a family can be at its own cap while the bus-wide ducking formula is also actively attenuating), they don't replace each other. Sidechain ducking: the SFX bus ducks Ambient by roughly -6dB on any SFX trigger; the UI bus ducks both Music and SFX by roughly -4dB on any UI trigger, so UI feedback always cuts through combat chaos, never the reverse. Envelope timing (attack/hold/release) is specified in Formula F3, added per `design/quick-specs/sidechain-ducking-timing-2026-07-31.md` — the two duck relationships (SFX→Ambient, UI→Music+SFX) run independent envelope state machines and are expected to stack additively when both are active simultaneously (Ambient is a child bus under Music per Core Rule 1, so a Music-bus duck cascades to it automatically on top of any direct Ambient duck).

**Core Rule 6 — Global Preferences Persist Outside Save & Persistence's `restore_order` System (A New Cross-System Precedent)**
Volume settings (the 4 accessibility-committed sliders) are a **device/session preference**, not per-save-slot progress — they must persist identically across every save slot, and must be available before any save slot even exists (main menu, first boot), which `save-persistence.md`'s own `restore_order`/`sanctuary_state_restored` model (scoped entirely to slot-restore) cannot provide. Audio therefore owns a small, independent `ConfigFile` at `user://audio_settings.cfg` (4 floats, one per bus), loaded in `_ready()` before any cue plays, with no `restore_order` slot and no `SaveRestorer` registration of any kind. **This establishes a real precedent worth carrying forward**: global player preferences (volume today; input remapping is the next obvious candidate, also committed at Basic/Standard accessibility tier) live outside Save & Persistence's system entirely — future GDDs touching preference-style state should follow this pattern rather than awkwardly fitting it into a slot-scoped restore model.

**Core Rule 7 — Pause Behavior: Duck, Don't Stop (Should Close an Existing `event-bus.md` Placeholder — Not Yet Applied There)**
`game_paused`/`game_unpaused` are currently frozen in `event-bus.md` with "no subscribers yet — future Audio ducking" as their only documented purpose. **This document defines the subscriber behavior that should close that placeholder — the actual edit to `event-bus.md` itself has not been made yet** (flagged as Open Question OQ-7, the same "inherited gap in a sibling document, not this one's defect" pattern this project's `encyclopedia.md` review already established for its own Equipment-Forge-emitter finding). Concretely: on `game_paused`, the Music and Ambient buses attenuate to roughly 40% (never full silence — the game should still feel "there," not abruptly absent), while the SFX and UI buses mute the world-combat family entirely (no world sound should continue accruing while gameplay is frozen); both restore to their pre-pause levels on `game_unpaused`. Per `design/accessibility-requirements.md`'s own stronger-than-Standard commitment ("the whole game must be pausable at any frame, with no penalty"), this ducking must never interrupt or reset any in-flight music crossfade state — pausing mid-crossfade and unpausing should resume exactly where the crossfade left off, not restart it.

### States and Transitions

**Music State** (one of 4 Energy levels, per Core Rule 2 — not a 1:1 mirror of the 6 mission phases, since SANCTUARY/MISSION_COMPLETE/DEFEAT share the `Contemplative` level):

| State | Entry Condition | Behavior | Exit Transition |
|---|---|---|---|
| `Contemplative` | `mission_phase_changed` → SANCTUARY, MISSION_COMPLETE, or DEFEAT; or initial boot | One continuous stem per this Energy level plays; Ambient base bed matches context (SANCTUARY room tone vs. battlefield-aftermath tone differ even at the same Energy level — an Ambient-layer distinction, not a Music one) | Crossfade to `Measured` (→ SCOUT) or exit to Mission Select (no further game-state audio owned by this document past that hand-off) |
| `Measured` | `mission_phase_changed` → SCOUT | Continuous stem; Ambient's SCOUT-specific "still, expectant" layer active | Anticipatory crossfade to `Urgent`, beginning on `wave_countdown_warning` (Core Rule 2) |
| `Urgent` | `mission_phase_changed` → WAVE_ACTIVE, or the anticipatory crossfade from `Measured` resolves | Continuous stem; Combat Impact family (Core Rule 3) active; Ambient combat layer active | Fast duck/cut (<0.5s) to `Measured-urgent` on wave-clear (Core Rule 2's deliberate exception) |
| `Measured-urgent` | `mission_phase_changed` → INTERMISSION | Continuous stem; Ambient combat layer fades out over ~2s while base bed continues uninterrupted | Crossfade to `Urgent` (next wave) or `Contemplative` (mission ends) |

### Interactions with Other Systems

| System | Direction | Data | Mechanism | When |
|---|---|---|---|---|
| **EventBus** | ← subscribes (16 events) | `mission_phase_changed`, `wave_countdown_warning`, `hero_skill_activated`, `hero_class_unlocked`, `tower_placed`, `tower_attacked`, `pre_placement_perk_activated`, `boss_died`, `hero_damage_taken`, `constellation_activated`, `component_crafted`, `component_repaired`, `sanctuary_structure_built`, `hero_equipment_crafted`, `game_paused`, `game_unpaused` | EventBus signal, generic dispatch via Core Rule 4's `AudioCueMap` | Continuous, any time during gameplay |
| **All 16 emitting systems** | Upstream (Audio depends on, one-directional — none of them depend back on Audio) | Whatever payload each event already carries; Audio reads only the event name for cue-map lookup, never inspects payload fields for mixing decisions beyond what a given `AudioCueEntry` needs | Frozen per `event-bus.md`; Audio never requires an emitting system to change its own contract |
| **Accessibility Requirements** | Constrains (hard) | The 4-slider bus commitment (Core Rule 1) — this document must conform to that commitment, not the reverse | Design-time constraint, not a runtime interface |
| **Save & Persistence** | Explicitly NOT a dependency (deliberate, stated — see Core Rule 6) | None | Global prefs live in Audio's own `ConfigFile`, outside this system entirely |

## Formulas

#### F1 — Concurrent-Cue Ducking (per SFX-bus voice)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `base_volume` | `V_base` | float | 0.0–1.0 | Cue's authored linear volume before ducking |
| `active_voice_count` | `N` | int | 1–20 | Simultaneous SFX-bus voices currently playing, including this one |
| `duck_coefficient` | `k` | float | 0.02–0.10 | Attenuation applied per additional concurrent voice (Tuning Knobs) |
| `duck_floor` | `D_floor` | float | 0.2–0.4 | Minimum volume floor — prevents total silence under heavy load |
| `ducked_volume` | `V_sfx` | float | `[D_floor, V_base]` | The value actually applied |

**Expression:**
```
ducked_volume = base_volume × max(duck_floor, 1 − duck_coefficient × (active_voice_count − 1))
```

**Output range:** Clamped to `[duck_floor, base_volume]` — a single voice (`N=1`) plays at full authored volume; volume degrades gracefully, never to silence, as concurrent voices increase.

**Worked example:** `V_base=0.8`, `N=6` (6 towers firing the same frame), `k=0.05`, `D_floor=0.3` → `0.8 × max(0.3, 1 − 0.05×5) = 0.8 × max(0.3, 0.75) = 0.8 × 0.75 = 0.60`.

#### F2 — World-Space Distance Attenuation (spatial cues only, per `AudioCueEntry.spatial == true`)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `base_volume` | `V_base` | float | 0.0–1.0 | Cue's authored linear volume at zero distance |
| `distance` | `d` | float | 0–unbounded | Grid-cell distance from the source (tower/monster cell) to the camera's current focus point |
| `max_audible_radius` | `R` | float | 10–20 cells | Distance beyond which the cue is fully inaudible (Tuning Knobs) |
| `world_volume` | `V_world` | float | `[0, V_base]` | The value actually applied |

**Expression:**
```
world_volume = base_volume × clamp(1 − distance / max_audible_radius, 0, 1)
```

**Output range:** `[0, V_base]` — full volume at the camera focus point, linearly attenuating to silence at `max_audible_radius`. **UI/HUD-family cues (Core Rule 3 families #2–#5) never use this formula** — they play at `AudioCueEntry`'s authored volume unmodified, since they are player-facing feedback, not diegetic world sound.

**Worked example:** `V_base=0.7`, `d=8`, `R=15` → `0.7 × clamp(1 − 8/15, 0, 1) = 0.7 × 0.467 = 0.327`.

#### F3 — Sidechain Duck State (per relationship, evaluated per-frame while active)

*Added per `design/quick-specs/sidechain-ducking-timing-2026-07-31.md` — closes Core Rule 5's previously-unspecified attack/release timing gap.*

Applies independently to each of the 2 duck relationships (SFX→Ambient, UI→Music+SFX), each with its own state.

**Trigger definition**: a qualifying trigger is any `AudioCueDispatcher.dispatch_cue()` call whose resolved `AudioCueEntry.bus` matches the relationship's source bus (`&"SFX"` or `&"UI"`). Ambient-family cues (Core Rule 3 family #7) are never a trigger source, only ever a duck target.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `duck_amount_db` | `D` | float | -8 to -2 | Target attenuation once fully ducked (the -6dB/-4dB values above) |
| `attack_time` | `T_a` | float (sec) | 0.005–0.05 | Time to ramp from unducked to fully ducked |
| `release_delay` | `T_h` | float (sec) | 0.05–0.3 | Time after the last trigger before release begins (the "hold") |
| `release_time` | `T_r` | float (sec) | 0.1–0.4 | Time to ramp from fully ducked back to unducked, once release begins |
| `current_db_offset` | `V_t` | float | `[D, 0]` | The actual dB offset applied at time `t` — 0 at rest, `D` when fully ducked |

**Expression** (state machine, not a closed-form formula — matches Core Rule 2's own crossfade/duck-cut state model precedent):
```
on qualifying_trigger:
  if state == RESTING:
    state = ATTACKING; attack_start_db = current_db_offset; attack_start_time = now
  reset release_timer to T_h  # always, regardless of state

per-frame:
  if state == ATTACKING:
    V_t = lerp(attack_start_db, D, clamp((now - attack_start_time) / T_a, 0, 1))
    if V_t reaches D: state = HELD
  if state == HELD and release_timer expired:
    state = RELEASING; release_start_db = current_db_offset; release_start_time = now
  if state == RELEASING:
    V_t = lerp(release_start_db, 0, clamp((now - release_start_time) / T_r, 0, 1))
    if V_t reaches 0: state = RESTING
```

**Retrigger behavior**: every qualifying trigger arriving while already ducked (ATTACKING, HELD, or RELEASING) resets `release_timer` to `T_h` rather than restarting the attack ramp — this is what prevents audible "pumping" during a dense stream of triggers (e.g. many Combat Impact cues during WAVE_ACTIVE holding Ambient continuously ducked). A trigger arriving mid-RELEASING re-enters HELD from the current partially-released `V_t`, never snapping back to full `D` first.

**Worked example** (SFX→Ambient, default values): a `tower_attacked` cue dispatches (bus=SFX) while Ambient is at rest. Ambient's `volume_db` ramps from `0` to `-6dB` over `15ms` (`T_a`). Three more Combat Impact cues dispatch over the next `400ms` — each resets the `150ms` hold timer (`T_h`) rather than re-attacking. `150ms` after the last of those four triggers, Ambient begins ramping back from `-6dB` to `0dB` over `250ms` (`T_r`) — total time from last trigger to fully restored: `400ms`.

## Edge Cases

- **If more one-shot triggers fire in a single frame than a family's voice cap allows** (e.g. 10+ `tower_attacked` events during a dense WAVE_ACTIVE moment, against Combat Impact's cap): the oldest-started voice on that family is stolen and replaced by the new trigger (Core Rule 5) — never silently drop the newest trigger, since that would mean the player's most recent action produces no audible feedback, the worse failure mode.
- **If a mission-ending transition (DEFEAT or MISSION_COMPLETE) fires while a combat sting is still playing**: all SFX-bus voices fade out over ~150ms (not a hard cut, to avoid an audible pop), while the Music bus crossfades directly to the new `Contemplative`-level track per Core Rule 2's standard model — no special-cased hard stop.
- **If `mission_phase_changed` fires again before an in-flight music crossfade has finished** (e.g. an unusually short mission cycling SCOUT→WAVE_ACTIVE→INTERMISSION in rapid succession): the in-flight crossfade is cancelled and a new one begins immediately from the current live volume/position — crossfades never queue, only the latest phase's target track matters, matching Sanctuary UI's own "re-targets from current live value, never snaps to a default first" interrupt discipline for its own camera tweens.
- **If `game_paused` fires mid-crossfade**: the crossfade's progress is frozen exactly where it is (per Core Rule 7's "resume exactly where it left off" requirement) — pausing must never restart or cancel an in-flight transition, only duck the currently-audible mix around it.
- **If an `AudioCueMap` entry references an event name Audio isn't actually subscribed to, or omits an entry for an event it is subscribed to**: no cue plays (a silent no-op), never an error — this is a content-authoring gap (Full Vision-tier audio bible work not yet done for most events), not a runtime failure; every one of this document's 16 inbound events is expected to have an eventual `AudioCueMap` entry, but none need to exist for this system's own mechanics to function correctly today. Tested explicitly by AC-10a.
- **If the player has never adjusted volume before** (fresh `user://audio_settings.cfg` doesn't exist yet): all 4 buses default to 80% per `accessibility-requirements.md`'s own stated default — not 100%, not muted.
- **If Formula F2's `distance` value is negative** (physically impossible under correct grid-cell math — added per the design review, which found the formula's own clamp silently masks this as "very close" rather than flagging it): treated as an upstream caller-error signal, not valid input — Audio clamps `distance` to `max(distance, 0)` before evaluating F2, so a negative value produces the same result as `distance = 0` (full volume) rather than an out-of-range artifact, but the emitting system's own grid-position logic is the actual place such a value would indicate a real bug, not this system.
- **If a qualifying sidechain trigger (Formula F3) arrives while a duck relationship is mid-RELEASING** (added per `design/quick-specs/sidechain-ducking-timing-2026-07-31.md`): cancel the release and re-enter HELD at the current (partially-released) `current_db_offset` — do not snap back to full `D` first and do not let the release continue underneath the new hold.
- **If `game_paused` fires while a sidechain duck relationship is ATTACKING, HELD, or RELEASING** (added per `design/quick-specs/sidechain-ducking-timing-2026-07-31.md`): freeze `current_db_offset` exactly where it is (matching Core Rule 7's crossfade-freeze precedent) until `game_unpaused`, then resume the same state — the SFX bus's world-combat content is muted entirely during pause (Core Rule 7), so no new qualifying triggers can arrive to naturally hold or release the duck during that window.
- **If both SFX→Ambient and UI→Music+SFX duck relationships are simultaneously active** (added per `design/quick-specs/sidechain-ducking-timing-2026-07-31.md`): no special handling needed — Ambient is a child bus under Music (Core Rule 1), so the combined attenuation the player hears is the sum of both relationships' dB offsets. This is a correct outcome of the bus graph, not an interaction to suppress.

## Dependencies

| System | Direction | Nature |
|---|---|---|
| EventBus | Audio depends on | Hard — all 16 inbound subscriptions route through it |
| Accessibility Requirements | Audio depends on | Hard — the 4-slider bus commitment (Core Rule 1) is a binding constraint this document conforms to, not a design choice made here |
| The 14 gameplay-event-emitting systems (Wave Manager, Tower, Hero, Constellation, Crafting, Equipment Forge, Defense Building, Tower Mastery/Hero Skill Build, Sanctuary systems) | Audio depends on | Soft, one-directional — Audio degrades gracefully (silence) without any single one of them; none of them depend back on Audio, matching every one of their own GDDs' "directional only, no audio bible yet" framing |
| Save & Persistence | Explicitly not a dependency | None — deliberate, per Core Rule 6; Audio owns its own preference persistence outside this system |

**Bidirectional note**: the ~10 GDDs whose own "Audio direction" sections this document formally absorbs (Tarot, Constellation, Crafting, Sanctuary UI, Tarot Deck UI, Defense Building, Equipment Forge, Hero Skill Build, and others) should each eventually gain a one-line cross-reference to this document once next revised, matching the convention `sanctuary-ui.md`/`tarot-deck-ui.md` used for their own wrapped systems — not done here, since editing ~10 other GDDs is out of this document's own authoring scope.

## Tuning Knobs

| Parameter | Default Value | Safe Range | Too High | Too Low |
|---|---|---|---|---|
| Duck coefficient (`k`, Formula F1) | 0.05 | 0.02–0.10 | Combat feels thin/quiet the moment 2+ things happen at once | Ducking is imperceptible, dense combat becomes a wall of undifferentiated noise |
| Duck floor (`D_floor`, Formula F1) | 0.3 | 0.2–0.4 | Peak-combat SFX barely attenuates, defeats the purpose of ducking | Peak-combat SFX nearly disappears, reads as a bug not a mix choice |
| Max audible radius (`R`, Formula F2) | 15 grid cells | 10–20 | World SFX audible from effectively anywhere, undermines spatial readability | Towers/monsters go silent while still on-screen, feels broken |
| Combat Impact voice cap | 12 | 8–16 | Wastes voice budget on redundant simultaneous impacts | Audible culling during normal, not even peak, combat |
| Discovery Fanfare voice cap | 1 | Fixed — must never exceed 1 | N/A — would violate the "never stack two reveal cards" precedent this rule reuses | N/A — this is a floor, not a range |
| Progress Blip voice cap *(placeholder, added per `/design-review` — see OQ-8)* | 4 | 2–6 | Multiple simultaneous minor progress cues start to sound like combat noise | Genuine simultaneous small unlocks (e.g. a crafting recipe and a skill tier-up in the same frame) get culled unnecessarily |
| Denial/Rejection voice cap *(placeholder — see OQ-8)* | 3 | 2–5 | Rapid repeated denial-clicking becomes a noise wall | A player rapidly testing multiple locked options loses feedback on later attempts |
| Activation/Deactivation Confirm voice cap *(placeholder — see OQ-8)* | 4 | 2–6 | Multiple simultaneous toggles (unlikely but possible) sound cluttered | Legitimate near-simultaneous toggles get culled |
| UI Confirm/Cancel voice cap *(placeholder — see OQ-8)* | 6 | 4–8 | Rapid navigation clicking becomes fatiguing noise | Fast, legitimate menu navigation loses per-click feedback |
| Resync tolerance for the anticipatory crossfade *(placeholder — see OQ-9)* | Complete immediately if incomplete at `mission_phase_changed` | N/A — a correctness fallback, not a tunable range | N/A | N/A |
| SCOUT→WAVE_ACTIVE anticipatory crossfade duration | 3.5 sec | 3–4 sec | Crossfade doesn't resolve before the countdown's final beat, downbeat lands on a still-transitioning mix | Feels abrupt, undercuts the anticipation beat the countdown is building |
| WAVE_ACTIVE→INTERMISSION duck/cut duration | 0.4 sec | 0.2–0.5 sec | Starts to feel like a crossfade again, undermines "held breath released" | Reads as a literal audio glitch/pop |
| Pause music/ambient duck level | 40% | 30–50% | Barely different from unpaused, pause doesn't register sonically | Too close to silent, contradicts "duck, don't stop" |
| Default bus volume (all 4) | 80% | Fixed — must match `accessibility-requirements.md`'s own stated default exactly | N/A | N/A |
| Sidechain duck amount, SFX→Ambient (`D`, Formula F3) | -6dB | -8 to -2dB | Ambient nearly disappears under any combat, reads as broken rather than mixed | Ducking is imperceptible, combat and ambience blur together |
| Sidechain duck amount, UI→Music+SFX (`D`, Formula F3) | -4dB | -8 to -2dB | Music/SFX drop noticeably every UI click, feels twitchy | UI feedback doesn't cut through combat, defeats the mechanism's purpose |
| Sidechain attack time, SFX→Ambient (`T_a`, Formula F3) | 15ms | 5–50ms | Audible click/snap on engage | Duck feels laggy, first transient of the triggering sound isn't covered |
| Sidechain attack time, UI→Music+SFX (`T_a`, Formula F3) | 10ms | 5–50ms | Audible click/snap on engage | UI feedback's own attack is delayed by a sluggish duck |
| Sidechain release delay, SFX→Ambient (`T_h`, Formula F3) | 150ms | 50–300ms | Ambient flickers back up between individual hits during normal combat pacing | Ambient stays ducked noticeably after combat activity has clearly stopped |
| Sidechain release delay, UI→Music+SFX (`T_h`, Formula F3) | 80ms | 50–300ms | Music/SFX flicker during rapid legitimate UI navigation | Music/SFX stay ducked after a single UI click, feels sluggish |
| Sidechain release time, SFX→Ambient (`T_r`, Formula F3) | 250ms | 100–400ms | Restoration feels abrupt, reads as a hard cut | Ambient takes noticeably long to feel "back," especially right after a wave ends |
| Sidechain release time, UI→Music+SFX (`T_r`, Formula F3) | 180ms | 100–400ms | Restoration feels abrupt after UI interaction | Music/SFX stay perceptibly quiet after the UI moment has clearly passed |

## Visual/Audio Requirements

*Not applicable in the usual sense — this document IS the project's audio-requirements architecture, the sibling to every other GDD's own Visual/Audio Requirements section rather than a consumer of one.* Individual per-system SFX descriptions (exact cue character, timing, layering) remain owned by each originating system's own GDD, sorted into this document's 7 cue families (Core Rule 3) — this document defines the shared architecture those descriptions plug into, not the descriptions themselves. Visual coordination note: this document's 4 Music Energy-level states are deliberately 1:1 with `art-bible.md` Section 2's own state model, so any future visual revision to that section's state boundaries should trigger a corresponding check here.

## UI Requirements

A volume settings surface (4 sliders — Music/SFX/Voice/UI, per Core Rule 1) needs to exist somewhere the player can reach it, but **this document does not design that screen or its placement** — no Settings/Options system exists anywhere in this project yet (confirmed by search), and the two most likely hosts (Main Menu, Pause Menu) are both already-designed UX specs (`design/ux/main-menu.md`, `design/ux/pause-menu.md`) this document should not unilaterally assume ownership of extending, matching the same discipline `encyclopedia.md` used for its own deferred UI question earlier this session. Flagged as Open Question OQ-1.

📌 **UX Flag**: This system will need a settings surface eventually, but does not yet have a designed one — do not run `/ux-design audio-system` until OQ-1 is resolved and there is an actual host screen decided.

## Acceptance Criteria

> **Test type key** (per QA story-type gate): **Logic** = automated unit test, BLOCKING · **Integration** = integration test or documented playtest, BLOCKING.

### Group 1 — Mix Bus Architecture (Core Rule 1)

- **AC-1** *(Logic)*: GIVEN the audio system initializes, THEN exactly 4 player-adjustable buses exist (Music, SFX, Voice, UI), each independently settable 0–100%, defaulting to 80% — matching `accessibility-requirements.md` exactly.
- **AC-2** *(Integration)*: GIVEN the player adjusts the Music bus volume, WHEN a Combat Impact (SFX-bus) cue plays immediately after, THEN its volume is unaffected by the Music bus change, and vice versa for any other bus pair.

### Group 2 — State-Driven Music and Ambient (Core Rule 2, States and Transitions)

- **AC-3** *(Integration)*: GIVEN Music state is `Measured` (SCOUT), WHEN `wave_countdown_warning(seconds_remaining=10)` fires, THEN a crossfade to `Urgent` begins, timed to complete as the countdown reaches 0.
- **AC-4** *(Integration)*: GIVEN Music state is `Urgent` (WAVE_ACTIVE), WHEN the wave-clear signal fires (`mission_phase_changed` → INTERMISSION), THEN Music ducks/cuts to `Measured-urgent` within the Tuning Knobs' 0.2–0.5s window — not a multi-second crossfade.
- **AC-5** *(Integration)*: GIVEN any `mission_phase_changed` fires with `previous_phase == new_phase`, THEN no music retrigger or restart occurs.
- **AC-6** *(Integration)*: GIVEN INTERMISSION's Ambient combat layer is fading out, WHEN a new wave begins (`Measured-urgent` → `Urgent`), THEN the base Ambient bed is never interrupted or restarted — only layers change.

### Group 3 — One-Shot Cue Triggering (Core Rules 3–4)

- **AC-7** *(Integration)*: GIVEN `boss_died` fires, THEN a Discovery/Milestone Fanfare-family cue plays (per whatever `AudioCueMap` entry exists for that event), respecting the family's voice cap.
- **AC-8** *(Integration)*: GIVEN `tower_attacked` fires, THEN a Combat Impact-family cue plays with world-space distance attenuation (Formula F2) applied.
- **AC-9** *(Integration)*: GIVEN `sanctuary_structure_built` fires, THEN a Progress Blip or Discovery/Milestone Fanfare-family cue plays (per the `AudioCueMap`'s own categorization), at full volume regardless of the structure's world position (UI/HUD-adjacent milestone, not spatial per Formula F2's own exclusion).
- **AC-10** *(Logic, rewritten per `/design-review` — the original wording asserted an untestable code-structure absence)*: GIVEN `AudioCueMap` entries exist for at least 2 arbitrarily-different subscribed events (e.g. `boss_died` and `component_crafted`), WHEN each fires in turn, THEN each plays its own correctly-mapped cue on its own configured bus — confirming generic dispatch works across genuinely different events using the same lookup path, without the test itself needing per-event branching. **The stronger claim the original AC made ("no per-event code path exists in Audio's own implementation") is an architecture-review/code-inspection checklist item, not a runtime-testable Acceptance Criterion — moved out of this section.**
- **AC-10a** *(Logic, added per `/design-review` — closes an Edge Cases claim with zero prior AC coverage)*: GIVEN an event fires with no matching `AudioCueMap` entry, THEN no cue plays and no error or exception occurs.

### Group 4 — Ducking and Voice Limiting (Core Rule 5, Formula F1)

- **AC-11** *(Logic)*: GIVEN a family's voice cap (e.g. Combat Impact, 12) is already at capacity, WHEN one more trigger fires, THEN the oldest-started voice on that family stops and the new trigger plays — the newest trigger is never silently dropped.
- **AC-12** *(Logic)*: GIVEN 6 simultaneous SFX-bus voices are active, WHEN Formula F1 is evaluated with the Tuning Knobs' default `k=0.05`/`D_floor=0.3`, THEN each voice's ducked volume matches the formula's worked example (`0.60` for `V_base=0.8`).
- **AC-12a** *(Integration, added 2026-08-06 — closes a real gap: Formula F3's envelope was implemented and unit-tested but its output was never applied to real audio)*: GIVEN a qualifying `SFX_TO_AMBIENT` or `UI_TO_MUSIC_AND_SFX` trigger fires, THEN the real `AudioServer` volume of every bus that relationship affects (Ambient; Music+SFX respectively) reflects the current envelope offset every frame — not just `VoiceLimiter`'s own computed state — and returns to the unducked baseline once the envelope fully releases. The persisted volume preference (`AudioSystem.get_bus_volume_percent()`) is never touched by this application step.

### Group 5 — Persistence (Core Rule 6)

- **AC-13** *(Integration — process-relaunch harness required, not a standard in-process test, flagged explicitly per `/design-review`)*: GIVEN the player sets a non-default bus volume, WHEN the game process is fully killed and relaunched (not merely a save/load — this project's normal in-process test runner cannot exercise this; requires either a documented manual playtest or a scripted headless-relaunch subprocess harness), THEN the volume is restored from `user://audio_settings.cfg` on the fresh process, not reset to default.
- **AC-14** *(Integration)*: GIVEN volume settings exist in `user://audio_settings.cfg`, WHEN a save slot is loaded or a fresh game is started from the main menu, THEN volume settings are unaffected by either action — confirming they are genuinely slot-independent, not silently coupled to Save & Persistence's restore cycle.

### Group 6 — Pause Behavior (Core Rule 7)

- **AC-15a** *(Integration, split from the original compound AC-15 per `/design-review` — matches this project's own established precedent for splitting bundled claims)*: GIVEN `game_paused` fires mid-crossfade, THEN the crossfade's progress freezes exactly where it is — no restart, no cancellation; WHEN `game_unpaused` fires, THEN the crossfade resumes from exactly the frozen point, not from the beginning or a default.
- **AC-15b** *(Integration, split from AC-15)*: GIVEN `game_paused` fires, THEN Music/Ambient buses duck to the configured pause level (~40%, Tuning Knobs) and the SFX bus's world-combat content mutes entirely; WHEN `game_unpaused` fires, THEN all affected bus levels restore to their exact pre-pause values.

## Open Questions

| # | Question | Owner | Target Resolution |
|---|---|---|---|
| OQ-1 | No settings screen/host exists for the 4-slider volume UI this document requires (UI Requirements). Main Menu and Pause Menu are the two most likely hosts, but this document does not decide between them or design either extension. | UX Designer | When a dedicated settings surface is scheduled |
| OQ-2 | **Pipeline decided 2026-08-28, pilot shipped same day** (`production/qa/audio-content-pipeline-decision.md`) — licensed/CC0 asset packs (Kenney.nl / Freesound.org CC0 / itch.io), not AI-generation, custom commission, or procedural placeholder. **Tower Mastery's 3 stingers are now real content** (`assets/data/audio/audio_cue_map.tres`, sourced from Kenney's Interface Sounds pack) — the first real audio anyone will hear in this project, since `AudioCueDispatcher.dispatch_cue()` itself gained real `AudioStreamPlayer` playback as part of this pass (previously routing/ducking math ran but no cue actually played, for any event, project-wide). The `AudioCueMap` is otherwise still almost entirely empty — the other ~76 events across the ~10 GDDs' own scattered "audio direction" notes still need to be formally sorted into this document's 7 cue families and given real entries; that broader content-authoring pass has not started. This remains Full Vision-tier content-authoring work, not a design gap in this document, and the pilot's 3 cues are the proof-of-concept, not the completion. **2026-09-20 update:** all 20 wired event cues now have real content (mission_phase_changed is deliberately unmapped), sourced from Kenney CC0 packs per this pipeline decision — see `assets/audio/sfx/SOURCES.md`; five cues are flagged weak matches pending replacement. Still open: music/ambient stems, unwired UI-click/denial cues, spatial distance wiring, and per-element/per-skill variants (see `docs/superpowers/specs/2026-09-20-audio-cue-list-design.md` §9). **2026-09-20 (music/ambient):** the four Music Energy stems, the ambient base bed and the ambient combat layer now have real playback and synthesized PLACEHOLDER content (see `docs/superpowers/specs/2026-09-20-music-ambient-stems-design.md`); real music, the sanctuary/scout/smoke ambient layers, and adaptive layering remain. | Audio Director / Sound Designer | Content-authoring pass, scaling beyond Tower Mastery's 3 piloted cues |
| OQ-3 | Whether sub-mixing Ambient under the Music bus (Core Rule 1) rather than giving it its own player-facing slider is the right long-term choice — if playtesting shows players want to adjust atmosphere independently of music stems, this may need a 5th slider, which would require reopening `accessibility-requirements.md`'s own frozen 4-slider commitment. | Game Designer / Accessibility owner | After first playtest pass with real music+ambient content |
| OQ-4 | Input remapping (also committed at Basic/Standard accessibility tier) is named in Core Rule 6 as "the next obvious candidate" for the same outside-Save-&-Persistence preference-persistence pattern this document establishes for volume — not designed here, since no Input/Controls system GDD exists yet, but flagged so whoever designs it doesn't have to rediscover this precedent from scratch. | Whoever designs Input/Controls | When that system is next scheduled |
| OQ-5 (new, `/design-review`) | "The Sanctuary Is Your Statement" (ambient audio density scaling with sanctuary investment — menagerie occupancy, active crafting stations) was originally claimed as a co-primary Player Fantasy pillar but has no implementing mechanic anywhere in this document — narrowed out of the Player Fantasy section during review (now Everything Connects-primary only). If this is genuinely wanted later, it needs: a new continuous (not one-shot) EventBus signal carrying occupancy/activity data, an ambient-density formula, and its own Tuning Knobs — real new scope, not an oversight in this pass. | Game Designer | If/when this ambition is actually prioritized |
| OQ-6 (new, `/design-review`) | The Voice bus (Core Rule 1) is reserved and currently silent — no VO content exists or is planned at MVP/Alpha scope. Shipping a functional-looking slider with zero audible effect risks reading as broken UI to a player who adjusts it and hears nothing change. Whoever designs the settings screen (OQ-1) should consider disabling/graying/hiding the Voice slider until real VO content exists, rather than presenting 4 seemingly-identical sliders where one silently does nothing. | UX Designer | When the settings surface (OQ-1) is designed |
| OQ-7 (new, `/design-review`) | `event-bus.md`'s own catalogue still lists `game_paused`/`game_unpaused`'s Key Subscribers as "None yet (future Audio ducking)" — this document's Core Rule 7 defines the subscriber behavior that should close that placeholder, but the actual edit to `event-bus.md` has not been made. Inherited gap in that sibling document, not this one's defect (same pattern as `encyclopedia.md`'s own Equipment-Forge-emitter finding). | EventBus owner | Next `event-bus.md` revision |
| OQ-8 (new, `/design-review`) | Only 2 of the 6 non-Ambient cue families (Combat Impact, Discovery Fanfare) have an explicit voice cap in Tuning Knobs, despite Core Rule 5's own text claiming every family gets one. Placeholder default caps have been added for the remaining 4 (Tuning Knobs) to close the immediate gap, but none have been validated against real content or playtesting — treat them as provisional starting points, not tuned values. | Audio Director / Sound Designer | After first content-authoring pass |
| OQ-9 (new, `/design-review`) | The SCOUT→WAVE_ACTIVE anticipatory crossfade (Core Rule 2) assumes `wave_countdown_warning`'s 10-second signal reliably predicts actual wave-spawn timing, with a resync fallback now specified (Edge Cases) for drift beyond a small tolerance — but that fallback's exact tolerance threshold is a placeholder value, not validated against real countdown/spawn timing variance in a running build. | Audio Director | After first live-build verification pass |

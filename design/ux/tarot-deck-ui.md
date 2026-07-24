# UX Spec: Tarot Deck UI

> **Status**: Complete (2026-07-24)
> **Author**: Claude Sonnet (autonomous session, no user review)
> **Last Updated**: 2026-07-24
> **Journey Phase(s)**: Not tracked — `design/player-journey.md` does not exist in this project. This spec's Player Context on Arrival section stands in for that mapping, per the same convention `design/ux/sanctuary-ui.md` already established.
> **Template**: UX Spec
> **Governing GDD**: `design/gdd/tarot-deck-ui.md` (Approved, 2026-07-24)

---

## Purpose & Player Need

Tarot Deck UI is the sole player-facing surface for composing a pre-mission strategic commitment across two systems at once: Tarot's deck (which mission modifiers to wager on) and Hero Skill Build's active loadout (which skills, and therefore which Ultimate, to bring). It is markedly narrower in scope than its sibling shell, Sanctuary UI — it hosts exactly 2 already-fully-designed screens unmodified and adds only two small cross-screen affordances of its own (a Current Build Snapshot chip and a Tarot/Mission Select conflict indicator).

The player arrives wanting to answer one question with two parts: **who am I bringing** (Hero Skill Build) and **how hard am I choosing to make it** (Tarot). This shell fails if it makes that feel like two disconnected errands rather than one continuous act of self-assessment — the exact gap the GDD's own `/design-review` found and fixed by adding the Current Build Snapshot chip (Core Rule 7).

Success is a player who can freely move between the two screens mid-thought (checking "what Ultimate does my current build make?" while browsing Tarot cards, or "how much risk have I already staked?" while assigning skills) without ever losing track of either half of the decision.

---

## Player Context on Arrival

*(Standing in for `design/player-journey.md`, which does not yet exist — see `design/ux/sanctuary-ui.md`'s identical flag.)*

| Arrival Moment | Prior Action | Emotional State | Primary Player Need |
|---|---|---|---|
| **From Sanctuary UI, any state** | Player selected the Loadout tab (Sanctuary UI Core Rule 2/10), from `OVERVIEW` or mid-room | Deliberate, planning-focused — not a forced/automatic arrival like Sanctuary UI's own `MISSION_COMPLETE` entry | Compose or revise their build before the next mission; reach whichever of the 2 screens they care about right now |
| **Returning mid-composition** | Player left and came back within the same Sanctuary visit (e.g. checked Crafting, came back to finish a loadout decision) | Resuming a train of thought | Land on `HERO_SKILL_BUILD` by default (Core Rule 2's fixed default — not sticky, so this is always a fresh start, not a resume) |
| **Mid-Tarot-composition, sees a conflict badge** | Actively slotting Tarot cards | Focused, evaluating risk | Understand which Mission Select modifier a card collides with, without leaving the screen (Core Rule 6) |

Design implication: unlike Sanctuary UI's forced-entry `OVERVIEW` beat, every arrival here is player-initiated and purposeful — there is no "contemplative beat" need to protect. The shell's whole job is staying out of the way of a decision the player already came here to make.

---

## Navigation Position

Tarot Deck UI is a top-level destination, sibling to Sanctuary UI, not nested inside it:

`Sanctuary UI (any state) → [Loadout tab] → Tarot Deck UI (HERO_SKILL_BUILD default) → [Cancel/Return] → Sanctuary UI (OVERVIEW)`

Within the shell, navigation is flat — a 2-entry tab strip with both screens as siblings, one input apart. No screen is nested inside the other.

---

## Entry & Exit Points

### Entry Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Sanctuary UI, any state (`OVERVIEW` or any `ROOM_*`) | Loadout tab-strip entry selected | None persisted — always lands on `HERO_SKILL_BUILD`, regardless of which Sanctuary UI room they came from or which screen they last used here |

### Exit Points

| Exit Destination | Trigger | Notes |
|---|---|---|
| Sanctuary UI (`OVERVIEW`) | Cancel, or explicit "Return to Sanctuary" affordance | Sole exit path (Core Rule 4) — no confirmation of any kind, since every committed edit on both screens is already applied. Not a special-cased "return from Loadout" — identical to any other Sanctuary UI arrival. |

There is no direct exit to Mission Select from this shell — a player leaving loadout editing has not launched anything; they always return to Sanctuary UI first.

---

## Layout Specification

### Information Hierarchy

| Priority | Element | State Visibility | Rationale |
|---|---|---|---|
| 1 | Tab Strip (2 entries) | Always | The only navigation surface — smaller than Sanctuary UI's, but the same role |
| 2 | Active screen content (Tarot or Hero Skill Build, full-frame) | Active state only | The actual work surface — everything else is chrome around it |
| 3 | Current Build Snapshot chip | Always | Read-only cross-reference to the *other* screen's headline state — this is the mechanic the Player Fantasy is actually grounded in (GDD Core Rule 7) |
| 4 | Conflict Indicator badge | `TAROT_DECK` only, conditional | Advisory-only, appears on specific tray slots when a real conflict exists — lower priority than the chip since it's conditional, not always-present |

### Layout Zones

```
┌─────┬─────────────────────────────────────────────────────────┐
│     │  ZONE S — SNAPSHOT CHIP (always, single line, top-right   │
│  Z  │  corner of the header band)                                │
│  O  ├─────────────────────────────────────────────────────────┤
│  N  │                                                           │
│  E  │  ZONE C — CONTENT (ScreenHost, full frame minus chrome)   │
│     │                                                           │
│  T  │  Either:                                                 │
│  A  │   • HERO_SKILL_BUILD: that screen's own full-rect layout │
│  B  │   • TAROT_DECK: that screen's own full-rect layout,      │
│     │     including Conflict Indicator badges on tray slots    │
│  S  │                                                           │
│  T  │                                                           │
│  R  │                                                           │
│  I  │                                                           │
│  P  │                                                           │
│     │                                                           │
│ ≤96 │                                                           │
│ px  │                                                           │
└─────┴─────────────────────────────────────────────────────────┘
```

**Zone rules:**

| Zone | Visibility | Behaviour |
|---|---|---|
| Tab Strip (left edge, ≤96px) | Always | 2 entries, top-to-bottom: Hero Skill Build, Tarot Deck (matching the Player Fantasy's "build, then deck" reading — see Open Questions). No Connection Badges of any kind — this shell has no 3rd-party cross-system event to surface, unlike Sanctuary UI's 4 rooms |
| Snapshot Chip (top-right, single line) | Always | Non-interactive, read-only — reuses Sanctuary UI's persistent-resource-header visual treatment (same UI Chrome/Parchment register, zero focus ring) |
| Content / `ScreenHost` (remaining frame) | Always, content swaps | The active screen's own full-rect layout — never both, never neither |

Reuses the same "thin static chrome around one dominant content region" model as Sanctuary UI, scaled down to 2 tabs instead of 6 and no resource header (this shell has no gold/materials display need of its own).

### Component Inventory

#### Tab Strip

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Tab entry ×2 | Icon button + label-on-focus | Screen icon (Ultimate-glyph silhouette for Hero Skill Build; tarot-card-back motif, reused from `tarot.md`, for Tarot Deck) + label | Yes — click / `LT`/`RT` / `[`/`]` | Reuses Sanctuary UI's own **Persistent Room Tab Strip** candidate pattern, at 2 entries instead of 6 — same underlying component, smaller instance |

#### Snapshot Chip

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Current Build Snapshot chip | Data display | On `TAROT_DECK`: Hero Skill Build's `ultimate_id` (or "No Ultimate yet"). On `HERO_SKILL_BUILD`: Tarot's aggregate risk readout | No | Adjacent to Pattern 5 (Resource Counter) but cross-system rather than player-resource — closest neighbor to Sanctuary UI's own Connection Badge candidate pattern, though this is a continuous readout, not an event-driven counter |

#### Content Zone — `TAROT_DECK` (conflict indicator only — the rest of the screen is `tarot.md`'s own unmodified UI)

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Conflict Indicator badge | Overlay glyph | Warning-glyph badge, 4px outside a tray slot's top-right corner | No (advisory, inspectable on hover/focus for plain-text detail) | New pattern — **Conflict Indicator** (see below), distinct from Sanctuary UI's Connection Badge (this one is a per-slot warning, not a per-tab notification counter) |

#### Content Zone — `HERO_SKILL_BUILD`

No shell-owned components — this screen is `hero-skill-build.md`'s own existing full-rect layout, hosted unmodified. Not re-specified here per this GDD's own UI Requirements section.

### ASCII Wireframe

#### `HERO_SKILL_BUILD` state (default landing)

```
┌────┬──────────────────────────────────────────────────────────────┐
│    │                              [Tarot risk: Speed×1.3 · 4 cards]│
│ ▣1 ├──────────────────────────────────────────────────────────────┤
│ hsb│                                                                │
│    │   [Hero Skill Build's own existing full-rect layout —        │
│ □2 │    library panel + 4 active slots + Ultimate readout,          │
│ trt│    unmodified from hero-skill-build.md's own UI Requirements] │
│    │                                                                │
└────┴──────────────────────────────────────────────────────────────┘
```

Legend: `▣1` = active tab (Hero Skill Build), `□2` = inactive tab (Tarot Deck), top-right readout = the Snapshot chip showing Tarot's current aggregate risk.

#### `TAROT_DECK` state, showing a Conflict Indicator

```
┌────┬──────────────────────────────────────────────────────────────┐
│    │                              [Ultimate: Frostspire Cascade]   │
│ □1 ├──────────────────────────────────────────────────────────────┤
│ hsb│                                                                │
│    │   [Tarot's own existing full-rect layout — deck tray +       │
│ ▣2 │    fanned card pool, unmodified from tarot.md's own UI        │
│ trt│    Requirements]                                               │
│    │                                                                │
│    │        ┌──────┐●                                              │
│    │        │ CARD │  ← Conflict Indicator badge (● = warning      │
│    │        └──────┘    glyph, 4px outside slot's top-right corner)│
└────┴──────────────────────────────────────────────────────────────┘
```

Legend: `▣2` = active tab (Tarot Deck), top-right readout = the Snapshot chip showing Hero Skill Build's current `ultimate_id`, `●` = Conflict Indicator badge on a tray slot whose `modifier_type` collides with an active Mission Select selection.

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| `HERO_SKILL_BUILD` | Default landing (Core Rule 2); tab/hotkey/`LT`/`RT` selection | That screen's own full layout mounts; Snapshot chip shows Tarot's risk readout |
| `TAROT_DECK` | Tab/hotkey/`LT`/`RT` selection | That screen's own full layout mounts, including any active Conflict Indicator badges; Snapshot chip shows Hero Skill Build's `ultimate_id` |
| Conflict Indicator active | A slotted Tarot card's `modifier_type` matches an active Mission Select `run_modifier_selected` per the mapping table (GDD Core Rule 6) | Badge appears on that tray slot; plain-text detail available on inspect |
| Gamepad pick-up abandoned | Player switches screens or exits mid-pick-up (Hero Skill Build's own 2-step confirm flow) | Silent — no toast, no error, no lingering visual on next entry (unlike Sanctuary UI's staged-discard toast, since this is a single unconsummated selection, not multi-step staged work) |
| Snapshot chip, empty Ultimate | Hero Skill Build has fewer than 4 slots filled | Chip shows "No Ultimate yet" instead of a blank/error state |

---

## Interaction Map

Interactions mapped for: **Keyboard/Mouse (primary), Gamepad (partial)** — same project-wide input configuration as Sanctuary UI.

### Complete Binding Table

| Action | K/M | Gamepad | Scope | Notes |
|---|---|---|---|---|
| Select screen directly | Click tab | — | Tab strip | Mouse-only direct-select |
| Cycle screen prev/next | `[` / `]` | `LT` / `RT` | Global (either state) | Only 2 entries — "cycle" and "toggle" are the same operation at this count. Not `LB`/`RB` — those stay owned by each screen's own internal category-cycling (Tarot's card-pool categories, Hero Skill Build's archetype filter) |
| Switch in-screen category (Tarot card pool, Hero Skill Build archetype filter) | Screen-owned bind | `LB` / `RB` | Inside active screen only | Deliberately never triggers a screen switch (Core Rule 2, same split as Sanctuary UI) |
| Navigate tab strip (focus move) | `↑`/`↓` or Tab/Shift+Tab | D-pad Up/Down | Tab strip | Only 2 entries — trivial traversal, no wrap-around ambiguity to resolve (unlike Sanctuary UI's 6-entry OQ-7) |
| Confirm focused tab | `Enter`/`Space` | `A` / South face button | Tab strip | Activates the focused tab |
| Inspect Conflict Indicator badge | Hover / click | Focus the slot, no dedicated confirm needed — badge detail shows whenever the slot itself is focused/hovered | `TAROT_DECK`, badge present | Plain text names the exact shared field and colliding selection — never icon-only at that tier (GDD Core Rule 6) |
| Cancel / Return to Sanctuary | `Esc` or explicit button | `B` / East face button, or explicit button | Either state | No confirmation of any kind — every edit is already committed |
| Hero Skill Build gamepad pick-up (1st confirm) | — | `A` on a library entry | `HERO_SKILL_BUILD` | Owned entirely by `hero-skill-build.md` — not re-specified here |
| Hero Skill Build gamepad pick-up (2nd confirm / place) | — | `A` on a target slot | `HERO_SKILL_BUILD` | Same — abandoning mid-pick-up via screen switch/exit is this shell's own concern (States & Variants row above), the pick-up mechanic itself is not |

### Focus Traversal Order

1. **Tab strip** (default focus on `HERO_SKILL_BUILD` entry): Hero Skill Build → Tarot Deck, top to bottom. No wrap-around ambiguity at 2 entries.
2. **Inside the active screen**: that screen's own `InputModeTracker` and its own documented focus order (`hero-skill-build.md`/`tarot.md`'s own concern, out of scope here).
3. No diorama-style secondary entry path exists in this shell (unlike Sanctuary UI's `OVERVIEW`) — the tab strip is the only focus region this spec owns.

This satisfies the accessibility requirement that both shell-level `InputModeTracker` regions (tab strip + whichever screen is active) are keyboard/gamepad-reachable with no mouse-only step — screen-internal completeness is each screen's own GDD's responsibility.

---

## Events Fired

### Outbound Events (Tarot Deck UI → EventBus)

| Player Action | Event Fired | Payload | Notes |
|---|---|---|---|
| None — internal screen switching fires no EventBus events (Core Rule 4) | — | — | Only the shell exit (Cancel/Return) is externally visible, and it's a direct call back to Sanctuary UI, not an EventBus emission |
| Cancel / Return confirmed | *(direct call, not EventBus)* a call to Sanctuary UI's own re-entry path | — | Per Core Rule 4; Sanctuary UI mounts fresh at `OVERVIEW`, the identical path any other arrival uses |

### Inbound Events Consumed (EventBus/direct-read → Tarot Deck UI, display only)

| Event / Read | Tarot Deck UI Response |
|---|---|
| Hero Skill Build's derived `ultimate_id` (direct read, already-computed) | Snapshot chip updates while `TAROT_DECK` is active |
| Tarot's aggregate risk value (`tarot_speed_scalar`/equipped-card count, direct read, already-computed) | Snapshot chip updates while `HERO_SKILL_BUILD` is active |
| `run_modifier_selected` (Mission Select, read indirectly via Tarot's own existing subscription) | Conflict Indicator badge shows/hides per the modifier-mapping table (Core Rule 6) |

No new EventBus event is introduced by this shell — every value it displays is a pre-existing read from a system that already computes it (matching the GDD's own "no formulas" framing).

---

## Transitions & Animations

Reuses Sanctuary UI's motion contract wholesale (snappy-in ≤120ms / eased-out settle 150–200ms, no overshoot) per the GDD's own "reuses wholesale" instruction.

| Transition | Trigger | Animation | Duration | Reduced-Motion Variant |
|---|---|---|---|---|
| Shell mount | Loadout selected in Sanctuary UI | Chrome + active screen fade in together | ~120ms snappy-in | Instant show |
| Screen switch (drawer-slide) | Tab/hotkey/`LT`/`RT` selection | Outgoing screen slides toward tab strip, incoming slides in from same edge, horizontal only | 200ms in / 220ms eased-out settle (matches Sanctuary UI's own room-switch knob) | Instant swap, no slide |
| Conflict Indicator badge appears | Mapped conflict detected | Scale-pop 1.0→1.15→1.0, matching Sanctuary UI's Connection Badge treatment | ~0.2s | Badge appears at final scale directly |
| Snapshot chip value change | Underlying derived value changes on the other screen | Scale-pop 1.0→1.15→1.0, matching the resource-header/chip convention | ~0.2s | Value updates instantly, no pop |
| Shell exit | Cancel/Return confirmed | Fade out (chrome + active screen together) | ~120ms | Instant hide |

No `DEPARTING`-style multi-beat transition exists here — exit is a single, symmetrical fade, since this shell's own exit is reversible lateral navigation, not an irreversible session-ending beat like Sanctuary UI's Launch/Depart.

---

## Data Requirements

Entirely read-heavy, same as Sanctuary UI — this shell computes nothing of its own.

| Data | Source System | Read/Write | Update Mechanism | Notes |
|---|---|---|---|---|
| Current shell state (`HERO_SKILL_BUILD`/`TAROT_DECK`) | Tarot Deck UI itself | Read/Write (local state) | Tab/hotkey/`LT`/`RT`/Cancel input | Not persisted |
| Hero Skill Build's `ultimate_id` | Hero Skill Build | Read | Direct read of already-derived state, live | For the Snapshot chip |
| Tarot's aggregate risk (`tarot_speed_scalar`/card count) | Tarot | Read | Direct read of already-derived state, live | For the Snapshot chip |
| `run_modifier_selected` | Mission Select, via Tarot's own existing subscription | Read (indirect) | Tarot's own subscription lifecycle | For the Conflict Indicator; this shell does not subscribe directly |
| Conflict mapping table (`modifier_type` ↔ `modifier_id`) | This GDD's own explicit constant (Core Rule 6) | Read (hardcoded) | Static, updated only if Mission Select's catalogue grows | Not runtime-derived from string comparison |

### Initial / Null State Specification

| Data | Initial Value at Mount | Null Fallback |
|---|---|---|
| Active state | `HERO_SKILL_BUILD` | Never null — always set synchronously on mount |
| Snapshot chip (Tarot risk view) | Reflects currently-equipped deck at mount time | Empty deck shows a zero/baseline risk readout, not a loading state |
| Snapshot chip (Ultimate view) | Reflects currently-resolved `ultimate_id` at mount time | `EMPTY` shows "No Ultimate yet," not a blank/error state |
| Conflict Indicator | Reflects current `run_modifier_selected` at mount time | No selection set → no badges shown, not an error state |

---

## Accessibility

Accessibility tier: **Standard** — same commitment as Sanctuary UI, per `design/accessibility-requirements.md`.

| Element | Concern | Requirement | Implementation Note |
|---|---|---|---|
| Tab strip active/inactive state | Color-as-only-indicator | Filled-vs-outline convention, same as Sanctuary UI — never color-only | Per GDD Visual/Audio Requirements: reuses the existing convention wholesale |
| Conflict Indicator badge | Color-as-only-indicator | Distinct warning-glyph shape, never a color-only dot; glyph reserved exclusively for this purpose (never reused from lock-state/mastery-pip iconography already on the same card) | Per GDD Core Rule 6/Visual Requirements, explicit |
| Both shell-level `InputModeTracker` regions | Keyboard/gamepad-only completion | Tab strip → active screen's own tracker, no mouse-only step | Screen-internal completeness is each screen's own GDD's responsibility |
| Snapshot chip text | Text scaling | Follows the project's committed UI scale slider (75%–150%); at 150% scale, if the chip's content would overflow its single-line budget, abbreviate (e.g. truncate a long Ultimate name with an ellipsis + full text on hover/focus) rather than allowing layout breakage | New commitment this spec adds, mirroring Sanctuary UI's own resource-header precedent |
| Screen-switch drawer-slide | Reduced motion | Instant swap (no slide) when reduced motion is enabled | Matches project's committed Standard-tier toggle |
| Conflict Indicator / Snapshot chip scale-pop | Reduced motion | Appears at final scale directly, no pop, when reduced motion is enabled | Same toggle |
| Conflict Indicator inspect text | Screen reader / low-vision | Plain text naming the exact shared field and colliding selection is always available on inspect, never icon-only at that tier | Per GDD Core Rule 6, explicit — this is itself an accessibility-relevant design choice, not just a UX nicety |

---

## Localization Considerations

Same 40% text-expansion discipline as Sanctuary UI.

| Element | Max English Length | Expansion Risk | Constraint |
|---|---|---|---|
| Tab label: "Hero Skill Build" | 16 chars | **HIGH** | ~22 chars at 40% expansion — label renders on focus/hover reveal only (not persistent), same icon-first pattern as Sanctuary UI's tab strip; cap the focus-reveal tooltip width to fit up to 26 chars before wrapping |
| Tab label: "Tarot Deck" | 10 chars | Medium | Same reveal-on-focus treatment |
| Snapshot chip (Ultimate name view) | Variable — Ultimate names are content-authored, could be long | **HIGH** | Single-line budget; truncate with ellipsis at a fixed character cap (recommend 24 chars) with full text available on hover/focus, rather than allowing the chip to grow and push into the content zone |
| Snapshot chip ("No Ultimate yet") | 16 chars | Medium | At 40% expansion ~22 chars — fits comfortably within the same single-line budget above |
| Snapshot chip (Tarot risk readout, e.g. "Speed×1.3 · 4 cards") | ~20 chars | **HIGH** | At 40% expansion ~28 chars — same single-line truncation rule as the Ultimate view |
| Conflict Indicator inspect text (names the shared field + colliding selection) | Variable | **HIGH** | This is the one place plain-text detail is mandatory (Core Rule 6) — cannot be abbreviated away. Render in a small popover/tooltip with its own wrap budget (recommend 2–3 lines, ~30 chars/line), not the chip's single-line constraint |

**HIGH PRIORITY for localization engineer**: "Hero Skill Build" tab label, the Snapshot chip's Ultimate-name and risk-readout views, and the Conflict Indicator's inspect text. All risk either truncation-losing-meaning or layout breakage — flag for string-length audit before each locale ships, matching Sanctuary UI's own established precedent.

---

## Acceptance Criteria

*(Supplies the Visual/Feel evidence-tier criteria this GDD's own Acceptance Criteria section does not cover at runtime-assertion level — see that GDD's precedent-following exclusion pattern. Does not duplicate the GDD's functional criteria.)*

- [ ] **Performance**: GIVEN the player switches screens via tab, hotkey, or `LT`/`RT`, WHEN the drawer-slide transition plays, THEN the outgoing screen's teardown and the incoming screen's mount both complete within the 200ms in / 220ms eased-out settle budget with no dropped frames below 60 FPS — confirmed by frame-time capture during implementation, not just visual inspection.
- [ ] **Navigation**: GIVEN the shell has just mounted from a Loadout selection, WHEN the tab strip is queried, THEN `HERO_SKILL_BUILD` is the focused and active entry, confirmed by a visible focus ring on that tab and no focus ring on Tarot Deck.
- [ ] **Error/empty state**: GIVEN Hero Skill Build has fewer than 4 slots filled (`ultimate_id == EMPTY`), WHEN `TAROT_DECK` is active, THEN the Snapshot chip displays "No Ultimate yet" rather than a blank or error-styled state — confirmed by screenshot.
- [ ] **Accessibility**: GIVEN reduced motion is enabled, WHEN a screen switch and a Conflict Indicator badge arrival each occur in the same test session, THEN both play their reduced-motion variant (instant swap, no scale-pop) with zero sliding or scaling animation observed — confirmed by side-by-side screenshot comparison against reduced motion disabled.
- [ ] **Core purpose**: GIVEN a player has an active Hero Skill Build loadout with a resolved Ultimate, WHEN they switch to `TAROT_DECK` without any other action, THEN the Snapshot chip already shows that Ultimate's name with no additional load/refresh step required — validating that the "one continuous act of self-assessment" claim (Purpose & Player Need) genuinely holds on arrival, not only after an explicit interaction.
- [ ] **Conflict Indicator legibility**: GIVEN a slotted Tarot card's badge is showing, WHEN the player inspects it via hover or gamepad focus, THEN plain text naming the exact shared field and colliding Mission Select selection appears within one interaction — no additional navigation required to see the detail.

---

## Open Questions

Carried forward from the GDD plus 1 new one this spec's authoring pass surfaced:

| # | Question | Owner | Source |
|---|---|---|---|
| OQ-3 (GDD) | The tab-strip landing default (`HERO_SKILL_BUILD` first, "build, then deck") is a design call made during authoring, not confirmed against playtest behavior — flagged as a real, repeated cost for a player who prefers Tarot first (no persisted "last used screen" memory is permitted). | Game Designer | `design/gdd/tarot-deck-ui.md` |
| OQ-5 (GDD) | Neither `tarot.md`'s nor `hero-skill-build.md`'s screen exists as an actual `.tscn` file yet — this spec's wireframes are structural approximations (full-rect layout, unmodified), not verified against real container/anchor structure. | UI Programmer | `design/gdd/tarot-deck-ui.md` |
| OQ-10 (new, this spec) | The Snapshot chip's truncation behavior for long Ultimate names (Localization table) is this spec's own provisional call (24-char cap, ellipsis + hover/focus full text) — not confirmed against actual content-authored Ultimate name lengths, since Hero Skill Build's own content-authoring pass hasn't happened yet. Worth revisiting once real Ultimate names exist. | UX Designer / Narrative | This spec (Localization Considerations) |

### New Interaction Patterns Introduced

One candidate for promotion into `design/ux/interaction-patterns.md` once a second user exists (matching Sanctuary UI's own "promote at second use" deferral):

- **Conflict Indicator** — an advisory-only, per-element warning badge that signals a cross-system data collision (not a player-resource state or a "something changed elsewhere" notification counter like Sanctuary UI's Connection Badge). Distinct because it's keyed to a specific data relationship (a mapped modifier-type pairing) rather than a generic event-count increment, and always resolves to plain-text detail on inspect rather than staying icon-only.

The **Persistent Room Tab Strip** and **Current-Build/Connection-Badge-family** patterns Sanctuary UI's own UX spec already flagged as candidates now have a genuine second user each (this shell's 2-entry tab strip; this shell's Snapshot chip as a variant of the read-only cross-reference register) — worth promoting both to the pattern library together, next time `design/ux/interaction-patterns.md` is revised, rather than leaving them as two separate single-document flags.

---

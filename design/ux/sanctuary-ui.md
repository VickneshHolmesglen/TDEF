# UX Spec: Sanctuary UI

> **Status**: Current (2026-07-24, follow-up pass complete). History: `/ux-review` found 1 blocking issue (a malformed Information Hierarchy table row — fixed) and 3 advisory issues (2 fixed same-session [toast missing from Component Inventory; no resolution/aspect-ratio AC], 1 left open as an inherited, pre-existing project-wide drift not this document's defect to fix [Standard-vs-Comprehensive reduced-motion tier inconsistency between `accessibility-requirements.md` and established `mission-hud.md` precedent]). Later the same day, the governing GDD's Core Rule 10 was redesigned (Loadout became a genuine 6th tab-strip entry), making this spec briefly stale (tracked as OQ-9). **This follow-up pass (2026-07-24, later still) closes that gap**: both ASCII wireframes, Component Inventory, the full binding table, Focus Traversal Order, Entry & Exit Points, States & Variants, and Events Fired are all now updated for the 6-entry tab strip. OQ-9 is Resolved. This spec is current for implementation.
> **Author**: Claude Sonnet (autonomous session, no user review)
> **Last Updated**: 2026-07-24
> **Journey Phase(s)**: Not tracked — `design/player-journey.md` does not exist in this project. This spec's Player Context on Arrival section below stands in for that mapping until a formal journey document exists; flagged here per the skill's own gap-reporting convention, and again in Open Questions.
> **Template**: UX Spec
> **Governing GDD**: `design/gdd/sanctuary-ui.md` (Needs Revision status at time of writing, but this UX spec authors against its Detailed Design in full — the "Needs Revision" flag is a request for one more formal `/design-review` confirmation pass, not an indication the content is unreliable; this spec should be re-checked against that GDD if it changes materially before implementation)

---

## Purpose & Player Need

Sanctuary UI is the only player-facing surface for five otherwise-invisible systems (Inventory, Crafting, Menagerie, Defense Building, Equipment Forge) and for the Sanctuary-overview diorama itself — the physical embodiment of the Player Fantasy's "self-portrait taking shape." It serves two distinct needs that must never fight each other for the same pixels: **(1) the contemplative "step back and look" need** — a player who just finished a mission wants a moment to see what their choices built, with zero task pressure — and **(2) the efficient "get to work" need** — a player who knows exactly which room they want and should reach it in one input, from anywhere, without a tour through intermediate screens.

The shell fails if either need crowds out the other: a diorama so small it can't be appreciated, or a room-switch flow so slow or buried that "I want to check Crafting" becomes a multi-step hunt. It also fails if the Player Fantasy's cross-system promise ("a choice in one drawer lights up the connected slots in another") goes undelivered — the GDD's Core Rule 9 revision narrowed this to tab-strip-level Connection Badges specifically so it stays deliverable; this spec's job is to make sure that narrower promise is still felt as connection, not just as a stray notification icon.

Success is a player who, on any post-mission return, spends a few unhurried seconds looking at `OVERVIEW` before diving into a room — and who, mid-session, can jump to any of the 5 rooms in one input without thinking about navigation at all.

---

## Player Context on Arrival

*(Standing in for `design/player-journey.md`, which does not yet exist in this project — see Open Questions.)*

| Arrival Moment | Prior Action | Emotional State | Primary Player Need |
|---|---|---|---|
| **Post-mission return (forced)** | `MISSION_COMPLETE` or `DEFEAT` just resolved | Coming down from combat — satisfaction or disappointment, either way seeking a beat to reset | See the sanctuary reflect what just happened (new structure, if one was earned); orient before deciding what's next |
| **Voluntary mid-session return** | Player pressed tab 1 / hotkey `1` from inside a room | Task-focused, briefly checking in | Confirm a change landed (e.g. "did that structure actually appear?"), or just take the offered break before continuing |
| **Direct room entry (returning player)** | Player already knows which room they want (e.g. "I have new materials, straight to Crafting") | Purposeful, low patience for ceremony | Reach the room in one input; no forced detour through `OVERVIEW` first |
| **First-ever mount (new player)** | Very first mission just completed | Orienting — first time seeing this screen at all | Understand there are 5 rooms and 2 ways to move between them (tab strip direct-select vs. `[`/`]`/triggers cycle) — this is what the onboarding tooltip (Core Rule 2) exists to solve |
| **Mid-room, Connection Badge appears** | Player is deep in one room, unrelated to the badge's origin | Focused on current task | Notice the badge without being pulled out of flow; understand roughly what it means without opening the room (per the GDD's Experiential Criterion) |

Design implication: because entry always defaults to `OVERVIEW` (Core Rule 5) regardless of arrival moment, the `OVERVIEW` state itself must satisfy the *first* need (the contemplative beat) every single time, even for a player who's about to immediately hotkey away from it. This spec treats that beat as "available, never mandatory" — nothing about `OVERVIEW` should force a dwell time.

---

## Navigation Position

Sanctuary UI is a top-level destination, not a sub-screen. It sits at:

`Mission Select → [Mission] → MISSION_COMPLETE / DEFEAT → Sanctuary UI (OVERVIEW) → Mission Select`

Within Sanctuary UI itself, navigation is flat, not hierarchical, for the 5 rooms — the tab strip presents all 5 as siblings, one input apart from each other and from `OVERVIEW`. The only hierarchy that exists is *inside* a room (e.g. Equipment Forge's Craft/Imbue toggle, Menagerie's breeding-pen flow), which is that room's own concern per its own GDD, not this shell's.

---

## Entry & Exit Points

### Entry Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Mission Select / Mission scene | `mission_phase_changed → MISSION_COMPLETE`, SceneManager transitions | Post-mission resource deltas already applied (Resource Economy), any new `sanctuary_structure_built` event already fired or about to fire |
| Mission Select / Mission scene | `mission_phase_changed → DEFEAT`, SceneManager transitions | Same as above — DEFEAT does not strip Sanctuary progress per `game-concept.md` Core Rule 11 |

Both entry sources land identically: a fresh Sanctuary UI instance, `OVERVIEW` active, tab strip default-focused (Core Rule 5, Core Rule 6's focus default).

### Exit Points

| Exit Destination | Trigger | Notes |
|---|---|---|
| Mission Select (`BROWSING` state) | Launch/Depart confirmed from `OVERVIEW` | Irreversible session-ending exit (Core Rule 8) — routed through `DEPARTING` transitional state first, `OVERVIEW`-only. |
| Tarot Deck UI | Loadout tab-strip entry selected (Core Rule 2/10) | Reversible lateral hand-off, reachable from **any** state (`OVERVIEW` or any `ROOM_*`), not `OVERVIEW`-only — routed through `DEPARTING_TO_LOADOUT` transitional state first. Tears down any active room per Core Rule 6 before hand-off. On return, a fresh Sanctuary UI instance mounts at `OVERVIEW` — same entry path as any other arrival, not a special-cased "return from Loadout." |

There is no "quit to desktop" or "return to main menu" affordance owned by this spec — that's Pause Menu / Main Menu territory, out of scope here.

---

## Layout Specification

### Information Hierarchy

| Priority | Element | State Visibility | Rationale |
|---|---|---|---|
| 1 | Room Tab Strip (icons + Connection Badges) | Always | The one navigation surface that's always present — every decision about where to go starts here |
| 2 | Persistent Resource Header | Always | Read-only orientation — the player should never wonder "what do I have to spend" regardless of where they are |
| 3 | Sanctuary-overview diorama | `OVERVIEW` only | The Player Fantasy's core deliverable — full frame while active, per Core Rule 1 |
| 4 | Launch/Depart action | `OVERVIEW` only | The single most consequential action in this screen (it ends the session) — deliberately confined to the one state where the player has just taken their contemplative beat, never reachable mid-task from inside a room |
| 5 | Room content (via `RoomHost`) | Active `ROOM_*` state only | Full frame, unmodified from each room's own GDD — this spec does not re-specify room-internal layout except where noted (Inventory+Crafting wireframe below) |
| 6 | Onboarding tooltip | First mount only, session-local | Discoverability for the trigger/bumper split — transient, never persists past dismissal or first-input |
| 7 | "Staged changes discarded" toast | Event-driven (room switch away from unconfirmed staged state) | Loss-of-progress notice — must be seen, but must not block the fast tab-switch flow it's reporting on |

### Layout Zones

```
┌─────┬─────────────────────────────────────────────────────────┐
│     │  ZONE H — RESOURCE HEADER (always, ≤64px tall)           │
│  Z  │  [🪙 Gold: 340]  [Materials: Wood 12 · Iron 4 · Silk 2]  │
│  O  ├─────────────────────────────────────────────────────────┤
│  N  │                                                           │
│  E  │  ZONE C — CONTENT (RoomHost, full frame minus chrome)     │
│     │                                                           │
│  T  │  Either:                                                 │
│  —  │   • OVERVIEW: full-canvas diorama (secondary entry path  │
│  T  │     via structure/habitat click)                         │
│  A  │   • ROOM_*: that room's own full-rect screen, unmodified │
│  B  │                                                           │
│     │  Launch/Depart button renders inside this zone, OVERVIEW │
│  S  │  only — bottom-right corner of the diorama frame          │
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
| Tab Strip (left edge, ≤96px) | Always | **6 entries** top-to-bottom (updated 2026-07-24 — the GDD's Core Rule 2/10 was redesigned to add Loadout as a genuine tab-strip entry, after this spec was originally authored against the 5-entry version): Overview, Inventory & Crafting, Menagerie, Defense Building, Equipment Forge, Loadout. Icon-only at rest; label reveals on focus/hover (Tuning Knobs). Connection Badges overlay the icon's top-right corner on the 4 room entries only — Loadout never carries one (GDD Core Rule 2). Selecting Loadout triggers `DEPARTING_TO_LOADOUT` (a shell exit to Tarot Deck UI) instead of a room mount, reachable from any state, not `OVERVIEW`-only. **The wireframes and legend below still show the pre-redesign 5-entry layout and have not yet been refreshed — flagged as Open Question OQ-9, not silently left inconsistent.** |
| Resource Header (top edge, ≤64px) | Always | Gold + materials, read-only, no focus ring ever (Core Rule 3) |
| Content / `RoomHost` (remaining frame) | Always, content swaps | `OVERVIEW`'s diorama or the active room's full-rect screen — never both, never neither |

This is a deliberately thin, static two-strip chrome frame (left + top) around a single dominant content region — no additional always-on margin, matching Core Rule 1's explicit rejection of the pre-revision "diorama-always-visible-in-a-margin" model.

### Component Inventory

#### Tab Strip

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Tab entry ×6 (updated 2026-07-24) | Icon button + label-on-focus | Room icon, label, active-state fill | Yes — click / hotkey `1`–`6` / `[`/`]` / `LT`/`RT` | New pattern candidate: **Persistent Room Tab Strip** (see Interaction Patterns note below). 5 of the 6 select a shell-internal state; the 6th (Loadout) triggers a shell hand-off instead — visually identical entry type, different activation outcome, no special-cased styling |
| Connection Badge ×4 (on Inventory/Menagerie/Defense Building/Equipment Forge entries only — `OVERVIEW`'s own tab and the Loadout tab never carry one) | Overlay icon + optional count | Small badge glyph, corner-anchored on the tab icon | No (informational only) | New pattern — **Connection Badge** (see below). Loadout's carve-out is deliberate (GDD Core Rule 2/OQ-8), not an oversight |
| Onboarding tooltip | One-time contextual tooltip | One line: trigger/bumper split | Dismiss on any input | Reuses tooltip conventions from `interaction-patterns.md`'s Gap list ("Tooltip on hover" — not yet formally catalogued; this is a second user, worth promoting once authored) |
| "Staged changes discarded" toast | Non-blocking notification toast | One line, room-name-agnostic phrasing ("Staged changes discarded") | No (informational only, auto-hold then fade) | Matches `interaction-patterns.md`'s existing Gap list entry **"Floating notification toast"** (added to the review pass 2026-07-24 — this component should cite that gap entry rather than being treated as unprecedented; distinct from the onboarding tooltip's contextual-hover-tooltip lineage) |

#### Resource Header

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Gold counter | Data display | Icon + numeric | No | Pattern 5 (Resource Counter) |
| Materials counter(s) | Data display | Icon + numeric, per material type currently tracked | No | Pattern 5 (Resource Counter) |

#### Content Zone — `OVERVIEW`

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Diorama | World-space full-canvas render | Built structures + habitat occupancy at fixed positions | Yes — click a structure/habitat (secondary entry path) | Reuses the oblique-camera diorama convention (`art-bible.md`), stacked-sprite/shadow treatment |
| Structure/habitat inert tooltip | Contextual info | Structure name, "no gameplay effect" framing for structures with no room | No | Adjacent to Pattern 2 (Contextual Info Panel) but lighter-weight — a single-line tooltip, not a full panel |
| Launch/Depart button | Primary action button | "Launch Mission" (see Localization) | Yes | Fully-chamfered primary-action button per art bible's UI shape family |

#### Content Zone — `ROOM_INVENTORY_CRAFTING` (the one room that exists in code today)

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Slot grid (left panel) | `GridContainer`, 5 columns | Inventory item slots | Yes — select item | Not yet a named pattern in `interaction-patterns.md` — flagged as a gap below |
| Category tab strip (in-room, above slot grid) | `HBoxContainer` | Item category tabs (this room's own `LB`/`RB` bumper-switched tabs per Core Rule 2) | Yes — `LB`/`RB` or click | Distinct from the shell's own Room Tab Strip — different physical input (bumpers vs. triggers), different scope (in-room categories vs. cross-room navigation) |
| Crafting panel (right panel) | `PanelContainer` | Recipe list / crafting interaction | Yes | Room-owned, unchanged from `crafting.md` |

### ASCII Wireframe

#### `OVERVIEW` state

```
┌────┬──────────────────────────────────────────────────────────────┐
│    │ 🪙 Gold: 340        Materials: Wood 12 · Iron 4 · Silk 2      │
│ ▣1 ├──────────────────────────────────────────────────────────────┤
│ ov │                                                                │
│    │        [Watchtower]      [Habitat: Menagerie]                 │
│ □2 │            ▲                    ▲                             │
│ inv│                                                                │
│    │                    [Sanctuary keep]                           │
│ □3 │                        ▲                                      │
│ men│                                                                │
│    │   [Forge structure]           [Tech spire]                    │
│ □4 │        ▲                          ▲                           │
│ def│                                                                │
│    │                                                                │
│ □5 │                                            ┌─────────────────┐│
│ frg│                                            │  LAUNCH MISSION ││
│    │                                            └─────────────────┘│
│ □6 │                                                                │
│ ldt│                                                                │
└────┴──────────────────────────────────────────────────────────────┘
```

Legend: `▣1` = active tab (Overview), `□2`–`□6` = inactive tabs (icon shown, label hidden — labels shown here for wireframe clarity only), `▲` = clickable structure/habitat (secondary entry path), `ldt` = Loadout (updated 2026-07-24 — the tab strip's own height grows to fit this 6th entry per Core Rule 2's `VBoxContainer`-of-fixed-width-entries architecture; entry width is unchanged), diorama rendered at full content-zone size. Note Loadout selection never mounts room content in this content zone — it triggers a hand-off to Tarot Deck UI instead (see Entry & Exit Points).

#### Tab strip detail, showing a Connection Badge

```
┌────┐
│ □1 │  ← Overview (never carries a badge)
│ ov │
├────┤
│ □2 │  ← Inventory & Crafting
│ inv│
├────┤
│ □3●│  ← Menagerie — Connection Badge showing (● = badge glyph,
│ men│     e.g. a creature just reached READY state)
├────┤
│ □4 │  ← Defense Building
│ def│
├────┤
│ □5 │  ← Equipment Forge
│ frg│
├────┤
│ □6 │  ← Loadout (never carries a badge — GDD Core Rule 2's
│ ldt│     deliberate carve-out, OQ-8, not an oversight)
└────┘
```

The badge sits corner-anchored on the icon (top-right), does not push or resize the tab, and clears the instant that tab is entered (Core Rule 2). Loadout is structurally excluded from ever showing one, not merely unconfigured.

#### `ROOM_INVENTORY_CRAFTING` state

```
┌────┬──────────────────────────────────────────────────────────────┐
│    │ 🪙 Gold: 340        Materials: Wood 12 · Iron 4 · Silk 2      │
│ □1 ├──────────────────────────────────────────────────────────────┤
│ ov │ [All][Components][Materials][Consumables] ← LB/RB switches   │
│    │ ┌────┬────┬────┬────┬────┐   ┌────────────────────────────┐ │
│ ▣2 │ │ IT │ IT │ IT │ IT │ IT │   │ CRAFTING                    │ │
│ inv│ ├────┼────┼────┼────┼────┤   │ Recipe list:                │ │
│    │ │ IT │ IT │ IT │ IT │ IT │   │  ▣ Iron Foundation  (owned) │ │
│ □3 │ ├────┼────┼────┼────┼────┤   │  ▣ Silk Focus       (owned)│ │
│ men│ │ IT │ IT │ IT │ IT │ IT │   │  ░ Amber Power   (locked)  │ │
│    │ └────┴────┴────┴────┴────┘   │ [Craft Selected]            │ │
│ □4 │                                └────────────────────────────┘ │
│ def│                                                                │
│    │                                                                │
│ □5 │                                                                │
│ frg│                                                                │
│    │                                                                │
│ □6 │                                                                │
│ ldt│                                                                │
└────┴──────────────────────────────────────────────────────────────┘
```

Legend: `IT` = inventory item slot, `▣` = active tab / owned recipe, `░` = locked recipe. Loadout (`□6`/`ldt`) remains visible and selectable while any room is active — including from inside Inventory & Crafting shown here — per Core Rule 10's "reachable from any state" rule. Matches `InventoryScreen.tscn`'s actual `HBoxContainer`(`LeftPanel` `stretch_ratio=2.0` / `RightPanel` `stretch_ratio=1.0`) split — this wireframe is proportioned to reflect that real 2:1 ratio, not an arbitrary guess. The room occupies the full content zone (frame minus tab strip width and header height) with no additional shell chrome inside it.

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| `OVERVIEW` | Default entry (Core Rule 5); tab 1 / hotkey `1`; `[`/`]`/`LT`/`RT` cycle lands here | Diorama renders full content zone; Launch/Depart visible; tab strip default-focused unless diorama explicitly entered |
| `ROOM_INVENTORY_CRAFTING` / `ROOM_MENAGERIE` / `ROOM_DEFENSE_BUILDING` / `ROOM_EQUIPMENT_FORGE` | Tab/hotkey/`LT`/`RT` selection; fresh instance per Core Rule 6 | That room's own full screen mounts in `RoomHost`; Launch/Depart absent; that room's own `InputModeTracker` gains focus at its own default |
| `DEPARTING` | Launch/Depart confirmed | Chrome fades (fastest first), diorama pulls back and settles, all input discarded (terminal latch) |
| `DEPARTING_TO_LOADOUT` (added 2026-07-24) | Loadout tab selected from **any** state | Any active room torn down first (Core Rule 6); shell hands off to Tarot Deck UI; all further input discarded (shared terminal latch with `DEPARTING`, Core Rule 10). No dedicated visual beat is specified by the GDD beyond the room-teardown that was already in flight — this spec does not invent a separate `DEPARTING_TO_LOADOUT`-specific transition animation, since Core Rule 10 explicitly frames the walk to Loadout as "one continuous motion," not a second departure beat mirroring `DEPARTING`'s own pacing |
| Onboarding tooltip active | First-ever mount this session | Non-blocking tooltip anchored to tab strip; dismisses on any input |
| Connection Badge present | Badge-trigger event fires for a non-active room | Badge appears with scale-pop on that tab's icon corner; clears instantly on entry |
| Diorama-selection focus | Player explicitly directs input at the diorama (click, or `Down` from tab strip's bottom tab) | Focus moves from tab strip's `InputModeTracker` to `OVERVIEW`'s own structure-selection tracker; Cancel returns focus to tab strip |
| "Staged changes discarded" toast | Room switch away from Equipment Forge/Defense Building with unconfirmed staged state | Brief non-blocking toast on the departing room's own affordance, or a shell-level equivalent if the room has none |
| No-op Cancel | Cancel pressed with tab strip focused, no room open | Nothing happens — explicit no-op, not silently mapped elsewhere |
| Structure with no room clicked | `OVERVIEW` secondary entry path, structure has no room mapping (e.g. Watchtower) | Inert tooltip names the structure; no room-mount attempted; state remains `OVERVIEW` |

---

## Interaction Map

Interactions mapped for: **Keyboard/Mouse (primary), Gamepad (partial)**. All interactions must be completable with K/M — per `.claude/docs/technical-preferences.md`, this is a project-wide decision, not a per-screen choice.

### Complete Binding Table

| Action | K/M | Gamepad | Scope | Notes |
|---|---|---|---|---|
| Select tab-strip entry directly | Click tab | — | Tab strip | Mouse-only direct-select; gamepad uses D-pad focus + confirm instead (see below). Applies to all 6 entries, including Loadout |
| Jump to entry by number (updated 2026-07-24) | `1`–`6` | — | Global (any state) | `1`=Overview, `2`=Inventory & Crafting, `3`=Menagerie, `4`=Defense Building, `5`=Equipment Forge, `6`=Loadout. `6` reaches `DEPARTING_TO_LOADOUT` from any state, not `OVERVIEW`-only — unlike Launch/Depart, which has no hotkey and is `OVERVIEW`-only by design |
| Cycle entry prev/next (updated 2026-07-24) | `[` / `]` | `LT` / `RT` | Global (any state) | Wraps at both ends (6↔1, updated from the pre-redesign 5-item wrap) — not explicitly stated in the GDD; this spec makes that call (see Open Questions) |
| Switch in-room tab (Inventory categories, Defense Building Tech/Build, Equipment Forge Craft/Imbue) | Room-owned bind (e.g. `Q`/`E` or click) | `LB` / `RB` | Inside active room only | Deliberately never triggers a room switch (Core Rule 2) |
| Navigate tab strip (focus move) | `↑`/`↓` or Tab/Shift+Tab | D-pad Up/Down or Left Stick Up/Down | Tab strip | Focus-ring traversal, top (Overview) to bottom (Equipment Forge) |
| Confirm focused tab | `Enter`/`Space` | `A` / South face button | Tab strip | Activates the focused tab, same result as a click |
| Enter diorama (structure-selection focus) | Click a structure directly | `Down` from the tab strip's bottom-most focused tab (Equipment Forge) | `OVERVIEW`, tab strip → diorama handoff | This is the "dedicated input" the GDD (Core Rule 6) left unnamed — this spec names it concretely as **`Down` from the bottom tab, mirroring a list-to-grid boundary handoff** |
| Navigate diorama structures | Mouse hover/click | D-pad / Left Stick (moves selection between clickable structures, nearest-neighbor by screen position) | `OVERVIEW`, diorama focus | Structures with no room mapping are still focus-reachable (they show the inert tooltip) |
| Select/enter a structure's room | Click | `A` / South face button | `OVERVIEW`, diorama focus | Secondary entry path into that room |
| Cancel (diorama → tab strip) | `Esc` | `B` / East face button | `OVERVIEW`, diorama focus | Returns focus to tab strip, per Core Rule 6's explicit "never to nothing" rule |
| Cancel (in-room nested state) | `Esc` | `B` / East face button | Inside active room | Steps back one nested stage (room-owned behavior, Core Rule 7) |
| Cancel (room root → `OVERVIEW`) | `Esc` | `B` / East face button | Room root | Exits room, destroys instance, returns to `OVERVIEW` (Core Rule 6/7) |
| Cancel (tab strip, no room open) | `Esc` | `B` / East face button | Tab strip, `OVERVIEW` | No-op — explicit, not silently remapped (Edge Cases) |
| Launch/Depart | Click button | `A` / South face button (button must be focus-reachable via the same tab-strip-adjacent traversal) | `OVERVIEW` only | Only interactive surface that ends the Sanctuary UI session — irreversible, pacing-gated |
| Select Loadout (added 2026-07-24) | Click tab | `A` / South face button on focused tab, or `LT`/`RT`/hotkey `6` | Global — any state, `OVERVIEW` or any `ROOM_*` | Reversible lateral navigation, no pacing gate — same activation mechanism as any other tab entry (Core Rule 10's own explicit "same button, different focus path to reach it" framing); tears down any active room before hand-off |
| Dismiss onboarding tooltip | Any input | Any input | First mount only | No dedicated dismiss button — any input works, including the input that triggers the action itself |

### Focus Traversal Order

1. **Tab strip** (default focus on `OVERVIEW` entry, per Core Rule 6): Overview → Inventory & Crafting → Menagerie → Defense Building → Equipment Forge → Loadout, top to bottom, wrapping top↔bottom on continued `↑`/`↓` press (updated 2026-07-24 — Loadout is now the bottom-most tab entry, not Equipment Forge).
2. **`Down` from Loadout (now the bottom tab, updated 2026-07-24)** hands off to the diorama's structure-selection tracker (only reachable when `OVERVIEW` is active — this input is inert/no-op while any `ROOM_*` state is active, since the diorama isn't rendered then). Since Loadout itself confirms via `A`/South face/click rather than `Down`, this boundary-crossing input and Loadout's own activation input remain distinct and don't conflict on the focused Loadout tab.
3. **Diorama structure-selection ring**: nearest-neighbor spatial traversal between clickable structures/habitats. `Esc`/`B` returns to step 1.
4. **Inside a room**: that room's own `InputModeTracker` and its own documented focus order (out of scope for this spec — see each room's own GDD/UX).
5. **Launch/Depart button**: reachable as the final stop past the diorama's structure ring (or via a direct `Tab`/D-pad-right from the tab strip, whichever the eventual implementation finds more natural — flagged as an implementation-detail choice, not fixed here, since the GDD doesn't specify it and both are equally valid Standard-tier options).

This satisfies the accessibility requirement (below) that all 6 `InputModeTracker` regions (4 rooms + tab strip + `OVERVIEW`'s diorama ring) are keyboard/gamepad-reachable with no mouse-only step.

---

## Events Fired

### Outbound Events (Sanctuary UI → EventBus)

| Player Action | Event Fired | Payload | Notes |
|---|---|---|---|
| None — Sanctuary UI's internal room/tab navigation fires no EventBus events (Core Rule 8) | — | — | Only the eventual Launch/Depart or Loadout hand-off is externally visible, and both are direct calls, not EventBus emissions (Core Rule 8/10, Interactions table) |
| Launch/Depart confirmed | *(direct call, not EventBus)* `MissionSelect.enter_browsing()`-equivalent | — | Per Core Rule 8 + Interactions table; exact call signature owned by whichever ADR formalizes this (OQ-2 in the GDD, still open) |
| Loadout selected (added 2026-07-24) | *(direct call, not EventBus)* a call to Tarot Deck UI's own established entry point, per `tarot-deck-ui.md`'s Interactions table | — | Per Core Rule 10; same precision tier as the Launch/Depart call above; exact call signature also owned by whichever ADR formalizes both hand-offs — ADR-0032 (Presentation Shell Hosting Pattern, 2026-07-24) formalizes the destroy-and-recreate/terminal-latch mechanics this call sits behind, but the call's own ADR-0020 Criterion A/B classification remains open (OQ-9 in the GDD) |

### Inbound Events Consumed (EventBus → Sanctuary UI, display/state only)

| Event | Sanctuary UI Response |
|---|---|
| `scene_transition_completed(target_context="SANCTUARY")` | Mounts/resets to `OVERVIEW` (sole mount trigger) |
| `sanctuary_structure_built` | Diorama's structure rendering updates immediately regardless of active state; increments Defense Building's Connection Badge if that room isn't active |
| `resources_changed` / `materials_earned` / `materials_spent` | Resource header updates; scale-pop feedback on the changed value |
| `recipe_unlocked` | Increments Inventory & Crafting's Connection Badge (Tuning Knob, provisional per OQ-6) |
| Creature reaches `READY` state | Increments Menagerie's Connection Badge (Tuning Knob, provisional per OQ-6) |
| `rune_socket_unlocked` | Increments Equipment Forge's Connection Badge (Tuning Knob, provisional per OQ-6) |

All of the above are discarded once `DEPARTING` is entered (terminal latch, Edge Cases).

---

## Transitions & Animations

All timings are design targets pending art direction sign-off, and match `mission-hud.md`'s established motion contract (snappy-in ≤120ms / eased-out settle 150–200ms, no overshoot) per this GDD's explicit "reuses wholesale" instruction. Reduced-motion variants are noted per entry — this project's committed Standard-tier "Motion / animation reduction mode" toggle applies to every entry below.

| Transition | Trigger | Animation | Duration | Reduced-Motion Variant |
|---|---|---|---|---|
| Sanctuary UI mount | `scene_transition_completed` | Chrome + diorama fade in together | ~120ms snappy-in | Instant show |
| Room switch (drawer-slide) | Tab/hotkey/`LT`/`RT` selection | Outgoing room slides left (toward tab strip), incoming slides in from the same edge, overlapping briefly | 200ms in / 220ms eased-out settle (Tuning Knobs) | Instant swap — outgoing room disappears, incoming appears, no slide |
| Connection Badge appears | Badge-trigger event fires | Scale-pop 1.0→1.15→1.0, matching resource header's existing treatment | ~0.2s | Badge appears at final scale directly, no pop |
| Connection Badge clears | That room is entered | Instant removal, no fade | 0 (immediate) | Same — already instant, nothing to reduce |
| Resource header value change | `resources_changed`/`materials_earned`/`materials_spent` | Scale-pop 1.0→1.15→1.0 | ~0.2s | Value updates instantly, no pop |
| `DEPARTING` beat | Launch/Depart confirmed | Chrome fades out first/fastest; diorama camera pulls back and settles (60% fade+pull-back / 40% hold-on-settled-frame) | ~0.5s total (Tuning Knobs) | Instant cut to the settled framing, then hand-off — no pull-back animation, hold beat removed since it exists to sell the animated pull-back |
| Onboarding tooltip appear/dismiss | First mount / any input | Fade in on mount; fade out on dismiss input | ~120ms each | Instant show/hide |
| "Staged changes discarded" toast | Room switch away with unconfirmed staged state | Slide/fade in, auto-hold, fade out (non-blocking) | ~2s total (matches Pattern 10's Phase Transition Banner cadence — not gameplay-critical, so full reduced-motion collapse applies) | Instant show, hold, instant hide |
| Diorama focus handoff (tab strip → structure ring) | `Down` input from bottom tab | Focus ring outline moves from tab strip to nearest diorama structure | Instant (focus rings don't ease) | No change — already instant |

**Provisional call flagged**: the GDD's Visual/Audio Requirements section specifies the `DEPARTING` beat's reduced-motion behavior only implicitly (it describes the full-motion version in detail but doesn't give an explicit reduced-motion variant, unlike `mission-hud.md` which specs every transition's reduced-motion fallback explicitly). This spec provisionally defines one above (instant cut to settled framing, no pull-back, no hold) to close that gap, following `mission-hud.md`'s own precedent for terminal-transition reduced-motion (its MISSION_COMPLETE/DEFEAT row: "Cut to outcome screen"). Flagged for confirmation, not silently assumed as final.

---

## Data Requirements

Sanctuary UI is almost entirely read-heavy — a pure subscriber/display shell, per the GDD's own "no formulas" framing (Detailed Design → Formulas: "every value it displays... is a direct EventBus payload read or a simple counter increment/clear").

| Data | Source System | Read/Write | Update Mechanism | Notes |
|---|---|---|---|---|
| Current shell state (`OVERVIEW`/`ROOM_*`/`DEPARTING`) | Sanctuary UI itself | Read/Write (local state) | Tab/hotkey/`LT`/`RT`/Cancel/Launch-Depart input | Not persisted (Save & Persistence owns nothing here) |
| Gold / materials balances | Resource Economy | Read | `resources_changed`/`materials_earned`/`materials_spent`, plus a mount-time poll fallback (Edge Cases) | Header is read-only, never authoritative for spend checks |
| Structure positions + build state | Defense Building / Sanctuary-overview's own rendering data | Read | `sanctuary_structure_built` event; diorama keeps listening regardless of active state | |
| Connection Badge counts (per room) | EventBus, various (see Tuning Knobs) | Read | Increments on trigger event; cleared to 0 on room entry | Purely informational, no persisted unread state |
| Onboarding-seen flag | Session-local (not `save-persistence.md`-tracked) | Read/Write | Set on first mount this session; not saved across sessions | Matches "no UI state is ever saved" (Core Rule 2) |
| Room content (all 5 rooms) | Each room's own GDD/scene | Read (hosted, not owned) | Room's own event subscriptions; Sanctuary UI only controls mount/unmount timing | Sanctuary UI never reads or writes into a room's internal state directly |

### Initial / Null State Specification

| Data | Initial Value at Mount | Null Fallback |
|---|---|---|
| Active state | `OVERVIEW` | Never null — always set synchronously on mount, before any input is processed. Now 7 possible values (`OVERVIEW`, 4 `ROOM_*` states, `DEPARTING`, `DEPARTING_TO_LOADOUT` — updated 2026-07-24 to include the redesigned Loadout transitional state) |
| Resource header values | Direct poll of Resource Economy's current balance | If `resources_changed` hasn't fired yet, the poll covers it (Edge Cases) — never shows an empty/loading state |
| Connection Badges | All 4 room tabs start with no badge | 0/absent is a valid, common state — not an error |
| Onboarding tooltip | Shown if this is truly the first mount this session | Not shown on any subsequent mount this session |
| Diorama structure render | Reflects Defense Building's currently-built state at mount time | If no structures are built yet, diorama renders its base/empty layout — not a loading placeholder |

### EventBus Gaps

None identified as newly missing by this UX pass — all events this spec consumes (`scene_transition_completed`, `sanctuary_structure_built`, `resources_changed`, `materials_earned`, `materials_spent`) are already named as existing in the GDD's own Interactions/Edge Cases sections. The 4 Connection Badge trigger events (`recipe_unlocked`, creature `READY`, `sanctuary_structure_built`, `rune_socket_unlocked`) are the GDD's own Tuning Knob first-pass guess (OQ-6) — this spec does not independently verify they exist in `event-bus.md`; that verification is exactly what OQ-6 already asks for and is carried forward rather than silently assumed resolved here.

---

## Accessibility

Accessibility tier: **Standard** — per `design/accessibility-requirements.md`. The GDD commits only to "non-color-first tab state" explicitly; everything below extends that into the full Standard-tier commitment this project has already made project-wide.

| Element | Concern | Requirement | Implementation Note |
|---|---|---|---|
| Tab strip active/inactive state | Color-as-only-indicator | Filled-vs-outline convention (existing project pattern) — active tab is never distinguished by color alone | Per GDD Visual/Audio Requirements: "Active-tab state reuses the existing filled-vs-outline actionable convention (never color-only)" |
| Connection Badge | Color-as-only-indicator | Distinct badge glyph shape, not a color-only dot — same principle as Defense Building's built/unbuilt structure distinction | Per GDD Visual/Audio Requirements, explicitly stated |
| All 6 `InputModeTracker` regions | Keyboard-only completion | Full traversal path: tab strip → (optional) diorama structure-selection ring → (optional) active room's own tracker, with `Down`/`Esc` as the named boundary-crossing inputs (Interaction Map) | No mouse-only step exists anywhere in this spec's own navigation — room-internal completeness is each room's own GDD's responsibility |
| All 6 `InputModeTracker` regions | Gamepad-only completion | Same traversal path via D-pad/Left Stick + face buttons + `LT`/`RT` | Confirmed distinct from `LB`/`RB` (in-room tabs) per Core Rule 2's explicit split |
| Resource header text | Text scaling | Follows the project's committed UI scale slider (75%–150%, Standard tier); at 150% scale the header must not exceed its 64px height budget in a way that clips text — widen the numeric display area or abbreviate large material counts (e.g. "99+") before allowing clipping | New commitment this spec adds — the GDD's Tuning Knobs table only states the header's *default* height, not its behavior under UI scale extremes; this spec closes that gap provisionally, matching `mission-hud.md`'s own "test all HUD zones at 75% and 150%" acceptance criterion precedent |
| Connection Badge count text | Text scaling | Numeric count (when present) follows the same UI scale slider; at 150% scale, if the badge count would overlap the tab icon's own glyph, cap displayed count at "9+" rather than allowing visual collision | New commitment, same rationale as above |
| Room-switch drawer-slide | Reduced motion | Instant swap (no slide) when reduced motion is enabled — see Transitions & Animations table | Matches project's committed "Motion / animation reduction mode" (Standard tier) |
| Connection Badge scale-pop | Reduced motion | Badge appears at final scale directly, no pop animation, when reduced motion is enabled | Same toggle |
| `DEPARTING` pull-back/settle beat | Reduced motion | Instant cut to the settled framing (no animated pull-back, no separate hold beat) — this spec's own provisional call, see Transitions & Animations note | Provisional — flagged for confirmation since the GDD itself doesn't specify this variant explicitly |
| Onboarding tooltip | Reading time | Not auto-dismissing on a timer — dismisses only on player input, satisfying the "no auto-dismissing dialog with actionable info under 5 seconds" Standard-tier rule trivially (there's no timer at all) | Per GDD Tuning Knobs: "Dismiss on any input, no auto-timeout" |
| "Staged changes discarded" toast | Reading time | Non-blocking, ~2s hold (matches Pattern 10 cadence) — informational only, no action required from the player, so the 5-second rule (reserved for actionable dialogs) doesn't apply, same reasoning `mission-hud.md`'s Phase Transition Banner already established for this project | Explicit per-instance justification, not a silent exception |
| Diorama structure click targets | Motor accessibility | Clickable structures/habitats sized generously enough for reliable mouse targeting at default UI scale (Fitts's Law — small, densely-packed hand-authored positions on a diorama risk being a click-precision trap); gamepad's nearest-neighbor D-pad traversal is the accessible alternative to precise mouse clicking | New commitment — flagged as a concern to validate once the diorama's actual structure density/spacing is known (structures are "fixed, hand-authored positions" per Core Rule 1, so this needs an art/layout pass to confirm, not just a UX rule) |
| Launch/Depart button | Motor accessibility, error prevention | Double-press within the same frame produces only one `DEPARTING` entry (Edge Cases) — protects against accidental double-activation ending the session unexpectedly | Already specified at GDD level; restated here as an accessibility commitment (irreversible-action protection), not just a technical race-condition fix |

---

## Localization Considerations

A 40% text expansion (typical for English → German/French) must not break any Sanctuary UI layout. Elements marked HIGH PRIORITY require explicit constraints in the localization pipeline.

| Element | Max English Length | Expansion Risk | Constraint |
|---|---|---|---|
| Tab label: "Overview" | 8 chars | Medium | Tab strip width (56–96px, Tuning Knobs) is icon-first, label-on-focus-only — label renders in a flyout/tooltip-style reveal, not fixed-width in the strip itself, so expansion risk is contained to that reveal's own width, not the persistent chrome |
| Tab label: "Inventory & Crafting" | 21 chars | **HIGH** | Longest label in the set — at 40% expansion could run ~29 chars. Since labels only render on focus/hover (not persistently), cap the focus-reveal tooltip width to fit up to 32 chars before wrapping to two lines |
| Tab label: "Menagerie" | 9 chars | Medium | Same reveal-on-focus treatment |
| Tab label: "Defense Building" | 17 chars | **HIGH** | ~24 chars at 40% expansion — same reveal-tooltip wrap rule as Inventory & Crafting |
| Tab label: "Equipment Forge" | 15 chars | Medium | Same reveal-on-focus treatment |
| Resource header labels ("Gold", material type names) | 4–10 chars | Medium | Icon-first design (per Pattern 5, Resource Counter) means the label is secondary to the icon — numeric value stays fixed-width regardless of label length, per that pattern's existing convention |
| Launch/Depart button label ("Launch Mission") | 15 chars | **HIGH** | At 40% expansion, ~21 chars. This is a single fully-chamfered primary button (art bible convention) with no stated width constraint yet — cap translated label at 20 chars or allow the button to grow up to 25% wider before wrapping to a second line (never truncate — this is the most consequential single action in the screen) |
| Onboarding tooltip line (trigger/bumper split, e.g. "Triggers switch rooms — bumpers switch tabs") | ~44 chars | **HIGH** | At 40% expansion, ~62 chars. Anchored to the tab strip (a narrow, tall region) — must wrap to 2–3 lines rather than requiring width the tab strip doesn't have. Cap at 3 lines, ~22 chars/line |
| "Staged changes discarded" toast | 25 chars | **HIGH** | At 40% expansion, ~35 chars. Matches `mission-hud.md`'s PC-3 "Path update queued" banner precedent (also a toast/banner in a constrained top-of-screen zone) — cap at 40 chars or wrap to two lines, same treatment |
| Inert structure tooltip (e.g. "Watchtower — no room") | Variable (structure-name-dependent) | Medium | Single-line tooltip; cap at 40 chars total or wrap, matching the toast's own budget above |
| Connection Badge count | Numeric only (or "9+") | None | Locale-agnostic — no translation required |

**HIGH PRIORITY for localization engineer**: "Inventory & Crafting" tab label, "Defense Building" tab label, Launch/Depart button label, onboarding tooltip line, "Staged changes discarded" toast. All five risk layout breakage at default UI scale — flag for string-length audit before each locale ships, matching `mission-hud.md`'s own established localization audit precedent.

---

## Acceptance Criteria

*(This section supplies the Visual/Feel evidence-tier criteria the GDD's own Acceptance Criteria explicitly deferred to this spec — see that GDD's "Not Independently Testable as GDD-Level Runtime Criteria" note. It does not duplicate the GDD's functional criteria, which remain that document's own.)*

- [ ] **Performance**: GIVEN the player switches rooms via tab, hotkey, or `LT`/`RT`, WHEN the drawer-slide transition plays, THEN the outgoing room's teardown and the incoming room's mount both complete within the 200ms in / 220ms eased-out settle budget (Tuning Knobs) with no dropped frames below 60 FPS during the transition — confirmed by frame-time capture during a `/team-ui` implementation pass, not just visual inspection.
- [ ] **Navigation**: GIVEN the player has never touched Sanctuary UI's diorama-selection focus ring this session, WHEN they navigate the tab strip to Equipment Forge (bottom entry) and press `Down`, THEN focus transfers to the nearest clickable structure on the diorama, confirmed by a visible focus ring on that structure and no focus ring remaining on the tab strip — validating the "dedicated input" this spec names concretely (Interaction Map).
- [ ] **Error/empty state**: GIVEN `OVERVIEW` is active and the player clicks a structure with no corresponding room (e.g. Watchtower) via mouse or confirms it via gamepad focus, WHEN the click/confirm registers, THEN an inert tooltip naming the structure appears, no room-mount is attempted, and the active state remains `OVERVIEW` — confirmed by screenshot showing both the tooltip and the unchanged tab-strip active-state.
- [ ] **Accessibility**: GIVEN reduced motion is enabled in accessibility settings, WHEN a room switch, Connection Badge arrival, and the `DEPARTING` beat each occur in the same test session, THEN all three play their reduced-motion variant from this spec's Transitions & Animations table (instant swap, no scale-pop, instant cut respectively) with zero sliding, scaling, or pull-back animation observed — confirmed by side-by-side screenshot comparison against the same three events with reduced motion disabled.
- [ ] **Core purpose**: GIVEN a player completes a mission that earned a new sanctuary structure and returns to `OVERVIEW`, WHEN they are shown the diorama before any input is required from them, THEN the new structure is already rendered at its fixed position (no pop-in delay, no separate "reveal" step) — validating that the "step back and look" beat (Player Fantasy) genuinely has something new to look at on arrival, not a stale diorama that updates only after an explicit refresh action.
- [ ] **Resolution/aspect-ratio** *(added 2026-07-24, `/ux-review`)*: GIVEN the game is run at the project's minimum and maximum supported PC resolutions/aspect ratios (per `technical-preferences.md`'s Target Platforms), WHEN Sanctuary UI is mounted in each, THEN the tab strip width, resource header height, and content-zone proportions hold with no clipping, overlap, or element loss at either extreme — confirmed by screenshot comparison across both configurations.

---

## Open Questions

Carried forward from the GDD (not resolved here, since resolving them is explicitly outside this UX spec's scope per the task's own instruction) plus 2 new ones this spec's authoring pass surfaced:

| # | Question | Owner | Source |
|---|---|---|---|
| OQ-5 (GDD) | Whether Menagerie/Defense Building/Equipment Forge's actual `.tscn` screens will dock cleanly inside `RoomHost` is unverified — only `InventoryScreen.tscn` exists today. This UX spec's Inventory+Crafting wireframe is accurate against real code; the other 3 rooms' wireframes could not be produced (they don't exist yet to wireframe) and are represented only at the GDD's structural level (full-frame, unmodified) in this spec's States/Interaction sections. | UI Programmer | `design/gdd/sanctuary-ui.md` |
| OQ-6 (GDD) | Connection Badge trigger events per room are a first-pass guess, not confirmed against each room's own owning designer. This spec's Localization and Data Requirements sections both reference these events as given but do not independently verify them. | Game Designer | `design/gdd/sanctuary-ui.md` |
| OQ-7 (new, this spec) | `[`/`]` and `LT`/`RT` cycling wrap-around behavior (now 6→1 and 1→6, updated from the pre-redesign 5-item count) is not stated in the GDD's States and Transitions table or Core Rule 2. This spec assumes wrapping (a common list-navigation convention, and the friendlier choice for a flat set) but this is a UX-specific call, not confirmed against the GDD. | UX Designer / Game Designer | This spec (Interaction Map) |
| OQ-8 (new, this spec) | The `DEPARTING` beat's reduced-motion variant is not explicitly specified in the GDD (unlike every other transition in `mission-hud.md`, which specs reduced-motion per-entry). This spec provisionally defines one (instant cut, no pull-back, no hold) following `mission-hud.md`'s own MISSION_COMPLETE/DEFEAT precedent, but it has not been confirmed against Visual/Audio Requirements sign-off. | UX Designer / Art Director | This spec (Transitions & Animations) |
| ~~OQ-9~~ | ~~Resolved 2026-07-24, same-day follow-up pass~~ — this spec has been fully updated for the 6-entry tab strip: both ASCII wireframes (`OVERVIEW`, the tab-strip-detail Connection Badge diagram, `ROOM_INVENTORY_CRAFTING`), Component Inventory, the full binding table, Focus Traversal Order, Entry & Exit Points, States & Variants (new `DEPARTING_TO_LOADOUT` row), and Events Fired now all reflect Loadout as the 6th tab entry. No open transcription work remains. | — | Resolved |

### New Interaction Patterns Introduced

Two candidates for promotion into `design/ux/interaction-patterns.md` once a second user exists (per that library's own "promote at second use" maintenance rule) — not added there yet, since Sanctuary UI is currently the sole user of both:

- **Connection Badge** — a live-updating, informational-only, non-dismissible badge overlay on a persistent navigation element, driven by EventBus counter increments and cleared on the target's own entry. Distinct from any existing catalogued pattern (closest neighbor is Resource Counter, pattern #5, but that pattern displays a player-owned resource value, not a cross-system "something changed elsewhere" signal).
- **Persistent Room Tab Strip** — a fixed, always-visible, vertical icon+label navigation rail with three parallel input paths (direct click/hotkey, cyclic prev/next, and gamepad-trigger cycling) all targeting the same flat sibling-state set. Distinct from the library's existing Gap-list "Tab navigation container" (which describes settings-style horizontal tab+page regions) — this is vertical, persistent across content swaps, and carries Connection Badges, none of which the existing gap entry anticipated.

---

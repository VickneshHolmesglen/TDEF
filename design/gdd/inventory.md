# Inventory System

> **Status**: Needs Revision (`/design-review` 2026-07-14 — 4 blockers found and fixed same-session: multi-unit stack-overflow algorithm, drop-resolution lock-precedence, 2 missing ACs, 4-slot discretionary floor. **`/design-review --depth lean` re-review 2026-07-17**: those 4 fixes confirmed intact. New blockers found and fixed this pass: 3 confirmed-missing cross-system APIs specified (`has_room_for()`, `clear_damaged_flag()`, `apply_rune_to_item()`), `has_items()` promoted from an unspecified placeholder to a fully specified method; stale "(no GDD yet)" labels updated for Crafting/Menagerie/Defense Building/Equipment Forge (all now authored); AC-14 unblocked; a self-contradiction resolved — the Interactions table said `tower_component_returned` was closed while the Open Questions table said it was still open, both now agree it's closed.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-17
> **Implements Pillar**: Everything Connects · The Sanctuary Is Your Statement

## Overview

The Inventory System is the storage ledger for every item and material the player
collects — equipment pieces, tower components, crafted goods, and raw materials —
represented as discrete stacks with per-stack quantity limits. Multiple separate
stacks of the same item are permitted once a stack is full, rather than one
unbounded pile per item type.

Player-facing, it surfaces through a dedicated two-panel Sanctuary screen: a
left-hand inventory grid (starting at 10 slots, expandable, organized into tabs)
paired directly against a right-hand Crafting panel — inventory and crafting are
presented as one continuous surface the moment the player opens it, not two
screens they navigate between separately.

Every other system that touches player possessions (Crafting, Tower component
selection, Equipment Forge, Menagerie) reads and writes through this single
ledger rather than inventing its own storage, so "what does the player own" has
exactly one authoritative answer anywhere in the game.

## Player Fantasy

You don't open the inventory to count what you have — you open it to see what you
could make. The left panel and the right panel sit side by side for exactly this
reason: a stack of frost-touched silk isn't just an item, it's a question the
Crafting panel is already answering before you've finished looking. This is where
"what happens when these two things interact?" gets asked most often, because
everything you've ever picked up is sitting in the same two panels, waiting to be
noticed together.

It's also the quietest kind of record. Ten slots that grew to thirty because you
needed them to. A stack of components you never used, still there, still yours.

**Honesty note, added during `/design-review`**: this GDD's own structural rules
are deliberately uniform — fixed tabs (Core Rule 3), a universal slot-expansion
cost table, fixed stack caps — so the variation described above is limited to
*contents*, not structure. Inventory does not itself generate the "nobody else's
inventory looks like this" trace Pillar 3 (`game-pillars.md`) asks for; it is the
shared ledger that makes Pillar 2's cross-system questions askable in the first
place ("what pairs with this?"). The Sanctuary-Is-Your-Statement payoff belongs
to the systems that write distinguishable, player-chosen content into these slots
(Crafting, Menagerie, Equipment Forge) — Inventory enables that payoff by being
the one place it's all visible together, rather than authoring the payoff itself.

## Detailed Design

### Core Rules

1. **Storage model**: The Inventory is a slot-based grid, starting at 10 slots.
   Every slot holds one stack of one item.
2. **Stack caps are type-driven, not universal**:
   - Equipment and stat-rolled Tower Components (unique instances with
     individual stats/affixes): stack cap = 1. Each slot holds exactly one
     instance.
   - Materials and generic Crafted Goods (no per-instance variance): stack
     cap = 99.
   - When a 99-cap stack fills, adding more of that item auto-creates a new
     stack in the next open slot — it does not block the pickup or force
     manual stack management.
   - **Multi-unit overflow algorithm** (added during `/design-review` —
     resolves a gap where only the trivial +1-at-full-stack case was
     specified): a pickup event of quantity `N` for an existing stackable
     `item_id` resolves as **fill-then-overflow**: (1) top off the target
     stack's existing partial quantity up to 99 first, consuming as much of
     `N` as fits; (2) if quantity remains after step 1, create new 99-cap
     stacks in successive open slots, each consuming up to 99 of the
     remainder, until either `N` is exhausted or no open slots remain; (3) if
     `N` is exhausted before all of it is placed (inventory ran out of open
     slots mid-overflow), the **portion actually placed** commits normally
     (`item_added` fires for that portion) and the **unplaced remainder**
     triggers `item_pickup_rejected` for that remainder's quantity — a single
     pickup event can therefore produce both an `item_added` and an
     `item_pickup_rejected` emission in the same frame if it partially fits.
     Example: slot N holds 97/99, incoming quantity 5, one other open slot
     exists: step 1 tops slot N to 99 (consumes 2, 3 remain); step 2 places 3
     in the new open slot as its own stack; `item_added` fires for the full 5.
     If instead zero open slots existed, step 1 still tops slot N to 99
     (`item_added` fires for 2), and `item_pickup_rejected` fires for the
     remaining 3.
3. **Tabs** are fixed, by item category: Equipment, Tower Components,
   Materials, Crafted Goods. Not player-customizable at MVP.
4. **Slot expansion**: craftable only (no gold cost, no Defense Building
   structure). 5 tiers, diminishing-returns curve: 18 → 24 → 30 → 36 → 42 → 48
   (max), each tier costing progressively rarer/more materials than the last.
   **Revised twice, 2026-08-16 (player-requested)**: originally 10 → 16 → 22 →
   28 → 34 → 40; re-based to 14 → 20 → 26 → 32 → 38 → 44 when Equipment Forge
   fixed Hero's equipment-slot count at 10 named slots (Rule 5a), then to the
   current sequence after a live playthrough found the resulting 4
   discretionary slots insufficient for a mission's material drops. Same
   +6-per-tier cadence and material costs both times — only the base shifted.
5. **Equipped-item lock**: any item currently equipped (Hero gear) or
   installed (Tower Component in active use) cannot be removed or discarded
   from inventory while in that state. Locked items still occupy and count
   against the current slot cap — they are not exempted from capacity.
5a. **Minimum discretionary-slot guarantee** (added during `/design-review` —
    resolves a gap where the `starting_slot_count` Tuning Knob's stated "safe
    range" floor of 6 was never checked against Rule 5's mandatory locked-slot
    occupancy): at `starting_slot_count`'s default tier, **at least 4 slots
    must remain free (unlocked, unoccupied) after every mandatory equip/install
    lock is accounted for.** This is a standing constraint on any future system
    that defines how many Hero gear slots or simultaneously-installed Tower
    Components exist (Hero System, Equipment Forge, Tower System) — not a
    number this GDD invents today. **Resolved 2026-08-16**: Equipment Forge
    (`equipment-forge.md` Rule 1) fixed Hero's mandatory-lock count at 10
    named equipment slots; Tower System's per-placed-tower-component lock
    count is still undefined and remains an open half of this rule. With the
    Hero half now numeric, `starting_slot_count` was raised to 18 (10 locked +
    8 discretionary), comfortably clearing the 4-slot floor — not just barely
    meeting it, after a live playthrough found the floor-exact 14 (10+4) too
    tight in practice (drops were being rejected constantly with no in-mission
    recovery path).
6. **UI presentation**: opening the Inventory screen shows two panels
   together — left is the inventory grid (tabbed), right is the Crafting
   panel. They are one continuous screen, not separate navigable views.

### States and Transitions

Inventory has **two operating states**, not a simple locked/unlocked toggle:

| State | Active During | UI Access | Writes / Events |
|---|---|---|---|
| `INVENTORY_ACTIVE` | SANCTUARY | Full two-panel screen accessible | Full — player-initiated adds/removes/equips |
| `INVENTORY_HEADLESS` | SCOUT, WAVE_ACTIVE, INTERMISSION | Screen inaccessible (Crafting/Menagerie/Defense Building are all LOCKED per `game-concept.md`'s own state table) | **Still fully active** — `item_added`/`item_removed` continue firing as materials are earned mid-wave (`materials_earned` → Resource Economy → Inventory) and as towers return components on destruction/removal. Mission HUD subscribes to these events for live counters even though the screen itself can't be opened. |

This corrects an initial assumption from context-gathering: Inventory is not
"locked" during missions in the sense of refusing writes — only the *screen*
is inaccessible. The underlying ledger keeps updating in real time; the player
just can't browse it until back in SANCTUARY.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **EventBus** | Inventory → | `item_added(item_id: String, item_type: String, quantity: int, metadata: Dictionary = {})`, `item_removed(item_id, item_type, quantity)`, `equipment_slot_changed(slot, new_item_id, previous_item_id)`, `item_pickup_rejected(item_id: String, item_type: String, quantity: int, reason: String)` (new — fires when a pickup can't be stored; see Edge Cases). The `metadata` field is a new, optional addition to `item_added`'s existing signature — carries fields like `damaged: bool` for tower components returned from a destroyed tower (see Tower System gap below). |
| **EventBus** | → Inventory | Subscribes to Resource Economy's `materials_earned`/`materials_spent` — Inventory is where the resulting material quantities are actually stored; Resource Economy only calculates the flow. |
| **Tower System** | → Inventory (resolved during `/design-review`, 2026-07-14) | `tower.md` now emits `tower_component_returned(tower_id, item_id, item_type, damaged)` once per component whenever a tower's components return to inventory (voluntary removal or destruction). Inventory subscribes to this event, adds the item to its ledger, and emits `item_added(item_id, item_type, quantity=1, metadata={"damaged": damaged})` itself — Inventory remains the sole emitter of `item_added` per ADR-0016; Tower never emits it directly. **`event-bus.md`'s catalogue confirmed to already carry `tower_component_returned`** *(corrected 2026-07-17 — this row and the Open Questions table below previously disagreed on whether this gap was closed; verified directly against `event-bus.md` and `tower.md`'s own Dependencies table, both of which already document this event. This row was accurate all along; the Open Questions entry below was the stale one.)* |
| **Save & Persistence** | Inventory implements `SaveRestorer` | `get_save_key()` / `get_save_data()` (primitives only, per ADR-0003) / `restore_save_data()` / `reset_to_defaults()`. **Restore ordering constraint**: Inventory's `restore_order` must be lower (restore earlier) than Hero's and Tower's, so equip-state validation always has fresh inventory data. If a save references an equipped `item_id` no longer present in restored inventory, that slot unequips to empty (`equipment_slot_changed` fires with `previous_item_id` set, `new_item_id` empty) rather than failing silently. |
| **Crafting** *(authored 2026-07-16)* | ← Inventory | Three query/mutation APIs, specified below in "Cross-System Query & Mutation APIs": `has_items()`, `has_room_for()`, `clear_damaged_flag()`. Subscribes to `item_added` for recipe-availability refresh (already locked in `event-bus.md`). *(Updated 2026-07-17 — `crafting.md` now exists; the APIs it depends on are specified below.)* |
| **Menagerie** *(authored 2026-07-16)* | ← Inventory | Consumes Materials-tab items (`menagerie_lure`) as a deterministic acquisition cost via `has_items()`/consume — no new API needed beyond what's specified below. *(Updated 2026-07-17 — menagerie.md now exists.)* |
| **Defense Building** *(authored 2026-07-16)* | ← Inventory | Consumes gold + material cost on tech-node unlock via `has_items()`/consume — no new API needed. *(Updated 2026-07-17 — defense-building.md now exists.)* |
| **Equipment Forge** *(authored 2026-07-17)* | ← Inventory | Reads Equipment + Materials tabs, writes new Equipment via `item_added`; in-place rune-imbuing uses the new `apply_rune_to_item()` mutation API, specified below. *(Updated 2026-07-17 — equipment-forge.md now exists and specifies exactly this need.)* |

#### Cross-System Query & Mutation APIs *(added 2026-07-17, closes confirmed-missing interfaces flagged by `crafting.md` and `equipment-forge.md`)*

Four methods make up Inventory's full query/mutation surface for downstream Sanctuary systems. All are synchronous direct Autoload calls (not EventBus events) — consistent with how Grid and Tower already expose read/query APIs elsewhere in this project.

| Method | Signature | Behavior | Used by |
|---|---|---|---|
| `has_items` | `has_items(cost: Dictionary) -> bool` | Returns `true` iff every `item_type` key in `cost` has a matching total quantity at least the required amount across all matching slots. Empty `cost` dict returns `true` trivially. Does not mutate state — a pure availability check. **Promoted from an "(anticipated)" placeholder to a fully specified method on 2026-07-17** — previously appeared only once in this doc with no edge-case coverage despite being load-bearing for `crafting.md`'s entire discovery/craftability mechanism. | Crafting (Rules 3/4/8), Menagerie (Lure acquisition), Defense Building (tech-node unlock) |
| `has_room_for` | `has_room_for(item_type: String, quantity: int) -> bool` | Returns `true` iff adding `quantity` units of `item_type` would not exceed the tier-capacity floor (Rule 5a) — a pre-check runnable before a craft/acquire action consumes its cost, so a failed room check never leaves materials spent with nothing received. **New method, added 2026-07-17** — confirmed absent prior to this pass; required by `crafting.md` Rule 7/AC-4. | Crafting (pre-craft capacity check) |
| `clear_damaged_flag` | `clear_damaged_flag(item_id: String) -> bool` | Mutates the target item's `damaged` metadata true to false in place (same slot, same `item_id` — no remove/re-add). Returns `false` if `item_id` doesn't exist or isn't currently damaged. Inventory calls this **internally** on receipt of Crafting's `component_repaired(item_id: String, component_type: String)` event — matching `crafting.md` Rule 6's own design (`component_repaired` is Crafting-owned; Inventory is a subscriber, alongside Mission HUD and Audio, not the emitter). This method itself does not emit anything — the notification other systems react to is `component_repaired`, already emitted by Crafting before Inventory's subscriber runs. **New method, added 2026-07-17** — confirmed absent; required by `crafting.md` Rule 6 (repair, closes `tower.md` OQ-12). `event-bus.md`'s catalogue needs `component_repaired` added (Crafting-owned) — not done as part of this pass. | Crafting (Rule 6, repair) |
| `apply_rune_to_item` | `apply_rune_to_item(item_id: String, rune_id: String, stat_delta: Dictionary) -> bool` | Mutates the target Equipment item's stat block in place per `stat_delta`, tagging it with `rune_id`. Same slot and `item_id` preserved — in-place, not remove/add. Returns `false` if `item_id` doesn't exist or isn't an Equipment-tab item. **New method, added 2026-07-17** — confirmed absent; required by `equipment-forge.md` Rule 16/19. **Rule 5 (equip-lock) compatibility**: this is a metadata mutation, not removal/discard, so it is very likely already permitted under Rule 5's existing scope (cannot be removed or discarded while equipped) without an amendment — `equipment-forge.md` calls this its top fragility risk and requests a Rule 5 scope change; recommend confirming compatibility first, since the amendment may not actually be necessary. | Equipment Forge (Rule 16/19) |

## Formulas

**Correction (2026-07-10, found by qa-lead during Acceptance Criteria review)**:
an earlier draft of this section claimed `common_qty(tier) = round(10 ×
1.35^(tier - 1))` generates the table below. It does not — that formula
produces 10/14/18/25/33, not the table's 10/18/28/36/45 (ratios between
consecutive tiers are 1.8, 1.56, 1.29, 1.25 — not a constant exponent, so no
clean geometric formula reproduces these values). **The table below is the
sole authoritative source** for slot expansion cost — all three material
tiers (Common, Uncommon, Rare) are hand-tuned per tier, not formula-derived.
This is a Logic-story value, so the contradiction would have blocked
automated test creation had it shipped uncaught.

The **slot expansion cost** table, keyed by tier index (`tier: int`, range
1–5, where 1 = 10→16 slots and 5 = 34→40 slots):

| Tier | Slots | Common Qty | Uncommon Qty | Rare Qty | Material Types Required |
|------|-------|-----------|---------------|----------|--------------------------|
| 1 | 10→16 | 10 | — | — | 1 |
| 2 | 16→22 | 18 | 4 | — | 2 |
| 3 | 22→28 | 28 | 10 | — | 2 |
| 4 | 28→34 | 36 | 18 | 5 | 3 |
| 5 | 34→40 | 45 | 28 | 12 | 3 |

**Rarity gating rule**: a new material rarity tier is introduced exactly once
as a step change (Uncommon at Tier 2, Rare at Tier 4), not gradually — each
expansion that crosses a rarity threshold should feel like a discrete "this
now requires something I have to hunt for," not a smooth cost creep.

**Output range**: common-material cost grows from 10 to 45 across 5 tiers
(4.5× total, per-tier ratios of 1.8/1.56/1.29/1.25 — front-loaded, not a
constant rate) — deliberately modest in the back half, so raw quantity
grinding never becomes the dominant late-game difficulty. The real difficulty
curve is material *diversity*: going from 1 → 2 → 3 required rarity tiers
forces the player into rare-drop/crafting loops by the late game.

**Example**: Tier 3 (22→28 slots) costs 28 Common + 10 Uncommon material — no
Rare material required yet.

*Note: "Common/Uncommon/Rare material" are placeholder rarity-tier names, not
final item names. `monster.md` confirms no material-rarity vocabulary exists
yet anywhere in the project (STANDARD/ELITE/BOSS is a monster-difficulty tier,
not a material-rarity tier — checked, not reusable here). Crafting's GDD (not
yet designed) will assign real material names within these rarity tiers.*

## Edge Cases

- **If a mid-mission pickup arrives while the inventory is completely full**
  (all slots occupied, no stack has room) during `INVENTORY_HEADLESS`: the
  write is rejected — `item_added` does NOT fire. Instead, a new signal
  `item_pickup_rejected(item_id: String, item_type: String, quantity: int,
  reason: String)` fires so Mission HUD can surface a toast/notification
  without needing the full inventory screen. Rejected pickups are **not**
  queued or retried — Crafting/loot-tracking systems must not assume eventual
  delivery of a rejected pickup. *(New EventBus signal — added to the
  Interactions table below and flagged as an `event-bus.md` catalogue
  follow-up, same category as the Tower System gap.)*
- **If the player is at max slot tier (40/40) and attempts another
  expansion**: the action is blocked at the eligibility check (no Tier 6
  exists) — materials are not spent, no event fires. This is a
  UI-disableable state, not a runtime failure.
- **If a pickup would require a 41st slot while already at max tier**: this
  collapses into the full-inventory rejection rule above — tier only affects
  slot count, not the reject behavior itself.
- **If Crafting consumes a partial quantity from a 99-stack** (e.g. 40 of
  99): the remainder stays in the same slot index. Consumption only mutates
  the stack's `quantity` and emits `item_removed` — it never triggers a
  slot-compaction pass. This must be explicit, or save/load and drag-drop UI
  will disagree on slot stability.
- **If two independently stat-rolled copies of the same Equipment/Tower
  Component definition exist**: they occupy two separate slots, each
  individually cap=1. This is not a stacking violation — stacking never
  applies to stat-rolled items at all. Cap=1 is enforced at instance-ID
  granularity, so duplicate rolls of an identical item definition never
  merge, even with identical rolled stats.
- **If a system reads "number of stacks" rather than "quantity held"**: this
  is forbidden — no mechanic may key off stack count (only total quantity
  per item_id), since stack-splitting is an automatic overflow behavior, not
  a player-meaningful action, and keying logic off it would create an
  exploitable stack-splitting incentive.
- **If a player accumulates enough of one material to consume many slots via
  auto-created overflow stacks**: the UI must show a proactive capacity
  warning before the inventory is fully blocked, not just a hard stop at
  100% full — silently soft-locking pickups (see the first edge case) with
  no forewarning is a real player-frustration risk.

## Dependencies

| System | Direction | Nature | Interface |
|---|---|---|---|
| **EventBus** | Depends on | Hard | All cross-system communication (see Interactions table above) |
| **Save & Persistence** | Depends on | Hard | `SaveRestorer` interface; `restore_order` in the Core band (10-49), earlier than Hero and Tower |
| **Crafting** *(no GDD yet)* | Depended on by | Hard (anticipated) | Query/consume API; subscribes to `item_added` |
| **Menagerie** *(no GDD yet)* | Depended on by | Hard (anticipated) | Query/consume API on Materials tab |
| **Defense Building** *(no GDD yet)* | Depended on by | Hard (anticipated) | Consumes Tower Components tab; reuses equipped-lock rule |
| **Equipment Forge** *(no GDD yet)* | Depended on by | Hard (anticipated) | Reads Equipment/Materials tabs, writes via `item_added` |
| **Tower System** *(designed & implemented)* | Depended on by | Hard | Emits `tower_component_returned(tower_id, item_id, item_type, damaged)` on component return (resolved 2026-07-14 during `/design-review`); Inventory subscribes and emits `item_added(metadata={"damaged": damaged})` on Tower's behalf — Inventory remains the sole `item_added` emitter |
| **Mission HUD** *(Designed 2026-07-14, pending `/design-review`)* | Depended on by | Soft | Subscribes to `item_added`/`item_removed`/`item_pickup_rejected` for live counters/toasts during `INVENTORY_HEADLESS` — confirmed in `design/gdd/mission-hud.md`'s Dependencies table |

## Tuning Knobs

| Knob | Default | Safe Range | Affects |
|---|---|---|---|
| `starting_slot_count` | 18 | 18–24 (Rule 5a's Hero half is now fixed at 10 locked slots; floor is 14 to guarantee ≥4 free discretionary slots, but 14-exact proved too tight in a live playthrough — see Rule 5a's 2026-08-16 note. Tower System's install-lock count is still undefined, so the upper bound remains soft) | Early-game inventory pressure. Too low frustrates before Crafting is unlocked; too high removes the early "what do I keep" tension |
| `stack_cap_stackable` | 99 | 20–999 | How often Materials/generic Crafted Goods overflow into new stacks. Lower values increase overflow-stack slot pressure |
| `stack_cap_unique` | 1 | Fixed — do not tune | Equipment/Tower Components never stack; this isn't a balance lever |
| `max_slot_tier_count` | 5 | 3–7 | Total expansion depth. More tiers = longer-tail slot progression; fewer = players hit the cap earlier and the Formulas curve compresses |
| `slot_expansion_cost_table` | see Formulas table | Hand-tuned per tier — not a single scalar | The entire 5-tier cost table (Common/Uncommon/Rare quantities) is the tunable artifact, not one exponent parameter — corrected 2026-07-10, see Formulas section's authoritative-source note. Adjust individual cells directly for balance passes. |
| `rare_material_gate_tier` | 4 | 3–5 | Which tier first requires Rare material. Earlier = Rare-material crafting/farming loops matter sooner in the game |

## Visual/Audio Requirements

**Event feedback:**
- **Item pickup**: destination slot icon does a quick scale-pop (1.0→1.15→1.0,
  ~0.2s) with a soft Parchment Cream sparkle burst. No new color introduced —
  this is a routine event, not an exceptional one (art bible Sec 4.2). Must
  render identically whether the screen is open or fired as a Mission HUD
  toast during `INVENTORY_HEADLESS`.
- **Stack overflow (new stack created)**: same pickup pop on the new slot,
  plus a brief Parchment Cream border pulse (fade over ~0.4s) distinguishing
  "new stack" from "quantity increased" on an existing slot. Herald Gold and
  UI Accent Cyan are reserved (gold = exceptional-only, cyan =
  interactive-only, per Sec 4.4) — neither applies here.
- **Slot expansion completing**: the grid visually grows — new slots reveal
  via the chamfered-rectangle frame (Sec 3.3) fading in left-to-right, each
  flashing Herald Gold once. This is the one inventory event that earns gold:
  it's a genuine milestone (Sec 4.1, "achievement feedback").
- **Item rejected (full inventory)**: toast uses UI Warning Orange
  (`#F5921A`), paired with a non-color cue — icon shake/bounce-back — per
  colorblind-safety discipline (Sec 4.5, disabled/warning pairs always need
  a non-color backup).
- **Equip/unequip**: synced scale-pop on both source and destination icons.
  Locked (equipped/installed) slots get a lock-icon overlay at the mandatory
  24×24 icon minimum (Sec 3.3) — never a color-only lock indicator, matching
  the Disabled-state rule (Sec 4.5, Pair 3).

**Animation/style constraints:**
- No world-space shadows on any inventory panel; drop shadows vertical-offset
  only (Sec 3.3 UI rule).
- All icons: chamfered-rectangle frame, 2px inset border, legible at 24×24
  minimum.
- Motion stays restrained/peripheral for HEADLESS-state toasts — must not
  compete with the WAVE_ACTIVE center-third rule (Sec 3.3).

**Principles most directly invoked**: Sec 4.2 (Semantic Color Vocabulary),
Sec 4.4 (UI-only colors), Sec 3.3 (UI Shape Grammar), Sec 4.5 (Colorblind
Safety, Pairs 2 & 3).

## UI Requirements

**Core interaction flow**
- Opening the screen loads both panels simultaneously (per AC-13) with input
  focus defaulting to the first occupied slot in the active tab (or the tab
  bar if empty).
- Selecting a slot is a single click/press — no double-click-to-inspect.
  Selection shows a tooltip (name, stats, quantity) without blocking further
  input.
- Moving items uses click-drag-drop for mouse. Drop resolution is checked in
  this precedence order (added during `/design-review` — resolves an
  unspecified ordering gap): **(1) is the target slot locked (Rule 5)? If so,
  reject with a shake — no merge or swap is attempted, regardless of
  `item_id` match.** Only if the target slot is unlocked: **(2)** same
  stackable `item_id` → merge up to cap (overflow follows the Rule 2
  multi-unit algorithm if the merge would exceed 99); **(3)** different item
  → swap positions. The lock check always gates first — a locked slot can
  never be entered as a merge target even if it happens to hold the same
  `item_id`.
- Equipping is a secondary action from the tooltip/context menu (e.g., a
  dedicated "Equip" button), **not** drag-onto-hero — dragging stays
  inventory-internal only, avoiding an ambiguous "did I equip or reorder?"
  moment, and drag-to-target doesn't translate cleanly to gamepad.
- Tab switching preserves selection/tooltip state; the Crafting panel's
  context updates live as inventory selection changes (feeds the Player
  Fantasy's "what could I make" moment).

**Gamepad navigation** *(required — this project mandates full K/M + gamepad
parity per `.claude/docs/technical-preferences.md`)*
- D-pad/left-stick moves selection via 2D spatial adjacency (row/column),
  wrapping at grid edges to switch tabs rather than silently stopping.
- Shoulder buttons (LB/RB) cycle tabs directly regardless of grid position.
- Single confirm button opens the context menu (Equip/Discard/Move-to-Crafting);
  no drag equivalent — "pick up (confirm) → move → confirm again" substitutes
  for drag.
- Focus always renders a visible, non-color-dependent highlight (outline +
  slight scale), distinct from hover.
- Keyboard-only input mirrors the same grid-adjacency model (Tab/Shift+Tab
  or arrow keys) — same interactions, same mapping shape as gamepad.

**Accessibility considerations**
- Locked-slot indicator: 24×24 minimum, colorblind-safe icon overlay
  (already specified in Visual/Audio Requirements).
- Full-inventory/capacity-warning states never rely on color alone (Warning
  Orange + shake, already spec'd).

## Acceptance Criteria

*Validated by qa-lead — verdict GAPS at first pass (one BLOCKED criterion,
AC-9, due to the formula/table contradiction found and fixed above; one
correctly DEFERRED, AC-14, pending Crafting's own GDD). Both resolved/expected
as of this write.*

- **AC-1**: GIVEN a freshly initialized Inventory with no save data, WHEN it
  starts up, THEN it exposes exactly 10 slots, all empty.
- **AC-2**: GIVEN any occupied slot, WHEN its contents are queried, THEN it
  holds exactly one stack of exactly one `item_id`.
- **AC-3**: GIVEN an empty slot, WHEN a stat-rolled Equipment/Tower Component
  instance is added, THEN the resulting stack has quantity 1 and cap 1.
- **AC-4**: GIVEN a Material/generic Crafted Good stack at quantity 99 in
  slot N, WHEN one more unit is added, THEN the pickup is not blocked, a new
  stack of quantity 1 is created in the next open slot, and slot N remains
  at 99.
- **AC-5**: GIVEN the Inventory screen is open, WHEN the tab bar renders,
  THEN exactly 4 tabs appear in fixed order: Equipment, Tower Components,
  Materials, Crafted Goods. *(UI — advisory, screenshot evidence)*
- **AC-6**: GIVEN the tab bar, WHEN drag-reorder/add-tab/rename is
  attempted, THEN no such interaction is available. *(UI — advisory)*
- **AC-7**: GIVEN an item with a given `item_type`, WHEN `item_added` fires,
  THEN it files under exactly one tab per the fixed mapping.
- **AC-8**: GIVEN the current slot tier, WHEN each expansion completes, THEN
  capacity increases exactly as 10→16→22→28→34→40 (max); no Tier 6 exists.
- **AC-9**: GIVEN tier index 1–5, WHEN the material cost is checked, THEN it
  matches the Formulas table exactly: 10/18/28/36/45 Common;
  —/4/10/18/28 Uncommon; —/—/—/5/12 Rare.
- **AC-10**: GIVEN Tier 4 (28→34), WHEN the material requirement is checked,
  THEN it requires all 3 rarity tiers, Rare appearing for the first time.
- **AC-11**: GIVEN an equipped/installed item, WHEN a remove/discard is
  attempted, THEN it's rejected and the item stays unchanged.
- **AC-12**: GIVEN an equipped/installed item occupying a slot, WHEN the
  full-capacity check runs, THEN that slot counts toward the cap.
- **AC-13**: GIVEN the player opens Inventory, WHEN it renders, THEN the
  grid (left) and the right-hand panel are simultaneously visible with no
  extra navigation. *(UI — advisory, screenshot)*
- **AC-14 [READY — re-evaluated 2026-07-17]**: GIVEN the two-panel screen, WHEN the right panel's
  content is checked, THEN it's the functional Crafting panel. *(Previously DEFERRED pending
  `crafting.md`'s authoring — that condition is now met, `crafting.md` exists as of 2026-07-16.
  No longer blocked; testable once the Crafting panel UI is implemented.)*
- **AC-15**: GIVEN `INVENTORY_HEADLESS`, inventory full, WHEN a pickup
  arrives, THEN `item_added` does NOT fire, `item_pickup_rejected` fires
  instead, no retry occurs.
- **AC-19** *(added during `/design-review` — closes a gap where only the
  full-inventory rejection path, AC-15, had coverage, not the states table's
  own headline claim)*: GIVEN `INVENTORY_HEADLESS` with at least one open
  slot or non-full stack available, WHEN `materials_earned` triggers a
  pickup mid-mission, THEN `item_added` fires normally and the ledger
  updates correctly — proving writes continue during `INVENTORY_HEADLESS`
  independent of whether the screen is open.
- **AC-20** *(added during `/design-review` — the Dependencies table's
  Save & Persistence restore-ordering note describes this behavior but no
  AC tested it)*: GIVEN a restored save references an equipped `item_id` no
  longer present in the restored inventory data, WHEN `restore_save_data()`
  completes, THEN that slot unequips to empty and `equipment_slot_changed`
  fires with `previous_item_id` set to the missing id and `new_item_id`
  empty.
- **AC-16**: GIVEN slot tier at max (40/40), WHEN another expansion is
  attempted, THEN it's blocked at the eligibility check, no materials
  deducted, no event fires.
- **AC-17**: GIVEN a 99-quantity Material stack at slot N, WHEN 40 units are
  consumed, THEN slot N holds 59 at the same index, `item_removed` fires
  with quantity 40, no compaction occurs.
- **AC-18**: GIVEN two independently stat-rolled instances of the same item
  definition, WHEN both are added, THEN they occupy two distinct slots and
  never merge.

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| Should gold interact with Inventory at all (e.g., an optional gold cost on top of materials for slot expansion)? | Resource Economy GDD author (S5-04, next sprint) | Deliberately deferred — Inventory v1 is materials-only by design decision, so this GDD has no hard dependency on Resource Economy's signal contract. Revisit once Resource Economy exists. |
| ~~`tower.md` claims destroyed components "return to inventory" but emits no event for it~~ **RESOLVED** | Tower System owner / technical-director | **Corrected 2026-07-17** — this row was itself stale, contradicting the Interactions table above (which already correctly stated the gap was resolved 2026-07-14). Verified directly: `tower.md` now emits `tower_component_returned(tower_id, item_id, item_type, damaged)` (Rule 13/24), Inventory subscribes and emits `item_added` on Tower's behalf, and `event-bus.md`'s catalogue already carries the event. No further action needed on either doc's side. |
| ~~`item_pickup_rejected` is a new signal introduced by this GDD — not yet in `event-bus.md`'s catalogue~~ **RESOLVED** — stale as of `/design-review` (2026-07-14): `event-bus.md` was updated 2026-07-13 (after this GDD's 2026-07-10 authoring date) and already catalogues both `item_pickup_rejected` and `item_added`'s `metadata` field. No further action needed on the docs side; `event_bus.gd` code addition still pending implementation. | — | Closed. |
| Is 40 slots (Tier 5 max) actually enough for the full game, or does Alpha/Full-Vision content (post-MVP systems: Menagerie, Defense Building, Equipment Forge) demand more headroom? | game-designer | Flagged, not answered — this GDD only covers Vertical-Slice-tier scope; a future revision may need to extend the tier table once those systems exist and their material/item volume is known. |
| What does the Crafting panel actually contain, and does its presence change any Inventory-side interaction assumptions (e.g., does selecting a recipe filter/highlight relevant inventory slots)? | game-designer | **Partially resolved 2026-07-17** — `crafting.md` now exists (Rules 1-9, UI Requirements section). AC-14 moved from DEFERRED to READY (see Acceptance Criteria). Remaining: a dedicated UX pass to confirm whether recipe selection should filter/highlight Inventory slots is still open. |

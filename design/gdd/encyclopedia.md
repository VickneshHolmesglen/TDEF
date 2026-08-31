# Encyclopedia System

> **Status**: Approved (2026-07-24 — full `/design-review` [game-designer, systems-designer, qa-lead, ux-designer, creative-director] found NEEDS REVISION on first pass: a real data-model self-contradiction [an AC required storing a field Core Rule 2 said entries never have], an unfalsifiable Player Fantasy [no query contract existed for any consumer to read the ledger], a mis-scoped AC testing another system's behavior, an unearned "NEW flair" claim, and a design tension over creature-discovery granularity. Fixed same-session: added a minimal read-only query contract, corrected the data-model contradiction, split the mis-scoped AC, added a "Data Requirements for a Future UI" note without designing a screen, and adjudicated the granularity tension [species-level confirmed correct]. Independently re-verified same-day by a fresh-context pass, which confirmed all 5 problems structurally closed, explicitly endorsed the deliberate UI-deferral decision as sound engineering discipline rather than under-design, and elevated one Open Question's priority. See `design/gdd/reviews/encyclopedia-review-log.md` for full detail.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-24
> **Implements Pillar**: The Sanctuary Is Your Statement (primary); Everything Connects (secondary — witnesses cross-system connection, never creates it); explicitly does not serve Mastery-as-Vindication

## Overview

The Encyclopedia System is the game's passive, cross-cutting discovery log — a permanent, read-only ledger that converts already-fired discovery events from nearly every other system (Constellation, Tarot, Crafting, Equipment Forge, Menagerie, Defense Building, Tower Mastery/Hero Skill Build) into named, categorized entries the player can never lose. It owns no gameplay logic and gates nothing; it only receives, records, and (via one frozen event) notifies. It is the last system to restore on load (`restore_order = 35` in `save-persistence.md`) precisely because its data references every other system's own discoveries — it has nothing to reconstruct that isn't already implied by everything restored before it. Without this system, every other system's own discovery moment (a rune reveal, a card flip, a bred creature) remains a one-time flourish with no permanent record afterward — the player's accumulated progress across a playthrough has no single place it adds up.

## Player Fantasy

**The Game's Memory of You**

> The Encyclopedia is the game's memory of you — the permanent, after-the-fact record that gathers a playthrough's scattered discoveries into a portrait of the specific player you turned out to be.

The Encyclopedia never gets the moment of revelation, because that moment already belongs to the system that earned it — the medallion carves itself in the Constellation, the card turns in the Tarot, and only afterward does a quiet line arrive here to be filed away forever. Chasing that spotlight is the one thing this system must not do; it would only dilute a moment that already landed elsewhere. What it offers instead is slower and, in its own way, more lasting: the afterglow of proof. It is the ledger where every discovery, once its spotlight has faded, comes to rest under its own name — so that far downstream a player can turn back through the pages and read not a score, but the exact route they took through a game no one else played quite the same way.

This is decisively a **Pillar 3** system: where the sanctuary itself is the player's statement made visible and spatial, the Encyclopedia is that same statement made enumerated and permanent — the sanctuary's textual twin. It brushes Pillar 2 (it aggregates what every connected system produced) but only *witnesses* connection, it never creates one, so Pillar 2 is context here, not claim. It does not serve Pillar 1 at all, and should not be designed as if it does — no vindication moment belongs to this system; every vindication it touches already happened somewhere else.

**A deliberate scope boundary, stated here because it shapes everything below**: this system is pure testimony, not a spendable resource. `tarot.md`'s own Open Questions flag a candidate idea — Encyclopedia as a *purchase* mechanism for unlocking Tarot cards — but a codex that spends its own entries to buy things stops being pure record-keeping and starts being a currency, which would reintroduce a forward-facing "moment" this system's whole register is built to avoid. Core Rule 5 below declines that candidate explicitly, rather than silently absorbing it.

## Detailed Design

### Core Rules

**Core Rule 1 — Six Categories, Each Mapped 1:1 to an Already-Frozen Discovery Event**
No new EventBus event is invented to feed this system — every inbound event already exists, frozen, in `event-bus.md`, each already explicitly naming Encyclopedia as a Key Subscriber:

| Category | Source event(s) | `entry_id` source |
|---|---|---|
| `skill` | `skill_unlocked(skill_id, source_tower_id)` | `skill_id` |
| `constellation_rune` | `constellation_rune_discovered(rune_id, pattern_id)` | `rune_id` |
| `tarot_rune` | `tarot_rune_discovered(rune_id, card_id)` | `rune_id` |
| `recipe` | `recipe_discovered(recipe_id, recipe_category)` | `recipe_id` |
| `creature` | `creature_acquired(creature_id, species)`, `creature_bred(offspring_id, species)` | `species` (species-level discovery — see Rule 8) |
| `tech` | `tech_unlocked(tech_id, tech_category)` | `tech_id` |

`constellation_rune` and `tarot_rune` are kept as two distinct categories rather than merged into one "gear/rune" bucket — they come from unrelated systems with unrelated unlock conditions, and merging them would force a UI browsing the Encyclopedia to re-derive which discipline a rune belongs to from its `entry_id` alone. `tech` is kept distinct from `recipe` rather than folded together — a tech node can unlock things Crafting doesn't cover (e.g. `sanctuary_structure_built` eligibility), so treating a tech unlock as merely "a recipe became available" would lose information a Defense Building tech-tree browsing view needs.

**Core Rule 2 — Entry Data Model: The Discovery Fact Only, Never Display Content**
An entry is exactly: `{category: String, entry_id: String, discovered_at: int}` — no more, no fewer fields, for any category, without exception. `discovered_at` is a Unix timestamp (informational only, for sort order; never gameplay-relevant). **Display metadata (name, icon, description) is deliberately not stored here.** Encyclopedia stores only the discovery fact; any future browsing UI resolves display content by looking up `entry_id` against the *owning* system's own already-authored data at render time. This avoids Encyclopedia becoming a second, drifting copy of content every other system already owns and authors — the same lean-ledger discipline `crafting.md`'s own Discovery Ledger already established.

**`recipe_category` is resolved by lookup, never stored** (fixes a real self-contradiction an earlier draft of this document had — AC-4 previously claimed `recipe_category` was "preserved on the entry," directly violating this rule's own "exactly 3 fields" claim in the same document). A `recipe` entry's `entry_id` (the `recipe_id`) is sufficient to look up its `recipe_category` from Crafting's/Equipment Forge's own already-authored recipe data at render time, the same way name/icon/description are resolved — `recipe_category` is display/routing metadata, not a 4th ledger field.

**A "seen/unread" distinction is explicitly NOT supported by this data model, and no claim to the contrary should be read into it.** `discovered_at` supports sorting by recency, but nothing here tracks whether a player has actually viewed a given entry — a "NEW since your last visit" affordance would need a last-viewed reference point this model does not provide. This is a real, known gap in what a future browsing UI could support without a Core Rule revision, not an oversight to quietly work around — see the "Data Requirements for a Future UI" note under UI Requirements.

**Collision safety, stated explicitly rather than left implicit**: entries are keyed by the `(category, entry_id)` composite, never by `entry_id` alone — so a `constellation_rune`'s `rune_id` and a `tarot_rune`'s `rune_id` can never collide even if the two systems happened to reuse the same string, since they land in different category buckets. This is a structural guarantee of Core Rule 1's category split, not a coincidence.

**Minimal query contract (added — closes a real gap the design review found: without this, the Player Fantasy's "turn back through the pages" claim was unfalsifiable, since nothing in this document specified how any consumer, including a future UI, actually reads the ledger)**: Encyclopedia exposes exactly two read methods, `get_entries(category: String = "") -> Array` (all entries, or filtered to one category if provided) and `is_discovered(category: String, entry_id: String) -> bool`. Both are pure reads against the in-memory ledger populated by Core Rules 3–4 and restored by Save & Persistence — no write path exists on this interface, matching the whole system's read-only design. This is the contract AC-14 tests against, and the contract any future browsing UI (Open Question OQ-5) will build on, independent of when that UI is actually designed.

**Core Rule 3 — One-Way Discovery Ledger (Matches the Project's Established Precedent Exactly)**
Identical in kind to Constellation's, Crafting's, and Tarot's own Discovery Ledgers: `HIDDEN` (implicit — absence from the ledger; not itself a stored state) → `DISCOVERED` (terminal, permanent, save-persisted, never reverts). An entry's presence in the ledger *is* its `DISCOVERED` state — there is no separate boolean flag to desync from ledger membership.

**Core Rule 4 — `encyclopedia_entry_added` Fires Exactly Once Per Entry, Ever**
On a genuinely new `category`+`entry_id` combination transitioning to `DISCOVERED`, Encyclopedia emits `encyclopedia_entry_added(category: String, entry_id: String)` (the one frozen outbound event this system owns, per `event-bus.md`, consumed by Mission HUD for its own discovery notification). If the same `category`+`entry_id` is already `DISCOVERED`, the inbound event is a no-op (Core Rule 6/Edge Cases) and this event does not re-fire — Mission HUD must never show a duplicate "you discovered X" toast for something already discovered.

**Core Rule 5 — Explicitly Declines the "Encyclopedia as Purchase Mechanism" Candidate (Resolves `tarot.md`'s Open Question)**
`tarot.md` names Encyclopedia as one candidate source for "how a Tarot card becomes unlocked," alongside Defense Building's tech tree. This document explicitly declines that role. **The load-bearing reason is architectural, not philosophical**: giving Encyclopedia purchase authority over the same `unlocked: bool` flag Tarot reads would create a second, uncoordinated writer alongside Defense Building's tech tree for the same field — a duplicate-authority risk, independent of any argument about tone. (A weaker, secondary observation — that spending discovered entries as a currency would sit oddly against this system's archival Player Fantasy — is real precedent exists elsewhere for "spend your codex" mechanics that don't undermine an archival feel, e.g. journal/notebook systems in other completionist games, so this is not treated as the deciding factor, only a supporting one.) `tarot.md`'s open question is resolved here as: **Defense Building's tech tree (`tech_unlocked`) remains the sole source**, not "unresolved, two candidates." If a genuine Encyclopedia-driven unlock/purchase mechanic is ever wanted, it needs its own dedicated Core Rule addition in a future revision, built around a real designed write-authority boundary — it is not an implicit reading of "this system logs discoveries."

**Core Rule 6 — Bestiary/Monster Codex: Explicitly Deferred, Not Implemented**
`monster.md` names "any future monster codex or inspection panel" as this system's feature. This GDD does not implement it: no frozen one-shot event exists anywhere that signals "first encounter of this monster species" — `monster_spawned`/`monster_died` are repeat-firing combat events, not discovery events, and converting them into a one-shot bestiary entry would require `monster.md` itself to originate a new event first (the same "new event this GDD originates" pattern Menagerie used for `creature_acquired`). Flagged as Open Question OQ-1, not silently invented here.

**Core Rule 7 — Completion Percentage: Explicitly Out of Scope**
`mission-select.md` refers in passing to "a future Encyclopedia/completionist system." This document does not implement a completion-percentage formula (per-category or overall) because no GDD anywhere authors a stable, frozen `total_known_count` per category — computing a percentage against an unauthored, unstable denominator would silently break every time new content ships. Deferred until a content-catalogue GDD or registry entry freezes those totals (Open Question OQ-2).

**Core Rule 8 — Creature Discovery Is Species-Level, Not Instance-Level**
Menagerie's `creature_acquired`/`creature_bred` payloads carry both a per-instance ID (`creature_id`/`offspring_id`) and `species`. This document tracks discovery at **species-level** — the first individual of a species logs the `creature` entry; every subsequent individual of the same species (bred or acquired) is a no-op against an already-`DISCOVERED` entry. This matches the fixed-catalogue-of-IDs pattern every other category in this document already follows, and `menagerie.md`'s own text already consistently describes `creature_acquired`/`creature_bred` as feeding "species-discovery entries" in three separate places — so this is not an unconfirmed guess about Menagerie's intent, the two documents already agree.

**A real design tension was raised and adjudicated during review, not silently resolved**: does species-level tracking undercut the Player Fantasy's "portrait of the specific player you turned out to be," since Menagerie already tracks individual bred creatures with real identities (lineage, traits)? **Resolution**: Encyclopedia *witnesses* discovery; Menagerie *owns* creature identity. A codex is a checklist by nature — matching every other category here (skills, runes, recipes, tech are all catalogue-style, not instance-style) — and the "specific player" individuality the Player Fantasy promises is genuinely delivered, just not by this system: it already lives in Menagerie's own per-creature records, which this document does not duplicate (per Core Rule 2's own anti-duplication discipline). Species-level stands as the correct scope for THIS system's job, not a compromise.

### States and Transitions

**Per-Entry Discovery Ledger** (per `category`+`entry_id` pair, save-persisted, playthrough-scoped):

| State | Entry Condition | Behavior | Exit Condition |
|---|---|---|---|
| `HIDDEN` (implicit — not a stored state, just ledger absence) | Default for every possible `category`+`entry_id` at playthrough start | No entry exists; not returned by any query | Matching inbound discovery event fires for the first time → `DISCOVERED` |
| `DISCOVERED` | First matching inbound event (Core Rule 1's table) | Entry permanently present in the ledger; `encyclopedia_entry_added` fired exactly once at this transition | Terminal — never reverts, never re-fires the added event |

### Interactions with Other Systems

| System | Direction | Data | Mechanism | When |
|---|---|---|---|---|
| **EventBus** | ← subscribes | `skill_unlocked`, `constellation_rune_discovered`, `tarot_rune_discovered`, `recipe_discovered`, `creature_acquired`, `creature_bred`, `tech_unlocked` | EventBus signal | Continuous, any time during gameplay (Sanctuary or Mission context) |
| **EventBus** | → emits | `encyclopedia_entry_added(category, entry_id)` | EventBus signal | At most once per genuinely new entry, ever |
| **Constellation** | Upstream (Encyclopedia depends on) | `constellation_rune_discovered` | EventBus subscription | First pattern completion per rune, per playthrough |
| **Tarot** | Upstream | `tarot_rune_discovered` | EventBus subscription | First mission attempt with a card equipped, per playthrough |
| **Crafting** | Upstream | `recipe_discovered` (`recipe_category` unspecified taxonomy — see Edge Cases) | EventBus subscription | Tech gate + material gate both true, first time |
| **Equipment Forge** | Upstream | `recipe_discovered` (`recipe_category = "hero_equipment"`) | EventBus subscription | Same gating, Forge-scoped recipes. **Provenance note**: `equipment-forge.md`'s own already-written text asserts this emission, but `event-bus.md`'s frozen catalogue currently lists `recipe_discovered` under Crafting only, with no Equipment Forge emitter row — this is an inherited gap in `event-bus.md`'s own catalogue (not something this document invented), flagged as OQ-7, not treated as blocking Encyclopedia's own design |
| **Menagerie** | Upstream | `creature_acquired`, `creature_bred` | EventBus subscription | Lure success or breeding-pen output |
| **Defense Building** | Upstream | `tech_unlocked` | EventBus subscription | Tech tree node unlock confirmed |
| **Hero Skill Tree / Hero Skill Build** | Upstream | `skill_unlocked` | EventBus subscription | Node purchased at Sanctuary (corrected 2026-08-31, third pass — was "Proximity threshold reached," Tower Mastery's old direct-unlock trigger; that system now only feeds Hero Skill Tree, which is the sole current emitter) |
| **Mission HUD** | Downstream | `encyclopedia_entry_added` | EventBus subscription | Any new entry, for its own discovery-notification toast |
| **Save & Persistence** | Bidirectional | Full entry ledger, all categories | `get_save_data()`/`restore_save_data()`/`reset_to_defaults()` at `restore_order = 35` (restored last — see Edge Cases for why this is not a race) | Standard save/restore cycle |

## Formulas

None. The only numeric candidate — a completion-percentage readout per category or overall — is explicitly deferred (Core Rule 7): no GDD anywhere authors a stable, frozen total-known-count denominator per category, so computing a percentage now would produce a number that silently breaks the first time new content ships. Every other value this system owns is a discovery fact (a boolean-shaped ledger membership check), not a derived calculation.

## Edge Cases

- **If the game boots on a fresh save (0 prior entries)**: `get_save_data()` returns an empty structure for every category; `restore_save_data({})` and `reset_to_defaults()` produce an identical empty-ledger result — no error, no special-cased "first ever boot" branch needed.
- **If a discovery event fires for a `category`+`entry_id` already `DISCOVERED`** (e.g. a second creature of an already-discovered species is bred, or a duplicate `recipe_discovered` fires due to an upstream system's own retry): the event is a no-op — ledger membership is checked before insert, no duplicate entry is created, and `encyclopedia_entry_added` does not re-fire (preventing a duplicate Mission HUD toast for something already discovered).
- **If `restore_order = 35` (last) creates an apparent boot-order race with an early-mission discovery event**: not a real race. `restore_save_data()` populates the ledger directly from disk and never itself re-fires any of the 7 inbound discovery events — those only ever originate from live gameplay (a proximity threshold, a completed pattern, a crafted recipe, a bred creature, a purchased tech node), none of which can occur before Save & Persistence's own full restore sequence completes and `sanctuary_state_restored` fires. Being restored last only means Encyclopedia's own ledger is the last one populated from disk, not that it risks missing a live event that happens to fire early.
- **If `recipe_discovered`'s `recipe_category` field carries a value neither `crafting.md` nor `equipment-forge.md` has defined a closed taxonomy for**: Encyclopedia stores whatever string arrives, unvalidated — this system is not the authority on what `recipe_category` values are legal (Crafting/Equipment Forge are), and rejecting or special-casing unknown values here would silently duplicate validation logic that belongs upstream. Flagged as Open Question OQ-4 for whoever owns that taxonomy.
- **If a monster/bestiary discovery is expected by a future UI but no event exists to drive it**: no entry is ever created for that category, by design — Core Rule 6 defers this entirely rather than faking a partial implementation.

## Dependencies

| System | Direction | Nature |
|---|---|---|
| EventBus | Encyclopedia depends on | Hard — all 7 inbound subscriptions and its own outbound emission route through it |
| Save & Persistence | Encyclopedia depends on | Hard — `restore_order = 35`, restored last, per `save-persistence.md`'s own authoritative table |
| Constellation | Encyclopedia depends on | Soft — subscribes to `constellation_rune_discovered`; Encyclopedia's own function degrades gracefully (fewer entries) without it, nothing structurally breaks |
| Tarot | Encyclopedia depends on | Soft — same pattern, `tarot_rune_discovered` |
| Crafting | Encyclopedia depends on | Soft — same pattern, `recipe_discovered` |
| Equipment Forge | Encyclopedia depends on | Soft — same pattern, `recipe_discovered` (Forge-scoped) |
| Menagerie | Encyclopedia depends on | Soft — same pattern, `creature_acquired`/`creature_bred` |
| Defense Building | Encyclopedia depends on | Soft — same pattern, `tech_unlocked` |
| Hero Skill Tree / Hero Skill Build | Encyclopedia depends on | Soft — same pattern, `skill_unlocked` (corrected 2026-08-31, third pass, was Tower Mastery) |
| Mission HUD | Depended on by Encyclopedia | Downstream — subscribes to `encyclopedia_entry_added` for its own toast; already declared on Mission HUD's own side per `event-bus.md`'s Key Subscribers column |

**Bidirectional note**: each of the 7 upstream systems already lists Encyclopedia as a downstream subscriber in its own Interactions/Dependencies table (confirmed by direct cross-reference while authoring this document) — this is one of the rare cases in this project where the bidirectional-dependencies rule was already satisfied on the upstream side before this GDD existed, since every one of those documents was written expecting Encyclopedia to eventually exist.

## Tuning Knobs

None. Encyclopedia has no designer-adjustable gameplay values — its category list and event mappings (Core Rule 1) are architecture, not balance, and changing them requires a Core Rule revision, not a tuning pass. This matches `sanctuary-ui.md`'s and `tarot-deck-ui.md`'s own precedent for pure presentation/data shells with no tunable knobs of their own (though unlike those two, this document has no timing/animation values either, since it owns no presentation layer yet — see UI Requirements).

## Visual/Audio Requirements

This system owns no VFX or audio of its own. Every discovery moment's actual visual/audio flourish is already fully specified in its *originating* system's own GDD (Constellation's carved-medallion reveal, Tarot's card-flip reveal, Crafting's unlock-cascade, etc.) — Encyclopedia never re-presents or duplicates those moments, per the Player Fantasy's own explicit "never chase the spotlight" discipline. The one downstream consequence with any presentation surface — Mission HUD's own discovery-notification toast, driven by `encyclopedia_entry_added` — is already Mission HUD's own responsibility (`event-bus.md`'s Key Subscribers column) and already covered by that document's own Visual/Audio Requirements, not this one's.

## UI Requirements

**Deliberately deferred, not designed here.** No dedicated Encyclopedia browsing screen exists anywhere in this project yet, and this document does not invent one or its entry point. Two existing UI shells (`sanctuary-ui.md`, a 5-room hub already width-budgeted and reviewed for exactly 5 entries; `tarot-deck-ui.md`, a 2-screen shell) were considered as possible hosts and explicitly rejected as something this GDD should decide unilaterally — this project's own recent experience (documented in `sanctuary-ui.md`'s review log) showed that bolting a late UI entry point onto an already-reviewed shell, without that shell's own author re-running its review, produces exactly the kind of cascading defect this document wants to avoid. `mission-hud.md`'s own Overview section speculated, before either shell existed, that Encyclopedia would live inside "the separate, not-yet-started Sanctuary UI system" — that expectation was never followed through when Sanctuary UI was actually designed, and this document does not silently assume it still holds.

**What this means concretely**: Encyclopedia's data model, discovery-logging behavior, and persistence (all of Detailed Design above) are fully specified and implementable today, independent of any UI. The screen that lets a player actually browse discovered entries — whether a 3rd top-level shell sibling to Sanctuary UI and Tarot Deck UI, a future 6th Sanctuary UI room (requiring that document's own frozen Core Rule 2 to be deliberately reopened, not patched), or something else entirely — is Open Question OQ-5, to be resolved with full context whenever it's actually taken up, not guessed at here.

**Data Requirements for a Future UI (added — deferring the screen doesn't mean deferring the question of whether the data model can support one; this closes that gap without designing anything)**: whoever eventually authors that screen can support, directly from Core Rule 2's data model, **sort/group by category** (stored directly) and **sort by discovery recency** (`discovered_at`). They **cannot** support, without a Core Rule revision, any "seen/unread since your last visit" affordance — no last-viewed reference point exists anywhere in this model (Core Rule 2's own text states this explicitly now, rather than the earlier draft's unearned implication that a "NEW flair" was already supported). If a future UI pass needs that affordance, it is new scope for this document, not an oversight in this one.

📌 **UX Flag**: This system will eventually need UI requirements, but does not yet — do not run `/ux-design encyclopedia` until OQ-5 is resolved and there is an actual screen/entry-point decision to spec against.

## Acceptance Criteria

> **Test type key** (per QA story-type gate): **Logic** = automated unit test, BLOCKING · **Integration** = integration test or documented playtest, BLOCKING.

### Group 1 — Discovery Event → Entry Conversion (Core Rule 1)

- **AC-1** *(Integration)*: GIVEN Encyclopedia is subscribed to EventBus, WHEN `skill_unlocked(skill_id, source_tower_id)` fires, THEN exactly one new `DISCOVERED` entry is added to the `skill` category keyed by `skill_id`.
- **AC-2** *(Integration)*: WHEN `constellation_rune_discovered(rune_id, pattern_id)` fires, THEN exactly one new `DISCOVERED` entry is added to the `constellation_rune` category keyed by `rune_id`.
- **AC-3** *(Integration)*: WHEN `tarot_rune_discovered(rune_id, card_id)` fires, THEN exactly one new `DISCOVERED` entry is added to the `tarot_rune` category keyed by `rune_id`.
- **AC-4** *(Integration, corrected — the original draft contradicted Core Rule 2)*: WHEN `recipe_discovered(recipe_id, recipe_category)` fires (for any observed `recipe_category` value, including both Crafting- and Equipment-Forge-sourced recipes), THEN exactly one new `DISCOVERED` entry is added to the `recipe` category keyed by `recipe_id` — and the entry's stored shape is exactly `{category: "recipe", entry_id: recipe_id, discovered_at: <timestamp>}`, with `recipe_category` **not** persisted on the entry (it is resolved by lookup at render time, per Core Rule 2's revised text).
- **AC-5** *(Integration)*: WHEN `creature_acquired(creature_id, species)` fires for a species with no existing `creature` entry, THEN a `DISCOVERED` entry is added to the `creature` category keyed by `species` — **not** `creature_id` (Core Rule 8).
- **AC-6** *(Integration)*: WHEN `creature_bred(offspring_id, species)` fires for a species with no existing `creature` entry, THEN the same species-keyed entry is added, following AC-5's rule.
- **AC-7** *(Integration)*: WHEN `tech_unlocked(tech_id, tech_category)` fires, THEN a `DISCOVERED` entry is added to the `tech` category keyed by `tech_id`.

### Group 2 — Duplicate Suppression (Edge Cases)

- **AC-8** *(Logic)*: GIVEN a species already has a `DISCOVERED` `creature` entry, WHEN a second `creature_bred` or `creature_acquired` fires for that same species (different `offspring_id`/`creature_id`), THEN no new entry is created and the existing entry is untouched.
- **AC-9** *(Logic)*: GIVEN any category, WHEN a discovery event fires for a `category`+`entry_id` combination already `DISCOVERED`, THEN the entry ledger's size for that category is unchanged.

### Group 3 — `encyclopedia_entry_added` Emission Contract (Core Rule 4)

- **AC-10** *(Logic)*: GIVEN a genuinely new entry is created (any category), WHEN the entry is committed, THEN `encyclopedia_entry_added(category, entry_id)` fires exactly once with the correct category and ID.
- **AC-11** *(Logic)*: GIVEN a duplicate discovery event per AC-8/AC-9, WHEN it is processed, THEN `encyclopedia_entry_added` does **not** fire.

### Group 4 — Persistence

- **AC-12** *(Integration)*: GIVEN entries exist across multiple categories, WHEN the game saves and reloads, THEN every entry is present post-load with identical `category`/`entry_id`/`DISCOVERED` state and identical `discovered_at` timestamp.
- **AC-13** *(Logic)*: GIVEN a fresh save with no prior discoveries, WHEN Encyclopedia initializes, THEN every category (`skill`, `constellation_rune`, `tarot_rune`, `recipe`, `creature`, `tech`) reports 0 entries.

### Group 5 — Core Purpose (Cross-System Record)

- **AC-14** *(Logic, rewritten — the original wording asserted an untestable negative)*: GIVEN entries exist from at least 3 distinct source systems (e.g. Constellation, Menagerie, Defense Building), WHEN `get_entries()` (Core Rule 2's query contract) is called with no `category` argument, THEN it returns all of them in one collection — confirming a consumer can read the full cross-system record through one method call, with no category-specific special-casing required.
- **AC-15a** *(Logic, split from the original AC-15 — narrowed to what Encyclopedia's own code can actually prove)*: GIVEN `restore_save_data()` is called, WHEN it processes the saved ledger, THEN Encyclopedia itself emits none of its 7 inbound discovery-event types as a side effect, and emits `encyclopedia_entry_added` only for entries that are genuinely new relative to the ledger being restored (i.e. never for entries the save data itself already contains).
- **AC-15b** *(Integration, split from the original AC-15 — the broader claim about upstream systems, correctly reclassified)*: GIVEN a full save/restore cycle across Encyclopedia and at least 2 of its upstream systems (e.g. Constellation, Tarot), WHEN restoration completes, THEN none of those upstream systems fire a live discovery event as a side effect of their own restore — this is jointly owned evidence with those systems' own test suites, not solely Encyclopedia's, since the "not a real race" claim in Edge Cases depends on their behavior, not just this system's.
- **AC-16** *(Logic, added — closes a real gap the design review found: nothing previously pinned the exact stored shape, leaving room for silent scope creep)*: GIVEN any entry in any category, WHEN its persisted/serialized form is inspected, THEN it contains exactly the 3 keys `category`, `entry_id`, `discovered_at` and no others.

## Open Questions

| # | Question | Owner | Target Resolution |
|---|---|---|---|
| OQ-1 | Bestiary/monster codex (`monster.md`'s own stated expectation) is deferred — no one-shot "first encounter" event exists for any monster species. Should `monster.md` originate one (matching Menagerie's `creature_acquired` precedent), and if so, what's the trigger (first spawn? first kill? first sighting in Scout Phase)? | Monster System owner | Before a bestiary feature is scheduled |
| OQ-2 | Completion-percentage tracking (`mission-select.md`'s "future completionist system") is deferred pending a stable, frozen total-known-count per category. Which document should own authoring that catalogue — a new registry entry, or each source system's own GDD stating its own total? | Producer / Game Designer | Before a completion-percentage UI element is scheduled |
| ~~OQ-3~~ | ~~Adjudicated during `/design-review`~~ — species-level discovery (Core Rule 8) is confirmed consistent with `menagerie.md`'s own already-existing text (which independently says "species-discovery entries" in 3 places), and the design tension it raises against the Player Fantasy (individual identity vs. checklist) is resolved: Encyclopedia witnesses, Menagerie owns identity — species-level is the correct scope for this system, not a compromise. See Core Rule 8's own revised text. | — | Resolved |
| OQ-4 | `recipe_discovered`'s `recipe_category` field has no closed, documented taxonomy in either `crafting.md` or `equipment-forge.md` as of this GDD's authoring — Encyclopedia stores whatever string arrives, unvalidated, at render-time lookup only (never persisted, per Core Rule 2's revised text). Should one of those two GDDs (or a shared registry) freeze the legal value set? | Crafting / Equipment Forge owner | Before content validation tooling is built |
| OQ-5 | No Encyclopedia browsing screen or entry point exists yet (UI Requirements). Candidates considered but not decided: a 3rd top-level shell (sibling to Sanctuary UI and Tarot Deck UI), a future 6th Sanctuary UI room (requires deliberately reopening that document's frozen Core Rule 2, not patching it), or something else. Deliberately left open rather than guessed at, given this project's own recent experience with late, unreviewed UI-shell additions. A minimal read-only query contract (Core Rule 2's `get_entries()`/`is_discovered()`) exists independent of this question, so the Player Fantasy is reachable by *some* consumer even before a screen is designed. | UX Designer / Game Designer | When a dedicated `/ux-design` pass for this system is scheduled |
| OQ-6 | This GDD explicitly declines the "Encyclopedia as Tarot-card-purchase-mechanism" candidate `tarot.md` named (Core Rule 5) — Defense Building's tech tree remains the sole unlock source. If a genuine Encyclopedia-driven unlock/spend mechanic is ever wanted later, it needs a dedicated future Core Rule addition, not a retrofit of this document's passive-ledger model. | Game Designer | If/when a purchase-style unlock mechanic is proposed |
| OQ-7 | `equipment-forge.md`'s own text asserts it emits `recipe_discovered(recipe_category="hero_equipment")`, but `event-bus.md`'s frozen catalogue currently lists `recipe_discovered` under Crafting only, with no Equipment Forge emitter row — an inherited documentation gap in `event-bus.md`, found while authoring this GDD, not a defect this document introduced. Should `event-bus.md` add the missing row? | EventBus owner | Next `event-bus.md` revision |
| **OQ-8 (elevated priority — flagged during independent re-verification as the highest-priority open item in this document)** | No `GameDataRegistry`-style lookup path is confirmed to exist anywhere for `constellation_rune` or `tarot_rune` entries — Core Rule 2's render-time-lookup model assumes one, but only Crafting recipes and Monster/drop-table data have a documented registry today. `constellation.md`'s own discovery-reveal card already displays a rune's name/icon without stating where that data comes from. **Why this outranks OQ-1/OQ-4/OQ-7**: this document's Core Rule 2 fix (a `get_entries()`/`is_discovered()` query contract) made the *data* readable and closed the "Player Fantasy is unfalsifiable" gap the design review found — but for 2 of this document's 6 categories, there is still no confirmed path from a readable `entry_id` to actual human-readable display content, which is what the Player Fantasy's "turn back through the pages" promise actually needs once a UI exists. This is a shared gap with 2 upstream GDDs, not something Encyclopedia can resolve alone. | Constellation / Tarot owners | Before a browsing UI needs to render rune display content — higher priority than this document's other Open Questions |

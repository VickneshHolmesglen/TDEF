# Tarot System

> **Status**: Needs Revision (`/design-review --depth lean` 2026-07-17 — mastery-tier count contradicted itself between Core Rules (5 tiers) and the Visual/Audio pip spec (3 masterable tiers); fixed same-day, pip count corrected 3→4 to match the 5-tier ladder. Formula F2's aggregate-stage ceiling for `tarot_reward_scalar_mult` was undefined/ambiguous against Rule 7's table; fixed same-day — explicit note added clarifying F2 passes this type through unclamped, with the real ceiling applied once at F3.) → **Approved** (`/design-review --depth lean` re-review 2026-08-27 — the wave-manager.md blocker (Tarot misattributed as `run_modifier_selected` sender) confirmed fixed there 2026-07-17; no new blockers found.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-17
> **Implements Pillar**: Mastery-as-Vindication · Everything Connects · The Sanctuary Is Your Statement
> **Closes**: `wave-manager.md`'s Open Question OQ-2 (Tarot modifier override protocol) — `wave-manager.md` itself now reflects this correction as of 2026-07-17 (see `wave-manager.md`'s status header). **Known gaps**: no system yet owns how a Tarot card becomes unlocked; `tarot_wave_config_override` is mechanically complete but has no authored content yet. See Open Questions.

## Overview

The Tarot System is the sanctuary's pre-mission wager layer: it lets the player assemble a deck of Tarot cards between missions and, at mission start, resolves that deck into a concrete set of run modifiers that reshape the specific mission ahead. Technically, it owns the player's card collection and the composition of an equipped deck, unlocks new cards through a discovery layer (`tarot_rune_discovered` fires the first time a given rune is unlocked in a playthrough, mirroring Constellation's discovery pattern), and tracks a per-card mastery value that deepens through repeated use — a card grown in mastery returns more, or exacts less cost, for the same staked risk. During the Scout Phase the equipped deck resolves *deterministically* (no RNG on the resolution itself) into mission-parameter modifiers — monster speed scalars, wave-composition changes, drop-rate changes — that layer on top of, and are kept explicitly distinct from, Mission Select's generic difficulty modifiers: Tarot is specifically the player's *own chosen* risk, not an imposed one. Per the game's stated risk/reward philosophy these effects are coupled — a card that doubles enemy speed also doubles their drops — so the deck is never a pure buff or a pure handicap but a self-authored trade the player must then survive. It is a pre-commitment mechanic: there is no real-time "play a card" moment in combat; the deck is chosen in the calm of the sanctuary, snaps into the run's terms once at mission start, and is lived through without a take-back. Player-facing, a well-read deck is the one that turns a mission the player deliberately made harder into a mission that pays out precisely because they knew they could carry it — the deck is both a statement of playstyle (cautious and reckless decks look nothing alike) and a running ledger of exactly how much difficulty the player has learned to stake a run on and win.

## Player Fantasy

> A wager against luck is a gamble. A wager against yourself is a prediction. The deck only ever deals the second kind.
>
> There is a moment at the start of every mission — in the Scout Phase, before a single tower is placed — when the deck you built back in the sanctuary stops being a collection of cards and becomes the actual terms of the fight. The board changes in front of you. The enemies you are about to face move faster than they should, or arrive in a shape no unmodified wave ever takes, or carry more than they have any business carrying — because you told them to. That is the instant the Tarot system exists for: the one where you look at a mission that is harder than it had to be, and remember that you are the reason it is. Nothing forced these terms on you. You went into the sanctuary between runs, you looked at what you had survived and what you thought you could survive next, and you set the dial yourself.
>
> This is the one thing you build that does not arm you. A crafted component makes a tower stronger; a constellation makes a field greater than the sum of its towers; a tended menagerie makes every haul larger; the hero makes you present inside the fight. Every other system in the game points its power at the enemy on your behalf. The deck points power the other way. It is the single place in the sanctuary where you reach in and make the mission *worse* — quicker enemies, denser waves, thinner margins — and you do it deliberately, with your eyes open, because a mission worth more is a mission that costs more, and the deck is where you agree to pay. You are not composing your defense here. You are naming your adversary.
>
> And yes — the fight you make harder pays you more. The card that doubles their speed doubles their drops; the terms that could end your run are the same terms that make it worth running. But read the trade the wrong way — pick the risk *for* the payout, stack the deck to farm the richest possible haul and merely hope to survive it — and you have turned a prediction back into a gamble. The deck does not reward the greediest hand. It rewards the *accurate* one: the player who looked at a set of terms and knew, before the first wave broke, that they could carry them. The greater haul is not the prize. It is the receipt. It is the mission confirming, in the only currency it has, that you read your own limit correctly and then chose to stand one step past where you had stood before.
>
> This is why the deck is the truest thing you own. A tower can be well-placed by a lucky hand; a haul can be padded by an easy run. But the deck is a standing record of exactly how much difficulty you have learned to carry and be paid for — every card in it a bet you have placed before, sharpened by the mastery that only comes from placing it again and again and living. A cautious player's deck and a reckless player's deck do not look alike, and neither is wrong; each is a true statement of the hand that holds it. And when the last enemy of a mission you deliberately made harder finally falls — the fast ones, the dense ones, the terms you set yourself, all of it survived — the feeling is not that your towers held, and not that your arrangement held. It is that your *judgment* held: that you named a harder trial than you needed to face, staked the run on being able to pass it, and were proven right by the only proof that counts. That is the vindication the deck gives you that nothing else in the sanctuary can — not that you met the challenge the game set for you, but that you set a harder one yourself, and met that.

## Detailed Design

### Core Rules

#### Group 1 — Card Data Model

1. A Tarot card is a `TarotCardResource` (`.tres` in `assets/data/tarot/`). Fields:

   | Field | Type | Description |
   |-------|------|-------------|
   | `card_id` | `StringName` | Unique identifier |
   | `rarity` | `enum {Common, Rare, Legendary}` | Informs content design's `unlock_tech_id` assignment (see below) — Common cards are typically ungated, Rare/Legendary typically gated behind a Defense Building tech node |
   | `unlock_tech_id` | `StringName` | Defense Building tech node id gating this card's unlock; `""` means unlocked from the start. Content-authored, fixed per card (not mutable per-playthrough state) |
   | `unlocked` (runtime, not a Resource field) | `bool` | Whether the player has this card equippable. Lives on Tarot's own `_card_unlocked` runtime ledger (a future non-tech unlock source writes here), OR-combined at query time with a live `GDefenseBuilding.is_tech_unlocked(unlock_tech_id)` check — see `is_card_unlocked()` |
   | `modifiers` | `Array[TarotModifierEntry]` | 1–2 entries (see Rule 2). Most cards carry exactly 1; "dual-edge" risk/reward cards (Rule 2a) carry 2 |
   | `linked_rune_id` | `StringName` | The rune this card unlocks on discovery (Rule 9). One card → exactly one rune, 1:1 |
   | `mastery_tier` | `int` | 0–4, save-persisted per card instance (Group 4) |
   | `mastery_missions_played` | `int` | Cumulative XP counter, save-persisted per card instance (Group 4) |

2. A `TarotModifierEntry` is `{modifier_type: StringName, base_modifier_value: float}`. `modifier_type` must be one of the four registered types in the Modifier Resolution Protocol (Group 3, Rule 6). A card's `modifiers` array is fixed content — authored once, never changed at runtime except by mastery scaling (Formula F1).

   **2a. Dual-edge (risk/reward) cards:** A card may carry two entries — one combat-difficulty type (`tarot_speed_scalar_mult`) and one Resource-Economy-adjacent type (`tarot_reward_scalar_mult`) — to realize the game-concept.md design intent "a Tarot card that doubles enemy speed also doubles their drops." See the worked example under Formula F4.

---

#### Group 2 — Deck Model

3. A deck is an ordered list of up to `TAROT_DECK_SLOT_COUNT` (default: 5; safe range 3–7 — see Tuning Knobs) equipped `card_id` values, configured only at SANCTUARY. This is a per-mission commitment, not an inventory — it is not the full set of unlocked cards, only the subset the player has chosen to bring.
4. Equipping or unequipping a card at Sanctuary emits `tarot_deck_changed(active_card_count: int)` immediately (frozen event contract — no changes here).
5. **Deck lock:** On `mission_launched`, Tarot copies the current deck into an internal `_active_mission_deck: Array[StringName]` snapshot. This snapshot is immutable for the mission's full duration — Sanctuary is not accessible mid-mission (per game-concept.md's phase model), so no runtime deck-editing path exists, but the snapshot exists as a defensive boundary in case Sanctuary UI is ever reachable from a paused state in a future revision.

---

#### Group 3 — Modifier Resolution Protocol (**closes Wave Manager GDD Open Question OQ-2**)

6. **Emission trigger:** Immediately on `mission_phase_changed` (→ SCOUT) — i.e., at the same moment Wave Manager Rule 8 begins SCOUT — Tarot iterates `_active_mission_deck` and emits one `mission_modifier_applied(modifier_type: String, modifier_value: float, source_card_id: String)` per `TarotModifierEntry` across all equipped cards (a card with 2 entries emits 2 events). `modifier_value` is the entry's **mastery-scaled effective value** (Formula F1) — Tarot performs mastery scaling before emission; downstream subscribers never see raw `base_modifier_value`.

7. **Four registered `modifier_type` values, one mechanism each (no mixed/ambiguous schemes):**

   | `modifier_type` | Mechanism | Target | Aggregating subscriber | Clamp/Ceiling |
   |---|---|---|---|---|
   | `tarot_speed_scalar_mult` | **MULTIPLICATIVE** | Monster System's `tarot_speed_scalar` (registered constant, consumed directly by `monster_speed_scaling` — see `design/registry/entities.yaml`) | **Monster System** (subscribes directly to `mission_modifier_applied`, per event-bus.md's existing Key Subscribers row — Monster System aggregates, not Wave Manager) | `[0.50, 2.00]` — the constant's own registered range |
   | `tarot_reward_scalar_mult` | **MULTIPLICATIVE** | Wave Manager's `wave_reward_scalar` (Formula F1 output in wave-manager.md), applied uniformly across all waves for the mission | **Wave Manager** | Final scalar clamped to `[1.00, 4.768]` — wave-manager.md F1's own natural output ceiling (see Formula F3 below; chosen deliberately so Tarot cannot push a mission's combined economic return past the ceiling Resource Economy already calibrated against, `WAVE_ERI_CEILING_COMBINED = 22.73`) |
   | `tarot_difficulty_growth_rate` | **REPLACE** (absolute substitution) | `WaveConfig.difficulty_growth_rate` (`r`) | **Wave Manager** | Clamped to Wave Manager's own validated range `[0.10, 0.25]` (wave-manager.md Rule "Runtime validation") |
   | `tarot_wave_config_override` | **REPLACE** (whole-Resource swap) | `WaveConfig` itself (wave count / composition) | **Wave Manager** | Must reference a pre-authored alternate `WaveConfig` variant tagged for the same `mission_id`; if absent or invalid, Edge Case EC-6 applies |

   **Rationale for per-type mechanism choice:** `tarot_speed_scalar_mult` reuses the mechanism the registry has already fixed for `tarot_speed_scalar` (multiplicative term in `monster_speed_scaling`) — this is not a new design decision, it is precedent-following. `tarot_reward_scalar_mult` mirrors it for consistency and because a multiplier composes cleanly with Wave Manager's own exponential F1 formula. `difficulty_growth_rate` is a single authored global-per-mission float; an additive delta or multiplier would require the card author to know the mission's base `r` in advance to predict the outcome, whereas REPLACE gives a card a clear, mission-independent identity ("this card sets the growth rate to exactly 0.25"). `tarot_wave_config_override` cannot be expressed as a delta or multiplier at all — wave count is a structural property of an authored `Array[WaveScript]`, not a scalar — so whole-Resource REPLACE is the only mechanism that is structurally coherent.

   **`tarot_wave_config_override` is Vertical Slice scope-flagged (assumption):** no mission currently authors an alternate `WaveConfig` variant. This mechanism is fully specified here to close OQ-2, but content authoring (building the alternate `WaveConfig` assets) is Post-MVP. A card using this `modifier_type` should not ship until at least one mission has an authored alternate variant.

8. **Resolution order (binding, extends game-concept.md's existing edge case):**

   1. Mission Select's `run_modifier_selected` values are applied to `WaveConfig`/mission parameters first (existing Wave Manager / Mission Select territory, unchanged by this GDD).
   2. Tarot's `mission_modifier_applied` (per equipped card, per Rule 6/7) applies on top of the Mission-Select-adjusted values, at SCOUT entry.
   3. Tarot **rune** effects (Group 5 — permanent, discovery-gated, always-on regardless of current deck) apply last, layered on top of steps 1–2's result. This is the literal ordering event-bus.md already states for `mission_modifier_applied`: "modifiers resolve before Tarot rune effects."

   **Channel ownership (resolves the `run_modifier_selected` vs. `mission_modifier_applied` ambiguity):** Tarot does **not** emit through `run_modifier_selected`. That channel is exclusively Mission-Select-owned (difficulty sliders, player-toggled run options) and its payload (`modifier_id`, `modifier_value`) has no `source_card_id` field — it cannot express "which card produced this," which Tarot's mastery/rune-discovery model requires for traceability. Tarot exclusively emits `mission_modifier_applied`, whose payload was purpose-built with `source_card_id`. Tarot **does subscribe** (read-only) to `run_modifier_selected` — not to perform resolution logic (that already lives structurally in Wave Manager per Rule 8's ordering) but so the Tarot Deck UI can surface a conflict indicator when a Mission Select run modifier already targets a `modifier_type` a slotted card also targets, before the player launches the mission. **wave-manager.md's Dependencies table lists "Tarot / Mission Select" together as senders of `run_modifier_selected` — this is a documentation looseness this GDD corrects: Tarot is a subscriber, never a sender, of `run_modifier_selected`.**

9. Tarot must not define a hero-damage-affecting modifier. The registered `hero_damage_bonus_multiplier` (`design/gdd/damage-status.md`, value 1.50) is the sole hero-vs-ELITE/BOSS damage bonus. No `modifier_type` in Rule 7's table touches hero damage, by design — this satisfies the registry's explicit warning against a duplicate.

---

#### Group 4 — Mastery

10. Each equipped card accrues `mastery_missions_played += 1` once per mission attempt where it was present in `_active_mission_deck` (Rule 5), regardless of mission outcome (MISSION_COMPLETE or DEFEAT — see Edge Case EC-5). Increment fires once, on the mission's terminal `mission_phase_changed` (→ MISSION_COMPLETE or → DEFEAT).
11. `mastery_tier` (0–4, "Novice/Apprentice/Adept/Expert/Master") is derived from `mastery_missions_played` via a fixed threshold lookup (Formula F6) — not stored independently; it is recomputed from the counter every time it is read, so there is no tier-desync risk.
12. Mastery scales a card's `modifiers[].base_modifier_value` via `mastery_tier_scalar` (Formula F1) — magnitude only. It never changes `modifier_type`, never adds new modifier entries, and never affects the deck-slot cost of the card.

---

#### Group 5 — Card vs. Rune Distinction

13. A **card** is the deck-building unit: many exist, the player chooses which ≤5 to slot per mission, and its effect (Group 3) is active only while equipped.
14. A **rune** is a permanent, discovery-gated, always-on bonus layer tied 1:1 to a specific card (`linked_rune_id`), independent of whether that card is currently equipped. Runes are the "vindication" layer — proof a card has been proven out, not a build-time choice.
15. **Discovery condition:** The first time a card completes a mission attempt (MISSION_COMPLETE **or** DEFEAT — engagement, not victory, is what proves the card out; see Rule 10's identical no-outcome-gate rationale) while equipped, its linked rune transitions `UNDISCOVERED → DISCOVERED` and `tarot_rune_discovered(rune_id: String, card_id: String)` fires exactly once, permanently, for the remainder of the playthrough (identical one-way pattern to Constellation's Discovery Ledger, `design/gdd/constellation.md` States and Transitions — see also Crafting's `recipe_discovered`). **Assumption flagged:** whether rune discovery should require MISSION_COMPLETE only (a stricter "prove it works" bar) is a real design choice with no other GDD constraining it; this document defaults to the more permissive "any mission attempt" bar for consistency with Rule 10's mastery-accrual reasoning, but this is the single most swappable assumption in this document if playtesting shows first-rune discovery happens too early.
16. Once `DISCOVERED`, a rune applies a small, fixed, **additive** bonus to its associated `modifier_type` every mission thereafter, regardless of deck composition (Formula F5) — this is what makes it distinct from the card's own (equipped-only, mastery-scaled, multiplicative-or-replace) effect. A discovered rune's card can still be equipped and will double-apply its own card effect on top — this "stacking a card with its own proven rune" is intended, not a bug (Edge Case EC-8).

---

### States and Transitions

**Deck Lock Lifecycle** (per mission):

| State | Entry Condition | Player Actions | Exit Condition |
|-------|-----------------|-----------------|-----------------|
| `EDITABLE` | Default; player is at SANCTUARY | Equip/unequip cards (≤ deck slot count); emits `tarot_deck_changed` per change | Player launches a mission (`mission_launched`) |
| `LOCKED` | `mission_launched` received | None — deck is immutable for the mission | Mission ends (MISSION_COMPLETE or DEFEAT) → returns to `EDITABLE` at SANCTUARY |

**Per-Card Mastery Progression** (per card, save-persisted):

| State | Entry Condition | Behavior | Exit Condition |
|-------|-----------------|----------|-----------------|
| Tier 0 (Novice) | Card first unlocked | `mastery_tier_scalar = 1.00` | `mastery_missions_played` crosses tier-1 threshold → Tier 1 |
| Tier 1 (Apprentice) | Threshold crossed | `mastery_tier_scalar = 1.15` | Threshold crossed → Tier 2 |
| Tier 2 (Adept) | Threshold crossed | `mastery_tier_scalar = 1.30` | Threshold crossed → Tier 3 |
| Tier 3 (Expert) | Threshold crossed | `mastery_tier_scalar = 1.50` | Threshold crossed → Tier 4 |
| Tier 4 (Master) | Threshold crossed | `mastery_tier_scalar = 1.75` | Terminal — no further tiers |

**Rune Discovery Ledger** (per card's `linked_rune_id`, playthrough-scoped, save-persisted — mirrors Constellation's Discovery Ledger exactly):

| State | Entry Condition | Behavior | Exit Condition |
|-------|-----------------|----------|-----------------|
| `UNDISCOVERED` | Default for every `linked_rune_id` at playthrough start (or fresh save) | No effect applied | Card completes its first mission attempt while equipped (MISSION_COMPLETE or DEFEAT) → `DISCOVERED`, `tarot_rune_discovered` emitted |
| `DISCOVERED` | First mission attempt with the card equipped | Rune's fixed additive bonus (Formula F5) applies every mission thereafter, unconditionally | Terminal — never reverts |

---

### Interactions with Other Systems

| System | Direction | Data | Mechanism | When |
|--------|-----------|------|-----------|------|
| **EventBus** | → emits | `mission_modifier_applied` (per equipped card modifier entry, mastery-scaled), `tarot_rune_discovered` (first discovery only), `tarot_deck_changed` (deck edits at Sanctuary) | EventBus signal | `mission_modifier_applied`: at SCOUT entry, per mission. `tarot_rune_discovered`: at most once per `linked_rune_id` per playthrough, on mission end. `tarot_deck_changed`: any Sanctuary deck edit |
| **EventBus** | ← subscribes | `mission_launched` (lock deck snapshot, Rule 5), `mission_phase_changed` (detect SCOUT entry to fire modifiers per Rule 6; detect MISSION_COMPLETE/DEFEAT to accrue mastery/discovery per Rules 10/15), `run_modifier_selected` (read-only conflict-awareness for Tarot Deck UI, Rule 8) | EventBus signal | Continuous during a mission's lifecycle |
| **Wave Manager** | ← consumes | `mission_modifier_applied` where `modifier_type ∈ {tarot_reward_scalar_mult, tarot_difficulty_growth_rate, tarot_wave_config_override}` | EventBus subscription | At SCOUT entry, before PRE_WAVE begins — Wave Manager applies these to its own `WaveConfig`/F1 output before any wave's spawn sequencing starts |
| **Monster System** | ← consumes | `mission_modifier_applied` where `modifier_type == tarot_speed_scalar_mult` | EventBus subscription | At SCOUT entry — Monster System aggregates (Formula F2) and clamps its own `tarot_speed_scalar` value before Wave 1's first `monster_speed_scaling` evaluation |
| **Save & Persistence** | Bidirectional | Deck composition (`_active_mission_deck` template, i.e. the SANCTUARY-time equipped list), per-card `mastery_tier`/`mastery_missions_played`, Discovery Ledger (`linked_rune_id → DISCOVERED` set) | `get_save_data()`/`restore_save_data()` at `restore_order = 22` (Feature layer, independent) | Standard save/restore cycle |
| **Encyclopedia** | → downstream | `tarot_rune_discovered(rune_id, card_id)` | EventBus | First discovery of any rune |
| **Equipment Forge** | → downstream | `tarot_rune_discovered(rune_id, card_id)` | EventBus | First discovery of any rune |
| **Tarot Deck UI** | → downstream | `tarot_deck_changed(active_card_count)` | EventBus | Any Sanctuary deck edit |
| **Mission Select** | ← reads (indirect) | `run_modifier_selected` (read-only — see Interactions row above) | EventBus subscription | Player toggles a run modifier before/during SCOUT |

**Assumption flagged:** No Mission Select GDD file exists yet in this repository (`design/gdd/mission-select.md` was not found at authoring time) — the `run_modifier_selected` payload shape used above is taken solely from `event-bus.md`'s frozen catalogue (`modifier_id: String`, `modifier_value: float`). If Mission Select's own GDD later defines additional structure, this document's read-only subscription should be revisited, but the ownership/mechanism decisions in Group 3 do not depend on Mission Select's internals.

## Formulas

#### F1 — Card Effective Modifier Value (mastery scaling)

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `base_modifier_value` | `b` | float | per-`modifier_type` safe range (Tuning Knobs) | Authored value on the `TarotModifierEntry` |
| `mastery_tier_scalar` | `m` | float | `{1.00, 1.15, 1.30, 1.50, 1.75}` | Looked up from the card's current `mastery_tier` (0–4) via Formula F6 |
| `effective_modifier_value` | `v` | float | unbounded here — clamped downstream at aggregation (F2) | The value actually emitted in `mission_modifier_applied.modifier_value` |

**Expression:**
```
effective_modifier_value = base_modifier_value × mastery_tier_scalar
```

**Output range:** Unbounded at this stage by design — clamping happens once, at the aggregate level (F2), not per-card, so that stacking behavior (Rule 8/EC-3) is evaluated on the combined product, not on each card independently.

**Worked example:** A `tarot_speed_scalar_mult` card with `base_modifier_value = 1.30`, currently Tier 2 (Adept, `m = 1.30`): `effective_modifier_value = 1.30 × 1.30 = 1.69`.

---

#### F2 — Aggregate Multiplicative Modifier (stacking rule for MULTIPLICATIVE types)

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `effective_modifier_value_i` | `v_i` | float | from F1 | Each equipped card's effective value for this `modifier_type` |
| `N` | `N` | int | 0–5 (deck slot count) | Number of equipped cards targeting this `modifier_type` this mission |
| `aggregate_raw` | `A` | float | unbounded | Product across all `N` cards |
| `ceiling_min`, `ceiling_max` | — | float | per-type, Rule 7's table | The registered clamp for this specific `modifier_type` |
| `aggregate_final` | `A'` | float | `[ceiling_min, ceiling_max]` | The value actually applied to the target system |

**Expression:**
```
aggregate_raw = Π(v_i) for i in 1..N        (empty product = 1.0 when N = 0)
aggregate_final = clamp(aggregate_raw, ceiling_min, ceiling_max)
```

**Output range:** Clamped to the specific `modifier_type`'s registered ceiling (Rule 7 table) — e.g. `[0.50, 2.00]` for `tarot_speed_scalar_mult`.

**`tarot_reward_scalar_mult`'s F2-stage ceiling — resolved 2026-07-17 (previously ambiguous):** Rule 7's table row for this type cites `[1.00, 4.768]`, but that figure is F3's fully-composed final output ceiling, not a distinct F2-stage bound — F3 adds the rune bonus (Formula F5) on top of F2's `aggregate_final` before its own clamp applies, so clamping twice at the same value would be redundant and could silently mask F3's own composition math. **F2's `ceiling_min`/`ceiling_max` for `tarot_reward_scalar_mult` specifically are `[0.0, +inf)`** (i.e., `aggregate_raw` passes through F2 unclamped except for the trivial floor at zero — MULTIPLICATIVE composition of positive `v_i` values can never actually go negative, so this floor is never load-bearing in practice). The real, binding ceiling for this modifier type is applied once, downstream, at F3.

**Stacking rule (closes the "two cards, same modifier_type" edge case):** For **MULTIPLICATIVE** types (`tarot_speed_scalar_mult`, `tarot_reward_scalar_mult`), stacking is multiplicative — chosen because it composes naturally with the single-card multiplicative mechanism already fixed by Rule 7, and because it lets two moderate cards combine into a build-defining extreme without needing a separate additive-stacking formula. For **REPLACE** types (`tarot_difficulty_growth_rate`, `tarot_wave_config_override`), only one equipped card may target that `modifier_type` at a time — the Tarot Deck UI must enforce this at equip-time (a validation rule, not a runtime clamp). If violated by a save-data error or a future UI bug, Wave Manager applies the card in the lowest deck-slot index and discards the rest, logging: `"Multiple REPLACE-type Tarot modifiers targeting [modifier_type] — using slot [i]'s card, discarding [N-1] others."`

**Worked example (2 equipped `tarot_speed_scalar_mult` cards):** Card A `v_1 = 1.69` (from F1 above), Card B `v_2 = 1.20` → `aggregate_raw = 1.69 × 1.20 = 2.028` → `aggregate_final = clamp(2.028, 0.50, 2.00) = 2.00` (clamped).

---

#### F3 — Wave Reward Scalar with Tarot Layer (extends wave-manager.md's F1; **closes OQ-2's reward dimension**)

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `wave_reward_scalar_natural` | `s` | float | 1.00–4.768 | wave-manager.md's own F1 output: `1.0 × (1+r)^(w-1)` |
| `tarot_reward_multiplier` | `A'` | float | from F2 | Aggregate across all equipped `tarot_reward_scalar_mult` cards |
| `rune_reward_bonus` | `rb` | float | 0.00–0.30 (Formula F5) | Additive rune-layer bonus, applied last (Rule 8 step 3) |
| `wave_reward_scalar_final` | `s'` | float | `[1.00, 4.768]` | The value actually forwarded in `monster_spawn_requested`/`monster_died` |

**Expression:**
```
wave_reward_scalar_final = clamp(wave_reward_scalar_natural × tarot_reward_multiplier + rune_reward_bonus, 1.00, 4.768)
```

**Output range:** Hard-clamped to `[1.00, 4.768]` — the same ceiling wave-manager.md's own F1 already produces at its worst case (r=0.25, wave 8). This is a deliberate design choice: Tarot's reward layer can accelerate a mission's reward curve (e.g. make wave 2 feel like wave 6) but cannot exceed the absolute ceiling Resource Economy already calibrated `MAX_BASE_QUALITY_PROBABILITY` and `WAVE_ERI_CEILING_COMBINED` against. Routing mechanism: this final value is what Wave Manager forwards unchanged through the existing `monster_spawn_requested.wave_reward_scalar` field into Monster System's `monster_died` payload — **no new Tarot→Resource-Economy interface is introduced**; Tarot's reward-side effect rides the hook that already exists end-to-end.

**Worked example (wave 3, default r=0.20, one Legendary "Reckless Onslaught" card equipped, Tier 0):** `wave_reward_scalar_natural = 1.0 × 1.20^2 = 1.44`. `tarot_reward_multiplier = 2.00` (F2, single card, `base_modifier_value = 2.00`, Tier 0 scalar 1.00). `rune_reward_bonus = 0.00` (rune not yet discovered). `wave_reward_scalar_final = clamp(1.44 × 2.00 + 0.00, 1.00, 4.768) = 2.88`.

---

#### F4 — Tarot Speed Scalar (**closes OQ-2's speed dimension**; feeds the already-registered `monster_speed_scaling` formula unchanged)

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `tarot_speed_scalar` | `A'` | float | `[0.50, 2.00]` | F2's aggregate output for `modifier_type == tarot_speed_scalar_mult`. This **is** the registered constant `tarot_speed_scalar` (`design/registry/entities.yaml`) — Tarot computes it, Monster System consumes it unmodified in `monster_speed_scaling = base_speed × (1 + speed_wave_growth_rate × (wave_index-1)) × tarot_speed_scalar` |

**Expression:** (identical to F2, restated here for the specific registered target)
```
tarot_speed_scalar = clamp(Π(effective_modifier_value_i for equipped tarot_speed_scalar_mult cards), 0.50, 2.00)
```

**Output range:** `[0.50, 2.00]` — the registry's own bound. When no card targets this type, `tarot_speed_scalar = 1.0` (empty product), matching the registered default exactly.

**Worked example — full risk/reward card ("Reckless Onslaught", Legendary, dual-edge per Rule 2a):**

| Entry | `modifier_type` | `base_modifier_value` |
|-------|-----------------|------------------------|
| 1 | `tarot_speed_scalar_mult` | 2.00 |
| 2 | `tarot_reward_scalar_mult` | 2.00 |

Solo-equipped, Tier 0 (`m = 1.00`): both entries' `effective_modifier_value = 2.00 × 1.00 = 2.00`.
- Speed side: `tarot_speed_scalar = clamp(2.00, 0.50, 2.00) = 2.00` — monster speed **exactly doubles** (before the mission's own natural wave-index speed growth is applied on top, per `monster_speed_scaling`).
- Reward side: at wave 1 (`s = 1.00`): `wave_reward_scalar_final = clamp(1.00 × 2.00 + 0, 1.00, 4.768) = 2.00` — reward **exactly doubles** at wave 1, demonstrating the "doubles enemy speed also doubles their drops" pattern from game-concept.md's Overview. At wave 8 (`s = 3.583`, default r=0.20): `wave_reward_scalar_final = clamp(3.583 × 2.00, 1.00, 4.768) = 4.768` (clamped — the doubling is capped late-mission, an intentional diminishing-returns safety valve, not a design gap).

At Tier 4 (Master, `m = 1.75`) with the card still solo-equipped: `effective_modifier_value = 2.00 × 1.75 = 3.50` for both entries. Speed: `clamp(3.50, 0.50, 2.00) = 2.00` (already saturated at Tier 0 — mastery growth on this particular card has no further speed-side effect past Tier 0, an emergent consequence of its unusually high `base_modifier_value`, not a bug). Reward at wave 8: `clamp(3.583 × 3.50, 1.00, 4.768) = 4.768` (same clamp). **Design note:** this is a legitimate outcome of pairing a maximum-magnitude base value with mastery scaling — high-magnitude cards saturate their ceiling early and mastery investment on them primarily rewards *reliability* (the card behaves identically across a wider range of future rebalances) rather than *further growth*. If this feels anticlimactic in playtesting, lower "Reckless Onslaught"'s `base_modifier_value` to ~1.4 so mastery tiers 1–4 remain visibly meaningful.

---

#### F5 — Rune Bonus Aggregate (additive, permanent, applied last)

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `rune_bonus_flat` | `r_i` | float | 0.02–0.10 per rune | Fixed value baked into each rune definition (roughly half of its linked card's Tier-0 `base_modifier_value`'s *marginal* effect — a design guideline, not a formula) |
| `discovered_runes_for_type` | `M` | int | 0–5 | Count of currently-`DISCOVERED` runes whose linked card targets this `modifier_type` |
| `rune_reward_bonus` / `rune_speed_bonus` | `rb` | float | `[0.00, 0.30]` | Total additive rune-layer contribution for this `modifier_type`, this mission |

**Expression:**
```
rune_bonus_total(modifier_type) = clamp(Σ(rune_bonus_flat_i) for all DISCOVERED runes linked to a card targeting modifier_type, 0.00, 0.30)
```

**Output range:** Clamped `[0.00, 0.30]` — additive stacking across multiple discovered runes of the same `modifier_type` is intentional (rewards long-run mastery breadth), but capped so 5+ discovered runes of the same type cannot alone approach the F2/F4 multiplicative ceilings.

**Worked example:** Two runes discovered, both linked to `tarot_reward_scalar_mult` cards, `rune_bonus_flat = 0.05` each → `rune_reward_bonus = clamp(0.05 + 0.05, 0, 0.30) = 0.10`, added into F3's `wave_reward_scalar_final` computation.

---

#### F6 — Mastery Tier Lookup

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `mastery_missions_played` | `p` | int | 0–unbounded | Cumulative counter (Rule 10) |
| `mastery_tier` | `t` | int | 0–4 | Derived tier |

**Expression:**
```
mastery_tier = max { t ∈ {0,1,2,3,4} : p ≥ threshold[t] }
threshold = {0: 0, 1: 3, 2: 8, 3: 15, 4: 25}
```

**Output range:** `0–4`, monotonic non-decreasing in `p`; terminal at 4 (no further tiers, no decay).

**Worked example:** `p = 10` → satisfies `threshold[2]=8` but not `threshold[3]=15` → `mastery_tier = 2` (Adept).

## Edge Cases

- **EC-1 — If a deck has 0 cards equipped at `mission_launched`:** Tarot emits zero `mission_modifier_applied` events at SCOUT entry. Wave Manager's `WaveConfig` and F1 output are used unmodified (Mission-Select modifiers still apply per Rule 8 step 1, since Tarot contributes nothing). `tarot_speed_scalar` remains at its registered default `1.0`. The mission launches cleanly — this is not an error state. **Previously-discovered rune bonuses (Rule 16) still apply**, since runes are permanent and independent of current deck composition — a 0-card deck is not a 0-modifier mission if the player has discovered runes from prior playthrough progress.

- **EC-2 — If an aggregate modifier would push `tarot_speed_scalar` outside `[0.50, 2.00]`:** Clamp at the boundary (Formula F2/F4). Log a warning: `"tarot_speed_scalar aggregate [raw value] clamped to [0.50|2.00] — equipped cards: [list of source_card_id]."` The mission proceeds with the clamped value; no error, no mission-launch block.

- **EC-3 — If two equipped cards both target the same `modifier_type`:** For MULTIPLICATIVE types (`tarot_speed_scalar_mult`, `tarot_reward_scalar_mult`): both apply, multiplicatively (Formula F2) — this is intended stacking, not a conflict. For REPLACE types (`tarot_difficulty_growth_rate`, `tarot_wave_config_override`): only one may be equipped — enforced by the Tarot Deck UI at equip-time (validation, not runtime). If violated anyway (data error): the lowest deck-slot-index card wins, the rest are discarded with a logged warning (see Formula F2's stacking rule for exact log text).

- **EC-4 — If a card is discovered (unlocked) mid-mission:** Structurally impossible. `_active_mission_deck` is locked at `mission_launched` (Rule 5) and Sanctuary — the only place card unlocks or deck edits occur — is not reachable during a mission (per game-concept.md's phase model, SANCTUARY is a separate top-level state entered only from MISSION_COMPLETE/DEFEAT). No runtime guard is needed; this is a structural guarantee, not a defensive check.

- **EC-5 — If a mission ends in DEFEAT:** Mastery XP still accrues normally (`mastery_missions_played += 1` for every equipped card, Rule 10) and rune discovery still fires if this is a card's first mission attempt (Rule 15). **Rationale:** game-concept.md's DEFEAT transition states "Sanctuary progress fully preserved" — this document treats card mastery and rune discovery as Sanctuary-scoped meta-progress (identical category to Crafting recipe discovery or Constellation pattern discovery), not mission-scoped combat progress, so it follows the same persists-through-defeat rule. A player who brings an unproven card into a mission and loses still gets credit for having fielded it.

- **EC-6 — If a `tarot_wave_config_override` card's target `WaveConfig` variant does not exist for the current `mission_id`, or is otherwise invalid:** Wave Manager discards the override, logs a content error (`"tarot_wave_config_override targeting [variant_id] has no valid alternate WaveConfig for mission [mission_id] — using mission's default WaveConfig."`), and proceeds with the mission's originally-authored `WaveConfig` unmodified. This mirrors wave-manager.md's own established pattern for content-authoring errors (EC-6, EC-11 in that document) — log and gracefully degrade, never crash or block mission launch.

- **EC-7 — If multiple discovered runes target the same `modifier_type`:** Additive stacking (Formula F5), clamped to `[0.00, 0.30]` total for that `modifier_type`. Consistent with Constellation's own additive-stacking precedent for overlapping pattern bonuses (constellation.md Core Rule 6).

- **EC-8 — If a card's linked rune is already `DISCOVERED` and the card is also currently equipped:** Both apply — the card's own mastery-scaled multiplicative/replace effect (Group 3) **and** the rune's fixed additive bonus (Formula F5) stack on top of each other (Rule 8's ordering: cards resolve, then runes resolve on top). This "double-dipping" is intentional — it is the reward for having proven a card out AND choosing to keep running it, not a balance oversight.

- **EC-9 — If a player unequips a card whose rune was already `DISCOVERED`, then never re-equips it:** The rune's bonus (Formula F5) continues to apply every mission regardless — discovery is permanent and deck-composition-independent by design (Rule 14). Unequipping only removes the card's own Group 3 effect; it cannot "undiscover" a rune.

## Dependencies

### Upstream — Systems the Tarot System depends on

| System | What Tarot needs from it | How |
|--------|---------------------------|-----|
| **EventBus** | `mission_launched`, `mission_phase_changed`, `run_modifier_selected` subscriptions; emits `mission_modifier_applied`, `tarot_rune_discovered`, `tarot_deck_changed` | EventBus signal (frozen contract, `event-bus.md`) |
| **Wave Manager** | `WaveConfig` schema (`difficulty_growth_rate`, `wave_scripts`) and F1's `wave_reward_scalar` output shape — Tarot's F3/F4 formulas are extensions of, not replacements for, Wave Manager's own math | Read-only design dependency (no direct API call — all interaction is via EventBus) |
| **Monster System / Registry** | The registered `tarot_speed_scalar` constant's exact name, default, and range (`design/registry/entities.yaml`) — Tarot must not diverge from this | Registry reference |
| **Damage & Status Registry** | The registered `hero_damage_bonus_multiplier` constant — Tarot must not define a competing hero-damage modifier (Rule 9) | Registry reference (read-only constraint) |
| **Save & Persistence** | `register(ref, restore_order=22)`, `get_save_data()`/`restore_save_data()`/`reset_to_defaults()` three-function interface | Direct API call per save-persistence.md's hybrid pattern |
| **Defense Building** (card unlock source, resolved 2026-08-12) | `is_tech_unlocked(tech_id)` — read-only, checked live (no caching) against each card's own `unlock_tech_id` field | Direct API call, same pull-based pattern Crafting uses for recipe tech-gates (`crafting.md`'s `tech_unlocked` dependency) |

### Downstream — Systems that depend on the Tarot System

| System | What it needs from Tarot | How |
|--------|----------------------------|-----|
| **Wave Manager** | `mission_modifier_applied` for `tarot_reward_scalar_mult`, `tarot_difficulty_growth_rate`, `tarot_wave_config_override` | EventBus subscription |
| **Monster System** | `mission_modifier_applied` for `tarot_speed_scalar_mult` | EventBus subscription |
| **Encyclopedia** | `tarot_rune_discovered` | EventBus subscription |
| **Equipment Forge** | `tarot_rune_discovered` | EventBus subscription |
| **Save & Persistence** | `tarot_deck_changed` (also drives its own save-trigger table); deck composition + mastery via the three-function interface | EventBus + direct API |
| **Tarot Deck UI** | `tarot_deck_changed`; read-only access to `run_modifier_selected` conflict state (Rule 8) | EventBus |
| **Building Upgrade** (new, 2026-08-11) | `is_card_unlocked(card_id)` — read-only, checked as one of `building-upgrade.md`'s 4 requirement category types; never mutates Tarot state | Direct API call |

## Tuning Knobs

| Parameter | Default | Safe Range | Too High | Too Low |
|-----------|---------|-----------|----------|---------|
| `TAROT_DECK_SLOT_COUNT` | 5 | 3–7 | Deck-building decisions dilute into "equip everything unlocked," undermining the "handful of meaningful choices" fantasy | Below 3: not enough room to express a build identity or a risk/reward dual-edge card alongside a safety pick |
| `mastery_missions_played` tier thresholds | `{0, 3, 8, 15, 25}` | Spacing 1.5–2.5× per tier | Tighter spacing: mastery tiers blur together, each promotion feels unearned | Wider spacing: Master tier (25 missions on one card) feels unreachable within Vertical Slice's expected playtime, discouraging card loyalty |
| `mastery_tier_scalar` ladder | `{1.00, 1.15, 1.30, 1.50, 1.75}` | Final tier 1.5×–2.0× base | Above 2.0×: low-`base_modifier_value` cards can reach Tier-4 magnitudes that trivialize the aggregate ceiling clamp (F2), making mastery investment feel like the only relevant lever | Below 1.5×: Master tier doesn't feel meaningfully different from Novice, undermining the "Mastery-as-Vindication" pillar this system is supposed to serve |
| `tarot_speed_scalar_mult` per-card `base_modifier_value` | 0.60–1.75 (typical); up to 2.00 for a dedicated Legendary risk card | 0.50–2.00 (registry hard bound) | A single card near 2.00 saturates the entire aggregate ceiling alone, making stacking with a second speed card pointless (see F4's saturation note) | Below 0.60: card is imperceptible next to natural wave-index speed growth (`speed_wave_growth_rate = 0.06`) |
| `tarot_reward_scalar_mult` per-card `base_modifier_value` | 0.60–1.75 (typical); up to 2.00 for a dedicated Legendary risk card | 0.50–2.00 | Same saturation risk as above, mirrored onto the reward side | Below 0.60: imperceptible against the natural F1 exponential curve at later waves |
| `tarot_difficulty_growth_rate` (REPLACE) card values | 0.10, 0.15, 0.25 (offer distinct named-identity cards at each interesting point in Wave Manager's own safe range) | `[0.10, 0.25]` — hard-clamped to Wave Manager's validated range | N/A — cannot exceed Wave Manager's own ceiling | N/A — cannot go below Wave Manager's own floor |
| `rune_bonus_flat` (per rune) | 0.05 | 0.02–0.10 | Above 0.10: a single discovered rune rivals a full equipped card's effect, cheapening the deck-building decision the card itself represents | Below 0.02: discovery reward is imperceptible, undermining the "vindication" fantasy of unlocking a rune |
| Total rune-bonus cap per `modifier_type` | 0.30 | 0.20–0.40 | Above 0.40: a player who has discovered many runes of one type can meaningfully approach the multiplicative ceiling using only permanent bonuses, devaluing active deck choices for that mission | Below 0.20: caps out after only 2–3 discovered runes, discouraging further rune-hunting investment in that `modifier_type` |
| `wave_reward_scalar_final` ceiling | 4.768 | Fixed — must equal wave-manager.md F1's own natural ceiling | N/A — raising this independently of Wave Manager/Resource Economy's `WAVE_ERI_CEILING_COMBINED` recalibration would silently break Resource Economy's drop-rate ceiling math | N/A — this is a ceiling, not a floor; no "too low" failure mode |

## Visual/Audio Requirements

**Deck-building screen — core visual language**

The deck-building screen is a UI panel, not a diorama scene (per the art bible's own distinction — cards are inert objects being arranged, not creatures being tended like Menagerie's habitat). It sits closer to Inventory/Crafting's panel language than to Menagerie's living-diorama language. However, the literal tarot-card motif is a gift from the "wizard's cabinet" anchor — a cabinet plausibly contains an actual tarot deck — so this screen earns one deliberate point of physicality that Inventory/Crafting's flat icon grid does not attempt:

- Cards render as tactile objects, not flat icons: each card sprite carries a subtle drop shadow (short, hard-edged, offset toward one consistent light direction — matching the Sanctuary's raking 45° interior light per art bible Sec 2.2) and a slight painted-card-stock texture (visible cardstock edge highlight, faint corner wear) rather than a clean vector icon frame. This is the screen's one register of "hand-carved diorama" physicality — it does not need stacked-sprite layering or cast-shadow-between-layers (that convention is for objects occupying 3D ground-plane space; a card lying on a table only needs to read as an object with slight thickness, not depth-stacked).
- The active deck slots render as a fixed row of carved wooden card-frames (a physical tray a wizard might use to hold a working spread), reusing the UI shape grammar's chamfered-rectangle-with-consistent-corner-radius language (art bible Sec 3.3) so the tray reads as "interface furniture," not world geometry. Empty slots show a shallow recessed silhouette (an empty groove in the tray) rather than a blank rectangle — communicates "a card belongs here" without needing a text label.
- The available card pool renders as a scrollable spread/fan beneath or beside the tray — cards overlap slightly (fanned, not gridded) to reinforce "this is a deck," while still snapping to a clear per-card hit-target for both mouse and gamepad selection. Overlap must never obscure a card's rarity/state frame (see below) — minimum visible margin around every card's edge.

**The SCOUT-phase modifier-resolution moment (`mission_modifier_applied`)**

This is the visible confirmation of "here is the risk you accepted for this run" and is comparable in weight to Constellation's rune-ignition, Crafting's unlock-cascade, and Menagerie's breeding reveal — it is Tarot's one reserved "big moment" beat:

- At SCOUT-phase start, the equipped deck's cards animate a quick sequential flip-reveal in tray order (each card flips face-up with a short arc, ~0.15-0.2s per card, staggered so a 3-7 card deck resolves in well under 2s total) — this is diegetically "the wizard reads the cards for this run," a natural fit for the literal tarot motif that Constellation's carved-rune-plate and Crafting's cascade-wipe don't have access to.
- As each card flips, its resolved modifier value briefly appears as a small non-blocking readout anchored to that card (e.g., "Monster Speed +15% / Material Drop +20%" for a risk/reward-coupled card) — paired values must render together, never just one side of the coupling, since the coupling itself is the point per the Core Rules framing.
- On full resolution, a brief summary strip persists at the edge of the SCOUT-phase HUD for the remainder of SCOUT (dismiss-on-advance, not auto-hiding) — this is the player's last chance to review the accepted risk before committing to launch, addressing the same "consequence must be visible before commitment" principle Crafting's craft-preview uses (see UI Requirements).
- No blocking modal, no bloom/glow dependency (per the Godot 4.6 constraint already flagged in every prior GDD) — the flip animation is sprite-driven (rotate + face-swap on a flat card sprite), the readout is standard UI text/iconography.

**Card state and mastery visual coding**

Two independent visual axes, deliberately kept separate so they never get confused: **lock state** (can the player use this card at all) and **mastery tier** (how proficient is the player with a card they already own). Per Sec 4.5 colorblind discipline, neither axis is color-only:

| Axis | States | Primary (shape/structure) cue | Secondary (color) cue |
|---|---|---|---|
| Lock state | Locked / Discovered (owned, unmastered) | Locked: card renders as a silhouette-only back-face (no art), lock-icon overlay (same glyph as Inventory's equipped-lock indicator, per established cross-system visual-language reuse). Discovered: full card art, face-up. | Locked: UI Disabled Grey (`#6B7280`) tint. Discovered: full color. |
| Mastery tier | Tier 0 (Novice, just discovered) → Tier 1 (Apprentice) → Tier 2 (Adept) → Tier 3 (Expert) → Tier 4 (Master) — **5 tiers, matching Core Rules Group 4's `mastery_tier` (0–4) and Formula F6** | A row of pip notches along the card frame's bottom edge (**4 pips total**, corrected 2026-07-17 from an earlier 3-pip draft that undercounted this axis — Tier 0 has zero filled pips, Tiers 1–4 each fill one additional pip); filled pip count = current tier. Pip shape/count is legible with color disabled. | Filled pips render in Herald Gold — a controlled reuse of the "exceptional/achievement" hue already extended to Crafting's Rare-tier frame; justified the same way (mastery progress is an achievement-register event, and Tarot's usage doesn't compete with gold's other reservations since it only appears on already-owned, in-hand cards, never ambiently). |

Card rarity as a separate data axis is out of scope for this pass (not established in Core Rules) — if systems-designer introduces card rarity tiers later, they must reuse Crafting's circle/hexagon/diamond frame-shape convention (Common/Uncommon/Rare) rather than inventing a new frame grammar, to keep the project's one shape-first rarity vocabulary singular.

**`tarot_rune_discovered` moment (permanent meta-progression milestone)**

Comparable weight to Constellation's rune-discovery and Crafting's unlock-cascade, and the tarot motif again gives this system a more literal version of the same beat than either predecessor had:

- A dedicated **card-flip reveal**, larger and slower than the routine SCOUT-phase resolution flip above (~1.5-2s, held ~2-3s after landing, dismissible early) — the discovered card flips up to reveal-scale (larger than its tray size, floating briefly center-screen) showing its full art, name, and a one-line hook toward its Encyclopedia/Equipment Forge unlock, mirroring Constellation's "carved-medallion reveal card" pattern but expressed through the system's own native object (a tarot card) rather than an imported medallion motif.
- Non-blocking (play continues if triggered mid-SCOUT or mid-Sanctuary), but must never fire more than once in a session without being clearly resolved first if a second rune discovers in quick succession — queue sequentially, never stack two reveal cards simultaneously (matches Crafting's "sum the count, don't stack the VFX" discipline for simultaneous triggers).
- Sprite/particle-driven only — a soft light-burst behind the card as it reveals (non-bloom, per the Godot 4.6 constraint flagged in every prior GDD), not a glow shader.

**Mastery-tier-up moment (routine, must not compete with rune discovery)**

- On a tier-up, the newly-filled pip on the card's frame plays a quick bright flash-and-settle (~0.4s), and the card itself does a small scale-pulse (1.1x, ease back to 1.0) in place within the tray/pool — no screen-level pause-beat, no reveal card, no center-screen floating. This is deliberately the smaller sibling of the rune-discovery beat: same gold hue (consistent "progress" language), much smaller scale and shorter duration, no dedicated modal-adjacent card.
- If a tier-up and a rune-discovery happen to fire from the same trigger event, the rune-discovery reveal takes visual priority and the tier-up flash plays underneath/after it, never simultaneously fighting for center-screen attention.

**Audio direction (category only, no audio bible yet)**

- SCOUT-phase resolution flip: a soft, dry card-flip foley per card (quick, non-fatiguing since it repeats 3-7 times per mission-start), with a slightly fuller closing "settle" tone once the summary strip locks in.
- Locked-card interaction attempt: soft negative-denial tone, same category as Crafting's tech-locked denial (not identical asset) — reinforces "this is the same kind of gate," per the project's existing cross-system audio-family convention.
- Mastery tier-up: a short, bright positive blip — smaller and quicker than the rune-discovery fanfare, must not use the same layered-chime patch to avoid the two milestones bleeding together in memory.
- `tarot_rune_discovered`: a fuller fanfare comparable in production weight to Constellation's discovery sting and Crafting's unlock-cascade chime, but built around a card-shuffle/reveal foley layer (distinct sonic signature) so a player can tell "which system" fired a milestone sting purely by ear.

## UI Requirements

**Deck-building screen layout**

- Two-region layout: **active deck tray** (fixed row, one slot per equipped card, 3-7 slots depending on current unlock progress) is the dominant/upper region; **available card pool** (fanned/scrollable spread, grouped by modifier category) is the secondary/lower region — mirrors Inventory/Crafting's "primary content dominant, supporting list secondary" convention.
- Mouse: drag-and-drop a card from the pool into an empty (or occupied, to swap) tray slot; dragging a tray card back to the pool unequips it. Dropping on an occupied slot swaps the two cards in place (no separate "remove first" step required).
- Gamepad/keyboard: **no drag-drop** (per the project's established gamepad model). Select-then-confirm instead: D-pad/left-stick moves a single selection cursor across pool and tray as one continuous 2D adjacency space (matching Crafting's "whole screen as one adjacency space" precedent) with wrap-at-edges; confirm on a pool card marks it "picked up" (persistent highlight, distinct from mere focus, matching Menagerie's focus-vs-selection distinction); a second confirm on a tray slot places it there (swapping out any existing card back to the pool). Canceling a pick-up is a single dedicated cancel/back action, not requiring re-selection.
- Shoulder buttons (LB/RB) cycle card pool categories (by modifier type), matching Inventory/Crafting/Menagerie's existing shoulder-button category-cycle convention.

**Card info display**

- At-a-glance (pool and tray, no drill-in): card name/icon, lock-state treatment, mastery pip row (if discovered), and a compact modifier glyph pair for risk/reward-coupled cards (e.g., a small dual icon showing "↑monster speed / ↑material drop" using existing semantic iconography, not new hues) — the coupling must be visible at a glance, since hiding it behind an inspect action would undercut the "understand your risk before committing" design intent.
- On inspect (hover/focus-and-hold, or a dedicated inspect button on gamepad — never hover-only, per the project's no-hover-only-interactions rule): full modifier text with exact values, full risk/reward coupling description in plain text (never icon-only at this tier), current mastery tier and progress toward the next tier, and discovery/Encyclopedia status.

**The SCOUT-phase confirmation flow — passive, not a gate**

The modifier-resolution beat (above) is **purely visible, not a confirmation gate**: it does not block or require player input to proceed. Reasoning:

- The actual commitment point for "which deck is equipped" already happened during Sanctuary deck-building, and the actual point-of-no-return for "launching this mission with this deck" belongs to the mission-launch flow (owned by Sanctuary/mission-flow systems, not Tarot) — Tarot's own resolution beat is downstream of both of those decisions, so gating it with a second confirmation would be a redundant third checkpoint for the same underlying decision.
- This mirrors Crafting's reasoning for its own single-confirm precedent (a prior deliberate step already exists; do not add a further "are you sure" for the same commitment) rather than Menagerie's sacrifice precedent (which requires a second confirmation specifically because no prior step captures that decision's full weight).
- The summary strip persists dismiss-on-advance (see Visual/Audio Requirements) precisely so the player is never rushed past the readout even though it isn't a hard gate — informational weight without interaction friction.

**Deck-editing confirmation step — none required (single-action, immediate)**

Deck editing (swapping cards in the Sanctuary tray) requires **no confirmation dialog of any kind** — not even Crafting's single-confirm-button pattern, since there isn't a discrete "commit this edit" action to begin with; a drag/drop or select-confirm-select-confirm swap simply applies immediately. Justification:

- Unlike Menagerie's sacrifice (permanent, non-fungible loss of a unique asset) or even Crafting's craft-confirm (consumes finite materials), swapping cards in a deck is fully reversible at zero cost, at any time, as many times as the player wants, right up until mission launch. There is no resource or state being spent by the edit itself.
- The real risk-bearing commitment is deferred entirely to mission launch (a separate system's action), which is exactly why the SCOUT-phase resolution beat above is passive rather than a gate — the "weight" the user's framing anticipates for this moment is real, but it belongs procedurally to mission-launch, not to either the edit action or the resolution readout. Tarot's own UI never needs a modal for either.
- If a future revision adds a genuinely irreversible deck-related action (e.g., permanently discarding an owned card rather than merely unequipping it), that specific action should adopt Menagerie's two-step confirmation convention on its own merits — this section's "no confirmation" ruling applies only to equip/unequip/swap.

**Gamepad navigation model**

- Consistent with Inventory/Crafting/Menagerie: D-pad/left-stick 2D adjacency across the combined pool+tray space, wrap-at-edges, shoulder-button category cycling, single confirm button for context-appropriate action (pick up / place / swap / open inspect).
- Confirm on a locked card opens a context tooltip explaining the unlock requirement (mirrors the established "confirm on a non-actionable target opens explanatory context" pattern from Inventory/Crafting/Menagerie) rather than doing nothing.
- Keyboard-only mirrors the same adjacency model (arrow keys / Tab-Shift+Tab), matching every prior system's stated keyboard parity requirement.

**Accessibility notes**

- Lock state and mastery tier are both shape/structure-first (silhouette-back-face + lock icon; pip-notch count) with color as confirmatory only — fully legible with color vision disabled, per art bible Sec 4.5.
- The risk/reward modifier coupling is always available as plain text on inspect, never icon-only at that tier, so the actual numeric trade-off is never gated behind color or iconography alone.
- Mastery-tier-up and rune-discovery use markedly different scale/duration/screen-placement (not just color) so the two milestone tiers remain distinguishable to players who cannot rely on the shared gold hue.
- No hover-only interactions anywhere on this screen (inspect is available via a dedicated gamepad button, not mouse-hover exclusively), consistent with the project's mandatory K/M + gamepad parity requirement.

## Acceptance Criteria

> **Test type key** (per QA story-type gate): **Logic** = automated unit test,
> BLOCKING · **Integration** = integration test or documented playtest,
> BLOCKING · **Config/Data** = smoke check, ADVISORY. All ACs below are Logic
> or Integration unless explicitly marked Config/Data.

### Group 1 — Card Data Model (Rules 1, 2, 2a)

- **AC-1** *(Config/Data)*: GIVEN a `TarotCardResource` loaded from
  `assets/data/tarot/`, WHEN its fields are inspected, THEN `card_id`,
  `rarity`, `unlocked`, `modifiers`, `linked_rune_id`, `mastery_tier`, and
  `mastery_missions_played` are all present with the types specified in
  Rule 1's table.
- **AC-2**: GIVEN any `TarotCardResource`, WHEN Tarot's own codepaths are
  exercised across a full deck-edit + mission lifecycle, THEN Tarot never
  *writes* to that card's `unlocked` state via `unlock_tech_id` — the
  Defense Building tech-gate half is resolved entirely by Defense Building's
  own `resolve_tech_unlock()`; Tarot's `is_card_unlocked()` only ever reads
  `GDefenseBuilding.is_tech_unlocked()`. The `_card_unlocked` runtime ledger
  remains a genuine write surface (a future non-tech unlock source, e.g.
  Encyclopedia purchase), unaffected by this resolution.
- **AC-3** *(Config/Data)*: GIVEN a card's `modifiers` array, WHEN content
  is validated pre-ship, THEN every entry's `modifier_type` is one of the
  four registered types (Rule 7's table) — a card authored with any other
  value fails content validation before it can be added to a deck pool.
- **AC-4** *(dual-edge coupling — emission level)*: GIVEN a dual-edge card
  ("Reckless Onslaught," Rule 2a) with both a `tarot_speed_scalar_mult` and
  a `tarot_reward_scalar_mult` entry, WHEN it is equipped and SCOUT entry
  resolves, THEN both entries emit as part of the same `mission_modifier_applied`
  batch for that card — the risk/reward pair never resolves with only one
  side present.

### Group 2 — Deck Model (Rules 3, 4, 5)

- **AC-5**: GIVEN a deck already at `TAROT_DECK_SLOT_COUNT` (5) equipped
  cards, WHEN the player attempts to equip a 6th, THEN the attempt is
  rejected and `tarot_deck_changed` does not fire.
- **AC-6**: GIVEN a card is equipped at SANCTUARY, WHEN the equip resolves,
  THEN `tarot_deck_changed(active_card_count)` fires immediately with the
  correct incremented count.
- **AC-7**: GIVEN a card is unequipped at SANCTUARY, WHEN the unequip
  resolves, THEN `tarot_deck_changed(active_card_count)` fires immediately
  with the correct decremented count.
- **AC-8**: GIVEN a deck of `[A, B, C]` at the moment `mission_launched`
  fires, WHEN Tarot receives it, THEN `_active_mission_deck` snapshots to
  exactly `[A, B, C]`, independent of any later Sanctuary-side deck state.
- **AC-9**: GIVEN `_active_mission_deck` is locked (post-`mission_launched`),
  WHEN a defensive deck-edit call is attempted against it mid-mission (e.g.
  a test harness simulating a future paused-Sanctuary path), THEN it has no
  effect on `_active_mission_deck` for the remainder of the mission.

### Group 3 — Modifier Resolution Protocol (Rules 6-9)

- **AC-10**: GIVEN `mission_phase_changed` transitions to SCOUT, WHEN Tarot
  processes it, THEN exactly one `mission_modifier_applied` fires per
  `TarotModifierEntry` across all equipped cards (a 5-card deck with one
  dual-edge card produces 6 events), synchronized to the same tick as Wave
  Manager Rule 8's SCOUT entry.
- **AC-11**: GIVEN a card's `base_modifier_value` and current `mastery_tier`,
  WHEN its `mission_modifier_applied` emits, THEN `modifier_value` equals
  Formula F1's mastery-scaled `effective_modifier_value` — the raw
  `base_modifier_value` is never emitted directly.
- **AC-12** *(proves MULTIPLICATIVE mechanism — `tarot_speed_scalar_mult`)*:
  GIVEN two equipped `tarot_speed_scalar_mult` cards with effective values
  `v_1 = 1.69` and `v_2 = 1.20`, WHEN Monster System aggregates them (F2/F4),
  THEN `aggregate_raw = 1.69 × 1.20 = 2.028` (a **product**, never a sum),
  clamped to `aggregate_final = 2.00`.
- **AC-13** *(proves MULTIPLICATIVE mechanism — `tarot_reward_scalar_mult`)*:
  GIVEN `wave_reward_scalar_natural = 1.44` and an aggregated
  `tarot_reward_multiplier = 2.00`, WHEN Wave Manager computes F3, THEN the
  natural scalar and the Tarot multiplier are combined by **multiplication**
  (`1.44 × 2.00`), with the rune's F5 bonus added only afterward — never a
  scheme where the Tarot layer is itself additive to the natural scalar.
- **AC-14** *(proves REPLACE mechanism — `tarot_difficulty_growth_rate`)*:
  GIVEN one equipped card targeting `tarot_difficulty_growth_rate` with
  value `0.25`, and the mission's authored `WaveConfig.difficulty_growth_rate`
  originally `0.20`, WHEN the modifier applies, THEN
  `difficulty_growth_rate` becomes exactly `0.25` — an absolute
  substitution, never `0.20 + 0.25` or `0.20 × 0.25`.
- **AC-15** *(proves REPLACE mechanism — `tarot_wave_config_override`)*:
  GIVEN one equipped card targeting `tarot_wave_config_override`
  referencing a valid, pre-authored alternate `WaveConfig` variant tagged
  for the current `mission_id`, WHEN the modifier applies, THEN the
  mission's entire `WaveConfig` resource is swapped wholesale for the
  variant — no field-by-field merge with the original occurs. **Content
  dependency flagged (qa-lead)**: not executable as a positive-path test
  today — per Rule 7's own Vertical-Slice scope-flag, no mission currently
  has an authored alternate `WaveConfig` variant. See Open Questions.
- **AC-16** *(REPLACE single-card-only enforcement, EC-3)*: GIVEN two
  equipped cards both target the same REPLACE-type `modifier_type`, WHEN
  the second equip is attempted via the Tarot Deck UI, THEN it is rejected
  at equip-time (validation, not a runtime clamp). GIVEN this constraint is
  bypassed anyway (simulated save-data corruption), WHEN the mission
  resolves, THEN only the lowest deck-slot-index card's value is applied,
  the rest are discarded, and the exact log text from Formula F2's stacking
  rule is emitted.
- **AC-17**: GIVEN active Mission Select run modifiers, equipped Tarot
  cards, and previously-discovered runes all target the same
  `modifier_type` for one mission, WHEN the mission resolves, THEN they
  apply in the exact order Rule 8 specifies: Mission Select first, Tarot
  per-card modifiers second (at SCOUT entry), Tarot rune bonuses third
  (last). **Cross-system dependency flagged (qa-lead)**: no
  `design/gdd/mission-select.md` exists yet (this GDD's own Dependencies
  section already flags this) — this AC is only testable today against a
  mock emitting `run_modifier_selected` per `event-bus.md`'s frozen payload
  shape, not against a real Mission Select system. See Open Questions.
- **AC-18** *(channel ownership — proves Tarot never emits on
  `run_modifier_selected`)*: GIVEN a full mission lifecycle (Sanctuary deck
  edit → `mission_launched` → SCOUT → mission end) with any number of
  equipped cards, WHEN every EventBus emission Tarot performs is recorded,
  THEN zero emissions occur on the `run_modifier_selected` channel — Tarot
  emits only `mission_modifier_applied`, `tarot_rune_discovered`, and
  `tarot_deck_changed`, and appears solely as a subscriber (never a sender)
  of `run_modifier_selected`. This is the AC that specifically corrects the
  documentation looseness in `wave-manager.md`'s Dependencies table, which
  lists "Tarot / Mission Select" together as senders.
- **AC-19**: GIVEN a Mission Select run modifier already targets a
  `modifier_type` a slotted card also targets, WHEN the Tarot Deck UI is
  open pre-launch, THEN a conflict indicator is surfaced from the read-only
  `run_modifier_selected` subscription — without Tarot altering its own
  resolution logic (which remains governed solely by Rule 8's fixed
  ordering). Same cross-system dependency flag as AC-17 applies.
- **AC-20** *(Config/Data, Rule 9)*: GIVEN Tarot's four registered
  `modifier_type` values, WHEN enumerated against the Damage & Status
  Registry's `hero_damage_bonus_multiplier`, THEN none of the four target
  hero damage — a content-validation check, not a runtime behavior.

### Group 4 — Mastery (Rules 10-12)

- **AC-21**: GIVEN an equipped card present in `_active_mission_deck` at
  mission end (`MISSION_COMPLETE`), WHEN the terminal
  `mission_phase_changed` fires, THEN that card's `mastery_missions_played`
  increments by exactly 1, exactly once.
- **AC-22** *(EC-5 — mastery/discovery persist through DEFEAT)*: GIVEN an
  equipped card present in `_active_mission_deck` at mission end
  (`DEFEAT`), WHEN the terminal `mission_phase_changed` fires, THEN that
  card's `mastery_missions_played` still increments by exactly 1 —
  byte-identical to the `MISSION_COMPLETE` case — and, if this is the
  card's first mission attempt while equipped, its linked rune still
  transitions `UNDISCOVERED → DISCOVERED` and `tarot_rune_discovered` still
  fires exactly once. This test must run both terminal states
  (`MISSION_COMPLETE` and `DEFEAT`) and assert identical mastery/discovery
  side effects, differing only in which phase value triggered them —
  mirroring `menagerie.md`'s precedent that Sanctuary-scoped meta-progress
  is not reversed by a losing mission outcome.
- **AC-23**: GIVEN a card NOT present in `_active_mission_deck` for a given
  mission, WHEN that mission ends (either outcome), THEN its
  `mastery_missions_played` does not change.
- **AC-24** *(F6 tier lookup)*: GIVEN `mastery_missions_played = 10`, WHEN
  `mastery_tier` is read, THEN it resolves to `2` (Adept) per F6's
  threshold table — and resolves identically whether read immediately after
  the increment or independently at a later time, since it is recomputed
  from the counter every time, never stored.
- **AC-25** *(F1 mastery scaling)*: GIVEN a `tarot_speed_scalar_mult` card
  with `base_modifier_value = 1.30` at `mastery_tier = 2` (`m = 1.30`),
  WHEN `effective_modifier_value` is computed at SCOUT entry, THEN it
  equals exactly `1.30 × 1.30 = 1.69`.
- **AC-26** *(Rule 12 — magnitude only)*: GIVEN a card's `mastery_tier`
  increases across missions, WHEN its `mission_modifier_applied` output is
  compared before and after the tier-up, THEN `modifier_type` is unchanged,
  no new modifier entry appears, and the card's deck-slot cost is unchanged.

### Group 5 — Card vs. Rune Distinction (Rules 13-16)

- **AC-27** *(Rule 13)*: GIVEN a card is unequipped, WHEN SCOUT entry
  resolves, THEN no `mission_modifier_applied` fires for that card's entries.
- **AC-28** *(Rules 14/15 — first discovery)*: GIVEN a card's linked rune is
  `UNDISCOVERED` and the card completes its first mission attempt while
  equipped, WHEN the terminal `mission_phase_changed` fires, THEN
  `tarot_rune_discovered(rune_id, card_id)` fires exactly once and the
  ledger transitions to `DISCOVERED` permanently.
- **AC-29** *(Rule 15 — one-time-only)*: GIVEN a rune already `DISCOVERED`,
  WHEN the same card completes further mission attempts (equipped or not),
  THEN `tarot_rune_discovered` does not fire again for that `rune_id`.
- **AC-30** *(Rule 16 / F5 — deck-independent)*: GIVEN a `DISCOVERED` rune
  whose linked card is NOT currently equipped, WHEN a mission resolves,
  THEN the rune's fixed additive bonus (F5) still applies to its
  `modifier_type`.
- **AC-31** *(EC-8 — intended double-dip)*: GIVEN a `DISCOVERED` rune whose
  linked card IS also currently equipped, WHEN a mission resolves, THEN
  both the card's own Group 3 effect and the rune's F5 additive bonus apply
  together — neither suppresses the other.

### Formulas

- **AC-32** *(F3 regression anchor)*: GIVEN wave 3, default `r = 0.20`, one
  Legendary "Reckless Onslaught" card solo-equipped at Tier 0, rune bonus
  `0.00`, WHEN `wave_reward_scalar_final` is computed, THEN it equals
  exactly `2.88` (matches the GDD's own worked example).
- **AC-33** *(F4 — dual-edge value coupling, complements AC-4's emission
  coupling)*: GIVEN "Reckless Onslaught" solo-equipped at Tier 0, WHEN both
  its speed and reward sides resolve at wave 1, THEN `tarot_speed_scalar =
  2.00` AND `wave_reward_scalar_final = 2.00` are both true in the same
  resolution pass — the doubling never appears on only one side.
- **AC-34** *(F5 — additive stacking and clamp)*: GIVEN two `DISCOVERED`
  runes both linked to `tarot_reward_scalar_mult` cards with
  `rune_bonus_flat = 0.05` each, WHEN `rune_reward_bonus` is computed, THEN
  it equals `clamp(0.10, 0.00, 0.30) = 0.10` exactly.
- **AC-35** *(F6, duplicate anchor for formula-section completeness — see
  also AC-24)*: GIVEN `mastery_missions_played` values of `0, 3, 8, 15, 25`,
  WHEN `mastery_tier` is computed for each, THEN the results are exactly
  `0, 1, 2, 3, 4` respectively — the threshold table's own boundary values
  resolve to the tier they newly unlock, not the prior tier.

### Edge Cases

- **AC-36** *(EC-1)*: GIVEN a deck with 0 cards equipped at
  `mission_launched`, WHEN SCOUT entry resolves, THEN zero
  `mission_modifier_applied` events fire, `tarot_speed_scalar` remains
  `1.0`, `WaveConfig`/F1 output is affected only by Mission Select
  modifiers (if any), and any previously-discovered rune bonuses still apply.
- **AC-37** *(EC-2)*: GIVEN an aggregate raw value outside `[0.50, 2.00]`
  for `tarot_speed_scalar`, WHEN it is clamped, THEN the mission proceeds
  with the clamped boundary value, a warning is logged listing every
  offending `source_card_id`, and no mission-launch block occurs.
- **AC-38** *(EC-6 — negative/fallback path)*: GIVEN a
  `tarot_wave_config_override` card whose target variant does not exist
  for the current `mission_id`, WHEN Wave Manager attempts to apply it,
  THEN the override is discarded, the specified content-error log fires,
  and the mission proceeds with its originally-authored `WaveConfig`
  unmodified — no crash, no launch block. **Content dependency flagged
  (qa-lead)**: only this negative/fallback path is currently testable; the
  corresponding positive path (AC-15) is blocked on the same missing
  content (no mission has an authored alternate `WaveConfig` variant yet).
- **AC-39** *(EC-9)*: GIVEN a card whose rune is `DISCOVERED` is later
  unequipped and never re-equipped, WHEN subsequent missions resolve, THEN
  the rune's F5 bonus continues to apply every mission, unaffected by the
  card's absence from the deck.

### State Tables

**Deck Lock Lifecycle:**

- **AC-40**: GIVEN `EDITABLE` state at SANCTUARY, WHEN `mission_launched`
  fires, THEN the state transitions to `LOCKED` and remains so for the
  mission's full duration regardless of any player input.
- **AC-41**: GIVEN `LOCKED` state, WHEN the mission ends (either
  `MISSION_COMPLETE` or `DEFEAT`), THEN the state returns to `EDITABLE` at
  SANCTUARY.

**Per-Card Mastery Progression:**

- **AC-42**: GIVEN a card at Tier 3 (`mastery_missions_played` in
  `[15, 24]`), WHEN `mastery_missions_played` crosses `25`, THEN
  `mastery_tier_scalar` transitions from `1.50` to `1.75` (Tier 4) and
  remains terminal — no further tier exists regardless of additional
  missions played.

**Rune Discovery Ledger:**

- **AC-43**: GIVEN the `UNDISCOVERED` default state at a fresh save or
  playthrough start, WHEN queried before any mission completes with that
  card equipped, THEN no rune effect applies and `tarot_rune_discovered`
  has not fired for that `rune_id`.
- **AC-44**: GIVEN a rune has entered `DISCOVERED`, WHEN the save is
  reloaded in a later session, THEN the ledger reads `DISCOVERED` for that
  `rune_id` — the transition is permanent and save-persisted
  (`restore_order = 22`), never reverting to `UNDISCOVERED`.

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| `tarot_wave_config_override` is fully specified mechanically (Rule 7, closes OQ-2's structural-override dimension) but has zero authored content | Mission / content pipeline owner | No mission currently has an alternate `WaveConfig` variant tagged for it. AC-15 (positive path) is blocked on this; only AC-38's negative/fallback path is testable today. Per Rule 7's own scope-flag, a card using this `modifier_type` should not ship until at least one mission has an authored variant. |
| Rune discovery bar — "any mission attempt" vs. "`MISSION_COMPLETE` only" | Tarot GDD owner (systems-designer) | Rule 15 explicitly flags this as its own most-swappable assumption. This document defaults to the permissive "any attempt" bar for consistency with Rule 10's mastery-accrual reasoning. If playtesting shows first-rune discovery happens too early, swap the discovery gate to `MISSION_COMPLETE`-only — AC-22/AC-28 would need to be re-parameterized (the `DEFEAT` half of AC-22's discovery assertion would no longer hold) but the mastery-XP half of AC-22 would be unaffected, since Rule 10 is a separate, unflagged rule. |
| No `design/gdd/mission-select.md` exists yet | Mission Select owner | Flagged already in this GDD's own Dependencies section, but surfaced here as an AC-level gap found during this review: AC-17 and AC-19 (resolution ordering against `run_modifier_selected`, and the Tarot Deck UI conflict indicator) are only testable today against a mock built from `event-bus.md`'s frozen payload shape (`modifier_id`, `modifier_value`), not against a real Mission Select system. If Mission Select's own GDD later adds structure to that payload, these two ACs should be revisited alongside the read-only subscription itself. |
| `wave-manager.md` itself still states OQ-2 as unresolved and its Dependencies table still lists "Tarot / Mission Select" together as `run_modifier_selected` senders | Wave Manager GDD owner | This GDD (Rule 8) resolves OQ-2 and asserts the correction (Tarot is a subscriber, never a sender, of `run_modifier_selected`), but `wave-manager.md`'s own file has not yet been edited to mark OQ-2 resolved or fix its Dependencies table row — same category of cross-doc follow-up as Inventory's `tower_component_returned` / EventBus catalogue gaps in prior sessions. Not done as part of this GDD to avoid scope creep into a separate document; flagged here so the follow-up isn't lost. |

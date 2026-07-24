# Story 001: Tarot Card & Deck Model

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tarot.md`
**Requirement**: `TR-tarot-001` (data model portion)

**ADR Governing Implementation**: ADR-0027 (Tarot Modifier Aggregation Pipeline)
**ADR Decision Summary**: `TarotCardResource` (static, immutable, `GameDataRegistry`-backed) is split from a new `TarotProgressLedger` (runtime, Tarot-owned, save-persisted) — resolving the GDD's own inconsistency where Rule 1 described mutable per-card state living directly on a shared boot-loaded Resource.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Reuses ADR-0009's `GameDataRegistry` convention, ADR-0023's Discovery-Ledger pattern, ADR-0001's EventBus dispatch. No new engine subsystem.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0027/ADR-0009 directly.
- Forbidden: Never store mutable per-playthrough state (`mastery_missions_played`, rune discovery, card unlock status) directly on the shared `TarotCardResource` instance — violates ADR-0003's `resource_object_in_save_data` forbidden pattern.
- Guardrail: `mastery_tier` must never be independently stored — always recomputed from `_mastery_missions_played` via Formula F6, preserving "no tier-desync risk."

---

## Acceptance Criteria

*From GDD `design/gdd/tarot.md`, scoped to this story:*

- [x] AC-1 *(Config/Data)* — `TarotCardResource` fields present with correct types — **resolved per ADR-0027's own Implementation Notes code sketch**: `unlocked`/`mastery_tier`/`mastery_missions_played` are deliberately NOT fields on this Resource (they'd violate ADR-0003's `resource_object_in_save_data` forbidden pattern); they live on `Tarot`'s runtime `_card_unlocked` ledger slice instead. `card_id`/`rarity`/`modifiers`/`linked_rune_id` are present with correct types.
- [x] AC-2 — Tarot never writes to a card's `unlocked` field, only reads it *(interface dependency flagged — see Open Questions below)*
- [x] AC-3 *(Config/Data)* — every `modifiers` entry's `modifier_type` is one of the 4 registered types, validated pre-ship
- [x] AC-4 *(data-model level only — full emission-batch behavior is Story 002's own scope)* — a dual-edge card's `modifiers` array correctly carries both entries; the resolution-pipeline emission itself is Story 002's concern
- [x] AC-5 — equipping a 6th card when the deck is already at `TAROT_DECK_SLOT_COUNT` (5) is rejected, `tarot_deck_changed` does not fire
- [x] AC-6 — equipping a card fires `tarot_deck_changed(active_card_count)` immediately with the correct incremented count
- [x] AC-7 — unequipping a card fires `tarot_deck_changed(active_card_count)` immediately with the correct decremented count
- [x] AC-8 — `mission_launched` snapshots the current deck into `_active_mission_deck`, independent of later Sanctuary-side deck state
- [x] AC-9 — a defensive deck-edit call against a locked `_active_mission_deck` has no effect for the remainder of the mission

---

## Implementation Notes

*Derived from ADR-0027 Implementation Guidelines:*

```gdscript
# TarotCardResource (assets/data/tarot/*.tres, loaded by GameDataRegistry)
class_name TarotCardResource extends Resource
@export var card_id: StringName = &""
@export var rarity: String = "Common"          # Common | Rare | Legendary
@export var modifiers: Array[TarotModifierEntry] = []   # 1-2 entries
@export var linked_rune_id: StringName = &""
func validate() -> Array[String]: ...          # confirms modifier_type in Rule 7's 4 registered types

# TarotModifierEntry (nested Resource, not a top-level GameDataRegistry entry)
class_name TarotModifierEntry extends Resource
@export var modifier_type: StringName = &""
@export var base_modifier_value: float = 1.0
```

- `TarotProgressLedger` (runtime, Tarot-owned): `_mastery_missions_played: Dictionary[StringName, int]`, `_rune_discovered: Dictionary[StringName, bool]`, `_card_unlocked: Dictionary[StringName, bool]` (read-only from Tarot's own logic — the write side is an explicitly unresolved external dependency, see Open Questions).
- Deck lock (Rule 5): on `mission_launched`, copy the current deck into `_active_mission_deck: Array[StringName]` — immutable for the mission's full duration. This is a defensive boundary; no runtime deck-editing path exists mid-mission per game-concept.md's phase model.
- `TAROT_DECK_SLOT_COUNT` default 5, safe range 3–7 — equip attempts beyond this count must be rejected before `tarot_deck_changed` fires.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the SCOUT-entry modifier resolution/emission pipeline itself
- Story 003/004: mastery accrual and rune discovery logic (this story only establishes the ledger's shape)
- Story 007: `SaveRestorer` persistence of the ledger

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-1**: Field presence and types *(Config/Data)*
  - Given: a `TarotCardResource` loaded from `assets/data/tarot/`
  - When: fields are inspected
  - Then: `card_id`, `rarity`, `unlocked`, `modifiers`, `linked_rune_id`, `mastery_tier`, `mastery_missions_played` all present with Rule 1's specified types

- **AC-2**: Read-only `unlocked` behavior
  - Given: any `TarotCardResource`
  - When: Tarot's own codepaths are exercised across a full deck-edit + mission lifecycle
  - Then: Tarot never writes to `unlocked` — only reads it
  - Edge cases: this AC can only verify the read side; the setter side is unresolved (see Open Questions)

- **AC-3**: Content validation *(Config/Data)*
  - Given: a card's `modifiers` array
  - When: content is validated pre-ship
  - Then: every entry's `modifier_type` is one of the 4 registered types; any other value fails validation before the card can enter a deck pool

- **AC-4**: Dual-edge coupling at emission level
  - Given: a dual-edge card ("Reckless Onslaught") with both a `tarot_speed_scalar_mult` and a `tarot_reward_scalar_mult` entry
  - When: it is equipped and SCOUT entry resolves
  - Then: both entries emit as part of the same batch for that card — never only one side

- **AC-5**: Deck slot cap enforced
  - Given: a deck already at 5 equipped cards
  - When: the player attempts to equip a 6th
  - Then: rejected, `tarot_deck_changed` does not fire

- **AC-6**: Equip fires event with correct count
  - Given: a card equipped at SANCTUARY
  - When: the equip resolves
  - Then: `tarot_deck_changed(active_card_count)` fires immediately with correct incremented count

- **AC-7**: Unequip fires event with correct count
  - Given: a card unequipped at SANCTUARY
  - When: the unequip resolves
  - Then: `tarot_deck_changed(active_card_count)` fires immediately with correct decremented count

- **AC-8**: Deck lock snapshot
  - Given: a deck of `[A, B, C]` at the moment `mission_launched` fires
  - When: Tarot receives it
  - Then: `_active_mission_deck` snapshots to exactly `[A, B, C]`, independent of any later Sanctuary-side deck state

- **AC-9**: Locked deck resists mid-mission edits
  - Given: `_active_mission_deck` is locked (post-`mission_launched`)
  - When: a defensive deck-edit call is attempted mid-mission
  - Then: no effect on `_active_mission_deck` for the remainder of the mission

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/tarot/card-deck-model_test.gd` — 15 tests covering AC-1/2/3/4(data-model)/5/6/7/8/9. All passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1133/1134 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: None (foundational story for this system)
- Unlocks: Story 002, Story 003, Story 004

**Unblocked**: ADR-0027 accepted 2026-07-18 (Sprint 6, S6-03). **Remaining open item, not blocking**: AC-2's setter side — no GDD currently owns "how a Tarot card becomes unlocked" (Defense Building tech tree vs. Encyclopedia purchase, undecided per `tarot.md`'s Open Questions) — this does not block AC-2's read-only verification, but any story requiring real card unlocking (rather than a test-seeded `true` flag) is blocked until this is resolved elsewhere.

**Implemented (2026-07-19, Sprint 7)**: built from scratch — this was a genuinely new system, unlike Epic 06's later Constellation stories where production code already existed. Created `src/core/tarot/tarot_modifier_entry.gd` (`TarotModifierEntry`, nested Resource with the 4 registered `modifier_type` constants), `src/core/tarot/tarot_card_resource.gd` (`TarotCardResource`, matching ADR-0027's Implementation Notes code sketch exactly — `card_id`/`rarity`/`modifiers`/`linked_rune_id` only, with `validate()` following `TowerBlueprintData`'s bool+push_error convention), and `src/core/tarot/tarot.gd` (`Tarot`, scene-instanced: `equip_card()`/`unequip_card()` with slot-cap + unlocked-gate enforcement, `tarot_deck_changed` emission, and the `mission_launched` deck-lock snapshot via `.duplicate()`). Wired `GameDataRegistry` to load `assets/data/tarot/*.tres` (new `_load_tarot_cards()`, `get_tarot_card()`/`get_all_tarot_cards()`, appended `tarot_cards_dir` as a new trailing `_inject()` parameter — backward-compatible with all 13 existing call sites since it has a default). Authored 2 real content files: `card_iron_resolve.tres` (single-modifier) and `card_reckless_onslaught.tres` (the GDD's own dual-edge worked example, `tarot_speed_scalar_mult` + `tarot_reward_scalar_mult`). New test file (15 tests). Live-verified via gdUnit4: 15/15 new tests passing; full regression 1133/1134 (same pre-existing unrelated `TD-menag-006` failure).

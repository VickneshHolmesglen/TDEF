# ADR-0027: Tarot Modifier Aggregation Pipeline

## Status
Accepted

## Acceptance Note
Accepted 2026-07-18 (Sprint 6, S6-03) by explicit user decision, outside the normal `/architecture-review` gate — same precedent as Epic 05's batch acceptance and ADR-0022/ADR-0029's Sprint 6 S6-02 acceptance. Lightweight manual cross-check: all 4 dependency ADRs (0001, 0009, 0012, 0023) confirmed `Accepted`; `restore_order=22` confirmed collision-free against the full authoritative table (10, 11, 20, 21, 24, 30, 31, 32, 34). Unblocks Epic 07's Tarot stories (001–007) — flips them `Blocked` → `Ready`. An independent `/architecture-review` pass in a fresh session is still recommended before Epic 07's next milestone.

## Date
2026-07-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Cross-system communication / Data Structures |
| **Knowledge Risk** | LOW — reuses ADR-0009's `GameDataRegistry` convention, ADR-0023's Discovery-Ledger pattern, and ADR-0001's EventBus dispatch. No new engine subsystem. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0009 (Resource Data Model); ADR-0023 (Crafting recipe data model — Discovery-Ledger precedent); ADR-0001 (EventBus architecture — synchronous dispatch, ≤4-field/Resource-subclass payload rule) |
| **Post-Cutoff APIs Used** | Typed `Dictionary[StringName, int]`/`Dictionary[StringName, bool]` (4.4+, already verified working) |
| **Verification Required** | None beyond what `VERSION.md` already confirms for typed Dictionaries |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (Resource Data Model), ADR-0001 (EventBus architecture — `mission_modifier_applied`'s existing frozen Resource-subclass-or-typed-payload contract), ADR-0023 (Crafting recipe data model — Discovery-Ledger pattern this ADR's rune ledger and mastery ledger both follow), ADR-0012 (Wave Manager FSM — `mission_launched` always completes before `mission_phase_changed(SCOUT)` fires, the ordering guarantee this ADR's emission pipeline relies on) |
| **Enables** | `design/gdd/tarot.md` implementation stories (currently blocked pending this ADR) |
| **Blocks** | None further downstream — Wave Manager and Monster System (both already-Accepted, shipped Foundation/Core systems) are the consumers of `mission_modifier_applied`'s per-card values and perform their own F2-stage aggregation independently; this ADR does not gate their implementation, only Tarot's own emission-side logic |
| **Ordering Note** | `restore_order = 22` (already assigned in `save-persistence.md`) has no ordering dependency on this session's other new ADRs — nothing reads Tarot's state during another system's `restore_save_data()` (unlike Crafting's boot sweep, ADR-0023, or Equipment Forge, ADR-0025, which both read Defense Building/Tarot's *already-restored* state at a *later* `restore_order`, not during their own restore). Equipment Forge's `restore_order = 32` already accounts for restoring after Tarot's 22. |

## Context

### Problem Statement

`design/gdd/tarot.md` is mechanically complete — six formulas (F1–F6), a fully-specified 4-type modifier resolution protocol, and an explicit "channel ownership" resolution closing `wave-manager.md`'s Open Question OQ-2 — but has no ADR covering the `TarotCardResource` data model or, more importantly, an inconsistency in how the GDD's own prose describes mutable per-card state. Rule 1 lists `mastery_tier`, `mastery_missions_played`, and `unlocked` as fields directly on `TarotCardResource`, annotated "save-persisted per card instance" — but every other data-driven Resource in this project (`MonsterResource`, `RecipeResource`, `TechNodeResource`, ADR-0009/0023/0024's own established convention) is a boot-loaded, `GameDataRegistry`-shared, **immutable** definition. Mutating a shared, boot-loaded Resource instance at runtime would violate the `resource_object_in_save_data` forbidden pattern (ADR-0003) the moment that mutable state needs to be persisted, and risks aliasing bugs if the same `TarotCardResource` instance is ever referenced from more than one place. This ADR resolves that inconsistency and specifies the actual runtime architecture behind it.

**Naming clarification**: despite this ADR's title (matching the architecture review's own naming), Tarot does **not** perform the GDD's F2-stage aggregation itself — per `tarot.md`'s own Interactions table, Monster System aggregates `tarot_speed_scalar_mult` and Wave Manager aggregates the other three types, each independently, from the per-card `mission_modifier_applied` events Tarot emits. Tarot's own responsibility, precisely scoped, is **F1** (per-card mastery scaling before emission) plus the mastery/discovery ledgers F1 and F6 read from — this ADR covers exactly that scope, not the downstream F2/F3/F4 aggregation logic that belongs to Wave Manager's and Monster System's own (already-Accepted) ADRs.

### Constraints

- `TarotCardResource` must follow ADR-0009's convention: boot-loaded via `GameDataRegistry`, immutable, shared, validated via `validate()`.
- Mutable per-playthrough state (`mastery_missions_played`, rune discovery, card unlock status) must **not** live on the shared Resource instance — must be tracked in a separate, Tarot-owned runtime ledger, mirroring the Discovery-Ledger pattern ADR-0023/ADR-0022 already established.
- `mastery_tier` (0–4) must never be independently stored — Rule 11 is explicit that it is "recomputed from the counter every time it is read, so there is no tier-desync risk." This ADR must preserve that guarantee architecturally, not just as a convention.
- Per Rule 6, mastery scaling (F1) happens **before** emission — subscribers must never see raw `base_modifier_value`. This is Tarot's emission-time responsibility, not something deferred to consumers.
- Per Rule 8's "channel ownership" resolution: Tarot must never emit through `run_modifier_selected` — it only subscribes to it, read-only, for UI conflict-awareness. This ADR must not introduce any code path that emits on that channel.
- Card unlock (`unlocked: bool`) is explicitly external — "Set by an external system; Tarot never sets this itself" — and the GDD itself flags that no system currently owns setting it. This ADR specifies the read-side data structure but does not invent the setter, consistent with how ADR-0025 left Menagerie's Autoload status flagged rather than fabricated (though here, unlike that case, no sibling ADR is currently positioned to resolve it — this ADR states it as an accepted open dependency, per the GDD's own explicit framing).

### Requirements

- `TarotCardResource` fields (Rule 1, static portion only): `card_id`, `rarity`, `modifiers: Array[TarotModifierEntry]`, `linked_rune_id`.
- Runtime `TarotProgressLedger` (Tarot-owned, save-persisted): per-card `mastery_missions_played: int` counter, per-`linked_rune_id` discovery `bool`, per-card `unlocked: bool` (read-only from Tarot's perspective, written by an as-yet-unspecified external system).
- Deck lock snapshot (Rule 5): `_active_mission_deck: Array[StringName]`, captured at `mission_launched`, immutable for the mission's duration.
- Emission pipeline (Rule 6/Formula F1): on `mission_phase_changed → SCOUT`, iterate `_active_mission_deck`, look up each card's current `mastery_tier` (derived via F6 from the ledger's counter), apply F1 scaling per modifier entry, emit one `mission_modifier_applied` per entry.
- Mastery accrual (Rule 10) and rune discovery (Rule 15) both trigger on mission-terminal `mission_phase_changed` (→ MISSION_COMPLETE or → DEFEAT), for every card that was in `_active_mission_deck`.

## Decision

**Split `TarotCardResource` (static, immutable, `GameDataRegistry`-backed) from a new `TarotProgressLedger` (runtime, Tarot-owned, save-persisted)** — resolving the GDD-level inconsistency identified above. This mirrors the exact static-vs-runtime split ADR-0016 established for `ItemDefinitionResource`/`InventorySlot` and ADR-0023 established for `RecipeResource`/Discovery Ledger.

**`TarotCardResource`** (static content data): `card_id: StringName`, `rarity: String` (`"Common"`/`"Rare"`/`"Legendary"`), `modifiers: Array[TarotModifierEntry]` (1–2 entries), `linked_rune_id: StringName`. Loaded at boot via `GameDataRegistry`, validated via `validate()` (confirms `modifiers` entries use one of the 4 registered `modifier_type` values, per Rule 7's table — directly implements AC-3's content-validation requirement).

**`TarotProgressLedger`** (runtime, Tarot-owned, three `Dictionary[StringName, ...]` structures keyed by `card_id`/`linked_rune_id`):
- `_mastery_missions_played: Dictionary[StringName, int]` — `card_id -> count`. `mastery_tier` is **never stored** — computed on every read via Formula F6's threshold lookup against this counter, preserving Rule 11's "no tier-desync risk" guarantee structurally (there is no second value that could desync from the counter, because no second value exists).
- `_rune_discovered: Dictionary[StringName, bool]` — `linked_rune_id -> discovered`. Identical shape and one-way-terminal semantics to Constellation's (ADR-0022) and Crafting's (ADR-0023) Discovery Ledgers.
- `_card_unlocked: Dictionary[StringName, bool]` — `card_id -> unlocked`. **Read-only from Tarot's own logic** (every check against `unlocked` in Tarot's resolution/deck-editing code reads this structure, never writes it) — the write side is an explicitly unresolved external dependency (see Risks), consistent with the GDD's own "no GDD currently owns how a card becomes unlocked" framing (Open Questions).

All three are covered by one `SaveRestorer` implementation, `restore_order = 22` (already assigned in `save-persistence.md`), alongside `_active_mission_deck`'s **template** (the Sanctuary-time equipped list — not the mission-locked snapshot, which is ephemeral runtime-only state that does not need to survive a save, per Rule 5's own framing that the snapshot exists only as a mid-mission defensive boundary).

**Emission pipeline** (Rule 6, Formula F1): a single method, `_resolve_scout_modifiers()`, invoked on `mission_phase_changed → SCOUT`. For each `card_id` in `_active_mission_deck`: look up `mastery_tier = _lookup_mastery_tier(card_id)` (F6, reading `_mastery_missions_played`), then for each `TarotModifierEntry` in that card's `TarotCardResource.modifiers`: compute `effective_modifier_value = base_modifier_value × mastery_tier_scalar[mastery_tier]` (F1) and emit `mission_modifier_applied(modifier_type, effective_modifier_value, source_card_id=card_id)`. This method performs **no F2-stage aggregation or clamping** — per the Naming Clarification above, that is Wave Manager's/Monster System's own responsibility as consumers.

**Mastery/discovery accrual** (Rules 10/15): a single method, `_on_mission_terminal(outcome)`, invoked on `mission_phase_changed → MISSION_COMPLETE` or `→ DEFEAT` (both trigger identically, per Rule 10/EC-5's explicit no-outcome-gate). For each `card_id` in `_active_mission_deck`: increment `_mastery_missions_played[card_id]`; if this is the card's first-ever mission attempt (i.e., the counter was `0` before this increment) and `_rune_discovered[card.linked_rune_id]` is not yet `true`, set it `true` and emit `tarot_rune_discovered(rune_id, card_id)`.

### Architecture Diagram

```
GameDataRegistry (Autoload, boot position 5)
  └─ preloads TarotCardResource[] from assets/data/tarot/
       validate() called per card at boot (ADR-0009 contract)

Tarot (scene-instanced node, Sanctuary-only for deck editing; active
       during missions for SCOUT-entry resolution and terminal accrual —
       nothing calls INTO Tarot directly, so it needs no Autoload status)
  ├─ owns: _mastery_missions_played: Dictionary[StringName, int]
  ├─ owns: _rune_discovered: Dictionary[StringName, bool]
  ├─ owns: _card_unlocked: Dictionary[StringName, bool]         # read-only; external writer TBD
  ├─ owns: _active_mission_deck: Array[StringName]              # mission-locked snapshot, NOT persisted
  ├─ owns: _deck_template: Array[StringName]                    # Sanctuary-time equipped list, persisted
  ├─ implements SaveRestorer:
  │    get_save_key() -> "tarot"
  │    get_save_data() -> Dictionary (primitives only — 3 ledgers + deck template)
  │    restore_save_data(data) -> bool
  │    reset_to_defaults() -> void
  ├─ registers: SavePersistence.register(self, restore_order=22)
  ├─ reads: GameDataRegistry.get_tarot_card(card_id) -> TarotCardResource
  ├─ subscribes (EventBus): mission_launched (lock deck snapshot), mission_phase_changed
  │    (SCOUT entry → resolve modifiers; terminal → accrue mastery/discovery),
  │    run_modifier_selected (read-only, UI conflict-awareness only)
  └─ emits (EventBus): mission_modifier_applied (per card, per entry, F1-scaled),
       tarot_rune_discovered (first discovery only), tarot_deck_changed (Sanctuary edits)
```

### Key Interfaces

```gdscript
# TarotCardResource (assets/data/tarot/*.tres, loaded by GameDataRegistry)
class_name TarotCardResource extends Resource
@export var card_id: StringName = &""
@export var rarity: String = "Common"          # Common | Rare | Legendary
@export var modifiers: Array[TarotModifierEntry] = []   # 1-2 entries
@export var linked_rune_id: StringName = &""
func validate() -> Array[String]: ...          # confirms modifier_type ∈ Rule 7's 4 registered types

# TarotModifierEntry (nested Resource, not a top-level GameDataRegistry entry)
class_name TarotModifierEntry extends Resource
@export var modifier_type: StringName = &""
@export var base_modifier_value: float = 1.0

# Tarot (scene-instanced node, implements SaveRestorer per ADR-0003)
var _mastery_missions_played: Dictionary[StringName, int] = {}
var _rune_discovered: Dictionary[StringName, bool] = {}
var _card_unlocked: Dictionary[StringName, bool] = {}   # read-only; write side unresolved (see Risks)
var _active_mission_deck: Array[StringName] = []        # NOT persisted — mission-scoped only
var _deck_template: Array[StringName] = []              # persisted — Sanctuary-time equipped list

const MASTERY_TIER_THRESHOLDS := [0, 3, 8, 15, 25]
const MASTERY_TIER_SCALARS := [1.00, 1.15, 1.30, 1.50, 1.75]

func _lookup_mastery_tier(card_id: StringName) -> int:
    var p: int = _mastery_missions_played.get(card_id, 0)
    var tier := 0
    for t in range(MASTERY_TIER_THRESHOLDS.size()):
        if p >= MASTERY_TIER_THRESHOLDS[t]:
            tier = t
    return tier

func _resolve_scout_modifiers() -> void:
    for card_id in _active_mission_deck:
        var card: TarotCardResource = GameDataRegistry.get_tarot_card(card_id)
        if card == null:
            push_warning("Tarot: deck template references unknown card_id '%s' — skipped." % card_id)
            continue   # orphaned content (removed post-save) — never crash, per project convention
        var tier := _lookup_mastery_tier(card_id)
        var scalar: float = MASTERY_TIER_SCALARS[tier]
        for entry in card.modifiers:
            var effective_value: float = entry.base_modifier_value * scalar
            EventBus.mission_modifier_applied.emit(entry.modifier_type, effective_value, card_id)

func get_save_key() -> String: return "tarot"
func get_save_data() -> Dictionary:
    return {
        "mastery_missions_played": _mastery_missions_played,
        "rune_discovered": _rune_discovered,
        "card_unlocked": _card_unlocked,
        "deck_template": _deck_template,
    }
```

## Alternatives Considered

### Alternative A: `mastery_tier`/`mastery_missions_played`/`unlocked` stored directly on `TarotCardResource`, per the GDD's literal Rule 1 table

- **Description**: Follow the GDD's prose exactly — treat `TarotCardResource` as a mutable, per-instance object rather than a shared boot-loaded definition.
- **Pros**: No split needed; matches the GDD's field table verbatim.
- **Cons**: Directly violates ADR-0009's established convention that `GameDataRegistry`-loaded Resources are boot-time-shared and immutable; would require either loading a separate `TarotCardResource` instance per save file (defeating the point of a shared registry) or accepting shared mutable state across whatever holds a reference to the same loaded Resource — and mutating it would need `get_save_data()` to somehow extract primitive fields from a live Resource instance, which is exactly the pattern the `resource_object_in_save_data` forbidden pattern (ADR-0003) exists to prevent.
- **Rejection Reason**: Every other data-driven system in this project (Monster, Item, Recipe, TechNode, Structure, Species) already resolved this identical tension the same way — static Resource + runtime ledger. Tarot is not a special case.

### Alternative B: A single flat `Dictionary[StringName, Dictionary]` ledger instead of three separate typed Dictionaries

- **Description**: One `_card_progress: Dictionary[StringName, Dictionary]` keyed by `card_id`, each value an inner Dictionary with `missions_played`/`unlocked` keys, plus a separate rune ledger.
- **Pros**: Fewer top-level fields.
- **Cons**: Loses static typing on the inner values (GDScript typed Dictionaries only type the outer container, not arbitrary nested Dictionary contents) — exactly the untyped-Dictionary anti-pattern this project's engine reference flags as discouraged (per the pattern already noted during ADR-0021's engine-specialist review).
- **Rejection Reason**: Three separately-typed `Dictionary[StringName, int]`/`Dictionary[StringName, bool]` structures preserve compile-time type safety at negligible additional field-count cost — consistent with the project's stated static-typing preference.

## Consequences

### Positive
- Resolves the GDD-level Resource-mutability inconsistency before it becomes an implementation bug — a literal implementation of Rule 1's table would have hit the exact `resource_object_in_save_data` violation ADR-0003 forbids.
- `_lookup_mastery_tier()` structurally guarantees Rule 11's "no tier-desync risk" claim — there is exactly one stored value (`_mastery_missions_played`) and tier is always derived, never independently settable.
- Clear scope boundary (Naming Clarification) prevents a future maintainer from assuming Tarot owns F2-stage aggregation/clamping — that responsibility correctly stays with Wave Manager/Monster System, avoiding duplicate or conflicting clamp logic.

### Negative
- Three separate ledger Dictionaries (rather than the GDD's implied single Resource) is a small additional surface area to keep synchronized during save/restore — mitigated by all three sharing one `get_save_data()`/`restore_save_data()` call, so there is no risk of one being restored without the others.
- `_card_unlocked`'s write side remains genuinely unresolved — this ADR specifies the read-side data structure but cannot invent the setter, since no other system (Defense Building's tech tree, Encyclopedia) currently claims ownership of card unlocking.

### Risks
- **Risk**: `_card_unlocked`'s external writer is unspecified — unlike Menagerie's Autoload-status gap (which ADR-0025 flagged and ADR-0026 then resolved), no sibling ADR in this session's batch is positioned to resolve card-unlock ownership, since the GDD itself states this is genuinely undesigned territory (Defense Building tech tree *or* Encyclopedia purchase, unresolved which).
  - **Mitigation**: This ADR specifies `_card_unlocked` as a `Dictionary[StringName, bool]` with an explicit external-write contract (Tarot never sets it, only reads it) so that whichever future system claims ownership has a concrete target to write into, without needing to renegotiate Tarot's own data model. Flagged as a genuine open dependency, not silently assumed.
- **Risk** (godot-specialist validation, fixed in this revision): the original draft's Risks section promised a null-check guard on `GameDataRegistry.get_tarot_card()`, but the Key Interfaces code sample dereferenced `card.modifiers` unguarded — a real inconsistency between the ADR's stated intent and its own authoritative code.
  - **Mitigation**: Fixed — `_resolve_scout_modifiers()` now explicitly null-checks and skips (with a logged warning) any `card_id` that fails to resolve, mirroring the orphan-content handling pattern already established elsewhere in this project (e.g. `hero.md`'s `class_id` orphan handling).
- **Risk** (godot-specialist validation): the `mission_launched → mission_phase_changed(SCOUT)` ordering this ADR's emission pipeline depends on (deck must be locked via Rule 5 before SCOUT-entry resolution reads it) is asserted by this ADR but not explicitly re-confirmed against the ADR that actually owns Wave Manager's phase-transition ordering.
  - **Mitigation**: This guarantee is established by ADR-0012 (Wave Manager FSM, Accepted) — its `_transition_to()` single-entry-point design and phase sequence (IDLE → SCOUT only after `mission_launched` has been fully processed) already ensures `mission_launched` completes before any `mission_phase_changed(SCOUT)` fires. Cited here explicitly rather than left as an unstated cross-ADR assumption.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| tarot.md | Rule 1: `TarotCardResource` schema | Split into static `TarotCardResource` + runtime `TarotProgressLedger`, resolving the Resource-mutability inconsistency |
| tarot.md | Rule 6/Formula F1: mastery scaling before emission | `_resolve_scout_modifiers()` specified as the single emission-time call site |
| tarot.md | Rule 10/11: mastery accrual, tier derived not stored | `_mastery_missions_played` counter + `_lookup_mastery_tier()`, no independent tier storage |
| tarot.md | Rule 15/States and Transitions: Rune Discovery Ledger | `_rune_discovered: Dictionary[StringName, bool]`, identical shape to ADR-0022/0023's precedent |
| tarot.md | Rule 8: channel ownership (never emits `run_modifier_selected`) | Confirmed by omission — no code path in this ADR's Key Interfaces emits on that channel |
| tarot.md | Dependencies: `restore_order=22` | Confirmed compatible with no new ordering constraints from this session's other ADRs |

## Performance Implications
- **CPU**: Negligible — modifier resolution and mastery/discovery accrual both fire once per mission (at SCOUT entry and at mission-terminal respectively), bounded by deck size (≤7 cards). No per-frame cost.
- **Memory**: Three small `Dictionary` ledgers bounded by total card-content scale (dozens of cards, not hundreds). Negligible.
- **Load Time**: `TarotCardResource` definitions load alongside existing `GameDataRegistry` boot-time preloading (ADR-0009) — no new load-time phase.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Tarot has no existing implementation to migrate from. This is a greenfield decision.

## Validation Criteria
- Unit test confirms `_lookup_mastery_tier()` returns the correct tier for boundary values of `_mastery_missions_played` (e.g. exactly `3`, `7`, `8` against the `{0,3,8,15,25}` thresholds) — directly implements Formula F6's worked example.
- Unit test confirms `_resolve_scout_modifiers()` never emits a raw `base_modifier_value` — every emitted `modifier_value` reflects F1's mastery-scaled result.
- Unit test confirms a dual-edge card's both entries emit within the same `_resolve_scout_modifiers()` pass (AC-4), never with only one side present.
- Unit test confirms rune discovery fires exactly once per `linked_rune_id`, on a card's first mission-terminal event (MISSION_COMPLETE or DEFEAT, per EC-5's no-outcome-gate), and never re-fires on subsequent missions.
- Integration test confirms `_active_mission_deck` (mission-locked snapshot) is correctly excluded from `get_save_data()`'s payload — only `_deck_template` (the Sanctuary-time editable list) persists.

## Related Decisions
- ADR-0009 (Resource Data Model) — `GameDataRegistry` + `validate()` pattern `TarotCardResource` extends
- ADR-0022 (Constellation pattern-detection data structure) — Discovery Ledger precedent `_rune_discovered` follows
- ADR-0023 (Crafting recipe data model) — direct structural precedent for the static-Resource/runtime-ledger split this ADR applies to Tarot
- ADR-0016 (Inventory Storage Model) — earliest instance of the same static-vs-runtime split, for `ItemDefinitionResource`/`InventorySlot`
- ADR-0001 (EventBus architecture) — `mission_modifier_applied`'s existing frozen contract this ADR's emission pipeline populates
- ADR-0012 (Wave Manager FSM) — source of the `mission_launched`-before-`SCOUT` ordering guarantee this ADR's emission pipeline relies on
- `design/gdd/tarot.md` — source GDD for all requirements this ADR addresses

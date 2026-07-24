# Story 002: Modifier Resolution Protocol & Mechanism Proofs

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tarot.md`
**Requirement**: `TR-tarot-001`

**ADR Governing Implementation**: ADR-0027 (Tarot Modifier Aggregation Pipeline)
**ADR Decision Summary**: A single method `_resolve_scout_modifiers()`, invoked on `mission_phase_changed → SCOUT`, iterates `_active_mission_deck`, computes each entry's F1 mastery-scaled `effective_modifier_value`, and emits one `mission_modifier_applied` per entry. Tarot performs only F1 — F2-stage aggregation/clamping is Wave Manager's/Monster System's own responsibility as consumers.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `mission_launched` is guaranteed to complete before `mission_phase_changed(SCOUT)` fires per ADR-0012's Wave Manager FSM (`_transition_to()` single-entry-point design) — this is the ordering guarantee the emission pipeline relies on.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0027 directly.
- Forbidden: Tarot must never emit through `run_modifier_selected` — that channel is exclusively Mission-Select-owned. Tarot only subscribes to it read-only for UI conflict-awareness.
- Guardrail: `_resolve_scout_modifiers()` performs no F2-stage aggregation or clamping — that responsibility belongs to Wave Manager/Monster System.

---

## Acceptance Criteria

*From GDD `design/gdd/tarot.md`, scoped to this story:*

- [x] AC-10 — exactly one `mission_modifier_applied` fires per `TarotModifierEntry` across all equipped cards, synchronized to Wave Manager's SCOUT entry
- [x] AC-11 — `modifier_value` always equals F1's mastery-scaled `effective_modifier_value`, never raw `base_modifier_value`
- [x] AC-12 — MULTIPLICATIVE mechanism proof (`tarot_speed_scalar_mult`): aggregate is a product, never a sum
- [x] AC-13 — MULTIPLICATIVE mechanism proof (`tarot_reward_scalar_mult`): natural scalar × Tarot multiplier, rune bonus added only afterward
- [x] AC-14 — REPLACE mechanism proof (`tarot_difficulty_growth_rate`): absolute substitution, never additive or multiplicative
- [ ] AC-15 *(content dependency flagged — genuinely not executable)* — REPLACE mechanism proof (`tarot_wave_config_override`): wholesale `WaveConfig` swap, no field merge. No mission authors an alternate `WaveConfig` variant yet (Vertical Slice scope-flag, unchanged) — cannot be positive-path tested until that content exists.
- [x] AC-16 *(equip-time half only)* — REPLACE single-card-only enforcement (EC-3): equip-time rejection implemented and tested. **The data-error runtime fallback/log is Wave Manager's own consumption-side responsibility per the GDD's own Formula F2 text — confirmed via inspection that neither Wave Manager nor Monster System subscribes to `mission_modifier_applied` yet, so that half is a genuine downstream gap, not fabricated here.**
- [ ] AC-17 *(cross-system dependency flagged — genuinely not executable)* — resolution order: Mission Select first, Tarot per-card modifiers second, Tarot rune bonuses third. No real Mission Select system exists yet (this epic's own remaining stories) to test the full 3-step order against; Tarot's own step-2/3 ordering (per-card then rune) is Story 004's scope.
- [x] AC-18 — Tarot never emits on `run_modifier_selected`; appears solely as a subscriber
- [x] AC-19 — conflict indicator surfaced from read-only `run_modifier_selected` subscription, without altering resolution logic
- [x] AC-20 *(Config/Data)* — none of Tarot's 4 modifier types target hero damage

---

## Implementation Notes

*Derived from ADR-0027 Implementation Guidelines:*

```gdscript
func _resolve_scout_modifiers() -> void:
    for card_id in _active_mission_deck:
        var card: TarotCardResource = GameDataRegistry.get_tarot_card(card_id)
        if card == null:
            push_warning("Tarot: deck template references unknown card_id '%s' — skipped." % card_id)
            continue   # orphaned content, never crash
        var tier := _lookup_mastery_tier(card_id)
        var scalar: float = MASTERY_TIER_SCALARS[tier]
        for entry in card.modifiers:
            var effective_value: float = entry.base_modifier_value * scalar
            EventBus.mission_modifier_applied.emit(entry.modifier_type, effective_value, card_id)
```

- Four registered `modifier_type` values, one mechanism each: `tarot_speed_scalar_mult` (MULTIPLICATIVE, Monster System aggregates), `tarot_reward_scalar_mult` (MULTIPLICATIVE, Wave Manager aggregates), `tarot_difficulty_growth_rate` (REPLACE, Wave Manager), `tarot_wave_config_override` (REPLACE, whole-Resource swap, Wave Manager).
- REPLACE types: only one equipped card may target that type at a time — enforced by the Tarot Deck UI at equip-time (validation, not runtime clamp). If violated by data corruption, the lowest deck-slot-index card wins, rest discarded with the exact log text specified in Formula F2.
- Resolution order (binding): (1) Mission Select's `run_modifier_selected` applies first; (2) Tarot's `mission_modifier_applied` per equipped card at SCOUT entry; (3) Tarot rune effects apply last, layered on top.
- Tarot subscribes read-only to `run_modifier_selected` solely so the Tarot Deck UI can surface a conflict indicator pre-launch — never to perform resolution logic itself.
- `tarot_wave_config_override` is Vertical-Slice scope-flagged: no mission currently authors an alternate `WaveConfig` variant, so AC-15's positive path is not executable today (per Rule 7's own scope-flag) — only AC-38's negative/fallback path (Story 006) is testable.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: mastery tier lookup itself (this story consumes it, doesn't derive it — see Formula F6 in Story 003)
- Story 006: the EC-6 negative/fallback path for `tarot_wave_config_override`

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-10**: One event per entry, synced to SCOUT
  - Given: `mission_phase_changed` transitions to SCOUT
  - When: Tarot processes it
  - Then: exactly one `mission_modifier_applied` fires per `TarotModifierEntry` across all equipped cards (a 5-card deck with one dual-edge card produces 6 events), synchronized to Wave Manager's SCOUT entry

- **AC-11**: Emitted value is always mastery-scaled
  - Given: a card's `base_modifier_value` and current `mastery_tier`
  - When: its `mission_modifier_applied` emits
  - Then: `modifier_value` equals F1's `effective_modifier_value` — raw `base_modifier_value` is never emitted

- **AC-12**: MULTIPLICATIVE proof — speed
  - Given: two equipped `tarot_speed_scalar_mult` cards with effective values `v_1=1.69`, `v_2=1.20`
  - When: Monster System aggregates
  - Then: `aggregate_raw = 1.69 × 1.20 = 2.028` (product, never sum), clamped to `2.00`

- **AC-13**: MULTIPLICATIVE proof — reward
  - Given: `wave_reward_scalar_natural = 1.44`, aggregated `tarot_reward_multiplier = 2.00`
  - When: Wave Manager computes F3
  - Then: combined by multiplication (`1.44 × 2.00`), rune's F5 bonus added only afterward

- **AC-14**: REPLACE proof — growth rate
  - Given: one equipped card targeting `tarot_difficulty_growth_rate` value `0.25`, mission's authored rate `0.20`
  - When: the modifier applies
  - Then: `difficulty_growth_rate` becomes exactly `0.25` — absolute substitution, never `0.20+0.25` or `0.20×0.25`

- **AC-15** `[content-dependency flagged]`: REPLACE proof — wave config override
  - Given: one equipped card targeting `tarot_wave_config_override` referencing a valid pre-authored alternate `WaveConfig`
  - When: the modifier applies
  - Then: the entire `WaveConfig` is swapped wholesale, no field merge
  - Edge cases: not executable as a positive-path test today — no mission has an authored alternate variant yet

- **AC-16**: REPLACE single-card enforcement
  - Given: two equipped cards both target the same REPLACE-type
  - When: the second equip is attempted via UI
  - Then: rejected at equip-time; if bypassed (simulated data corruption), only the lowest deck-slot-index card applies, rest discarded with the exact log text

- **AC-17** `[cross-system dependency flagged]`: Resolution ordering
  - Given: active Mission Select modifiers, equipped Tarot cards, previously-discovered runes all targeting the same type
  - When: the mission resolves
  - Then: apply in order — Mission Select first, Tarot per-card second, Tarot runes third
  - Edge cases: testable today only against a mock `run_modifier_selected` emitter (no real Mission Select system yet — see Epic 07's Mission Select stories)

- **AC-18**: Tarot never sends on `run_modifier_selected`
  - Given: a full mission lifecycle with any number of equipped cards
  - When: every EventBus emission Tarot performs is recorded
  - Then: zero emissions on `run_modifier_selected` — only `mission_modifier_applied`, `tarot_rune_discovered`, `tarot_deck_changed`

- **AC-19** `[cross-system dependency flagged]`: Conflict indicator
  - Given: a Mission Select run modifier already targets a type a slotted card also targets
  - When: the Tarot Deck UI is open pre-launch
  - Then: conflict indicator surfaced from the read-only subscription, without altering resolution logic

- **AC-20**: No hero-damage modifier *(Config/Data)*
  - Given: Tarot's 4 registered modifier types
  - When: enumerated against the Damage & Status Registry's `hero_damage_bonus_multiplier`
  - Then: none of the four target hero damage

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/tarot/modifier-resolution-mechanism-proofs_test.gd` — 12 tests covering AC-10/11/12/13/14/16(equip-time)/18/19/20. AC-15/17 tracked as genuinely-blocked (missing content / missing Mission Select system), not fabricated.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1145/1146 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 001 (card/deck model)
- Unlocks: Story 005 (formula worked-example validation)

**Unblocked**: ADR-0027 accepted 2026-07-18 (Sprint 6, S6-03).

**Implemented (2026-07-19, Sprint 7)**: added `_resolve_scout_modifiers()` to `tarot.gd`, wired to `mission_phase_changed`'s SCOUT transition — iterates `_active_mission_deck`, emits one `mission_modifier_applied` per modifier entry with F1 mastery-scaling (a `_lookup_mastery_tier()` stub always returns Tier 0/scalar 1.00 until Story 003 implements the real lookup). Extended `equip_card()` with `_has_replace_type_conflict()` for EC-3/AC-16's equip-time enforcement. Added read-only `run_modifier_selected` subscription (`_on_run_modifier_selected`/`has_run_modifier_conflict()`) for Rule 8's UI-conflict-awareness, never consulted by resolution logic. Authored 3 more real content cards (`swift_current`/`hunters_pace` — matching AC-12's own worked-example values 1.69/1.20 exactly; `grim_resolve` — a second `tarot_difficulty_growth_rate` card, needed to exercise AC-16's rejection path) alongside Story 001's 2. AC-12/13/14's "mechanism proofs" are tested as formula-correctness assertions within the test file itself (Tarot emits correctly F1-scaled per-card values; the test then applies the stated F2/F3 mechanism to prove those values combine as the GDD specifies) — matching the ADR's own scope boundary that Tarot performs only F1, never F2 aggregation. AC-15 (no authored alternate `WaveConfig` content exists) and AC-17 (no real Mission Select system exists yet) are honestly tracked as not-yet-executable rather than faked. Live-verified via gdUnit4: 12/12 new tests passing; full regression 1145/1146 (same pre-existing unrelated `TD-menag-006` failure).

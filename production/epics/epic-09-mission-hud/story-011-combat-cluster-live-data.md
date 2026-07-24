# Story 011: Combat Cluster Live Data Widgets

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-000` *(untraced — scoped from Core Rules Rule 4's visual consumers + the Interactions table's Monster/Damage & Status/Hero/Resource Economy/Inventory rows + PC-4)*

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture)
**ADR Decision Summary**: `CombatCluster` (Story 002's persistent child) hosts every real-time combat readout: hero HP bar, skill/ultimate cooldown fill (non-Ultimate slots — display only, no press contract, that's Story 009's scope), breach counter, boss bar, tower HP bars, floating damage numbers, live gold/material counters, phase/wave/timer chrome (PC-4), and toast notifications for Inventory events.

**Engine**: Godot 4.6.2 | **Risk**: LOW — pure display, no interaction, no post-cutoff API surface beyond what Story 001 already established
**Engine Notes**: None beyond ADR-0031's general notes.

**Control Manifest Rules (this layer)**:
- Required: N/A.
- Forbidden: No layout change or expanded treatment during WAVE_ACTIVE (Rule 7's "recede" guardrail) — this cluster is peripheral awareness, never a second focal point.
- Guardrail: Boss bar mounts only via Story 001's `_boss_state` field; tower HP bars mount/clear per Story 001's `_active_tower_hp_bars` field — this story renders those fields, it does not re-derive their mutation logic (already Story 001's scope).

---

## Acceptance Criteria

*From GDD Core Rules Rule 4 (visual half), Confirmed Signal Contract PC-4, and the Interactions table's Monster/Damage & Status/Hero/Resource Economy/Inventory rows:*

- [x] AC-57 — Hero HP bar reads `hero_health_changed` and renders current/max HP
- [x] AC-58 — skill cooldown fill for slots 0-3 reads `hero_skill_cooldown_updated` (display-only — no press contract, out of scope per GDD's own explicit note pending Hero Skill Build's payload)
- [x] AC-59 — breach counter renders Story 001's `_breach_count` field, updates on every mutation
- [x] AC-60 — boss bar mounts when Story 001's `_boss_state` becomes non-empty, renders `display_name`/`current_hp`/`max_hp`, updates on `boss_hp_changed`, dismounts when `_boss_state` clears
- [x] AC-61 — tower HP bars render Story 001's `_active_tower_hp_bars` dictionary — one bar per tracked `tower_id`, removed immediately when a tower is dropped from the dictionary (not just at the next wholesale INTERMISSION clear). **Real mutation gap found and fixed**: this per-tower removal path never existed anywhere before this story — see Implementation Deviation Notes.
- [x] AC-62 — floating damage numbers spawn on `monster_damage_taken` (`amount`, `is_crit`, `hero_bonus_tier`, `source_type`) — **PARTIAL, flagged not silently faked**: renders as a stacked feed, not at the real world position — see Implementation Deviation Notes.
- [x] AC-63 — phase indicator, wave counter, and phase timer render per PC-4 (`mission_phase_changed`, `wave_started`, `phase_timer_tick`, `wave_countdown_warning`) — resolved by the already-Approved `design/ux/mission-hud.md` Zone A spec
- [x] AC-64 — live gold balance + per-material-type running tally render from `materials_earned`/`resources_changed`
- [x] AC-65 — Inventory events (`item_added`, `item_removed`, `item_pickup_rejected`) drive live counters/toast notifications during mission (Inventory's own screen is inaccessible mid-mission)
- [x] AC-66 (edge case) — `boss_hp_changed` arriving while `_boss_state` is empty (subscription-order nondeterminism, or after `boss_died` already cleared it): discard silently
- [x] AC-67 (edge case) — `tower_damaged` arriving for a `tower_id` not currently tracked as alive (out-of-order delivery after `tower_destroyed`/`tower_removed`): discard — structurally a no-op, every `tower_damaged` legitimately creates/updates its own entry

---

## Implementation Notes

*Derived from ADR-0031/GDD Implementation Guidelines:*

- All widgets in this story are pure renderers of state Story 001 already owns and mutates (`_breach_count`, `_active_tower_hp_bars`, `_boss_state`) or of direct EventBus payloads (Hero HP, cooldowns, damage numbers, gold/material, Inventory toasts, PC-4 chrome) — this story does NOT re-implement any mutation logic, only display.
- `_active_tower_hp_bars`/`_boss_state`'s mutation-side edge-case guards (AC-66/67) are already implemented by Story 001 — this story's own responsibility is only to render whatever those fields currently contain, never to independently re-guard against stale data.
- No performance budget concern — up to 10 HABITAT-scale... n/a for Mission (this is Mission-context, not Sanctuary) — up to the project's per-frame EventBus batch threshold (20/frame per `event-bus.md`), well within a single wave's realistic damage-number volume.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the underlying state mutation logic for `_breach_count`/`_active_tower_hp_bars`/`_boss_state` (this story only renders it)
- Story 009: Ultimate button's own interactable/press contract (this story renders only the non-Ultimate cooldown fills, display-only)
- `tower_wave_summary`'s full "Endless Theorist" post-wave authorship panel — GDD explicitly defers the full display design; this story only consumes `max_hp` for the existing tower-HP-bar reset already covered by Story 001

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-60**: Boss bar mount/update/dismount
  - Given: `_boss_state` empty
  - When: it becomes non-empty (Story 001's own guard already applied), then `boss_hp_changed` fires, then `boss_died` clears it
  - Then: the bar mounts on the first transition, updates its HP display on the second, dismounts on the third

- **AC-61**: Tower HP bar immediate removal
  - Given: a tower HP bar tracked for `tower_id=5`
  - When: `_active_tower_hp_bars` drops `tower_id=5` (Story 001's own `tower_destroyed` handling)
  - Then: the corresponding bar is removed from display immediately, not deferred to the next INTERMISSION clear

- **AC-66/AC-67**: Stray-event discards
  - Given: `_boss_state` empty
  - When: `boss_hp_changed` fires anyway
  - Then: no crash, no mount, silently discarded
  - Edge cases: `tower_damaged` for an untracked `tower_id` similarly discarded

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/mission-hud/combat-cluster-live-data_test.gd` — must exist and pass

**Status**: [x] `tests/integration/mission-hud/combat-cluster-live-data_test.gd` — 20 tests, all passing (98/98 across all 8 mission-hud test files, after fixing 2 pre-existing tests whose CombatCluster child-count/NonReadyControls-node assumptions this story's new permanent widgets and Story 010's SellButton move invalidated). Full project regression re-confirmed clean (1464/1464, 0 errors, 1 pre-existing unrelated failure).

---

## Implementation Deviation Notes

- **AC-61, real mutation gap found and fixed**: prior to this story, `_active_tower_hp_bars` had NO per-tower removal path anywhere in shipped code — only the wholesale `.clear()` on SCOUT mount and INTERMISSION entry (Story 001's own code). AC-61 explicitly requires immediate per-tower removal on destruction. Fixed by extending `_on_tower_destroyed()` (already this file's existing handler) to `.erase(tower_id)` and free that tower's Label — documented inline at the handler itself.
- **AC-62, real architecture gap, left explicitly PARTIAL**: "at the relevant world position" requires a live `MonsterEntity.global_position` lookup by `entity_id`, but `MonsterManager` is not an Autoload and is not one of ADR-0031's classified direct-call dependencies — granting Mission HUD a live cross-scene position lookup is a new architectural decision this story doesn't have the authority to make unilaterally. Implemented as a stacked feed near the boss bar instead. **Needs a follow-up ADR** before this can use the real world position.
- Materials tally (AC-64) accumulates only `materials_earned` deltas, not `materials_spent` — the AC's own text lists only `materials_earned`/`resources_changed` as this story's sources.

---

## Dependencies

- Depends on: Story 001 (HUD Scaffold & Local State Model), Story 002 (Phase-Gated Cluster Lifecycle)
- Unlocks: None further within this epic

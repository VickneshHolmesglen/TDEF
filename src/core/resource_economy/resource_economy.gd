class_name ResourceEconomy
extends Node

## Scene-instanced (NOT Autoload) mission-scoped drop-table lookup service.
##
## GDD source: design/gdd/resource-economy.md
## ADR: docs/architecture/adr-0017-resource-economy-drop-resolution.md — scene-instanced
## node classification (matches ADR-0002's Autoload/Scene-Instanced boundary table),
## DropTableResource/DropEntry schema, "no public call API beyond EventBus" precedent
## (mirrors Damage & Status, ADR-0007).
## Story: production/epics/epic-03-core-economy/story-010-drop-table-schema-registry-lookup.md
## (AC-05 — a real registered table's entries are the ones "in play" for a given
## drop_table_id; AC-13 — an unregistered drop_table_id warns exactly once per unique
## id per session and resolves as no-drop) and
## production/epics/epic-03-core-economy/story-008-drop-occurrence-quantity-resolution.md
## (AC-01 — Formula 2's worked-example quantity; AC-02 — guaranteed_min_quantity floor,
## distinct from a failed Formula 1 roll staying 0; AC-12 — Formula 1's occurrence rate
## over a 10,000-sample statistical test).
##
## Story 010 scope: monster_died/monsters_died_batch correctly triggers a
## GameDataRegistry.get_drop_table() lookup for the correct id, and batch entries
## resolve identically to individual dispatch (both paths funnel through the same
## _resolve_drop_table()).
## Story 008 scope (this addition): for each DropEntry in a resolved table, Formula 1
## (occurrence roll, table.base_drop_rate) and Formula 2 (quantity, entry.base_quantity
## × payload.wave_reward_scalar × _menagerie_quality_bonus, floored to
## table.guaranteed_min_quantity) are resolved independently per entry (Rule 9 — no
## shared/accumulated rounding state), emitting the real materials_earned EventBus
## signal on each successful roll. Quality/rarity math consuming
## DropEntry.base_quality_probability (Story 009), despawn suppression (kill_source ==
## "wave_end" filtering, Story 011), and resources_changed/gold emission (Story 013)
## remain explicitly OUT of scope here.
##
## Test-accessible surface: ADR-0017 mandates "no public call API beyond what EventBus
## provides." _resolve_drop_table() and _unregistered_ids_seen below are
## underscore-prefixed — internal implementation detail, not a public query API — but
## remain directly reachable by tests via the class's own members, matching this
## project's existing convention of tests calling underscore-prefixed methods/reading
## underscore-prefixed state directly rather than the class exposing a broader public
## surface just for testability (see tests/unit/game_data_registry/game_data_registry_test.gd
## calling _registry._ready()/_inject() directly, and
## tests/integration/monster/monster_manager_wave_completed_wiring_test.gd reading
## _mm._is_wave_active). The ADR's public-API constraint is about calls FROM other
## gameplay systems into this one — a test reaching into implementation internals to
## assert on structure is a different concern and does not violate it.

## Unregistered drop_table_id values already warned about this instance's lifetime
## (AC-13 dedup key = the drop_table_id StringName itself). Cleared implicitly by a
## fresh ResourceEconomy instance at mission start (ADR-0017: mission-scoped node,
## not Autoload) — no explicit reset method needed.
var _unregistered_ids_seen: Dictionary[StringName, bool] = {}

## Formula 3's tuning-knob ceiling (design/gdd/resource-economy.md — Tuning Knobs
## table: "quality_probability_ceiling | 0.80 (tuning knob) | Hard cap regardless
## of scalar growth"). Project-wide system constant, not per-DropEntry/per-table
## authored data — matches the project's established const-as-tuning-knob pattern
## (Inventory.STACK_CAP_STACKABLE, SlotExpansionCostTable's consts). Story 009.
const QUALITY_PROBABILITY_CEILING: float = 0.80

## Sole additional mutable field per ADR-0017's "exactly one mutable field" design
## (Story 008 introduces it; Story 012 is the only story that ever writes a live
## value into it). Hardcoded at its 1.0 neutral default here — no
## creature_happiness_changed/creature_moved_to_breeding_pen/
## creature_returned_from_breeding_pen subscriptions exist yet (out of scope,
## Story 012). Consumed as a plain multiplier by _compute_drop_quantity() below.
var _menagerie_quality_bonus: float = 1.0

## kill_source value Monster System sets for wave-end force-clears
## (monster_manager.gd:366-368). Story 011 (AC-07, fixing TD-econ-002 —
## flagged during Story 008's code review as a then-live GDD violation):
## a MonsterDiedEvent carrying this kill_source must skip ALL drop
## resolution — no GameDataRegistry table lookup, no Formula 1/2/3
## evaluation, no materials_earned emission. See _process_drops() below,
## where this is checked before _resolve_drop_table() is even called.
const KILL_SOURCE_WAVE_END: String = "wave_end"

## Story 013 (Gold Track & Scout Starting Grant), AC-09/AC-10:
## WaveManager._phase_name() emits Phase.keys()[phase] as mission_phase_changed's
## new_phase String — "SCOUT" is that enum key's literal string form, not a
## separately-authored magic string.
const PHASE_SCOUT: String = "SCOUT"

## Rule 8 (design/gdd/resource-economy.md) flat Scout Phase starting gold grant.
## AC-09: emitted ONLY via resources_changed — never materials_earned/materials_spent
## (true by construction: _on_mission_phase_changed() below calls nothing else).
## Lowered from 150 to 50, 2026-08-11 (recalibrated against real Tower content,
## per the GDD's own Open Questions note that 150 was "provisional pending real
## tower content" — the 4 real blueprints cost 10-12g each, so 50 still fields
## 4-5 opening towers). See resource-economy.md's Tuning Knobs table and
## Formula 5 for the updated mission-total arithmetic and the newly-reopened
## tower_placement_budget_target comparison this creates.
const SCOUT_STARTING_GOLD: int = 50
const SCOUT_GRANT_SOURCE: StringName = &"mission_start_grant"

## Formula 5 (design/gdd/resource-economy.md, Rule 10) — Wave-Completion Gold
## Grant. Fully specified in the GDD since 2026-07-14 but never implemented;
## Story 013 only ever covered the Scout starting grant (AC-09/AC-10), never
## picked up Formula 5's own AC-18a/AC-18b/AC-19a/AC-19b. base_wave_gold=20
## is the GDD's documented default (safe range 15-25).
const BASE_WAVE_GOLD: int = 20
const WAVE_COMPLETION_GRANT_SOURCE: StringName = &"wave_completion_grant"

## Formula 5's own wave_reward_scalar(w) term. wave_completed's payload
## (wave_number/enemies_remaining/was_boss_breached) does not carry this
## scalar, so it's cached here from wave_started's own 3rd argument
## (wave_difficulty — the identical _wave_reward_scalar WaveManager already
## broadcasts, and the same value MonsterDiedEvent.wave_reward_scalar
## forwards per-kill for Formulas 2/3 above). wave_started always fires
## before the matching wave_completed for the same wave (WaveManager's own
## FSM — PRE_WAVE always precedes WAVE_ACTIVE, which is the only phase that
## can produce a wave_completed), so this is never stale for a real wave.
##
## This is a second mutable field, honestly flagged as a deviation from
## ADR-0017's "exactly one mutable field" framing (_menagerie_quality_bonus
## above) — that ADR predates Formula 5 (added to the GDD 2026-07-14, after
## ADR-0017 was written) and doesn't anticipate this need. Worth an ADR
## retrofit if this system grows further, not done here.
var _current_wave_reward_scalar: float = 1.0


func _ready() -> void:
	GEventBus.monster_died.connect(_on_monster_died)
	GEventBus.monsters_died_batch.connect(_on_monsters_died_batch)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GEventBus.wave_started.connect(_on_wave_started)
	GEventBus.wave_completed.connect(_on_wave_completed)


func _exit_tree() -> void:
	GEventBus.monster_died.disconnect(_on_monster_died)
	GEventBus.monsters_died_batch.disconnect(_on_monsters_died_batch)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	GEventBus.wave_started.disconnect(_on_wave_started)
	GEventBus.wave_completed.disconnect(_on_wave_completed)


func _on_monster_died(payload: MonsterDiedEvent) -> void:
	_process_drops(payload)


## Resolves each batch entry identically to individual monster_died dispatch — both
## paths call _process_drops() (which itself calls _resolve_drop_table() directly),
## so there is no shared/accumulated state between batch entries (ADR-0017 Validation
## Criteria: "monsters_died_batch entries resolve identically to individual
## monster_died dispatch — no shared rounding state between batch entries").
func _on_monsters_died_batch(payloads: Array[MonsterDiedEvent]) -> void:
	for payload: MonsterDiedEvent in payloads:
		_process_drops(payload)


## Story 013 (AC-10): fires the flat 50-gold Scout Phase starting grant exactly
## once per SCOUT entry — i.e. once per mission_phase_changed(new_phase="SCOUT")
## dispatch, synchronously within this same handler call (ADR-0001 Rule 1:
## synchronous dispatch is the default; there is no timer/frame boundary between
## WaveManager's own mission_phase_changed.emit() call and this handler running,
## so the grant always lands before WaveManager's SCOUT-phase timer, started
## immediately afterward in WaveManager._enter_scout(), can expire).
##
## No internal double-grant guard exists here by design (ADR-0017: ResourceEconomy
## is a stateless calculator with exactly one mutable field, _menagerie_quality_bonus,
## which this is not). "Fires exactly once" is scoped to one SCOUT transition, not
## once per node lifetime — a mission restart after DEFEAT is a fresh ResourceEconomy
## node instance per ADR-0017's mission-scoped lifecycle, so the realistic
## double-grant scenario (two missions sharing one instance) cannot occur; a second
## SCOUT transition artificially delivered to the same instance is a distinct
## transition and is expected to grant again (see
## gold_track_scout_grant_test.gd's dedicated test and comment for this
## distinction, flagged because the story's own QA Test Cases wording does not
## draw it explicitly).
func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	if new_phase == PHASE_SCOUT:
		GEventBus.resources_changed.emit(SCOUT_STARTING_GOLD, SCOUT_GRANT_SOURCE)


## Caches the just-started wave's reward scalar for _on_wave_completed()
## below to read — see _current_wave_reward_scalar's own doc comment for why
## this can't be read directly off wave_completed's payload instead.
func _on_wave_started(_wave_number: int, _total_waves: int, wave_difficulty: float) -> void:
	_current_wave_reward_scalar = wave_difficulty


## Formula 5 (Rule 10): gold_grant(w) = round(base_wave_gold × wave_reward_scalar(w)).
## Fires unconditionally on every wave_completed — the GDD's rule text states
## no exception for a boss-breach or force-clear wave (was_boss_breached is
## read by other systems, e.g. Mission HUD's banner text, not by this gate).
func _on_wave_completed(_wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	var gold_grant: int = int(round(BASE_WAVE_GOLD * _current_wave_reward_scalar))
	GEventBus.resources_changed.emit(gold_grant, WAVE_COMPLETION_GRANT_SOURCE)


## Story 008 entry point: resolves payload's drop table, then rolls Formula 1 and
## computes Formula 2 independently for each DropEntry (Rule 9 — rounded exactly once
## per kill per drop-table entry, never accumulated). Emits the real materials_earned
## EventBus signal for each successful, floored-quantity roll. A null/no-entry table
## (Story 010's existing unregistered-id or zero-entry-table cases) is a silent no-op
## here — nothing new to add on top of _resolve_drop_table()'s own warn-once handling.
## Story 009 additionally computes Formula 3 (quality roll probability) per
## successful entry, using the real per-kill entry.base_quality_probability /
## payload.wave_reward_scalar data — deliberately not rolled-against or surfaced
## anywhere yet (no quality-tier consumer exists: materials_earned's signature is
## out of scope here, Story 013 territory; the actual roll-and-branch is Story
## 011/012's job once a real consumer exists). See _compute_quality_roll_probability()
## below for why menagerie_quality_bonus is never part of this calculation (AC-04).
## Story 011 (AC-07, fixing TD-econ-002): a wave-end force-clear payload
## (kill_source == KILL_SOURCE_WAVE_END) is suppressed as the very first check,
## before _resolve_drop_table() is even called — no table lookup, no Formula
## 1/2/3, no materials_earned, and no Story 010 unregistered-id warning either.
## BOSS breach (AC-06) needs no equivalent check here: it emits the distinct
## monster_breached signal, which this system never subscribes to at all.
## Story 012 (GDD Rule 6): the Menagerie attraction material (lure) roll is
## resolved here, immediately after the wave-end guard and BEFORE (structurally
## independent of) _resolve_drop_table()/the table-null-check below — Rule 6's
## lure roll uses payload.menagerie_attraction_drop_chance directly and has no
## relationship whatsoever to drop_table_id/DropTableResource/DropEntry (it is
## not a table entry, not looked up via GameDataRegistry at all). Placing it
## before the table resolution means an unregistered or empty drop table has
## zero effect on whether the lure rolls; placing it after the wave_end guard
## means a wave-end force-clear (and, transitively, a BOSS breach, which never
## reaches this function at all) cannot spuriously grant a lure either — see
## _roll_menagerie_lure() below for why wave_reward_scalar can never leak into
## this roll.
func _process_drops(payload: MonsterDiedEvent) -> void:
	if payload.kill_source == KILL_SOURCE_WAVE_END:
		return
	if _roll_menagerie_lure(payload.menagerie_attraction_drop_chance):
		# quantity=1: the GDD/story define no quantity formula for the lure
		# (unlike Formula 2's wave-scaled math) — a fixed 1 matches the
		# "found a single rare item" framing of a flat, unscaled chance roll.
		GEventBus.materials_earned.emit(String(&"menagerie_lure"), 1, payload.kill_source)
	var table: DropTableResource = _resolve_drop_table(payload)
	if table == null:
		return
	for entry: DropEntry in table.entries:
		if not _roll_drop_occurs(table.base_drop_rate):
			continue
		var quantity: int = _compute_drop_quantity(
			entry.base_quantity,
			payload.wave_reward_scalar,
			_menagerie_quality_bonus,
			table.guaranteed_min_quantity
		)
		# Formula 3 (Story 009): computed per successful entry, matching Formula 1/2's
		# per-entry cadence — deliberately NOT consumed by an actual roll or surfaced
		# anywhere yet (see doc comment above). Kept here, not left as an orphaned
		# static function, so the real per-kill data is what's proven to flow through
		# Formula 3 — not just synthetic unit-test inputs.
		var _quality_roll_probability: float = _compute_quality_roll_probability(
			entry.base_quality_probability,
			payload.wave_reward_scalar
		)
		GEventBus.materials_earned.emit(String(entry.material_id), quantity, payload.kill_source)


## Formula 1 — Drop Occurrence Roll (design/gdd/resource-economy.md):
##   drop_occurs = random() < base_drop_rate
## Pure, static, real (unseeded) randomness — matches hero.gd's randf() precedent
## (test-standards.md forbids injected/seeded RNG). Statistically verified by AC-12
## over a 10,000-sample loop calling this function directly, isolated from full drop
## resolution.
##
## Usage:
##   ResourceEconomy._roll_drop_occurs(0.45)  # -> true ~45% of the time
static func _roll_drop_occurs(base_drop_rate: float) -> bool:
	return randf() < base_drop_rate


## Formula 2 — Drop Quantity (design/gdd/resource-economy.md), computed ONLY once a
## drop has already occurred (Formula 1 succeeded):
##   quantity = max(guaranteed_min_quantity, round(base_quantity × wave_reward_scalar
##              × menagerie_quality_bonus))
## Pure, static, no RNG — rounds exactly once per call (Rule 9); callers must never
## accumulate fractional quantities across kills before calling this.
##
## Usage:
##   ResourceEconomy._compute_drop_quantity(1, 4.768, 1.3, 1)  # -> 6
static func _compute_drop_quantity(base_quantity: int, wave_reward_scalar: float, menagerie_quality_bonus: float, guaranteed_min_quantity: int) -> int:
	var raw: float = base_quantity * wave_reward_scalar * menagerie_quality_bonus
	var rounded: int = int(round(raw))
	return max(rounded, guaranteed_min_quantity)


## Formula 3 — Quality Tier Roll probability (design/gdd/resource-economy.md):
##   quality_roll_probability = clamp(base_quality_probability × wave_reward_scalar,
##                                     0.0, quality_probability_ceiling)
## Pure, static, no RNG. Deliberately does NOT accept menagerie_quality_bonus as a
## parameter — GDD Rule 3 / ADR-0017 are explicit that the Menagerie bonus applies
## only to Formula 2's quantity term, never to this probability (Story 009, AC-04).
## A function that structurally cannot receive the bonus cannot accidentally apply
## it — see quality_roll_menagerie_scope_test.gd's regression coverage.
##
## Usage:
##   ResourceEconomy._compute_quality_roll_probability(0.20, 4.768)  # -> 0.80 (clamped)
##   ResourceEconomy._compute_quality_roll_probability(0.10, 4.768)  # -> 0.477 (uncapped)
static func _compute_quality_roll_probability(base_quality_probability: float, wave_reward_scalar: float) -> float:
	var raw: float = base_quality_probability * wave_reward_scalar
	return clamp(raw, 0.0, QUALITY_PROBABILITY_CEILING)


## Menagerie Attraction Material (Lure) roll (design/gdd/resource-economy.md Rule 6):
##   lure_found = random() < menagerie_attraction_drop_chance
## Pure, static, real (unseeded) randf() — matches _roll_drop_occurs()'s existing
## pattern. Deliberately does NOT accept wave_reward_scalar as a parameter — Rule 6
## is explicit that this rare-find roll is "not scaled by wave_reward_scalar... not
## part of the wave-escalating economy," so this function's signature structurally
## excludes it (a function that cannot receive the scalar cannot accidentally apply
## it), the same technique _compute_quality_roll_probability() already uses to
## exclude menagerie_quality_bonus (Story 009, AC-04).
##
## Usage:
##   ResourceEconomy._roll_menagerie_lure(0.5)  # -> true ~50% of the time,
##   #   regardless of the caller's wave_reward_scalar (Story 012, AC-08).
static func _roll_menagerie_lure(menagerie_attraction_drop_chance: float) -> bool:
	return randf() < menagerie_attraction_drop_chance


## Internal resolution surface (test-reachable, not a public call API per ADR-0017).
## Looks up payload.drop_table_id via GameDataRegistry — the sole lookup point
## (control manifest: "no system constructs its own res://assets/data/... path").
##
## Returns the resolved DropTableResource on a hit (Story 008/009 will consume it
## further — quantity/quality math is not this story's job). On a miss: this is a
## runtime content-authoring gap (MonsterResource.drop_table_id references a table
## that was never authored/registered), not a load-time validation failure — that
## distinction is why this uses push_warning() rather than push_error(): a malformed
## DropTableResource caught by validate() at GameDataRegistry boot IS push_error()-
## worthy (hard content bug, caught early); an unregistered id discovered only when a
## monster actually dies is a softer, recoverable case the story/ADR explicitly call
## out as "warn-then-no-drop," not a crash. Warns exactly once per unique
## drop_table_id per ResourceEconomy instance lifetime (AC-13) — tracked via
## _unregistered_ids_seen, keyed by the drop_table_id StringName itself (AC-13 edge
## case: two different unregistered ids each warn once, independently).
func _resolve_drop_table(payload: MonsterDiedEvent) -> DropTableResource:
	var table: DropTableResource = GGameDataRegistry.get_drop_table(payload.drop_table_id)
	if table == null:
		if not _unregistered_ids_seen.has(payload.drop_table_id):
			_unregistered_ids_seen[payload.drop_table_id] = true
			push_warning("[ResourceEconomy] Unregistered drop_table_id '%s' — treating as no-drop." % payload.drop_table_id)
		return null
	return table

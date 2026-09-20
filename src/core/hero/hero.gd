class_name Hero
extends CharacterBody2D

## Hero stat storage, stat resolution (Formula 1), movement, and grid position tracking.
##
## Design: design/gdd/hero.md (TR-hero-001, TR-hero-006)
## ADR: docs/architecture/adr-0010-hero-tower-synced-class.md — "Stat Resolution — Formula 1"
## Story: production/epics/epic-02-core-combat/story-001-hero-stat-resolution.md (stats)
## Story: production/epics/epic-02-core-combat/story-002-hero-movement.md (movement, S4-04)
## Story: production/epics/epic-02-core-combat/story-008-hero-lifecycle.md (lifecycle,
## death, and SaveRestorer implementation — see Story-008 sections near the bottom of
## this file)
##
## Scene root is CharacterBody2D per docs/architecture/control-manifest.md Core Layer Rules
## (required for move_and_slide()). Story-001 implements ONLY stat storage and
## get_effective_stat(). Story-002 (this addition) implements omnidirectional movement
## (Rule 26), collision with BLOCKED/tower-occupied cells (Rule 27), and grid-cell-change
## position tracking + hero_position_changed emission (Rule 28). Tower Cache / Tower
## Affinity (ADR-0010, story-005) is implemented below. Auto-attack damage (story-003)
## is also already implemented. Tower-Synced Class proximity accumulation and the 30s
## primary-class unlock/lock (ADR-0010, story-006) are implemented below too — story-006
## deliberately implements only ADR-0010's simpler 30s-primary-unlock subset (locking
## immediately in _physics_process on threshold crossing); the ADR's fuller 90s
## deep-unlock and SCOUT-phase-entry primary/secondary computation are out of scope,
## deferred to a later story.
##
## Control manifest requirement: all stat reads go through get_effective_stat() — no other
## system may read _base_stats / _flat_bonuses / _additive_bonuses directly, and effective
## (resolved) values are never cached as persistent fields; they are always recomputed.
##
## Control manifest requirement (Core Layer, ADR-0002): input polling happens in _process(),
## movement (move_and_slide()) happens in _physics_process(). The raw Input.get_vector() read
## is cached to _input_direction in _process() each frame; _physics_process() consumes the
## cached value. This differs from story-002's own Implementation Notes code sketch (which
## reads Input directly inside _physics_process) — the control manifest is the authoritative
## source and takes precedence over the story's illustrative sketch.
##
## Collision layer convention — see ADR-0015 (docs/architecture/adr-0015-collision-layer-convention.md)
## for the full table and rationale. Summary: Layer 1 = environment (BLOCKED-cell tilemap
## collision shapes, tower physics bodies — neither built yet as of ADR-0015); Layer 2 = hero.
## Hero: collision_layer = 2, collision_mask = 1 (hero collides against environment only;
## hero never blocks or is blocked by monsters, which are Area2D and do not participate in
## move_and_slide() collision response regardless of layer/mask).

## Formula 1 additive-bonus clamp bounds (ADR-0010): floor -0.75 -> 0.25x multiplier,
## cap +3.00 -> 4.0x multiplier.
const ADDITIVE_BONUS_FLOOR: float = -0.75
const ADDITIVE_BONUS_CAP: float = 3.0

## Per-stat post-formula caps (story-001 Tuning Knobs). Applied after Formula 1 resolves.
## TODO: migrate these into HeroResource or a TuningKnobs data resource once that data
## model lands (stories 005/006) — hardcoded here for now, matching ADR-0010's own
## Key Interfaces sketch, which has no data-file mechanism defined yet for this story.
## Diminishing-returns curve cap/scaling-constant pairs (design/combat_
## formula_and_stats.txt, reconciled in docs/superpowers/specs/2026-09-18-
## hero-combat-stats-redesign-design.md Section 3.2). Scaling constants are
## rescaled from the source doc's large-stat-point examples (100/200/150) to
## fit this game's existing 0.0-1.0 fractional stat convention — see that
## spec section's own correction note for the worked-example values these
## produce.
const CRIT_CHANCE_CAP: float = 0.85
const CRIT_CHANCE_SCALING_CONSTANT: float = 0.5
const CRIT_MULTIPLIER_BONUS_CAP: float = 2.0
const CRIT_MULTIPLIER_SCALING_CONSTANT: float = 1.0
const LUCK_CAP: float = 0.35
const LUCK_SCALING_CONSTANT: float = 0.5
const ELEMENTAL_RESIST_CAP: float = 0.75
const LIFESTEAL_CAP: float = 0.4
const CDR_CAP: float = 0.75

## Story-002 (S4-04) collision radius. Quarter of MonsterManager.CELL_SIZE (64.0), a
## reasonable default hitbox for a single-cell-scale entity. TODO: migrate into
## HeroResource / TuningKnobs once that data model lands (same TODO as the stat caps
## above) — no data-file mechanism exists yet for this story either.
const HERO_COLLISION_RADIUS: float = 16.0

## Story-002 collision layer/mask — see ADR-0015 (class doc comment above) for the
## full convention. Layer 1 = environment (BLOCKED tilemap + towers); Layer 2 = hero.
const COLLISION_LAYER_ENVIRONMENT: int = 1
const COLLISION_LAYER_HERO: int = 2

## Epic 15 Story 005 (ADR-0037, Visual Presentation 3D Companion Layer): the
## entity_or_component_id Hero resolves its 3D visual through, via
## GGameDataRegistry.get_visual_mesh_mapping(). Hero is a single mission-wide
## instance (unlike Monster/Tower, this is the only mesh id this file will
## ever need). No character/hero model exists in the "Tower Defense Models"
## Kenney pack (it ships terrain, towers, UFO-enemy, and siege-weapon pieces
## only — confirmed by an asset-directory survey during this story) — the
## placeholder mapping below points at detail-crystal.glb, a small, visually
## distinct standalone piece not already claimed by TowerInstance
## (tower_round.tres) or MonsterInstance (enemy_ufo_a.tres). Same "one shared
## placeholder proves the pipeline, not final art" judgment call already
## established by those two stories — real hero art is a future
## content-authoring pass (ADR-0037's Phase 6), not this story's concern.
const HERO_MESH_ENTITY_ID: StringName = &"hero"

## Y-height for the hero's visual companion per ADR-0037's layer_height table
## ("monster/tower visual anchors = 0" — same reasoning as
## TowerInstance.TOWER_LAYER_HEIGHT / MonsterInstance.MONSTER_LAYER_HEIGHT:
## the spike's live-queried AABB data shows these Kenney meshes already have
## their origin at their own base).
const HERO_LAYER_HEIGHT: float = 0.0

## Story-003 (S4-05) auto-attack cadence. Fixed cadence — Rule 3: CDR does NOT affect
## auto-attack rate, and no "attack_speed" stat exists in the story-001 stat set yet.
## TODO: migrate into HeroResource / TuningKnobs once that data model lands (same TODO
## as the stat caps and HERO_COLLISION_RADIUS above) — no data-file mechanism exists
## yet for this story either.
const AUTO_ATTACK_INTERVAL_S: float = 1.0

## Story-003 (S4-05) crit multiplier base (GDD event-bus.md / ADR-0010).
## Hero Combat & Stats Redesign (2026-09-18): base changed 1.75 -> 1.5 per
## the reconciled source doc. Now folded INTO get_effective_stat(&"crit_
## multiplier")'s own return value by _apply_stat_cap() below — callers no
## longer add this constant on top (see that function).
const CRIT_MULTIPLIER_BASE: float = 1.5

## Story-005 (ADR-0010 Formula 2): Tower Affinity sqrt-scaling reference tower count
## and the multiplier's hard cap.
const TOWERS_AFFINITY_REFERENCE: float = 16.0
const TOWER_AFFINITY_BONUS_CAP: float = 2.0

## Story-006 (ADR-0010 Tower-Synced Class): Chebyshev radius, in grid cells, within
## which the hero accumulates per-archetype proximity time toward a class unlock.
const CLASS_PROXIMITY_RADIUS: int = 3

## Story-006: cumulative seconds of proximity required to unlock a primary class.
## This story implements ONLY the 30s primary unlock (story-006 scope decision).
## ADR-0010's fuller model additionally defines a 90s "deep unlock"
## (CLASS_UNLOCK_THRESHOLD_ADVANCED_S) and SCOUT-phase-entry primary/secondary
## class computation from highest/second-highest proximity time among all
## unlocked classes — both are explicitly out of scope here per story-006's Out
## of Scope section (deferred to Story 007/008). This story's simpler model locks
## the FIRST archetype to cross 30s, immediately, inside _physics_process.
const CLASS_UNLOCK_THRESHOLD_S: float = 30.0

## Story-007 (TR-hero-005): per-skill base cooldown, keyed by skill StringName ID.
## TD-hero-006 (fixed 2026-09-02): self-populated at _ready() from
## GGameDataRegistry's real 32-skill SkillDefinitionResource catalogue
## (res://assets/data/skills/definitions/) if empty — see _ready()'s
## self-populate block. Previously read the legacy SkillResource pipeline
## (res://assets/data/skills/, 4 unrelated skill_ids with zero overlap with
## the real catalogue), which meant every real, player-equippable skill had
## no cooldown data and no damage — see TD-hero-006 in
## docs/tech-debt-register.md for the full bug. _inject_skill_data() (test
## seam, below) still overrides this wholesale for tests, matching the
## established MonsterManager/TowerSystem self-populate-if-empty pattern (S5-01).
##
## Epic 08 / ADR-0030 correction (Story 003, 2026-07-19): this field previously
## sat alongside a second `_ultimate_lookup` Dictionary + `_recompute_ultimate()`
## — Hero independently deriving the Ultimate from raw skill IDs via a
## combo-key lookup (TD-hero-002's original MVP mechanism). ADR-0030 (Hero
## Skill Build) explicitly forbids this: Hero Skill Build now owns Ultimate
## derivation entirely (category-profile -> shape -> Ultimate ID, a pure
## function), and Hero only ever applies the `ultimate_id` it receives via
## `ultimate_skill_changed`, verbatim, via _on_ultimate_skill_changed() below —
## never re-deriving it. `_ultimate_lookup`/`_recompute_ultimate()` removed;
## `UltimateComboTable.combos` (the old derivation table) is now unused by
## Hero, but `UltimateComboTable.ultimate_cooldowns` remains — Ultimate
## cooldown is content data keyed by ultimate_id, an unrelated concern this
## ADR does not touch.
##
## Declared directly as a `var` field (not `const` + a separate mutable copy) —
## see git history for the empty-literal-typed-Dictionary engine quirk this
## avoids (Godot 4.6.2, found via real test execution during Story 007).
var _skill_cooldowns: Dictionary[StringName, float] = {}

## Base stat values, set from HeroResource at mission start (wired in a later story).
## Keys are the 13 stat StringNames from design/gdd/hero.md, e.g. &"max_hp",
## &"physical_attack", &"move_speed", &"cdr", &"crit_chance", &"armor", &"magic_attack",
## &"attack_range", &"elemental_resist_fire", &"elemental_resist_frost", &"lifesteal",
## &"tower_affinity", &"crit_multiplier", &"luck".
var _base_stats: Dictionary[StringName, float] = {}

## Hero Leveling System (2026-09-19): persistent (cross-mission) level/XP —
## see docs/superpowers/specs/2026-09-19-hero-leveling-design.md. Resets to
## 1/0 only via reset_to_defaults() (called on a fresh/malformed save load,
## which is also this project's own established "new adventure" reset
## trigger — see that field's own doc comment precedent on _proximity_time).
var _current_level: int = 1
var _current_xp: int = 0

## Hero Leveling System (2026-09-19), Critical fix (found in final review):
## the running total of every class-specific level-up bonus stat delta
## ever granted (Section 3.4's every-5th-level reward). Persisted directly
## rather than re-derived from _current_level, because it depends on
## whichever Primary class was active at EACH historical qualifying
## level-up -- which can differ from the Hero's CURRENT Primary class if
## the player has since changed it. Re-deriving from the current class
## would silently rewrite history for that case. Keys are the real
## stat StringNames (e.g. &"physical_attack"), matching CLASS_LEVEL_BONUS's
## own bonus_stat values.
var _accumulated_class_bonuses: Dictionary[StringName, float] = {}

## Level cap (Section 3.3 of the governing spec) — no further XP/levels
## past this point; excess XP at the cap is discarded, never banked.
const LEVEL_CAP: int = 50

## Formula L2 (kill XP bands). Keys match MonsterResource.tier's own
## 0/1/2 convention (STANDARD/ELITE/BOSS).
const KILL_XP_BY_TIER: Dictionary[int, int] = {0: 5, 1: 15, 2: 100}
const KILL_XP_OUTER_BAND_MULTIPLIER: float = 0.5
const KILL_XP_OUTER_BAND_RANGE_MULTIPLIER: float = 2.0
const WAVE_COMPLETION_XP: int = 25
const MISSION_COMPLETION_XP: int = 150

## Retargeted 2026-09-20 to match design/gdd/hero-class-catalogue.md's real
## Primary perk per class (the catalogue existed since 2026-08-27, predating
## this mapping's original placeholder values, which were invented before
## that catalogue was known/reconciled). Each class's PRIMARY perk was
## chosen since this schema supports only one bonus per class per qualifying
## level: physical -> Bulwark Stance (flat Armor), ranged -> Extended Reach
## (Attack Range), elemental -> Arcane Attunement (Magic Attack, already
## correctly targeted before this change), support -> Field Medic
## (Lifesteal) -- support previously targeted CDR, which is that class's
## SECONDARY perk (Efficient Casting), not Primary; switched to match.
## Amounts are this system's own per-level increments (the catalogue's own
## safe ranges are one-time totals, not per-level -- see each entry below
## for how the chosen increment maps to the catalogue's stated range across
## the 10 qualifying levels between 5 and 50). Each entry: [stat_name, amount].
const CLASS_LEVEL_BONUS: Dictionary[StringName, Array] = {
	&"physical": [&"armor", 2.0],  ## Bulwark Stance; 10 levels -> +20, catalogue's own upper bound (+8 to +20)
	&"ranged": [&"attack_range", 6.0],  ## Extended Reach; 10 levels -> +60 world units (~27% of the 220 placeholder base, within the catalogue's +15%-30% range)
	&"elemental": [&"magic_attack", 1.0],  ## Arcane Attunement -- unchanged, already the right stat
	&"support": [&"lifesteal", 0.01],  ## Field Medic; 10 levels -> +10% (within the catalogue's +8%-15% range)
}
const SKILL_POINT_LEVEL_INTERVAL: int = 5
## Reserved sentinel for a level-derived skill_tree_point_earned emission --
## real tower ids from Tower Mastery's own emissions are always >= 0.
const LEVEL_DERIVED_SKILL_POINT_SOURCE_ID: int = -1

## Formula L1: xp_required(level) = floor(100 * 1.15^(level-1)). Pure,
## static — no instance state, matching this file's established
## _diminishing_curve()/_apply_tower_affinity_bonus() precedent for
## formula helpers.
static func _xp_required_for_level(level: int) -> int:
	return int(floor(100.0 * pow(1.15, float(level - 1))))


## Formula L2: resolves kill XP for one monster death by distance band.
## Returns 0 if the death is outside both bands. Reads MonsterDiedEvent's
## own world_position/tier fields directly -- never _monster_cache, which
## _on_monster_died() erases the entry from before XP would resolve in
## some call orderings.
## Finding I2 (final review, 2026-09-19): a monster force-removed at
## wave-end (kill_source == "wave_end") is not a real kill -- matches
## ResourceEconomy._process_drops()'s own identical first-check convention
## for the same reason (MonsterDiedEvent's own doc comment: "Resource
## Economy must filter kill_source == 'wave_end' and suppress drop
## resolution" -- Hero Leveling is a second reward consumer subject to the
## same rule, just not originally called out for it).
func _resolve_kill_xp_band(payload: MonsterDiedEvent) -> int:
	if payload.kill_source == "wave_end":
		return 0
	var base_xp: int = KILL_XP_BY_TIER.get(payload.tier, 0)
	if base_xp <= 0:
		return 0
	var attack_range: float = get_effective_stat(&"attack_range")
	var distance: float = global_position.distance_to(payload.world_position)
	if distance <= attack_range:
		return base_xp
	if distance <= attack_range * KILL_XP_OUTER_BAND_RANGE_MULTIPLIER:
		return int(floor(float(base_xp) * KILL_XP_OUTER_BAND_MULTIPLIER))
	return 0


## Formula L3: single entry point for every XP source. Resolves every
## level threshold crossed by this one grant (never just the first),
## applying Task 1/3's flat growth per level and emitting
## hero_xp_gained/hero_leveled_up. amount <= 0 is a silent no-op (a kill
## outside both bands, or a not-yet-authored zero-XP source, must never
## emit a spurious hero_xp_gained(0, ...)).
func _grant_xp(amount: int) -> void:
	if amount <= 0:
		return
	if _current_level >= LEVEL_CAP:
		return
	_current_xp += amount
	while _current_level < LEVEL_CAP and _current_xp >= _xp_required_for_level(_current_level + 1):
		_current_xp -= _xp_required_for_level(_current_level + 1)
		_current_level += 1
		_apply_level_up_rewards()
		GEventBus.hero_leveled_up.emit(_current_level)
	if _current_level >= LEVEL_CAP:
		_current_xp = 0
	# Finding I3 (final review, 2026-09-19): emitted AFTER the level-up loop
	# (was emitted before it, so new_level was the pre-grant level, not the
	# resulting one -- contradicted this signal's own doc comment).
	GEventBus.hero_xp_gained.emit(amount, _current_level)


## Flat per-level stat growth (Section 3.4's first bullet) -- applies
## unconditionally, every level, regardless of Primary class designation.
## Task 4 extends this same function with the every-5th-level Skill Tree
## point + class bonus (gated on _current_level % 5 == 0), appended at the
## end of this function's body, not a separate call site -- see Task 4's
## own Step 1.
func _apply_level_up_rewards() -> void:
	_base_stats[&"max_hp"] = _base_stats.get(&"max_hp", 0.0) + 10.0
	_base_stats[&"physical_attack"] = _base_stats.get(&"physical_attack", 0.0) + 2.0
	_base_stats[&"magic_attack"] = _base_stats.get(&"magic_attack", 0.0) + 2.0
	# Finding M6 (final review): keep _max_hp's live cache in sync with the
	# just-raised base stat immediately, not only at the next
	# reset_to_defaults() call -- the HP bar/overheal clamp both read
	# _max_hp, not get_effective_stat(&"max_hp"), directly.
	_max_hp = get_effective_stat(&"max_hp")

	if _current_level % SKILL_POINT_LEVEL_INTERVAL != 0:
		return
	if _primary_class == &"":
		return
	GEventBus.skill_tree_point_earned.emit(String(_primary_class), LEVEL_DERIVED_SKILL_POINT_SOURCE_ID)
	var bonus_entry: Array = CLASS_LEVEL_BONUS.get(_primary_class, [])
	if bonus_entry.is_empty():
		return
	var bonus_stat: StringName = bonus_entry[0] as StringName
	var bonus_amount: float = bonus_entry[1] as float
	_base_stats[bonus_stat] = _base_stats.get(bonus_stat, 0.0) + bonus_amount
	# Finding C1 (final review): also record into the persisted running
	# total, so this exact bonus survives apply_placeholder_base_stats()'s
	# per-mission _base_stats reseed via _reapply_persistent_level_growth()
	# below -- see that function and _accumulated_class_bonuses's own doc
	# comment for why this can't just be re-derived from the current
	# Primary class instead.
	_accumulated_class_bonuses[bonus_stat] = _accumulated_class_bonuses.get(bonus_stat, 0.0) + bonus_amount
	_max_hp = get_effective_stat(&"max_hp")

## Finding C1 (final review, 2026-09-19): re-applies every persistent
## level-up reward on top of a freshly-reseeded _base_stats dict.
## Universal growth (+10 HP/+2 Physical Attack/+2 Magic Attack per level)
## is purely deterministic from _current_level, so it's recomputed fresh
## here rather than stored separately. The class bonus portion is NOT
## recomputed -- it's added back verbatim from _accumulated_class_bonuses,
## which was built up historically at the moment each qualifying level-up
## actually occurred (see that field's own doc comment for why).
func _reapply_persistent_level_growth() -> void:
	var levels_gained: int = _current_level - 1
	if levels_gained > 0:
		_base_stats[&"max_hp"] = _base_stats.get(&"max_hp", 0.0) + 10.0 * float(levels_gained)
		_base_stats[&"physical_attack"] = _base_stats.get(&"physical_attack", 0.0) + 2.0 * float(levels_gained)
		_base_stats[&"magic_attack"] = _base_stats.get(&"magic_attack", 0.0) + 2.0 * float(levels_gained)
	for stat: StringName in _accumulated_class_bonuses:
		_base_stats[stat] = _base_stats.get(stat, 0.0) + _accumulated_class_bonuses[stat]

## Stopgap values for apply_placeholder_base_stats() below — see that
## method's own doc comment. Deduplicated 2026-09-17 from two identical
## copies (the_gap.gd's and mission_scene.gd's own _set_hero_placeholder_
## stats(), byte-for-byte the same dict) into this single source of truth.
const PLACEHOLDER_BASE_STATS: Dictionary[StringName, float] = {
	&"max_hp": 500.0,
	&"physical_attack": 25.0,
	&"move_speed": 220.0,
	&"cdr": 0.0,
	&"crit_chance": 0.1,
	&"armor": 0.0,
	&"magic_attack": 10.0,
	&"attack_range": 220.0,
	&"elemental_resist_fire": 0.0,
	&"elemental_resist_frost": 0.0,
	&"lifesteal": 0.0,
	&"tower_affinity": 1.0,
	&"crit_multiplier": 0.0,
	&"luck": 0.0,
}

## Every real _base_stats key, used for the `additive_bonus_total` fan-out
## (equipment-stats-wiring spec §3.3). MAINTENANCE POINT: add any new Hero
## stat here too -- Hero has no dynamic stat-name introspection. Enforced by
## hero_equipment_stats_test.gd against PLACEHOLDER_BASE_STATS.
const EQUIPMENT_FAN_OUT_STATS: Array[StringName] = [
	&"max_hp", &"physical_attack", &"move_speed", &"cdr", &"crit_chance",
	&"armor", &"magic_attack", &"attack_range", &"elemental_resist_fire",
	&"elemental_resist_frost", &"lifesteal", &"tower_affinity",
	&"crit_multiplier", &"luck",
]

## Flat (pre-multiplier) bonuses from gear, skills, etc.
var _flat_bonuses: Dictionary[StringName, float] = {}

## Additive percentage bonuses summed before the Formula 1 multiplier is applied
## (e.g. +0.10 means +10% before clamping).
var _additive_bonuses: Dictionary[StringName, float] = {}

## Rule 28: last grid cell the hero occupied. Sentinel (-1, -1) guarantees the
## first _update_position_tracking() call always emits, since (-1, -1) is never
## a valid on-grid cell.
var _prev_cell: Vector2i = Vector2i(-1, -1)

## Rule 26: raw directional input, polled in _process() and consumed by
## _physics_process(). Not normalized here — normalization happens at the point
## of use (_handle_movement()) per the story's documented formula.
var _input_direction: Vector2 = Vector2.ZERO

## Story-003 (S4-05): local monster cache (ADR-0010 — Hero never holds direct Monster
## node references; target acquisition reads only from this cache).
## Keyed by entity_id: int → {cell: Vector2i, hp: float, monster_id: StringName,
## tier: int, path_step: int}.
## "hp" is seeded once from monster_spawned's hp_max and never updated afterward —
## intentionally mirroring Tower System's shipped monster-cache limitation (ADR-0007
## precedent); this story does not subscribe to monster_damage_taken to "fix" that.
## "tier" is cached once at spawn from GameDataRegistry (immutable per monster type),
## avoiding a registry lookup on every attack.
var _monster_cache: Dictionary = {}

## Story-003 (S4-05): auto-attack cadence timer (ADR-0010 Engine Note — Timer node,
## not _physics_process). Built and started in _ready().
var _attack_timer: Timer

## Story-005 (ADR-0010): unified tower cache — Hero never holds a direct Tower node
## reference; populated and maintained exclusively via the tower_placed / tower_removed /
## tower_destroyed EventBus signals. Keyed by tower_id: int -> {archetype: StringName,
## cell: Vector2i}. Untyped Dictionary, matching _monster_cache's existing style.
var _tower_cache: Dictionary = {}

## Story-005 field only — default empty (&"") means no primary class is designated yet,
## in which case ALL cached towers count as qualifying for Tower Affinity (see
## _count_qualifying_towers()). Story-006 populates this via proximity/class-unlock
## logic; this story only needs the field to exist so the qualifying-tower filter has
## something to check.
var _primary_class: StringName = &""

## Story-006 (ADR-0010): per-archetype cumulative proximity time in seconds,
## accumulated only while _proximity_active is true and the class is not yet
## locked. Keyed by archetype StringName.
var _proximity_time: Dictionary[StringName, float] = {}

## Story-006: gates the _physics_process proximity-accumulation loop. Flipped
## exactly once per phase transition via the mission_phase_changed subscription
## (_on_mission_phase_changed) — never recomputed per-frame, per the control
## manifest guardrail. True during WAVE_ACTIVE and INTERMISSION; false otherwise
## (AC-10 — SCOUT phase is excluded from proximity tracking).
var _proximity_active: bool = false

## Story-006: true once a primary class has been designated. Set the moment an
## archetype crosses CLASS_UNLOCK_THRESHOLD_S in _update_class_proximity(), and
## re-affirmed on SCOUT phase entry ONLY if _primary_class is already non-empty
## (bug fix, code review) — SCOUT entry never force-locks an undesignated
## (&"") primary class, since SCOUT is the first phase of every mission and
## doing so would permanently prevent unlocking for the rest of the
## playthrough. Once true, no other archetype can ever displace _primary_class
## (AC-11).
var _class_locked: bool = false


## Story-007 (Rule 8): the 4 active skill slots, A-D = indices 0-3. &"" means
## the slot is empty. Skills are identified by StringName ID only — the Hero
## never holds skill effect data/resources (out of scope per this story).
var _skill_slots: Array[StringName] = [&"", &"", &"", &""]

## Story-007 (Rule 9), corrected by ADR-0030 (Epic 08, Story 003): the hero's
## current Ultimate, applied verbatim from Hero Skill Build's
## ultimate_skill_changed emission. Never set directly outside of
## _on_ultimate_skill_changed() — Hero never derives this value itself.
var _ultimate_id: StringName = &""

## Story-007 (Rule 12, ADR-0010 Engine Note): one cooldown Timer per active
## skill slot (A-D), matching _attack_timer's established Timer-node pattern
## (story-003) rather than Time.get_ticks_msec() polling. Built in _ready().
## one_shot = true — each activation restarts its own slot's timer.
var _skill_cooldown_timers: Array[Timer] = []

## TD-hero-003 (fixed): the Ultimate's own cooldown Timer, independent of the
## 4 skill-slot timers (GDD Rule 10: "The Ultimate has its own cooldown defined
## by its data entry"). Discarded (stopped) on every _on_ultimate_skill_changed()
## call (ADR-0030) per GDD's mid-adventure slot-change EC — "any active
## Ultimate cooldown timer is discarded" when a source skill is removed. Built
## in _ready().
var _ultimate_cooldown_timer: Timer

## TD-hero-003 (fixed): per-second broadcast of hero_skill_cooldown_updated for
## every slot (0-3 skills, 4 = Ultimate) currently on cooldown — the story's own
## recommended fix ("a repeating Timer... emitting hero_skill_cooldown_updated
## for any slot with not timer.is_stopped()"). Built in _ready().
const COOLDOWN_BROADCAST_INTERVAL_S: float = 1.0
const ULTIMATE_SLOT_INDEX: int = 4
var _cooldown_broadcast_timer: Timer


# ---------------------------------------------------------------------------
# Story-008 (Rule 19, ADR-0002, ADR-0003): Hero Lifecycle, Death & Save
# ---------------------------------------------------------------------------

## Rule 19 state machine: IDLE_SANCTUARY -> SCOUT -> COMBAT -> INTERMISSION -> DEAD.
## Transitions are driven exclusively by the existing mission_phase_changed
## subscription (_on_mission_phase_changed, extended below) — Hero never reads
## WaveManager directly (control manifest requirement).
enum HeroPhase { IDLE_SANCTUARY, SCOUT, COMBAT, INTERMISSION, DEAD }
var _phase: HeroPhase = HeroPhase.IDLE_SANCTUARY

## restore_order is NOT a readable const/property inspected by SavePersistence —
## it is a call-site argument to GSavePersistence.register(). Declared as a
## const here purely so the value used at the _ready() call site is documented
## and named, matching this file's existing const-for-tuning-value style.
const RESTORE_ORDER: int = 30

## Current / max HP. max_hp is resolved from get_effective_stat(&"max_hp")
## in reset_to_defaults() — see that method's doc comment re: the known
## pre-HeroResource-wiring gap (returns 0.0 in production until a later story
## wires real hero data).
var _current_hp: float = 0.0
var _max_hp: float = 0.0

## Epic 15 Story 005 (ADR-0037): Node3D visual-companion subtree, holding
## Hero's MeshInstance3D-bearing mesh instance. Built once in _ready() (Hero
## has no configure()-style build-time method the way TowerInstance/
## MonsterInstance do — it is a single scene-resident instance, not spawned
## through a factory call) — see _build_visual_companion()'s own doc comment.
## Per-frame position sync happens from inside Hero's EXISTING
## _physics_process() (see _sync_visual_companion_position(), called from
## there) — no new _process()/_physics_process() callback is added anywhere
## in this file.
var _visual_companion: Node3D = null

## Resolves a hero stat's effective value per ADR-0010 Formula 1:
##   effective = max(0, max(0, base + flat) x clamp(1 + additive, 0.25, 4.0))
##
## Rounding convention: no rounding is applied. The raw float is returned so downstream
## formulas (Tower Affinity - story-005, auto-attack damage - story-003, CDR - story-007)
## keep full precision; callers needing display precision round at the presentation layer.
## This is the story's documented, consistent rounding convention (AC-01).
##
## Per-stat caps (crit_chance, elemental_resist_fire/frost, lifesteal, cdr) are applied
## after the Formula 1 result, per story-001 Tuning Knobs.
func get_effective_stat(stat_name: StringName) -> float:
	var base: float = _base_stats.get(stat_name, 0.0)
	var flat: float = _flat_bonuses.get(stat_name, 0.0)
	var additive: float = _additive_bonuses.get(stat_name, 0.0)
	var intermediate: float = maxf(0.0, base + flat)
	var multiplier: float = 1.0 + clampf(additive, ADDITIVE_BONUS_FLOOR, ADDITIVE_BONUS_CAP)
	var effective: float = maxf(0.0, intermediate * multiplier)
	if stat_name == &"tower_affinity":
		effective = _apply_tower_affinity_bonus(effective)
	return _apply_stat_cap(stat_name, effective)


## Hero Combat & Stats Redesign (2026-09-18), Section 3.4.2: Luck contributes
## a secondary Crit Chance source on top of the dedicated Crit Chance stat,
## each independently diminishing-curved (get_effective_stat handles that per
## stat), then summed and re-clamped to CRIT_CHANCE_CAP so a heavily-stacked
## build can never exceed the "never quite guaranteed" ceiling even with both
## sources maxed. Both auto-attack and skill-cast crit rolls use this instead
## of a bare get_effective_stat(&"crit_chance") read.
func _effective_crit_chance() -> float:
	var combined: float = get_effective_stat(&"crit_chance") + get_effective_stat(&"luck")
	return minf(combined, CRIT_CHANCE_CAP)


## Diminishing-returns curve (Hero Combat & Stats Redesign, 2026-09-18):
## Actual = (Raw x HardCap) / (Raw + ScalingConstant). Raw <= 0 short-circuits
## to 0.0 (avoids a needless divide when there is nothing to diminish, and
## keeps a negative Formula-1 intermediate — already impossible per
## get_effective_stat()'s own maxf(0.0, ...) floor — from ever reaching this
## function in a way that could misbehave).
static func _diminishing_curve(raw: float, hard_cap: float, scaling_constant: float) -> float:
	if raw <= 0.0:
		return 0.0
	return (raw * hard_cap) / (raw + scaling_constant)


## Applies the per-stat post-formula cap (story-001 Tuning Knobs), if any, to an
## already-resolved Formula 1 value. Stats with no defined cap pass through
## unchanged. crit_chance/crit_multiplier/luck use the diminishing-returns
## curve above (Hero Combat & Stats Redesign, 2026-09-18) instead of a flat
## clamp; crit_multiplier's curve computes only the BONUS portion, with
## CRIT_MULTIPLIER_BASE added on top so this function's return value is
## always the full, ready-to-use multiplier (callers never add the base
## separately anymore).
func _apply_stat_cap(stat_name: StringName, value: float) -> float:
	match stat_name:
		&"crit_chance":
			return _diminishing_curve(value, CRIT_CHANCE_CAP, CRIT_CHANCE_SCALING_CONSTANT)
		&"crit_multiplier":
			return CRIT_MULTIPLIER_BASE + _diminishing_curve(value, CRIT_MULTIPLIER_BONUS_CAP, CRIT_MULTIPLIER_SCALING_CONSTANT)
		&"luck":
			return _diminishing_curve(value, LUCK_CAP, LUCK_SCALING_CONSTANT)
		&"elemental_resist_fire", &"elemental_resist_frost":
			return minf(value, ELEMENTAL_RESIST_CAP)
		&"lifesteal":
			return minf(value, LIFESTEAL_CAP)
		&"cdr":
			return minf(value, CDR_CAP)
		_:
			return value


## Story-005 (ADR-0010 Formula 2): multiplies the Formula-1-resolved tower_affinity base
## value by a sqrt-scaling bonus derived from the current qualifying tower count. Never
## cached as a field — recomputed on every read via _count_qualifying_towers(), per the
## control manifest requirement that effective stat reads always recompute.
func _apply_tower_affinity_bonus(base_result: float) -> float:
	var qualifying: int = _count_qualifying_towers()
	var bonus_multiplier: float = clampf(
		sqrt(float(qualifying) / TOWERS_AFFINITY_REFERENCE),
		0.0,
		TOWER_AFFINITY_BONUS_CAP
	)
	return base_result * bonus_multiplier


## Story-005 (ADR-0010): counts _tower_cache entries that qualify for Tower Affinity.
## When no primary class is set (_primary_class == &"", the default pre-Story-006 state),
## ALL cached towers qualify — ADR-0010's _recompute_tower_affinity() treats "no primary
## class" as "unfiltered count", not "zero qualifying". O(tower_cache_size); called only
## on a tower_affinity stat read, never per-frame or cached.
func _count_qualifying_towers() -> int:
	if _primary_class == &"":
		return _tower_cache.size()
	var count: int = 0
	for tower_id: int in _tower_cache:
		var entry: Dictionary = _tower_cache[tower_id] as Dictionary
		if entry["archetype"] == _primary_class:
			count += 1
	return count


# ---------------------------------------------------------------------------
# Story-002 (S4-04): Movement & Position Tracking
# ---------------------------------------------------------------------------

## Builds the hero's collision shape and layer/mask (see class doc comment for the
## convention this establishes). No Hero.tscn exists yet (S4-09 assembles the real
## mission scene) — the shape is built in code so move_and_slide() collision response
## (Rule 27) is real and testable before that scene exists.
func _ready() -> void:
	collision_layer = COLLISION_LAYER_HERO
	collision_mask = COLLISION_LAYER_ENVIRONMENT

	var shape := CircleShape2D.new()
	shape.radius = HERO_COLLISION_RADIUS
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)

	_attack_timer = Timer.new()
	_attack_timer.wait_time = AUTO_ATTACK_INTERVAL_S
	_attack_timer.one_shot = false
	_attack_timer.autostart = true
	add_child(_attack_timer)
	_attack_timer.timeout.connect(_on_attack_timer_timeout)

	# Story-007 (Rule 12, ADR-0010 Engine Note): one one-shot cooldown Timer per
	# active skill slot (A-D). Not autostarted — a slot's timer only starts once
	# that slot's skill is actually activated (_start_cooldown_timer()).
	_skill_cooldown_timers.clear()
	for _i in range(4):
		var cooldown_timer := Timer.new()
		cooldown_timer.one_shot = true
		cooldown_timer.autostart = false
		add_child(cooldown_timer)
		_skill_cooldown_timers.append(cooldown_timer)

	# TD-hero-003 (fixed): Ultimate's own cooldown timer + per-second broadcast timer.
	_ultimate_cooldown_timer = Timer.new()
	_ultimate_cooldown_timer.one_shot = true
	_ultimate_cooldown_timer.autostart = false
	add_child(_ultimate_cooldown_timer)

	_cooldown_broadcast_timer = Timer.new()
	_cooldown_broadcast_timer.wait_time = COOLDOWN_BROADCAST_INTERVAL_S
	_cooldown_broadcast_timer.one_shot = false
	_cooldown_broadcast_timer.autostart = true
	add_child(_cooldown_broadcast_timer)
	_cooldown_broadcast_timer.timeout.connect(_on_cooldown_broadcast_timeout)

	# TD-hero-006 (fixed 2026-09-02): self-populate from GGameDataRegistry's
	# real 32-skill catalogue if empty, mirroring MonsterManager/TowerSystem's
	# established self-populate-if-empty pattern (S5-01). Only self-populates
	# when empty so _inject_skill_data() (test seam) still works exactly as
	# before — a test that injects fixture data runs after this and overwrites
	# the field wholesale regardless. Previously read get_all_skill_resources()
	# (the legacy, unrelated 4-skill catalogue) — see this field's own doc
	# comment above and TD-hero-006 in docs/tech-debt-register.md.
	if _skill_cooldowns.is_empty():
		for skill_id: StringName in GGameDataRegistry.get_all_skill_definitions():
			var skill: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(skill_id)
			_skill_cooldowns[skill_id] = skill.base_cooldown

	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.monster_cell_entered.connect(_on_monster_cell_entered)
	GEventBus.monster_died.connect(_on_monster_died)
	GEventBus.monsters_died_batch.connect(_on_monsters_died_batch)
	GEventBus.wave_completed.connect(_on_wave_completed)

	GEventBus.tower_placed.connect(_on_tower_placed)
	GEventBus.tower_removed.connect(_on_tower_removed)
	GEventBus.tower_destroyed.connect(_on_tower_destroyed)

	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)

	GEventBus.active_skill_equipped.connect(_on_active_skill_equipped)
	GEventBus.ultimate_skill_changed.connect(_on_ultimate_skill_changed)
	GEventBus.hero_ultimate_activated.connect(_on_hero_ultimate_activated)

	# Story-008: hero_damage_taken carries no target_id — Hero is the implicit
	# sole target (exactly one Hero per mission).
	GEventBus.hero_damage_taken.connect(_on_hero_damage_taken)

	# TD-story-001 AC-06 (fixed 2026-07-08): Hero owns lifesteal overheal clamping
	# per design/gdd/damage-status.md ("Hero owns lifesteal clamping... and overheal
	# clamping; D&S owns the heal-amount calculation").
	GEventBus.hero_healed.connect(_on_hero_healed)

	# Equipment-stats-wiring spec §3.1: Hero reads equipped gear passively
	# via these two signals; the initial recompute covers gear equipped in
	# the Sanctuary before this Hero existed (no signal fires for that).
	GEventBus.equipment_slot_changed.connect(_on_equipment_slot_changed)
	GEventBus.item_rune_imbued.connect(_on_item_rune_imbued)
	_recompute_equipment_bonuses()

	# Story-008 (ADR-0003): establish sane starting HP/state before this Hero
	# is registered with SavePersistence, so a scene that never explicitly
	# calls GSavePersistence.load_slot() (e.g. a quick mission start, or a
	# test) still has valid HP rather than the field defaults (0.0).
	reset_to_defaults()
	GSavePersistence.register(self, RESTORE_ORDER)

	# Epic 15 Story 005 (ADR-0037): build the 3D visual-companion subtree once
	# at _ready() — Hero has no separate build-time entry point, unlike
	# TowerInstance/MonsterInstance's configure(). See
	# _build_visual_companion()'s own doc comment.
	_build_visual_companion()


## Story-003 (S4-05) / Story-005 / Story-006 / Story-008: mandatory disconnect
## (ADR-0001 Rule 6 — every subscriber must disconnect in _exit_tree()).
func _exit_tree() -> void:
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.monster_cell_entered.disconnect(_on_monster_cell_entered)
	GEventBus.monster_died.disconnect(_on_monster_died)
	GEventBus.monsters_died_batch.disconnect(_on_monsters_died_batch)
	GEventBus.wave_completed.disconnect(_on_wave_completed)

	GEventBus.tower_placed.disconnect(_on_tower_placed)
	GEventBus.tower_removed.disconnect(_on_tower_removed)
	GEventBus.tower_destroyed.disconnect(_on_tower_destroyed)

	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)

	GEventBus.active_skill_equipped.disconnect(_on_active_skill_equipped)
	GEventBus.ultimate_skill_changed.disconnect(_on_ultimate_skill_changed)
	GEventBus.hero_ultimate_activated.disconnect(_on_hero_ultimate_activated)

	GEventBus.hero_damage_taken.disconnect(_on_hero_damage_taken)
	GEventBus.hero_healed.disconnect(_on_hero_healed)
	GEventBus.equipment_slot_changed.disconnect(_on_equipment_slot_changed)
	GEventBus.item_rune_imbued.disconnect(_on_item_rune_imbued)
	GSavePersistence.unregister(self)


func _on_equipment_slot_changed(_slot: String, _new_item_id: String, _previous_item_id: String) -> void:
	_recompute_equipment_bonuses()


func _on_item_rune_imbued(_item_id: String, _rune_id: String, _rune_source: String) -> void:
	_recompute_equipment_bonuses()


## Equipment-stats-wiring spec §3.2: fully re-derives _flat_bonuses/
## _additive_bonuses from GInventory's currently-equipped slots. Full
## replace, never incremental, so an unequipped item's contribution simply
## disappears. stat_overrides (the item's real roll) wins per-stat over the
## definition's base_stats template.
func _recompute_equipment_bonuses() -> void:
	var new_flat: Dictionary[StringName, float] = {}
	var new_additive: Dictionary[StringName, float] = {}
	for slot_name: String in Inventory.EQUIPMENT_SLOT_NAMES:
		var contents: Dictionary = GInventory.get_equipped_item(slot_name)
		if contents.is_empty():
			continue
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(contents["item_id"] as String))
		if definition == null:
			continue
		var stats: Dictionary = definition.base_stats.duplicate()
		var overrides: Dictionary = contents["stat_overrides"]
		for stat: Variant in overrides:
			stats[stat] = overrides[stat]
		for stat: Variant in stats:
			_fold_stat_entry(StringName(stat), float(stats[stat]), new_flat, new_additive)
		for rune_id: String in contents["imbued_runes"]:
			var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(StringName(rune_id))
			for stat: Variant in delta:
				_fold_stat_entry(StringName(stat), float(delta[stat]), new_flat, new_additive)
	_flat_bonuses = new_flat
	_additive_bonuses = new_additive


## Spec §3.3 key-handling rule: `additive_bonus_total` fans out into the
## additive bucket of every real stat; any other key is a flat bonus to that
## named stat. Unknown stat names are stored but never read (inert).
static func _fold_stat_entry(stat: StringName, value: float, new_flat: Dictionary[StringName, float], new_additive: Dictionary[StringName, float]) -> void:
	if stat == &"additive_bonus_total":
		for real_stat: StringName in EQUIPMENT_FAN_OUT_STATS:
			new_additive[real_stat] = new_additive.get(real_stat, 0.0) + value
	else:
		new_flat[stat] = new_flat.get(stat, 0.0) + value


## Rule 26: input polling happens in _process() per the control manifest (Core Layer
## Rules, ADR-0002) — not inside _physics_process(), which owns movement only.
func _process(_delta: float) -> void:
	_input_direction = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


## Rule 26 + Rule 28 + Story-006: movement (physics-integrated, via
## move_and_slide()), grid position tracking, and Tower-Synced Class proximity
## accumulation all run once per physics frame, per the control manifest.
func _physics_process(delta: float) -> void:
	_handle_movement()
	_update_position_tracking()
	_update_class_proximity(delta)
	# Epic 15 Story 005 (ADR-0037): the one line this story adds to Hero's
	# EXISTING _physics_process() — no new callback. Runs last so the
	# companion syncs against this frame's fully-resolved global_position
	# (move_and_slide() inside _handle_movement() has already finalized it).
	_sync_visual_companion_position()


## Rule 26: omnidirectional movement, instantaneous velocity (no acceleration curve
## at MVP). velocity = direction.normalized() x move_speed. move_and_slide() resolves
## collision against COLLISION_LAYER_ENVIRONMENT (BLOCKED cells, towers — Rule 27)
## once that geometry exists (S4-09 / tower placement).
func _handle_movement() -> void:
	velocity = _input_direction.normalized() * get_effective_stat(&"move_speed")
	move_and_slide()


## Rule 28: determines the hero's current grid cell every physics frame via the sole
## sanctioned spatial conversion (GGrid.world_to_cell — control manifest, Foundation
## Layer). Emits hero_position_changed only when the cell differs from the previous
## frame's cell (O(1) prev_cell guard — no per-frame emission). Physics caller, so the
## emission must be deferred per ADR-0001 Rule 2.
func _update_position_tracking() -> void:
	var current_cell: Vector2i = GGrid.world_to_cell(global_position)
	if current_cell != _prev_cell:
		_prev_cell = current_cell
		GEventBus.hero_position_changed.emit.call_deferred(current_cell)


# ---------------------------------------------------------------------------
# Story-006 (ADR-0010): Tower-Synced Class Proximity
# ---------------------------------------------------------------------------

## Story-006 (ADR-0010 Tower-Synced Class, MVP scope — see CLASS_UNLOCK_THRESHOLD_S
## doc comment for what is deliberately out of scope here). Accumulates
## per-archetype proximity time for towers within CLASS_PROXIMITY_RADIUS Chebyshev
## cells of the hero, while _proximity_active is true and no class is locked yet.
## The FIRST archetype whose accumulated time reaches CLASS_UNLOCK_THRESHOLD_S
## becomes _primary_class and locks immediately (AC-11) — this happens right here
## in _physics_process, not deferred to SCOUT-phase entry (that deferral is
## ADR-0010's fuller model; out of scope for this story).
##
## O(tower_cache_size) per frame; early-exits via the _proximity_active /
## _class_locked guard during SCOUT and all other phases (control manifest
## budget: ≤ 0.3 ms/frame at realistic tower counts, ≤ 50).
##
## Physics caller — hero_class_unlocked emission must be deferred (ADR-0001
## Rule 2), matching _update_position_tracking()'s existing
## hero_position_changed.emit.call_deferred() pattern.
func _update_class_proximity(delta: float) -> void:
	if not _proximity_active or _class_locked:
		return
	var hero_cell: Vector2i = GGrid.world_to_cell(global_position)
	for tower_id: int in _tower_cache:
		var entry: Dictionary = _tower_cache[tower_id] as Dictionary
		var tower_cell: Vector2i = entry["cell"] as Vector2i
		var dist: int = maxi(abs(hero_cell.x - tower_cell.x), abs(hero_cell.y - tower_cell.y))
		if dist <= CLASS_PROXIMITY_RADIUS:
			var arch: StringName = entry["archetype"] as StringName
			_proximity_time[arch] = _proximity_time.get(arch, 0.0) + delta
			if _proximity_time[arch] >= CLASS_UNLOCK_THRESHOLD_S:
				_primary_class = arch
				_class_locked = true
				# is_deep=false: this story only implements the 30s primary unlock.
				# The 90s deep-unlock case (is_deep=true) is out of scope — see
				# CLASS_UNLOCK_THRESHOLD_S doc comment.
				GEventBus.hero_class_unlocked.emit.call_deferred(arch, false)
				break


## Story-006: mission_phase_changed subscription (added this story — hero.gd did
## not previously subscribe to this signal). Gates _proximity_active per
## ADR-0010: proximity accumulation only during WAVE_ACTIVE/INTERMISSION,
## excluded during SCOUT and all other phases (AC-10). Also force-locks class
## designation on SCOUT phase entry, per the story's own Implementation Notes
## sketch — belt-and-suspenders alongside the immediate lock inside
## _update_class_proximity(): once _class_locked is true (by either path),
## _update_class_proximity() short-circuits and _primary_class can never change
## again (AC-11).
##
## Real signal (verified against src/foundation/event_bus/event_bus.gd):
##   mission_phase_changed(previous_phase: String, new_phase: String, timestamp: float)
## 3 args, String not StringName — this story's original 1-arg StringName sketch
## was stale and does not match the actual EventBus signature; corrected during
## readiness review.
##
## Bug fix (code review, this story): the SCOUT branch previously force-set
## _class_locked = true unconditionally, even when _primary_class was still
## &"" (no archetype had ever crossed CLASS_UNLOCK_THRESHOLD_S). Since SCOUT is
## the FIRST phase of every mission (design/gdd/hero.md's phase table), this
## permanently disabled Tower-Synced Class unlocking after the very first
## SCOUT transition for any playthrough that hadn't already unlocked a class —
## i.e. nearly all of them. Fix: only force-lock on SCOUT entry if a primary
## class has actually been designated; otherwise leave _class_locked false so
## proximity accumulation can resume on the next WAVE_ACTIVE/INTERMISSION entry
## (design/gdd/hero.md:337 — "no classes unlocked when SCOUT begins... is a
## valid early-game state", not a permanent one). Full death/mission-restart
## reset semantics for _proximity_time remain Story 008's scope (Save &
## Persistence) — not addressed here.
##
## Story-008 (Rule 19) EXTENDS this same method (does not duplicate it) to
## additionally drive the HeroPhase state machine from the identical new_phase
## values already being matched here for proximity gating. Real mission phase
## strings (verified against src/gameplay/wave_manager.gd's Phase enum and
## src/foundation/save_persistence/save_persistence.gd's own "SANCTUARY"
## check): SANCTUARY, SCOUT, PRE_WAVE, WAVE_ACTIVE, INTERMISSION,
## MISSION_COMPLETE, DEFEAT. Note this deviates from this story's own
## Acceptance Criteria wording ("DEFEAT"/"VICTORY" -> DEAD) — no "VICTORY"
## phase string exists anywhere in this codebase; the real win-condition phase
## name is "MISSION_COMPLETE" (WaveManager.Phase.MISSION_COMPLETE). Both
## DEFEAT and MISSION_COMPLETE transition Hero to DEAD (mission over either
## way; Hero has no distinct "victory" pose/state at MVP).
func _on_mission_phase_changed(_previous_phase: String, new_phase: String,
		_timestamp: float) -> void:
	match new_phase:
		"WAVE_ACTIVE":
			_proximity_active = true
			_phase = HeroPhase.COMBAT
		"INTERMISSION":
			_proximity_active = true
			_phase = HeroPhase.INTERMISSION
		"SCOUT":
			_proximity_active = false
			if _primary_class != &"":
				_class_locked = true
			_phase = HeroPhase.SCOUT
		"SANCTUARY":
			_proximity_active = false
			_phase = HeroPhase.IDLE_SANCTUARY
		"MISSION_COMPLETE":
			_proximity_active = false
			_phase = HeroPhase.DEAD
			_grant_xp(MISSION_COMPLETION_XP)
		"DEFEAT":
			_proximity_active = false
			_phase = HeroPhase.DEAD
		_:
			_proximity_active = false


# ---------------------------------------------------------------------------
# Story-003 (S4-05): Auto-Attack
# ---------------------------------------------------------------------------

## Rule 3: fires unconditionally at AUTO_ATTACK_INTERVAL_S (Timer node, non-physics
## caller — ADR-0010 Engine Note). CDR does not affect this rate; the Timer's
## wait_time is a fixed constant, never derived from get_effective_stat(&"cdr").
##
## Rule 4/5/6: selects the priority target (see _select_target()) and, if one exists,
## always hits (no miss chance), rolls a crit, and emits hero_auto_attacked
## synchronously with a fully pre-computed HeroAutoAttackEvent payload — D&S needs no
## back-reference to Hero (ADR-0010).
##
## Rule 7: a swing in progress completes even if the hero moves out of range —
## satisfied structurally: range is checked only inside _select_target(), never
## re-validated after the target is chosen, so this callback never aborts a swing
## once a target has been selected.
func _on_attack_timer_timeout() -> void:
	var target_id: int = _select_target()
	if target_id == -1:
		return
	var entry: Dictionary = _monster_cache[target_id] as Dictionary

	var payload := HeroAutoAttackEvent.new()
	# GDD Formula 2 (ADR-0010): damage x (1 + tower_affinity_bonus).
	payload.base_damage = get_effective_stat(&"physical_attack") * (1.0 + get_effective_stat(&"tower_affinity"))
	payload.is_crit = randf() < _effective_crit_chance()
	payload.target_id = target_id
	# CRIT_MULTIPLIER_BASE is now folded into get_effective_stat() itself
	# (Hero Combat & Stats Redesign, 2026-09-18, _apply_stat_cap()) — no
	# longer added here separately.
	payload.crit_multiplier_effective = get_effective_stat(&"crit_multiplier")
	payload.hero_lifesteal_fraction = get_effective_stat(&"lifesteal")
	payload.hero_bonus_tier = entry.get("tier", 0) as int
	# Auto-attack is always physical (Hero Combat & Stats Redesign,
	# 2026-09-18, Section 3.5) — damage_type left at its "physical" default,
	# target_elemental_resist left at its 0.0 default (never consulted for a
	# physical hit).
	payload.target_armor = entry.get("armor", 0.0) as float
	payload.target_evasion = entry.get("evasion", 0.0) as float
	payload.hero_level = _current_level
	GEventBus.hero_auto_attacked.emit(payload)


## Rule 4: target priority —
##   (1) highest cached path_step (furthest along the route / closest to GOAL)
##       among monsters within get_effective_stat(&"attack_range") world units of
##       the hero's global_position (attack_range is a world-unit distance, not a
##       cell count — GGrid.cell_to_world() converts the cached cell for comparison,
##       mirroring how Tower System's is_in_range() does its own range check);
##   (2) tie -> lower cached hp;
##   (3) tie -> first in cache iteration order (Dictionary iteration order in
##       GDScript 4.x is insertion order — satisfied naturally by only overwriting
##       the current best on a strict improvement, never on an exact tie).
## Returns -1 when no monster is in range.
func _select_target() -> int:
	var attack_range: float = get_effective_stat(&"attack_range")
	var best_id: int = -1
	var best_step: int = -1
	var best_hp: float = INF
	for entity_id: int in _monster_cache:
		var entry: Dictionary = _monster_cache[entity_id] as Dictionary
		var cell: Vector2i = entry["cell"] as Vector2i
		var world_pos: Vector2 = GGrid.cell_to_world(cell)
		if global_position.distance_to(world_pos) > attack_range:
			continue
		var step: int = entry["path_step"] as int
		var hp: float = entry["hp"] as float
		if step > best_step or (step == best_step and hp < best_hp):
			best_step = step
			best_hp = hp
			best_id = entity_id
	return best_id


## Story-003 (S4-05) monster cache population — same pattern as Tower System's
## monster cache (ADR-0007 precedent). Tier is resolved once here via
## GameDataRegistry (S4-02) since MonsterResource.tier is immutable per monster type.
func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	var resource: MonsterResource = GGameDataRegistry.get_monster_resource(payload.monster_id)
	_monster_cache[payload.entity_id] = {
		"cell": payload.grid_position,
		"hp": payload.hp_max,
		"monster_id": payload.monster_id,
		"tier": resource.tier if resource != null else 0,
		"path_step": 0,
		# Hero Combat & Stats Redesign (2026-09-18): cached once at spawn
		# (immutable per monster type, same reasoning as "tier" above) so
		# _on_attack_timer_timeout()/_resolve_skill_hit() can resolve target
		# mitigation without a second GameDataRegistry lookup per attack.
		"armor": resource.armor if resource != null else 0.0,
		"evasion": resource.evasion if resource != null else 0.0,
		"elemental_resistances": resource.elemental_resistances if resource != null else {},
	}


## path_step_index is the real substitute for a continuous path-progress float:
## a higher index means further along the route (closer to the GOAL), which is all
## Rule 4's target-priority formula needs.
func _on_monster_cell_entered(entity_id: int, grid_cell: Vector2i, path_step_index: int) -> void:
	if _monster_cache.has(entity_id):
		var entry: Dictionary = _monster_cache[entity_id] as Dictionary
		entry["cell"] = grid_cell
		entry["path_step"] = path_step_index


## Removes the monster from the cache — no longer a valid attack target.
## Hero Leveling System (2026-09-19): also grants kill XP by distance band
## (Formula L2) -- resolved BEFORE the cache erase line only in the sense
## that both read payload's own fields, never _monster_cache, so ordering
## between these two lines does not matter; kept in this order (XP first)
## purely for readability (XP is this handler's newer, less structural
## concern).
func _on_monster_died(payload: MonsterDiedEvent) -> void:
	_grant_xp(_resolve_kill_xp_band(payload))
	_monster_cache.erase(payload.entity_id)


## Hero Leveling System (2026-09-19): batched deaths (DEATH_BATCH_THRESHOLD
## exceeded, monster_manager.gd) resolve kill XP identically to individual
## monster_died -- Hero had no subscription to this signal before this
## addition (it only ever needed per-entity cache cleanup, which
## monsters_died_batch's own emitter does not require of subscribers).
## Each entry resolved independently, matching ResourceEconomy's own
## established "no shared/batched rounding state across a batch" precedent.
func _on_monsters_died_batch(payloads: Array[MonsterDiedEvent]) -> void:
	for payload: MonsterDiedEvent in payloads:
		_grant_xp(_resolve_kill_xp_band(payload))
		_monster_cache.erase(payload.entity_id)


## Hero Leveling System (2026-09-19), Section 3.2: flat XP per wave clear.
## was_boss_breached is ignored -- wave_completed fires once per wave clear
## regardless of breach outcome, and this XP source is deliberately
## unconditional per the governing spec (no partial-credit/breach-penalty
## rule was specified).
func _on_wave_completed(_wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	_grant_xp(WAVE_COMPLETION_XP)


# ---------------------------------------------------------------------------
# Story-005 (ADR-0010): Tower Cache
# ---------------------------------------------------------------------------

## Populates the tower cache from the tower_placed payload. archetype arrives
## as String on this payload; cast to StringName for Hero's StringName
## stat/archetype convention. Only tower_id/archetype/grid_position are
## needed by Tower Affinity.
## Amendment 2026-07-19 (Epic 06 Story 008): tower_placed promoted to a
## TowerPlacedEvent Resource payload.
func _on_tower_placed(payload: TowerPlacedEvent) -> void:
	_tower_cache[payload.tower_id] = {"archetype": StringName(payload.archetype), "cell": payload.grid_position}


## Voluntary removal (SCOUT/INTERMISSION) — erase from cache. grid_position/archetype
## are not needed once the entry is being erased.
func _on_tower_removed(tower_id: int, _grid_position: Vector2i, _archetype: String, _constellation_eligibility_tag: String) -> void:
	_tower_cache.erase(tower_id)


## Mid-wave destruction — erase from cache. Functionally identical to
## _on_tower_removed; kept as a separate handler per ADR-0010's three-signal
## subscription contract (tower_placed / tower_removed / tower_destroyed).
func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, _archetype: String,
		_footprint: Array, _constellation_eligibility_tag: String) -> void:
	_tower_cache.erase(tower_id)


# ---------------------------------------------------------------------------
# Story-007 (TR-hero-005): Hero Skill System
# ---------------------------------------------------------------------------

## Test-only injection seam overriding the registry-self-populated
## _skill_cooldowns field (see its doc comment — TD-hero-002). Mirrors this
## codebase's established _inject() pattern (GameDataRegistry,
## PathfindingSystem, SceneManager). Call before exercising activate_skill() /
## slot assignment in tests; production code never calls this.
func _inject_skill_data(cooldowns: Dictionary[StringName, float]) -> void:
	_skill_cooldowns = cooldowns


## Rule 8: assigns a skill to an active slot (A-D) — bookkeeping only, for
## activate_skill()'s per-slot skill_id/cooldown lookup. Real signal signature
## (verified against src/foundation/event_bus/event_bus.gd):
## active_skill_equipped(slot_index: int, skill_id: String) — "Player assigns
## a skill to an active slot at Sanctuary." Hero SUBSCRIBES to this signal
## (connected in _ready(), disconnected in _exit_tree(), matching every other
## EventBus subscription in this file) — it does not expose a public
## assign_skill() API.
##
## ADR-0030 correction (Story 003, Epic 08): this handler previously also
## called _recompute_ultimate() to independently derive the Ultimate from
## _skill_slots — removed. Hero Skill Build (Autoload #13) now owns Ultimate
## derivation entirely and is the sole emitter of active_skill_equipped in
## production; Hero only ever applies the resolved ultimate_id it receives
## via ultimate_skill_changed (_on_ultimate_skill_changed() below), never
## re-deriving it from raw skill IDs (Rule 9's ownership boundary).
func _on_active_skill_equipped(slot_index: int, skill_id: String) -> void:
	assert(slot_index >= 0 and slot_index < 4, "Slot index must be 0-3")
	_skill_slots[slot_index] = StringName(skill_id)


## Rule 9 / Rule 10 / AC-12 (ADR-0030): applies the resolved Ultimate ID
## verbatim from Hero Skill Build's emission — Hero never re-derives it.
## Discards any active Ultimate cooldown timer unconditionally (GDD Rule 10
## EC: "any active Ultimate cooldown timer is discarded" whenever the active-
## skill combination changes) — Hero Skill Build re-emits ultimate_skill_changed
## on every active-slot change, even when the resolved ID is unchanged
## (AC-11), so discarding here on every receipt correctly reproduces the EC
## without Hero needing to detect the change itself.
func _on_ultimate_skill_changed(ultimate_id: String) -> void:
	_ultimate_id = StringName(ultimate_id)
	_ultimate_cooldown_timer.stop()


## Rule 12: activates the skill in the given slot (A-D). No-op if the slot is
## empty (Rule 8 edge case — no event emitted, no timer started). No-op if the
## slot's cooldown Timer is still running (code review fix — without this
## guard the Timer was cosmetic: nothing enforced it, so a slot could be
## reactivated instantly with zero rate-limiting). CDR is resolved fresh via
## get_effective_stat(&"cdr") every activation — never cached (control manifest
## requirement) — and applied per Rule 12's formula: effective_cooldown =
## base_cooldown x (1 - cdr), floored at 0.5s.
##
## TD-hero-001 (Skill Power implementation, 2026-08-26): also resolves the
## cast's damage via _resolve_skill_hit() — see that method's own doc comment.
## This closes the previous "no consumer of hero_skill_activated" gap
## (skill_resource.gd's original doc comment, and this method's own prior
## comment below) — damage-status.md Rule IX/Formula D7 now exists and is
## wired here as the emitting side.
func activate_skill(slot_index: int) -> void:
	var skill_id: StringName = _skill_slots[slot_index]
	if skill_id == &"":
		return
	if not _skill_cooldown_timers[slot_index].is_stopped():
		return  # still on cooldown — reject reactivation
	var base_cooldown: float = _skill_cooldowns.get(skill_id, 0.0)
	var cdr: float = get_effective_stat(&"cdr")  # capped at CDR_CAP (0.75) by Formula 1
	var effective_cooldown: float = maxf(0.5, base_cooldown * (1.0 - cdr))
	_start_cooldown_timer(slot_index, effective_cooldown)
	# Real signal: hero_skill_activated(skill_id: String, target_position: Vector2)
	# — not "hero_skill_used" (that signal does not exist). String, not
	# StringName — cast at emit time.
	GEventBus.hero_skill_activated.emit(String(skill_id), global_position)
	_resolve_skill_hit(skill_id)


## TD-hero-001 (Skill Power implementation, 2026-08-26): resolves the single
## priority target this MVP skill cast strikes, reusing _select_target()'s
## exact auto-attack target-priority logic (design/gdd/damage-status.md Rule
## IX explicitly leaves "which target(s) a skill cast struck" to Hero
## System's own resolution — not specified further by that GDD). A no-target
## cast still consumes the skill's cooldown (already started in
## activate_skill() above) but emits no hero_skill_attacked — the cast
## simply whiffs, mirroring _on_attack_timer_timeout()'s identical no-target
## early return. Multi-target/AoE resolution (Rule IX.8's elem_firestorm
## example) is not implemented here regardless of a skill's own `delivery`
## value (e.g. `aoe_zone`) — every cast resolves as a single hit against
## _select_target()'s one priority target; a future pass would need this
## method extended to emit one HeroSkillAttackEvent per struck target, per
## Rule IX.8's explicit requirement. TD-hero-006 (2026-09-02) fixed this
## method reading the wrong skill catalogue entirely (see below) but did not
## change this single-target scoping.
func _resolve_skill_hit(skill_id: StringName) -> void:
	var target_id: int = _select_target()
	if target_id == -1:
		return
	# TD-hero-006 (fixed 2026-09-02): previously read GGameDataRegistry.
	# get_skill_resource() (the legacy, unrelated 4-skill catalogue) — every
	# real, player-equippable skill_id resolved to null here and this
	# function returned before ever emitting hero_skill_attacked, so no
	# equipped skill dealt any damage. Now reads the real catalogue
	# (SkillDefinitionResource.effect_data.skill_power_coefficient), matching
	# damage-status.md's own Formula D7 doc, which always said this value
	# comes from "the cast skill's effect_data" — the GDD was correct; only
	# the code was wrong. See docs/tech-debt-register.md TD-hero-006.
	var skill: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(skill_id)
	if skill == null or skill.effect_data == null:
		return
	var entry: Dictionary = _monster_cache[target_id] as Dictionary
	# "" (non-damage support/buff skill) normalizes to "physical" here —
	# matches this codebase's existing behavior of always emitting a real
	# damage hit regardless of a skill's effect_data.damage_type (D&S has
	# never gated on it); Section 3.6 flags this as a separate, out-of-scope
	# question this redesign does not attempt to resolve.
	var damage_type: String = skill.effect_data.damage_type
	if damage_type == "":
		damage_type = "physical"
	var attack_stat: StringName = &"physical_attack" if damage_type == "physical" else &"magic_attack"
	var elemental_resistances: Dictionary = entry.get("elemental_resistances", {}) as Dictionary
	var payload := HeroSkillAttackEvent.new()
	payload.skill_id = skill_id
	payload.target_id = target_id
	# GDD Formula 2: effective_attack_final = effective_attack x
	# (1 + tower_affinity_bonus) — identical shape to
	# _on_attack_timer_timeout()'s base_damage line.
	payload.skill_power = get_effective_stat(attack_stat) * (1.0 + get_effective_stat(&"tower_affinity"))
	payload.skill_power_coefficient = skill.effect_data.skill_power_coefficient
	payload.is_crit = randf() < _effective_crit_chance()
	# CRIT_MULTIPLIER_BASE is now folded into get_effective_stat() itself
	# (Hero Combat & Stats Redesign, 2026-09-18, _apply_stat_cap()).
	payload.crit_multiplier_effective = get_effective_stat(&"crit_multiplier")
	payload.hero_bonus_tier = entry.get("tier", 0) as int
	payload.damage_type = damage_type
	payload.target_armor = entry.get("armor", 0.0) as float
	payload.target_evasion = entry.get("evasion", 0.0) as float
	payload.target_elemental_resist = elemental_resistances.get(damage_type, 0.0) as float
	payload.hero_level = _current_level
	GEventBus.hero_skill_attacked.emit(payload)


## Rule 8: starts (restarting if already running) the given slot's dedicated
## cooldown Timer — each slot's cooldown is fully independent of the other 3.
func _start_cooldown_timer(slot_index: int, effective_cooldown: float) -> void:
	var timer: Timer = _skill_cooldown_timers[slot_index]
	timer.stop()
	timer.wait_time = effective_cooldown
	timer.start()


## TD-hero-003 (fixed): Hero SUBSCRIBES to hero_ultimate_activated (fired by
## Mission HUD when the player presses the Ultimate button) — mirrors
## activate_skill()'s no-op/reject-reactivation guard pattern. No-op if no
## Ultimate is currently resolved (Rule 10 EC: empty slots or no table entry
## -> _ultimate_id == &""). No-op if still on cooldown (reject reactivation).
## Rule 12's CDR formula does NOT apply here — it is explicitly scoped to
## "active skill cooldowns" only; the raw data-defined cooldown is used as-is.
## No effect resolution — same gap as activate_skill() (no consumer of
## hero_skill_activated/an Ultimate-effect signal exists anywhere yet).
func _on_hero_ultimate_activated() -> void:
	# "EMPTY" is Hero Skill Build's own sentinel for "fewer than 4 slots
	# filled" (ADR-0030) — never a real, cooldown-having ultimate_id. Guarded
	# here alongside the pre-Hero-Skill-Build &"" default so a no-resolved-
	# Ultimate activation attempt is a silent no-op, not a spurious
	# "no cooldown data" error log (code review fix).
	if _ultimate_id == &"" or _ultimate_id == &"EMPTY":
		return
	if not _ultimate_cooldown_timer.is_stopped():
		return
	var table: UltimateComboTable = GGameDataRegistry.get_ultimate_combo_table()
	var cooldown: float = 0.0 if table == null else table.get_cooldown_for_ultimate(_ultimate_id)
	if cooldown <= 0.0:
		push_error("[Hero] No cooldown data for ultimate_id '%s' — Ultimate not activated." % _ultimate_id)
		return
	_ultimate_cooldown_timer.stop()
	_ultimate_cooldown_timer.wait_time = cooldown
	_ultimate_cooldown_timer.start()


## TD-hero-003 (fixed): fires every COOLDOWN_BROADCAST_INTERVAL_S (1s) for
## Mission HUD's cooldown-fill display (design/gdd/hero.md Row 489). Slots 0-3
## are the 4 active skills; ULTIMATE_SLOT_INDEX (4) is the Ultimate — "Same
## mechanism as skill buttons" per the GDD's own UI Requirements note. Only
## slots currently on cooldown broadcast (the story's own recommended fix).
func _on_cooldown_broadcast_timeout() -> void:
	for i: int in range(_skill_cooldown_timers.size()):
		var timer: Timer = _skill_cooldown_timers[i]
		if not timer.is_stopped():
			GEventBus.hero_skill_cooldown_updated.emit(i, timer.time_left, timer.wait_time)
	if not _ultimate_cooldown_timer.is_stopped():
		GEventBus.hero_skill_cooldown_updated.emit(
				ULTIMATE_SLOT_INDEX, _ultimate_cooldown_timer.time_left, _ultimate_cooldown_timer.wait_time)


# ---------------------------------------------------------------------------
# Story-008 (Rule 19/20, AC-13, ADR-0002, ADR-0003): Hero Lifecycle, Death & Save
# ---------------------------------------------------------------------------

## Rule 20 + AC-13: real signal (verified against src/foundation/event_bus/event_bus.gd):
## hero_damage_taken(amount: int, source_type: int) — "Deferred one frame from
## hero_incoming_damage after D4 armor reduction applied." Carries no target_id;
## Hero is the implicit sole target (exactly one Hero per mission).
##
## Rule 20: outside COMBAT/INTERMISSION (i.e. IDLE_SANCTUARY, SCOUT, or DEAD),
## this is a no-op — no HP change, no hero_health_changed emission, no death check.
##
## AC-13: on lethal damage (HP <= 0 after this hit), hero_died fires
## synchronously from this same non-physics callback — no call_deferred, no
## 1-frame delay (ADR-0002 Rule 2 permits synchronous emission from
## non-physics callers). _phase is also set to DEAD directly here (not just
## via the mission_phase_changed round-trip below) so Hero's own DEAD state is
## guaranteed same-frame and self-contained, independent of WaveManager's
## internal locking state.
##
## TD-hero-005 (fixed 2026-07-08): this method used to ALSO directly emit
## mission_phase_changed(..., "DEFEAT", ...) itself. That was a real bug, not
## a design choice — WaveManager._on_hero_died() (Story 001, epic-04) is ALSO
## connected to hero_died and ALSO calls _transition_to(Phase.DEFEAT), which
## emits its own mission_phase_changed("DEFEAT") with proper _phase_locked
## reentrancy guards. Both emissions fired for a single hero_died, a genuine
## duplicate-emission bug (caught by
## hero_lifecycle_test.gd::test_ac13_damage_equal_to_current_hp_triggers_death_at_exactly_zero
## expecting exactly 1 mission_phase_changed emission, observing 2). The old
## doc comment here claimed "WaveManager's own DEFEAT transition logic is
## explicitly Out of Scope for its current implementation" — true when Hero's
## own Story 008 was written (2026-07-04), but Wave Manager's Story 001
## (2026-07-05, one day later) shipped real DEFEAT handling and this comment
## was never updated to match, so the duplicate was never caught until this
## test's full-suite regression run surfaced it. Fixed by removing Hero's own
## emission — WaveManager is the sole mission-phase FSM owner (matching
## ADR-0002's architecture); Hero already correctly reacts to WAVE_MANAGER's
## mission_phase_changed("DEFEAT") via _on_mission_phase_changed()'s existing
## match arm, so no functional behavior is lost, only the duplicate emission.
func _on_hero_damage_taken(amount: int, _source_type: int) -> void:
	if _phase != HeroPhase.COMBAT and _phase != HeroPhase.INTERMISSION:
		return  # Rule 20: hero cannot be attacked in IDLE_SANCTUARY/SCOUT/DEAD
	_current_hp = maxf(0.0, _current_hp - float(amount))
	GEventBus.hero_health_changed.emit(_current_hp, _max_hp)
	if _current_hp <= 0.0:
		_phase = HeroPhase.DEAD
		GEventBus.hero_died.emit()


## TD-story-001 AC-06 (fixed 2026-07-08), GDD Formula 6: D&S already computes
## heal_amount and only emits hero_healed when it is > 0 (event_bus.gd doc
## comment). Hero's sole responsibility here is the overheal clamp —
## `min(amount, max_hp - current_hp)` — never exceeding max_hp. No-op if the
## hero is not alive (DEAD) or not yet initialized (IDLE_SANCTUARY, _max_hp==0)
## — mirrors _on_hero_damage_taken()'s Rule 20 phase guard for symmetry, since
## a heal landing on a dead/uninitialized hero is not a real scenario at MVP.
## Does NOT re-emit hero_healed (event_bus.gd: "Hero System must NOT re-emit
## from its hero_healed handler" — that note guards against re-triggering the
## same cascade, not against emitting a different signal); emits
## hero_health_changed instead, matching _on_hero_damage_taken()'s existing
## precedent for HP-change observability (Mission HUD's HP bar).
func _on_hero_healed(amount: int) -> void:
	if _phase != HeroPhase.COMBAT and _phase != HeroPhase.INTERMISSION:
		return
	_current_hp = minf(_current_hp + float(amount), _max_hp)
	GEventBus.hero_health_changed.emit(_current_hp, _max_hp)


# ---------------------------------------------------------------------------
# Story-008 (ADR-0003): SaveRestorer interface
# ---------------------------------------------------------------------------

## ADR-0003 SaveRestorer interface (per save_persistence.gd's own doc comment).
## Called by GSavePersistence._collect_save_data() to key this system's entry
## in the master save Dictionary.
func get_save_key() -> String:
	return "hero"


## ADR-0003 primitive-only rule: Dictionary keys must be String, values must be
## primitive — StringName is not in the allowed-type list, only String is.
## _proximity_time (Dictionary[StringName, float]) and _skill_slots
## (Array[StringName]) are converted to String explicitly here via str()/String()
## rather than relying on Godot's store_var() to serialize StringName keys
## natively. This is required by ADR-0003's Primitive-Only Rule regardless of
## store_var()'s actual native StringName-key behaviour in 4.6.2 (which is not
## documented in docs/engine-reference/godot/ — see this story's report for the
## explicit call made on that open question).
func get_save_data() -> Dictionary:
	var proximity_data: Dictionary = {}
	for arch: StringName in _proximity_time:
		proximity_data[String(arch)] = _proximity_time[arch]
	var slots: Array = []
	for slot_id: StringName in _skill_slots:
		slots.append(String(slot_id))
	var class_bonuses_data: Dictionary = {}
	for stat: StringName in _accumulated_class_bonuses:
		class_bonuses_data[String(stat)] = _accumulated_class_bonuses[stat]
	return {
		"hp": _current_hp,
		"proximity_time": proximity_data,
		"primary_class": String(_primary_class),
		"class_locked": _class_locked,
		"skill_slots": slots,
		"level": _current_level,
		"xp": _current_xp,
		"class_bonuses": class_bonuses_data,
	}


## Restores all Story-006/007/008 persisted fields. Returns false (not void!)
## on any malformed/missing data so SavePersistence's _restore_all_systems()
## falls back to reset_to_defaults() for this system — see that method's doc
## comment in save_persistence.gd. Validates presence and basic shape of every
## expected key before mutating any field (no partial-restore side effects on
## a rejected payload).
func restore_save_data(data: Dictionary) -> bool:
	if not (data.has("hp") and data.has("proximity_time") and data.has("primary_class")
			and data.has("class_locked") and data.has("skill_slots")
			and data.has("level") and data.has("xp") and data.has("class_bonuses")):
		return false

	var hp_value: Variant = data["hp"]
	if not (hp_value is float or hp_value is int):
		return false

	var proximity_raw: Variant = data["proximity_time"]
	if not (proximity_raw is Dictionary):
		return false

	var slots_raw: Variant = data["skill_slots"]
	if not (slots_raw is Array) or (slots_raw as Array).size() != 4:
		return false

	var class_locked_raw: Variant = data["class_locked"]
	if not (class_locked_raw is bool):
		return false

	var primary_class_raw: Variant = data["primary_class"]
	if not (primary_class_raw is String):
		return false

	var level_raw: Variant = data["level"]
	if not (level_raw is int) or (level_raw as int) < 1 or (level_raw as int) > LEVEL_CAP:
		return false

	var xp_raw: Variant = data["xp"]
	if not (xp_raw is int) or (xp_raw as int) < 0:
		return false

	var class_bonuses_raw: Variant = data["class_bonuses"]
	if not (class_bonuses_raw is Dictionary):
		return false

	var restored_proximity: Dictionary[StringName, float] = {}
	for key: Variant in (proximity_raw as Dictionary):
		var value: Variant = (proximity_raw as Dictionary)[key]
		if not (value is float or value is int):
			return false
		restored_proximity[StringName(String(key))] = float(value)

	var restored_slots: Array[StringName] = [&"", &"", &"", &""]
	for i in range(4):
		var slot_value: Variant = (slots_raw as Array)[i]
		if not (slot_value is String):
			return false
		restored_slots[i] = StringName(slot_value as String)

	var restored_class_bonuses: Dictionary[StringName, float] = {}
	for key: Variant in (class_bonuses_raw as Dictionary):
		var value: Variant = (class_bonuses_raw as Dictionary)[key]
		if not (value is float or value is int):
			return false
		restored_class_bonuses[StringName(String(key))] = float(value)

	_current_hp = float(hp_value)
	_proximity_time = restored_proximity
	_primary_class = StringName(primary_class_raw as String)
	_class_locked = class_locked_raw as bool
	_skill_slots = restored_slots
	_current_level = level_raw as int
	_current_xp = xp_raw as int
	_accumulated_class_bonuses = restored_class_bonuses
	return true


## Clears all Story-006/007/008 persisted fields to their starting values.
## Called by SavePersistence when no save data exists for this key, or when
## restore_save_data() rejects malformed data. max_hp is resolved fresh via
## get_effective_stat(&"max_hp") — returns 0.0 in production until a later
## story wires a real HeroResource (known, accepted pre-existing gap; see
## class doc comment history for Story 001/005/006).
func reset_to_defaults() -> void:
	_current_hp = get_effective_stat(&"max_hp")
	_max_hp = _current_hp
	_proximity_time.clear()
	_primary_class = &""
	_class_locked = false
	_skill_slots = [&"", &"", &"", &""]
	_phase = HeroPhase.IDLE_SANCTUARY
	_current_level = 1
	_current_xp = 0
	_accumulated_class_bonuses.clear()


## Stopgap, unchanged in effect from the two identical call sites this
## replaces (the_gap.gd's and mission_scene.gd's own _set_hero_placeholder_
## stats()) — no real HeroResource pipeline exists yet to author
## _base_stats externally (see that field's own doc comment). Both mission
## entry scenes now call this instead of poking _base_stats directly with
## their own duplicated literal, so the one placeholder value set has one
## source of truth (PLACEHOLDER_BASE_STATS above) until the real pipeline
## lands. Also calls reset_to_defaults() so _current_hp/_max_hp resolve
## against the newly-set base_stats immediately, matching both original
## call sites' own sequencing.
func apply_placeholder_base_stats() -> void:
	# Finding C1 (final review, 2026-09-19): reset_to_defaults() below also
	# resets _current_level/_current_xp to 1/0 -- this stopgap runs on
	# EVERY mission launch, well after Hero._ready()'s own correct
	# SavePersistence-driven restore already happened, so calling
	# reset_to_defaults() unguarded here was silently wiping a player's
	# real progress on every single mission entry. Save/restore level and
	# xp around this call, and re-derive/re-apply the level-up growth this
	# reseed would otherwise discard (see _reapply_persistent_level_growth()).
	# Round-2 fix (scoped re-review, 2026-09-19): _accumulated_class_bonuses
	# needs the identical save/restore treatment -- reset_to_defaults()
	# clears it unconditionally too, and the first pass of this fix missed
	# that, silently losing the ledger on a second call in the same session
	# or on the next save.
	var saved_level: int = _current_level
	var saved_xp: int = _current_xp
	var saved_class_bonuses: Dictionary[StringName, float] = _accumulated_class_bonuses.duplicate()
	_base_stats = PLACEHOLDER_BASE_STATS.duplicate()
	_current_level = saved_level
	_reapply_persistent_level_growth()
	reset_to_defaults()
	_current_level = saved_level
	_current_xp = saved_xp
	_accumulated_class_bonuses = saved_class_bonuses


# ---------------------------------------------------------------------------
# Epic 15 Story 005 (ADR-0037): 3D visual-companion subtree.
# Purely additive -- everything above this point (Hero's existing 2D
# movement/combat/skill/lifecycle logic) is unchanged, per ADR-0037's core
# constraint of zero simulation-code changes. No NEW _process()/
# _physics_process() is declared anywhere in this file -- the sync call is
# one added line inside the _physics_process() that already existed before
# this story (see that method, above). Mirrors TowerInstance's/
# MonsterInstance's identical _build_visual_companion() precedent
# (src/core/tower/tower_instance.gd, src/core/monster/monster_instance.gd),
# with the sync step also self-contained on this script (unlike Monster,
# which is driven externally by MonsterManager's centralized pass) since
# Hero is not a centrally-managed, many-instance entity type (ADR-0037's
# Decision: "TowerInstance/Hero ... sync in their own existing _process/
# _physics_process").
# ---------------------------------------------------------------------------

## Builds (or rebuilds) the Node3D visual-companion subtree holding Hero's
## MeshInstance3D-bearing mesh instance, resolved via
## GGameDataRegistry.get_visual_mesh_mapping() (data-driven per ADR-0037's
## Constraints -- never a hardcoded scene reference). Seeds the companion's
## initial position from this node's own global_position so Hero has a
## correctly-placed companion from the first visible frame, with no
## one-frame lag before _physics_process()'s first sync call.
##
## A missing/invalid mapping fails loudly (push_error) rather than silently
## rendering no visual, per ADR-0037's Risks section policy -- same policy
## TowerInstance/MonsterInstance/GridVisual already established.
##
## Called once from _ready() (see that method, above) -- Hero has no
## configure()-style re-entrant build method the way TowerInstance/
## MonsterInstance do. If this is ever called again on an already-built
## Hero, the previous companion subtree is freed and rebuilt from scratch
## rather than leaking or duplicating mesh instances.
func _build_visual_companion() -> void:
	# Synchronous remove_child() BEFORE queue_free(), not queue_free() alone
	# -- same gotcha TowerInstance's/MonsterInstance's/GridVisual's
	# _build_visual_companion() already fixed (docs/registry/architecture.yaml's
	# mission_hud_planning_cluster_lifecycle entry): queue_free() defers
	# removal to end-of-frame, so an immediately-following add_child() of a
	# new node with the SAME name ("VisualCompanion3D") while the old one is
	# still technically in the tree causes Godot to auto-uniquify the new
	# node's name -- after the deferred free runs, zero nodes are left with
	# the expected name.
	if _visual_companion != null and is_instance_valid(_visual_companion):
		remove_child(_visual_companion)
		_visual_companion.queue_free()
	_visual_companion = Node3D.new()
	_visual_companion.name = "VisualCompanion3D"
	add_child(_visual_companion)

	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(HERO_MESH_ENTITY_ID)
	if mapping == null or mapping.mesh_scene == null:
		push_error("[Hero] No valid VisualMeshMappingResource for '%s' -- hero will have no 3D visual companion." % HERO_MESH_ENTITY_ID)
		return

	var mesh_node: Node = mapping.mesh_scene.instantiate()
	if not (mesh_node is Node3D):
		push_error("[Hero] mesh_scene for '%s' did not instantiate as a Node3D -- no 3D visual companion." % HERO_MESH_ENTITY_ID)
		mesh_node.free()
		return
	_visual_companion.add_child(mesh_node)
	# ABSOLUTE assignment only, never additive/relative to this
	# CharacterBody2D's own transform -- a Node3D child of a Node2D-family
	# (CharacterBody2D extends Node2D) parent does not inherit the parent's
	# 2D transform (ADR-0037's "Important engine clarification").
	(mesh_node as Node3D).position = VisualMath.map_to_3d(global_position, HERO_LAYER_HEIGHT)


## Per-frame sync entry point -- called from _physics_process() (above),
## which already existed before this story; this is the one added line, not
## a new callback. world_position is computed fresh here (not passed in,
## unlike MonsterInstance's externally-driven sync_visual_companion_position())
## since Hero owns its own _physics_process() and is not centrally managed.
## ABSOLUTE position assignment -- never offset against this CharacterBody2D's
## own transform (ADR-0037's "Important engine clarification"). No-op if Hero
## has no companion mesh (e.g. the mapping was missing/invalid at build time
## -- see _build_visual_companion()'s own doc comment).
func _sync_visual_companion_position() -> void:
	if _visual_companion == null or not is_instance_valid(_visual_companion):
		return
	if _visual_companion.get_child_count() == 0:
		return
	var world_position: Vector3 = VisualMath.map_to_3d(global_position, HERO_LAYER_HEIGHT)
	(_visual_companion.get_child(0) as Node3D).position = world_position

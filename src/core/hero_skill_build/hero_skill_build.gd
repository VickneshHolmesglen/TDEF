class_name HeroSkillBuild
extends Node

## Autoload #13 (ADR-0030) — must remain alive and correctly-stated across
## the exact SANCTUARY->MISSION transition instant (not merely survive it):
## the system is LOCKED throughout the entire mission and must re-emit the
## currently-resolved build to a freshly-instantiated Hero at
## mission_launched, per the GDD's own States and Transitions.
##
## GDD source: design/gdd/hero-skill-build.md
## Governing ADR: docs/architecture/adr-0030-hero-skill-build-ultimate-lookup.md
##
## Story 001 (TR-heroskill-001, data model portion): the slot/catalogue data
## model only — 4 active slots (A-D) + the Ultimate slot (U, always
## derived, never directly written), the equippable-skill mirror, and
## Sanctuary-only write gating (Rule 3, mirrors tower.md Rule 3/hero.md Rule
## 18's precedent). Duplicate skill_id across active slots is a deliberate,
## valid build strategy — never blocked (Rule 2's own stated intent).
## get_category_count() is a Story-001-scoped occupied-slot tally for AC-4
## only, distinct from Story 002's stricter Formula 1 (_category_profile(),
## which requires all 4 slots filled with valid, equippable skills as an
## Ultimate-derivation precondition) — Story 002 owns the full
## category_profile -> classify_shape -> derive_ultimate_id pipeline.
##
## Story 002 (TR-heroskill-001, Formulas 1-3): the Ultimate derivation pure-
## function pipeline, named exactly per ADR-0030's own Key Interfaces code
## sample. _category_profile() (Formula 1) requires ALL 4 active slots
## filled with skill_ids that resolve to a real SkillDefinitionResource
## (Rule 7 precondition) — returns {} (empty Dictionary) if not met, which
## _derive_ultimate_id() treats as "EMPTY" (AC-6/AC-7), never partially
## evaluating Formula 2/3. _classify_shape()/_ultimate_id_for_shape()
## (Formulas 2-3) are pure functions over an arbitrary profile Dictionary —
## catalogue-independent by construction (AC-10c), never touching
## GameDataRegistry themselves. Recomputed fresh on every call, never cached
## (Guardrail) — no persisted intermediate state anywhere in this pipeline.
##
## Story 003 (TR-heroskill-001, Rule 9/AC-11/AC-12): recompute trigger and
## ownership boundary. set_active_slot() is now the sole production emitter
## of active_skill_equipped (Hero System's own bookkeeping input) and
## ultimate_skill_changed (the resolved Ultimate) — both fire on every
## successful write, even if the resolved Ultimate is unchanged (AC-11).
## Real bug found and fixed during this story: hero.gd (Epic 02) already had
## its OWN Ultimate-derivation mechanism (_ultimate_lookup/_recompute_ultimate(),
## TD-hero-002's MVP stopgap) — directly forbidden by this ADR's Rule 9
## ("Hero System must never independently compute a category profile or
## shape from raw skill IDs"). Removed from hero.gd; Hero now only subscribes
## to ultimate_skill_changed and applies the value verbatim
## (_on_ultimate_skill_changed()), per user decision (full migration, not a
## deferred-tech-debt or compatibility-shim option). _on_mission_launched()
## re-emits the full current build (deferred, per ADR-0001 Core Rule 2 — this
## handler is itself an EventBus subscriber emitting further events, a
## Level-1 cascade) so a freshly-instantiated Hero (a MissionScene child,
## recreated every mission) always receives the current build regardless of
## which scene most recently held Hero Skill Build's UI — this is Autoload
## #13's whole reason for existing (see class doc comment).
##
## Story 004 (TR-heroskill-001, Rule 12/AC-13/AC-14): passive slots as
## internal state. set_passive_slot()/get_passive_loadout() update/read
## _passive_slots directly — no EventBus event fires for a passive-slot-only
## change (Forbidden rule, resolving event-bus.md's Open Note 4). Bounded by
## the target skill's own passive_slot_count (SkillDefinitionResource) — a
## slot_index outside that range is rejected. get_passive_loadout() is a
## synchronous pull, called at UI-open time — never delivered via
## subscription, mirroring Save & Persistence's own EC-10 pull-not-push
## precedent for Sanctuary-only, non-live-combat state.
##
## Story 005 (TR-heroskill-002, Rule 11/AC-15/16/17/26): persistence boundary.
## _equippable_skills is populated exclusively via the skill_unlocked
## subscription — live in EVERY state including LOCKED (AC-17), but adding to
## the library is never a write and never triggers an Ultimate recompute (no
## active-slot/passive-slot mutation, no EventBus emission). Full SaveRestorer
## at restore_order=31 (save-persistence.md's authoritative table, corrected
## from the GDD's self-proposed 32) persists all 3 structures as primitives —
## the resolved Ultimate itself is never persisted (Guardrail), always
## recomputed fresh from restored _active_slots on the next _derive_ultimate_id()
## call. Slot assignments survive every mission-exit path (MISSION_COMPLETE,
## DEFEAT) since nothing in this system's own code ever resets them except
## reset_to_defaults() (a brand-new save only, AC-16, in lockstep with Tower
## Mastery's own reset since both are independent SaveRestorer implementations
## triggered by the same "no save data yet" condition).
##
## Story 006 (TR-heroskill-001, Edge Cases/AC-21-25): orphaned data. AC-21
## (orphaned active-slot skill_id) and AC-22 (orphaned library entry) are
## already structural — restore_save_data() never filters _active_slots/
## _equippable_skills against the current catalogue (preserves everything),
## and _category_profile() (Story 002) already treats any unresolvable
## skill_id identically to an empty slot. get_assignable_skills() is the new
## UI-facing query that hides orphaned library entries (AC-22's "not
## surfaced" half) without discarding them from _equippable_skills.
## get_effective_passive_loadout() resolves a skill's passive loadout against
## the item registry, substituting "" for any item_id that no longer exists
## in content (AC-23) — the raw _passive_slots binding itself is untouched.
## restore_save_data() also reconciles passive_slot_count reductions
## (AC-24): any loadout entries beyond a skill's CURRENT passive_slot_count
## are trimmed (so only current sockets render) and their bound item is
## returned to Inventory via add_unique_item()/add_stackable() (chosen by
## the item's own is_unique_instance field) if it resolves via
## GameDataRegistry — skill-modifier items don't exist in content yet
## (Story 004/007's flagged, still-open inventory.md item_type gap), so this
## path is exercised by test fixtures only until that content lands; a
## genuinely unresolvable item_id is logged and the excess binding is simply
## dropped (nothing left to return). AC-25 (off-build passive configuration)
## required no code change — set_passive_slot() was never gated on
## active-slot occupancy (Story 004), only confirmed by this story's test.

const ACTIVE_SLOT_COUNT: int = 4
const CATEGORIES: Array[String] = ["physical", "ranged", "elemental", "support"]
const RESTORE_ORDER: int = 31

## Formula 2's exhaustive, mutually-exclusive shape classification — one of
## the 5 integer partitions of 4.
enum Shape { PURE, TRIPLE, DOUBLE_DOUBLE, DOUBLE_SINGLE_SINGLE, ALL_DIFFERENT }

## Sanctuary-only write gate (Rule 3). Test seam: unit tests instantiate
## HeroSkillBuild.new() without add_child(), so _ready() never runs — tests
## set this directly (same convention as Defense Building's _is_sanctuary seam).
var _is_sanctuary: bool = false

## Mirror of Tower Mastery's unlock state — populated exclusively via the
## skill_unlocked subscription in a later story, never independently derived.
var _equippable_skills: Dictionary[String, bool] = {}

## 4 active slot bindings (A, B, C, D). Empty string means unassigned.
var _active_slots: Array[String] = ["", "", "", ""]

## skill_id -> Array[String] of installed skill-modifier item IDs.
var _passive_slots: Dictionary[String, Array] = {}


func _ready() -> void:
	GEventBus.scene_transition_completed.connect(_on_scene_transition_completed)
	GEventBus.mission_launched.connect(_on_mission_launched)
	GEventBus.skill_unlocked.connect(_on_skill_unlocked)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GEventBus.scene_transition_completed.disconnect(_on_scene_transition_completed)
	GEventBus.mission_launched.disconnect(_on_mission_launched)
	GEventBus.skill_unlocked.disconnect(_on_skill_unlocked)
	GSavePersistence.unregister(self)


## Adds skill_id to the equippable-skill mirror the instant it's received —
## live in every state including LOCKED (AC-17). Never triggers an Ultimate
## recompute and never emits an EventBus event — this is not an active/
## passive-slot write.
func _on_skill_unlocked(skill_id: String, _source_tower_id: int) -> void:
	_equippable_skills[skill_id] = true


## Deferred per ADR-0001 Core Rule 2 — this handler is itself an EventBus
## subscriber emitting further events (a Level-1 cascade), must defer rather
## than emit synchronously within the mission_launched call stack.
func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	call_deferred("_push_current_build")


## Re-emits the full current build (all occupied active slots +
## ultimate_skill_changed) so a freshly-instantiated Hero always receives it
## at mission start, regardless of scene-transition timing. Idempotent by
## construction — redundant delivery (e.g. on a retry_current_mission() cycle,
## ADR-0028) just re-sets Hero's slot bindings to the same values, harmless.
func _push_current_build() -> void:
	for i: int in ACTIVE_SLOT_COUNT:
		if not _active_slots[i].is_empty():
			GEventBus.active_skill_equipped.emit(i, _active_slots[i])
	GEventBus.ultimate_skill_changed.emit(_derive_ultimate_id())


func _on_scene_transition_completed(target_context: String, _mission_id: String) -> void:
	_is_sanctuary = (target_context == "SANCTUARY")


## True while LOCKED (any in-mission phase) — slot writes are rejected.
func is_locked() -> bool:
	return not _is_sanctuary


## Returns a copy of the 4 active slot bindings (A, B, C, D order).
func get_active_slots() -> Array[String]:
	return _active_slots.duplicate()


## Returns all 5 independent binding slots (A, B, C, D, U — AC-1). U
## (Ultimate) is always the live-derived value ("EMPTY" if the Formula 1
## precondition isn't met) — never a stored field. There is no corresponding
## set_ultimate_slot() — Hero Skill Build never accepts a direct write to U
## (Rule 9: Hero System only ever applies the resolved Ultimate, never
## re-derives or directly assigns it).
func get_all_slot_bindings() -> Dictionary[String, String]:
	return {
		"A": _active_slots[0], "B": _active_slots[1],
		"C": _active_slots[2], "D": _active_slots[3],
		"U": _derive_ultimate_id(),
	}


## Writes skill_id into active slot_index (0-3, A-D). Rejected while LOCKED
## (Rule 3 — no state change). Duplicate skill_id across slots is never
## blocked (Rule 2) — the same skill_id may occupy 2, 3, or all 4 slots.
## Pass an empty String to clear the slot. On success, emits
## active_skill_equipped(slot_index, skill_id) unconditionally — including a
## clear (empty skill_id), so Hero's own _skill_slots bookkeeping stays in
## sync — then recomputes and emits ultimate_skill_changed unconditionally,
## even if the resolved value is unchanged from before (Rule 10 EC/AC-11 —
## Hero discards its cooldown timer on every receipt regardless). Returns
## true on success.
func set_active_slot(slot_index: int, skill_id: String) -> bool:
	if is_locked():
		return false
	if slot_index < 0 or slot_index >= ACTIVE_SLOT_COUNT:
		return false
	_active_slots[slot_index] = skill_id
	GEventBus.active_skill_equipped.emit(slot_index, skill_id)
	GEventBus.ultimate_skill_changed.emit(_derive_ultimate_id())
	return true


## Story-001-scoped occupied-slot category tally (AC-4) — counts one
## increment per occupied active slot, regardless of skill_id repetition.
## Skips empty slots and slots whose skill_id doesn't resolve to a real
## SkillDefinitionResource. Distinct from Story 002's stricter Formula 1
## (which requires ALL 4 slots filled+equippable as an Ultimate-derivation
## precondition) — see class doc comment.
func get_category_count() -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {"physical": 0, "ranged": 0, "elemental": 0, "support": 0}
	for skill_id: String in _active_slots:
		if skill_id.is_empty():
			continue
		var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
		if definition == null:
			continue
		if counts.has(definition.category):
			counts[definition.category] += 1
	return counts


## Formula 1: category profile. Requires ALL 4 active slots filled with
## skill_ids that resolve to a real SkillDefinitionResource (Rule 7
## precondition) — returns {} if any slot is empty or references an unknown
## skill_id, signaling the precondition failed. Computed fresh every call,
## never cached (Guardrail).
func _category_profile() -> Dictionary:
	var counts: Dictionary[String, int] = {"physical": 0, "ranged": 0, "elemental": 0, "support": 0}
	for skill_id: String in _active_slots:
		if skill_id.is_empty():
			return {}
		var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
		if definition == null:
			return {}
		if not counts.has(definition.category):
			return {}
		counts[definition.category] += 1
	return counts


## Formula 2: shape classification. Total and mutually exclusive — any 4
## non-negative integers summing to 4 form exactly one of the 5 integer
## partitions of 4. Pure function, catalogue-independent (AC-10c) — never
## reads GameDataRegistry.
func _classify_shape(profile: Dictionary) -> Shape:
	var max_count: int = 0
	var n_at_2: int = 0
	for category: String in CATEGORIES:
		var count: int = profile.get(category, 0)
		max_count = max(max_count, count)
	for category: String in CATEGORIES:
		if profile.get(category, 0) == 2:
			n_at_2 += 1
	if max_count == 4:
		return Shape.PURE
	if max_count == 3:
		return Shape.TRIPLE
	if max_count == 2 and n_at_2 == 2:
		return Shape.DOUBLE_DOUBLE
	if max_count == 2 and n_at_2 == 1:
		return Shape.DOUBLE_SINGLE_SINGLE
	return Shape.ALL_DIFFERENT


## Formula 3: Ultimate ID for a classified shape. 19 fixed outputs total
## (4 _ascendant + 4 _overload + 6 _fusion + 4 _surge + 1 convergence).
## "NONE" is an unreachable defensive guard (Forbidden rule) — proven
## unreachable for any valid profile produced by _classify_shape(), retained
## only against a data-integrity bug upstream. Pure function, catalogue-
## independent (AC-10c) — never reads GameDataRegistry.
func _ultimate_id_for_shape(shape: Shape, profile: Dictionary) -> String:
	match shape:
		Shape.PURE:
			for category: String in CATEGORIES:
				if profile.get(category, 0) == 4:
					return category + "_ascendant"
		Shape.TRIPLE:
			for category: String in CATEGORIES:
				if profile.get(category, 0) == 3:
					return category + "_overload"
		Shape.DOUBLE_DOUBLE:
			var twos: Array[String] = []
			for category: String in CATEGORIES:
				if profile.get(category, 0) == 2:
					twos.append(category)
			twos.sort()
			return "%s_%s_fusion" % [twos[0], twos[1]]
		Shape.DOUBLE_SINGLE_SINGLE:
			for category: String in CATEGORIES:
				if profile.get(category, 0) == 2:
					return category + "_surge"
		Shape.ALL_DIFFERENT:
			return "convergence"
	return "NONE"


## Full pipeline entry point (Formulas 1-3). Returns "EMPTY" if Formula 1's
## precondition isn't met (fewer than 4 slots filled, or any slot references
## an unknown skill_id — AC-6/AC-7) without evaluating Formula 2/3 at all.
func _derive_ultimate_id() -> String:
	var profile: Dictionary = _category_profile()
	if profile.is_empty():
		return "EMPTY"
	var shape: Shape = _classify_shape(profile)
	return _ultimate_id_for_shape(shape, profile)


## Equips item_id into skill_id's passive_slot_index (0-based, bounded by
## that skill's own passive_slot_count). Rejected while LOCKED (Rule 3) or if
## slot_index is out of bounds. No EventBus event fires (Forbidden rule,
## AC-13) — internal state only. Pass an empty String to clear the slot
## (always allowed regardless of item_type — clearing never needs a
## compatibility check).
##
## Rule 13 (revised 2026-09-01 — typed passive slots): item_id must resolve
## to a real ItemDefinitionResource with item_type == "skill_modifier", and
## its requires_tag must either be "any" or appear in the socketed skill's
## own effect_data.tags. Checked here, not continuously — an already-equipped
## item is never retroactively invalidated (Rule 13's own explicit framing).
## Does not touch Inventory.set_slot_locked() — no existing equip flow in
## this codebase (Hero equipment, Tower Components) currently calls it
## either, confirmed via grep; wiring that up is a separate, pre-existing
## gap affecting the whole equip system, not scoped to this change.
func set_passive_slot(skill_id: String, slot_index: int, item_id: String) -> bool:
	if is_locked():
		return false
	var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
	if definition == null:
		return false
	if slot_index < 0 or slot_index >= definition.passive_slot_count:
		return false
	if item_id != "" and not _is_skill_modifier_compatible(item_id, definition):
		return false
	if not _passive_slots.has(skill_id):
		_passive_slots[skill_id] = []
	var loadout: Array = _passive_slots[skill_id]
	while loadout.size() <= slot_index:
		loadout.append("")
	loadout[slot_index] = item_id
	return true


## Rule 13's typed-slot compatibility check — see set_passive_slot()'s own
## doc comment. False for a non-existent item or a non-skill_modifier item.
## Otherwise checks exactly whichever of the item's 3 mutually-exclusive
## gating axes is populated (ItemDefinitionResource.requires_tag's own doc
## comment) — TD-hero-skill-002's resolution (2026-09-02) added the latter
## two axes for the 4 catalogued items that gate on damage_type/
## secondary_effect rather than a tag.
func _is_skill_modifier_compatible(item_id: String, skill: SkillDefinitionResource) -> bool:
	var item: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	if item == null or item.item_type != &"skill_modifier":
		return false
	if item.requires_tag == "any":
		return true
	if skill.effect_data == null:
		return false
	if item.requires_tag != "":
		return skill.effect_data.tags.has(item.requires_tag)
	if not item.requires_damage_type.is_empty():
		return item.requires_damage_type.has(skill.effect_data.damage_type)
	if not item.requires_secondary_effect.is_empty():
		return item.requires_secondary_effect.has(skill.effect_data.secondary_effect)
	return false


## Synchronous read of skill_id's current passive loadout, pulled at UI-open
## time (AC-14) — never delivered via subscription. Empty Array if skill_id
## has no passive slots equipped yet.
func get_passive_loadout(skill_id: String) -> Array[String]:
	var raw: Array = _passive_slots.get(skill_id, [])
	var result: Array[String] = []
	for item_id: Variant in raw:
		result.append(item_id as String)
	return result


## AC-22: equippable skill_ids that ALSO resolve via GameDataRegistry — the
## UI-facing query. Orphaned library entries remain in _equippable_skills
## (never discarded) but are excluded here, so the Sanctuary skill-build
## screen never surfaces them as assignable.
func get_assignable_skills() -> Array[String]:
	var result: Array[String] = []
	for skill_id: String in _equippable_skills:
		if not _equippable_skills[skill_id]:
			continue
		if GGameDataRegistry.get_skill_definition(StringName(skill_id)) != null:
			result.append(skill_id)
	return result


## AC-23: skill_id's passive loadout resolved against the item registry —
## any item_id that no longer resolves via GameDataRegistry.get_item_definition()
## (removed post-launch content) reads as "" (treated as empty for effect
## folding). The raw _passive_slots binding is untouched — this is a display/
## consumption-time resolution only, never a mutation.
func get_effective_passive_loadout(skill_id: String) -> Array[String]:
	var result: Array[String] = []
	for item_id: String in get_passive_loadout(skill_id):
		if item_id.is_empty():
			result.append("")
			continue
		if GGameDataRegistry.get_item_definition(StringName(item_id)) != null:
			result.append(item_id)
		else:
			result.append("")
	return result


func get_save_key() -> String:
	return "hero_skill_build"


## The resolved Ultimate is intentionally excluded (Guardrail — never
## persisted, always recomputed). Only the 3 structures below are saved.
func get_save_data() -> Dictionary:
	return {
		"equippable_skills": _equippable_skills.duplicate(),
		"active_slots": _active_slots.duplicate(),
		"passive_slots": _passive_slots.duplicate(true),
	}


## Returns false (not void!) on any malformed/missing data so SavePersistence
## falls back to reset_to_defaults(), matching every other SaveRestorer in
## this project. Type-checks every leaf before mutating any field — no
## partial-restore side effects on a rejected payload.
func restore_save_data(data: Dictionary) -> bool:
	if not (data.has("equippable_skills") and data.has("active_slots") and data.has("passive_slots")):
		return false

	var equippable_raw: Variant = data["equippable_skills"]
	var active_raw: Variant = data["active_slots"]
	var passive_raw: Variant = data["passive_slots"]
	if not (equippable_raw is Dictionary and active_raw is Array and passive_raw is Dictionary):
		return false

	var restored_equippable: Dictionary[String, bool] = {}
	for key: Variant in (equippable_raw as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (equippable_raw as Dictionary)[key]
		if not (value is bool):
			return false
		restored_equippable[key as String] = value as bool

	if (active_raw as Array).size() != ACTIVE_SLOT_COUNT:
		return false
	var restored_active: Array[String] = []
	for entry: Variant in (active_raw as Array):
		if not (entry is String):
			return false
		restored_active.append(entry as String)

	var restored_passive: Dictionary[String, Array] = {}
	for skill_id: Variant in (passive_raw as Dictionary):
		if not (skill_id is String):
			return false
		var loadout_raw: Variant = (passive_raw as Dictionary)[skill_id]
		if not (loadout_raw is Array):
			return false
		var loadout: Array[String] = []
		for item_id: Variant in (loadout_raw as Array):
			if not (item_id is String):
				return false
			loadout.append(item_id as String)
		restored_passive[skill_id as String] = loadout

	_equippable_skills = restored_equippable
	_active_slots = restored_active
	_passive_slots = restored_passive
	_reconcile_passive_slot_overflow()
	return true


## AC-24: trims each skill's passive loadout down to its CURRENT
## passive_slot_count (a content patch may have reduced it since the save
## was written) and returns any excess bound item to Inventory —
## add_unique_item()/add_stackable(), chosen by the item's own
## is_unique_instance field, if it still resolves via GameDataRegistry. An
## excess item_id that no longer resolves has nothing to return; logged and
## dropped (nothing left to preserve — the slot it occupied is gone, and the
## item itself no longer exists as content). Skips any skill_id whose
## SkillDefinitionResource itself no longer resolves at all — that's AC-21's
## orphaned-active-slot case, unrelated to a slot-count reduction.
func _reconcile_passive_slot_overflow() -> void:
	for skill_id: String in _passive_slots:
		var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
		if definition == null:
			continue
		var loadout: Array = _passive_slots[skill_id]
		if loadout.size() <= definition.passive_slot_count:
			continue
		var excess: Array = loadout.slice(definition.passive_slot_count)
		_passive_slots[skill_id] = loadout.slice(0, definition.passive_slot_count)
		for item_id: Variant in excess:
			var item_id_str: String = item_id as String
			if item_id_str.is_empty():
				continue
			var item_definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id_str))
			if item_definition == null:
				push_warning("HeroSkillBuild: passive_slot_count reduction orphaned item '%s' for skill '%s', but it no longer resolves in content — nothing to return." % [item_id_str, skill_id])
				continue
			# add_unique_item()/add_stackable() fail gracefully on a full
			# Inventory (return -1 / a nonzero leftover, emit
			# item_pickup_rejected) — check the result so the log accurately
			# reflects whether the item actually made it back, rather than
			# unconditionally claiming success (code review fix).
			var returned: bool = false
			if item_definition.is_unique_instance:
				returned = GInventory.add_unique_item(item_definition) != -1
			else:
				returned = GInventory.add_stackable(item_definition, 1) == 0
			if returned:
				push_warning("HeroSkillBuild: passive_slot_count reduction for skill '%s' returned orphaned item '%s' to Inventory." % [skill_id, item_id_str])
			else:
				push_warning("HeroSkillBuild: passive_slot_count reduction orphaned item '%s' for skill '%s', but Inventory rejected it (full) — item lost." % [item_id_str, skill_id])


## Clears all 3 persisted structures to their starting (brand-new-save)
## state, in lockstep with Tower Mastery's own reset (AC-16 — both are
## independent SaveRestorer implementations triggered by the same "no save
## data yet" condition, not a cross-system call). Never called by mission
## end — only by SavePersistence when no save data exists yet, or when
## restore_save_data() rejects malformed data.
func reset_to_defaults() -> void:
	_equippable_skills.clear()
	_active_slots = ["", "", "", ""]
	_passive_slots.clear()

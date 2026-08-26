class_name DamageStatus
extends Node

## Damage & Status pipeline — single event-driven node. No public method API.
##
## All inputs arrive via GEventBus; all outputs via GEventBus.
## ADR-0007: deferred one-frame dispatch via await get_tree().process_frame;
## is_instance_valid(self) is the FIRST statement after every await (no exceptions).
## Lifesteal resolves on monster_hp_absorbed — synchronous Level-1 cascade
## (ADR-0007 exemption: volume-bounded, terminal).

const ARMORED_MITIGATION_MULTIPLIER: float = 0.50
const HERO_DAMAGE_BONUS_MULTIPLIER: float = 1.50

## target_entity_id → hero_lifesteal_fraction. Registered before await so the
## round-trip value is available when monster_hp_absorbed arrives next frame.
var _lifesteal_pending: Dictionary[int, float] = {}


func _ready() -> void:
	GEventBus.tower_attacked.connect(_on_tower_attacked)
	GEventBus.hero_auto_attacked.connect(_on_hero_auto_attacked)
	GEventBus.hero_skill_attacked.connect(_on_hero_skill_attacked)
	GEventBus.monster_hp_absorbed.connect(_on_monster_hp_absorbed)
	GEventBus.wave_completed.connect(_on_wave_completed)
	GEventBus.hero_died.connect(_on_hero_died)


func _exit_tree() -> void:
	GEventBus.tower_attacked.disconnect(_on_tower_attacked)
	GEventBus.hero_auto_attacked.disconnect(_on_hero_auto_attacked)
	GEventBus.hero_skill_attacked.disconnect(_on_hero_skill_attacked)
	GEventBus.monster_hp_absorbed.disconnect(_on_monster_hp_absorbed)
	GEventBus.wave_completed.disconnect(_on_wave_completed)
	GEventBus.hero_died.disconnect(_on_hero_died)


## D1 formula: floor(raw_damage × mitigation). is_siege unused at MVP.
## effect_type/effect_value/effect_duration (2026-08-13): burn/poison status
## ticks are resolved by Monster System's own status-tick pass, not D&S — see
## damage-status.md Rule I.3's exception note. Ignored here on purpose.
##
## armor_penetration/is_crit (Tower Stats System Phase 1, 2026-08-16):
## armor_penetration reduces the armored-mitigation multiplier itself —
## effective_mitigation = ARMORED_MITIGATION_MULTIPLIER + (1.0 -
## ARMORED_MITIGATION_MULTIPLIER) × armor_penetration, clamped to
## [ARMORED_MITIGATION_MULTIPLIER, 1.0] (0% pen = today's flat 0.5, 100% pen
## = mitigation fully countered). damage_amount arrives with crit already
## applied (TowerSystem's own job) — is_crit is only forwarded here so
## MonsterDamageTaken carries a real value instead of the previous hardcoded
## false, for any VFX/audio/HUD hook that wants to react to a tower crit.
func _on_tower_attacked(_tower_id: int, target_monster_id: int, damage_amount: float,
		_is_siege: bool, is_armored: bool, _effect_type: String, _effect_value: float,
		_effect_duration: float, armor_penetration: float, is_crit: bool) -> void:
	var mitigation: float = 1.0
	if is_armored:
		mitigation = clampf(
			ARMORED_MITIGATION_MULTIPLIER + (1.0 - ARMORED_MITIGATION_MULTIPLIER) * armor_penetration,
			ARMORED_MITIGATION_MULTIPLIER, 1.0
		)
	var resolved: float = damage_amount * mitigation
	var final_damage: int = floori(resolved)
	if final_damage <= 0:
		return
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var ev: MonsterDamageTaken = MonsterDamageTaken.new()
	ev.entity_id = target_monster_id
	ev.amount = final_damage
	ev.source_type = 0  # 0 = tower (see MonsterDamageTaken source_type values)
	ev.is_crit = is_crit
	ev.hero_bonus_tier = 0
	GEventBus.monster_damage_taken.emit(ev)


## D2 formula: floor(base × tier_mult × crit_mult). One flat HERO_DAMAGE_BONUS_MULTIPLIER
## for any hero_bonus_tier > 0 (ELITE and BOSS resolve identically) — confirmed correct
## per design/gdd/hero.md Formula 4 (`elite_boss_multiplier` range is {1.0, 1.5}, no
## distinct BOSS value) and user decision (TD-story-002, resolved 2026-07-08). Story
## 004's own text originally claimed a distinct BOSS=2.0x, contradicting its own
## governing GDD; the story text was corrected to match this shipped behavior instead.
## Lifesteal fraction registered before await — must survive across the frame boundary.
func _on_hero_auto_attacked(event: HeroAutoAttackEvent) -> void:
	var tier_dmg: float = event.base_damage * (HERO_DAMAGE_BONUS_MULTIPLIER if event.hero_bonus_tier > 0 else 1.0)
	var crit_dmg: float = tier_dmg * (event.crit_multiplier_effective if event.is_crit else 1.0)
	var final_damage: int = floori(crit_dmg)
	if final_damage <= 0:
		return
	if event.hero_lifesteal_fraction > 0.0:
		_lifesteal_pending[event.target_id] = event.hero_lifesteal_fraction
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var ev: MonsterDamageTaken = MonsterDamageTaken.new()
	ev.entity_id = event.target_id
	ev.amount = final_damage
	ev.source_type = 1  # 1 = hero (see MonsterDamageTaken source_type values)
	ev.is_crit = event.is_crit
	ev.hero_bonus_tier = event.hero_bonus_tier
	GEventBus.monster_damage_taken.emit(ev)


## D7 formula (Rule IX, added 2026-08-26 — closes TD-hero-001's Skill Power
## GDScript implementation gap): floor(base × tier_mult × crit_mult),
## structurally identical to D2/_on_hero_auto_attacked() from the tier step
## onward — only the base term differs (skill_power × skill_power_coefficient
## instead of a pre-resolved base_damage). Reuses the same
## HERO_DAMAGE_BONUS_MULTIPLIER constant as D2 — Rule IX.3 is explicit that
## no second constant is introduced for skills.
##
## Rule IX.9: lifesteal is NOT wired here on purpose — HeroSkillAttackEvent
## carries no hero_lifesteal_fraction field at all (unlike HeroAutoAttackEvent),
## so there is no fraction to register into _lifesteal_pending even
## defensively. See damage-status.md OQ-5 for the open question this leaves.
func _on_hero_skill_attacked(event: HeroSkillAttackEvent) -> void:
	var base_skill_damage: float = event.skill_power * event.skill_power_coefficient
	var tier_dmg: float = base_skill_damage * (HERO_DAMAGE_BONUS_MULTIPLIER if event.hero_bonus_tier > 0 else 1.0)
	var crit_dmg: float = tier_dmg * (event.crit_multiplier_effective if event.is_crit else 1.0)
	var final_damage: int = floori(crit_dmg)
	if final_damage <= 0:
		return
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var ev: MonsterDamageTaken = MonsterDamageTaken.new()
	ev.entity_id = event.target_id
	ev.amount = final_damage
	ev.source_type = 1  # 1 = hero (see MonsterDamageTaken source_type values)
	ev.is_crit = event.is_crit
	ev.hero_bonus_tier = event.hero_bonus_tier
	GEventBus.monster_damage_taken.emit(ev)


## D3 formula: floor(absorbed × fraction). Synchronous — ADR-0007 Level-1 cascade exemption.
func _on_monster_hp_absorbed(entity_id: int, absorbed: int) -> void:
	if not _lifesteal_pending.has(entity_id):
		return
	var fraction: float = _lifesteal_pending[entity_id]
	_lifesteal_pending.erase(entity_id)
	var heal_amount: int = floori(absorbed * fraction)
	if heal_amount > 0:
		GEventBus.hero_healed.emit(heal_amount)


## Deferred clear — lets same-frame monster_hp_absorbed events resolve before wiping state.
## Story 002 (epic-04-wave-manager): wave_completed gained a third
## was_boss_breached: bool field. GDScript requires connected handlers to
## accept every argument a signal emits (arity must match exactly — extra
## args are NOT silently dropped, contrary to this agent's initial
## assumption; verified by a parse error during regression testing). This
## handler ignores the new field but must declare it.
func _on_wave_completed(_wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	if _lifesteal_pending.is_empty():
		return
	# Any entries added this same frame by concurrent hero_auto_attacked coroutines
	# will be cleared here. This is intentional — wave_completed means no live monsters;
	# any such entries are orphaned (ADR-0007: acceptable cleanup behaviour).
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	_lifesteal_pending.clear()


## TD-damage-002 (fixed 2026-08-26): Rule VIII (Hero-Death Cleanup) was
## documented in damage-status.md since 2026-07-15d as already-shipped
## behavior but had no actual implementation anywhere in this file — this
## closes that gap.
##
## Rule VIII.2: clears _lifesteal_pending IMMEDIATELY, SYNCHRONOUSLY — no
## await, unlike _on_wave_completed()'s deferred clear above. Rule VIII.3's
## rationale (see the GDD, not repeated in full here): a lifesteal hit landed
## just before the hero's own death defers its heal by one frame
## (_on_hero_auto_attacked()/_on_hero_skill_attacked() both register into
## _lifesteal_pending before their own await) before monster_damage_taken/
## monster_hp_absorbed resolve on the Monster System side. hero_died and that
## deferred resolution are two unrelated chains with no guaranteed relative
## order — if monster_hp_absorbed for a pending hit arrives AFTER hero_died
## has already fired, without this synchronous clear _on_monster_hp_absorbed()
## would still find the entry present and emit hero_healed on an
## already-dead hero. Clearing here the instant hero_died fires means any
## monster_hp_absorbed arriving afterward finds no entry —
## _on_monster_hp_absorbed()'s existing "if not present: ignore" guard
## (line ~135 above) suppresses the heal with no new logic needed there.
##
## Rule VIII.4/VIII.5: this does NOT wait a frame the way _on_wave_completed()
## does (that method drains pending heals before clearing, preserving a
## legitimate end-of-wave killing-blow heal; this method discards
## immediately, since by definition no heal received after hero_died can be
## legitimate). wave_completed and hero_died are mutually exclusive triggers
## within a mission (Wave Manager's own DEFEAT-priority rule) — no
## double-clear ordering hazard between the two handlers.
##
## Rule VIII.6 documents a structural timing dependency this rule's
## correctness relies on (Monster System's monster_hp_absorbed flush being
## pinned to _physics_process, resolving before this handler's synchronous
## clear within the same frame) — that dependency is a property of the
## surrounding systems, not enforced by this handler itself, and (like the
## rest of this pass) not live-verified here. See the GDD for the full
## explanation if that guarantee is ever suspected broken.
func _on_hero_died() -> void:
	_lifesteal_pending.clear()

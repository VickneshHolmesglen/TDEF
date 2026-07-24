class_name SnapshotChip
extends Node

## Current Build Snapshot chip -- the shell's own cross-screen bridge (Story
## 005, epic-11-tarot-deck-ui).
##
## GDD source: design/gdd/tarot-deck-ui.md -- Core Rule 7, AC Group 5.
## Story: production/epics/epic-11-tarot-deck-ui/story-005-current-build-snapshot.md
##
## Pure reads of state each wrapped system already derives for its own
## purposes -- this class introduces no new formula, no new EventBus event,
## no new data ownership (matches the GDD's own "no formulas" framing).
##
## Ultimate half is fully real: GHeroSkillBuild is a genuine Autoload
## (confirmed in project.godot) exposing get_all_slot_bindings()["U"] as a
## live-derived read ("EMPTY" sentinel matches this class's own
## EMPTY_ULTIMATE constant exactly, per hero_skill_build.gd's own doc
## comment -- never a stored field, always freshly derived on call).
##
## Tarot-risk half, RESOLVED 2026-07-25: Tarot is still scene-instanced
## (ADR-0027), not an Autoload, but its one real instance now lives as a
## shell-owned child of TarotDeckUI.tscn (added alongside the real Tarot/
## Hero Skill Build screens, matching equipment_forge.gd's own identical
## "equipment_forge" group precedent). get_tarot_risk_summary() discovers it
## via the "tarot" group and returns a real, live-derived reading --
## get_active_card_count() (the equipped-deck size), the closest existing
## real signal to "aggregate risk" per this class's own doc comment; a
## dedicated risk-aggregate formula, if the GDD ever specifies one, replaces
## this read without changing the {"available": bool, ...} shape callers
## already depend on. Still returns {"available": false} in the one
## remaining genuine case: no TarotDeckUI shell mounted at all (this chip
## instantiated standalone, outside its normal host).

const EMPTY_ULTIMATE: String = "EMPTY"


## Hero Skill Build's currently-derived ultimate_id, or EMPTY_ULTIMATE when
## fewer than 4 slots are filled (hero_skill_build.gd's own defined value).
## Always a live read, never cached -- matches the GDD's own "reads it, never
## computes it" requirement exactly.
func get_ultimate_id() -> String:
	return GHeroSkillBuild.get_all_slot_bindings().get("U", EMPTY_ULTIMATE)


## Tarot's current aggregate risk readout -- see class doc comment for what
## "aggregate risk" currently means (equipped-deck size) and why.
func get_tarot_risk_summary() -> Dictionary:
	var tree: SceneTree = get_tree()
	if tree == null:
		return {"available": false}  # this chip isn't inside a scene tree at all (e.g. a standalone .new())
	var tarot: Tarot = tree.get_first_node_in_group(&"tarot") as Tarot
	if tarot == null:
		return {"available": false}
	return {"available": true, "equipped_card_count": tarot.get_active_card_count()}
